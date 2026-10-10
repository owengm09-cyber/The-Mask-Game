-- Slides the left survivor panel off-screen. H on keyboard,
-- or the "HUD" button on touch devices.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("DreadHUD")
local panel = gui:WaitForChild("Survivors")

local shownPos = panel.Position
local hiddenPos = shownPos - UDim2.new(0, 320, 0, 0)  -- slide left, off screen
local visible = true
local tweening = false

local INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setVisible(state)
	if tweening or state == visible then return end
	visible = state
	tweening = true
	local goal = state and shownPos or hiddenPos
	local t = TweenService:Create(panel, INFO, { Position = goal })
	t.Completed:Connect(function() tweening = false end)
	t:Play()
end

local function onAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		setVisible(not visible)
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("ToggleHUD", onAction, true, Enum.KeyCode.H)
ContextActionService:SetTitle("ToggleHUD", "HUD")
ContextActionService:SetPosition("ToggleHUD", UDim2.new(1, -140, 0, -95))
