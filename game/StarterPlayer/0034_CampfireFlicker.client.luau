-- CampfireFlicker: the campfire's light breathes and flickers like a real fire.
-- Runs on each player's machine, so it costs the server nothing. It drives every PointLight in
-- workspace.EmergencyCampsite.Campfire that has BaseBrightness / BaseRange attributes (CampfireRebuilder sets them),
-- and sets the flame sprites' brightness for day or night (DayBrightness / NightBrightness attributes).
-- Lantern lights tagged "LanternLight" (LanternUpgrader) get a gentler version of the same flicker.
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local camp = workspace:WaitForChild("EmergencyCampsite")

local lights, flames = {}, {}
local function applyPhase()
	local night = Lighting:GetAttribute("Phase") == "Night"
	for _, e in flames do
		local b = e:GetAttribute(night and "NightBrightness" or "DayBrightness")
		if b then e.Brightness = b end
	end
end
local function scan()
	lights, flames = {}, {}
	local fire = camp:FindFirstChild("Campfire")
	if not fire then return end
	for _, d in fire:GetDescendants() do
		if d:IsA("PointLight") and d:GetAttribute("BaseBrightness") then table.insert(lights, d) end
		if d:IsA("ParticleEmitter") and d:GetAttribute("DayBrightness") then table.insert(flames, d) end
	end
	applyPhase()
end
scan()
camp.DescendantAdded:Connect(function(d) if d:IsA("PointLight") or d:IsA("ParticleEmitter") then task.defer(scan) end end)
Lighting:GetAttributeChangedSignal("Phase"):Connect(applyPhase)

local CollectionService = game:GetService("CollectionService")
local lanterns = {}
for _, l in CollectionService:GetTagged("LanternLight") do lanterns[l] = math.random() * 100 end
CollectionService:GetInstanceAddedSignal("LanternLight"):Connect(function(l) lanterns[l] = math.random() * 100 end)
CollectionService:GetInstanceRemovedSignal("LanternLight"):Connect(function(l) lanterns[l] = nil end)

local t = 0
local function where(l)
	local p = l.Parent
	return p and (p:IsA("Attachment") and p.WorldPosition or p:IsA("BasePart") and p.Position)
end
RunService.Heartbeat:Connect(function(dt)
	t += dt
	local cam = workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position
	for i, l in lights do
		local pos = where(l)
		if pos and (not eye or (eye - pos).Magnitude < 300) then
			local b, r = l:GetAttribute("BaseBrightness"), l:GetAttribute("BaseRange")
			-- a slow breathing swell, a quicker waver and a fast flutter on top
			local n = math.noise(t * 2.3, i * 7.1) * 0.55 + math.noise(t * 7.9, i * 3.3) * 0.3 + math.noise(t * 17, i * 1.7) * 0.15
			l.Brightness = b * (1 + n * 0.4)
			l.Range = r * (1 + n * 0.06)
		end
	end
	for l, seed in lanterns do
		local pos = where(l)
		if pos and (not eye or (eye - pos).Magnitude < 160) then
			local b = l:GetAttribute("BaseBrightness")
			if b then
				local n = math.noise(t * 3.1, seed) * 0.7 + math.noise(t * 11, seed + 3) * 0.3
				l.Brightness = b * (1 + n * 0.22)
			end
		end
	end
end)
