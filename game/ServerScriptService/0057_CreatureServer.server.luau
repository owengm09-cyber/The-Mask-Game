-- Authoritative nighttime killer service. Respects the existing mask and safe zones.
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local Storage=game:GetService("ServerStorage")
local Tags=game:GetService("CollectionService")
local Pathfinding=game:GetService("PathfindingService")
local Rig=require(game.ReplicatedStorage:WaitForChild("CreatureRig"))
local Mask=require(script.Parent:WaitForChild("MaskService"))
local config=workspace:WaitForChild("MaskSystem")
local rng=Random.new()
local transformed={}
local npc, npcHumanoid, npcRoot
local points,pointIndex,goal,lastPath,patrolGoal=nil,1,nil,0,nil
local lastPosition,stuckAt
local function number(name,fallback)
 local value=config:GetAttribute(name)
 return type(value)=="number" and value or fallback
end
local function night()
 local phase=Lighting:GetAttribute("Phase")
 if phase~=nil then return phase=="Night" end
 return Lighting.ClockTime>=18 or Lighting.ClockTime<6
end
local function visibleTarget(character)
 local player=character and Players:GetPlayerFromCharacter(character)
 if player and not player:GetAttribute("InRound") then return end
 local h=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if h and h.Health>0 and root and not character:FindFirstChildOfClass("ForceField") and not Mask.IsSafe(root.Position) then return h,root end
end
local function attach(character)
 local root=character:FindFirstChild("HumanoidRootPart")
 local h=character:FindFirstChildOfClass("Humanoid")
 if not root or not h then return nil end
 local m=Storage:WaitForChild("HarlequinTemplate"):Clone()
 m.Name="MaskCreature"
 for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=false end end
 m:PivotTo(root.CFrame)
 m.Parent=character
 local weld=Instance.new("WeldConstraint") weld.Name="CreatureAttachment" weld.Part0=root weld.Part1=m.PrimaryPart weld.Parent=m.PrimaryPart
 Tags:AddTag(m,"MaskCreature")
 return m
end
local function untransform(p)
 local data=transformed[p]
 if not data then return end
 transformed[p]=nil
 if data.connection then data.connection:Disconnect() end
 if data.model then Tags:RemoveTag(data.model,"MaskCreature") data.model:Destroy() end
 for object,value in pairs(data.hidden) do if object.Parent then object.Transparency=value end end
 local h=data.humanoid
 if h and h.Parent then h.WalkSpeed=data.speed h.CameraOffset=data.camera h.DisplayDistanceType=data.display end
 if data.character and data.character.Parent then
  data.character:SetAttribute("CreatureKillAt",nil) data.character:SetAttribute("CreatureAttackAt",nil)
 end
end
local function transform(p)
 if transformed[p] then return end
 local c=p.Character local h=c and c:FindFirstChildOfClass("Humanoid")
 if not h or h.Health<=0 then return end
 local m=attach(c) if not m then return end
 local data={character=c,humanoid=h,model=m,hidden={},speed=h.WalkSpeed,camera=h.CameraOffset,display=h.DisplayDistanceType}
 transformed[p]=data
 local function hide(o)
  if o:IsDescendantOf(m) then return end
  if o:IsA("BasePart") or o:IsA("Decal") then data.hidden[o]=o.Transparency o.Transparency=1 end
 end
 for _,o in ipairs(c:GetDescendants()) do hide(o) end
 data.connection=c.DescendantAdded:Connect(hide)
 h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 c:SetAttribute("CreatureKillAt",-100) c:SetAttribute("CreatureAttackAt",-100)
end
local function removeNPC()
 if npc then Tags:RemoveTag(npc.MaskCreature,"MaskCreature") npc:Destroy() end
 npc=nil npcHumanoid=nil npcRoot=nil points=nil patrolGoal=nil goal=nil
 config:SetAttribute("NightCreatureActive",false)
