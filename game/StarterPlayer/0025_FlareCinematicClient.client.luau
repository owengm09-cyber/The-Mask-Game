-- Emergency flare cinematic, played on every client when someone fires the meeting flare.
-- Shot 1: the caller raises the flare gun.  Shot 2: low angle tracking the flare into the sky.
-- Burst: blood-red flash + flickering EMERGENCY MEETING title.  Then the lights fail while the server seats everyone.
-- Horror dressing: letterbox, desaturated grade, vignette, heartbeat thuds, drone + sting.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("FlareCinematic")
local camp = workspace:WaitForChild("EmergencyCampsite")

local LAUNCH_SOUND = "rbxassetid://126697483821683" -- flare launch; swap here if you prefer another
local RAISE_START, RAISE_END = 0.12, 0.72
local FIRE_AT, APEX_AT = 0.85, 2.85
local SHOT1_END = 1.2
local FLARE_HEIGHT = 62
local MAX_PITCH = math.rad(60) -- the tracking shot never tilts past this, so it can't roll or stare straight up
local ARM_UP = math.rad(168)

---------------------------------------------------------------- UI (horror: letterbox, grade, vignette, splash, fade)
local CREAM = Color3.fromRGB(229, 225, 215)
local MUTED = Color3.fromRGB(152, 151, 145)
local BLOOD = Color3.fromRGB(190, 46, 51)

local DRONE_SOUND = "rbxassetid://9039981895" -- "Hellish" (APM Music) under the whole cinematic
local STING_SOUND = "rbxassetid://1846887425" -- "Evil Mind 9" (APM Music) on the flare burst
local THUD_SOUND = "rbxassetid://9119879867"  -- "Synth Whomps 9" (Pro Sound Effects) as a heartbeat

local gui = Instance.new("ScreenGui")
gui.Name = "FlareCinematic"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 60; gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play(); return tw
end

-- vignettes (black frame, and a red one that pulses with the heartbeat)
local function makeVignette(name, colour, z)
	local g = Instance.new("CanvasGroup")
	g.Name = name; g.BackgroundTransparency = 1; g.Size = UDim2.fromScale(1, 1); g.GroupTransparency = 1; g.ZIndex = z; g.Parent = gui
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(0.32, 1), 0 },
		{ UDim2.fromScale(0.68, 0), UDim2.fromScale(0.32, 1), 180 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.38), 90 },
		{ UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.38), 270 },
	}
	for _, sd in ipairs(sides) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0; f.BackgroundColor3 = colour; f.Position = sd[1]; f.Size = sd[2]; f.Parent = g
		local grad = Instance.new("UIGradient")
		grad.Rotation = sd[3]
		grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.65), NumberSequenceKeypoint.new(1, 1) })
		grad.Parent = f
	end
	return g
end
local vignette = makeVignette("Vignette", Color3.new(0, 0, 0), 2)
local bloodVignette = makeVignette("BloodVignette", Color3.fromRGB(70, 0, 4), 3)

-- letterbox bars
local barTop = Instance.new("Frame")
barTop.Name = "LetterboxTop"; barTop.BorderSizePixel = 0; barTop.BackgroundColor3 = Color3.new(0, 0, 0)
barTop.Size = UDim2.new(1, 0, 0, 0); barTop.ZIndex = 8; barTop.Parent = gui
local barBottom = barTop:Clone(); barBottom.Name = "LetterboxBottom"; barBottom.AnchorPoint = Vector2.new(0, 1)
barBottom.Position = UDim2.fromScale(0, 1); barBottom.Parent = gui

local fade = Instance.new("Frame")
fade.Name = "Fade"; fade.BackgroundColor3 = Color3.new(0, 0, 0); fade.BackgroundTransparency = 1; fade.BorderSizePixel = 0
fade.Size = UDim2.fromScale(1, 1); fade.ZIndex = 20; fade.Parent = gui

-- splash
local function spaced(text) return (text:gsub(".", "%0 "):gsub("%s+$", "")) end
local splash = Instance.new("CanvasGroup")
splash.Name = "Splash"; splash.AnchorPoint = Vector2.new(0.5, 0.5); splash.Position = UDim2.fromScale(0.5, 0.5)
splash.Size = UDim2.new(0.9, 0, 0.36, 0); splash.BackgroundTransparency = 1; splash.GroupTransparency = 1; splash.ZIndex = 15; splash.Parent = gui
local push = Instance.new("UIScale"); push.Parent = splash
local function label(name, text, font, colour, pos, size, z)
	local l = Instance.new("TextLabel")
	l.Name = name; l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = pos; l.Size = size
	l.Font = font; l.TextScaled = true; l.Text = text; l.TextColor3 = colour; l.ZIndex = z or 16; l.Parent = splash
	return l
