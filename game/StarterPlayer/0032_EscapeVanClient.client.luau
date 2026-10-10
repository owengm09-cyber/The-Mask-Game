-- EscapeVanClient: the escape vehicle (a yellow camp bus) on this player's screen (server: EscapeVanService).
-- Everything players read says "camp bus" or "bus"; the code and attributes keep their old "van" names.
--   * A banner when the van starts, moves, and leaves.
--   * A countdown under the clock: when the van leaves, and (until it has) when it moves.
--   * A marker over the van with how far away it is — everyone sees it, the killer too. It's a race.
--   * Once you're in the van: "YOU GOT AWAY", and the camera circles the van until the round ends.
-- Amber is the van's colour everywhere (it matches the ESCAPE VAN list in the task panel).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local p = Players.LocalPlayer
local config = workspace:WaitForChild("MaskSystem")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("EscapeVan")

local PAPER = Color3.fromRGB(232, 229, 218)
local MUTED = Color3.fromRGB(177, 173, 165)
local INK = Color3.fromRGB(15, 17, 17)
local AMBER = Color3.fromRGB(205, 128, 58)
local RED = Color3.fromRGB(196, 34, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "EscapeVanHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false -- same coordinates as the clock it sits under
gui.DisplayOrder = 62
gui.Parent = p:WaitForChild("PlayerGui")
local overlay = Instance.new("ScreenGui") -- full screen, for "you got away"
overlay.Name = "EscapeVanOverlay"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 61
overlay.Parent = p.PlayerGui
local function new(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function tween(o, t, goal, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
local function isKiller() return p:GetAttribute("Role") == "Killer" or p:GetAttribute("HasMask") == true end

---------------------------------------------------------------- the banner
-- a strip across the upper middle of the screen: the headline big, the instruction under it
local banner = new("Frame", gui, { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(1, 0, 0, 118), BackgroundColor3 = INK, BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false })
local bannerGrad = new("UIGradient", banner, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 0.25),
	NumberSequenceKeypoint.new(0.78, 0.25), NumberSequenceKeypoint.new(1, 1) }) })
local bannerRule = new("Frame", banner, { Name = "Rule", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 0, 0, 2),
	BackgroundColor3 = AMBER, BorderSizePixel = 0 })
local bannerTitle = new("TextLabel", banner, { Name = "Title", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.new(1, -40, 0, 54),
	BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 48, TextColor3 = PAPER, Text = "", TextTransparency = 1 })
local bannerSub = new("TextLabel", banner, { Name = "Sub", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.new(1, -40, 0, 26),
	BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 21, TextColor3 = AMBER, Text = "", TextTransparency = 1 })
local bannerToken = 0
local function showBanner(title, sub, colour, seconds)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerSub.Text = sub or ""
	bannerSub.TextColor3 = colour or AMBER
	bannerRule.BackgroundColor3 = colour or AMBER
	banner.Visible = true
	banner.BackgroundTransparency = 0
	bannerTitle.TextTransparency = 1 bannerSub.TextTransparency = 1
	bannerTitle.Position = UDim2.new(0.5, 0, 0, 26)
	bannerRule.Size = UDim2.new(0, 0, 0, 2)
	tween(bannerRule, 0.5, { Size = UDim2.new(0.56, 0, 0, 2) })
	tween(bannerTitle, 0.45, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, 16) })
	task.delay(0.25, function() if token == bannerToken then tween(bannerSub, 0.4, { TextTransparency = 0 }) end end)
	task.delay(seconds or 5, function()
		if token ~= bannerToken then return end
		tween(bannerTitle, 0.5, { TextTransparency = 1 })
		tween(bannerSub, 0.5, { TextTransparency = 1 })
		tween(bannerRule, 0.5, { Size = UDim2.new(0, 0, 0, 2) })
		task.delay(0.55, function() if token == bannerToken then banner.Visible = false end end)
	end)
end

