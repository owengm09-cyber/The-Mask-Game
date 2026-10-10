-- Emergency meeting screen: a dark "case file" in the DreadHUD style (ink panels, cream Oswald, blood-red accent).
-- Survivors on the left, the campfire log (chat) on the right. Chat runs on the filtered "EmergencyMeeting" TextChannel.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local config = workspace:WaitForChild("MaskSystem")
local MAX_CHARS = 100
local OPEN_SOUND = "rbxassetid://9119879867" -- low thud (Pro Sound Effects)

local INK = Color3.fromRGB(14, 15, 18)
local PANEL = Color3.fromRGB(20, 21, 25)
local CARD = Color3.fromRGB(27, 28, 33)
local LINE = Color3.fromRGB(56, 50, 54)
local CREAM = Color3.fromRGB(229, 225, 215)
local MUTED = Color3.fromRGB(152, 151, 145)
local DIM = Color3.fromRGB(96, 95, 92)
local BLOOD = Color3.fromRGB(190, 46, 51)
local FALLBACK_COLOURS = {
	Color3.fromRGB(176, 52, 52), Color3.fromRGB(70, 104, 170), Color3.fromRGB(78, 132, 84), Color3.fromRGB(170, 96, 150),
	Color3.fromRGB(196, 128, 60), Color3.fromRGB(200, 186, 96), Color3.fromRGB(88, 164, 160), Color3.fromRGB(120, 92, 168),
}

local function new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = o end
	return o
end
local function corner(px) return new("UICorner", { CornerRadius = UDim.new(0, px) }) end
local function stroke(c, t) return new("UIStroke", { Color = c, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function pad(t, b, l, r) return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r) }) end
local function spaced(text) return (text:gsub(".", "%0 "):gsub("%s+$", "")) end

local function bandColour(p)
	local c = p and p:GetAttribute("BandColor")
	if typeof(c) == "Color3" then return c end
	return FALLBACK_COLOURS[((p and p.UserId or 0) % #FALLBACK_COLOURS) + 1]
end

local headshots = {}
local function headshot(userId)
	if headshots[userId] then return headshots[userId] end
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	headshots[userId] = ok and img or ""
	return headshots[userId]
end

-- square "file photo": headshot, darkened, with the player's colour as a thin frame
local function photo(p, size, dead)
	local frame = new("Frame", { Name = "Photo", Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(34, 34, 38) }, {
		corner(3), stroke(bandColour(p), 1.5) })
	local img = new("ImageLabel", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageColor3 = dead and Color3.fromRGB(110, 106, 104) or Color3.fromRGB(205, 200, 192) }, { corner(3) })
	img.Parent = frame
	new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = dead and 0.35 or 0.72, BorderSizePixel = 0, ZIndex = 3 }, { corner(3) }).Parent = frame
	if p then task.spawn(function() img.Image = headshot(p.UserId) end) end
	return frame
end

---------------------------------------------------------------- layout
local gui = new("ScreenGui", { Name = "MeetingTablet", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200, Enabled = false })
gui.Parent = player:WaitForChild("PlayerGui")
local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0 }, {
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }), Rotation = 90 }),
})
dim.Parent = gui

local file = new("CanvasGroup", { Name = "CaseFile", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.88, 0.82), BackgroundColor3 = INK, BackgroundTransparency = 0.04, GroupTransparency = 1 }, {
	corner(4), stroke(LINE, 1.5),
	new("UISizeConstraint", { MaxSize = Vector2.new(1040, 640) }),
	new("UIAspectRatioConstraint", { AspectRatio = 1.62 }),
})
file.Parent = gui
local fileScale = new("UIScale", { Scale = 1.04 }); fileScale.Parent = file
new("Frame", { Name = "Accent", Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = BLOOD, BorderSizePixel = 0 }).Parent = file

