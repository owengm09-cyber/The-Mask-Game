-- Mini-games: search, pour, fuses, components, power, pullcord, pump, debris.
-- Each game is fn(board, data, api). The board is 600 x 300 (local units).
local RunService = game:GetService("RunService")
local G = {}

---------------------------------------------------------------- SEARCH THE CAMP
G.search = function(board, d, api)
	local K, T = api.K, api.T
	api.status("LOOKING FOR " .. string.upper(d.item), T.AMBER)
	local cells, busy = {}, false
	for i, name in ipairs(d.places) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local b = K.button(board, "", UDim2.fromOffset(180, 130), UDim2.fromOffset(18 + col * 192, 16 + row * 142), { BackgroundColor3 = T.CARD })
		local box = K.frame(b, { Size = UDim2.new(1, -50, 0, 52), Position = UDim2.fromOffset(25, 24), BackgroundColor3 = T.RUST:Lerp(T.CARD, 0.45) })
		K.corner(3).Parent = box
		K.frame(b, { Size = UDim2.new(1, -40, 0, 9), Position = UDim2.fromOffset(20, 17), BackgroundColor3 = T.RUST })
		K.frame(box, { Size = UDim2.fromOffset(20, 7), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.3), BackgroundColor3 = T.STEEL })
		K.label(b, string.upper(name), UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 84), { TextSize = 17 })
		local res = K.label(b, "TAP TO SEARCH", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 106), { TextSize = 12, TextColor3 = T.DIM })
		cells[i] = { b = b, res = res }
		b.Activated:Connect(function()
			if cells[i].used or busy then return end
			busy = true; cells[i].used = true
			res.Text = "RUMMAGING..."; res.TextColor3 = T.MUTED
			K.shake(b)
			task.delay(0.35, function() api.act("probe", i) end)
			task.delay(1.6, function() busy = false end)
		end)
	end
	api.onResult(function(r)
		busy = false
		local e = r.extra
		if not e or not e.index then return end
		local c = cells[e.index]
		if e.hit then
			c.res.Text = "FOUND " .. string.upper(d.item); c.res.TextColor3 = T.GREEN
			c.b.BackgroundColor3 = Color3.fromRGB(32, 46, 32)
		else
			c.res.Text = "NOTHING HERE"; c.res.TextColor3 = T.DIM
			c.b.BackgroundTransparency = 0.55
			api.status("NOTHING THERE — KEEP LOOKING FOR " .. string.upper(d.item), T.MUTED)
		end
	end)
end

