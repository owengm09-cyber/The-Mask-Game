--[[
	DayNightCycle
	3 minute day / 2 minute night, repeating until tasks or elimination end the round.

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

-- One simulation clock drives both the phase and its lighting transition.
-- Meetings pause elapsed time, so neither a phase deadline nor a fade advances.
local RunService=game:GetService("RunService")
local config=workspace:WaitForChild("MaskSystem")
local bindings={{Lighting,"Lighting"},{atmos,"Atmosphere"},{cc,"Color"},{bloom,"Bloom"},{rays,"Rays"},{clouds,"Clouds"}}
local phase="Day"
local resetDay=false
config:GetAttributeChangedSignal("RoundId"):Connect(function() resetDay=true end)
while true do
 local remaining=phase=="Day" and DAY_SECONDS or NIGHT_SECONDS
 local preset=PRESETS[phase] local elapsed=0 local starts={}
 for i,b in ipairs(bindings) do
  starts[i]={}
  if b[1] then for key in pairs(preset[b[2]]) do starts[i][key]=b[1][key] end end
 end
 local clockStart=Lighting.ClockTime local clockDiff=preset.Lighting.ClockTime-clockStart
 if clockDiff>12 then clockDiff-=24 elseif clockDiff< -12 then clockDiff+=24 end
 Lighting:SetAttribute("Phase",phase) PhaseChanged:FireAllClients(phase,remaining)
 while remaining>0 do
  local dt=RunService.Heartbeat:Wait()
  if resetDay then break end
  local paused=config:GetAttribute("MeetingActive")==true
  if not paused then
   remaining=math.max(0,remaining-dt)
   if elapsed<BLEND then
    elapsed=math.min(BLEND,elapsed+dt)
    local a=elapsed/BLEND a=a*a*(3-2*a)
    for i,b in ipairs(bindings) do if b[1] then
     for key,target in pairs(preset[b[2]]) do if key~="ClockTime" then
      local initial=starts[i][key]
      b[1][key]=typeof(target)=="Color3" and initial:Lerp(target,a) or initial+(target-initial)*a
     end end
    end end
    Lighting.ClockTime=(clockStart+clockDiff*a)%24
   end
  end
  Lighting:SetAttribute("CyclePaused",paused)
  Lighting:SetAttribute("PhaseRemaining",remaining)
  Lighting:SetAttribute("PhaseEndsAt",os.clock()+remaining)
  Lighting:SetAttribute("PhaseEndsServerTime",workspace:GetServerTimeNow()+remaining)
 end
 if resetDay then phase="Day" resetDay=false else phase=phase=="Day" and "Night" or "Day" end
end
