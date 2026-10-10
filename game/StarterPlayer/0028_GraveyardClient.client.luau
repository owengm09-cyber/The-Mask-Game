-- Cemetery task (Task17) on the client: notices, the "shovel in hand" chip, and the Fisch-style dig mini-game.
-- Digging: a round dot with a shovel in it pops up somewhere on screen; tap it, it jumps somewhere else.
-- 4 taps clear a layer, 3 layers open the coffin. The server counts every tap.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local p = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("GraveyardDig")

local PAPER = Color3.fromRGB(232, 229, 218)
local INK = Color3.fromRGB(15, 17, 17)
local RED = Color3.fromRGB(196, 34, 40)
local WOOD = Color3.fromRGB(196, 140, 84)
local STEEL = Color3.fromRGB(205, 208, 212)
local OUTLINE = Color3.fromRGB(14, 12, 12)
local TAP_GAP = 0.17
local rng = Random.new()

local gui = Instance.new("ScreenGui")
gui.Name = "GraveyardHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 58
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = p:WaitForChild("PlayerGui")

local function new(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return new("UICorner", o, { CornerRadius = r or UDim.new(1, 0) }) end
local function stroke(o, c, t) return new("UIStroke", o, { Color = c, Thickness = t or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

---------------------------------------------------------------- the shovel icon (drawn, so it scales crisply)
-- red pointed blade, wooden shaft, D-grip, tilted like a shovel leaning against something
local function shovelIcon(parent, size, rotation)
	local box = new("Frame", parent, { Name = "ShovelIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = size, Rotation = rotation or -32 })
	local function piece(name, x, y, w, h, color, z, round)
		local f = new("Frame", box, { Name = name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z or 1 })
		if round then corner(f, round) end
		return f
	end
	-- D-grip: red yoke with a wooden crossbar
	local yoke = piece("Grip", 0.5, 0.02, 0.27, 0.13, RED, 3, UDim.new(0.45, 0))
	yoke.BackgroundTransparency = 1
	stroke(yoke, RED, 3.2)
	piece("GripBar", 0.5, 0.012, 0.3, 0.045, WOOD, 4, UDim.new(1, 0))
	piece("Socket", 0.5, 0.135, 0.11, 0.06, RED, 3, UDim.new(0.2, 0))
	-- shaft
	local shaft = piece("Shaft", 0.5, 0.18, 0.085, 0.4, WOOD, 2)
	stroke(shaft, OUTLINE, 1.2)
	piece("Ferrule", 0.5, 0.56, 0.11, 0.035, STEEL, 3)
	piece("Neck", 0.5, 0.59, 0.1, 0.09, RED, 3)
	-- blade: steel rim peeking out under the red, squared shoulders, rounded point
	piece("BladeEdge", 0.5, 0.67, 0.36, 0.3, STEEL, 2, UDim.new(0.5, 0))
	piece("Blade", 0.5, 0.655, 0.36, 0.28, RED, 3, UDim.new(0.5, 0))
	piece("Shoulders", 0.5, 0.655, 0.36, 0.13, RED, 3)
	local shine = piece("Shine", 0.42, 0.69, 0.04, 0.17, Color3.new(1, 1, 1), 4, UDim.new(1, 0))
	shine.BackgroundTransparency = 0.45
	shine.Rotation = 18
	-- ink outlines on the outer pieces only (an outline on the inner blade pieces would draw seams across it)
	local skip = { Grip = true, Shaft = true, Blade = true, Shoulders = true, Shine = true }
	for _, f in box:GetChildren() do
		if f:IsA("Frame") and not skip[f.Name] then stroke(f, OUTLINE, 1.2) end
	end
	return box
end

---------------------------------------------------------------- notices + the shovel chip
local noticeLabel = new("TextLabel", gui, { Name = "Notice", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7),
	Size = UDim2.fromOffset(560, 34), BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 22, TextColor3 = PAPER,
	TextStrokeTransparency = 0.45, Text = "", TextWrapped = true })
local noticeToken = 0
local function notice(msg)
	if not msg or msg == "" then return end
	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = msg
	noticeLabel.TextTransparency = 0
	noticeLabel.TextStrokeTransparency = 0.45
	task.delay(3.2, function()
		if token == noticeToken then tween(noticeLabel, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 }) end
	end)
end

local chip = new("Frame", gui, { Name = "ShovelChip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.56, 0),
	Size = UDim2.fromOffset(196, 54), BackgroundColor3 = INK, BackgroundTransparency = 0.15, Visible = false })
corner(chip, UDim.new(0, 6))
stroke(chip, Color3.fromRGB(70, 62, 58), 1)
new("Frame", chip, { Name = "Edge", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 })
local chipIconHolder = new("Frame", chip, { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(44, 44) })
shovelIcon(chipIconHolder, UDim2.fromScale(0.95, 0.95))
new("TextLabel", chip, { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -64, 0, 22),
	Font = Enum.Font.Oswald, TextSize = 18, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left, Text = "SHOVEL IN HAND" })
new("TextLabel", chip, { Name = "Hint", BackgroundTransparency = 1, Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -64, 0, 18),
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(177, 173, 165), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Walk up to a grave and dig" })
local function refreshChip() chip.Visible = p:GetAttribute("CarryingShovel") == true end
p:GetAttributeChangedSignal("CarryingShovel"):Connect(refreshChip)
refreshChip()

---------------------------------------------------------------- the dig mini-game
local game_ = new("Frame", gui, { Name = "DigGame", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
-- the progress panel sits low and centred, clear of the rescue-task panel on the left and the clock at the top
local panel = new("Frame", game_, { Name = "Panel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -60),
	Size = UDim2.fromOffset(330, 92), BackgroundColor3 = INK, BackgroundTransparency = 0.12 })
corner(panel, UDim.new(0, 6))
stroke(panel, Color3.fromRGB(70, 62, 58), 1)
new("Frame", panel, { Name = "Edge", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 })
local titleLabel = new("TextLabel", panel, { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -60, 0, 24),
	Font = Enum.Font.Oswald, TextSize = 19, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left, Text = "DIGGING" })
local layerLabel = new("TextLabel", panel, { Name = "Layer", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 18),
	Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(177, 173, 165), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local stop = new("TextButton", panel, { Name = "Stop", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(32, 30, 30), Text = "X", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = PAPER, AutoButtonColor = true, Modal = true })
corner(stop, UDim.new(0, 5))
local segments = {}
for i = 1, 3 do
	segments[i] = new("Frame", panel, { Name = "Layer" .. i, Position = UDim2.new((i - 1) / 3, 14 - (i - 1) * 9, 0, 56),
		Size = UDim2.new(1 / 3, -14, 0, 8), BackgroundColor3 = Color3.fromRGB(45, 40, 34), BorderSizePixel = 0 })
	corner(segments[i], UDim.new(0, 3))
	new("Frame", segments[i], { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(150, 112, 74), BorderSizePixel = 0 })
	corner(segments[i].Fill, UDim.new(0, 3))
end
local hint = new("TextLabel", panel, { Name = "Hint", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 68), Size = UDim2.new(1, -28, 0, 18),
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(150, 146, 138), TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Tap the shovel as it pops up" })

-- the dot
local dot = new("TextButton", game_, { Name = "ShovelDot", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(92, 92), Text = "",
	BackgroundColor3 = Color3.fromRGB(22, 22, 24), BackgroundTransparency = 0.08, AutoButtonColor = false, Visible = false, ZIndex = 5 })
corner(dot)
stroke(dot, PAPER, 3)
local dotScale = new("UIScale", dot, {})
local dotIcon = shovelIcon(dot, UDim2.fromScale(0.74, 0.74))
for _, d in dotIcon:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex += 5 end end
-- a ring that closes in on the dot (when it lands, the dot hops somewhere new)
local ring = new("Frame", game_, { Name = "Approach", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(92, 92), BackgroundTransparency = 1, Visible = false, ZIndex = 4 })
corner(ring)
local ringStroke = stroke(ring, Color3.fromRGB(230, 200, 150), 2)
local ringScale = new("UIScale", ring, {})

local active -- {token, layer, layers, need, taps, waiting, last, deadline}
local ringTween
local function renderProgress()
	if not active then return end
	titleLabel.Text = "DIGGING  ·  " .. string.upper(active.title or "GRAVE")
	layerLabel.Text = "LAYER " .. math.min(active.layer, active.layers) .. " / " .. active.layers .. "   ·   " .. active.taps .. " / " .. active.need
	for i, seg in segments do
		local fill = i < active.layer and 1 or (i == active.layer and active.taps / active.need or 0)
		tween(seg.Fill, 0.15, { Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1) })
	end
end
local function placeDot()
	if not active or active.waiting then dot.Visible = false ring.Visible = false return end
	local x, y = rng:NextNumber(0.3, 0.7), rng:NextNumber(0.34, 0.68)
	dot.Position = UDim2.fromScale(x, y)
	ring.Position = dot.Position
	dot.Visible = true
	ring.Visible = true
	dotScale.Scale = 0.55
	tween(dotScale, 0.14, { Scale = 1 }, Enum.EasingStyle.Back)
	ringScale.Scale = 2
	ringStroke.Transparency = 0.15
	if ringTween then ringTween:Cancel() end
	ringTween = tween(ringScale, 1.9, { Scale = 1 }, Enum.EasingStyle.Linear)
	active.deadline = os.clock() + 1.9
end
local function splash(pos)
	-- a quick expanding ring where you tapped
	local s = new("Frame", game_, { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(92, 92), BackgroundTransparency = 1, ZIndex = 6 })
	corner(s)
	local st = stroke(s, Color3.fromRGB(170, 128, 86), 4)
	local sc = new("UIScale", s, {})
	tween(sc, 0.35, { Scale = 1.7 })
	tween(st, 0.35, { Transparency = 1 }).Completed:Once(function() s:Destroy() end)
end
local function close(msg)
	active = nil
	game_.Visible = false
	dot.Visible = false
	ring.Visible = false
	if msg then notice(msg) end
end
local function cancel()
	if active then active = nil remote:FireServer("cancel") end
	close(nil)
end
local function hit()
	if not active or active.waiting or not dot.Visible then return end
	local now = os.clock()
	if now - (active.last or 0) < TAP_GAP then return end
	active.last = now
	remote:FireServer("tap", active.token)
	splash(dot.Position)
	placeDot()
end
dot.Activated:Connect(hit)
stop.Activated:Connect(cancel)
UIS.InputBegan:Connect(function(input, processed)
	if not active then return end
	if input.KeyCode == Enum.KeyCode.Escape then cancel()
	elseif input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.ButtonR2 then hit() end
end)
RunService.Heartbeat:Connect(function()
	if active and not active.waiting and active.deadline and os.clock() > active.deadline then placeDot() end
end)

remote.OnClientEvent:Connect(function(action, data)
	if action == "notice" then
		notice(data)
	elseif action == "open" then
		active = { token = data.token, title = data.title, layer = data.layer, layers = data.layers, need = data.need, taps = 0 }
		game_.Visible = true
		renderProgress()
		hint.Text = UIS.GamepadEnabled and not UIS.MouseEnabled and "Press Ⓐ as the shovel pops up" or "Tap the shovel as it pops up"
		placeDot()
	elseif action == "tap" and active then
		active.taps = data.taps
		renderProgress()
	elseif action == "layer" and active then
		active.taps = active.need
		renderProgress()
		active.waiting = true
		dot.Visible = false
		ring.Visible = false
		hint.Text = data.finished and "You hit wood…" or ("Layer " .. data.layer .. " cleared")
		if data.finished then return end
		task.delay(0.6, function()
			if active and active.waiting then
				active.layer = data.layer + 1
				active.taps = 0
				active.waiting = false
				hint.Text = "Tap the shovel as it pops up"
				renderProgress()
				placeDot()
			end
		end)
	elseif action == "close" then
		close(data)
	end
end)

-- keep the panel clear of the top bar on small screens
local function layout()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	panel.Position = UDim2.new(0.5, 0, 1, v.Y < 520 and -12 or -60)
	noticeLabel.Size = UDim2.fromOffset(math.min(560, v.X - 30), 34)
	chip.Position = UDim2.new(1, -18, v.Y < 520 and 0.7 or 0.56, 0)
end
layout()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
