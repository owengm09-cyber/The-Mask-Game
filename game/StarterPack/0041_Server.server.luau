local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tool   = script.Parent
local Handle = Tool:WaitForChild("Handle")
local Remote = Tool:WaitForChild("Remote")

local beam    = Tool:FindFirstChild("Beam2") and Tool.Beam2:FindFirstChildOfClass("Beam")
local surface = Tool:FindFirstChild("p") and Tool.p:FindFirstChildOfClass("SurfaceLight")
local spot    = Handle:FindFirstChildOfClass("SpotLight")

-- Battery: charge (0-100) lives in the "Charge" attribute and drains while the light is on.
-- Batteries are loaded by ServerScriptService.FlashlightBatteryService (R key / clicking a Battery),
-- which also sets "FullBatterySeconds" from ServerScriptService.FlashlightBattery.
Tool:SetAttribute("IsFlashlight", true)
Tool:SetAttribute("Charge", 100)
local charge = 100

-- "On" replicates to every client, which is how each client knows
-- whether to render its own local beam.
Tool:SetAttribute("On", false)

local function getPlayer()
	return Players:GetPlayerFromCharacter(Tool.Parent)
end

local function apply(state)
	if state and charge <= 0 then state = false end
	Tool:SetAttribute("On", state)
	-- Visible to OTHER players: a glow on the prop so a lit player reads
	-- as a target. The holder's actual beam is built client-side.
	if surface then surface.Enabled = state end
	if beam then beam.Enabled = state end
	-- the handle spotlight stays off: it bobs with the arm animation
	if spot then spot.Enabled = false end
end

Remote.OnServerEvent:Connect(function(player, func)
	if player ~= getPlayer() then return end
	if func == "ToggleLight" then
		local turningOn = not Tool:GetAttribute("On")
		if turningOn and charge <= 0 then
			Tool:SetAttribute("DeadClick", os.clock()) -- the HUD flashes "DEAD"
			return
		end
		apply(turningOn)
	end
end)

-- picks up a freshly loaded battery
Tool:GetAttributeChangedSignal("Charge"):Connect(function()
	local c = Tool:GetAttribute("Charge")
	if typeof(c) == "number" and math.abs(c - charge) > 0.5 then charge = c end
end)

local sinceSync = 0
RunService.Heartbeat:Connect(function(dt)
	if not Tool:GetAttribute("On") then return end
	local seconds = Tool:GetAttribute("FullBatterySeconds") or 240
	charge = math.max(0, charge - (100 / seconds) * dt)
	sinceSync += dt
	if charge <= 0 then
		Tool:SetAttribute("Charge", 0)
		apply(false)
	elseif sinceSync >= 0.25 then
		sinceSync = 0
		Tool:SetAttribute("Charge", math.floor(charge * 10 + 0.5) / 10)
	end
end)

Tool.Unequipped:Connect(function()
	apply(false)
end)

apply(false)