end
local kicker = label("Kicker", "— SIGNAL FIRED —", Enum.Font.SpecialElite, BLOOD, UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.6, 0.13))
local ghost = label("TitleGhost", spaced("EMERGENCY") .. "   " .. spaced("MEETING"), Enum.Font.Oswald, BLOOD, UDim2.fromScale(0.5, 0.45), UDim2.fromScale(1, 0.42), 16)
ghost.TextTransparency = 0.3
local title = label("Title", ghost.Text, Enum.Font.Oswald, CREAM, UDim2.fromScale(0.5, 0.45), UDim2.fromScale(1, 0.42), 17)
local tStroke = Instance.new("UIStroke"); tStroke.Color = Color3.new(0, 0, 0); tStroke.Thickness = 1.5; tStroke.Parent = title
local ruleTop = Instance.new("Frame"); ruleTop.Name = "RuleTop"; ruleTop.BorderSizePixel = 0; ruleTop.BackgroundColor3 = BLOOD
ruleTop.AnchorPoint = Vector2.new(0.5, 0.5); ruleTop.Position = UDim2.fromScale(0.5, 0.22); ruleTop.Size = UDim2.new(0, 0, 0, 2); ruleTop.ZIndex = 16; ruleTop.Parent = splash
local ruleBottom = ruleTop:Clone(); ruleBottom.Name = "RuleBottom"; ruleBottom.Position = UDim2.fromScale(0.5, 0.7); ruleBottom.Parent = splash
local sub = label("Caller", "", Enum.Font.SpecialElite, CREAM, UDim2.fromScale(0.5, 0.84), UDim2.fromScale(0.75, 0.15))

local glitchUntil = 0
RunService.RenderStepped:Connect(function()
	if not splash.Visible then return end
	if os.clock() < glitchUntil then
		ghost.Position = UDim2.new(0.5, math.random(-6, 6), 0.45, math.random(-3, 3))
		ghost.TextTransparency = 0.15 + math.random() * 0.5
	else
		ghost.Position = UDim2.new(0.5, 3, 0.45, 1)
		ghost.TextTransparency = 0.55
	end
end)

local function flicker(obj, prop, steps)
	task.spawn(function()
		for _, st in ipairs(steps) do obj[prop] = st[1]; task.wait(st[2]) end
	end)
end

local function showSplash(callerName)
	splash.Visible = true
	sub.Text = string.upper(callerName) .. " LIT THE FLARE — GATHER AT THE FIRE"
	push.Scale = 1
	ruleTop.Size = UDim2.new(0, 0, 0, 2); ruleBottom.Size = UDim2.new(0, 0, 0, 2)
	-- comes on like a failing bulb
	flicker(splash, "GroupTransparency", { { 0.2, 0.05 }, { 0.9, 0.07 }, { 0.15, 0.05 }, { 0.75, 0.08 }, { 0, 0 } })
	glitchUntil = os.clock() + 1.1
	tween(ruleTop, 0.6, { Size = UDim2.new(0.55, 0, 0, 2) })
	tween(ruleBottom, 0.6, { Size = UDim2.new(0.55, 0, 0, 2) })
	tween(push, 2.2, { Scale = 1.06 }, Enum.EasingStyle.Linear)
end
local function hideSplash()
	flicker(splash, "GroupTransparency", { { 0.6, 0.06 }, { 0.1, 0.05 }, { 1, 0 } })
	task.delay(0.2, function() splash.Visible = false end)
end

-- sound helpers + mood
local function playSound(id, volume, speed)
	local snd = Instance.new("Sound")
	snd.SoundId = id; snd.Volume = volume or 0.8; snd.PlaybackSpeed = speed or 1
	snd.Parent = SoundService
	snd:Play()
	task.delay(9, function() snd:Destroy() end)
	return snd
end
local function heartbeat(strength)
	playSound(THUD_SOUND, 0.9 * strength, 0.85)
	task.delay(0.22, function() playSound(THUD_SOUND, 0.55 * strength, 1.05) end)
	bloodVignette.GroupTransparency = 0.25
	tween(bloodVignette, 0.55, { GroupTransparency = 1 })