-- header
local header = new("Frame", { Name = "Header", Position = UDim2.new(0, 22, 0, 14), Size = UDim2.new(1, -44, 0, 70), BackgroundTransparency = 1 })
header.Parent = file
new("TextLabel", { Name = "Kicker", BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0, 18), Font = Enum.Font.Oswald, TextSize = 14,
	Text = spaced("EMERGENCY MEETING") .. "   ·   " .. spaced("CAMPFIRE"), TextColor3 = BLOOD, TextXAlignment = Enum.TextXAlignment.Left }).Parent = header
new("TextLabel", { Name = "Title", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(0.7, 0, 0, 44), Font = Enum.Font.Oswald,
	TextSize = 40, Text = "WHO WEARS THE MASK?", TextColor3 = CREAM, TextXAlignment = Enum.TextXAlignment.Left }).Parent = header
local timerBox = new("Frame", { Name = "Timer", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 6), Size = UDim2.fromOffset(150, 56),
	BackgroundColor3 = PANEL }, { corner(3), stroke(BLOOD, 1.5) })
timerBox.Parent = header
new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 0, 14), Font = Enum.Font.Oswald, TextSize = 12,
	Text = spaced("TIME LEFT"), TextColor3 = MUTED }).Parent = timerBox
local timerText = new("TextLabel", { Name = "Clock", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 1, -18), Font = Enum.Font.Oswald,
	TextSize = 30, Text = "00:45", TextColor3 = CREAM })
timerText.Parent = timerBox
local minimise = new("TextButton", { Name = "Minimise", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = PANEL, Font = Enum.Font.Oswald, Text = "—", TextSize = 20, TextColor3 = MUTED, AutoButtonColor = true }, { corner(3), stroke(LINE, 1.5) })
minimise.Parent = header
new("Frame", { Name = "Rule", Position = UDim2.new(0, 22, 0, 92), Size = UDim2.new(1, -44, 0, 1), BackgroundColor3 = LINE, BorderSizePixel = 0 }).Parent = file

-- survivors column
local leftCol = new("Frame", { Name = "Survivors", Position = UDim2.new(0, 22, 0, 106), Size = UDim2.new(0.36, -22, 1, -126), BackgroundTransparency = 1 })
leftCol.Parent = file
new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Oswald, TextSize = 13, Text = spaced("SURVIVORS"),
	TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }).Parent = leftCol
local roster = new("ScrollingFrame", { Name = "Roster", Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = DIM, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
roster.Parent = leftCol

-- campfire log column
local rightCol = new("Frame", { Name = "Log", Position = UDim2.new(0.36, 14, 0, 106), Size = UDim2.new(0.64, -36, 1, -126), BackgroundTransparency = 1 })
rightCol.Parent = file
new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Oswald, TextSize = 13, Text = spaced("CAMPFIRE LOG"),
	TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left }).Parent = rightCol
local logPanel = new("Frame", { Name = "Panel", Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26), BackgroundColor3 = PANEL }, { corner(3), stroke(LINE, 1) })
logPanel.Parent = rightCol
local feed = new("ScrollingFrame", { Name = "Feed", Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(1, -20, 1, -84), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = DIM, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	pad(0, 4, 0, 8),
})
feed.Parent = logPanel
local inputRow = new("Frame", { Name = "Input", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 52),
	BackgroundColor3 = Color3.fromRGB(10, 10, 12) }, { corner(3) })
inputRow.Parent = logPanel
local inputStroke = stroke(LINE, 1.5); inputStroke.Parent = inputRow
local box = new("TextBox", { Name = "Box", BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -120, 1, 0),
	Font = Enum.Font.SpecialElite, TextSize = 17, TextColor3 = CREAM, PlaceholderText = "Say what you saw...", PlaceholderColor3 = DIM,
	Text = "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
box.Parent = inputRow
local counter = new("TextLabel", { Name = "Counter", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -92, 0.5, 0), Size = UDim2.fromOffset(52, 20),
	BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 13, TextColor3 = DIM, Text = "0/" .. MAX_CHARS, TextXAlignment = Enum.TextXAlignment.Right })