end
local function spawnNPC()
 local pos=Mask.FindSpawn()
 if not pos then return false end
 -- Avoid materializing in a survivor's immediate view.
 for _,p in ipairs(Players:GetPlayers()) do
  local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
  if r and (r.Position-pos).Magnitude<50 then return false end
 end
 local m=Instance.new("Model") m.Name="NightHarlequin"
 local r=Instance.new("Part") r.Name="HumanoidRootPart" r.Size=Vector3.new(2.2,2,1.8)
 r.Transparency=1 r.CanCollide=true r.CanTouch=false r.CFrame=CFrame.new(pos+Vector3.new(0,1,0)) r.Parent=m
 local h=Instance.new("Humanoid") h.Name="Humanoid" h.RequiresNeck=false h.BreakJointsOnDeath=false
 h.HipHeight=2 h.MaxHealth=500 h.Health=500 h.WalkSpeed=number("CreaturePatrolSpeed",12)
 h.JumpHeight=5 h.UseJumpPower=false h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None h.Parent=m
 local head=Instance.new("Part") head.Name="Head" head.Transparency=1 head.Size=Vector3.new(1,1,1)
 head.Massless=true head.CanCollide=false head.CanTouch=false head.CFrame=r.CFrame*CFrame.new(0,2,0) head.Parent=m
 local neck=Instance.new("WeldConstraint") neck.Part0=r neck.Part1=head neck.Parent=head
 m.PrimaryPart=r m:SetAttribute("CreatureKillAt",-100) m:SetAttribute("CreatureAttackAt",-100)
 m.Parent=workspace
 local visual=attach(m)
 if not visual then m:Destroy() return false end
 r:SetNetworkOwner(nil)
 npc=m npcHumanoid=h npcRoot=r
 lastPosition=r.Position stuckAt=os.clock() lastPath=0
 config:SetAttribute("NightCreatureActive",true)
 return true
end
local function lineClear(from,to,targetCharacter)
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude
 ray.FilterDescendantsInstances={npc,Mask.Runtime}
 ray.RespectCanCollide=true
 local hit=workspace:Raycast(from,to-from,ray)
 return not hit or (targetCharacter and hit.Instance:IsDescendantOf(targetCharacter))
end
local attackCooldown=0
local function attackNPC(target,targetRoot)
 local now=workspace:GetServerTimeNow()
 if config:GetAttribute("MeetingActive")==true or now<attackCooldown then return end
 if Mask.IsSafe(npcRoot.Position) or not lineClear(npcRoot.Position,targetRoot.Position,target.Parent) then return end
 attackCooldown=now+2.8
 npc:SetAttribute("CreatureAttackAt",now)
 npcHumanoid:MoveTo(npcRoot.Position)
 local thisNPC=npc
 task.delay(.32,function()
  if npc~=thisNPC or not night() or Mask.GetHolder() or config:GetAttribute("MeetingActive")==true then return end
  local h,r=visibleTarget(target.Parent)
  if h~=target or not r or (r.Position-npcRoot.Position).Magnitude>number("CreatureAttackRange",6.5) then return end
  if not lineClear(npcRoot.Position,r.Position,target.Parent) or Mask.IsSafe(npcRoot.Position) then return end
  npc:SetAttribute("CreatureKillAt",workspace:GetServerTimeNow())
  target.Health=0
 end)
end
local function patrol()
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Include ray.FilterDescendantsInstances={workspace.Terrain}
 for _=1,10 do
  local p=npcRoot.Position+Vector3.new(rng:NextNumber(-60,60),80,rng:NextNumber(-60,60))
  local hit=workspace:Raycast(p,Vector3.new(0,-200,0),ray)
  if hit and hit.Normal.Y>.7 and hit.Material~=Enum.Material.Water and not Mask.IsSafe(hit.Position) then return hit.Position end
 end
