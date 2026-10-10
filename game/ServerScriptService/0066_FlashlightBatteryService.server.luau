-- Loads looted batteries into flashlights:
--   * R / D-pad up while holding the flashlight (its Remote fires "Reload")
--   * clicking while holding a Battery tool
-- Rules and tuning live in the FlashlightBattery module next to this script.
local Players = game:GetService("Players")
local Battery = require(script.Parent:WaitForChild("FlashlightBattery"))

local hooked = setmetatable({}, { __mode = "k" })

local function hookTool(tool)
	if hooked[tool] or not tool:IsA("Tool") then return end
	if tool:GetAttribute("IsFlashlight") then
		hooked[tool] = true
		tool:SetAttribute("FullBatterySeconds", Battery.FULL_BATTERY_SECONDS)
		local remote = tool:WaitForChild("Remote", 5)
		if remote then
			remote.OnServerEvent:Connect(function(player, func)
				if func ~= "Reload" then return end
				local owner = Players:GetPlayerFromCharacter(tool.Parent) or (tool.Parent and tool.Parent.Parent)
				if owner == player then Battery.reload(player) end
			end)
		end
	elseif tool:GetAttribute("LootItemId") == "Battery" then
		hooked[tool] = true
		tool.Activated:Connect(function()
			local player = Players:GetPlayerFromCharacter(tool.Parent)
			if player then Battery.reload(player) end
		end)
	end
end

local function watch(container)
	for _, c in ipairs(container:GetChildren()) do task.spawn(hookTool, c) end
	container.ChildAdded:Connect(function(c) task.spawn(hookTool, c) end)
end

local function onPlayer(player)
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then watch(bp) end
	player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) end end)
	if player.Character then watch(player.Character) end
	player.CharacterAdded:Connect(watch)
end

for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerAdded:Connect(onPlayer)
