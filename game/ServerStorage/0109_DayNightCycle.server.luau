--[[
	DayNightCycle
	3 minute day / 2 minute night, matching the 5-minute round.

	Design note: at night the ambient stays LOW but the atmosphere is
	BRIGHT. That combination is what makes players read as hard
	silhouettes against the mist - dark scene, clearly visible killer.
	Raising ambient to "fix" visibility would flatten the silhouettes
	and actually make people harder to spot, not easier.

	Other systems can read the current phase from:
		Lighting:GetAttribute("Phase")        -- "Day" | "Night"
		Lighting:GetAttribute("PhaseEndsAt")  -- os.clock() timestamp
	or listen to ReplicatedStorage.Remotes.PhaseChanged
]]

local Lighting        = game:GetService("Lighting")
local TweenService    = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAY_SECONDS   = 180   -- 3 minutes
local NIGHT_SECONDS = 120   -- 2 minutes
local BLEND         = 10    -- seconds to fade between phases

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local PhaseChanged = remotes:FindFirstChild("PhaseChanged")
if not PhaseChanged then
	PhaseChanged = Instance.new("RemoteEvent")
	PhaseChanged.Name = "PhaseChanged"
	PhaseChanged.Parent = remotes
end

local PRESETS = {
	Day = {
		Lighting = {
			ClockTime = 13,
			Brightness = 2.2,
			Ambient = Color3.fromRGB(95, 100, 110),
			OutdoorAmbient = Color3.fromRGB(140, 148, 165),
			ColorShift_Top = Color3.fromRGB(150, 160, 180),
			ColorShift_Bottom = Color3.fromRGB(60, 64, 72),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 0.7,
			ExposureCompensation = 0.10,
			FogColor = Color3.fromRGB(150, 158, 172),
			FogStart = 60,
			FogEnd = 600,
		},
		Atmosphere = {
			Density = 0.20, Offset = 0.25,
			Color = Color3.fromRGB(150, 158, 172),
			Decay = Color3.fromRGB(110, 118, 135),
			Glare = 0.3, Haze = 1.2,
		},
		Color = { Brightness = 0, Contrast = 0.05, Saturation = -0.25 },
		Bloom = { Intensity = 0.4, Threshold = 1.6 },
		Rays  = { Intensity = 0.06 },
		Clouds = { Cover = 0.72, Density = 0.5, Color = Color3.fromRGB(168, 176, 190) },
	},

	Night = {
		Lighting = {
			ClockTime = 0,
			Brightness = 1.8,
			Ambient = Color3.fromRGB(40, 46, 60),
			OutdoorAmbient = Color3.fromRGB(70, 80, 100),
			ColorShift_Top = Color3.fromRGB(80, 96, 130),
			ColorShift_Bottom = Color3.fromRGB(26, 30, 40),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 0.45,
			ExposureCompensation = 0.55,
			FogColor = Color3.fromRGB(96, 110, 136),
			FogStart = 30,
			FogEnd = 320,
		},
		Atmosphere = {
			Density = 0.38, Offset = 0.18,
			Color = Color3.fromRGB(110, 124, 150),   -- brighter than the scene: silhouettes
			Decay = Color3.fromRGB(60, 70, 92),
			Glare = 1.2, Haze = 2.2,
		},
		Color = { Brightness = 0, Contrast = 0.12, Saturation = -0.40 },
		Bloom = { Intensity = 0.9, Threshold = 0.95 },
		Rays  = { Intensity = 0.12 },
		Clouds = { Cover = 0.78, Density = 0.55, Color = Color3.fromRGB(86, 96, 118) },
	},
}

local atmos  = Lighting:FindFirstChildOfClass("Atmosphere")
local cc     = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local bloom  = Lighting:FindFirstChildOfClass("BloomEffect")
local rays   = Lighting:FindFirstChildOfClass("SunRaysEffect")
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")

local function blend(preset, seconds)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- ClockTime must not tween linearly or it scrubs backwards through noon
	local targetClock = preset.Lighting.ClockTime
	local lightProps = {}
	for k, v in pairs(preset.Lighting) do
		if k ~= "ClockTime" then lightProps[k] = v end
	end

	TweenService:Create(Lighting, info, lightProps):Play()

	-- move ClockTime the short way round
	task.spawn(function()
		local start = Lighting.ClockTime
		local diff = targetClock - start
		if diff > 12 then diff -= 24 elseif diff < -12 then diff += 24 end
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			local a = (os.clock() - t0) / seconds
			a = a * a * (3 - 2 * a) -- smoothstep
			Lighting.ClockTime = (start + diff * a) % 24
			task.wait()
		end
		Lighting.ClockTime = targetClock
	end)

	if atmos  then TweenService:Create(atmos,  info, preset.Atmosphere):Play() end
	if cc     then TweenService:Create(cc,     info, preset.Color):Play() end
	if bloom  then TweenService:Create(bloom,  info, preset.Bloom):Play() end
	if rays   then TweenService:Create(rays,   info, preset.Rays):Play() end
	if clouds then TweenService:Create(clouds, info, preset.Clouds):Play() end
end

local function setPhase(name, duration)
	Lighting:SetAttribute("Phase", name)
	Lighting:SetAttribute("PhaseEndsAt", os.clock() + duration)
	PhaseChanged:FireAllClients(name, duration)
	blend(PRESETS[name], BLEND)
end

-- start on day
while true do
	setPhase("Day", DAY_SECONDS)
	task.wait(DAY_SECONDS)

	setPhase("Night", NIGHT_SECONDS)
	task.wait(NIGHT_SECONDS)
end
