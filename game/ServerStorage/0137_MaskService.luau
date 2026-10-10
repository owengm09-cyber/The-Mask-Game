local Players = game:GetService("Players")
local Storage = game:GetService("ServerStorage")
local Tags = game:GetService("CollectionService")
local S = {}
local rng = Random.new()
local holder, pickup, prompt, deathConnection
local generation = 0
local lastAttack = {}
local previousRoles = {}
local config = workspace:WaitForChild("MaskSystem")
local runtime = Instance.new("Folder")
runtime.Name = "MaskRuntime"
runtime.Parent = workspace
S.Runtime = runtime
local function number(name, fallback) return config:GetAttribute(name) or fallback end
function S.IsSafe(position)
 for _, zone in Tags:GetTagged("MaskSafeZone") do
  if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
   local p = zone.CFrame:PointToObjectSpace(position)
   local half = zone.Size / 2 + Vector3.new(3,3,3)
   if math.abs(p.X)<=half.X and math.abs(p.Y)<=half.Y and math.abs(p.Z)<=half.Z then return true end
  end
 end
 return false
end
local function alive(player)
 local c = player.Character
 local h = c and c:FindFirstChildOfClass("Humanoid")
 local root = c and c:FindFirstChild("HumanoidRootPart")
 if h and h.Health>0 and root then return c,h,root end
end
function S.FindSpawn()
 local radius = number("SpawnRadius",260)
 local ray = RaycastParams.new()
 ray.FilterType = Enum.RaycastFilterType.Include
 ray.FilterDescendantsInstances = {workspace.Terrain}
 local overlap = OverlapParams.new()
 overlap.FilterType = Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances = {runtime,config,workspace:FindFirstChild("Atmospherics")}
 overlap.RespectCanCollide = true
 for _=1,300 do
  local x,z = rng:NextNumber(-radius,radius),rng:NextNumber(-radius,radius)
  local hit = workspace:Raycast(Vector3.new(x,180,z),Vector3.new(0,-400,0),ray)
  if hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > .85 and not S.IsSafe(hit.Position) then
   local pos = hit.Position + Vector3.new(0,2,0)
   if #workspace:GetPartBoundsInBox(CFrame.new(pos),Vector3.new(4,3.5,4),overlap)==0 then return pos end
  end
 end
 return nil
end
local function makeMask()
 local model = Storage:WaitForChild("MaskTemplate"):Clone()
 for _,v in model:GetDescendants() do
  if v:IsA("BasePart") then v.Anchored=true v.CanCollide=false v.CanTouch=false v.Massless=true end
 end
 return model
end
function S.Spawn()
 if config:GetAttribute("MatchActive")~=true then return false end
 if holder or pickup then return false end
 if game:GetService("Lighting"):GetAttribute("Phase")~="Night" then return false end
 local position = S.FindSpawn()
 if not position then warn("Mask: no clear ground outside safe zones; retrying.") return false end
 pickup=makeMask()
 pickup.Name="CursedMask"
 pickup:PivotTo(CFrame.new(position)*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),0))
 pickup.Parent=runtime
 require(script.Parent.ForestRescueService).MaskDropped()
 local core=pickup.PrimaryPart or pickup:FindFirstChildWhichIsA("BasePart",true)
 pickup.PrimaryPart=core
 prompt=Instance.new("ProximityPrompt")
 prompt.ActionText="Wear the mask"
 prompt.ObjectText="THE MASK • Become the killer"
 prompt.HoldDuration=.6
 prompt.MaxActivationDistance=8
 prompt.RequiresLineOfSight=true
 prompt.Parent=core
 local light=Instance.new("PointLight")
 light.Color=Color3.fromRGB(185,210,178) light.Range=12 light.Brightness=1.2 light.Parent=core
 prompt.Triggered:Connect(S.TryPickup)
 config:SetAttribute("MaskState","Waiting")
 return true
end
function S.Release(player)
 if holder~=player then return end
 holder=nil
 generation+=1
 if deathConnection then deathConnection:Disconnect() deathConnection=nil end
 player:SetAttribute("Role",previousRoles[player] or "Survivor")
 player:SetAttribute("HasMask",false)
 previousRoles[player]=nil
 local c=player.Character
 if c then local worn=c:FindFirstChild("WornMask") if worn then worn:Destroy() end end
 for _,container in {player:FindFirstChild("Backpack"),c} do
  if container then for _,v in container:GetChildren() do if v:GetAttribute("MaskWeapon") then v:Destroy() end end end
 end
 config:SetAttribute("KillerUserId",0)
 config:SetAttribute("MaskState","Respawning")
