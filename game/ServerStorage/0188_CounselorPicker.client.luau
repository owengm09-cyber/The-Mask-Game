-- CounselorPicker (client) — "Your Camper"
-- The CAMPER button / C key opens a camp registration card: a polaroid of your own camper (live 3D,
-- turning slowly), a Boy / Girl box to tick, and the 11 match colours. Colours someone in your ready
-- ring (or round) already wears are crossed out. Choices go to the server (CounselorLooks).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CounselorChoice")

-- must match ServerScriptService.Wristbands
local COLOURS = {
	{ "Red", Color3.fromRGB(235, 40, 40) },
	{ "Blue", Color3.fromRGB(40, 95, 255) },
	{ "Green", Color3.fromRGB(30, 185, 70) },
	{ "Yellow", Color3.fromRGB(255, 225, 40) },
	{ "Orange", Color3.fromRGB(255, 135, 20) },
	{ "Purple", Color3.fromRGB(145, 55, 225) },
	{ "Pink", Color3.fromRGB(255, 105, 190) },
	{ "Cyan", Color3.fromRGB(35, 225, 225) },
	{ "White", Color3.fromRGB(240, 240, 240) },
	{ "Lime", Color3.fromRGB(165, 255, 60) },
	{ "Brown", Color3.fromRGB(140, 85, 45) },
}

-- the card: an old camp registration form
local PAPER_TOP = Color3.fromRGB(236, 226, 199)
local PAPER_BOTTOM = Color3.fromRGB(213, 196, 157)
local INK = Color3.fromRGB(43, 36, 32)
local INK_SOFT = Color3.fromRGB(104, 90, 74)
local STAMP = Color3.fromRGB(158, 43, 37)
local POLAROID = Color3.fromRGB(245, 241, 231)
local TAPE = Color3.fromRGB(240, 232, 204)
local PHOTO = Color3.fromRGB(40, 56, 48) -- a night-time camp photo behind your camper
-- the HUD button matches the rest of the HUD
local HUD_INK = Color3.fromRGB(17, 18, 19)
local HUD_CREAM = Color3.fromRGB(230, 225, 210)
local HUD_RED = Color3.fromRGB(151, 45, 45)

local MARKER = Enum.Font.PermanentMarker
local TYPE = Enum.Font.SpecialElite
local HAND = Enum.Font.PatrickHand

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	for _, c in children or {} do c.Parent = o end
	return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function round() return new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) end
local function stroke(c, t, tr) return new("UIStroke", { Color = c, Thickness = t or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function text(props)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or INK
	props.Font = props.Font or TYPE
	return new("TextLabel", props)
end
local function line(parent, props)
	props.BorderSizePixel = 0
	props.BackgroundColor3 = props.BackgroundColor3 or INK
	props.Parent = parent
	return new("Frame", props)
end

local gui = new("ScreenGui", { Name = "CounselorPicker", ResetOnSpawn = false, DisplayOrder = 72, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
gui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------- HUD button
local openButton = new("TextButton", {
	Name = "CamperButton", Size = UDim2.fromOffset(150, 34), Position = UDim2.fromOffset(16, 98),
	BackgroundColor3 = HUD_INK, BackgroundTransparency = 0.08, BorderSizePixel = 0, AutoButtonColor = true,
	Text = "", Parent = gui,
}, { corner(3), stroke(HUD_RED, 1) })
local swatchMini = new("Frame", { Name = "Swatch", Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 12, 0.5, -7), BorderSizePixel = 0, Parent = openButton }, { round() })
text({ Name = "Label", Text = "CAMPER  [C]", Font = Enum.Font.Oswald, TextColor3 = HUD_CREAM, TextSize = 15, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = openButton })

---------------------------------------------------------------- the card
local shade = new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 8, 7), BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false, Parent = gui })
local card = new("Frame", {
	Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(780, 480),
	BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = shade,
}, {
	corner(3),
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(PAPER_TOP, PAPER_BOTTOM) }),
	stroke(Color3.fromRGB(120, 100, 70), 1, 0.4),
})
local cardScale = new("UIScale", { Parent = card })
-- printed form border just inside the edge
new("Frame", { Name = "FormBorder", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundTransparency = 1, Parent = card }, { stroke(INK, 1, 0.75) })

