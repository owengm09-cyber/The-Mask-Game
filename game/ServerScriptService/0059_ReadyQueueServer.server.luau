local Progression=require(script.Parent.ProgressionService)
local Rescue=require(script.Parent.ForestRescueService)
local Players=game:GetService("Players")
local TeleportService=game:GetService("TeleportService")
local RunService=game:GetService("RunService")
local LOBBY_PLACE_ID=73347091467818
local lobbyArrivals={}
local lobbyArrivalFirstAt=nil
local lobbyExpected=1
local Core=require(script.Parent:WaitForChild("ReadyQueueCore"))
local Mask=require(script.Parent:WaitForChild("MaskService"))
-- Finishing both task lists starts the escape van; the round ends when it leaves (or nobody's left to escape).
local Van=require(script.Parent:WaitForChild("EscapeVanService"))
-- Before each round everyone gets PICK_SECONDS to pick their camper (the "Your Camper" card opens by itself:
-- player attribute PickingCamper, MaskSystem.PickEndsAt). Then they're placed at their spawn points and play a
-- short intro (RoundIntroClient): a look round the spawn, then the camera pushes into first person.
local PICK_SECONDS=15
local INTRO_SECONDS=8
local TweenService=game:GetService("TweenService")
local picking=nil
local remotesFolder=game.ReplicatedStorage:WaitForChild("Remotes")
local introRemote=remotesFolder:FindFirstChild("RoundIntro") or Instance.new("RemoteEvent")
introRemote.Name="RoundIntro" introRemote.Parent=remotesFolder
-- the camper looks left, then right, then straight ahead (neck and waist; everyone sees it). Times match the
-- close-up shot in RoundIntroClient.
local function lookAround(char)
 local head=char:FindFirstChild("Head") local neck=head and head:FindFirstChild("Neck")
 local ut=char:FindFirstChild("UpperTorso") local waist=ut and ut:FindFirstChild("Waist")
 if not (neck and neck:IsA("Motor6D")) then return end
 local nBase=neck:GetAttribute("RestC0") or neck.C0 neck:SetAttribute("RestC0",nBase)
 local wBase=waist and waist:IsA("Motor6D") and (waist:GetAttribute("RestC0") or waist.C0) or nil
 if wBase then waist:SetAttribute("RestC0",wBase) end
 local function turn(yaw,pitch,t)
  if not neck.Parent then return end
  TweenService:Create(neck,TweenInfo.new(t,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{C0=nBase*CFrame.Angles(math.rad(pitch),math.rad(yaw),0)}):Play()
  if wBase and waist.Parent then TweenService:Create(waist,TweenInfo.new(t*1.1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{C0=wBase*CFrame.Angles(0,math.rad(yaw*0.3),0)}):Play() end
 end
 for _,step in {{2.7,52,-4,0.75},{3.9,-50,2,1.0},{5.2,0,6,0.55},{5.9,0,0,0.4}} do
  task.delay(step[1],function() turn(step[2],step[3],step[4]) end)
 end
end
local config=workspace:WaitForChild("MaskSystem")
-- In-place ready zones are optional: players arrive from the lobby experience and rounds start automatically.
local lobbyModel=workspace:FindFirstChild("Lobby")
local zones=lobbyModel and lobbyModel:FindFirstChild("ReadyZones")
local spawnFolder=workspace:WaitForChild("SpawnPoints")
local lobbySpawn=spawnFolder:WaitForChild("Spawn_01") -- Main experience arrivals and respawns stay in the forest.
local active=nil
local serial=0
local states={}
local nextAttempt=0
local function alive(p)
 local c=p.Character
 local h=c and c:FindFirstChildOfClass("Humanoid")
 local r=c and c:FindFirstChild("HumanoidRootPart")
 if p.Parent==Players and h and h.Health>0 and r then return c,h,r end
end
local function inside(zone,p)
 local c,h,r=alive(p)
 if not c or p:GetAttribute("InRound") then return false end
 local v=zone.Trigger.CFrame:PointToObjectSpace(r.Position)
 return math.abs(v.Y)<=zone.Trigger.Size.Y/2 and Vector2.new(v.X,v.Z).Magnitude<=zone:GetAttribute("Radius")
end
local function clearMembership(p)
 p:SetAttribute("ReadyZone",nil)
end
local function endRound(winner)
 if not active then return end
 local previous=active active=nil
 config:SetAttribute("LastRoundWinner",winner)
 Rescue.End()
 Progression.Finish(winner)
 config:SetAttribute("MatchActive",false)
 config:SetAttribute("RoundEndsAt",nil)
 config:SetAttribute("RoundState","Lobby")
 Mask.ResetRound()
 for _,p in previous.players do
  if p.Parent==Players then
   p:SetAttribute("InRound",false) p:SetAttribute("RoundId",nil) clearMembership(p)
   local c,h,r=alive(p)
   if c then
    h.Sit=false c:PivotTo(lobbySpawn.CFrame*CFrame.new(0,4,0))
    r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero
   end
  end
 end
 local returning={}
 for _,p in previous.players do if p.Parent==Players then table.insert(returning,p) end end
 if #returning>0 and not RunService:IsStudio() then
  task.spawn(function()
   while not Progression.WaitForSaves(returning,20) do
    warn("Return to lobby delayed: XP is still saving; retrying.")
    local connected={}
    for _,player in returning do if player.Parent==Players then table.insert(connected,player) end end
    returning=connected
    if #returning==0 then return end
   end
   local connected={}
   for _,player in returning do if player.Parent==Players then table.insert(connected,player) end end
   returning=connected
   if #returning==0 then return end
   local options=Instance.new("TeleportOptions")
   options:SetTeleportData(require(script.Parent.ForestProgressTransfer).Build(returning))
   local ok,err=pcall(function() TeleportService:TeleportAsync(LOBBY_PLACE_ID,returning,options) end)
   if not ok then warn("Return to lobby failed: "..tostring(err)) end
  end)
 end
end
local function begin(batch)
 if active or #batch<1 then return false end
 local points={}
 for _,v in spawnFolder:GetChildren() do if v:IsA("BasePart") then table.insert(points,v) end end
 table.sort(points,function(a,b) return a.Name<b.Name end)
 if #points<#batch then warn("Ready zones need at least "..#batch.." forest spawn points.") return false end
 local characters={}
 for _,p in batch do local c,h,r=alive(p) if not c then return false end table.insert(characters,{c=c,h=h,r=r,old=c:GetPivot()}) end
 serial+=1
 active={players=table.clone(batch),id=serial}
 config:SetAttribute("MatchActive",true)
 config:SetAttribute("RoundState","Playing")
 config:SetAttribute("RoundId",serial)
 config:SetAttribute("RoundEndsAt",nil)
 local ok,err=pcall(function()
  Mask.ResetRound()
  for i,p in batch do
   local a=characters[i]
   p:SetAttribute("InRound",true) p:SetAttribute("RoundId",serial) p:SetAttribute("Role","Survivor") clearMembership(p)
   a.h.Sit=false
   -- stand them right on the spawn pad (feet on the top), so nobody hangs in the air during the intro
   local stand=a.h.HipHeight+a.r.Size.Y/2+0.05
   a.c:PivotTo(points[i].CFrame*CFrame.new(0,points[i].Size.Y/2+stand,0))
   a.r.AssemblyLinearVelocity=Vector3.zero a.r.AssemblyAngularVelocity=Vector3.zero
   local ff=Instance.new("ForceField") ff.Name="RoundArrivalProtection" ff.Visible=false ff.Parent=a.c -- no sparkles over the intro
   game:GetService("Debris"):AddItem(ff,INTRO_SECONDS+3)
  end
  Progression.Begin(batch)
  Rescue.Begin()
  Mask.Spawn()
 end)
 if not ok then
  warn("Round start failed: "..tostring(err))
  for i,p in batch do if characters[i].c.Parent then characters[i].c:PivotTo(characters[i].old) end p:SetAttribute("InRound",false) end
  endRound() return false
 end
 -- everyone's intro: the camera work runs on each player's machine, the looking round runs here
 for i,p in batch do
  introRemote:FireClient(p,{seconds=INTRO_SECONDS,spawn=points[i].CFrame})
  task.spawn(lookAround,characters[i].c)
 end
 return true
end
-- a group ready to play: first the camper picker, then (in the main loop) begin()
local function launch(batch)
 if active or picking or #batch<1 then return false end
 picking={batch=table.clone(batch),endsAt=workspace:GetServerTimeNow()+PICK_SECONDS}
 config:SetAttribute("RoundState","Picking")
 config:SetAttribute("PickEndsAt",picking.endsAt)
 for _,p in batch do p:SetAttribute("PickGroup",serial+1) p:SetAttribute("PickingCamper",true) end
 return true
end
local function setup(p)
 p:SetAttribute("InRound",false) p:SetAttribute("RoundId",nil) clearMembership(p)
 p.RespawnLocation=lobbySpawn
 local ok,joinData=pcall(function() return p:GetJoinData() end)
 if ok and type(joinData)=="table" and joinData.SourcePlaceId==LOBBY_PLACE_ID then
  lobbyArrivals[p]=true
  lobbyArrivalFirstAt=lobbyArrivalFirstAt or workspace:GetServerTimeNow()
  local data=joinData.TeleportData
  if type(data)=="table" and data.Mode=="LobbyQueue" then lobbyExpected=math.clamp(tonumber(data.Expected) or 1,1,11) end
 end
 -- Direct joins and Studio tests enter the forest without a second lobby queue.
 if not lobbyArrivals[p] then
  lobbyArrivals[p]=true
  lobbyArrivalFirstAt=lobbyArrivalFirstAt or workspace:GetServerTimeNow()
 end
 local function characterAdded(c)
  p:SetAttribute("InRound",false) p:SetAttribute("RoundId",nil) clearMembership(p)
  local h=c:WaitForChild("Humanoid",10)
  if h then h.Died:Connect(function()
   p:SetAttribute("InRound",false) clearMembership(p)
  end) end
 end
 p.CharacterAdded:Connect(characterAdded)
 if p.Character then task.spawn(characterAdded,p.Character) end
end
for _,p in Players:GetPlayers() do setup(p) end
Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(function(p) clearMembership(p); lobbyArrivals[p]=nil end)
config:SetAttribute("MatchActive",false)
config:SetAttribute("RoundState","Lobby")
Mask.ResetRound()
if zones then for _,zone in zones:GetChildren() do states[zone]=Core.new() end end
local lastTick=workspace:GetServerTimeNow()
while true do
 local now=workspace:GetServerTimeNow()
 local delta=now-lastTick lastTick=now
 if picking and now>=picking.endsAt then
  local list={}
  for _,p in picking.batch do
   if p.Parent==Players then p:SetAttribute("PickingCamper",nil) p:SetAttribute("PickGroup",nil) if alive(p) then table.insert(list,p) end end
  end
  picking=nil
  config:SetAttribute("PickEndsAt",nil)
  if #list==0 or not begin(list) then config:SetAttribute("RoundState","Lobby") end
 end
 if active then
  local survivors=0
  for _,p in active.players do if p:GetAttribute("InRound") and alive(p) then survivors+=1 end end
  config:SetAttribute("RoundPlayersRemaining",survivors)
  if config:GetAttribute("MeetingActive")~=true then Progression.Tick(delta) end
  local outcome=Van.Outcome()
  if outcome then endRound(outcome) elseif Progression.InnocentsAlive()==0 then endRound(Van.AnyEscaped() and "Innocents" or "Monster") end
 end
 if not active and not picking and lobbyArrivalFirstAt then
  local batch={}
  for p in pairs(lobbyArrivals) do if alive(p) then table.insert(batch,p) end end
  table.sort(batch,function(a,b) return a.UserId<b.UserId end)
  if #batch>0 and (#batch>=lobbyExpected or now-lobbyArrivalFirstAt>=12) then
   if launch(batch) then lobbyArrivals={}; lobbyArrivalFirstAt=nil; lobbyExpected=1 else lobbyArrivalFirstAt=now-9 end
  elseif now-lobbyArrivalFirstAt>35 then lobbyArrivals={}; lobbyArrivalFirstAt=nil; lobbyExpected=1 end
 end
 local used={}
 for _,p in Players:GetPlayers() do clearMembership(p) end
 local ordered=zones and zones:GetChildren() or {} table.sort(ordered,function(a,b) return a.Name<b.Name end)
 for _,zone in ordered do
  local candidates={}
  for _,p in Players:GetPlayers() do if not used[p] and inside(zone,p) then table.insert(candidates,p) end end
  table.sort(candidates,function(a,b) return a.UserId<b.UserId end)
  local busy=active~=nil or picking~=nil or lobbyArrivalFirstAt~=nil or now<nextAttempt
  local cap=zone:GetAttribute("Capacity") or 6
   local count,remaining,batch=Core.step(states[zone],candidates,now,busy,cap)
  for _,p in states[zone].members do used[p]=true p:SetAttribute("ReadyZone",zone.Name) end
  zone:SetAttribute("Count",count) zone:SetAttribute("Countdown",remaining)
  local status=busy and "Forest occupied • waiting" or (remaining and ("Starting in "..remaining.."s") or "Step inside to ready up")
  zone.Display.BillboardGui.Count.Text=tostring(count).."/"..cap
  zone.Display.BillboardGui.Status.Text=status
  zone:SetAttribute("Status",status)
  if batch then
   if launch(batch) then
    zone:SetAttribute("Count",0) zone:SetAttribute("Countdown",nil)
    zone.Display.BillboardGui.Count.Text="0/"..cap
    zone.Display.BillboardGui.Status.Text="Group sent to the forest"
   else nextAttempt=now+5 end
  end
 end
 task.wait(.2)
end