---------------------------------------------------------------- small alerts (who got in, the killer's notice)
local alert = new("TextLabel", gui, { Name = "VanAlert", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136),
	Size = UDim2.fromOffset(520, 26), BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 19, TextColor3 = AMBER,
	TextStrokeTransparency = 1, TextTransparency = 1, Text = "" })
local alertToken = 0
local function showAlert(msg, colour)
	alertToken += 1
	local token = alertToken
	alert.Text = msg alert.TextColor3 = colour or AMBER
	alert.TextTransparency = 0 alert.TextStrokeTransparency = 0.5
	task.delay(4, function() if token == alertToken then tween(alert, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 }) end end)
end

---------------------------------------------------------------- the countdown under the clock
local chip = new("Frame", gui, { Name = "VanTimer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76),
	Size = UDim2.fromOffset(240, 52), BackgroundColor3 = INK, BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false })
new("UICorner", chip, { CornerRadius = UDim.new(0, 6) })
new("UIStroke", chip, { Color = Color3.fromRGB(70, 62, 58), Thickness = 1 })
local chipEdge = new("Frame", chip, { Name = "Edge", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = AMBER, BorderSizePixel = 0 })
local chipLabel = new("TextLabel", chip, { Name = "Label", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -90, 0, 20),
	Font = Enum.Font.Oswald, TextSize = 15, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left, Text = "BUS LEAVES IN" })
local chipTime = new("TextLabel", chip, { Name = "Time", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4),
	Size = UDim2.fromOffset(76, 30), Font = Enum.Font.Oswald, TextSize = 28, TextColor3 = AMBER, TextXAlignment = Enum.TextXAlignment.Right, Text = "5:00" })
local chipSub = new("TextLabel", chip, { Name = "Sub", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 16),
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

---------------------------------------------------------------- the marker over the van
-- (a BillboardGui only draws as a direct child of PlayerGui, not inside the ScreenGui)
local marker = new("BillboardGui", p.PlayerGui, { Name = "VanMarker", AlwaysOnTop = true, Size = UDim2.fromOffset(150, 46), StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0),
	LightInfluence = 0, MaxDistance = 100000, Enabled = false, ResetOnSpawn = false })
local pip = new("Frame", marker, { Name = "Pip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(12, 12),
	BackgroundColor3 = AMBER, BorderSizePixel = 0, Rotation = 45 })
new("UIStroke", pip, { Color = INK, Thickness = 1.5 })
local markerName = new("TextLabel", marker, { Name = "Name", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 18),
	Font = Enum.Font.Oswald, TextSize = 17, TextColor3 = AMBER, TextStrokeTransparency = 0.3, Text = "CAMP BUS" })
local markerDist = new("TextLabel", marker, { Name = "Distance", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, 0, 0, 14),
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = PAPER, TextStrokeTransparency = 0.4, Text = "" })

---------------------------------------------------------------- you got away
local away = new("Frame", overlay, { Name = "GotAway", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
local vignette = new("Frame", away, { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0 })
new("UIGradient", vignette, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.35, 0.85),
	NumberSequenceKeypoint.new(0.65, 0.85), NumberSequenceKeypoint.new(1, 0.2) }), Rotation = 90 })
local awayTitle = new("TextLabel", away, { Name = "Title", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.new(1, -40, 0, 60),
	BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 56, TextColor3 = PAPER, Text = "YOU GOT AWAY", TextTransparency = 1 })
local awaySub = new("TextLabel", away, { Name = "Sub", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -80), Size = UDim2.new(1, -40, 0, 24),
	BackgroundTransparency = 1, Font = Enum.Font.Oswald, TextSize = 19, TextColor3 = AMBER, Text = "", TextTransparency = 1 })
local orbit = nil
local function stopOrbit()
	if not orbit then return end
	orbit:Disconnect() orbit = nil
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if h then cam.CameraSubject = h end
	away.Visible = false