counter.Parent = inputRow
local send = new("TextButton", { Name = "Send", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(74, 36),
	BackgroundColor3 = BLOOD, Font = Enum.Font.Oswald, TextSize = 16, Text = spaced("SEND"), TextColor3 = CREAM, AutoButtonColor = true }, { corner(2) })
send.Parent = inputRow

local pill = new("TextButton", { Name = "MeetingPill", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(320, 44),
	BackgroundColor3 = INK, Font = Enum.Font.Oswald, TextSize = 16, TextColor3 = CREAM, Text = "MEETING", Visible = false }, { corner(3), stroke(BLOOD, 1.5) })
pill.Parent = gui

---------------------------------------------------------------- log entries
local order = 0
local cardsById = {}
local function scrollToBottom()
	task.defer(function() feed.CanvasPosition = Vector2.new(0, math.max(0, feed.AbsoluteCanvasSize.Y - feed.AbsoluteWindowSize.Y)) end)
end

-- system notices: thin red lines of text, like entries stamped into the file
local function addNotice(text)
	order += 1
	local row = new("Frame", { Name = "Notice", LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
	new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.08, 0, 0, 1), BackgroundColor3 = BLOOD, BorderSizePixel = 0 }).Parent = row
	new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.08, 0, 0, 1), BackgroundColor3 = BLOOD, BorderSizePixel = 0 }).Parent = row
	new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.82, 0, 1, 0), BackgroundTransparency = 1,
		Font = Enum.Font.Oswald, TextSize = 14, TextWrapped = true, Text = string.upper(text), TextColor3 = BLOOD }).Parent = row
	row.Parent = feed
	scrollToBottom()
end

local function addMessage(sender, text, messageId)
	if messageId and cardsById[messageId] then
		cardsById[messageId].Text = text
		return
	end
	order += 1
	local mine = sender == player
	local colour = bandColour(sender)
	local card = new("Frame", { Name = "Message", LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = CARD }, {
		corner(3), pad(8, 9, 12, 12) })
	new("Frame", { Name = "Bar", AnchorPoint = Vector2.new(mine and 1 or 0, 0), Position = UDim2.new(mine and 1 or 0, mine and 12 or -12, 0, -8),
		Size = UDim2.new(0, 3, 1, 17), BackgroundColor3 = colour, BorderSizePixel = 0 }).Parent = card
	local pic = photo(sender, 38)
	pic.AnchorPoint = Vector2.new(mine and 1 or 0, 0); pic.Position = UDim2.new(mine and 1 or 0, 0, 0, 0); pic.Parent = card
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, mine and 0 or 50, 0, 0), Size = UDim2.new(1, -50, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, {
		new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = mine and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left }),
	})
	body.Parent = card
	new("TextLabel", { Name = "Name", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.Oswald, TextSize = 16,
		Text = string.upper(sender and sender.DisplayName or "Unknown"), TextColor3 = colour:Lerp(CREAM, 0.25),
		TextXAlignment = mine and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left }).Parent = body
	local msg = new("TextLabel", { Name = "Text", LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.SpecialElite, TextSize = 17, TextWrapped = true, Text = text, TextColor3 = CREAM,
		TextXAlignment = mine and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left })
	msg.Parent = body
	new("UISizeConstraint", { MinSize = Vector2.new(0, 38) }).Parent = card
	card.Parent = feed
	-- arrives with a faint flicker
	card.BackgroundTransparency = 0.6
	TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
	if messageId then cardsById[messageId] = msg end
	scrollToBottom()
end

