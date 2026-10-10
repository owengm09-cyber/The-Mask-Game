-- Continuous 24-minute day; sunrise 6 AM, sunset 7 PM.
local Lighting        = game:GetService("Lighting")
local TweenService    = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


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

local Clock=require(ReplicatedStorage:WaitForChild("ForestClock"))
local RunService=game:GetService("RunService")
local config=workspace:WaitForChild("MaskSystem")
local bindings={{Lighting,"Lighting"},{atmos,"Atmosphere"},{cc,"Color"},{bloom,"Bloom"},{rays,"Rays"},{clouds,"Clouds"}}
local function twilight(base)
 local p={} for group,values in base do p[group]=table.clone(values) end
 p.Lighting.Ambient=Color3.fromRGB(80,61,76)
 p.Lighting.OutdoorAmbient=Color3.fromRGB(155,108,94)
 p.Lighting.ColorShift_Top=Color3.fromRGB(255,166,99)
 p.Lighting.FogColor=Color3.fromRGB(164,117,112)
 p.Lighting.Brightness=1.7
 p.Atmosphere.Color=Color3.fromRGB(225,165,127)
 p.Atmosphere.Decay=Color3.fromRGB(128,81,108)
 p.Atmosphere.Glare=.65
 p.Clouds.Color=Color3.fromRGB(206,146,117)
 p.Color.Saturation=-.12
 return p
end
PRESETS.Dawn=twilight(PRESETS.Day)
PRESETS.Dusk=twilight(PRESETS.Night)
local keys={{0,"Night"},{5.5,"Night"},{6,"Dawn"},{7,"Day"},{17.5,"Day"},{19,"Dusk"},{20,"Night"},{24,"Night"}}
local hour=Clock.StartHour local phase=nil local accumulator=0
local function render()
 local lo,hi=keys[1],keys[2]
 for i=1,#keys-1 do if hour>=keys[i][1] and hour<keys[i+1][1] then lo=keys[i] hi=keys[i+1] break end end
 local alpha=(hour-lo[1])/(hi[1]-lo[1]) alpha=alpha*alpha*(3-2*alpha)
 for _,binding in bindings do
  local obj,group=binding[1],binding[2]
  if obj then for key,initial in PRESETS[lo[2]][group] do if key~="ClockTime" then
   local target=PRESETS[hi[2]][group][key]
   obj[key]=typeof(initial)=="Color3" and initial:Lerp(target,alpha) or initial+(target-initial)*alpha
  end end end
 end
 Lighting.ClockTime=Clock.SolarHour(hour)
 local remaining=Clock.Remaining(hour)
 Lighting:SetAttribute("GameTimeHours",hour)
 Lighting:SetAttribute("CycleDurationSeconds",Clock.CycleSeconds)
 Lighting:SetAttribute("CyclePaused",config:GetAttribute("MeetingActive")==true)
 Lighting:SetAttribute("PhaseRemaining",remaining)
 Lighting:SetAttribute("PhaseEndsAt",os.clock()+remaining)
 Lighting:SetAttribute("PhaseEndsServerTime",workspace:GetServerTimeNow()+remaining)
 local nextPhase=Clock.Phase(hour)
 if phase~=nextPhase then phase=nextPhase Lighting:SetAttribute("Phase",phase) PhaseChanged:FireAllClients(phase,remaining) end
end
config:GetAttributeChangedSignal("RoundId"):Connect(function() hour=Clock.StartHour render() end)
render()
RunService.Heartbeat:Connect(function(dt)
 hour=Clock.Advance(hour,dt,config:GetAttribute("MeetingActive")==true)
 accumulator+=dt
 if accumulator>=.1 then accumulator=0 render() end
end)