---------------------------------------------------------------- POUR FUEL
G.pour = function(board, d, api)
	local K, T = api.K, api.T
	local tank = K.frame(board, { Size = UDim2.fromOffset(120, 256), Position = UDim2.fromOffset(70, 22), BackgroundColor3 = Color3.fromRGB(30, 30, 34) })
	K.corner(6).Parent = tank; K.stroke(T.STEEL, 2).Parent = tank
	local fill = K.frame(tank, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.fromRGB(176, 128, 44) })
	K.corner(6).Parent = fill
	K.frame(tank, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1 - d.lo), Size = UDim2.new(1, 0, d.hi - d.lo, 0), BackgroundColor3 = T.GREEN, BackgroundTransparency = 0.7, ZIndex = 3 })
	for _, y in ipairs({ 1 - d.lo, 1 - d.hi }) do K.frame(tank, { Position = UDim2.new(0, -10, y, 0), Size = UDim2.new(1, 20, 0, 2), BackgroundColor3 = T.GREEN, ZIndex = 4 }) end
	K.label(board, "FILL LINE", UDim2.fromOffset(90, 18), UDim2.new(0, 196, 0, 22 + 256 * (1 - d.hi) - 2), { TextSize = 13, TextColor3 = T.GREEN, TextXAlignment = Enum.TextXAlignment.Left })
	K.label(board, "TANK", UDim2.fromOffset(120, 20), UDim2.fromOffset(70, 2), { TextSize = 13, TextColor3 = T.MUTED })
	local can = K.frame(board, { Size = UDim2.fromOffset(96, 120), Position = UDim2.fromOffset(250, 40), BackgroundColor3 = Color3.fromRGB(128, 36, 30) })
	K.corner(6).Parent = can
	K.frame(can, { Size = UDim2.fromOffset(30, 26), Position = UDim2.fromOffset(-18, 4), BackgroundColor3 = Color3.fromRGB(80, 74, 66) })
	K.frame(can, { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 40), BackgroundColor3 = Color3.fromRGB(96, 28, 24) })
	K.frame(can, { Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 76), BackgroundColor3 = Color3.fromRGB(96, 28, 24) })
	local stream = K.frame(board, { Size = UDim2.fromOffset(6, 0), Position = UDim2.fromOffset(212, 70), BackgroundColor3 = Color3.fromRGB(176, 128, 44), Visible = false })
	local holdBtn = K.button(board, "HOLD TO POUR", UDim2.fromOffset(220, 96), UDim2.fromOffset(360, 180), { TextSize = 26, BackgroundColor3 = Color3.fromRGB(58, 40, 30) })
	local pouring, locked, t0, level = false, false, 0, 0
	local stop
	local function start()
		if pouring or locked then return end
		pouring = true; t0 = os.clock(); level = 0
		can.Rotation = -38; stream.Visible = true
		api.status("POURING... LET GO AT THE FILL LINE", T.AMBER)
		api.act("begin")
	end
	stop = function()
		if not pouring then return end
		pouring = false; locked = true
		can.Rotation = 0; stream.Visible = false
		api.act("release")
	end
	K.track(RunService.RenderStepped:Connect(function()
		if pouring then
			level = (os.clock() - t0) / d.fill
			fill.Size = UDim2.fromScale(1, math.min(level, 1.06))
			stream.Size = UDim2.fromOffset(6, 200 * (1 - math.min(level, 1)))
			if level > 1.12 then stop() end
		end
	end))
	K.hold(holdBtn, start, stop, true)
	api.onResult(function(r)
		if r.roundDone then fill.BackgroundColor3 = T.GREEN return end
		if r.ok == false then
			if r.extra and r.extra.level and r.extra.level > d.hi then fill.BackgroundColor3 = T.BLOOD end
			task.delay(1, function()
				fill.Size = UDim2.fromScale(1, 0); fill.BackgroundColor3 = Color3.fromRGB(176, 128, 44)
				level = 0; locked = false
				api.status("TRY AGAIN — HOLD TO POUR", T.MUTED)
			end)
		end
	end)
end

---------------------------------------------------------------- FUSES / RADIO PARTS (drag or tap-tap into matching slots)
local FUSE_COLOURS = { Color3.fromRGB(196, 52, 52), Color3.fromRGB(52, 96, 196), Color3.fromRGB(214, 180, 50), Color3.fromRGB(222, 222, 214), Color3.fromRGB(64, 150, 80) }
local PART_COLOURS = { Color3.fromRGB(176, 196, 206), Color3.fromRGB(62, 92, 152), Color3.fromRGB(198, 172, 122), Color3.fromRGB(186, 112, 62), Color3.fromRGB(196, 198, 204) }
local function drawPiece(K, T, parent, kind, idx, label)
	if kind == "fuses" then
		local body = K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(34, 52), BackgroundColor3 = FUSE_COLOURS[idx] })
		K.corner(5).Parent = body
		for _, x in ipairs({ -8, 8 }) do K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0.42, 22), Size = UDim2.fromOffset(6, 12), BackgroundColor3 = T.STEEL }) end
	else
		local shapes = {
			function() local g = K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(30, 50), BackgroundColor3 = PART_COLOURS[1], BackgroundTransparency = 0.25 }) K.corner(UDim.new(0.5, 0)).Parent = g end,
			function() local g = K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(34, 42), BackgroundColor3 = PART_COLOURS[2] }) K.corner(8).Parent = g end,
			function() local g = K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(56, 18), BackgroundColor3 = PART_COLOURS[3] }) K.corner(9).Parent = g
				for k = 1, 3 do K.frame(g, { Position = UDim2.fromOffset(12 + k * 8, 0), Size = UDim2.fromOffset(4, 18), BackgroundColor3 = ({ Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 40, 40), Color3.fromRGB(200, 150, 40) })[k] }) end end,
			function() for k = 0, 4 do local g = K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.4, -16 + k * 8), Size = UDim2.fromOffset(40, 7), BackgroundColor3 = PART_COLOURS[4] }) K.corner(4).Parent = g end end,
			function() local g = K.frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(36, 28), BackgroundColor3 = PART_COLOURS[5] }) K.corner(3).Parent = g end,
		}
		shapes[idx]()
	end
	K.label(parent, label, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 1, -18), { TextSize = 12, TextColor3 = T.MUTED })
