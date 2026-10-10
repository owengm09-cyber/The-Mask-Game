local tool=script.Parent
print("FLARE CLIENT: boot",tool:GetFullName())
local remote=game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FireMeetingFlare")
local last=-100
tool.Activated:Connect(function()
 if os.clock()-last<.3 then return end last=os.clock()
 print("FLARE CLIENT: forwarding activation") remote:FireServer()
end)
tool:SetAttribute("FlareInputReady",true)
print("FLARE CLIENT: input ready")