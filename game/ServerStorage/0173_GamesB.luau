-- Mini-games: unbolt, clamps, antenna, logbook, tuning, beacon, morse, wires.
local RunService = game:GetService("RunService")
local G = {}
local function strokeOf(o) return o:FindFirstChildOfClass("UIStroke") end

---------------------------------------------------------------- LOOSEN THE BATTERY CLAMP (hold each bolt)
G.unbolt = function(board, d, api)
	local K, T = api.K, api.T
	local plate = K.frame(board, { Size = UDim2.fromOffset(400, 230), Position = UDim2.fromOffset(100, 35), BackgroundColor3 = Color3.fromRGB(64, 58, 50) })
	K.corner(6).Parent = plate; K.stroke(Color3.fromRGB(40, 36, 32), 3).Parent = plate
	local bat = K.frame(plate, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(200, 110), BackgroundColor3 = Color3.fromRGB(30, 30, 32) })
	K.corner(4).Parent = bat
	K.label(bat, "RADIO BATTERY  12V", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), { TextSize = 16, TextColor3 = T.MUTED })
	K.label(board, "UNDER THE TRUCK SEAT", UDim2.fromOffset(400, 18), UDim2.fromOffset(100, 12), { TextSize = 13, TextColor3 = T.MUTED })
	local corners = { { 40, 40 }, { 360, 40 }, { 40, 190 }, { 360, 190 } }
	local held, loose, holding, t0 = { 0, 0, 0, 0 }, {}, nil, 0
	for i, c in ipairs(corners) do
		local b = K.button(plate, "", UDim2.fromOffset(84, 84), UDim2.fromOffset(c[1] - 42, c[2] - 42), { BackgroundColor3 = Color3.fromRGB(40, 36, 32), ZIndex = 3 })
		b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		local ring = K.frame(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundColor3 = T.AMBER, BackgroundTransparency = 0.4, ZIndex = 3 })
		K.corner(UDim.new(1, 0)).Parent = ring
		local head = K.frame(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Color3.fromRGB(128, 82, 52), ZIndex = 4 })
		K.corner(6).Parent = head
		K.frame(head, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 6), BackgroundColor3 = Color3.fromRGB(70, 46, 30), ZIndex = 5 })
		local function progress() return (held[i] + (holding == i and (os.clock() - t0) or 0)) / d.req[i] end
		local function down()
			if loose[i] or holding then return end
			holding = i; t0 = os.clock()
			api.act("begin", i)
		end
		local function up()
			if holding ~= i then return end
			held[i] += os.clock() - t0
			holding = nil
			api.act("release", i)
			if held[i] >= d.req[i] - 0.12 then
				loose[i] = true
				K.tween(head, 0.3, { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 })
				ring.BackgroundColor3 = T.GREEN
			end
		end
		K.hold(b, down, up)
		K.track(RunService.RenderStepped:Connect(function()
			local p = math.min(progress(), 1)
			ring.Size = UDim2.fromOffset(84 * p, 84 * p)
			if holding == i then
				head.Rotation = (os.clock() - t0) * -220
				if p >= 1 then up() end
			end
		end))
	end
	api.status("PRESS AND HOLD EACH RUSTED BOLT UNTIL IT TURNS FREE", T.MUTED)
	api.onResult(function(r)
		if r.extra and r.extra.bolt and not r.extra.done and not loose[r.extra.bolt] then api.status("STILL STUCK — KEEP TURNING THAT ONE", T.AMBER) end
	end)
end

