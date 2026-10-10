-- The rescue-task mini-game window (case-file style, like the meeting screen).
-- Works with mouse, touch and gamepad: every control is a tap, a drag (with a tap-tap fallback) or a hold.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local W = {}

local T = {
	INK = Color3.fromRGB(14, 15, 18), PANEL = Color3.fromRGB(20, 21, 25), CARD = Color3.fromRGB(28, 29, 34), LINE = Color3.fromRGB(58, 52, 56),
	CREAM = Color3.fromRGB(229, 225, 215), MUTED = Color3.fromRGB(152, 151, 145), DIM = Color3.fromRGB(96, 95, 92),
	BLOOD = Color3.fromRGB(190, 46, 51), AMBER = Color3.fromRGB(214, 168, 74), GREEN = Color3.fromRGB(112, 170, 104),
	STEEL = Color3.fromRGB(110, 112, 118), RUST = Color3.fromRGB(122, 74, 46),
}
W.T = T

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local K = {}
K.new = new
function K.corner(px) return new("UICorner", { CornerRadius = typeof(px) == "UDim" and px or UDim.new(0, px or 4) }) end
function K.stroke(c, t) return new("UIStroke", { Color = c, Thickness = t or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
function K.spaced(s) return (s:gsub(".", "%0 "):gsub("%s+$", "")) end
function K.frame(parent, props) local f = new("Frame", props) f.BorderSizePixel = 0 f.Parent = parent return f end
function K.label(parent, text, size, pos, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, Size = size, Position = pos, Font = Enum.Font.Oswald, TextSize = 18,
		TextColor3 = T.CREAM, TextWrapped = true })
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end
function K.button(parent, text, size, pos, props)
	local b = new("TextButton", { Text = text, Size = size, Position = pos, Font = Enum.Font.Oswald, TextSize = 20, TextColor3 = T.CREAM,
		BackgroundColor3 = T.CARD, AutoButtonColor = true, BorderSizePixel = 0 }, { K.corner(4), K.stroke(T.LINE, 1.5) })
	for k, v in pairs(props or {}) do b[k] = v end
	b.Parent = parent
	return b
end
function K.tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play() return tw
end
function K.inside(o, pos)
	local a, s = o.AbsolutePosition, o.AbsoluteSize
	return pos.X >= a.X and pos.X <= a.X + s.X and pos.Y >= a.Y and pos.Y <= a.Y + s.Y
end
function K.shake(o)
	local p = o.Position
	task.spawn(function()
		for _, dx in ipairs({ -6, 6, -4, 4, -2, 0 }) do if not o.Parent then return end o.Position = p + UDim2.fromOffset(dx, 0) task.wait(0.03) end
		if o.Parent then o.Position = p end
	end)
end

local gui = new("ScreenGui", { Name = "TaskMinigame", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 70, Enabled = false })
gui.Parent = player:WaitForChild("PlayerGui")
K.frame(gui, { Name = "Dim", Size = UDim2.new(1, 0, 1, 60), Position = UDim2.fromOffset(0, -60), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45 })
local win = K.frame(gui, { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 500),
	BackgroundColor3 = T.INK, BackgroundTransparency = 0.02 })
K.corner(4).Parent = win; K.stroke(T.LINE, 1.5).Parent = win
local scale = new("UIScale", { Parent = win })
local accent = K.frame(win, { Name = "Accent", Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = T.BLOOD })
local kicker = K.label(win, "", UDim2.new(1, -90, 0, 18), UDim2.fromOffset(22, 14), { TextSize = 13, TextColor3 = T.BLOOD, TextXAlignment = Enum.TextXAlignment.Left })
local title = K.label(win, "", UDim2.new(1, -90, 0, 38), UDim2.fromOffset(22, 32), { TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left })
local guide = K.label(win, "", UDim2.new(1, -44, 0, 40), UDim2.fromOffset(22, 72), { Font = Enum.Font.SpecialElite, TextSize = 15, TextColor3 = T.MUTED,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
local close = K.button(win, "X", UDim2.fromOffset(44, 44), UDim2.new(1, -60, 0, 14), { TextSize = 20, TextColor3 = T.MUTED, BackgroundColor3 = T.PANEL })
local board = K.frame(win, { Name = "Board", Position = UDim2.fromOffset(20, 120), Size = UDim2.fromOffset(600, 300), BackgroundColor3 = T.PANEL, ClipsDescendants = true })
local pips = K.frame(win, { Name = "Pips", Position = UDim2.fromOffset(22, 438), Size = UDim2.fromOffset(200, 14), BackgroundTransparency = 1 })
local status = K.label(win, "", UDim2.new(1, -44, 0, 26), UDim2.fromOffset(22, 458), { TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left })

local function fit()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local inset = game:GetService("GuiService"):GetGuiInset()
	local vw, vh = cam.ViewportSize.X, cam.ViewportSize.Y - inset.Y
	scale.Scale = math.clamp(math.min(vw * 0.96 / 640, vh * 0.94 / 500), 0.45, 1.25)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local function isPress(input) return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch end
local cleanups = {}
local function track(c) table.insert(cleanups, c) return c end
K.track = track
function K.toLocal(parent, pos) return (pos - parent.AbsolutePosition) / scale.Scale end
function K.drag(obj, onStart, onMove, onDrop)
	track(obj.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		if onStart and onStart(input.Position) == false then return end
		local moveConn, endConn
		moveConn = UIS.InputChanged:Connect(function(i2)
			if (input.UserInputType == Enum.UserInputType.Touch and i2 == input) or (input.UserInputType ~= Enum.UserInputType.Touch and i2.UserInputType == Enum.UserInputType.MouseMovement) then
				if onMove then onMove(i2.Position) end
			end
		end)
		endConn = UIS.InputEnded:Connect(function(i2)
			if i2 == input or (input.UserInputType == Enum.UserInputType.MouseButton1 and i2.UserInputType == Enum.UserInputType.MouseButton1) then
				moveConn:Disconnect(); endConn:Disconnect()
				if onDrop then onDrop(i2.Position) end
			end
		end)
		track(moveConn); track(endConn)
	end))
end
function K.hold(obj, onDown, onUp, primary)
	local held = false
	local function down() if held then return end held = true onDown() end
	local function up() if not held then return end held = false onUp() end
	track(obj.InputBegan:Connect(function(input) if isPress(input) then down() end end))
	track(obj.InputEnded:Connect(function(input) if isPress(input) then up() end end))
	track(obj.MouseLeave:Connect(function() if held and not UIS.TouchEnabled then up() end end))
	if primary then
		ContextActionService:BindAction("TaskHold", function(_, state)
			if state == Enum.UserInputState.Begin then down() elseif state == Enum.UserInputState.End then up() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
		track(function() ContextActionService:UnbindAction("TaskHold") end)
	end
end
function K.line(parent, a, b, thick, colour, z)
	local l = K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = colour, ZIndex = z or 3 })
	K.corner(UDim.new(1, 0)).Parent = l
	local function set(p, q)
		local d = q - p
		l.Position = UDim2.fromOffset((p.X + q.X) / 2, (p.Y + q.Y) / 2)
		l.Size = UDim2.fromOffset(math.max(d.Magnitude, 1), thick)
		l.Rotation = math.deg(math.atan2(d.Y, d.X))
	end
	set(a, b)
	return l, set