end

local grade, drone
local function startMood()
	gui.Enabled = true
	fade.BackgroundTransparency = 1
	splash.Visible = false
	tween(barTop, 0.45, { Size = UDim2.new(1, 0, 0.11, 0) })
	tween(barBottom, 0.45, { Size = UDim2.new(1, 0, 0.11, 0) })
	tween(vignette, 0.45, { GroupTransparency = 0.05 })
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "FlareCinematicGrade"; grade.Parent = Lighting
	tween(grade, 0.45, { Saturation = -0.6, Contrast = 0.2, Brightness = -0.04, TintColor = Color3.fromRGB(222, 228, 238) })
	drone = playSound(DRONE_SOUND, 0, 1)
	tween(drone, 0.8, { Volume = 0.55 })
	heartbeat(1)
	task.delay(0.62, function() heartbeat(1) end)
end
local function endMood()
	tween(barTop, 0.4, { Size = UDim2.new(1, 0, 0, 0) })
	tween(barBottom, 0.4, { Size = UDim2.new(1, 0, 0, 0) })
	tween(vignette, 0.5, { GroupTransparency = 1 })
	if grade then
		local g = grade; grade = nil
		tween(g, 0.6, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
		task.delay(0.7, function() g:Destroy() end)
	end
	if drone then
		local d = drone; drone = nil
		tween(d, 0.8, { Volume = 0 })
		task.delay(0.9, function() d:Stop() end)
	end
end
local function blinkOut()
	-- the lights fail before the cut to the campfire
	flicker(fade, "BackgroundTransparency", { { 0.15, 0.06 }, { 0.85, 0.09 }, { 0.05, 0.05 }, { 0.6, 0.07 }, { 0, 0 } })
end

---------------------------------------------------------------- effects
local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"



local function muzzleFlash(pos)
	local f = Instance.new("Part")
	f.Shape = Enum.PartType.Ball; f.Material = Enum.Material.Neon; f.Color = Color3.fromRGB(255, 190, 120)
	f.Anchored = true; f.CanCollide = false; f.CanQuery = false; f.CanTouch = false; f.CastShadow = false
	f.Size = Vector3.new(0.3, 0.3, 0.3); f.Position = pos; f.Parent = workspace
	local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 150, 90); l.Range = 18; l.Brightness = 6; l.Parent = f
	tween(f, 0.18, { Size = Vector3.new(1.6, 1.6, 1.6), Transparency = 1 })
	tween(l, 0.3, { Brightness = 0 })
	local smoke = emitter(f, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(170, 165, 160)), Lifetime = NumberRange.new(1, 1.8),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(60, 60), Rate = 0, Acceleration = Vector3.new(0, 1.5, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40) })
	smoke:Emit(14)
	task.delay(2.5, function() f:Destroy() end)
end

