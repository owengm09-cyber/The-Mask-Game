local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local Config=require(game.ReplicatedStorage.FortuneConfig)
local Wallet=require(script.Parent.MOINSService)
local Rewards=require(script.Parent.FortuneRewards)
local Passes=require(script.Parent:WaitForChild("GamePassService"))
local Rolls=require(game.ReplicatedStorage:WaitForChild("FortuneRoll"))
local remote=game.ReplicatedStorage.FortuneRemotes.FortuneEvent
local S={}
local machine,mechanism,prompt,session
local throttles={}
local function send(player,kind,data)
	if player and player.Parent==Players then remote:FireClient(player,kind,data) end
end
local function near(player,position,distance)
	if not player or player.Parent~=Players or player:GetAttribute("InRound") then return false end
	local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid");local r=c and c:FindFirstChild("HumanoidRootPart")
	return h and h.Health>0 and r and (r.Position-position).Magnitude<=distance
end
local function state(phase)
	machine:SetAttribute("FortunePhase",phase)
	machine:SetAttribute("Awake",phase~="Idle")
end
local function finish(s)
	if session~=s then return end
	mechanism.Reset();session=nil;prompt.Enabled=true
	machine:SetAttribute("FortuneOwner",0);state("Idle")
end
local function cancel(s,message)
	if session~=s then return end
	s.cancelled=true;send(s.player,"Closed",{Message=message})
	if s.phase=="Choosing" or s.phase=="CardReady" or s.phase=="SavePending" then finish(s) end
end
function S.Begin(player)
	if not machine or session or not prompt.Enabled or not near(player,prompt.Parent.Position,12) then return false end
	if not player:GetAttribute("MOINSLoaded") then send(player,"Notice",{Message="Your MOINS are still loading. Try again in a moment."});return false end
	local s={player=player,id=Http:GenerateGUID(false),phase="Awakening",expires=os.clock()+Config.SessionSeconds}
	session=s;prompt.Enabled=false;machine:SetAttribute("FortuneOwner",player.UserId);state(s.phase)
	send(player,"Awakening",{Message="Zoltar stirs..."})
	task.spawn(function()
		local ok,err=xpcall(function()
			mechanism.Awaken()
			if session~=s then return end
			if s.cancelled or not near(player,prompt.Parent.Position,16) then finish(s);return end
			s.phase="Choosing";state(s.phase)
			local snapshot=Wallet.Snapshot(player)
			send(player,"Open",{Session=s.id,Wallet=snapshot,Price=Config.Price,RetryCategory=snapshot and snapshot.PendingCategory})
		end,debug.traceback)
		if not ok then warn("Zoltar awakening: "..tostring(err));send(player,"Notice",{Message="Zoltar is quiet. Please try again."});finish(s) end
	end)
	return true
end
function S.Collect(player,id)
	local s=session
	if not s or s.player~=player or s.id~=id or s.phase~="CardReady" or not near(player,prompt.Parent.Position,12) then return false end
	s.phase="Claimed"
	send(player,"Reveal",{Card=Config.Card(s.award.Id),Wallet=Wallet.Snapshot(player),Count=Wallet.Snapshot(player).Owned[s.award.Id]})
	finish(s);return true
