local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Config=require(game.ReplicatedStorage.FortuneConfig)
local Ledger=require(script.Parent.FortuneLedger)
local store=not Run:IsStudio() and game:GetService("DataStoreService"):GetDataStore(Config.DataStoreName) or nil
local S={}
local cache,busy,pending={},{},{}
local started=false
local function publish(player,data)
	cache[player.UserId]=data
	if player.Parent~=Players then return end
	player:SetAttribute("MOINS",data.MOINS)
	player:SetAttribute("MOINSLoaded",true)
	player:SetAttribute("MOINSLoadFailed",false)
	player:SetAttribute("StudioMOINSPreview",Run:IsStudio())
	local stats=player:FindFirstChild("leaderstats")
	if not stats then stats=Instance.new("Folder");stats.Name="leaderstats";stats.Parent=player end
	local balance=stats:FindFirstChild("MOINS")
	if not balance then balance=Instance.new("IntValue");balance.Name="MOINS";balance.Parent=stats end
	balance.Value=data.MOINS
	-- Use the saved lobby selections, never auto-equip an owned but unequipped card.
 local perkIndex=0
 for _,category in Config.Categories do
  local id=data.Equipped[category.Key]
  local card=Config.Card(id)
  local valid=card and card.Kind==category.Key and (tonumber(data.Owned[id]) or 0)>0
  player:SetAttribute("Fortune_"..category.Key,valid and id or nil)
 end
 -- Same order as Customize > Perks in the lobby.
 for _,kind in {"SurvivorPerks","KillerPerks"} do
  local card=Config.Card(player:GetAttribute("Fortune_"..kind))
  if card then perkIndex+=1 player:SetAttribute("Perk"..perkIndex,card.Name) end
 end
 for i=perkIndex+1,4 do player:SetAttribute("Perk"..i,nil) end
 player:SetAttribute("PerkLoadoutLoaded",true)

end
local function load(player)
	player:SetAttribute("MOINSLoaded",false)
	for attempt=1,4 do
		local ok,data=pcall(function()
			if store then return store:UpdateAsync("Player_"..player.UserId,function(old) return Ledger.Normalize(old,Config.StartingMOINS) end) end
			return Ledger.Normalize(cache[player.UserId],Config.StartingMOINS)
		end)
		if ok then publish(player,data);return end
		if player.Parent~=Players then return end
		task.wait(math.min(2^attempt,8))
	end
	player:SetAttribute("MOINSLoadFailed",true)
	-- Fail closed: never replace an unread saved balance with a fresh balance.
end
function S.Start()
	if started then return end;started=true
	for _,player in Players:GetPlayers() do task.spawn(load,player) end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		task.delay(30,function() if not Players:GetPlayerByUserId(player.UserId) and not busy[player.UserId] then cache[player.UserId]=nil end end)
	end)
end
function S.Snapshot(player)
	local data=cache[player.UserId]
	if not data then return nil end
	return {MOINS=data.MOINS,Owned=table.clone(data.Owned),Equipped=table.clone(data.Equipped),Latest=data.Latest,PendingCategory=pending[player.UserId] and pending[player.UserId].card.Kind}
end
function S.Purchase(player,receipt,card)
	local id=player.UserId
	if busy[id] then return false,"busy" end
	if not cache[id] or not player:GetAttribute("MOINSLoaded") then return false,"loading" end
	if pending[id] then
		if pending[id].card.Kind~=card.Kind then return false,"pending" end
		receipt=pending[id].receipt;card=pending[id].card
	else pending[id]={receipt=receipt,card=card} end
	busy[id]=true
	local status,award,data
	local now=os.time()
	for attempt=1,3 do
		local ok,result=pcall(function()
			local function transform(old)
				local nextData
				nextData,status,award=Ledger.Purchase(old,Config.StartingMOINS,Config.Price,receipt,card,now)
				return nextData
			end
			return store and store:UpdateAsync("Player_"..id,transform) or transform(cache[id])
		end)
		if ok then data=result;break end
		-- The same receipt is retried after uncertain writes; it cannot charge twice.
		task.wait(attempt)
	end
	busy[id]=nil
	if not data then return false,"save_failed" end
	pending[id]=nil
	publish(player,data)
	if status=="insufficient" then return false,"insufficient" end
	return true,award,data
end
-- Server-only grant API. Receipt IDs make future round rewards safe to retry.
function S.Award(player,amount,receipt)
	assert(type(amount)=="number" and amount>0 and amount==math.floor(amount))
	assert(type(receipt)=="string" and #receipt>0)
	local id=player.UserId
	if busy[id] or not cache[id] then return false end
	busy[id]=true
	local ok,data=pcall(function()
		local function update(old)
			local d=Ledger.Normalize(old,Config.StartingMOINS)
			if not d.Receipts[receipt] then
				d.MOINS+=amount;d.Receipts[receipt]={Credit=amount};table.insert(d.ReceiptOrder,receipt)
				while #d.ReceiptOrder>100 do d.Receipts[table.remove(d.ReceiptOrder,1)]=nil end
			end
			return d
		end
		return store and store:UpdateAsync("Player_"..id,update) or update(cache[id])
	end)
	busy[id]=nil
	if ok then publish(player,data) end
	return ok
end
return S