local function clearFeed()
	for _, c in ipairs(feed:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	table.clear(cardsById); order = 0
end

---------------------------------------------------------------- survivors
local rosterSig
local function rebuildRoster(force)
	local callerId = config:GetAttribute("MeetingCallerUserId")
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("InRound") or p:GetAttribute("InEmergencyMeeting") then table.insert(list, p) end
	end
	local sig = tostring(callerId)
	for _, p in ipairs(list) do sig ..= "|" .. p.UserId .. (p:GetAttribute("InEmergencyMeeting") and "a" or "d") end
	if sig == rosterSig and not force then return end
	rosterSig = sig
	for _, c in ipairs(roster:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	table.sort(list, function(a, b)
		local aa, bb = a:GetAttribute("InEmergencyMeeting") == true, b:GetAttribute("InEmergencyMeeting") == true
		if aa ~= bb then return aa end
		return a.DisplayName < b.DisplayName
	end)
	for i, p in ipairs(list) do
		local alive = p:GetAttribute("InEmergencyMeeting") == true
		local caller = p.UserId == callerId
		local tile = new("Frame", { Name = "Tile", LayoutOrder = i, Size = UDim2.new(1, -6, 0, 58), BackgroundColor3 = alive and CARD or Color3.fromRGB(20, 20, 23) }, {
			corner(3), stroke(caller and BLOOD or LINE, caller and 1.5 or 1) })
		new("Frame", { Name = "Bar", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = alive and bandColour(p) or DIM, BorderSizePixel = 0 }).Parent = tile
		local pic = photo(p, 42, not alive)
		pic.AnchorPoint = Vector2.new(0, 0.5); pic.Position = UDim2.new(0, 12, 0.5, 0); pic.Parent = tile
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 64, 0, 9), Size = UDim2.new(1, -72, 0, 22), Font = Enum.Font.Oswald, TextSize = 19,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = string.upper(p.DisplayName), TextColor3 = alive and CREAM or DIM, TextXAlignment = Enum.TextXAlignment.Left }).Parent = tile
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 64, 0, 31), Size = UDim2.new(1, -72, 0, 16), Font = Enum.Font.Oswald, TextSize = 12,
			Text = spaced(not alive and "DECEASED" or (caller and "CALLED THE MEETING" or "PRESENT")),
			TextColor3 = (not alive or caller) and BLOOD or MUTED, TextXAlignment = Enum.TextXAlignment.Left }).Parent = tile
		if not alive then
			-- struck through, like a name crossed off a list
			new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(1, -16, 0, 2), Rotation = -4,
				BackgroundColor3 = BLOOD, BorderSizePixel = 0, ZIndex = 5 }).Parent = tile
		end
		tile.Parent = roster
	end
end

---------------------------------------------------------------- sending / receiving
local channel
local function getChannel()
	if channel and channel.Parent then return channel end
	local folder = TextChatService:FindFirstChild("TextChannels")
	channel = folder and folder:FindFirstChild("EmergencyMeeting")
	return channel
end

local lastSend = 0
local function sendCurrent()
	local text = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" or os.clock() - lastSend < 0.6 then return end
	local ch = getChannel()
	if not ch then addNotice("The log is still opening...") return end
	lastSend = os.clock()
	box.Text = ""
	task.spawn(function()
		local ok = pcall(function() ch:SendAsync(text) end)
		if not ok then addNotice("Your words didn't carry.") end
	end)
end
box.FocusLost:Connect(function(enter) inputStroke.Color = LINE; if enter then sendCurrent() end end)
box.Focused:Connect(function() inputStroke.Color = BLOOD end)
send.Activated:Connect(sendCurrent)
box:GetPropertyChangedSignal("Text"):Connect(function()
	if #box.Text > MAX_CHARS then box.Text = box.Text:sub(1, MAX_CHARS) end
	counter.Text = #box.Text .. "/" .. MAX_CHARS
	counter.TextColor3 = #box.Text >= MAX_CHARS - 10 and BLOOD or DIM
end)

