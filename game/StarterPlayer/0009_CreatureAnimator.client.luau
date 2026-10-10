local Players=game:GetService("Players")
local Tags=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local Rig=require(game:GetService("ReplicatedStorage"):WaitForChild("CreatureRig"))
local player=Players.LocalPlayer
local tracked={}
local pending={}
local function add(m)
 if tracked[m] or pending[m] then return end
 pending[m]=true
 task.spawn(function()
  local context=Rig.Bind(m)
  pending[m]=nil
  if context and m:IsDescendantOf(workspace) then tracked[m]={ctx=context,blend=0} end
 end)
end
for _,m in ipairs(Tags:GetTagged("MaskCreature")) do add(m) end
Tags:GetInstanceAddedSignal("MaskCreature"):Connect(add)
Tags:GetInstanceRemovedSignal("MaskCreature"):Connect(function(m) tracked[m]=nil end)
local ownHumanoid,oldCameraOffset,oldMinZoom
local function restoreCamera()
 if ownHumanoid and ownHumanoid.Parent then ownHumanoid.CameraOffset=oldCameraOffset end
 if oldMinZoom then player.CameraMinZoomDistance=oldMinZoom end
 ownHumanoid=nil oldCameraOffset=nil oldMinZoom=nil
end
local elapsed=0
RunService.PreSimulation:Connect(function(dt)
 elapsed+=dt
 if elapsed<1/30 then return end
 dt=elapsed elapsed=0
 local now=workspace:GetServerTimeNow()
 local owns=false
 for m,data in pairs(tracked) do
  if not m:IsDescendantOf(workspace) then tracked[m]=nil continue end
  local root=data.ctx.root
  local owner=m.Parent
  local physical=owner and owner:FindFirstChild("HumanoidRootPart")
  if not physical then continue end
  local velocity=physical.AssemblyLinearVelocity
  local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
  local killAt=owner:GetAttribute("CreatureKillAt") or -100
  local attackAt=owner:GetAttribute("CreatureAttackAt") or -100
  local target=speed>1.5 and 1 or 0
  if now-killAt<1.8 then target=0 end
  data.blend+=(target-data.blend)*(1-math.exp(-dt*8))
  local camera=workspace.CurrentCamera
  if not camera or (camera.CFrame.Position-physical.Position).Magnitude<260 then
   Rig.Pose(data.ctx,now,data.blend,now-attackAt,now-killAt)
  end
  if owner==player.Character then
   owns=true
   local h=owner:FindFirstChildOfClass("Humanoid")
   if h then
    if ownHumanoid~=h then
     restoreCamera() ownHumanoid=h oldCameraOffset=h.CameraOffset oldMinZoom=player.CameraMinZoomDistance
     -- Preserve optional first person and player-controlled zoom.
    end
    h.CameraOffset=oldCameraOffset+Vector3.new(0,2.5*(1-data.blend),0)
   end
  end
 end
 if not owns and ownHumanoid then restoreCamera() end
end)
