-- RadioTowerClient: the radio tower on this player's machine.
--   * The ladder comes up through a notch in the platform. The notch has an invisible lid and gate: solid while
--     you walk about up there, switched off (on this machine only — your character's physics runs here) while you
--     climb through it, so climbers come straight up and walkers can't step off the edge.
--   * Notices from RadioTowerService, and the "in hand" chip for the module / toolbox / rungs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local p = Players.LocalPlayer
local tower = workspace:WaitForChild("RadioTower")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RadioTower")

local PAPER = Color3.fromRGB(232, 229, 218)
local INK = Color3.fromRGB(15, 17, 17)
local RED = Color3.fromRGB(196, 34, 40)
local MUTED = Color3.fromRGB(177, 173, 165)

---------------------------------------------------------------- the notch
-- The platform streams in and out with distance, so the lid and gate are looked up as they come and go.
local passing = false
local lid, gate, lidOpen = nil, nil, nil
local box -- the notch footprint: {min, max, deckY}, taken from the lid
local function inNotch(pos, pad)
	-- the far side is open air: a climber hangs out past the platform's edge
	return pos.X > box.min.X - pad and pos.X < box.max.X + pad and pos.Z > box.min.Z - pad and pos.Z < box.max.Z + pad + 1.8
end
RunService.Heartbeat:Connect(function()
	local deck = tower:FindFirstChild("Platform")
	local l = deck and deck:FindFirstChild("NotchLid")
	local g = deck and deck:FindFirstChild("NotchGate")
	if l ~= lid or g ~= gate then
		lid, gate, lidOpen = l, g, nil
		box = l and { min = l.Position - l.Size / 2, max = l.Position + l.Size / 2, deckY = l.Position.Y + l.Size.Y / 2 } or nil
	end
	if not lid then passing = false return end
	local c = p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local open = false
	if h and r then
		local pos = r.Position
		local near = inNotch(pos, 1.2) and pos.Y > box.deckY - 12 and pos.Y < box.deckY + 7
		if near and h:GetState() == Enum.HumanoidStateType.Climbing then passing = true end
		if passing then
			local feet = pos.Y - r.Size.Y / 2 - h.HipHeight
			-- through once you're standing on the platform beside the notch (or you've left the ladder)
			if not near or (feet > box.deckY - 0.3 and not inNotch(pos, 0.2)) then passing = false end
		end
		open = passing or c:GetAttribute("OnLadder") == true
	else
		passing = false
	end
	if open ~= lidOpen then
		lidOpen = open
		lid.CanCollide = not open
		if gate then gate.CanCollide = not open end
	end
end)

---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "RadioTowerHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 58
gui.Parent = p:WaitForChild("PlayerGui")
local function new(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return new("UICorner", o, { CornerRadius = r or UDim.new(0, 6) }) end

local noticeLabel = new("TextLabel", gui, { Name = "Notice", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66),
	Size = UDim2.fromOffset(600, 34), BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 22, TextColor3 = PAPER,
	TextStrokeTransparency = 1, TextTransparency = 1, Text = "", TextWrapped = true })
local noticeToken = 0
local function notice(msg)
	if not msg or msg == "" then return end
	noticeToken += 1
	local token = noticeToken
	noticeLabel.Text = msg
	noticeLabel.TextTransparency = 0
	noticeLabel.TextStrokeTransparency = 0.45
	task.delay(3.4, function()
		if token == noticeToken then TweenService:Create(noticeLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play() end
	end)
end
remote.OnClientEvent:Connect(function(action, data)
	if action == "notice" then notice(data) end
end)

-- what's in your hand: drawn icon, name, and where it goes
local chip = new("Frame", gui, { Name = "CarryChip", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.56, 0),
	Size = UDim2.fromOffset(236, 54), BackgroundColor3 = INK, BackgroundTransparency = 0.15, Visible = false })
corner(chip)
new("UIStroke", chip, { Color = Color3.fromRGB(70, 62, 58), Thickness = 1 })
new("Frame", chip, { Name = "Edge", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 })
local iconBox = new("Frame", chip, { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(40, 40) })
local chipTitle = new("TextLabel", chip, { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -64, 0, 22),
	Font = Enum.Font.Oswald, TextSize = 18, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local chipHint = new("TextLabel", chip, { Name = "Hint", BackgroundTransparency = 1, Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -64, 0, 18),
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
local function block(x, y, w, h, colour, rot)
	local f = new("Frame", iconBox, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
		BackgroundColor3 = colour, BorderSizePixel = 0, Rotation = rot or 0 })
	new("UIStroke", f, { Color = Color3.fromRGB(14, 12, 12), Thickness = 1 })
	return f
end
local ICONS = {
	Module = function()
		block(0.5, 0.52, 0.9, 0.64, Color3.fromRGB(58, 62, 64))
		block(0.5, 0.52, 0.76, 0.48, Color3.fromRGB(34, 120, 64))
		block(0.32, 0.45, 0.18, 0.14, Color3.fromRGB(22, 22, 24))
		block(0.6, 0.45, 0.26, 0.14, Color3.fromRGB(22, 22, 24))
		block(0.5, 0.88, 0.7, 0.07, Color3.fromRGB(204, 170, 80))
		block(0.78, 0.66, 0.08, 0.08, Color3.fromRGB(120, 255, 140))
	end,
	Toolbox = function()
		block(0.5, 0.25, 0.4, 0.07, Color3.fromRGB(30, 30, 32))
		block(0.32, 0.32, 0.06, 0.14, Color3.fromRGB(30, 30, 32))
		block(0.68, 0.32, 0.06, 0.14, Color3.fromRGB(30, 30, 32))
		block(0.5, 0.64, 0.92, 0.5, Color3.fromRGB(176, 36, 30))
		block(0.5, 0.44, 0.94, 0.1, Color3.fromRGB(150, 30, 26))
		block(0.22, 0.55, 0.08, 0.1, Color3.fromRGB(190, 192, 194))
		block(0.78, 0.55, 0.08, 0.1, Color3.fromRGB(190, 192, 194))
	end,
	Rungs = function()
		for i = 0, 3 do block(0.5, 0.26 + i * 0.16, 0.96, 0.1, Color3.fromRGB(160, 164, 166), -12) end
		block(0.3, 0.5, 0.08, 0.7, Color3.fromRGB(110, 78, 46), -12)
		block(0.7, 0.5, 0.08, 0.7, Color3.fromRGB(110, 78, 46), -12)
	end,
}
local TEXT = {
	Module = { "TRANSMITTER MODULE", "Fit it into the radio tower cabinet" },
	Toolbox = { "TOOLBOX", "Take it to the foot of the tower ladder" },
	Rungs = { "LADDER RUNGS", "Take them to the foot of the tower ladder" },
}
local function refreshChip()
	local kind = p:GetAttribute("Carrying")
	chip.Visible = kind ~= nil and TEXT[kind] ~= nil
	if not chip.Visible then return end
	iconBox:ClearAllChildren()
	ICONS[kind]()
	chipTitle.Text = TEXT[kind][1]
	chipHint.Text = TEXT[kind][2]
end
p:GetAttributeChangedSignal("Carrying"):Connect(refreshChip)
refreshChip()
