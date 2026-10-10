if not game:GetService("RunService"):IsStudio() then return end
local config=workspace:WaitForChild("MaskSystem")
local player=game.Players.LocalPlayer
local running=false
local function test()
 if running or config:GetAttribute("TestFireFlare")~=1 then return end running=true
 print("FLARE TEST: client request observed")
 local deadline=os.clock()+12 local tool
 repeat local c=player.Character tool=c and c:FindFirstChild("Emergency Flare") if tool and tool:FindFirstChild("Handle") and tool:GetAttribute("FlareInputReady") then break end task.wait(.1) until os.clock()>deadline
 if not tool then warn("FLARE TEST: no local equipped tool") return end
 print("FLARE TEST: activating",tool.Parent,tool.Enabled,tool.RequiresHandle,tool:GetAttribute("FlareInputReady"))
 tool.Activated:Once(function()print("FLARE TEST: Activated observed")end)
 tool:Activate()
end
config:GetAttributeChangedSignal("TestFireFlare"):Connect(test)
task.defer(test)
print("FLARE TEST: client listener ready",config:GetAttribute("TestFireFlare"))