end
local function slotsGame(kind)
	return function(board, d, api)
		local K, T = api.K, api.T
		local plate = K.frame(board, { Size = UDim2.fromOffset(560, 150), Position = UDim2.fromOffset(20, 10), BackgroundColor3 = kind == "fuses" and Color3.fromRGB(42, 44, 40) or Color3.fromRGB(34, 52, 40) })
		K.corner(4).Parent = plate
		K.label(plate, kind == "fuses" and "FUSE BOX — MATCH THE RATING" or "RADIO CHASSIS — MATCH THE STENCIL", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 4), { TextSize = 13, TextColor3 = T.MUTED })
		local slots = {}
		for i = 1, 3 do
			local s = K.frame(board, { Size = UDim2.fromOffset(140, 116), Position = UDim2.fromOffset(60 + (i - 1) * 170, 36), BackgroundColor3 = Color3.fromRGB(16, 16, 19) })
			K.corner(4).Parent = s
			local st = K.stroke(T.LINE, 2); st.Parent = s
			K.label(s, d.options[d.slots[i]], UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 44), { TextSize = kind == "fuses" and 26 or 15, TextColor3 = T.DIM })
			slots[i] = { f = s, st = st, item = nil }
		end
		local selected, locked = nil, false
		local function trayPos(j) return Vector2.new(24 + (j - 1) * 114, 186) end
		local function setSel(it)
			if selected then selected.st.Color = T.LINE end
			selected = it
			if it then it.st.Color = T.AMBER end
		end
		local function submitIfFull()
			for i = 1, 3 do if not slots[i].item then return end end
			locked = true
			api.status("CHECKING...", T.MUTED)
			task.delay(0.3, function() api.act("submit", { slots[1].item.opt, slots[2].item.opt, slots[3].item.opt }) end)
		end
		local function toTray(it)
			if it.slot then slots[it.slot].item = nil; it.slot = nil end
			local p = trayPos(it.j)
			K.tween(it.b, 0.18, { Position = UDim2.fromOffset(p.X, p.Y) })
		end
		local function place(it, i)
			if slots[i].item and slots[i].item ~= it then toTray(slots[i].item) end
			if it.slot then slots[it.slot].item = nil end
			slots[i].item = it; it.slot = i
			local sp = slots[i].f.Position
			K.tween(it.b, 0.15, { Position = UDim2.fromOffset(sp.X.Offset + 20, sp.Y.Offset + 14) })
			setSel(nil)
			submitIfFull()
		end
		for i = 1, 3 do
			local hit = K.button(slots[i].f, "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), { BackgroundTransparency = 1, ZIndex = 2 })
			hit:FindFirstChildOfClass("UIStroke").Enabled = false
			hit.Activated:Connect(function() if selected and not locked then place(selected, i) end end)
		end
		for j = 1, 5 do
			local p = trayPos(j)
			local b = K.button(board, "", UDim2.fromOffset(100, 96), UDim2.fromOffset(p.X, p.Y), { BackgroundColor3 = T.CARD, ZIndex = 5 })
			drawPiece(K, T, b, kind, j, d.options[j])
			for _, c in ipairs(b:GetDescendants()) do if c:IsA("GuiObject") then c.ZIndex = 6 end end
			local it = { b = b, j = j, opt = j, st = b:FindFirstChildOfClass("UIStroke") }
			local grab, startPos, startScreen
			K.drag(b, function(pos)
				if locked then return false end
				startScreen = pos
				startPos = Vector2.new(b.Position.X.Offset, b.Position.Y.Offset)
				grab = K.toLocal(board, pos) - startPos
				b.ZIndex = 8
			end, function(pos)
				local lp = K.toLocal(board, pos) - grab
				b.Position = UDim2.fromOffset(lp.X, lp.Y)
			end, function(pos)
				b.ZIndex = 5
				if (pos - startScreen).Magnitude < 10 then
					b.Position = UDim2.fromOffset(startPos.X, startPos.Y)
					if it.slot then toTray(it) else setSel(selected == it and nil or it) end
					return
				end
				for i = 1, 3 do if K.inside(slots[i].f, pos) then place(it, i) return end end
				toTray(it)
			end)
		end
		api.status(kind == "fuses" and "DRAG (OR TAP) EACH FUSE INTO THE SLOT WITH ITS RATING" or "DRAG (OR TAP) EACH PART INTO ITS MATCHING OUTLINE", T.MUTED)
		api.onResult(function(r)
			if r.roundDone then for i = 1, 3 do slots[i].st.Color = T.GREEN end return end
			for _, i in ipairs(r.extra and r.extra.wrong or {}) do
				local s = slots[i]
				s.st.Color = T.BLOOD
				K.shake(s.f)
				if s.item then toTray(s.item) end
				task.delay(0.8, function() s.st.Color = T.LINE end)
			end
			locked = false
		end)
	end
end
G.fuses = slotsGame("fuses")
G.components = slotsGame("components")

---------------------------------------------------------------- REROUTE POWER (rotate the cable sections)
local function rotMask(mask, r)
	for _ = 1, r % 4 do
		local n = 0
		if bit32.band(mask, 1) > 0 then n += 2 end
		if bit32.band(mask, 2) > 0 then n += 4 end
		if bit32.band(mask, 4) > 0 then n += 8 end
		if bit32.band(mask, 8) > 0 then n += 1 end
		mask = n
	end
	return mask
end
local BASE = { straight = 5, corner = 3 }
local DIRS = { { 1, 0, -1 }, { 2, 1, 0 }, { 4, 0, 1 }, { 8, -1, 0 } }
local OPP = { [1] = 4, [2] = 8, [4] = 1, [8] = 2 }
G.power = function(board, d, api)
	local K, T = api.K, api.T
	local cols, rows, S, GAP = d.cols, d.rows, 62, 6
	local ox, oy = 300 - (cols * (S + GAP) - GAP) / 2, 150 - (rows * (S + GAP) - GAP) / 2
	local rots, tiles, locked = table.clone(d.rots), {}, false
	local function cellPos(c, r) return ox + (c - 1) * (S + GAP), oy + (r - 1) * (S + GAP) end
	local gx, gy = cellPos(1, d.src)
	local gen = K.frame(board, { Size = UDim2.fromOffset(54, 46), Position = UDim2.fromOffset(gx - 72, gy + 8), BackgroundColor3 = Color3.fromRGB(150, 110, 40) })
	K.corner(4).Parent = gen; K.label(gen, "GEN", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), { TextSize = 15, TextColor3 = T.INK })
	K.frame(board, { Size = UDim2.fromOffset(18, 8), Position = UDim2.fromOffset(gx - 18, gy + S / 2 - 4), BackgroundColor3 = T.AMBER })
	local sx, sy = cellPos(cols, d.dst)
	local shed = K.frame(board, { Size = UDim2.fromOffset(54, 46), Position = UDim2.fromOffset(sx + S + 18, sy + 8), BackgroundColor3 = T.CARD })
	K.corner(4).Parent = shed; K.stroke(T.LINE, 1.5).Parent = shed
	local shedLbl = K.label(shed, "SHED", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), { TextSize = 15, TextColor3 = T.DIM })
	local shedLead = K.frame(board, { Size = UDim2.fromOffset(18, 8), Position = UDim2.fromOffset(sx + S, sy + S / 2 - 4), BackgroundColor3 = T.DIM })
	local function powered()
		local function mask(c, r) local i = (r - 1) * cols + c return rotMask(BASE[d.tiles[i]], rots[i]) end
		local on = {}
		if bit32.band(mask(1, d.src), 8) == 0 then return on, false end
		local queue = { { 1, d.src } }
		on[(d.src - 1) * cols + 1] = true
		local reached = false
		while #queue > 0 do
			local c, r = queue[1][1], queue[1][2]; table.remove(queue, 1)
			local mm = mask(c, r)
			if c == cols and r == d.dst and bit32.band(mm, 2) > 0 then reached = true end
			for _, dd in ipairs(DIRS) do
				local nc, nr = c + dd[2], r + dd[3]
				if bit32.band(mm, dd[1]) > 0 and nc >= 1 and nc <= cols and nr >= 1 and nr <= rows then
					local ni = (nr - 1) * cols + nc
					if not on[ni] and bit32.band(mask(nc, nr), OPP[dd[1]]) > 0 then on[ni] = true; table.insert(queue, { nc, nr }) end
				end
			end
		end
		return on, reached
	end
	local function paint(done)
		local on, reached = powered()
		for i, t in ipairs(tiles) do
			local col = done and T.GREEN or (on[i] and T.AMBER or T.DIM)
			for _, bar in ipairs(t.bars) do bar.BackgroundColor3 = col end
		end
		shedLead.BackgroundColor3 = reached and (done and T.GREEN or T.AMBER) or T.DIM
		shedLbl.TextColor3 = reached and T.CREAM or T.DIM
		return reached
	end
	for r = 1, rows do
		for c = 1, cols do
			local i = (r - 1) * cols + c
			local x, y = cellPos(c, r)
			local b = K.button(board, "", UDim2.fromOffset(S, S), UDim2.fromOffset(x, y), { BackgroundColor3 = T.CARD })
			local rotor = K.frame(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Rotation = rots[i] * 90 })
			local bars = {}
			local hub = K.frame(rotor, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = T.DIM })
			K.corner(UDim.new(1, 0)).Parent = hub
			table.insert(bars, hub)
			table.insert(bars, K.frame(rotor, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 10, 0.5, 0), BackgroundColor3 = T.DIM }))
			if d.tiles[i] == "straight" then
				table.insert(bars, K.frame(rotor, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 10, 0.5, 0), BackgroundColor3 = T.DIM }))
			else
				table.insert(bars, K.frame(rotor, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.5, 0, 0, 10), BackgroundColor3 = T.DIM }))
			end
			tiles[i] = { b = b, rotor = rotor, bars = bars }
			b.Activated:Connect(function()
				if locked then return end
				rots[i] = (rots[i] + 1) % 4
				K.tween(rotor, 0.12, { Rotation = rotor.Rotation + 90 })
				if paint(false) then
					locked = true
					api.status("POWER REACHES THE SHED...", T.AMBER)
					api.act("submit", rots)
				end
			end)
		end
	end
	paint(false)
	api.status("TAP A CABLE SECTION TO TURN IT", T.MUTED)
	api.onResult(function(r) if r.roundDone then paint(true) else locked = false end end)
