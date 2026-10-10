if not game:GetService("RunService"):IsStudio() then return end
local p=game.Players.LocalPlayer;local character=p.Character or p.CharacterAdded:Wait();task.wait(4)
local m=workspace:WaitForChild("Lobby"):WaitForChild("ZoltarFortuneMachine")
local o=m.PrimaryPart.CFrame*CFrame.new(0,-.16,0)
local cam=workspace.CurrentCamera;cam.CameraType=Enum.CameraType.Scriptable
cam.CFrame=CFrame.lookAt(o:PointToWorldSpace(Vector3.new(0,8,-16)),o:PointToWorldSpace(Vector3.new(0,7.5,0)))
for _,v in p.Character:GetDescendants() do if v:IsA("BasePart") then v.LocalTransparencyModifier=1 end end
print("ZF_CAMERA_READY")
