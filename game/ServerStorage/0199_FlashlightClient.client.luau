-- Flashlight (client)
-- First-person viewmodel: a copy of YOUR hand and forearm holding the flashlight, locked steady to
-- your view so it doesn't bob when you run. The beam comes from the lens and follows where you look.
-- Click or tap to toggle. It runs on batteries: R (or D-pad up) loads a spare one.
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Tool   = script.Parent
local Remote = Tool:WaitForChild("Remote")
local Handle = Tool:WaitForChild("Handle")
local player = Players.LocalPlayer

-- The flashlight's natural resting grip on an R15 character, relative to your eyes (measured in-game).
local HANDLE_VIEW = CFrame.new(0.7651, -0.5832, -0.9326, -0.0161, -0.0012, -0.9999, -0.0724, 0.9974, -0.0000, 0.9972, 0.0724, -0.0161)
-- Nudge from that grip: (right, up, forward). Raise the middle number to lift your hand higher in view.
local SHIFT = CFrame.new(0.10, -0.33, -1.11)
-- Turns the flashlight slightly inward, toward the middle of the screen, so your forearm
-- comes in from the bottom-right corner. Bigger = more inward.
local AIM_YAW = math.rad(6)
-- Tilts the flashlight up toward the middle of the screen, since your hand sits low.
local AIM_PITCH = math.rad(8)
-- How far the flashlight slides forward in your grip, so your fist holds its tail end
-- instead of its middle (the middle grip left half of it sticking out toward your face).
local SLIDE = 0.25
-- How long the flashlight looks in your hand, compared with the real model (1 = full length).
-- Only the length changes; THICKNESS keeps it a solid grip for your fist.
local LENGTH = 0.6
local THICKNESS = 0.9
local HV_ROT = HANDLE_VIEW - HANDLE_VIEW.Position

local ARM_R15 = { "RightHand" }   -- just your hand; the forearm took up too much of the screen
-- the slim (Rthro) counselor body: its forearm is narrow enough to show, and it carries the wristband
local ARM_SLIM = { "RightHand", "RightLowerArm" }
local ARM_R6  = { "Right Arm" }

local viewModel, offsets, lens
local wristband
local rig, beam, spill
local bouncePart, bounce
local renderConn
-- battery: the beam fades below 30% charge and flickers below 15% (charge lives in the "Charge" attribute)
local BASE_BEAM, BASE_RANGE, BASE_SPILL, BASE_BOUNCE = 5, 60, 0.8, 0.7
local flickerUntil, nextFlicker = 0, 0
local function chargeFactor()
	local c = math.clamp((Tool:GetAttribute("Charge") or 100) / 100, 0, 1)
	local f = c >= 0.3 and 1 or (0.35 + 0.65 * (c / 0.3))
	if c < 0.15 then
		local now = os.clock()
		if now > nextFlicker then
			flickerUntil = now + 0.03 + math.random() * 0.12
			nextFlicker = now + 0.15 + math.random() * (0.4 + c * 8)
		end
		if now < flickerUntil then f *= 0.08 + math.random() * 0.25 end
	end
	return f