end

---------------------------------------------------------------- TIMING: starter cord (saw) / hand pump (tri)
local function timingGame(kind)
	return function(board, d, api)
		local K, T = api.K, api.T
		local function value()
			local f = ((workspace:GetServerTimeNow() - api.start) % d.period) / d.period
			return d.wave == "tri" and (1 - math.abs(2 * f - 1)) or f
		end
		local needle, place, lever
		if kind == "pullcord" then
			K.label(board, "COMPRESSION", UDim2.fromOffset(460, 18), UDim2.fromOffset(70, 30), { TextSize = 13, TextColor3 = T.MUTED, TextXAlignment = Enum.TextXAlignment.Left })
			local track = K.frame(board, { Size = UDim2.fromOffset(460, 40), Position = UDim2.fromOffset(70, 52), BackgroundColor3 = Color3.fromRGB(30, 30, 34) })
			K.corner(4).Parent = track
			K.frame(track, { Position = UDim2.fromScale(d.center - d.width, 0), Size = UDim2.fromScale(d.width * 2, 1), BackgroundColor3 = T.GREEN, BackgroundTransparency = 0.55 })
			needle = K.frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 5, 1, 14), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = T.BLOOD, ZIndex = 3 })
			place = function(v) needle.Position = UDim2.fromScale(v, 0.5) end
			local eng = K.frame(board, { Size = UDim2.fromOffset(150, 90), Position = UDim2.fromOffset(70, 130), BackgroundColor3 = Color3.fromRGB(70, 62, 52) })
			K.corner(6).Parent = eng
			for k = 0, 4 do K.frame(eng, { Size = UDim2.fromOffset(120, 5), Position = UDim2.fromOffset(15, 14 + k * 14), BackgroundColor3 = Color3.fromRGB(52, 46, 40) }) end
		else
			K.label(board, "PRESSURE", UDim2.fromOffset(80, 18), UDim2.fromOffset(60, 8), { TextSize = 13, TextColor3 = T.MUTED })
			local track = K.frame(board, { Size = UDim2.fromOffset(56, 250), Position = UDim2.fromOffset(72, 30), BackgroundColor3 = Color3.fromRGB(30, 30, 34) })
			K.corner(4).Parent = track
			K.frame(track, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 1 - d.center), Size = UDim2.fromScale(1, d.width * 2), BackgroundColor3 = T.GREEN, BackgroundTransparency = 0.55 })
			needle = K.frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 14, 0, 5), Position = UDim2.fromScale(0.5, 1), BackgroundColor3 = T.BLOOD, ZIndex = 3 })
			place = function(v) needle.Position = UDim2.fromScale(0.5, 1 - v) end
			local body = K.frame(board, { Size = UDim2.fromOffset(70, 150), Position = UDim2.fromOffset(190, 110), BackgroundColor3 = Color3.fromRGB(46, 52, 50) })
			K.corner(6).Parent = body
			lever = K.frame(board, { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(150, 12), Position = UDim2.fromOffset(240, 120), BackgroundColor3 = Color3.fromRGB(60, 66, 64) })
			K.corner(6).Parent = lever
		end
		K.track(RunService.RenderStepped:Connect(function() place(value()) end))
		local btn = K.button(board, kind == "pullcord" and "PULL CORD" or "PUMP", UDim2.fromOffset(260, 100), UDim2.fromOffset(300, 160), { TextSize = 30, BackgroundColor3 = Color3.fromRGB(58, 40, 30) })
		K.hold(btn, function()
			api.act("hit")
			if lever then K.tween(lever, 0.12, { Rotation = 22 }) task.delay(0.15, function() if lever.Parent then K.tween(lever, 0.2, { Rotation = 0 }) end end) end
		end, function() end, true)
		api.status(kind == "pullcord" and "PULL WHEN THE NEEDLE IS IN THE GREEN BAND" or "PUMP WHEN THE PRESSURE IS IN THE GREEN BAND", T.MUTED)
		api.onResult(function(r) if r.roundDone then needle.BackgroundColor3 = T.GREEN else K.shake(btn) end end)
	end