end

local games = {}
for _, mod in ipairs(script:GetChildren()) do
	if mod:IsA("ModuleScript") then for name, fn in pairs(require(mod)) do games[name] = fn end end
end
local session
local function clearBoard()
	for _, c in ipairs(cleanups) do if typeof(c) == "RBXScriptConnection" then c:Disconnect() elseif typeof(c) == "function" then pcall(c) end end
	table.clear(cleanups)
	board:ClearAllChildren()
	K.corner(3).Parent = board; K.stroke(T.LINE, 1).Parent = board
end
local function setStatus(text, colour) status.Text = text or "" status.TextColor3 = colour or T.CREAM end
local function setPips(round, rounds)
	pips:ClearAllChildren()
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = pips })
	if rounds <= 1 then return end
	for i = 1, rounds do K.frame(pips, { Size = UDim2.fromOffset(28, 6), BackgroundColor3 = i < round and T.GREEN or (i == round and T.AMBER or T.LINE) }) end
end
local cancelFn
close.Activated:Connect(function() if cancelFn then cancelFn() end W.close() end)

function W.open(data, act, onCancel)
	clearBoard()
	session = { data = data, handler = nil }
	cancelFn = onCancel
	gui.Enabled = true
	accent.BackgroundColor3 = T.BLOOD
	kicker.Text = K.spaced(string.upper(data.site or "CAMP")) .. ((data.rounds or 1) > 1 and ("   ·   " .. K.spaced("STEP " .. data.round .. " OF " .. data.rounds)) or "")
	title.Text = string.upper(data.title or "TASK")
	guide.Text = data.guide or data.instruction or ""
	setPips(data.round or 1, data.rounds or 1)
	setStatus(data.instruction or "", T.MUTED)
	local api = {
		act = function(action, payload) if session then act(action, payload) end end,
		status = setStatus,
		onResult = function(fn) if session then session.handler = fn end end,
		data = data.data, round = data.round, rounds = data.rounds, start = data.start,
		board = board, T = T, K = K,
	}
	local fn = games[data.game]
	if fn then
		local ok, err = pcall(fn, board, data.data, api)
		if not ok then warn("[TaskWindow] " .. tostring(data.game) .. ": " .. tostring(err)) setStatus("This task failed to load.", T.BLOOD) end
	else
		setStatus("Unknown task type: " .. tostring(data.game), T.BLOOD)
	end
	win.Position = UDim2.new(0.5, 0, 0.5, 14)
	K.tween(win, 0.25, { Position = UDim2.fromScale(0.5, 0.5) })
end

function W.result(res)
	if not session then return end
	if res.roundDone then
		setStatus(session.data.round < session.data.rounds and "GOOD — NEXT STEP..." or "TASK COMPLETE", T.GREEN)
		accent.BackgroundColor3 = T.GREEN
	elseif res.msg then
		setStatus(res.msg, res.ok and T.GREEN or T.BLOOD)
	end
	if session.handler then
		local ok, err = pcall(session.handler, res)
		if not ok then warn("[TaskWindow] result: " .. tostring(err)) end
	end
end

function W.close()
	session = nil
	cancelFn = nil
	clearBoard()
	gui.Enabled = false
end

function W.isOpen() return session ~= nil end

return W
