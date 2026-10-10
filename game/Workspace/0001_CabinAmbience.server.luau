local Lighting=game:GetService("Lighting")
local TweenService=game:GetService("TweenService")
local village=workspace:WaitForChild("SummerCampCabins",30)
if not village then return end
local hollow=village:WaitForChild("Cabin06_HOLLOW",30)
if not hollow then return end
local light=hollow:FindFirstChild("FlickerLight",true)
if not light or not light:IsA("PointLight") then return end
local baseline=light:GetAttribute("NormalBrightness") or light.Brightness
while light.Parent do
	task.wait(math.random(16,28))
	local phase=Lighting:GetAttribute("Phase")
	local night=phase=="Night" or (phase==nil and (Lighting.ClockTime>=18 or Lighting.ClockTime<6))
	if night and math.random()<.42 then
		TweenService:Create(light,TweenInfo.new(.4),{Brightness=baseline*.62}):Play()
		task.wait(.8)
		if light.Parent then TweenService:Create(light,TweenInfo.new(1.5),{Brightness=baseline}):Play() end
	elseif light.Parent then light.Brightness=baseline end
end