end
local RELOAD_ACTION = "FlashlightReload"
local function bindReload()
	ContextActionService:BindAction(RELOAD_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then Remote:FireServer("Reload") end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.R, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle(RELOAD_ACTION, "Battery")
end
local function unbindReload()
	ContextActionService:UnbindAction(RELOAD_ACTION)
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function fxFolder()
	local f = workspace:FindFirstChild("LocalFlashlightFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "LocalFlashlightFX"
		f.Parent = workspace   -- created on this client only, so it never replicates
	end
	return f
end

local function prep(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false   -- the viewmodel must never shadow its own beam
	p.Massless = true
end

-- Remove anything from a copied part that could tie it to your real character or double up effects.
-- Constraints matter: newer avatars join limbs with AnimationConstraints/BallSockets instead of Motor6Ds,
-- and a copied arm that keeps one stays physically bound to your real arm.
local function strip(c)
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint")
			or d:IsA("LuaSourceContainer") or d:IsA("Light") or d:IsA("Beam")
			or d:IsA("Sound") or d:IsA("TouchTransmitter") then
			d:Destroy()
		end
	end
end

local function buildRig()
	rig = Instance.new("Part")
	rig.Name = "FlashlightBeam"
	rig.Size = Vector3.new(0.2, 0.2, 0.2)
	rig.Transparency = 1
	prep(rig)
	rig.Parent = fxFolder()

	beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Angle = 55
	beam.Range = 60
	beam.Brightness = 5
	beam.Color = Color3.fromRGB(255, 244, 218)
	beam.Shadows = true
	beam.Enabled = false
	beam.Parent = rig

	spill = Instance.new("PointLight")
	spill.Range = 9
	spill.Brightness = 0.8
	spill.Color = Color3.fromRGB(255, 240, 210)
	spill.Shadows = false
	spill.Enabled = false
	spill.Parent = rig

	-- faint bounce light by your hand, so the hand and flashlight aren't black silhouettes when it's on
	bouncePart = Instance.new("Part")
	bouncePart.Name = "FlashlightBounce"
	bouncePart.Size = Vector3.new(0.2, 0.2, 0.2)
	bouncePart.Transparency = 1
	prep(bouncePart)
	bouncePart.Parent = fxFolder()
	bounce = Instance.new("PointLight")
	bounce.Range = 4
	bounce.Brightness = 0.7
	bounce.Color = Color3.fromRGB(255, 236, 205)
	bounce.Shadows = false
	bounce.Enabled = false
	bounce.Parent = bouncePart
end

local function buildViewModel(char)
	viewModel = Instance.new("Model")
	viewModel.Name = "FlashlightViewModel"
	offsets, lens = {}, nil
	local toolClones = {}
	local base = Handle.CFrame
	local slide = CFrame.new()
	local tip = Tool:FindFirstChild("p")
	if tip then
		slide = CFrame.new(base:VectorToObjectSpace((tip.Position - base.Position).Unit) * SLIDE)
	end

	for _, d in ipairs(Tool:GetChildren()) do
		if d:IsA("BasePart") then
			local c = d:Clone()
			strip(c)
			prep(c)
			-- this flashlight is near-black; lift your first-person copy to gunmetal so it reads in the dark
			if c.Transparency < 0.9 then
				local lum = 0.299 * c.Color.R + 0.587 * c.Color.G + 0.114 * c.Color.B
				if lum < 0.25 then
					pcall(function() c.UsePartColor = true end)
					c.Color = Color3.fromRGB(70, 72, 78)
				end
			end
			offsets[c] = slide * base:ToObjectSpace(d.CFrame)
			toolClones[#toolClones + 1] = c
			c.Parent = viewModel
			if d.Name == "p" then lens = c end
		end
	end

	local isR15 = char:FindFirstChild("RightLowerArm") ~= nil
	local slim = char:GetAttribute("Body") == "Rthro"
	for _, name in ipairs(slim and ARM_SLIM or isR15 and ARM_R15 or ARM_R6) do
		local part = char:FindFirstChild(name)
		if part then
			local c = part:Clone()
			strip(c)
			prep(c)
			c.Transparency = 0
			offsets[c] = base:ToObjectSpace(part.CFrame)
			c.Parent = viewModel
		end
	end

	-- your own wristband: a thin flat band around the right forearm just above the wrist.
	-- Built from four flat plates (hollow), so seen end-on it never covers your hand.
	local armClone = viewModel:FindFirstChild("RightLowerArm") or viewModel:FindFirstChild("RightHand")
	wristband = {}
	-- the counselor outfit has its own fitted band on the forearm: on the slim body (whose forearm is in
	-- view) copy it exactly as it sits; the bulky body shows only the hand, so it gets the thin plates below
	local outfitBand = {}
	local outfit = char:FindFirstChild("Outfit")
	if outfit then
		for _, d in ipairs(outfit:GetChildren()) do
			if d:IsA("BasePart") and d:GetAttribute("Wristband") then table.insert(outfitBand, d) end
		end
	end
	if #outfitBand > 0 and slim then
		for _, d in ipairs(outfitBand) do
			local seg = d:Clone()
			strip(seg)
			prep(seg)
			seg.Name = "ViewWristband"
			seg.Transparency = 0
			offsets[seg] = base:ToObjectSpace(d.CFrame)
			seg.Parent = viewModel
			wristband[#wristband + 1] = seg
		end
	elseif armClone and offsets[armClone] then
		local att = armClone:FindFirstChild("RightWristRigAttachment")
		local y0 = (att and att.Position.Y or -armClone.Size.Y / 2) + 0.2
		-- seen end-on and right next to the camera, so it's kept narrower and thinner than the body band
		local X, Z, T, Hh = armClone.Size.X, armClone.Size.Z, 0.018, 0.12
		local bandColour = player:GetAttribute("BandColor")
		local plates = {
			{ Vector3.new(X + 0.06, Hh, T), CFrame.new(0, y0, -(Z / 2 + T / 2)) },
			{ Vector3.new(X + 0.06, Hh, T), CFrame.new(0, y0, Z / 2 + T / 2) },
			{ Vector3.new(T, Hh, Z + 0.06), CFrame.new(-(X / 2 + T / 2), y0, 0) },
			{ Vector3.new(T, Hh, Z + 0.06), CFrame.new(X / 2 + T / 2, y0, 0) },
		}
		for _, pl in ipairs(plates) do
			local seg = Instance.new("Part")
			seg.Name = "ViewWristband"
			seg.Size = pl[1]
			seg.Material = Enum.Material.Fabric
			seg.Color = bandColour or Color3.new(1, 1, 1)
			seg.Transparency = bandColour and 0 or 1
			prep(seg)
			offsets[seg] = offsets[armClone] * pl[2]
			seg.Parent = viewModel
			wristband[#wristband + 1] = seg
		end
	end

	-- shorten the flashlight (not your hand): squash it along its length, around your grip
	local axis = tip and base:VectorToObjectSpace((tip.Position - base.Position).Unit) or Vector3.new(1, 0, 0)
	local handPart = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local grip = handPart and base:PointToObjectSpace(handPart.Position) or Vector3.zero
	-- the slim (Rthro) hand is much smaller than the blocky one: a thinner, shorter flashlight so your
	-- fingers wrap round it instead of disappearing behind it
	local LENGTH, THICKNESS = LENGTH, THICKNESS
	if slim then LENGTH, THICKNESS = 0.5, 0.5 end
	for _, c in ipairs(toolClones) do
		local off = offsets[c]
		local rot = off - off.Position
		local rel = off.Position - grip
		local along = rel:Dot(axis)
		local perp = rel - axis * along
		offsets[c] = CFrame.new(grip + axis * (along * LENGTH) + perp * THICKNESS) * rot
		-- the part's own axis that lines up with the flashlight gets LENGTH, the other two THICKNESS
		local ax, ay, az = math.abs(rot.RightVector:Dot(axis)), math.abs(rot.UpVector:Dot(axis)), math.abs(rot.LookVector:Dot(axis))
		local s = c.Size
		c.Size = Vector3.new(
			s.X * ((ax >= ay and ax >= az) and LENGTH or THICKNESS),
			s.Y * ((ay > ax and ay >= az) and LENGTH or THICKNESS),
			s.Z * ((az > ax and az > ay) and LENGTH or THICKNESS))
	end

	-- your shirt on the copied arm (clothing only renders on body parts in a model with a Humanoid)
	local shirt = char:FindFirstChildOfClass("Shirt")
	if shirt then shirt:Clone().Parent = viewModel end
	local hum = Instance.new("Humanoid")
	hum.RigType = isR15 and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	pcall(function() hum.EvaluateStateMachine = false end)
	hum.Parent = viewModel

	viewModel.Parent = workspace.CurrentCamera

	-- safety net: nothing in the viewmodel may be physically connected to anything outside it
	for _, p in ipairs(viewModel:GetDescendants()) do
		if p:IsA("BasePart") and p.Parent then
			for _, q in ipairs(p:GetConnectedParts(false)) do
				if not q:IsDescendantOf(viewModel) then
					warn("[Flashlight] viewmodel part " .. p.Name .. " was connected to " .. q:GetFullName() .. " - removed")
					p:Destroy()
					break
				end
			end
		end
	end
end

-- the real prop stays in your character's hand for everyone else; for you it's hidden,
-- and its own lights are kept off locally so they don't double up with your beam
local function hideReal(hidden)
	for _, d in ipairs(Tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		elseif hidden and (d:IsA("Light") or d:IsA("Beam")) then
			d.Enabled = false
		end
	end
end

local function refresh()
	local on = Tool:GetAttribute("On") == true
	if beam then beam.Enabled = on end
	if spill then spill.Enabled = on end
	if bounce then bounce.Enabled = on end
end

local function destroyAll()
	unbindReload()
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	if rig then rig:Destroy(); rig, beam, spill = nil, nil, nil end
	if bouncePart then bouncePart:Destroy(); bouncePart, bounce = nil, nil end
	if viewModel then viewModel:Destroy(); viewModel, offsets, lens, wristband = nil, nil, nil, nil end
end

local function render()
	local cam = workspace.CurrentCamera
	if not cam or not viewModel then return end
	local camCF = cam.CFrame
	local handleCF = camCF * SHIFT * CFrame.new(HANDLE_VIEW.Position) * CFrame.Angles(0, AIM_YAW, 0) * CFrame.Angles(AIM_PITCH, 0, 0) * HV_ROT
	for part, off in pairs(offsets) do
		if part.Parent then
			part.CFrame = handleCF * off
			part.LocalTransparencyModifier = 0
		end
	end
	local lensPos = lens and lens.Position or (camCF * CFrame.new(0.5, -0.3, -3)).Position
	local dir = lensPos - camCF.Position
	local hit = workspace:Raycast(camCF.Position, dir, rayParams)
	local origin = hit and (hit.Position - dir.Unit * 0.4) or lensPos
	rig.CFrame = CFrame.lookAt(origin, origin + camCF.LookVector)
	if bouncePart then bouncePart.CFrame = camCF * CFrame.new(0.45, -0.2, -1.3) end
	if beam and beam.Enabled then
		local f = chargeFactor()
		beam.Brightness = BASE_BEAM * f
		beam.Range = BASE_RANGE * (0.55 + 0.45 * f)
		if spill then spill.Brightness = BASE_SPILL * f end
		if bounce then bounce.Brightness = BASE_BOUNCE * f end
	end
	if wristband then
		local bc = player:GetAttribute("BandColor")
		if bc then for _, seg in ipairs(wristband) do seg.Color = bc; seg.Transparency = 0 end end
	end
	hideReal(true)
end

Tool.Equipped:Connect(function()
	local char = player.Character
	if not char then return end
	-- wait until the flashlight is actually gripped, so the hand is copied in its real holding pose
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local t0 = os.clock()
	while hand and not hand:FindFirstChild("RightGrip") and os.clock() - t0 < 1 do task.wait() end
	task.wait(0.1)
	if Tool.Parent ~= char then return end
	destroyAll()
	buildRig()
	buildViewModel(char)
	rayParams.FilterDescendantsInstances = { char, viewModel, fxFolder() }
	refresh()
	renderConn = RunService.RenderStepped:Connect(render)
	bindReload()
end)

Tool.Unequipped:Connect(function()
	destroyAll()
	hideReal(false)
end)
Tool.Destroying:Connect(destroyAll)

Tool.Activated:Connect(function()
	Remote:FireServer("ToggleLight")
end)
Tool:GetAttributeChangedSignal("On"):Connect(refresh)