text({ Name = "Title", Text = "Your Camper", Font = MARKER, TextSize = 44, Position = UDim2.fromOffset(34, 22), Size = UDim2.fromOffset(420, 52), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
text({
	Name = "Help", Text = "Pick how you look. Your colour goes on your hat band, neckerchief, boots, wristband, badge and socks.",
	TextSize = 14, TextColor3 = INK_SOFT, TextWrapped = true, Position = UDim2.fromOffset(36, 76), Size = UDim2.fromOffset(470, 36),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card,
})
line(card, { Name = "Rule", Position = UDim2.fromOffset(34, 118), Size = UDim2.new(1, -68, 0, 2), BackgroundTransparency = 0.2 })

-- rubber stamp: whether you can change your camper right now
local stamp = new("Frame", {
	Name = "Stamp", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -170, 0, 58), Size = UDim2.fromOffset(150, 46),
	BackgroundTransparency = 1, Rotation = -7, Parent = card,
}, { corner(4), stroke(STAMP, 3, 0.15) })
local stampText = text({ Name = "Text", Text = "OPEN", Font = Enum.Font.Oswald, TextSize = 26, TextColor3 = STAMP, TextTransparency = 0.12, Size = UDim2.fromScale(1, 1), Rotation = -7, Parent = stamp })

local close = new("TextButton", {
	Name = "Close", Text = "X", Font = MARKER, TextSize = 26, TextColor3 = INK, AutoButtonColor = false,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 18), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = PAPER_TOP, BackgroundTransparency = 1, Modal = true, Parent = card,
}, { round(), stroke(INK, 2, 0.35) })

---------------------------------------------------------------- the polaroid
-- soft drop shadow under the photo
new("Frame", { Name = "Shadow", Position = UDim2.fromOffset(45, 146), Size = UDim2.fromOffset(250, 312), BackgroundColor3 = Color3.fromRGB(60, 45, 25), BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = card }, { corner(3) })
local polaroid = new("Frame", {
	Name = "Polaroid", Position = UDim2.fromOffset(40, 140), Size = UDim2.fromOffset(250, 312),
	BackgroundColor3 = POLAROID, BorderSizePixel = 0, Parent = card,
}, { corner(2), stroke(Color3.fromRGB(150, 135, 110), 1, 0.5) })
local view = new("ViewportFrame", {
	Name = "Photo", Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 1, -70),
	BackgroundColor3 = PHOTO, BorderSizePixel = 0, Ambient = Color3.fromRGB(95, 100, 105),
	LightColor = Color3.fromRGB(255, 244, 222), LightDirection = Vector3.new(-0.35, -0.6, 1), Parent = polaroid,
})
local world = new("WorldModel", { Parent = view })
local viewCam = new("Camera", { FieldOfView = 30, Parent = view })
view.CurrentCamera = viewCam
local caption = text({ Name = "Caption", Text = "", Font = MARKER, TextSize = 24, TextColor3 = INK, Position = UDim2.new(0, 12, 1, -54), Size = UDim2.new(1, -24, 0, 40), TextTruncate = Enum.TextTruncate.AtEnd, Parent = polaroid })
-- two strips of tape holding it to the card
for _, t in { { UDim2.fromOffset(18, 128), -32 }, { UDim2.fromOffset(250, 128), 28 } } do
	new("Frame", { Name = "Tape", Position = t[1], Size = UDim2.fromOffset(72, 22), Rotation = t[2], BackgroundColor3 = TAPE, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = card })
end

