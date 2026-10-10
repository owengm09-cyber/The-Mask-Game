-- CharacterHeight
-- Makes every player's character a little taller, so first person doesn't feel like it's
-- filmed from a short perspective. Stretches body HEIGHT only (not width), so people look
-- taller rather than bigger. Runs on every spawn and respawn.
local Players = game:GetService("Players")

local HEIGHT = 1.12   -- 1 = normal height. 1.12 = 12% taller. Change this one number to adjust.

local function apply(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then return end
	-- wait for the avatar to finish loading so hats and hair are scaled with the body
	if not player:HasAppearanceLoaded() then
		local done = false
		local conn = player.CharacterAppearanceLoaded:Connect(function() done = true end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 8 do task.wait(0.1) end
		conn:Disconnect()
	end
	if character.Parent == nil or hum.Health <= 0 or character:GetAttribute("HeightScaled") then return end
	if hum.RigType == Enum.HumanoidRigType.R15 then
		local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
		if ok and desc then
			desc.HeightScale = desc.HeightScale * HEIGHT
			local applied = pcall(function() hum:ApplyDescription(desc) end)
			if not applied then warn("[CharacterHeight] could not resize " .. player.Name) end
		end
	else
		pcall(function() character:ScaleTo(HEIGHT) end)   -- R6 has no separate height scale
	end
	character:SetAttribute("HeightScaled", HEIGHT)
end

local function hook(player)
	player.CharacterAdded:Connect(function(c) task.spawn(apply, player, c) end)
	if player.Character then task.spawn(apply, player, player.Character) end
end
Players.PlayerAdded:Connect(hook)
for _, p in ipairs(Players:GetPlayers()) do hook(p) end