end
function S.TryPickup(player)
 if config:GetAttribute("MeetingActive")==true then return false end
 if not player:GetAttribute("InRound") then return false end
 if config:GetAttribute("CreatureControlMode")=="AI" then return false end
 if holder or not pickup or not prompt or not prompt.Enabled then return false end
 local c,h,root=alive(player)
 if not c or S.IsSafe(root.Position) or S.IsSafe(pickup:GetPivot().Position) then return false end
 local head=c:FindFirstChild("Head")
 if not head or (root.Position-pickup:GetPivot().Position).Magnitude>10 then return false end
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={c,runtime}
 ray.RespectCanCollide=true
 if workspace:Raycast(root.Position,pickup:GetPivot().Position-root.Position,ray) then return false end
 holder=player
 require(script.Parent.ProgressionService).MarkMonster(player)
 prompt.Enabled=false
 previousRoles[player]=player:GetAttribute("Role") or "Survivor"
 player:SetAttribute("Role","Killer") player:SetAttribute("HasMask",true)
 config:SetAttribute("KillerUserId",player.UserId) config:SetAttribute("MaskState","Worn")
 local worn=makeMask() worn.Name="WornMask"
 worn:PivotTo(head.CFrame*CFrame.new(0,0,-head.Size.Z/2-.18))
 worn.Parent=c
 for _,v in worn:GetDescendants() do
  if v:IsA("BasePart") then
   v.Anchored=false
   local weld=Instance.new("WeldConstraint") weld.Part0=head weld.Part1=v weld.Parent=v
  end
 end
 pickup:Destroy() pickup=nil prompt=nil
 local tool=Instance.new("Tool")
 tool.Name="Mask Strike" tool.RequiresHandle=false tool.CanBeDropped=false
 tool.ToolTip="Strike nearby survivors — click / tap / controller trigger"
 tool:SetAttribute("MaskWeapon",true)
 tool.Activated:Connect(function() S.Attack(player) end)
 tool.Parent=player:WaitForChild("Backpack")
 h:EquipTool(tool)
 deathConnection=h.Died:Connect(function() S.Release(player) end)
 return true
end
function S.Attack(player)
 if config:GetAttribute("MeetingActive")==true then return false end
 if not player:GetAttribute("InRound") then return false end
 local lighting=game:GetService("Lighting")
 local phase=lighting:GetAttribute("Phase")
 local isNight=phase and phase=="Night" or (phase==nil and (lighting.ClockTime>=18 or lighting.ClockTime<6))
 if not isNight or config:GetAttribute("CreatureControlMode")=="AI" then return false end
 local character=player.Character
 if character and workspace:GetServerTimeNow()-(character:GetAttribute("CreatureKillAt") or -100)<1.8 then return false end
 if holder~=player then return false end
 local c,h,root=alive(player)
 if not c or S.IsSafe(root.Position) or c:FindFirstChildOfClass("ForceField") then return false end
 local now=os.clock()
 if now-(lastAttack[player] or -math.huge)<number("AttackCooldown",1.2) then return false end
 lastAttack[player]=now
 c:SetAttribute("CreatureAttackAt",workspace:GetServerTimeNow())
 local reach=number("AttackRange",7)
 local target,best
 for _,other in Players:GetPlayers() do
  if other~=player and other:GetAttribute("InRound") then
   local oc,oh,op=alive(other)
   if oc and not S.IsSafe(op.Position) and not oc:FindFirstChildOfClass("ForceField") then
    local delta=op.Position-root.Position local distance=delta.Magnitude
    if distance<=reach and (distance<.1 or root.CFrame.LookVector:Dot(delta.Unit)>.25) and (not best or distance<best) then
     local ray=RaycastParams.new()
     ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={c,runtime}
     ray.RespectCanCollide=true
     local hit=workspace:Raycast(root.Position,delta,ray)
     if not hit or hit.Instance:IsDescendantOf(oc) then target=oh best=distance end
    end
   end
  end
 end
 if target then c:SetAttribute("CreatureKillAt",workspace:GetServerTimeNow()) require(script.Parent.ProgressionService).Kill(player,Players:GetPlayerFromCharacter(target.Parent)) target.Health=0 return true end
 return false
end
function S.ResetRound()
 if holder then S.Release(holder) end
 if pickup then pickup:Destroy() pickup=nil prompt=nil end
 config:SetAttribute("KillerUserId",0)
 config:SetAttribute("MaskState","Waiting")
end
function S.GetHolder() return holder end
function S.GetPickup() return pickup end
function S.Start()
 game:GetService("Lighting"):GetAttributeChangedSignal("Phase"):Connect(function() if game:GetService("Lighting"):GetAttribute("Phase")=="Night" then S.Spawn() end end)
 local function setup(player)
  if player:GetAttribute("Role")==nil then player:SetAttribute("Role","Survivor") end
  player:SetAttribute("HasMask",false)
  player.CharacterRemoving:Connect(function() S.Release(player) end)
 end
 for _,p in Players:GetPlayers() do setup(p) end
 Players.PlayerAdded:Connect(setup)
 Players.PlayerRemoving:Connect(function(p) S.Release(p) previousRoles[p]=nil lastAttack[p]=nil end)
 task.spawn(function()
  while true do
   if not holder and not pickup then S.Spawn() end
   task.wait(number("RespawnDelay",5))
  end
 end)
end
return S