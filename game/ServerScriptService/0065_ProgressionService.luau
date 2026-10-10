local S={}
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Math=require(script.Parent.ProgressionMath)
local Passes=require(script.Parent:WaitForChild("GamePassService"))
local store=not Run:IsStudio() and game:GetService("DataStoreService"):GetDataStore("MaskProgression_v1") or nil
local Transfer=require(script.Parent.ForestProgressTransfer)
local cache,pending,busy={},{},{}
local round
local remotes=game.ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder",game.ReplicatedStorage) remotes.Name="Remotes"
local results=remotes:FindFirstChild("RoundXPResults") or Instance.new("RemoteEvent") results.Name="RoundXPResults" results.Parent=remotes
local function publish(id,data)
 cache[id]=data
 local p=Players:GetPlayerByUserId(id) if not p then return end
 local level,xp,cost=Math.Level(data.XP)
 p:SetAttribute("Level",level) p:SetAttribute("TotalXP",data.XP) p:SetAttribute("LevelXP",xp) p:SetAttribute("NextLevelXP",cost)
 p:SetAttribute("ProgressionLoaded",true)
 local stats=p:FindFirstChild("leaderstats") or Instance.new("Folder",p) stats.Name="leaderstats"
 for n,v in {Level=level,Wins=data.Wins or 0} do local item=stats:FindFirstChild(n) or Instance.new("IntValue",stats) item.Name=n item.Value=v end
end
local function flush(id)
 if busy[id] then return end busy[id]=true
 while pending[id] and #pending[id]>0 do
 local award=pending[id][1]
 if not award.vipApplied then
  local ownsVIP=Passes.OwnsAsync(id,"VIP")
  if ownsVIP==nil then
   local p=Players:GetPlayerByUserId(id) if p then p:SetAttribute("XPSavePending",true) end
   break -- Keep the award pending instead of silently dropping a paid XP bonus.
  end
  award.amount,award.parts=Math.AddVIP(award.amount,award.parts,ownsVIP)
  award.vipApplied=true
 end
 local ok,data
 if store then ok,data=pcall(function() return store:UpdateAsync("Player_"..id,function(old) return Math.Apply(old,award.receipt,award.amount,award.won) end) end)
 else ok=true data=Math.Apply(cache[id],award.receipt,award.amount,award.won) end
 if not ok then
 local p=Players:GetPlayerByUserId(id) if p then p:SetAttribute("XPSavePending",true) end
 warn("XP save pending; retry scheduled for user "..id) break
 end
 publish(id,data) table.remove(pending[id],1)
 local p=Players:GetPlayerByUserId(id) if p then p:SetAttribute("XPSavePending",false) results:FireClient(p,award.winner,award.amount,award.parts,award.won) end
 end
 busy[id]=nil
end
local function load(p)
 p:SetAttribute("ProgressionLoaded",false)
 p:SetAttribute("StudioXPPreview",Run:IsStudio())
 for attempt=1,4 do
 local ok,data=true,nil
 if store then ok,data=pcall(function()return store:GetAsync("Player_"..p.UserId)end) end
 if ok then
 local incoming=Transfer.Read(p)
 if incoming then
  if store then
   ok,data=pcall(function()
    return store:UpdateAsync("Player_"..p.UserId,function(old) return Transfer.Merge(old,incoming) end)
   end)
  else data=Transfer.Merge(cache[p.UserId] or data,incoming) end
 end
 if ok then
  if p.Parent~=Players then return end
  publish(p.UserId,data or cache[p.UserId] or {XP=0,Wins=0,Receipts={}})
  p:SetAttribute("ProgressionLoadFailed",false)
  return
 end
end
 task.wait(2^attempt)
 end
 p:SetAttribute("ProgressionLoadFailed",true)
end
function S.WaitForSaves(players,timeout)
 local deadline=os.clock()+(timeout or 20)
 repeat
  local remaining=false
  for _,p in players do
   local id=p.UserId
   if busy[id] or (pending[id] and #pending[id]>0) then
    remaining=true
    if not busy[id] then task.spawn(flush,id) end
   end
  end
  if not remaining then return true end
  task.wait(.2)
 until os.clock()>=deadline
 return false
end
function S.Begin(players)
 assert(not round,"An XP round is already active")
 round={id=game:GetService("HttpService"):GenerateGUID(false),records={}}
 for _,p in players do
 round.records[p.UserId]={player=p,team="Innocents",tasks=0,kills=0,seconds=0,done={},left=false}
 p:SetAttribute("RoundTasks",0)
 end
end
function S.MarkMonster(p)
 local r=round and round.records[p.UserId] if r then r.team="Monster" end
end
function S.Kill(p,target)
 local r=round and round.records[p.UserId]
 local victim=target and round and round.records[target.UserId]
 if r and victim and r.team=="Monster" and victim.team=="Innocents" then r.kills+=1 end
end
function S.Tick(dt)
 if not round then return end
 for _,r in round.records do
 local p=r.player local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if p.Parent==Players and p:GetAttribute("InRound") and h and h.Health>0 then r.seconds+=dt end
 end
end
function S.InnocentsAlive()
 local n=0 if not round then return n end
 for _,r in round.records do local p=r.player local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if r.team=="Innocents" and p.Parent==Players and p:GetAttribute("InRound") and h and h.Health>0 then n+=1 end end return n
end
function S.Task(p,id)
 local r=round and round.records[p.UserId]
 if not r or r.team~="Innocents" or r.done[id] or not p:GetAttribute("InRound") then return false end
 r.done[id]=true r.tasks+=1 p:SetAttribute("RoundTasks",r.tasks) return true
end
function S.Finish(winner)
 if not round then return false end
 local completed=round round=nil
 if not winner then return true end
 for id,r in completed.records do
 local amount,parts,won=Math.Reward(r,winner)
 pending[id]=pending[id] or {} table.insert(pending[id],{receipt=completed.id,amount=amount,parts=parts,won=won,winner=winner,vipApplied=false})
 task.spawn(flush,id)
 end return true
end
for _,p in Players:GetPlayers() do task.spawn(load,p) end
Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(p)
 local r=round and round.records[p.UserId] if r then r.left=true end
 task.spawn(flush,p.UserId)
end)
task.spawn(function() while true do task.wait(20) for id in pending do task.spawn(flush,id) end end end)
game:BindToClose(function()
 for id in pending do task.spawn(flush,id) end
 local untilTime=os.clock()+25
 repeat
 local remaining=false for _,q in pending do if #q>0 then remaining=true end end
 if not remaining then break end task.wait(.2)
 until os.clock()>untilTime
end)
return S