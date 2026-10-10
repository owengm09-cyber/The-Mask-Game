-- AntennaLight: the red light on top of the radio tower's antenna (workspace.RadioTower.AviationLight).
-- It stays dark until the radio is fixed (Task19 "Done"), then blinks red so everyone in the forest can see the tower
-- is transmitting. It goes dark again when a new round resets the tasks.
local light = workspace:WaitForChild("RadioTower"):WaitForChild("AviationLight")
local task19 = workspace:WaitForChild("ForestRescueTasks"):WaitForChild("Task19")
local glow = light:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
glow.Name = "Glow"
glow.Color = Color3.fromRGB(255, 45, 35)
glow.Range = 22
glow.Parent = light

local OFF = Color3.fromRGB(70, 18, 16)
local ON = Color3.fromRGB(255, 40, 30)
local ON_TIME, OFF_TIME = 1.0, 0.7 -- seconds lit / dark while blinking

local function dark()
	light.Material = Enum.Material.SmoothPlastic
	light.Color = OFF
	glow.Enabled = false
end
local function lit()
	light.Material = Enum.Material.Neon
	light.Color = ON
	glow.Brightness = 3
	glow.Enabled = true
end

local running = 0
local function update()
	running += 1
	local me = running
	if task19:GetAttribute("Done") ~= true then
		dark()
		return
	end
	task.spawn(function()
		while running == me and task19:GetAttribute("Done") == true do
			lit()
			task.wait(ON_TIME)
			if running ~= me then break end
			dark()
			task.wait(OFF_TIME)
		end
	end)
end

task19:GetAttributeChangedSignal("Done"):Connect(update)
update()
