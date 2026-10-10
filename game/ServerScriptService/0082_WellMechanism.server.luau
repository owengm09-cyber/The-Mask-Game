local Tween=game:GetService("TweenService")
local task7=workspace:WaitForChild("ForestRescueTasks"):WaitForChild("Task07")
local task14=workspace.ForestRescueTasks:WaitForChild("Task14")
local lever=task7:WaitForChild("PumpLever")
local rest=lever:GetPivot()
local stream=task7:WaitForChild("WaterStream")
local drops=stream:FindFirstChildWhichIsA("ParticleEmitter",true)
local site=workspace.Forest.RescueSites:WaitForChild("TOWER")
local lens=site:WaitForChild("BeaconLens")
local motion=Instance.new("NumberValue") local generation=0 local activeTween
motion.Changed:Connect(function(a) lever:PivotTo(rest*CFrame.Angles(math.rad(a),0,0)) end)
local function water(on) stream.Transparency=on and .35 or 1 drops.Enabled=on end
local function stroke()
 if activeTween then activeTween:Cancel() end
 generation+=1 local token=generation
 task.spawn(function()
  water(true)
  for i=1,2 do
   if token~=generation then return end
   local a=Tween:Create(motion,TweenInfo.new(.32,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Value=-27}) activeTween=a a:Play() a.Completed:Wait()
   if token~=generation then return end
   local b=Tween:Create(motion,TweenInfo.new(.42,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Value=0}) activeTween=b b:Play() b.Completed:Wait()
  end
  if token==generation then water(task7:GetAttribute("Done")==true) end
 end)
end
task7:GetAttributeChangedSignal("Step"):Connect(function() if (task7:GetAttribute("Step") or 0)>0 then stroke() end end)
task7:GetAttributeChangedSignal("Done"):Connect(function()
 if task7:GetAttribute("Done") then stroke() else generation+=1 if activeTween then activeTween:Cancel() end motion.Value=0 water(false) end
end)
local function beacon()
 local on=task14:GetAttribute("Done")==true
 lens.Color=on and Color3.fromRGB(245,178,62) or Color3.fromRGB(74,45,24)
 lens.Material=on and Enum.Material.Neon or Enum.Material.Glass
 lens.SignalLight.Brightness=on and 2 or 0
end
task14:GetAttributeChangedSignal("Done"):Connect(beacon)
water(task7:GetAttribute("Done")==true) beacon()

-- Task18 (the well winch): the bucket starts at the bottom of the shaft; each good crank hauls it up a third.
local task18=workspace.ForestRescueTasks:WaitForChild("Task18",10)
local well=site:FindFirstChild("RoofedBrickWell")
if task18 and well then
 local bucket=well:WaitForChild("WellBucket")
 local rope=well:WaitForChild("HangingRope")
 local arm,grip=well:WaitForChild("CrankArm"),well:WaitForChild("CrankGrip")
 local axle=well:WaitForChild("WinchAxle")
 local TOP=bucket:GetPivot() local ROPE_TOP=rope.Position.Y+rope.Size.Z/2
 local BOTTOM_Y=-12.75 -- bucket resting just above the water at the bottom
 local armBase,gripBase=arm.CFrame,grip.CFrame
 local pivot=CFrame.new(axle.Position.X+axle.Size.X/2,axle.Position.Y,axle.Position.Z)
 local armRel,gripRel=pivot:ToObjectSpace(armBase),pivot:ToObjectSpace(gripBase)
 local level=Instance.new("NumberValue") -- 0 = bottom of the shaft, 1 = hanging under the winch
 local spin=Instance.new("NumberValue")
 local function place()
  local y=BOTTOM_Y+(TOP.Y-BOTTOM_Y)*level.Value
  bucket:PivotTo(TOP+Vector3.new(0,y-TOP.Y,0))
  local bucketTop=y+0.5
  local len=math.max(0.2,ROPE_TOP-bucketTop)
  rope.Size=Vector3.new(rope.Size.X,rope.Size.Y,len)
  rope.CFrame=CFrame.new(rope.Position.X,ROPE_TOP-len/2,rope.Position.Z)*(rope.CFrame-rope.Position)
 end
 level.Changed:Connect(place)
 spin.Changed:Connect(function(a)
  local turn=pivot*CFrame.Angles(math.rad(a),0,0)
  arm.CFrame=turn*armRel grip.CFrame=turn*gripRel
 end)
 local generation=0
 local function sync(animate)
  generation+=1
  local rounds=task18:GetAttribute("Rounds") or 3
  local goal=task18:GetAttribute("Done") and 1 or math.clamp((task18:GetAttribute("Step") or 0)/rounds,0,1)
  if animate and goal>level.Value then
   Tween:Create(level,TweenInfo.new(1.1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Value=goal}):Play()
   spin.Value=0 Tween:Create(spin,TweenInfo.new(1.1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Value=-720}):Play()
  else level.Value=goal place() end
 end
 task18:GetAttributeChangedSignal("Step"):Connect(function() sync(true) end)
 task18:GetAttributeChangedSignal("Done"):Connect(function() sync(task18:GetAttribute("Done")==true) end)
 sync(false)
end