local function launchFlare(from, onApex)
	local flare = Instance.new("Part")
	flare.Name = "EmergencyFlare"; flare.Shape = Enum.PartType.Ball; flare.Material = Enum.Material.Neon
	flare.Color = Color3.fromRGB(255, 62, 40); flare.Size = Vector3.new(0.6, 0.6, 0.6)
	flare.Anchored = true; flare.CanCollide = false; flare.CanQuery = false; flare.CanTouch = false; flare.CastShadow = false
	flare.Position = from; flare.Parent = workspace
	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 60, 40); light.Range = 28; light.Brightness = 4; light.Shadows = false; light.Parent = flare
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(-0.2, 0, 0); a0.Parent = flare
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0.2, 0, 0); a1.Parent = flare
	local trail = Instance.new("Trail"); trail.Attachment0 = a0; trail.Attachment1 = a1; trail.Lifetime = 0.7; trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 210, 140), Color3.fromRGB(255, 60, 40))
	trail.Transparency = NumberSequence.new(0, 1); trail.FaceCamera = true; trail.Parent = flare
	local sparks = emitter(flare, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(255, 70, 40)),
		LightEmission = 1, Lifetime = NumberRange.new(0.3, 0.7), Rate = 90, Speed = NumberRange.new(3, 9), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }), Drag = 3, Acceleration = Vector3.new(0, -14, 0) })
	local smoke = emitter(flare, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(150, 140, 135)), Lifetime = NumberRange.new(2, 3.5),
		Rate = 40, Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30) })

	local drift = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	local apex = from + drift + Vector3.new(0, FLARE_HEIGHT, 0)
	tween(flare, APEX_AT - FIRE_AT, { Position = apex }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(APEX_AT - FIRE_AT, function()
		if not flare.Parent then return end
		flare.Size = Vector3.new(1.2, 1.2, 1.2)
		light.Range = 60; light.Brightness = 12
		tween(light, 1.4, { Brightness = 5 })
		local burst = emitter(flare, { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 220, 160), Color3.fromRGB(255, 50, 40)),
			LightEmission = 1, Lifetime = NumberRange.new(0.8, 1.6), Rate = 0, Speed = NumberRange.new(18, 32), SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) }), Drag = 2, Acceleration = Vector3.new(0, -10, 0) })
		burst:Emit(120)
		sparks.Rate = 50; smoke.Rate = 25
		if onApex then onApex(flare) end
		tween(flare, 9, { Position = apex - Vector3.new(0, 22, 0) }, Enum.EasingStyle.Linear)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not flare.Parent then conn:Disconnect() return end
			local t = os.clock() - t0
			if t > 1.4 then light.Brightness = (5 + math.sin(t * 23) * 0.8 + math.random() * 0.6) * math.clamp(1 - (t - 6) / 3, 0, 1) end
		end)
		task.delay(8, function() sparks.Rate = 0; smoke.Rate = 0; tween(flare, 1, { Transparency = 1 }) end)
		task.delay(11, function() conn:Disconnect(); flare:Destroy() end)
	end)
	return flare
end

