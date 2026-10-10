if not game:GetService("RunService"):IsStudio() then return end
local Players=game:GetService("Players")
local function setup(p)
 local c=p.Character or p.CharacterAdded:Wait();local r=c:WaitForChild("HumanoidRootPart");task.wait(3)
 local m=workspace.Lobby.ZoltarFortuneMachine;local o=m.PrimaryPart.CFrame*CFrame.new(0,-.16,0)
 c:PivotTo(o*CFrame.new(0,3,-8)*CFrame.Angles(0,math.pi,0));r.Anchored=true
 print("ZF_PLAY_READY",p.Name,p:GetAttribute("MOINS"),m:GetAttribute("FortunePhase"))
end
Players.PlayerAdded:Connect(setup);for _,p in Players:GetPlayers() do task.spawn(setup,p) end