---------------------------------------------------------------- CHARGER CLAMPS (red to +, black to −)
G.clamps = function(board, d, api)
	local K, T = api.K, api.T
	local bat = K.frame(board, { Size = UDim2.fromOffset(280, 140), Position = UDim2.fromOffset(160, 70), BackgroundColor3 = Color3.fromRGB(32, 32, 34) })
	K.corner(6).Parent = bat
	K.label(bat, "12V", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), { TextSize = 30, TextColor3 = T.DIM })
	local terms = {}
	for side = 1, 2 do
		local isPlus = (side == d.plus)
		local t = K.frame(board, { Size = UDim2.fromOffset(64, 46), Position = UDim2.fromOffset(side == 1 and 190 or 346, 30), BackgroundColor3 = Color3.fromRGB(150, 140, 120) })
		K.corner(4).Parent = t
		K.label(t, isPlus and "+" or "−", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), { TextSize = 34, TextColor3 = isPlus and Color3.fromRGB(150, 30, 30) or T.INK })
		terms[side] = t
	end
	local charger = K.frame(board, { Size = UDim2.fromOffset(140, 44), Position = UDim2.fromOffset(230, 244), BackgroundColor3 = Color3.fromRGB(56, 58, 52) })
	K.corner(4).Parent = charger
	local meter = K.frame(charger, { Size = UDim2.new(0, 0, 0, 6), Position = UDim2.new(0, 6, 1, -10), BackgroundColor3 = T.AMBER })
	K.label(charger, "CHARGER", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 4), { TextSize = 14, TextColor3 = T.MUTED })
	local clamps, selected, connected, charging = {}, nil, {}, false
	local homes = { red = Vector2.new(80, 230), black = Vector2.new(520, 230) }
	local function anchorOf(name) return Vector2.new(name == "red" and 250 or 350, 262) end
	local function tryConnect()
		if connected.red and connected.black and not charging then
			api.status("CONNECTING...", T.MUTED)
			api.act("connect", { red = connected.red, black = connected.black })
		end
	end
	for _, name in ipairs({ "red", "black" }) do
		local colour = name == "red" and Color3.fromRGB(190, 40, 40) or Color3.fromRGB(26, 26, 28)
		local c = K.button(board, name == "red" and "RED" or "BLACK", UDim2.fromOffset(76, 58), UDim2.fromOffset(homes[name].X, homes[name].Y), { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = colour, TextSize = 14, ZIndex = 5 })
		local _, setCable = K.line(board, anchorOf(name), homes[name], 6, colour, 2)
		local cl = { b = c }
		clamps[name] = cl
		local function moveTo(p) c.Position = UDim2.fromOffset(p.X, p.Y); setCable(anchorOf(name), p) end
		cl.attach = function(side)
			connected[name] = side
			local tp = terms[side].Position
			moveTo(Vector2.new(tp.X.Offset + 32, tp.Y.Offset + 46))
			tryConnect()
		end
		cl.reset = function() connected[name] = nil; moveTo(homes[name]) end
		local startScreen
		K.drag(c, function(pos) if charging then return false end startScreen = pos; connected[name] = nil end,
			function(pos) moveTo(K.toLocal(board, pos)) end,
			function(pos)
				if (pos - startScreen).Magnitude < 10 then
					moveTo(homes[name]); selected = (selected == name) and nil or name
					for n2, other in pairs(clamps) do strokeOf(other.b).Color = (n2 == selected) and T.AMBER or T.LINE end
					return
				end
				for side = 1, 2 do if K.inside(terms[side], pos) then cl.attach(side) return end end
				moveTo(homes[name])
			end)
	end
	for side = 1, 2 do
		local hit = K.button(terms[side], "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), { BackgroundTransparency = 1 })
		strokeOf(hit).Enabled = false
		hit.Activated:Connect(function()
			if selected and not charging then local s = selected; selected = nil; strokeOf(clamps[s].b).Color = T.LINE; clamps[s].attach(side) end
		end)
	end
	api.status("CLIP RED TO + AND BLACK TO − (DRAG, OR TAP A CLAMP THEN A TERMINAL)", T.MUTED)
	api.onResult(function(r)
		if r.roundDone then meter.BackgroundColor3 = T.GREEN return end
		if r.extra and r.extra.charging then
			charging = true
			api.status("CHARGING — HOLD ON...", T.AMBER)
			K.tween(meter, 3, { Size = UDim2.new(1, -12, 0, 6) }, Enum.EasingStyle.Linear)
			task.delay(3.05, function() api.act("submit") end)
		elseif r.msg == "LET IT CHARGE" then
			task.delay(0.4, function() api.act("submit") end)
		else
			K.shake(bat)
			bat.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
			task.delay(0.3, function() if bat.Parent then bat.BackgroundColor3 = Color3.fromRGB(32, 32, 34) end end)
			clamps.red.reset(); clamps.black.reset()
		end
	end)
end

---------------------------------------------------------------- AIM THE ANTENNA (bearing dial + elevation)
G.antenna = function(board, d, api)
	local K, T = api.K, api.T
	local bearing, elev = math.random(0, 71) * 5, 30
	local dial = K.frame(board, { Size = UDim2.fromOffset(220, 220), Position = UDim2.fromOffset(30, 20), BackgroundColor3 = Color3.fromRGB(26, 28, 30) })
	K.corner(UDim.new(1, 0)).Parent = dial; K.stroke(T.STEEL, 2).Parent = dial
	for k, txt in ipairs({ "N", "E", "S", "W" }) do
		local a = math.rad((k - 1) * 90)
		K.label(dial, txt, UDim2.fromOffset(24, 24), UDim2.fromOffset(110 + math.sin(a) * 92 - 12, 110 - math.cos(a) * 92 - 12), { TextSize = 16, TextColor3 = T.MUTED })
	end
	local _, setNeedle = K.line(dial, Vector2.new(110, 110), Vector2.new(110, 30), 5, T.BLOOD, 4)
	local hub = K.frame(dial, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(110, 110), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = T.STEEL, ZIndex = 5 })
	K.corner(UDim.new(1, 0)).Parent = hub
	local bLabel = K.label(board, "", UDim2.fromOffset(140, 22), UDim2.fromOffset(70, 244), { TextSize = 16 })
	local track = K.frame(board, { Size = UDim2.fromOffset(28, 200), Position = UDim2.fromOffset(300, 34), BackgroundColor3 = Color3.fromRGB(26, 28, 30) })
	K.corner(4).Parent = track
	local knob = K.frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(48, 22), BackgroundColor3 = T.STEEL, ZIndex = 3 })
	K.corner(4).Parent = knob
	local eLabel = K.label(board, "", UDim2.fromOffset(80, 22), UDim2.fromOffset(274, 244), { TextSize = 16 })
	K.label(board, "TILT", UDim2.fromOffset(60, 18), UDim2.fromOffset(284, 12), { TextSize = 13, TextColor3 = T.MUTED })
	K.label(board, "SIGNAL", UDim2.fromOffset(200, 18), UDim2.fromOffset(380, 12), { TextSize = 13, TextColor3 = T.MUTED })
	local bars = {}
	for k = 1, 10 do bars[k] = K.frame(board, { Size = UDim2.fromOffset(14, 10 + k * 9), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(384 + (k - 1) * 19, 150), BackgroundColor3 = T.LINE }) end
	local sigText = K.label(board, "", UDim2.fromOffset(200, 22), UDim2.fromOffset(380, 156), { TextSize = 15, Font = Enum.Font.SpecialElite })
	local function strength()
		local db = math.abs(((bearing - d.bearing + 180) % 360) - 180)
		local de = math.abs(elev - d.elevation)
		return math.clamp(1 - db / 70, 0, 1) * math.clamp(1 - de / 30, 0, 1)
	end
	local function redraw()
		local a = math.rad(bearing)
		setNeedle(Vector2.new(110, 110), Vector2.new(110 + math.sin(a) * 82, 110 - math.cos(a) * 82))
		bLabel.Text = string.format("BEARING %03d°", bearing)
		knob.Position = UDim2.fromScale(0.5, 1 - elev / 60)
		eLabel.Text = elev .. "°"
		local s = strength()
		for k, b in ipairs(bars) do b.BackgroundColor3 = (k <= math.floor(s * 10 + 0.001)) and (s > 0.85 and T.GREEN or T.AMBER) or T.LINE end
		sigText.Text = s > 0.85 and "clear signal" or (s > 0.4 and "faint voices in the static" or "static")
	end
	K.drag(dial, function() end, function(pos)
		local lp = K.toLocal(dial, pos) - Vector2.new(110, 110)
		if lp.Magnitude > 10 then bearing = (math.floor((math.deg(math.atan2(lp.X, -lp.Y)) % 360) / 5 + 0.5) * 5) % 360 redraw() end
	end, function() end)
	K.drag(track, function() end, function(pos)
		local lp = K.toLocal(track, pos)
		elev = math.clamp(math.floor((1 - lp.Y / 200) * 12 + 0.5) * 5, 0, 60) redraw()
	end, function() end)
	local function stepper(text, pos, fn)
		local b = K.button(board, text, UDim2.fromOffset(52, 44), pos, { TextSize = 20 })
		b.Activated:Connect(function() fn() redraw() end)
	end
	stepper("◄", UDim2.fromOffset(14, 244), function() bearing = (bearing - 5) % 360 end)
	stepper("►", UDim2.fromOffset(214, 244), function() bearing = (bearing + 5) % 360 end)
	stepper("▲", UDim2.fromOffset(336, 50), function() elev = math.min(60, elev + 5) end)
	stepper("▼", UDim2.fromOffset(336, 180), function() elev = math.max(0, elev - 5) end)
	local lock = K.button(board, "LOCK ANTENNA", UDim2.fromOffset(190, 64), UDim2.fromOffset(392, 206), { TextSize = 22, BackgroundColor3 = Color3.fromRGB(58, 40, 30) })
	lock.Activated:Connect(function() api.status("LOCKING...", T.MUTED) api.act("submit", { b = bearing, e = elev }) end)
	redraw()
	api.status("TURN THE DIAL AND TILT THE MAST UNTIL THE SIGNAL IS CLEAR", T.MUTED)
	api.onResult(function(r) if not r.roundDone then K.shake(lock) end end)