end
local function navigate(destination)
 local now=os.clock()
 if not goal or (destination-goal).Magnitude>9 or not points or now-lastPath>2.2 then
  if now-lastPath<.7 then return end
  lastPath=now goal=destination
  local actor=npc
  local path=Pathfinding:CreatePath({AgentRadius=1.8,AgentHeight=5,AgentCanJump=true,WaypointSpacing=4})
  local ok=pcall(function() path:ComputeAsync(npcRoot.Position,destination) end)
  if npc~=actor then return end
  if ok and path.Status==Enum.PathStatus.Success then points=path:GetWaypoints() pointIndex=2
  else points=nil npcHumanoid:MoveTo(npcRoot.Position) patrolGoal=nil return end
 end
 if points and points[pointIndex] then
  local waypoint=points[pointIndex]
  if Mask.IsSafe(waypoint.Position) then points=nil patrolGoal=nil npcHumanoid:MoveTo(npcRoot.Position) return end
  if (npcRoot.Position-waypoint.Position).Magnitude<4 then pointIndex+=1 waypoint=points[pointIndex] end
  if waypoint then
   if waypoint.Action==Enum.PathWaypointAction.Jump then npcHumanoid.Jump=true end
   npcHumanoid:MoveTo(waypoint.Position)
  else points=nil patrolGoal=nil end
 end
 if lastPosition and (npcRoot.Position-lastPosition).Magnitude>1 then lastPosition=npcRoot.Position stuckAt=now
 elseif stuckAt and now-stuckAt>3 then points=nil patrolGoal=nil npcHumanoid.Jump=true stuckAt=now end
end
Players.PlayerRemoving:Connect(untransform)
local nextSpawn=0
while true do
 local active=night() and config:GetAttribute("MatchActive")==true
 local mode=config:GetAttribute("CreatureControlMode") or "Hybrid"
 local holder=Mask.GetHolder()
 for _,p in ipairs(Players:GetPlayers()) do
  local data=transformed[p]
  local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  local should=active and config:GetAttribute("CreatureEnabled")~=false and mode~="AI" and p==holder and h and h.Health>0
  if data and (not should or data.character~=p.Character) then untransform(p) end
  if should then
   transform(p)
   data=transformed[p]
   if data then
    local recovering=p:GetAttribute("Venting")==true or config:GetAttribute("MeetingActive")==true or workspace:GetServerTimeNow()-(p.Character:GetAttribute("CreatureKillAt") or -100)<1.8
    data.humanoid.WalkSpeed=recovering and 0 or number("CreatureRunSpeed",22)
   end
  end
 end
 local wantsNPC=active and mode~="Player" and not holder and config:GetAttribute("CreatureEnabled")~=false
 if not wantsNPC then if npc then removeNPC() end
 elseif not npc then
  if os.clock()>=nextSpawn then nextSpawn=os.clock()+4 spawnNPC() end
 elseif not npc.Parent or npcHumanoid.Health<=0 then removeNPC() nextSpawn=os.clock()+10
 else
  local recovering=config:GetAttribute("MeetingActive")==true or workspace:GetServerTimeNow()-(npc:GetAttribute("CreatureKillAt") or -100)<1.8
  if recovering then npcHumanoid.WalkSpeed=0 npcHumanoid:MoveTo(npcRoot.Position)
  else
   local target,targetRoot,best=nil,nil,number("CreatureDetectionRange",125)
   for _,p in ipairs(Players:GetPlayers()) do
    local h,r=visibleTarget(p.Character)
    if h and not p:GetAttribute("HasMask") then
     local d=(r.Position-npcRoot.Position).Magnitude
     if d<best and lineClear(npcRoot.Position,r.Position,p.Character) then target=h targetRoot=r best=d end
    end
   end
   if target then
    npcHumanoid.WalkSpeed=number("CreatureRunSpeed",22)
    if best<=number("CreatureAttackRange",6.5) then attackNPC(target,targetRoot)
    else navigate(targetRoot.Position) end
   else
    npcHumanoid.WalkSpeed=number("CreaturePatrolSpeed",12)
    if not patrolGoal or (npcRoot.Position-patrolGoal).Magnitude<6 then patrolGoal=patrol() end
    if patrolGoal then navigate(patrolGoal) end
   end
  end
 end
 task.wait(.2)
end
