local C={}
function C.Start(machine)
 local TweenService=game:GetService("TweenService")
 local jaw=machine.FortuneTeller.PuppetJaw
 local closed=jaw:GetPivot()
 local prompt=machine.ControlsAndCardSlot.CoinMechanismBlackPlate.ConsultZoltar
 local busy=false
 local function move(pose,seconds)
  local value=Instance.new("CFrameValue");value.Value=jaw:GetPivot()
  local connection=value.Changed:Connect(function(cf) if jaw.Parent then jaw:PivotTo(cf) end end)
  local tween=TweenService:Create(value,TweenInfo.new(seconds,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Value=pose})
  tween:Play();tween.Completed:Wait();connection:Disconnect();value:Destroy()
 end
 local function trigger(player)
  if busy or not machine.Parent then return false end
  if player then local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart");if not root or (root.Position-prompt.Parent.Position).Magnitude>12 then return false end end
  busy=true;prompt.Enabled=false;machine:SetAttribute("Awake",true)
  local light=machine.GlassBooth.AmethystCrystalBall.CrystalGlow
  local normal=light.Brightness
  task.spawn(function()
   local ok,err=xpcall(function()
    TweenService:Create(light,TweenInfo.new(.5),{Brightness=1.6}):Play()
    for _,duration in ipairs({.23,.32,.19,.37,.25}) do
     move(closed*CFrame.Angles(math.rad(22),0,0),duration)
     move(closed,duration*.9)
    end
   end,debug.traceback)
   if jaw.Parent then jaw:PivotTo(closed) end
   if light.Parent then TweenService:Create(light,TweenInfo.new(.7),{Brightness=normal}):Play() end
   machine:SetAttribute("Awake",false);machine:SetAttribute("InteractionCount",(machine:GetAttribute("InteractionCount") or 0)+1)
   prompt.Enabled=true;busy=false
   if not ok then warn("Zoltar interaction: "..tostring(err)) end
  end)
  return true
 end
 prompt.Triggered:Connect(trigger)
 return {Trigger=trigger,ClosedJaw=closed}
end
return C