end

---------------------------------------------------------------- THE RANGER'S LOGBOOK
G.logbook = function(board, d, api)
	local K, T = api.K, api.T
	local page = 1
	local paper = K.frame(board, { Size = UDim2.fromOffset(520, 218), Position = UDim2.fromOffset(40, 12), BackgroundColor3 = Color3.fromRGB(206, 194, 166) })
	K.corner(3).Parent = paper
	K.frame(paper, { Size = UDim2.fromOffset(70, 46), Position = UDim2.fromOffset(410, 150), BackgroundColor3 = Color3.fromRGB(150, 110, 70), BackgroundTransparency = 0.6 })
	for k = 1, 7 do K.frame(paper, { Size = UDim2.new(1, -40, 0, 1), Position = UDim2.fromOffset(20, 44 + k * 22), BackgroundColor3 = Color3.fromRGB(150, 160, 170), BackgroundTransparency = 0.5 }) end
	local date = K.label(paper, "", UDim2.new(1, -40, 0, 28), UDim2.fromOffset(20, 10), { Font = Enum.Font.SpecialElite, TextSize = 20, TextColor3 = Color3.fromRGB(70, 40, 30), TextXAlignment = Enum.TextXAlignment.Left })
	local body = K.label(paper, "", UDim2.new(1, -40, 0, 160), UDim2.fromOffset(20, 46), { Font = Enum.Font.SpecialElite, TextSize = 18, TextColor3 = Color3.fromRGB(34, 30, 28), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local num = K.label(board, "", UDim2.fromOffset(160, 20), UDim2.fromOffset(220, 232), { TextSize = 14, TextColor3 = T.MUTED })
	local function show()
		local p = d.pages[page]
		date.Text = p.date; body.Text = p.text
		num.Text = "PAGE " .. page .. " / " .. #d.pages
	end
	local prev = K.button(board, "◄", UDim2.fromOffset(80, 46), UDim2.fromOffset(40, 250), { TextSize = 22 })
	local nxt = K.button(board, "►", UDim2.fromOffset(80, 46), UDim2.fromOffset(480, 250), { TextSize = 22 })
	prev.Activated:Connect(function() page = math.max(1, page - 1) show() end)
	nxt.Activated:Connect(function() page = math.min(#d.pages, page + 1) show() end)
	local copy = K.button(board, "COPY THIS CHANNEL", UDim2.fromOffset(240, 46), UDim2.fromOffset(180, 250), { TextSize = 18, BackgroundColor3 = Color3.fromRGB(58, 40, 30) })
	copy.Activated:Connect(function() api.act("submit", page) end)
	local startX
	K.drag(paper, function(pos) startX = pos.X end, function() end, function(pos)
		if startX and math.abs(pos.X - startX) > 50 then page = math.clamp(page + (pos.X < startX and 1 or -1), 1, #d.pages) show() end
	end)
	show()
	api.status("FLIP THROUGH (◄ ► OR SWIPE) AND COPY THE EMERGENCY CHANNEL", T.MUTED)
	api.onResult(function(r) if r.roundDone then body.TextColor3 = Color3.fromRGB(30, 80, 30) else K.shake(paper) end end)
end

---------------------------------------------------------------- TUNE THE STATION RADIO
G.tuning = function(board, d, api)
	local K, T = api.K, api.T
	local tc, tf = d.frequency:match("(%d+)%.(%d+)")
	tc, tf = tonumber(tc), tonumber(tf)
	local c, f = 140 + math.random(0, 10), math.random(0, 19) * 5
	local face = K.frame(board, { Size = UDim2.fromOffset(400, 280), Position = UDim2.fromOffset(16, 10), BackgroundColor3 = Color3.fromRGB(46, 52, 42) })
	K.corner(6).Parent = face
	local screen = K.frame(face, { Size = UDim2.fromOffset(360, 90), Position = UDim2.fromOffset(20, 16), BackgroundColor3 = Color3.fromRGB(14, 16, 12) })
	K.corner(4).Parent = screen
	local freq = K.label(screen, "", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), { TextSize = 50, TextColor3 = T.AMBER, Font = Enum.Font.RobotoMono })
	local noise = {}
	for k = 1, 24 do noise[k] = K.frame(face, { AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(10, 4), Position = UDim2.fromOffset(24 + k * 14, 156), BackgroundColor3 = T.DIM }) end
	local function knob(label, x, onStep)
		local k = K.frame(face, { Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(x, 166), BackgroundColor3 = Color3.fromRGB(30, 30, 30) })
		K.corner(UDim.new(1, 0)).Parent = k; K.stroke(T.STEEL, 2).Parent = k
		local mark = K.frame(k, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 34), BackgroundColor3 = T.CREAM })
		K.label(face, label, UDim2.fromOffset(80, 16), UDim2.fromOffset(x, 250), { TextSize = 12, TextColor3 = T.MUTED })
		local minus = K.button(face, "◄", UDim2.fromOffset(42, 42), UDim2.fromOffset(x - 46, 186), { TextSize = 16 })
		local plus = K.button(face, "►", UDim2.fromOffset(42, 42), UDim2.fromOffset(x + 84, 186), { TextSize = 16 })
		minus.Activated:Connect(function() onStep(-1) end)
		plus.Activated:Connect(function() onStep(1) end)
		local lastY
		K.drag(k, function(pos) lastY = pos.Y end, function(pos)
			if lastY and math.abs(pos.Y - lastY) > 14 then onStep(pos.Y < lastY and 1 or -1); lastY = pos.Y end
		end, function() end)
		return mark
	end
	local redraw
	local markC = knob("COARSE", 66, function(s) c = math.clamp(c + s, 140, 150) redraw() end)
	local markF = knob("FINE", 256, function(s) f = (f + s * 5) % 100 redraw() end)
	redraw = function()
		freq.Text = string.format("%d.%02d MHz", c, f)
		markC.Rotation = (c - 140) * 27; markF.Rotation = f * 2.7
	end
	local note = K.frame(board, { Size = UDim2.fromOffset(160, 110), Position = UDim2.fromOffset(426, 14), BackgroundColor3 = Color3.fromRGB(206, 194, 166), Rotation = 3 })
	K.label(note, "from the logbook:\n" .. d.frequency .. " MHz", UDim2.new(1, -16, 1, -16), UDim2.fromOffset(8, 8), { Font = Enum.Font.SpecialElite, TextSize = 17, TextColor3 = Color3.fromRGB(40, 30, 26) })
	local test = K.button(board, "TEST TRANSMIT", UDim2.fromOffset(160, 70), UDim2.fromOffset(426, 210), { TextSize = 20, BackgroundColor3 = Color3.fromRGB(58, 40, 30) })
	test.Activated:Connect(function() api.status("LISTENING...", T.MUTED) api.act("submit", { c = c, f = f }) end)
	K.track(RunService.RenderStepped:Connect(function()
		local off = math.abs(c - tc) * 20 + math.abs(f - tf)
		local n = math.clamp(off / 40, 0.03, 1)
		for _, b in ipairs(noise) do b.Size = UDim2.fromOffset(10, 4 + math.random() * 40 * n) end
	end))
	redraw()
	api.status("DIAL IN THE CHANNEL FROM THE LOGBOOK UNTIL THE STATIC DIES", T.MUTED)
	api.onResult(function(r) if r.roundDone then freq.TextColor3 = T.GREEN else K.shake(screen) end end)
end

---------------------------------------------------------------- BEACON PATTERN
G.beacon = function(board, d, api)
	local K, T = api.K, api.T
	local lamp = K.frame(board, { Size = UDim2.fromOffset(150, 150), Position = UDim2.fromOffset(60, 60), BackgroundColor3 = Color3.fromRGB(40, 34, 26) })
	K.corner(UDim.new(1, 0)).Parent = lamp; K.stroke(T.STEEL, 3).Parent = lamp
	K.label(board, "SIGNAL BEACON", UDim2.fromOffset(150, 18), UDim2.fromOffset(60, 30), { TextSize = 13, TextColor3 = T.MUTED })
	local entered, playing, alive = {}, false, true
	K.track(function() alive = false end)
	local seq = K.label(board, "", UDim2.fromOffset(300, 40), UDim2.fromOffset(270, 230), { TextSize = 32, TextColor3 = T.AMBER, TextXAlignment = Enum.TextXAlignment.Left })
	local function on(v) if alive then lamp.BackgroundColor3 = v and Color3.fromRGB(255, 196, 90) or Color3.fromRGB(40, 34, 26) end end
	local function drawSeq() local t = {} for _, s in ipairs(entered) do table.insert(t, s == "S" and "•" or "—") end seq.Text = table.concat(t, "  ") end
	local function play()
		playing = true; entered = {}; drawSeq()
		api.status("WATCH THE BEACON...", T.AMBER)
		task.spawn(function()
			task.wait(0.6)
			for _, s in ipairs(d.pattern) do if not alive then return end on(true) task.wait(s == "S" and 0.28 or 0.85) on(false) task.wait(0.4) end
			playing = false
			if alive then api.status("YOUR TURN — REPEAT IT: " .. #d.pattern .. " FLASHES", T.CREAM) end
		end)
	end
	local function press(sym)
		if playing then return end
		table.insert(entered, sym); drawSeq()
		on(true) task.delay(sym == "S" and 0.15 or 0.4, function() on(false) end)
		if #entered == #d.pattern then playing = true; api.act("submit", entered) end
	end
	local short = K.button(board, "SHORT  •", UDim2.fromOffset(150, 80), UDim2.fromOffset(270, 70), { TextSize = 24 })
	local long = K.button(board, "LONG  —", UDim2.fromOffset(150, 80), UDim2.fromOffset(430, 70), { TextSize = 24 })
	short.Activated:Connect(function() press("S") end)
	long.Activated:Connect(function() press("L") end)
	local replay = K.button(board, "WATCH AGAIN", UDim2.fromOffset(150, 44), UDim2.fromOffset(270, 170), { TextSize = 16 })
	replay.Activated:Connect(function() if not playing then play() end end)
	api.onResult(function(r) if not r.roundDone then K.shake(lamp) task.delay(0.6, play) end end)
	play()
end

---------------------------------------------------------------- KEY S.O.S.
G.morse = function(board, d, api)
	local K, T = api.K, api.T
	local expect = "SSSLLLSSS"
	local durs, symbols, t0, sent = {}, {}, nil, false
	local card = K.frame(board, { Size = UDim2.fromOffset(560, 70), Position = UDim2.fromOffset(20, 14), BackgroundColor3 = Color3.fromRGB(206, 194, 166) })
	K.corner(3).Parent = card
	local cells = {}
	for i = 1, 9 do
		local s = expect:sub(i, i)
		cells[i] = K.label(card, s == "S" and "•" or "—", UDim2.fromOffset(46, 46), UDim2.fromOffset(28 + (i - 1) * 56 + math.floor((i - 1) / 3) * 12, 12), { TextSize = 34, TextColor3 = Color3.fromRGB(110, 100, 90) })
	end
	local light = K.frame(board, { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(60, 140), BackgroundColor3 = Color3.fromRGB(60, 20, 18) })
	K.corner(UDim.new(1, 0)).Parent = light
	K.label(board, "TX", UDim2.fromOffset(40, 18), UDim2.fromOffset(60, 184), { TextSize = 13, TextColor3 = T.MUTED })
	local key = K.button(board, "HOLD TO KEY", UDim2.fromOffset(300, 110), UDim2.fromOffset(150, 110), { TextSize = 26, BackgroundColor3 = Color3.fromRGB(58, 40, 30) })
	local function refresh()
		for i = 1, 9 do
			local got = symbols[i]
			cells[i].TextColor3 = got == nil and Color3.fromRGB(110, 100, 90) or (got == expect:sub(i, i) and Color3.fromRGB(40, 110, 40) or Color3.fromRGB(170, 30, 30))
		end
	end
	local function reset() durs, symbols, sent = {}, {}, false refresh() end
	K.hold(key, function()
		if sent then return end
		t0 = os.clock(); light.BackgroundColor3 = T.BLOOD
	end, function()
		if not t0 or sent then return end
		local dur = os.clock() - t0; t0 = nil
		light.BackgroundColor3 = Color3.fromRGB(60, 20, 18)
		table.insert(durs, dur); table.insert(symbols, dur < 0.3 and "S" or "L")
		refresh()
		if #durs == 9 then sent = true; api.status("TRANSMITTING...", T.AMBER); api.act("submit", durs) end
	end, true)
	local clear = K.button(board, "CLEAR", UDim2.fromOffset(110, 50), UDim2.fromOffset(470, 140), { TextSize = 18 })
	clear.Activated:Connect(reset)
	api.status("TAP = SHORT, HOLD = LONG.  SHORT ×3, LONG ×3, SHORT ×3", T.MUTED)
	api.onResult(function(r) if not r.roundDone then K.shake(card) task.delay(0.8, reset) end end)
end

---------------------------------------------------------------- TOWER RADIO WIRES (match the colours)
local WIRE = {
	{ colour = Color3.fromRGB(196, 44, 44), shape = "circle" },
	{ colour = Color3.fromRGB(48, 96, 206), shape = "square" },
	{ colour = Color3.fromRGB(226, 194, 52), shape = "diamond" },
	{ colour = Color3.fromRGB(56, 156, 74), shape = "bar" },
}
local function badge(K, parent, w, pos, z)
	local s
	if w.shape == "circle" then s = K.frame(parent, { Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1) }) K.corner(UDim.new(1, 0)).Parent = s
	elseif w.shape == "square" then s = K.frame(parent, { Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1) })
	elseif w.shape == "diamond" then s = K.frame(parent, { Size = UDim2.fromOffset(15, 15), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1) })
	else s = K.frame(parent, { Size = UDim2.fromOffset(22, 7), BackgroundColor3 = Color3.new(1, 1, 1) }) end
	s.AnchorPoint = Vector2.new(0.5, 0.5); s.Position = pos; s.ZIndex = z or 6
	return s
