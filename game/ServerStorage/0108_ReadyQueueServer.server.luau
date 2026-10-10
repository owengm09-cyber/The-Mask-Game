local Players=game:GetService("Players")
local Core=require(script.Parent:WaitForChild("ReadyQueueCore"))
local Mask=require(script.Parent:WaitForChild("MaskService"))
local config=workspace:WaitForChild("MaskSystem")
local zones=workspace.Lobby:WaitForChild("ReadyZones")
local spawnFolder=workspace:WaitForChild("SpawnPoints")
local lobbySpawn=workspace.Lobby:WaitForChild("LobbySpawn")
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
local function endRound()
 if not active then return end
 local previous=active active=nil
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
end
local function launch(batch)
 if active or #batch~=6 then return false end
 local points={}
 for _,v in spawnFolder:GetChildren() do if v:IsA("BasePart") then table.insert(points,v) end end
 table.sort(points,function(a,b) return a.Name<b.Name end)
 if #points<6 then warn("Ready zones need at least six forest spawn points.") return false end
 local characters={}
 for _,p in batch do local c,h,r=alive(p) if not c then return false end table.insert(characters,{c=c,h=h,r=r,old=c:GetPivot()}) end
 serial+=1
 active={players=table.clone(batch),endsAt=workspace:GetServerTimeNow()+math.max(30,config:GetAttribute("RoundDuration") or 300),id=serial}
 config:SetAttribute("MatchActive",true)
 config:SetAttribute("RoundState","Playing")
 config:SetAttribute("RoundId",serial)
 config:SetAttribute("RoundEndsAt",active.endsAt)
 local ok,err=pcall(function()
  Mask.ResetRound()
  for i,p in batch do
   local a=characters[i]
   p:SetAttribute("InRound",true) p:SetAttribute("RoundId",serial) p:SetAttribute("Role","Survivor") clearMembership(p)
   a.h.Sit=false
   a.c:PivotTo(points[i].CFrame*CFrame.new(0,points[i].Size.Y/2+4,0))
   a.r.AssemblyLinearVelocity=Vector3.zero a.r.AssemblyAngularVelocity=Vector3.zero
   local ff=Instance.new("ForceField") ff.Name="RoundArrivalProtection" ff.Parent=a.c
   game:GetService("Debris"):AddItem(ff,3)
  end
  Mask.Spawn()
 end)
 if not ok then
  warn("Round start failed: "..tostring(err))
  for i,p in batch do if characters[i].c.Parent then characters[i].c:PivotTo(characters[i].old) end p:SetAttribute("InRound",false) end
  endRound() return false
 end
 return true
end
local function setup(p)
 p:SetAttribute("InRound",false) p:SetAttribute("RoundId",nil) clearMembership(p)
 p.RespawnLocation=lobbySpawn
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
Players.PlayerRemoving:Connect(clearMembership)
config:SetAttribute("MatchActive",false)
config:SetAttribute("RoundState","Lobby")
Mask.ResetRound()
for _,zone in zones:GetChildren() do states[zone]=Core.new() end
while true do
 local now=workspace:GetServerTimeNow()
 if active then
  local survivors=0
  for _,p in active.players do if p:GetAttribute("InRound") and alive(p) then survivors+=1 end end
  config:SetAttribute("RoundPlayersRemaining",survivors)
  if survivors==0 or now>=active.endsAt then endRound() end
 end
 local used={}
 for _,p in Players:GetPlayers() do clearMembership(p) end
 local ordered=zones:GetChildren() table.sort(ordered,function(a,b) return a.Name<b.Name end)
 for _,zone in ordered do
  local candidates={}
  for _,p in Players:GetPlayers() do if not used[p] and inside(zone,p) then table.insert(candidates,p) end end
  table.sort(candidates,function(a,b) return a.UserId<b.UserId end)
  local busy=active~=nil or now<nextAttempt
  local count,remaining,batch=Core.step(states[zone],candidates,now,busy)
  for _,p in states[zone].members do used[p]=true p:SetAttribute("ReadyZone",zone.Name) end
  zone:SetAttribute("Count",count) zone:SetAttribute("Countdown",remaining)
  local status=busy and "Forest occupied • waiting" or (remaining and ("Starting in "..remaining.."s") or "Step inside to ready up")
  zone.Display.BillboardGui.Count.Text=tostring(count).."/6"
  zone.Display.BillboardGui.Status.Text=status
  zone:SetAttribute("Status",status)
  if batch then
   if launch(batch) then
    zone:SetAttribute("Count",0) zone:SetAttribute("Countdown",nil)
    zone.Display.BillboardGui.Count.Text="0/6"
    zone.Display.BillboardGui.Status.Text="Group sent to the forest"
   else nextAttempt=now+5 end
  end
 end
 task.wait(.2)
end