local player = game:GetService("Players").LocalPlayer
local character = player.Character
local humanoid = character:WaitForChild("Humanoid")

local Stamina = script.Parent.Stamina

while true do
	wait()
	
	
	if Stamina.Value >= 100 then
		
	else
		
		repeat
			wait(0.15)
			Stamina.Value = Stamina.Value + 1
		until Stamina.Value >= 100
	end
end