end
local function startOrbit()
	if orbit then return end
	away.Visible = true
	tween(vignette, 0.8, { BackgroundTransparency = 0 })
	tween(awayTitle, 0.8, { TextTransparency = 0 })
	task.delay(0.4, function() tween(awaySub, 0.6, { TextTransparency = 0 }) end)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local angle = 0
	orbit = RunService.RenderStepped:Connect(function(dt)
		local van = workspace:FindFirstChild("EscapeVan")
		if not van or not p:GetAttribute("Escaped") then stopOrbit() return end
		angle += dt * 0.18
		local centre = van:GetPivot().Position + Vector3.new(0, 3, 0)
		local eye = centre + Vector3.new(math.cos(angle) * 24, 9, math.sin(angle) * 24)
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(eye, centre), math.min(1, dt * 4))
	end)
end
p:GetAttributeChangedSignal("Escaped"):Connect(function() if not p:GetAttribute("Escaped") then stopOrbit() end end)

---------------------------------------------------------------- server messages
remote.OnClientEvent:Connect(function(action, data)
	if action == "start" then
		showBanner("THE CAMP BUS IS HERE", isKiller() and "DON'T LET THEM REACH IT" or "GET TO IT BEFORE THE KILLER CATCHES YOU", isKiller() and RED or AMBER, 6)
	elseif action == "moving" then
		showBanner("THE CAMP BUS IS MOVING", isKiller() and "IT'S PULLING UP SOMEWHERE ELSE" or "IT'S PULLING UP SOMEWHERE ELSE — FOLLOW THE MARKER", nil, 5)
	elseif action == "moved" then
		showAlert("THE BUS HAS STOPPED — 2 MINUTES LEFT")
	elseif action == "leaving" then
		showBanner("THE CAMP BUS IS LEAVING", "", nil, 3.5)
	elseif action == "gone" then
		local n = data and data.escaped or 0
		showBanner("THE CAMP BUS IS GONE", n == 0 and "NOBODY MADE IT" or (n == 1 and "ONE CAMPER GOT AWAY" or (n .. " CAMPERS GOT AWAY")), n == 0 and RED or AMBER, 5)
	elseif action == "boarded" then
		local who = data and data.band and data.band ~= "" and string.upper(data.band) or (data and string.upper(data.name or "SOMEONE") or "SOMEONE")
		if not p:GetAttribute("Escaped") then showAlert(who .. " GOT ON THE BUS") end
	elseif action == "escaped" then
		startOrbit()
	elseif action == "notice" then
		showAlert(data, RED)
	end
end)

---------------------------------------------------------------- every frame: the countdown and the marker
RunService.RenderStepped:Connect(function()
	local state = config:GetAttribute("VanState")
	local running = state == "Running"
	local t = workspace:GetServerTimeNow()
	local endsAt = config:GetAttribute("VanEndsAt")
	local movesAt = config:GetAttribute("VanMovesAt")
	local paused = config:GetAttribute("VanPaused") == true
	local watching = p:GetAttribute("InRound") == true or p:GetAttribute("Escaped") == true
	chip.Visible = running and watching and endsAt ~= nil
	if chip.Visible then
		local left = endsAt - t
		chipTime.Text = clock(left)
		local urgent = left <= 30 and not paused
		chipTime.TextColor3 = urgent and (math.floor(t * 2) % 2 == 0 and RED or PAPER) or AMBER
		chipEdge.BackgroundColor3 = urgent and RED or AMBER
		chipSub.Text = paused and "PAUSED FOR THE MEETING" or (movesAt and ("MOVES SOMEWHERE ELSE IN " .. clock(movesAt - t)) or "IT WON'T WAIT AGAIN")
	end
	local van = workspace:FindFirstChild("EscapeVan")
	local body = van and van:FindFirstChild("Body")
	marker.Enabled = body ~= nil and running and p:GetAttribute("InRound") == true and not p:GetAttribute("Escaped")
	if marker.Enabled then
		marker.Adornee = body
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		markerDist.Text = root and (math.floor((root.Position - body.Position).Magnitude) .. " STUDS") or ""
	end
	if p:GetAttribute("Escaped") then
		awaySub.Text = endsAt and ("THE BUS LEAVES IN " .. clock(endsAt - t)) or (state == "Gone" and "ON THE ROAD OUT" or "")
	end
end)
