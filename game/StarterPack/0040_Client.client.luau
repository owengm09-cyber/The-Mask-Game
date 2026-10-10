-- Flashlight (client)
-- Your hand holding it in first person is drawn by StarterPlayerScripts.FirstPersonHands (camera > HeldViewModel).
-- This script makes the beam: it comes from the lens (the copy's "p" in first person, the real one otherwise)
-- and follows where you look. Click or tap to toggle. It runs on batteries: R (or D-pad up) loads a spare one.
-- (The old version, which drew its own full-size hand, is kept in ServerStorage.BeforeFirstPersonHands.)
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Tool   = script.Parent
local Remote = Tool:WaitForChild("Remote")
local Handle = Tool:WaitForChild("Handle")
local player = Players.LocalPlayer

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

-- the real prop's own glow is for everyone else; on your screen it's kept off so it doesn't double up with your beam
local function lightsOff()
	for _, d in ipairs(Tool:GetDescendants()) do
		if d:IsA("Light") or d:IsA("Beam") then d.Enabled = false end
	end
end

-- the lens to shine from: the first-person copy's when it's on screen, otherwise the real flashlight's
local function lensPart()
	local cam = workspace.CurrentCamera
	local vm = cam and cam:FindFirstChild("HeldViewModel")
	local p = vm and vm:FindFirstChild("p")
	if p then return p, true end
	return Tool:FindFirstChild("p"), false
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
	RunService:UnbindFromRenderStep("FlashlightBeam")
end

local function render()
	local cam = workspace.CurrentCamera
	if not cam or not rig then return end
	local camCF = cam.CFrame
	local lens, firstPerson = lensPart()
	if firstPerson or not lens then
		-- shine from the lens where you look; if the lens is poking into a wall, start just in front of the wall
		local lensPos = lens and lens.Position or (camCF * CFrame.new(0.5, -0.3, -3)).Position
		local dir = lensPos - camCF.Position
		local hit = workspace:Raycast(camCF.Position, dir, rayParams)
		local origin = hit and (hit.Position - dir.Unit * 0.4) or lensPos
		rig.CFrame = CFrame.lookAt(origin, origin + camCF.LookVector)
		if bouncePart then bouncePart.CFrame = camCF * CFrame.new(0.45, -0.2, -1.3) end
	else
		-- a cutscene or the escape camera: shine from the real flashlight, the way it points
		local along = lens.Position - Handle.Position
		local ahead = along.Magnitude > 0.01 and along.Unit or Handle.CFrame.LookVector
		rig.CFrame = CFrame.lookAt(lens.Position + ahead * 0.2, lens.Position + ahead * 2)
		if bouncePart then bouncePart.CFrame = CFrame.new(lens.Position - ahead * 0.6) end
	end
	if beam and beam.Enabled then
		local f = chargeFactor()
		beam.Brightness = BASE_BEAM * f
		beam.Range = BASE_RANGE * (0.55 + 0.45 * f)
		if spill then spill.Brightness = BASE_SPILL * f end
		if bounce then bounce.Brightness = BASE_BOUNCE * f end
	end
	lightsOff()
end

Tool.Equipped:Connect(function()
	local char = player.Character
	if not char then return end
	destroyAll()
	buildRig()
	rayParams.FilterDescendantsInstances = { char, fxFolder() }
	refresh()
	-- after FirstPersonHands has placed your hand (Camera + 2), so the beam leaves the lens where it's drawn
	RunService:BindToRenderStep("FlashlightBeam", Enum.RenderPriority.Camera.Value + 3, render)
	bindReload()
end)

Tool.Unequipped:Connect(function()
	destroyAll()
end)
Tool.Destroying:Connect(destroyAll)

Tool.Activated:Connect(function()
	Remote:FireServer("ToggleLight")
end)
Tool:GetAttributeChangedSignal("On"):Connect(refresh)
