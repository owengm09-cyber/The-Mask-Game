script.Parent.Use.OnServerEvent:Connect(function(player, HealAmount)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	local clone = script.Parent.Handle:Clone()
	clone.Parent = workspace
	clone.CanCollide = true
	script.Parent:Destroy()
	humanoid.Health = humanoid.Health + HealAmount
	clone.Used:Play()
	game.Debris:AddItem(clone, 5)
end)
