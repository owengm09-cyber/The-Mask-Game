-- Server owns travel, proximity checks, and the cooldown clock.
local V = {}
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Mask = require(script.Parent.MaskService)
local cfg = workspace:WaitForChild("MaskSystem")
local vents = workspace:WaitForChild("Vents")
local remote = RS:WaitForChild("Remotes"):WaitForChild("KillerVent")
local active, ready, throttled = {}, {}, {}
local started = false
local DURATION, COOLDOWN, RANGE = 2, 30, 12
local function now() return workspace:GetServerTimeNow() end
local function body(p)
 local c = p.Character
 local h = c and c:FindFirstChildOfClass("Humanoid")
 local r = c and c:FindFirstChild("HumanoidRootPart")
 if h and h.Health > 0 and r then return c,h,r end
end
local function allowed(p)
 return p.Parent == Players and p:GetAttribute("Role") == "Killer"
  and Mask.GetHolder() == p and p:GetAttribute("InRound") == true
  and cfg:GetAttribute("MatchActive") == true and cfg:GetAttribute("MeetingActive") ~= true
  and Lighting:GetAttribute("Phase") == "Night"
end
local function vent(id)
 if type(id) ~= "number" or id ~= id then return end
 for _,m in vents:GetChildren() do
  if m:IsA("Model") and m:GetAttribute("VentId") == id then return m end
 end
end
local function landing(m,h,r)
 local pos = m:GetPivot().Position
 local ray = RaycastParams.new()
 ray.FilterType = Enum.RaycastFilterType.Include
 ray.FilterDescendantsInstances = {workspace.Terrain}
 local hit = workspace:Raycast(pos+Vector3.new(0,15,0),Vector3.new(0,-60,0),ray)
 if not hit or hit.Material == Enum.Material.Water then return end
 local at = hit.Position + Vector3.new(0,h.HipHeight+r.Size.Y/2+.2,0)
 if Mask.IsSafe(at) then return end
 local look = m:GetPivot().LookVector * Vector3.new(1,0,1)
 return CFrame.lookAt(at,at+(look.Magnitude>.01 and look.Unit or Vector3.zAxis))
end
local function finish(p,success,reason)
 local a = active[p] if not a then return end
 active[p] = nil
 if a.conn then a.conn:Disconnect() end
 if a.root.Parent and p.Character == a.char then
  a.root.CFrame = success and a.exit or a.origin
  a.root.AssemblyLinearVelocity = Vector3.zero
  a.root.AssemblyAngularVelocity = Vector3.zero
  a.root.Anchored = a.anchored
  if not a.anchored then pcall(function() a.root:SetNetworkOwnershipAuto() end) end
  a.hum.AutoRotate = a.rotate
 end
 for o,t in a.hidden do if o.Parent then o.Transparency = t end end
 a.char:SetAttribute("Venting",false)
 p:SetAttribute("Venting",false)
 if p.Parent == Players then remote:FireClient(p,"End",{ok=success,reason=reason}) end
end
function V.CancelAll(reason)
 local pending={} for p in active do table.insert(pending,p) end
 for _,p in pending do finish(p,false,reason or "Travel interrupted") end
end
function V.Travel(p,fromId,toId)
 if not allowed(p) then return false,"Only the nighttime killer can tunnel" end
 if active[p] then return false,"Already tunneling" end
 if now() < (ready[p] or 0) then return false,"Tunnel is recharging" end
 local c,h,r = body(p) if not c or r.Anchored then return false,"Cannot tunnel now" end
 if now()-(c:GetAttribute("CreatureKillAt") or -100)<1.8 then return false,"Finish the kill first" end
 local from,to = vent(fromId),vent(toId)
 if not from or not to or from == to then return false,"Choose another entrance" end
 if (r.Position-from:GetPivot().Position).Magnitude>RANGE then return false,"Move closer to the entrance" end
 if Mask.IsSafe(r.Position) then return false,"Cannot tunnel from a safe zone" end
 local exit = landing(to,h,r) if not exit then return false,"Exit is unavailable" end
 local begin = now()
 local a = {char=c,hum=h,root=r,origin=r.CFrame,exit=exit,anchored=r.Anchored,rotate=h.AutoRotate,hidden={},start=begin}
 active[p] = a
 ready[p] = begin+DURATION+COOLDOWN
 p:SetAttribute("VentReadyAt",ready[p])
 p:SetAttribute("Venting",true) c:SetAttribute("Venting",true)
 r.Anchored = true h.AutoRotate = false h:UnequipTools()
 remote:FireClient(p,"Begin",{start=begin,duration=DURATION,readyAt=ready[p],region=to:GetAttribute("Region"),destination=toId})
 a.conn = Run.Heartbeat:Connect(function()
  if p.Character~=c or h.Health<=0 or not allowed(p) then finish(p,false,"Travel interrupted") return end
  local age=now()-begin
  if age>=DURATION then finish(p,true) return end
  if age<.25 then
   r.CFrame=a.origin*CFrame.new(0,-6*(age/.25)^2,0)
  elseif age<1.75 then
   if not a.concealed then
    a.concealed=true
    for _,o in c:GetDescendants() do if o:IsA("BasePart") or o:IsA("Decal") then a.hidden[o]=o.Transparency o.Transparency=1 end end
   end
   r.CFrame=exit*CFrame.new(0,-6,0)
  else
   if a.concealed then for o,t in a.hidden do if o.Parent then o.Transparency=t end end a.concealed=false end
   r.CFrame=exit*CFrame.new(0,-6*(1-(age-1.75)/.25)^2,0)
  end
 end)
 return true
end
function V.Start()
 if started then return end started=true
 local function persist(p)
  for _,m in vents:GetChildren() do if m:IsA("Model") then
   if p:GetAttribute("Role")=="Killer" then m:AddPersistentPlayer(p) else m:RemovePersistentPlayer(p) end
  end end
 end
 local function setup(p)
  p:SetAttribute("Venting",false) p:SetAttribute("VentReadyAt",0)
  p:GetAttributeChangedSignal("Role"):Connect(function() persist(p) if p:GetAttribute("Role")~="Killer" then finish(p,false,"Mask released") end end)
  p.CharacterRemoving:Connect(function() finish(p,false,"Character changed") end)
  persist(p)
 end
 for _,p in Players:GetPlayers() do setup(p) end
 Players.PlayerAdded:Connect(setup)
 Players.PlayerRemoving:Connect(function(p) finish(p,false) ready[p]=nil throttled[p]=nil end)
 cfg:GetAttributeChangedSignal("MatchActive"):Connect(function() if not cfg:GetAttribute("MatchActive") then
  V.CancelAll("Round ended") table.clear(ready)
  for _,p in Players:GetPlayers() do p:SetAttribute("VentReadyAt",0) end
 end end)
 remote.OnServerEvent:Connect(function(p,fromId,toId)
  local t=now() if t-(throttled[p] or 0)<.25 then return end throttled[p]=t
  local ok,why=V.Travel(p,fromId,toId)
  if not ok then remote:FireClient(p,"Denied",{reason=why}) end
 end)
end
return V
