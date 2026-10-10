-- Opens / closes every model tagged "CabinDoor".
-- Each door model has: Hinge (anchored, invisible) with the leaf parts welded to it,
-- attributes ClosedCFrame (CFrame) and OpenAngle (degrees, signed), and a DoorPrompt ProximityPrompt.
-- The creature (NightHarlequin) can path through doors (PathfindingModifier PassThrough) and
-- pushes a closed door open when it walks up to it.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local DOOR_SOUND = "rbxassetid://9114135682" -- Door Creak (Pro Sound Effects)
local OPEN_TIME, CLOSE_TIME = 0.6, 0.45
local CREATURE_NAME, CREATURE_RANGE = "NightHarlequin", 6

local doors = {}

local function setup(model)
	if doors[model] then return end
	local hinge = model:WaitForChild("Hinge", 5)
	local prompt = model:FindFirstChild("DoorPrompt", true)
	local closed = model:GetAttribute("ClosedCFrame")
	local angle = model:GetAttribute("OpenAngle") or 90
	if not (hinge and prompt and closed) then
		warn("[CabinDoorService] incomplete door:", model:GetFullName())
		return
	end
	hinge.CFrame = closed

	local leaf = model:FindFirstChild("DoorLeaf")
	local sound = Instance.new("Sound")
	sound.Name = "DoorCreak"
	sound.SoundId = DOOR_SOUND
	sound.RollOffMaxDistance = 60
	sound.RollOffMinDistance = 6
	sound.Volume = 0.55
	sound.Parent = leaf or hinge

	local door = { model = model, hinge = hinge, prompt = prompt, closed = closed, isOpen = false, tween = nil }
	door.center = (closed * CFrame.new((leaf and leaf.Size.X or 5) / 2, 0, 0)).Position

	function door.set(open)
		if door.isOpen == open then return end
		door.isOpen = open
		if door.tween then door.tween:Cancel() end
		local target = open and (closed * CFrame.Angles(0, math.rad(angle), 0)) or closed
		door.tween = TweenService:Create(hinge,
			TweenInfo.new(open and OPEN_TIME or CLOSE_TIME, Enum.EasingStyle.Sine, open and Enum.EasingDirection.Out or Enum.EasingDirection.In),
			{ CFrame = target })
		door.tween:Play()
		sound.PlaybackSpeed = open and 1.1 or 1.35
		sound.TimePosition = 0
		sound:Play()
		prompt.ActionText = open and "Close" or "Open"
		model:SetAttribute("IsOpen", open)
	end

	prompt.Triggered:Connect(function()
		door.set(not door.isOpen)
	end)
	model.Destroying:Connect(function() doors[model] = nil end)
	doors[model] = door
end

for _, m in ipairs(CollectionService:GetTagged("CabinDoor")) do task.spawn(setup, m) end
CollectionService:GetInstanceAddedSignal("CabinDoor"):Connect(setup)

-- The creature shoves closed doors open when it reaches them.
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, creature in ipairs(workspace:GetChildren()) do
			if creature.Name == CREATURE_NAME and creature:IsA("Model") then
				local root = creature:FindFirstChild("HumanoidRootPart")
				if root then
					for _, door in pairs(doors) do
						if not door.isOpen and (root.Position - door.center).Magnitude < CREATURE_RANGE then
							door.set(true)
						end
					end
				end
			end
		end
	end
end)
