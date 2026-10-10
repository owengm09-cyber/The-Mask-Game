local seat=script.Parent.SwingSeat
local prompt=seat.ProximityPrompt
local lastPush=0
seat:SetNetworkOwner(nil)
prompt.Triggered:Connect(function(player)
 local character=player.Character
 local h=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not h or h.Health<=0 or not root or (root.Position-seat.Position).Magnitude>12 then return end
 if seat.Occupant and seat.Occupant~=h then return end
 if os.clock()-lastPush<2 then return end
 lastPush=os.clock()
 seat:Sit(h)
 task.delay(.25,function()
  if seat.Parent and seat.Occupant==h then
   seat:ApplyImpulse(Vector3.new(0,0,seat.AssemblyMass*5))
  end
 end)
end)
