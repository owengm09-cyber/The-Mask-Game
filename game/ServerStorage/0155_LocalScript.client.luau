local plr = game.Players.LocalPlayer
local char = plr.Character
while not char or not char.Parent do
	char = plr.Character
	wait()
end

local player = game.Players.LocalPlayer
local plrsgui = player.PlayerGui
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local AnimTrack = humanoid:LoadAnimation(script.Parent.UseAnimation)
local sound = script.Parent.Handle.UseSound
local startergui = game:GetService("StarterGui")
local ts = game:GetService("TweenService")
local activating = false
local active = false
local guiclone

script.Parent.Equipped:Connect(function()
	guiclone = script.Parent.ToolGui:Clone()
	guiclone.Parent = plrsgui
end)

script.Parent.Unequipped:Connect(function()
	if plrsgui:FindFirstChild("ToolGui") then
		plrsgui:WaitForChild("ToolGui"):Destroy()
	end
end)

script.Parent.Activated:Connect(function()
	if activating == false then
		plr:SetAttribute("HotbarHidden", true) -- CampHotbar: no switching items mid-bandage
		activating = true
		active = true
		AnimTrack:Play()
		sound:Play()
		if guiclone ~= nil then
			for i, v in pairs(guiclone:GetDescendants()) do
				if v:IsA("Frame") then
					ts:Create(v, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
				end
			end
		end
		local filltween = ts:Create(guiclone.LineFrame.Fill, TweenInfo.new(3.7, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)})
		humanoid.WalkSpeed = 3
		filltween:Play()
		for i = 1, 33 do
			if active == false then
				filltween:Cancel()
				ts:Create(guiclone.LineFrame.Fill, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Size = UDim2.new(0, 0, 1, 0)}):Play()
				break
			end
			task.wait(0.1)
		end
		if active == true then
			if guiclone ~= nil then
				for i, v in pairs(guiclone:GetDescendants()) do
					if v:IsA("Frame") then
						ts:Create(v, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
					end
				end
			end
			game.Debris:AddItem(guiclone, 0.5)
			script.Parent.Use:FireServer(35)
			active = false
			activating = false
			plr:SetAttribute("HotbarHidden", nil)
			AnimTrack:Stop()
			sound:Stop()
			humanoid.WalkSpeed = 16
			active = false
		end
	end
end)

script.Parent.Deactivated:Connect(function()
	if active == true then
		if guiclone ~= nil then
			for i, v in pairs(guiclone:GetDescendants()) do
				if v:IsA("Frame") then
					ts:Create(v, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
				end
			end
		end
		active = false
		activating = false
		AnimTrack:Stop()
		sound:Stop()
		humanoid.WalkSpeed = 16
		plr:SetAttribute("HotbarHidden", nil)
	end
end)

