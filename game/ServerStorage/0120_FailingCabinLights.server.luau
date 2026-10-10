local cabin=workspace:WaitForChild("Lobby"):WaitForChild("GrandSpawnLodge")
local rng=Random.new()
for _,light in cabin.Lanterns:GetDescendants() do
 if light:IsA("Light") then
 task.spawn(function()
 local normal=light:GetAttribute("DimBrightness") or .25
 while light.Parent do
 task.wait(rng:NextNumber(3,11))
 light.Enabled=false task.wait(rng:NextNumber(.2,1.6))
 light.Enabled=true light.Brightness=normal*.4 task.wait(.25)
 light.Brightness=normal
 end
 end)
 end
end