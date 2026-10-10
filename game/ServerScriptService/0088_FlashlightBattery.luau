-- Shared flashlight battery rules (server only).
-- The flashlight keeps its charge (0-100) in the tool's "Charge" attribute.
-- Used by ServerScriptService.FlashlightBatteryService (R to swap, click a Battery to load).
-- The flashlight drains itself (StarterPack.Flashlight.Server) at the rate set by FULL_BATTERY_SECONDS.

local FlashlightBattery = {}

FlashlightBattery.MAX_CHARGE = 100
-- Seconds of continuous light from one full battery. Raise for an easier game, lower for scarcer light.
FlashlightBattery.FULL_BATTERY_SECONDS = 240
-- A fresh flashlight (each spawn) starts full.
FlashlightBattery.START_CHARGE = 100

local SWAP_SOUND = "rbxassetid://9113658569" -- short mechanical clack, re-pitched below

local function holders(player)
	return { player:FindFirstChildOfClass("Backpack"), player.Character }
end

function FlashlightBattery.findFlashlight(player)
	for _, h in ipairs(holders(player)) do
		if h then
			for _, t in ipairs(h:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("IsFlashlight") then return t end
			end
		end
	end
end

function FlashlightBattery.findBattery(player)
	-- prefer the battery in hand, then the backpack
	for _, h in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if h then
			for _, t in ipairs(h:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("LootItemId") == "Battery" then return t end
			end
		end
	end
end

local function consume(battery)
	local count = (battery:GetAttribute("Count") or 1) - 1
	if count <= 0 then
		battery:Destroy()
	else
		battery:SetAttribute("Count", count)
		battery.Name = count > 1 and ("Battery x" .. count) or "Battery"
	end
end

local function playSwap(flashlight)
	local handle = flashlight:FindFirstChild("Handle")
	if not handle then return end
	local s = handle:FindFirstChild("BatterySwap")
	if not s then
		s = Instance.new("Sound")
		s.Name = "BatterySwap"
		s.SoundId = SWAP_SOUND
		s.Volume = 0.6
		s.PlaybackSpeed = 2.1
		s.RollOffMinDistance = 4
		s.RollOffMaxDistance = 30
		s.Parent = handle
	end
	s.TimePosition = 0
	s:Play()
	task.delay(0.35, function() if s.Parent then s:Stop() end end)
end

-- Loads one battery into the player's flashlight. Returns true, or false + reason.
function FlashlightBattery.reload(player)
	local flashlight = FlashlightBattery.findFlashlight(player)
	if not flashlight then return false, "NoFlashlight" end
	if (flashlight:GetAttribute("Charge") or FlashlightBattery.MAX_CHARGE) >= FlashlightBattery.MAX_CHARGE - 1 then
		return false, "Full"
	end
	local battery = FlashlightBattery.findBattery(player)
	if not battery then return false, "NoBattery" end
	consume(battery)
	flashlight:SetAttribute("Charge", FlashlightBattery.MAX_CHARGE)
	flashlight:SetAttribute("LastReload", os.clock())
	playSwap(flashlight)
	return true
end

return FlashlightBattery
