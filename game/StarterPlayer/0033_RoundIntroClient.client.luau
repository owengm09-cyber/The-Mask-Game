-- RoundIntroClient: the few seconds at the start of a round, after the camper picker closes.
-- ReadyQueueServer places everyone at their spawn point and fires Remotes.RoundIntro. Then, on this machine:
--   1. fade up from black on a wide shot of your camper standing at the spawn, the camera drifting round
--   2. a close-up from the front while your camper looks left, then right, then ahead (the server turns the
--      neck and waist, so everyone sees it)
--   3. the camera swings round behind them and pushes in until you're looking out of their eyes: first person
-- Controls and the HUD come back when the camera reaches first person. The camera stays in first person until
-- you zoom out yourself (mouse wheel, O, or a pinch), then the usual zoom range is back.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local p = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RoundIntro")

local gui = Instance.new("ScreenGui")
gui.Name = "RoundIntro"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.Enabled = false
gui.Parent = p:WaitForChild("PlayerGui")
local function new(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local black = new("Frame", gui, { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
-- letterbox bars, so it reads as a shot, not gameplay
local barTop = new("Frame", gui, { Name = "BarTop", Size = UDim2.new(1, 0, 0.11, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
local barBottom = new("Frame", gui, { Name = "BarBottom", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.11, 0),
	BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
-- a lower third: the time, then your camper's colour
local caption = new("TextLabel", barBottom, { Name = "Caption", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 48, 0.5, 0), Size = UDim2.new(0.6, 0, 0, 30),
	BackgroundTransparency = 1, Font = Enum.Font.SpecialElite, TextSize = 22, TextColor3 = Color3.fromRGB(232, 229, 218), TextXAlignment = Enum.TextXAlignment.Left,
	TextTransparency = 1, Text = "" })

local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), goal)
	tw:Play()
	return tw
end
-- hold the camper still for the intro: their root is anchored on this machine only (their physics runs here)
local function freeze(root, h, on)
	if not root.Parent then return end
	root.Anchored = on
	if not on then root.AssemblyLinearVelocity = Vector3.zero end
	if h.Parent then h.AutoRotate = not on end
end

local running = 0 -- intro token: a newer intro (or a death) cancels an older one
-- after the intro: hold first person (max zoom 0.5) until the player zooms out themselves
local UIS = game:GetService("UserInputService")
local held = nil -- {min, max} to go back to
local function releaseFirstPerson()
	if not held then return end
	p.CameraMinZoomDistance, p.CameraMaxZoomDistance = held[1], held[2]
	held = nil
end
UIS.InputChanged:Connect(function(input)
	if held and input.UserInputType == Enum.UserInputType.MouseWheel and input.Position.Z < 0 then releaseFirstPerson() end
end)
UIS.InputBegan:Connect(function(input, processed)
	if held and not processed and input.KeyCode == Enum.KeyCode.O then releaseFirstPerson() end
end)
UIS.TouchPinch:Connect(function(_, scale)
	if held and scale < 0.9 then releaseFirstPerson() end
end)
p:GetAttributeChangedSignal("InRound"):Connect(function() if not p:GetAttribute("InRound") then releaseFirstPerson() end end)
local hidden = {}
local function hideHud()
	for _, g in p.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then hidden[g] = true g.Enabled = false end
	end
end
local function showHud()
	for g in hidden do if g.Parent then g.Enabled = true end end
	hidden = {}
end

local function play(data)
	running += 1
	local token = running
	local char = p.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	if not (h and root and head) then return end
	local cam = workspace.CurrentCamera
	hideHud()
	gui.Enabled = true
	black.BackgroundTransparency = 0
	barTop.Size = UDim2.new(1, 0, 0.11, 0)
	barBottom.Size = UDim2.new(1, 0, 0.11, 0)
	releaseFirstPerson()
	local oldMin, oldMax = p.CameraMinZoomDistance, p.CameraMaxZoomDistance
	local oldFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local alive = true
	local died = h.Died:Connect(function() alive = false end)
	local function stillOn() return token == running and alive and char.Parent ~= nil end
	-- behind the black: wait for the move to the spawn point to arrive here
	if data and data.spawn then
		local t = os.clock()
		while (root.Position - data.spawn.Position).Magnitude > 12 and os.clock() - t < 1.5 do RunService.RenderStepped:Wait() end
		-- let them land on the spawn before pinning them there
		local t2 = os.clock()
		while h:GetState() == Enum.HumanoidStateType.Freefall and os.clock() - t2 < 1 do RunService.RenderStepped:Wait() end
	end
	-- set them exactly on the ground before pinning them: pinned a moment too early (before they had dropped
	-- onto the pad) they would hang in the air for the whole intro
	do
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { char }
		rp.RespectCanCollide = true
		local hit = workspace:Raycast(root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), rp)
		if hit then
			local want = hit.Position.Y + h.HipHeight + root.Size.Y / 2
			root.CFrame += Vector3.new(0, want - root.Position.Y, 0)
		end
	end
	freeze(root, h, true)

	-- everything is framed off where the camper stands and faces
	local base = data and data.spawn and CFrame.new(root.Position) * (data.spawn - data.spawn.Position) or root.CFrame
	local face = base.LookVector
	local right = base.RightVector
	local function headPos() return head.Position end

	-- a camera path driven every frame: from(t) -> to(t) between two moments
	local shot
	local bodyParts = {}
	for _, d in char:GetDescendants() do if d:IsA("BasePart") then table.insert(bodyParts, d) end end
	local conn = RunService.RenderStepped:Connect(function()
		-- if they were in first person before, the camera left their body hidden: show it for the shots
		if shot then for _, d in bodyParts do d.LocalTransparencyModifier = 0 end end
		if shot then
			local a = math.clamp((os.clock() - shot.t0) / shot.len, 0, 1)
			a = shot.ease and (a * a * (3 - 2 * a)) or a
			local eye = shot.eye0:Lerp(shot.eye1, a)
			local at = headPos() + shot.aim0:Lerp(shot.aim1, a)
			cam.CFrame = CFrame.lookAt(eye, at)
			cam.FieldOfView = shot.fov0 + (shot.fov1 - shot.fov0) * a
		end
	end)
	local function setShot(len, eye0, eye1, aim0, aim1, fov0, fov1, ease)
		shot = { t0 = os.clock(), len = len, eye0 = eye0, eye1 = eye1, aim0 = aim0, aim1 = aim1, fov0 = fov0, fov1 = fov1, ease = ease }
	end
	local function wait(t)
		local t1 = os.clock() + t
		while os.clock() < t1 do
			if not stillOn() then return false end
			RunService.RenderStepped:Wait()
		end
		return true
	end
	local function finish(reachedFirstPerson)
		if conn then conn:Disconnect() conn = nil end
		died:Disconnect()
		if token ~= running then return end
		cam.FieldOfView = oldFov
		if cam.CameraType == Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Custom
			if h.Parent then cam.CameraSubject = h end
		end
		if not reachedFirstPerson then p.CameraMinZoomDistance, p.CameraMaxZoomDistance = oldMin, oldMax end
		showHud()
		freeze(root, h, false)
		tween(barTop, 0.4, { Size = UDim2.new(1, 0, 0, 0) })
		tween(barBottom, 0.4, { Size = UDim2.new(1, 0, 0, 0) })
		tween(caption, 0.3, { TextTransparency = 1 })
		task.delay(0.45, function() if token == running then gui.Enabled = false end end)
	end

	-- 1. wide: from behind one shoulder, drifting round to the side, while the picture fades up
	local hp = headPos()
	setShot(2.7,
		hp - face * 16 + right * 9 + Vector3.new(0, 7, 0),
		hp - face * 6 + right * 15 + Vector3.new(0, 4, 0),
		Vector3.new(0, -1.2, 0), Vector3.new(0, -0.6, 0), 55, 50, true)
	tween(black, 1.0, { BackgroundTransparency = 1 })
	local clockHour = game:GetService("Lighting"):GetAttribute("GameTimeHours")
	local hour = clockHour and math.floor(clockHour) or 8
	caption.Text = string.format("%d:00 %s  —  THE FIRST DAY", hour % 12 == 0 and 12 or hour % 12, hour < 12 and "AM" or "PM")
	task.delay(0.6, function() if token == running then tween(caption, 0.6, { TextTransparency = 0 }) end end)
	if not wait(2.7) then finish(false) return end

	-- 2. close-up from the front while they look round (the head turns are timed on the server: 2.7s to 6.3s)
	tween(caption, 0.4, { TextTransparency = 1 })
	setShot(3.3,
		hp + face * 6.5 + right * 1.2 + Vector3.new(0, 0.3, 0),
		hp + face * 4.6 + right * 0.6 + Vector3.new(0, 0.15, 0),
		Vector3.new(0, -0.1, 0), Vector3.new(0, 0, 0), 40, 36, false)
	local band = p:GetAttribute("BandName")
	if band then
		task.delay(0.8, function()
			if token ~= running then return end
			caption.Text = string.upper(band) .. "  —  " .. string.upper(p.DisplayName)
			tween(caption, 0.5, { TextTransparency = 0 })
		end)
	end
	if not wait(3.3) then finish(false) return end

	-- 3. round behind them, over the shoulder, ready to push in
	tween(caption, 0.3, { TextTransparency = 1 })
	setShot(1.1,
		cam.CFrame.Position,
		hp - face * 11 + Vector3.new(0, 3.2, 0),
		Vector3.new(0, 0, 0), face * 6 + Vector3.new(0, -0.6, 0), cam.FieldOfView, oldFov, true)
	if not wait(1.1) then finish(false) return end

	-- 4. hand over to the normal camera and push in to first person (zoom limits squeezed from 11 to 0.5)
	if conn then conn:Disconnect() conn = nil end
	shot = nil
	p.CameraMinZoomDistance = 11
	p.CameraMaxZoomDistance = 11
	cam.CameraType = Enum.CameraType.Custom
	cam.CameraSubject = h
	tween(barTop, 0.9, { Size = UDim2.new(1, 0, 0, 0) })
	tween(barBottom, 0.9, { Size = UDim2.new(1, 0, 0, 0) })
	local z = Instance.new("NumberValue")
	z.Value = 11
	z.Changed:Connect(function(v)
		if token ~= running then return end
		p.CameraMaxZoomDistance = math.max(0.5, v)
		p.CameraMinZoomDistance = math.max(0.5, v)
	end)
	local push = tween(z, 1.2, { Value = 0.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	push.Completed:Wait()
	z:Destroy()
	if token == running then
		-- first person now, and it stays that way until they zoom out themselves
		p.CameraMinZoomDistance = math.min(oldMin, 0.5)
		p.CameraMaxZoomDistance = 0.5
		held = { oldMin, oldMax }
	end
	finish(true)
end

remote.OnClientEvent:Connect(function(data)
	task.spawn(play, data)
end)
-- a new character (death, respawn) ends any intro still running
p.CharacterAdded:Connect(function()
	releaseFirstPerson()
	if gui.Enabled then running += 1 showHud() gui.Enabled = false end
end)