local hooked
local function hookChannel()
	local ch = getChannel()
	if not ch or hooked == ch then return end
	hooked = ch
	ch.MessageReceived:Connect(function(message)
		if not gui.Enabled then return end
		local src = message.TextSource
		local sender = src and Players:GetPlayerByUserId(src.UserId)
		if message.Status == Enum.TextChatMessageStatus.Success or message.Status == Enum.TextChatMessageStatus.Sending then
			addMessage(sender, message.Text, message.MessageId)
		end
	end)
end

---------------------------------------------------------------- open / close
local open, minimised = false, false
local hiddenDefaultChat = false
local function setDefaultChat(enabled)
	local w = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local b = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if w then w.Enabled = enabled end
	if b then b.Enabled = enabled end
end
local function setMinimised(m)
	minimised = m
	file.Visible = not m
	dim.Visible = not m
	pill.Visible = m
	if not m then box:CaptureFocus() end
end
minimise.Activated:Connect(function() setMinimised(true) end)
pill.Activated:Connect(function() setMinimised(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not open then return end
	if input.KeyCode == Enum.KeyCode.M then setMinimised(not minimised) end
end)

local function thud()
	local snd = Instance.new("Sound"); snd.SoundId = OPEN_SOUND; snd.Volume = 0.7; snd.PlaybackSpeed = 0.8; snd.Parent = SoundService
	snd:Play(); task.delay(3, function() snd:Destroy() end)
end

local warned10
local function openFile()
	open = true
	clearFeed(); warned10 = false
	gui.Enabled = true
	setMinimised(false)
	setDefaultChat(false); hiddenDefaultChat = true
	rebuildRoster(true)
	addNotice((config:GetAttribute("MeetingCaller") or "Someone") .. " lit the flare")
	addNotice("One of you is wearing the Mask")
	dim.BackgroundTransparency = 1
	file.GroupTransparency = 1
	fileScale.Scale = 1.04
	thud()
	TweenService:Create(dim, TweenInfo.new(0.4), { BackgroundTransparency = 0.25 }):Play()
	-- the file stutters on like an old monitor
	task.spawn(function()
		for _, st in ipairs({ { 0.35, 0.05 }, { 0.85, 0.06 }, { 0.15, 0.05 }, { 0.6, 0.05 }, { 0, 0 } }) do file.GroupTransparency = st[1]; task.wait(st[2]) end
	end)
	TweenService:Create(fileScale, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	task.delay(0.5, function() if open and not minimised then box:CaptureFocus() end end)
end
local function closeFile()
	open = false
	box:ReleaseFocus()
	local tw = TweenService:Create(file, TweenInfo.new(0.3), { GroupTransparency = 1 })
	tw:Play()
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	pill.Visible = false
	tw.Completed:Once(function() if not open then gui.Enabled = false end end)
	if hiddenDefaultChat then setDefaultChat(true); hiddenDefaultChat = false end
end

local lastRoster = 0
while true do
	local inMeeting = config:GetAttribute("MeetingActive") == true and player:GetAttribute("InEmergencyMeeting") == true and config:GetAttribute("MeetingEndsAt") ~= nil
	if inMeeting and not open then openFile() elseif not inMeeting and open then closeFile() end
	if open then
		hookChannel()
		local remaining = math.max(0, math.ceil((config:GetAttribute("MeetingEndsAt") or 0) - workspace:GetServerTimeNow()))
		timerText.Text = string.format("%02d:%02d", remaining // 60, remaining % 60)
		local urgent = remaining <= 10
		timerText.TextColor3 = (urgent and math.floor(os.clock() * 2) % 2 == 0) and BLOOD or CREAM
		pill.Text = spaced("MEETING") .. "   " .. string.format("%02d:%02d", remaining // 60, remaining % 60) .. "   ·   M"
		if urgent and not warned10 then warned10 = true; addNotice("Ten seconds left") end
		if os.clock() - lastRoster > 1 then lastRoster = os.clock(); rebuildRoster() end
	end
	task.wait(0.2)
end