local function redTint()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FlareTint"; cc.TintColor = Color3.fromRGB(255, 135, 125); cc.Brightness = 0.04; cc.Contrast = 0.14
	cc.Parent = Lighting
	tween(cc, 2.6, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	task.delay(2.8, function() cc:Destroy() end)
end

---------------------------------------------------------------- pose
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function poseCaller(char, t0, duration)
	local shoulder = char:FindFirstChild("RightUpperArm") and char.RightUpperArm:FindFirstChild("RightShoulder")
	local elbow = char:FindFirstChild("RightLowerArm") and char.RightLowerArm:FindFirstChild("RightElbow")
	local wrist = char:FindFirstChild("RightHand") and char.RightHand:FindFirstChild("RightWrist")
	local r6 = char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Right Shoulder")
	local conn
	conn = RunService.Stepped:Connect(function()
		local t = os.clock() - t0
		if t > duration then conn:Disconnect() return end
		local up = smooth((t - RAISE_START) / (RAISE_END - RAISE_START)) * (1 - smooth((t - (duration - 0.9)) / 0.7))
		local kick = (t > FIRE_AT and t < FIRE_AT + 0.25) and math.sin((t - FIRE_AT) / 0.25 * math.pi) * math.rad(10) or 0
		local a = ARM_UP * up + kick
		if shoulder then shoulder.Transform = CFrame.Angles(a, 0, 0) end
		if elbow then elbow.Transform = CFrame.new() end
		if wrist then wrist.Transform = CFrame.new() end
		if r6 then r6.Transform = CFrame.Angles(0, 0, a) end
	end)
end

---------------------------------------------------------------- cinematic
local playing = false
remote.OnClientEvent:Connect(function(callerUserId, duration)
	if playing then return end
	playing = true
	duration = duration or 4.9
	local caller = Players:GetPlayerByUserId(callerUserId)
	local callerName = caller and caller.DisplayName or "A survivor"
	local char = caller and caller.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local marker = camp:FindFirstChild("FlareSpawn")
	local rootCF = root and root.CFrame or (marker and marker.CFrame) or CFrame.new(160, 3, -10)
	rootCF = CFrame.new(rootCF.Position) * CFrame.Angles(0, select(2, rootCF:ToEulerAnglesYXZ()), 0)

	-- put away anything we're holding (the flare gun stays in the caller's hand)
	local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if myHum and player ~= caller then myHum:UnequipTools() end

	-- hide the rest of the HUD while the cinematic plays
	local hiddenGuis = {}
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then g.Enabled = false; table.insert(hiddenGuis, g) end
	end
	local cam = workspace.CurrentCamera
	local prevFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	startMood()
	local t0 = os.clock()
	if char then poseCaller(char, t0, duration - 0.4) end

	local flare
	local focus = rootCF.Position + Vector3.new(0, 2, 0)
	local shake = 0
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { char, player.Character }

	-- choose camera spots with a clear view of the whole caller and of the sky (the flare spawn sits at a treeline)
	local head = rootCF.Position + Vector3.new(0, 3, 0)
	local chest = rootCF.Position + Vector3.new(0, 0.6, 0)
	local function chooseSpot(dists, height, prefer, skyWeight)
		local best, bestScore = nil, -math.huge
		for step = 0, 23 do
			local a = step / 24 * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			for _, d in ipairs(dists) do
				for _, hgt in ipairs({ height, height + 1.2 }) do
					local pos = rootCF.Position + dir * d + Vector3.new(0, hgt, 0)
					local score = dir:Dot(prefer) * 1.2
					if not workspace:Raycast(head, pos - head, rp) then score += 2.5 end
					if not workspace:Raycast(chest, pos - chest, rp) then score += 2.5 end
					if not workspace:Raycast(pos, Vector3.new(0, 45, 0), rp) then score += 2 * skyWeight end
					if not workspace:Raycast(pos, (head + Vector3.new(0, 40, 0)) - pos, rp) then score += 2 * skyWeight end
					if score > bestScore then best, bestScore = pos, score end
				end
			end
		end
		return best
	end
	local front = rootCF.LookVector
	local spot1 = chooseSpot({ 6.5, 7.5, 8.5 }, 1.0, front, 0.25)
	local spot2 = chooseSpot({ 11, 13.5, 16 }, 1.6, front, 1)

	RunService:BindToRenderStep("FlareCinematicCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local t = os.clock() - t0
		if t < SHOT1_END then
			local k = smooth(t / SHOT1_END)
			local look = rootCF.Position + Vector3.new(0, 1.6 + 2.2 * k, 0)
			local pos = spot1:Lerp(look, 0.12 * k) + Vector3.new(0, 0.4 * k, 0)
			cam.FieldOfView = 50
			cam.CFrame = CFrame.lookAt(pos, look)
		else
			local target = flare and flare.Parent and flare.Position or (rootCF.Position + Vector3.new(0, 8, 0))
			focus = focus:Lerp(target, math.min(1, dt * 6))
			local pos = spot2
			cam.FieldOfView = 70
			local dir = focus - pos
			local flat = Vector3.new(dir.X, 0, dir.Z)
			if flat.Magnitude > 0.1 then
				local pitch = math.atan2(dir.Y, flat.Magnitude)
				if pitch > MAX_PITCH then focus = pos + flat.Unit * math.cos(MAX_PITCH) * 10 + Vector3.new(0, math.sin(MAX_PITCH) * 10, 0) end
			end
			shake = math.max(0, shake - dt * 2.5)
			local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake
			cam.CFrame = CFrame.lookAt(pos + jitter, focus)
		end
		-- the caller's own body can be hidden by first-person; show it for the cinematic
		if char then
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then d.LocalTransparencyModifier = 0 end
			end
		end
	end)

	task.delay(FIRE_AT, function()
		local tool = char and char:FindFirstChildOfClass("Tool")
		local handle = tool and tool:FindFirstChild("Handle")
		local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
		local muzzle = (handle and handle.Position or (hand and hand.Position) or rootCF.Position + Vector3.new(1, 4, 0)) + Vector3.new(0, 1.1, 0)
		muzzleFlash(muzzle)
		playSound(LAUNCH_SOUND, 0.9, 1)
		flare = launchFlare(muzzle, function()
			shake = 0.45
			redTint()
			showSplash(callerName)
			playSound(STING_SOUND, 0.85, 1)
			task.delay(0.55, function() heartbeat(0.8) end)
			task.delay(1.05, function() heartbeat(0.9) end)
			task.delay(1.5, function() heartbeat(1) end)
		end)
	end)
	task.delay(APEX_AT + 1.6, hideSplash)
	task.delay(duration - 0.45, blinkOut)
	task.delay(duration + 0.15, function()
		RunService:UnbindFromRenderStep("FlareCinematicCam")
		cam.FieldOfView = prevFov
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
		for _, g in ipairs(hiddenGuis) do if g.Parent then g.Enabled = true end end
		endMood()
		tween(fade, 0.5, { BackgroundTransparency = 1 })
		task.delay(0.55, function() gui.Enabled = false; playing = false end)
	end)
end)
