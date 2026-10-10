local player = game:GetService("Players").LocalPlayer
local character = player.Character
local humanoid = character:WaitForChild("Humanoid")

local StaminaGui = script.Parent
local Holder = StaminaGui:WaitForChild("Holder")
local Bar = Holder:WaitForChild("Bar")
local AmtDisplay = Holder:WaitForChild("AmtDisplay")

local UIS = game:GetService("UserInputService")

local Stamina = script.Stamina

local isRunning = false
local gotTired = false

UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if Stamina.Value >= 1 then
			if gotTired == false then
				humanoid.WalkSpeed = 30

				script.InSprint.Enabled = true
				script.OutSprint.Enabled = false
			end
		end
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = 16
		
		script.InSprint.Enabled = false
		script.OutSprint.Enabled = true
	end
end)

script.Tired.Event:Connect(function()
	if Stamina.Value <= 0 then
		humanoid.WalkSpeed = 16
		
		script.InSprint.Enabled = false
		script.OutSprint.Enabled = true
		gotTired = true
		
		wait(1)
		
		gotTired = false
	end
end)

while true do
	wait()
	AmtDisplay.Text = "STAMINA: ".. Stamina.Value .. "/100"
	
	game:GetService("TweenService"):Create(Bar, TweenInfo.new(0.075, Enum.EasingStyle.Quint), {Size = UDim2.new(Stamina.Value / 100, 0, 1, 0)}):Play()
end