-- Battery meter for the flashlight, drawn inside the Equipment panel's item row (DreadHUD.Loadout.Item).
-- Shows charge (4 segments + %), spare batteries carried, and an [R] hint when low.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local CREAM = Color3.fromRGB(230, 225, 210)
local MUTED = Color3.fromRGB(150, 146, 136)
local AMBER = Color3.fromRGB(214, 168, 74)
local RED = Color3.fromRGB(196, 52, 56)

local meter, segs, pct, count, hint
local lastDeadClick, blinkUntil = nil, 0

local function find(attrName, value)
	for _, h in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if h then
			for _, t in ipairs(h:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute(attrName) == value then return t end
			end
		end
	end
end

local function spareBatteries()
	local n = 0
	for _, h in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if h then
			for _, t in ipairs(h:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("LootItemId") == "Battery" then n += (t:GetAttribute("Count") or 1) end
			end
		end
	end
	return n
end

local function label(parent, name, x, w, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, x, 0, 0)
	l.Size = UDim2.new(0, w, 1, 0)
	l.Font = Enum.Font.Oswald
	l.TextSize = 12
	l.TextColor3 = CREAM
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function build(item)
	meter = Instance.new("Frame")
	meter.Name = "BatteryMeter"
	meter.BackgroundTransparency = 1
	meter.AnchorPoint = Vector2.new(1, 0.5)
	meter.Position = UDim2.new(1, -8, 0.5, 0)
	meter.Size = UDim2.fromOffset(122, 18)
	meter.Parent = item

	local shell = Instance.new("Frame")
	shell.Name = "Shell"
	shell.BackgroundTransparency = 1
	shell.AnchorPoint = Vector2.new(0, 0.5)
	shell.Position = UDim2.new(0, 0, 0.5, 0)
	shell.Size = UDim2.fromOffset(28, 12)
	shell.Parent = meter
	local stroke = Instance.new("UIStroke")
	stroke.Color = CREAM
	stroke.Thickness = 1.4
	stroke.Parent = shell
	local nub = Instance.new("Frame")
	nub.Name = "Nub"
	nub.BorderSizePixel = 0
	nub.BackgroundColor3 = CREAM
	nub.AnchorPoint = Vector2.new(0, 0.5)
	nub.Position = UDim2.new(1, 1, 0.5, 0)
	nub.Size = UDim2.fromOffset(3, 5)
	nub.Parent = shell
	segs = {}
	for i = 1, 4 do
		local f = Instance.new("Frame")
		f.Name = "Seg" .. i
		f.BorderSizePixel = 0
		f.Position = UDim2.fromOffset(2 + (i - 1) * 6.25, 2)
		f.Size = UDim2.fromOffset(5, 8)
		f.Parent = shell
		segs[i] = f
	end
	pct = label(meter, "Percent", 36, 38)
	count = label(meter, "Spares", 74, 26)
	count.TextColor3 = MUTED
	hint = label(meter, "Hint", 98, 24, Enum.TextXAlignment.Right)
	hint.Text = "[R]"
	hint.TextColor3 = AMBER
end

local function update()
	local dread = pg:FindFirstChild("DreadHUD")
	local item = dread and dread:FindFirstChild("Loadout") and dread.Loadout:FindFirstChild("Item")
	if not item then return end
	if not (meter and meter.Parent == item) then build(item) end
	local itemLabel = item:FindFirstChild("ItemLabel")
	if itemLabel then itemLabel.Size = UDim2.new(1, -140, 1, 0) end

	local flashlight = find("IsFlashlight", true)
	meter.Visible = flashlight ~= nil
	if not flashlight then return end

	local c = math.clamp(flashlight:GetAttribute("Charge") or 100, 0, 100)
	local spares = spareBatteries()
	local now = os.clock()
	local dc = flashlight:GetAttribute("DeadClick")
	if dc ~= lastDeadClick then
		if lastDeadClick ~= nil then blinkUntil = now + 0.9 end
		lastDeadClick = dc
	end

	local col = c > 50 and CREAM or (c > 25 and AMBER or RED)
	local lit = math.ceil(c / 25)
	for i, f in ipairs(segs) do
		f.BackgroundColor3 = col
		f.BackgroundTransparency = i <= lit and 0 or 0.85
	end
	if c <= 0 then
		pct.Text = "DEAD"
		pct.TextColor3 = (now < blinkUntil and math.floor(now * 8) % 2 == 0) and CREAM or RED
	else
		pct.Text = math.floor(c + 0.5) .. "%"
		pct.TextColor3 = col
	end
	count.Text = "x" .. spares
	count.TextColor3 = spares > 0 and CREAM or MUTED
	hint.Visible = spares > 0 and c < 25 and math.floor(now * 2) % 2 == 0
end

while true do
	update()
	task.wait(0.15)
end
