-- CampHotbar: the item slots along the bottom of the screen, in the camp HUD's style. Replaces Roblox's own
-- backpack bar. Press 1-9 (or click / tap a slot) to take an item out or put it away; on a gamepad L1 / R1 step
-- through them. Stacked loot shows its count; anything with a Charge attribute (the flashlight) shows a charge line.
-- Other scripts hide it while a menu is open or an item is in use: LocalPlayer attribute HotbarHidden = true.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local p = Players.LocalPlayer
local pg = p:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(17, 18, 19)
local INK_UP = Color3.fromRGB(34, 33, 32)
local CREAM = Color3.fromRGB(230, 225, 210)
local MUTED = Color3.fromRGB(185, 180, 166)
local DIM = Color3.fromRGB(120, 117, 109)
local RED = Color3.fromRGB(151, 45, 45)
local AMBER = Color3.fromRGB(205, 128, 58)
local MAX = 9
local GAP = 6
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }

-- keep Roblox's own bar off (something may switch it back on, e.g. after using a bandage)
local function coreOff() pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end) end
coreOff()
task.spawn(function()
	while true do
		task.wait(0.5)
		local ok, on = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) end)
		if not ok or on then coreOff() end
	end
end)

local function new(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local gui = new("ScreenGui", pg, { Name = "CampHotbar", ResetOnSpawn = false, DisplayOrder = 26 })
local bar = new("Frame", gui, { Name = "Bar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), BackgroundTransparency = 1, Size = UDim2.fromOffset(60, 60), Visible = false })
local barScale = new("UIScale", bar, {})
-- the item you've just taken out, named above the bar for a moment
local caption = new("TextLabel", bar, { Name = "Caption", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.fromOffset(320, 20),
	BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 16, TextColor3 = CREAM, TextStrokeTransparency = 0.6, TextTransparency = 1, Text = "" })

local order = {} -- tools in slot order
local slots = {} -- slot frames
local function slotSize() return UIS.TouchEnabled and 66 or 60 end

local function baseName(tool) return (tool.Name:gsub("%s+x%d+$", "")) end

local function makeSlot(i)
	local S = slotSize()
	local b = new("TextButton", bar, { Name = "Slot" .. i, Size = UDim2.fromOffset(S, S), BackgroundColor3 = INK, BackgroundTransparency = 0.12,
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", Selectable = false })
	local stroke = new("UIStroke", b, { Name = "Edge", Color = MUTED, Transparency = 0.78, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local top = new("Frame", b, { Name = "Accent", Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = RED, BorderSizePixel = 0, Visible = false })
	new("TextLabel", b, { Name = "Key", Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Font = Enum.Font.Oswald,
		TextSize = 12, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(i) })
	new("TextLabel", b, { Name = "Count", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(30, 14), BackgroundTransparency = 1,
		Font = Enum.Font.Oswald, TextSize = 12, TextColor3 = CREAM, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	new("ImageLabel", b, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -5), Size = UDim2.fromOffset(S - 26, S - 26),
		BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Image = "" })
	new("TextLabel", b, { Name = "ItemName", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -8, 0, 14), BackgroundTransparency = 1,
		Font = Enum.Font.Oswald, TextSize = 11, TextColor3 = MUTED, TextTruncate = Enum.TextTruncate.AtEnd, Text = "" })
	-- a thin charge line along the bottom edge (flashlight battery)
	local track = new("Frame", b, { Name = "Charge", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(45, 40, 30), BorderSizePixel = 0, Visible = false })
	new("Frame", track, { Name = "Fill", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = MUTED, BorderSizePixel = 0 })
	b.Activated:Connect(function()
		local idx = tonumber(b.Name:match("%d+"))
		if idx then _G.CampHotbarToggle(idx) end
	end)
	return b
end

local lastEquipped
local captionToken = 0
local function showCaption(text)
	captionToken += 1
	local token = captionToken
	caption.Text = text
	caption.TextTransparency = 0
	caption.TextStrokeTransparency = 0.6
	task.delay(2.2, function()
		if token ~= captionToken then return end
		TweenService:Create(caption, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local function hidden()
	local char = p.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	return p:GetAttribute("HotbarHidden") == true or not h or h.Health <= 0
end

local function refresh()
	local char = p.Character
	local bp = p:FindFirstChildOfClass("Backpack")
	-- forget tools that are gone (dropped, used up, or from a previous life)
	for i = #order, 1, -1 do
		local t = order[i]
		if not (t.Parent and (t.Parent == char or t.Parent == bp)) then table.remove(order, i) end
	end
	local S = slotSize()
	while #slots < #order do table.insert(slots, makeSlot(#slots + 1)) end
	while #slots > #order do slots[#slots]:Destroy() slots[#slots] = nil end
	local n = #order
	bar.Size = UDim2.fromOffset(math.max(n * S + (n - 1) * GAP, S), S)
	local equipped
	for i, t in order do
		local b = slots[i]
		local on = char ~= nil and t.Parent == char
		if on then equipped = t end
		b.Size = UDim2.fromOffset(S, S)
		b.Position = UDim2.fromOffset((i - 1) * (S + GAP), on and -5 or 0)
		b.BackgroundColor3 = on and INK_UP or INK
		b.BackgroundTransparency = on and 0.04 or 0.12
		b.Edge.Color = on and CREAM or MUTED
		b.Edge.Transparency = on and 0.35 or 0.78
		b.Accent.Visible = on
		b.Key.TextColor3 = on and CREAM or DIM
		local icon = t.TextureId
		local hasIcon = icon ~= nil and icon ~= ""
		b.Icon.Image = hasIcon and icon or ""
		b.Icon.Visible = hasIcon
		b.Icon.ImageTransparency = on and 0 or 0.15
		-- with no picture the name takes the middle of the slot, larger, on two lines if it needs them
		local name = string.upper(baseName(t))
		b.ItemName.Text = name
		b.ItemName.TextColor3 = on and CREAM or MUTED
		if hasIcon then
			b.ItemName.AnchorPoint = Vector2.new(0.5, 1) b.ItemName.Position = UDim2.new(0.5, 0, 1, -5) b.ItemName.Size = UDim2.new(1, -8, 0, 14)
			b.ItemName.TextSize = 11 b.ItemName.TextWrapped = false b.ItemName.TextTruncate = Enum.TextTruncate.AtEnd
		else
			b.ItemName.AnchorPoint = Vector2.new(0.5, 0.5) b.ItemName.Position = UDim2.new(0.5, 0, 0.5, 4) b.ItemName.Size = UDim2.new(1, -8, 0, 30)
			b.ItemName.TextSize = 13 b.ItemName.TextWrapped = true b.ItemName.TextTruncate = Enum.TextTruncate.None
		end
		local count = t:GetAttribute("Count")
		b.Count.Text = (type(count) == "number" and count > 1) and ("x" .. count) or ""
		local charge = t:GetAttribute("Charge")
		b.Charge.Visible = type(charge) == "number"
		if type(charge) == "number" then
			local c = math.clamp(charge / 100, 0, 1)
			b.Charge.Fill.Size = UDim2.new(c, 0, 1, 0)
			b.Charge.Fill.BackgroundColor3 = c < 0.3 and AMBER or MUTED
		end
	end
	if equipped ~= lastEquipped then
		if equipped then showCaption(string.upper(baseName(equipped))) end
		lastEquipped = equipped
	end
	bar.Visible = n > 0 and not hidden()
end

local function track(t)
	if t:IsA("Tool") and not table.find(order, t) and #order < MAX then
		table.insert(order, t)
		t:GetPropertyChangedSignal("Name"):Connect(refresh)
		t.AttributeChanged:Connect(refresh)
	end
	refresh()
end
local function hook(container)
	for _, t in container:GetChildren() do track(t) end
	container.ChildAdded:Connect(track)
	container.ChildRemoved:Connect(function() task.defer(refresh) end)
end
local function hookCharacter(char) hook(char) refresh() end
if p.Character then hookCharacter(p.Character) end
p.CharacterAdded:Connect(hookCharacter)
local bp = p:FindFirstChildOfClass("Backpack") or p:WaitForChild("Backpack", 10)
if bp then hook(bp) end
p.ChildAdded:Connect(function(c) if c:IsA("Backpack") then hook(c) end end)
p:GetAttributeChangedSignal("HotbarHidden"):Connect(refresh)

-- take out / put away
local function toggle(i)
	if hidden() then return end
	local t = order[i]
	local char = p.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	if not (t and h) then return end
	if t.Parent == char then h:UnequipTools() else h:EquipTool(t) end
	task.defer(refresh)
end
_G.CampHotbarToggle = toggle
local function step(dir)
	if #order == 0 then return end
	local char = p.Character
	local cur = 0
	for i, t in order do if t.Parent == char then cur = i end end
	local nxt = cur + dir
	if nxt < 1 then nxt = #order elseif nxt > #order then nxt = 1 end
	toggle(nxt)
end
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	for i, k in KEYS do
		if input.KeyCode == k then toggle(i) return end
	end
	if input.KeyCode == Enum.KeyCode.ButtonL1 then step(-1)
	elseif input.KeyCode == Enum.KeyCode.ButtonR1 then step(1) end
end)

-- size with the screen, like the rest of the camp HUD
task.spawn(function()
	while gui.Parent do
		local cam = workspace.CurrentCamera
		if cam then
			local v = cam.ViewportSize
			barScale.Scale = math.clamp(math.min(v.X / 1000, v.Y / 720), 0.75, 1)
		end
		refresh()
		task.wait(0.25)
	end
end)