end
G.pullcord = timingGame("pullcord")
G.pump = timingGame("pump")

---------------------------------------------------------------- CLEAR THE INTAKE (drag debris off the grate)
G.debris = function(board, d, api)
	local K, T = api.K, api.T
	local rng = Random.new(d.seed)
	local grate = K.frame(board, { Size = UDim2.fromOffset(380, 230), Position = UDim2.fromOffset(110, 35), BackgroundColor3 = Color3.fromRGB(24, 30, 32) })
	K.corner(4).Parent = grate; K.stroke(T.STEEL, 2).Parent = grate
	for k = 1, 11 do K.frame(grate, { Size = UDim2.fromOffset(5, 230), Position = UDim2.fromOffset(k * 32 - 2, 0), BackgroundColor3 = Color3.fromRGB(58, 62, 64) }) end
	K.label(board, "WATER INTAKE", UDim2.fromOffset(380, 18), UDim2.fromOffset(110, 12), { TextSize = 13, TextColor3 = T.MUTED })
	local left, submitted = d.count, false
	local function finish()
		if submitted then return end
		submitted = true
		api.status("WATER IS FLOWING...", T.GREEN)
		api.act("submit")
	end
	local function toss(p, dir)
		left -= 1
		K.tween(p, 0.35, { Position = p.Position + UDim2.fromOffset(dir.X * 300, dir.Y * 300), Rotation = p.Rotation + rng:NextNumber(-90, 90), BackgroundTransparency = 1 })
		for _, c in ipairs(p:GetDescendants()) do if c:IsA("GuiObject") then K.tween(c, 0.35, { BackgroundTransparency = 1 }) end end
		task.delay(0.4, function() p:Destroy() end)
		api.status(left > 0 and (left .. " LEFT ON THE GRATE") or "CLEAR!", left > 0 and T.MUTED or T.GREEN)
		if left <= 0 then task.delay(0.3, finish) end
	end
	for i = 1, d.count do
		local branch = i % 2 == 1
		local p = K.button(board, "", branch and UDim2.fromOffset(150, 18) or UDim2.fromOffset(64, 46), UDim2.fromOffset(0, 0),
			{ AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = branch and Color3.fromRGB(92, 64, 40) or Color3.fromRGB(70, 92, 48), ZIndex = 4, Rotation = rng:NextNumber(-50, 50) })
		p:FindFirstChildOfClass("UIStroke").Enabled = false
		if branch then
			for k = 1, 3 do K.frame(p, { Size = UDim2.fromOffset(34, 7), Position = UDim2.fromOffset(18 + k * 30, k % 2 == 0 and -8 or 14), Rotation = k % 2 == 0 and -30 or 30, BackgroundColor3 = Color3.fromRGB(82, 56, 34), ZIndex = 4 }) end
		else
			p:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
			for k = 1, 3 do local l = K.frame(p, { Size = UDim2.fromOffset(26, 18), Position = UDim2.fromOffset(rng:NextInteger(0, 38), rng:NextInteger(0, 28)), BackgroundColor3 = Color3.fromRGB(96, 76, 38), ZIndex = 5 }) K.corner(UDim.new(0.5, 0)).Parent = l end
		end
		p.Position = UDim2.fromOffset(110 + rng:NextInteger(70, 310), 35 + rng:NextInteger(50, 180))
		local grab, startScreen
		K.drag(p, function(pos)
			startScreen = pos
			grab = K.toLocal(board, pos) - Vector2.new(p.Position.X.Offset, p.Position.Y.Offset)
			p.ZIndex = 6
		end, function(pos)
			local lp = K.toLocal(board, pos) - grab
			p.Position = UDim2.fromOffset(lp.X, lp.Y)
		end, function(pos)
			if (pos - startScreen).Magnitude < 10 then
				local c = Vector2.new(p.Position.X.Offset, p.Position.Y.Offset) - Vector2.new(300, 150)
				toss(p, c.Magnitude > 0 and c.Unit or Vector2.new(1, 0))
			elseif not K.inside(grate, pos) then
				local v = K.toLocal(board, pos) - Vector2.new(300, 150)
				toss(p, v.Magnitude > 0 and v.Unit or Vector2.new(1, 0))
			end
		end)
	end
	api.status("DRAG (OR TAP) EVERY BRANCH AND LEAF OFF THE GRATE", T.MUTED)
	api.onResult(function(r)
		if not r.roundDone and r.msg == "KEEP CLEARING" then task.delay(0.8, function() submitted = false finish() end) end
	end)
end

return G