---------------------------------------------------------------- the form
local form = new("Frame", { Name = "Form", BackgroundTransparency = 1, Position = UDim2.fromOffset(330, 136), Size = UDim2.fromOffset(420, 320), Parent = card })
text({ Text = "Camper", TextSize = 18, TextColor3 = INK_SOFT, Size = UDim2.fromOffset(200, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = form })
local lookBoxes = {}
for i, look in { "Boy", "Girl" } do
	local b = new("TextButton", { Name = look, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset((i - 1) * 150, 30), Size = UDim2.fromOffset(130, 40), Parent = form })
	local box = new("Frame", { Name = "Box", Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = POLAROID, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = b }, { corner(2), stroke(INK, 2) })
	-- the tick: a marker X
	local mark = new("Frame", { Name = "Mark", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = box })
	for _, r in { 45, -45 } do
		local bar = line(mark, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 5), Rotation = r })
		corner(3).Parent = bar
	end
	text({ Name = "Word", Text = look, Font = TYPE, TextSize = 24, Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(88, 40), TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
	lookBoxes[look] = { button = b, mark = mark, box = box }
end
line(form, { Name = "Rule2", Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.7 })
text({ Text = "Colour", TextSize = 18, TextColor3 = INK_SOFT, Position = UDim2.fromOffset(0, 98), Size = UDim2.fromOffset(200, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = form })
local grid = new("Frame", { Name = "Colours", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 128), Size = UDim2.fromOffset(420, 170), Parent = form })
new("UIGridLayout", { CellSize = UDim2.fromOffset(62, 80), CellPadding = UDim2.fromOffset(9, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
local swatches = {}
for i, c in COLOURS do
	local cell = new("TextButton", { Name = c[1], LayoutOrder = i, Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Parent = grid })
	-- a cloth patch: darker rim, the colour, a stitched ring
	local h, s, v = c[2]:ToHSV()
	local patch = new("Frame", { Name = "Patch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(31, 6), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = c[2], BorderSizePixel = 0, Parent = cell }, {
		round(), stroke(Color3.fromHSV(h, s, v * 0.55), 3),
	})
	local stitches = new("Frame", { Name = "Stitches", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Parent = patch })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		line(stitches, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 18, 0.5, math.sin(a) * 18),
			Size = UDim2.fromOffset(5, 2), Rotation = math.deg(a) + 90, BackgroundColor3 = Color3.fromHSV(h, s * 0.35, math.min(1, v * 1.15 + 0.15)), BackgroundTransparency = 0.15,
		})
	end
	-- hand-drawn marker loop round the one you picked
	local loop = new("Frame", { Name = "Loop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(31, 29), Size = UDim2.fromOffset(62, 56), Rotation = -12, BackgroundTransparency = 1, Visible = false, Parent = cell }, { round(), stroke(INK, 2.5) })
	-- crossed out when someone in your group has it
	local strike = line(cell, { Name = "Strike", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(31, 29), Size = UDim2.fromOffset(58, 4), Rotation = -28, Visible = false })
	corner(2).Parent = strike
	local name = text({ Name = "Name", Text = c[1], Font = HAND, TextSize = 18, TextColor3 = INK_SOFT, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 22), Parent = cell })
	swatches[i] = { cell = cell, patch = patch, loop = loop, strike = strike, name = name }
end
local notice = text({ Name = "Notice", Text = "", TextSize = 15, TextColor3 = STAMP, Position = UDim2.fromOffset(0, 300), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = form })

---------------------------------------------------------------- state
local opened = false
local function groupKey(p)
	if p:GetAttribute("InRound") then return "Round" .. tostring(p:GetAttribute("RoundId")) end
	local z = p:GetAttribute("ReadyZone")
	if z then return "Zone" .. tostring(z) end
	return nil
end
local function takenColours()
	local taken = {}
	local k = groupKey(player)
	if not k then return taken end
	for _, o in Players:GetPlayers() do
		if o ~= player and groupKey(o) == k then
			local i = o:GetAttribute("BandIndex")
			if i then taken[i] = o.DisplayName end
		end
	end
	return taken
end
local function locked()
	return player:GetAttribute("InRound") == true and not (RunService:IsStudio() and #Players:GetPlayers() == 1)
end

local lastMine
local function refresh()
	local mine = player:GetAttribute("BandIndex")
	local look = player:GetAttribute("CounselorLook") or "Boy"
	local taken = takenColours()
	local lock = locked()
	for i, s in swatches do
		local isMine = i == mine
		local isTaken = taken[i] ~= nil and not isMine
		s.loop.Visible = isMine
		s.strike.Visible = isTaken
		s.patch.BackgroundTransparency = isTaken and 0.55 or 0
		s.name.Text = isTaken and "taken" or COLOURS[i][1]
		s.name.TextColor3 = isMine and INK or INK_SOFT
	end
	if mine ~= lastMine and mine and swatches[mine] and opened then
		-- the marker loop gets drawn round the new pick
		local loop = swatches[mine].loop
		loop.Size = UDim2.fromOffset(40, 36)
		TweenService:Create(loop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(62, 56) }):Play()
	end
	lastMine = mine
	for name, l in lookBoxes do l.mark.Visible = name == look end
	local c = mine and COLOURS[mine]
	swatchMini.BackgroundColor3 = c and c[2] or HUD_CREAM
	caption.Text = player.DisplayName
	stampText.Text = lock and "LOCKED" or "OPEN"
	stamp.Size = UDim2.fromOffset(lock and 170 or 120, 46)
	if lock and notice.Text == "" then notice.Text = "Locked until this match ends." end
	openButton.Visible = not lock
end

---------------------------------------------------------------- the photo: your own camper
local model, spin = nil, 0
local rebuildQueued = false
local function rebuildPreview()
	rebuildQueued = false
	if model then model:Destroy() model = nil end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local was = char.Archivable
	char.Archivable = true
	local ok, copy = pcall(function() return char:Clone() end)
	char.Archivable = was
	if not ok or not copy then return end
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("Sound") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.LocalTransparencyModifier = 0
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	copy.PrimaryPart = copy:FindFirstChild("HumanoidRootPart")
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	model = copy
end
local function queueRebuild()
	if rebuildQueued then return end
	rebuildQueued = true
	task.delay(0.15, function() if opened then rebuildPreview() else rebuildQueued = false end end)
end

local renderConn
local function setOpen(v)
	if v == opened then return end
	opened = v
	if v then
		shade.Visible = true
		notice.Text = ""
		lastMine = player:GetAttribute("BandIndex")
		refresh()
		rebuildPreview()
		-- the card slides up into place
		card.Position = UDim2.new(0.5, 0, 0.5, 40)
		shade.BackgroundTransparency = 1
		TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		TweenService:Create(shade, TweenInfo.new(0.2), { BackgroundTransparency = 0.3 }):Play()
		renderConn = RunService.RenderStepped:Connect(function(dt)
			spin += dt * 0.6
			if model and model.PrimaryPart then
				-- facing the camera, turning a little from side to side
				model:PivotTo(CFrame.Angles(0, math.sin(spin) * 0.6, 0))
			end
			-- framed from the knees up, like a photo
			viewCam.CFrame = CFrame.lookAt(Vector3.new(0, 1.1, -9.5), Vector3.new(0, 0.55, 0))
			-- keep the mouse free while the card is open (first person locks it to the centre)
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			UIS.MouseIconEnabled = true
		end)
	else
		shade.Visible = false
		if renderConn then renderConn:Disconnect() renderConn = nil end
		if model then model:Destroy() model = nil end
	end
end

openButton.Activated:Connect(function() setOpen(not opened) end)
close.Activated:Connect(function() setOpen(false) end)
close.MouseEnter:Connect(function() close.BackgroundTransparency = 0.6 end)
close.MouseLeave:Connect(function() close.BackgroundTransparency = 1 end)
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.C and not locked() then setOpen(not opened) end
	if input.KeyCode == Enum.KeyCode.Escape and opened then setOpen(false) end
end)
for look, l in lookBoxes do
	l.button.Activated:Connect(function()
		if locked() then refresh() return end
		-- tick straight away; the server confirms
		for other, o in lookBoxes do o.mark.Visible = other == look end
		remote:FireServer("Look", look)
	end)
end
for i, s in swatches do
	s.cell.Activated:Connect(function()
		if locked() then refresh() return end
		if takenColours()[i] then notice.Text = "Someone in your group already has " .. COLOURS[i][1] .. "." return end
		remote:FireServer("Colour", i)
	end)
end
remote.OnClientEvent:Connect(function(kind, ok, message)
	if kind ~= "Result" then return end
	notice.Text = ok and "" or tostring(message or "")
	refresh()
	queueRebuild()
end)

for _, a in { "BandIndex", "CounselorLook", "InRound", "ReadyZone", "RoundId" } do
	player:GetAttributeChangedSignal(a):Connect(function() refresh() if opened then queueRebuild() end end)
end
local function watchChar(char)
	char:GetAttributeChangedSignal("Look"):Connect(function() if opened then queueRebuild() end end)
	if opened then queueRebuild() end
end
player.CharacterAdded:Connect(watchChar)
if player.Character then watchChar(player.Character) end
Players.PlayerAdded:Connect(refresh)
Players.PlayerRemoving:Connect(function() task.defer(refresh) end)

-- under the rescue tasks panel during a (solo Studio) round, top left otherwise; the card scales to fit
local function layout()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	cardScale.Scale = math.clamp(math.min((v.X - 24) / 780, (v.Y - 24) / 480), 0.45, 1)
	openButton.Position = player:GetAttribute("InRound") and UDim2.fromOffset(16, 272) or UDim2.fromOffset(16, 98)
end
task.spawn(function()
	while gui.Parent do
		layout()
		-- other players' colours change as people join rings; keep the patches honest
		if opened then refresh() else openButton.Visible = not locked() swatchMini.BackgroundColor3 = player:GetAttribute("BandColor") or HUD_CREAM end
		task.wait(0.5)
	end
end)
refresh()