end
G.wires = function(board, d, api)
	local K, T = api.K, api.T
	local pl = K.frame(board, { Size = UDim2.fromOffset(150, 270), Position = UDim2.fromOffset(10, 8), BackgroundColor3 = Color3.fromRGB(46, 52, 42) })
	K.corner(4).Parent = pl
	local pr = K.frame(board, { Size = UDim2.fromOffset(150, 270), Position = UDim2.fromOffset(440, 8), BackgroundColor3 = Color3.fromRGB(28, 30, 28) })
	K.corner(4).Parent = pr
	K.label(board, "LOOSE WIRES", UDim2.fromOffset(150, 16), UDim2.fromOffset(10, 280), { TextSize = 12, TextColor3 = T.MUTED })
	K.label(board, "RADIO TERMINALS", UDim2.fromOffset(150, 16), UDim2.fromOffset(440, 280), { TextSize = 12, TextColor3 = T.MUTED })
	local function rowY(i) return 44 + (i - 1) * 64 end
	local leftNodes, rightNodes, links, locked, selected = {}, {}, {}, false, nil
	for j = 1, 4 do
		local w = WIRE[d.right[j]]
		local plate = K.frame(board, { Size = UDim2.fromOffset(84, 40), Position = UDim2.fromOffset(484, rowY(j) - 20), BackgroundColor3 = w.colour:Lerp(Color3.new(0, 0, 0), 0.3) })
		K.corner(4).Parent = plate
		badge(K, plate, w, UDim2.fromOffset(54, 20), 4)
		local node = K.button(board, "", UDim2.fromOffset(40, 40), UDim2.fromOffset(442, rowY(j) - 20), { BackgroundColor3 = Color3.fromRGB(170, 146, 92), ZIndex = 5 })
		node:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		rightNodes[j] = { node = node, plate = plate }
	end
	local function rightPoint(j) return Vector2.new(462, rowY(j)) end
	local function leftPoint(i) return Vector2.new(152, rowY(i)) end
	local function connect(i, j)
		for li, l in pairs(links) do if l.j == j and li ~= i then l.line:Destroy() links[li] = nil end end
		if links[i] then links[i].line:Destroy() end
		local line = K.line(board, leftPoint(i), rightPoint(j), 10, WIRE[d.left[i]].colour, 3)
		links[i] = { j = j, line = line }
		local n = 0
		for _ in pairs(links) do n += 1 end
		if n == 4 then
			locked = true
			api.status("CHECKING THE CONNECTIONS...", T.MUTED)
			local map = {}
			for k = 1, 4 do map[k] = links[k].j end
			task.delay(0.35, function() api.act("submit", map) end)
		end
	end
	local function setSelected(i)
		selected = i
		for k, n in ipairs(leftNodes) do local st = strokeOf(n) st.Color = (k == selected) and T.CREAM or T.LINE st.Thickness = (k == selected) and 3 or 1.5 end
	end
	for i = 1, 4 do
		local w = WIRE[d.left[i]]
		local stub = K.frame(board, { Size = UDim2.fromOffset(112, 18), Position = UDim2.fromOffset(20, rowY(i) - 9), BackgroundColor3 = w.colour })
		K.corner(UDim.new(1, 0)).Parent = stub
		badge(K, stub, w, UDim2.fromOffset(22, 9), 4)
		local node = K.button(board, "", UDim2.fromOffset(42, 42), UDim2.fromOffset(130, rowY(i) - 21), { BackgroundColor3 = w.colour, ZIndex = 5 })
		node:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		leftNodes[i] = node
		local ghost, setGhost, startScreen
		K.drag(node, function(pos)
			if locked then return false end
			startScreen = pos
			ghost, setGhost = K.line(board, leftPoint(i), K.toLocal(board, pos), 10, w.colour, 7)
		end, function(pos)
			if setGhost then setGhost(leftPoint(i), K.toLocal(board, pos)) end
		end, function(pos)
			if ghost then ghost:Destroy() ghost = nil setGhost = nil end
			if (pos - startScreen).Magnitude < 10 then setSelected(selected == i and nil or i) return end
			for j = 1, 4 do if K.inside(rightNodes[j].node, pos) or K.inside(rightNodes[j].plate, pos) then connect(i, j) return end end
		end)
	end
	for j = 1, 4 do
		rightNodes[j].node.Activated:Connect(function()
			if selected and not locked then local i = selected setSelected(nil) connect(i, j) end
		end)
	end
	api.status("DRAG EACH WIRE TO THE TERMINAL OF THE SAME COLOUR (OR TAP WIRE, THEN TERMINAL)", T.MUTED)
	api.onResult(function(r)
		if r.roundDone then
			for _, l in pairs(links) do l.line.BackgroundColor3 = l.line.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.25) end
			api.status("STATIC... THEN A VOICE. THE RELAY IS ALIVE.", T.GREEN)
			return
		end
		for _, i in ipairs(r.extra and r.extra.wrong or {}) do
			if links[i] then
				local line = links[i].line
				line.BackgroundColor3 = Color3.fromRGB(255, 220, 140)
				task.delay(0.35, function() line:Destroy() end)
				links[i] = nil
			end
		end
		locked = false
	end)
end

return G