end
function S.Choose(player,id,categoryKey)
	local s=session
	if type(id)~="string" or type(categoryKey)~="string" or not s or s.player~=player or s.id~=id then return false end
	if s.phase~="Choosing" and s.phase~="SavePending" then return false end
	if not Config.Category(categoryKey) or not near(player,prompt.Parent.Position,12) then return false end
	if s.card and s.card.Kind~=categoryKey then send(player,"Error",{Message="Please retry the deck you already selected."});return false end
	if not s.card then
        s.phase="Checking"
        local allowed=Passes.CanDrawAsync(player)
        local lucky=allowed==true and Passes.OwnsAsync(player.UserId,"PerkLuck")
        if session~=s or s.cancelled or not near(player,prompt.Parent.Position,12) then
            if session==s then finish(s) end
            return false
        end
        if allowed~=true or lucky==nil then
            s.phase="Choosing";state(s.phase)
            local message=allowed==false and "Fortunes are unavailable for this account." or "Your pass benefits are still connecting. Please try again."
            send(player,"Error",{Message=message,Wallet=Wallet.Snapshot(player)})
            return false
        end
        s.card=Rolls.Roll(categoryKey,lucky)
    end
	s.phase="Saving";state(s.phase);s.expires=os.clock()+Config.SessionSeconds
	send(player,"Saving",{Message="Zoltar is preparing your fortune..."})
	task.spawn(function()
		local ok,err=xpcall(function()
			local purchased,award=Wallet.Purchase(player,s.id,s.card)
			if not purchased then
				if s.cancelled then finish(s);return end
				s.phase=award=="save_failed" and "SavePending" or "Choosing";state(s.phase)
				if award~="save_failed" then s.card=nil end
				local messages={insufficient="You need 50 MOINS for a fortune. No MOINS were spent.",loading="Your MOINS are still loading. Try again shortly.",busy="Your wallet is busy. Please try again.",save_failed="The fortune could not be confirmed. Retry this deck; you will not be charged twice."}
				send(player,"Error",{Message=messages[award] or "Please try again.",Wallet=Wallet.Snapshot(player),RetryOnly=s.phase=="SavePending"})
				return
			end
			s.award=award;Rewards.Apply(player)
			if s.cancelled or player.Parent~=Players then finish(s);return end
			s.phase="Drawing";state(s.phase)
			send(player,"Drawing",{Message="Your Moin rolls toward fate...",Wallet=Wallet.Snapshot(player)})
			local card=mechanism.Dispense(Config.Category(award.Kind))
			if s.cancelled or player.Parent~=Players then finish(s);return end
			s.phase="CardReady";state(s.phase);s.expires=os.clock()+40
			local pickup=Instance.new("ProximityPrompt");pickup.Name="CollectFortune";pickup.ActionText="Take your fortune";pickup.ObjectText="A card for "..player.DisplayName
			pickup.MaxActivationDistance=10;pickup.HoldDuration=.2;pickup.RequiresLineOfSight=false;pickup.Parent=card
			pickup.Triggered:Connect(function(p) S.Collect(p,s.id) end)
			send(player,"CardReady",{Session=s.id,Message="Take your card from Zoltar's slot."})
		end,debug.traceback)
		if not ok then
			warn("Zoltar fortune: "..tostring(err))
			if s.award then send(player,"Reveal",{Card=Config.Card(s.award.Id),Wallet=Wallet.Snapshot(player),Message="Your fortune was saved."})
			else send(player,"Notice",{Message="Zoltar could not finish. Please try again."}) end
			finish(s)
		end
	end)
	return true
end
function S.Start(model)
	if machine then return end
	machine=model;mechanism=require(model.ZoltarMechanism).New(model)
	prompt=model.ControlsAndCardSlot.CoinMechanismBlackPlate.ConsultZoltar
	prompt.ActionText="50 MOINS For Your Fortune";prompt.ObjectText="Zoltar";prompt.HoldDuration=.35;prompt.MaxActivationDistance=10;prompt.Enabled=true
	Wallet.Start();Rewards.Start();state("Idle")
	prompt.Triggered:Connect(S.Begin)
	remote.OnServerEvent:Connect(function(player,action,id,key)
		if type(action)~="string" then return end
		local now=os.clock();local last=throttles[player] or -math.huge
		if now-last<.15 then return end;throttles[player]=now
		if action=="Sync" then send(player,"Wallet",Wallet.Snapshot(player))
		elseif action=="Choose" then S.Choose(player,id,key)
		elseif action=="Collect" then S.Collect(player,id)
		elseif action=="Cancel" and session and session.player==player and session.id==id then cancel(session)
		end
	end)
	Players.PlayerRemoving:Connect(function(player) throttles[player]=nil;if session and session.player==player then cancel(session) end end)
	task.spawn(function()
		while machine.Parent do
			task.wait(.5)
			local s=session
			if s and not s.cancelled and (os.clock()>s.expires or not near(s.player,prompt.Parent.Position,18)) then
				local message=s.award and "Your fortune is saved in your collection." or "The reading ended. No MOINS were spent."
				if s.phase=="Saving" or s.phase=="SavePending" then message="The reading closed. Any confirmed fortune is kept in your collection." end
				cancel(s,message)
			end
		end
	end)
end
-- No Zoltar machine in this place (the lobby lives in its own experience):
-- keep the MOINS wallet, fortune rewards and the HUD's wallet sync running.
function S.StartWithoutMachine()
	if machine or S._walletOnly then return end
	S._walletOnly=true
	Wallet.Start();Rewards.Start()
	remote.OnServerEvent:Connect(function(player,action)
		if type(action)~="string" then return end
		local now=os.clock();local last=throttles[player] or -math.huge
		if now-last<.15 then return end;throttles[player]=now
		if action=="Sync" then send(player,"Wallet",Wallet.Snapshot(player)) end
	end)
	Players.PlayerRemoving:Connect(function(player) throttles[player]=nil end)
end
function S.GetSession() return session end
return S
