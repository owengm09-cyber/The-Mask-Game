--[[ 
	This script controls the gui the player sees in regards to his or her health.
	Can be turned with Game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health,false)
	Copyright ROBLOX 2014. Written by Ben Tkacheff.
--]]
local Game = game
---------------------------------------------------------------------
-- Initialize/Variables
while not Game do
	wait(1/60)
end
while not Game.Players do
	wait(1/60)
end

local useCoreHealthBar = true

local currentHumanoid = nil

local HealthGui = nil
local lastHealth = 100
local HealthPercentageForOverlay = 5
local maxBarTweenTime = 0.3

local guiEnabled = false
local healthChangedConnection = nil
local humanoidDiedConnection = nil
local characterAddedConnection = nil
local sittingConnection = nil

local greenBarImage = "http://www.roblox.com/asset/?id=35238053"
local redBarImage = "http://www.roblox.com/asset/?id=35238036"
local goldBarImage = "http://www.roblox.com/asset/?id=154646431" -- for god mode
local hurtOverlayImage = "http://www.roblox.com/asset/?id=34854607"

Game:GetService("ContentProvider"):Preload(greenBarImage)
Game:GetService("ContentProvider"):Preload(redBarImage)
Game:GetService("ContentProvider"):Preload(goldBarImage)
Game:GetService("ContentProvider"):Preload(hurtOverlayImage)

while not Game.Players.LocalPlayer do
	wait(1/60)
end

---------------------------------------------------------------------
-- Functions

function UpdateGui(health)
	if not HealthGui then return end
	
	local healthFrame = HealthGui:FindFirstChild("HealthFrame")
	if not healthFrame then return end
	
	local healthBar = healthFrame:FindFirstChild("HealthBar")
	if not healthBar then return end
	
	-- If more than 1/4 health, bar = green.  Else, bar = red.
	local percentHealth = (health/currentHumanoid.MaxHealth)
	
	if percentHealth ~= percentHealth then
		percentHealth = 1
		healthBar.Image = goldBarImage
	elseif percentHealth > 0.25  then		
		healthBar.Image = greenBarImage
	else
		healthBar.Image = redBarImage
	end
		
	local width = (health / currentHumanoid.MaxHealth)
 	width = math.max(math.min(width,1),0) -- make sure width is between 0 and 1
 	if width ~= width then width = 1 end

	local healthDelta = lastHealth - health
	lastHealth = health
	
	local percentOfTotalHealth = math.abs(healthDelta/currentHumanoid.MaxHealth)
	percentOfTotalHealth = math.max(math.min(percentOfTotalHealth,1),0) -- make sure percentOfTotalHealth is between 0 and 1
	if percentOfTotalHealth ~= percentOfTotalHealth then percentOfTotalHealth = 1 end

	local newHealthSize = UDim2.new(width,0,1,0)
	
	if healthBar:IsDescendantOf(Game) then
		healthBar:TweenSize(newHealthSize, Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, percentOfTotalHealth * maxBarTweenTime, true)
	else
		healthBar.Size = newHealthSize
	end

	local thresholdForHurtOverlay = currentHumanoid.MaxHealth * (HealthPercentageForOverlay/100)
	
	if healthDelta >= thresholdForHurtOverlay then
		AnimateHurtOverlay()
	end
end

function AnimateHurtOverlay()
	if not HealthGui then return end
	
	local overlay = HealthGui:FindFirstChild("HurtOverlay")
	if not overlay then return end
	
	local newSize = UDim2.new(20, 0, 20, 0)
	local newPos = UDim2.new(-10, 0, -10, 0)

	if overlay:IsDescendantOf(Game) then
		-- stop any tweens on overlay
		overlay:TweenSizeAndPosition(newSize,newPos,Enum.EasingDirection.Out,Enum.EasingStyle.Linear,0,true,function()
			
			-- show the gui
			overlay.Size = UDim2.new(1,0,1,0)
			overlay.Position = UDim2.new(0,0,0,0)
			overlay.Visible = true
			
			-- now tween the hide
			if overlay:IsDescendantOf(Game) then
				overlay:TweenSizeAndPosition(newSize,newPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,10,false,function()
					overlay.Visible = false
				end)
			else
				overlay.Size = newSize
				overlay.Position = newPos
			end
		end)
	else
		overlay.Size = newSize
		overlay.Position = newPos
	end

end

function humanoidDied()
	 UpdateGui(0)
end

function disconnectPlayerConnections()
	if characterAddedConnection then characterAddedConnection:disconnect() end
	if humanoidDiedConnection then humanoidDiedConnection:disconnect() end
	if healthChangedConnection then healthChangedConnection:disconnect() end
	if sittingConnection then sittingConnection:disconnect() end
end

function newPlayerCharacter()
	disconnectPlayerConnections()
	startGui()
end

-- Function to handle sitting state
function onSittingChanged()
	if not currentHumanoid or not HealthGui then return end
	local seatPart = currentHumanoid.SeatPart
	if currentHumanoid.Sit and seatPart and seatPart:IsA("VehicleSeat") then
		HealthGui.Visible = false
	else
		HealthGui.Visible = true
	end
end

function startGui()
	characterAddedConnection = Game.Players.LocalPlayer.CharacterAdded:connect(newPlayerCharacter)

	local character = Game.Players.LocalPlayer.Character
	if not character then
		return
	end

	currentHumanoid = character:WaitForChild("Humanoid")
	if not currentHumanoid then
		return
	end
	
	healthChangedConnection = currentHumanoid.HealthChanged:connect(UpdateGui)
	humanoidDiedConnection = currentHumanoid.Died:connect(humanoidDied)
	-- Connect sitting state change
	sittingConnection = currentHumanoid:GetPropertyChangedSignal("Sit"):connect(onSittingChanged)
	UpdateGui(currentHumanoid.Health)
		
	-- Set initial visibility based on sitting state
	onSittingChanged()
end

---------------------------------------------------------------------
-- Start Script

HealthGui = script.Parent

guiEnabled = true
startGui()

