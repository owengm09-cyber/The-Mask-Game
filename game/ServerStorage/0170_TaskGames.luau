-- Server side of every rescue-task mini-game: builds each puzzle (make) and judges every player action (handle).
-- The client only ever sees what it needs to draw; the answer is checked here.
-- handle(state, action, payload, now, opened) returns nil (ignore), {done=true}, or {ok=bool, msg=string, extra=table}.
local G = {}

local function shuffle(rng, t)
	for i = #t, 2, -1 do local j = rng:NextInteger(1, i); t[i], t[j] = t[j], t[i] end
	return t
end

---------------------------------------------------------------- search the camp (Task01)
local SEARCH = {
	[1] = { places = { "Footlocker", "Cooler", "Canvas tarp", "Duffel bag", "Tool crate", "Gear bin" }, items = { "the jerry can", "the pour spout" } },
}
G.search = { minTime = 0.3,
	make = function(st, rng, ctx)
		local set = SEARCH[ctx.id] or SEARCH[1]
		st.hidden = rng:NextInteger(1, #set.places); st.checked = {}
		return { places = set.places, item = set.items[math.min(ctx.round, #set.items)] }
	end,
	handle = function(st, action, payload, now)
		if action ~= "probe" or typeof(payload) ~= "number" then return end
		local i = math.floor(payload)
		if i < 1 or i > 6 or st.checked[i] then return end
		if st.last and now - st.last < 0.25 then return end
		st.last = now; st.checked[i] = true
		if i == st.hidden then return { done = true, extra = { index = i, hit = true } } end
		return { ok = false, extra = { index = i, hit = false } }
	end }

---------------------------------------------------------------- pour fuel (Task02)
G.pour = { minTime = 0.5,
	make = function(st, rng)
		st.lo = rng:NextNumber(0.58, 0.74); st.hi = st.lo + 0.14; st.fill = 2.6
		return { lo = st.lo, hi = st.hi, fill = st.fill }
	end,
	handle = function(st, action, payload, now)
		if action == "begin" then st.began = now return nil end
		if action == "release" and st.began then
			local level = (now - st.began) / st.fill
			st.began = nil
			if level >= st.lo - 0.03 and level <= st.hi + 0.03 then return { done = true, extra = { level = level } } end
			return { ok = false, msg = level < st.lo and "NOT ENOUGH — KEEP POURING" or "OVERFILLED — FUEL SPILLED", extra = { level = level } }
		end
	end }

---------------------------------------------------------------- fuses / radio parts (Task03, Task10)
local function slots(options, failMsg)
	return { minTime = 1,
		make = function(st, rng)
			local pick = shuffle(rng, { 1, 2, 3, 4, 5 })
			st.req = { pick[1], pick[2], pick[3] }
			return { options = options, slots = { st.req[1], st.req[2], st.req[3] } }
		end,
		handle = function(st, action, payload)
			if action ~= "submit" or typeof(payload) ~= "table" then return end
			local wrong = {}
			for i = 1, 3 do if tonumber(payload[i]) ~= st.req[i] then table.insert(wrong, i) end end
			if #wrong == 0 then return { done = true } end
			return { ok = false, msg = failMsg, extra = { wrong = wrong } }
		end }
end
G.fuses = slots({ "10A", "15A", "20A", "25A", "30A" }, "WRONG RATING — THE FUSE BLEW")
G.components = slots({ "VACUUM TUBE", "CAPACITOR", "RESISTOR", "TUNING COIL", "CRYSTAL" }, "DOESN'T FIT — CHECK THE STENCIL")

---------------------------------------------------------------- reroute power (Task04): rotate cable sections
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
local function connected(cols, rows, tiles, rots, src, dst)
	local function mask(c, r) local t = tiles[(r - 1) * cols + c]; return rotMask(BASE[t], rots[(r - 1) * cols + c] or 0) end
	if bit32.band(mask(1, src), 8) == 0 then return false end
	local seen, queue = { [src * 100 + 1] = true }, { { 1, src } }
	while #queue > 0 do
		local c, r = queue[1][1], queue[1][2]; table.remove(queue, 1)
		local m = mask(c, r)
		if c == cols and r == dst and bit32.band(m, 2) > 0 then return true end
		for _, d in ipairs(DIRS) do
			local nc, nr = c + d[2], r + d[3]
			if bit32.band(m, d[1]) > 0 and nc >= 1 and nc <= cols and nr >= 1 and nr <= rows and not seen[nr * 100 + nc] then
				if bit32.band(mask(nc, nr), OPP[d[1]]) > 0 then seen[nr * 100 + nc] = true; table.insert(queue, { nc, nr }) end
			end
		end
	end
	return false
end
G.power = { minTime = 1.2,
	make = function(st, rng)
		local cols, rows = 5, 4
		local src, dst = rng:NextInteger(1, rows), rng:NextInteger(1, rows)
		local tiles, solved = {}, {}
		for i = 1, cols * rows do tiles[i] = rng:NextNumber() < 0.5 and "straight" or "corner"; solved[i] = rng:NextInteger(0, 3) end
		local path, r, entry = {}, src, 8
		for c = 1, cols do
			local target = (c == cols) and dst or rng:NextInteger(1, rows)
			while true do
				local exit
				if r == target then exit = 2 elseif target > r then exit = 4 else exit = 1 end
				table.insert(path, { c, r, entry, exit })
				if exit == 2 then entry = 8 break end
				r = r + (exit == 4 and 1 or -1); entry = OPP[exit]
			end
		end
		for _, p in ipairs(path) do
			local c, rr, e, x = p[1], p[2], p[3], p[4]
			local want = bit32.bor(e, x)
			local idx = (rr - 1) * cols + c
			local t = (want == 5 or want == 10) and "straight" or "corner"
			tiles[idx] = t
			for k = 0, 3 do if rotMask(BASE[t], k) == want then solved[idx] = k break end end
		end
		local rots = {}
		for i = 1, cols * rows do rots[i] = (solved[i] + rng:NextInteger(1, 3)) % 4 end
		st.cols, st.rows, st.tiles, st.src, st.dst = cols, rows, tiles, src, dst
		return { cols = cols, rows = rows, tiles = tiles, rots = rots, src = src, dst = dst }
	end,
	handle = function(st, action, payload)
		if action ~= "submit" or typeof(payload) ~= "table" then return end
		local rots = {}
		for i = 1, st.cols * st.rows do rots[i] = (tonumber(payload[i]) or 0) % 4 end
		if connected(st.cols, st.rows, st.tiles, rots, st.src, st.dst) then return { done = true } end
		return { ok = false, msg = "NO CURRENT — THE LINE IS STILL BROKEN" }
	end }
G._connected = connected
G._rotMask = rotMask

---------------------------------------------------------------- timing: starter cord (Task05), hand pump (Task07)
local function timing(wave, period, width, failMsg)
	return { minTime = 0.4,
		make = function(st, rng, ctx)
			st.center = rng:NextNumber(0.35, 0.72); st.width = width; st.period = period; st.wave = wave; st.start = ctx.opened
			return { center = st.center, width = st.width, period = period, wave = wave }
		end,
		handle = function(st, action, payload, now)
			if action ~= "hit" then return end
			if st.last and now - st.last < 0.35 then return end
			st.last = now
			local f = ((now - st.start) % st.period) / st.period
			local v = st.wave == "tri" and (1 - math.abs(2 * f - 1)) or f
			if math.abs(v - st.center) <= st.width + 0.04 then return { done = true } end
			return { ok = false, msg = failMsg }
		end }
end
G.pullcord = timing("saw", 2.2, 0.1, "IT SPUTTERED — PULL AT THE PEAK")
G.pump = timing("tri", 2.4, 0.1, "NO PRESSURE — WAIT FOR THE BAND")

---------------------------------------------------------------- clear the intake (Task06)
G.debris = { minTime = 2.2,
	make = function(st, rng) return { count = 6, seed = rng:NextInteger(1, 1000000) } end,
	handle = function(st, action, payload, now, opened)
		if action ~= "submit" then return end
		if now - opened >= 2.2 then return { done = true } end
		return { ok = false, msg = "KEEP CLEARING" }
	end }

---------------------------------------------------------------- loosen the battery clamp (Task08)
G.unbolt = { minTime = 2,
	make = function(st, rng)
		st.req, st.held, st.done = {}, { 0, 0, 0, 0 }, {}
		for i = 1, 4 do st.req[i] = rng:NextNumber(0.7, 1.3) end
		return { bolts = 4, req = st.req }
	end,
	handle = function(st, action, payload, now)
		local i = tonumber(payload)
		if not i then return end
		i = math.floor(i)
		if i < 1 or i > 4 then return end
		if action == "begin" then
			if not st.done[i] then st.hold = { i, now } end
			return nil
		elseif action == "release" then
			if st.hold and st.hold[1] == i then
				st.held[i] += math.min(now - st.hold[2], 3); st.hold = nil
				if st.held[i] >= st.req[i] - 0.12 then st.done[i] = true end
			end
			local all = true
			for k = 1, 4 do if not st.done[k] then all = false end end
			if all then return { done = true } end
			return { ok = st.done[i] == true, extra = { bolt = i, done = st.done[i] == true, held = st.held[i] } }
		end
	end }

---------------------------------------------------------------- charger clamps (Task09)
G.clamps = { minTime = 3,
	make = function(st, rng) st.plus = rng:NextInteger(1, 2) return { plus = st.plus, charge = 3 } end,
	handle = function(st, action, payload, now)
		if action == "connect" and typeof(payload) == "table" then
			local red, black = tonumber(payload.red), tonumber(payload.black)
			if red == st.plus and black and black ~= st.plus then st.connectedAt = now return { ok = true, extra = { charging = true } } end
			st.connectedAt = nil
			return { ok = false, msg = "WRONG POLARITY — SPARKS!" }
		elseif action == "submit" then
			if st.connectedAt and now - st.connectedAt >= 2.7 then return { done = true } end
			return { ok = false, msg = "LET IT CHARGE" }
		end
	end }

---------------------------------------------------------------- aim the antenna (Task11)
G.antenna = { minTime = 1.5,
	make = function(st, rng) st.b = rng:NextInteger(0, 71) * 5; st.e = rng:NextInteger(2, 11) * 5 return { bearing = st.b, elevation = st.e } end,
	handle = function(st, action, payload)
		if action ~= "submit" or typeof(payload) ~= "table" then return end
		local b, e = tonumber(payload.b), tonumber(payload.e)
		if not b or not e then return end
		local diff = math.abs(((b - st.b + 180) % 360) - 180)
		if diff <= 8 and math.abs(e - st.e) <= 6 then return { done = true } end
		return { ok = false, msg = "NO SIGNAL — KEEP ADJUSTING" }
	end }

---------------------------------------------------------------- the ranger's logbook (Task12)
local FILLER = {
	{ "Jun 30", "Storm took out the phone line to town again. Generator in the shed is low on fuel." },
	{ "Jul 4", "Campers saw lights moving out by the pond after midnight. Probably kids with flashlights." },
	{ "Jul 9", "Weather band: heavy fog rolling in through the weekend. Visibility under a hundred yards." },
	{ "Jul 13", "Found a cracked white mask nailed to the trail post near the old pump house. Took it down." },
	{ "Jul 18", "Bear tracks along the intake creek. Reminded counselors to keep food locked in the cooler." },
	{ "Jul 22", "Truck died on the north road. Left it. Radio battery is still under the seat." },
	{ "Jul 27", "Something knocked over the antenna mast. Wind, I hope. Need to re-aim it before inspection." },
	{ "Aug 2", "Counted the campers twice tonight. Got a different number both times." },
	{ "Aug 6", "Water tower beacon flickering again. Bulb or the wiring — can't tell from the ground." },
}
G.logbook = { minTime = 1.5,
	make = function(st, rng, ctx)
		local list = shuffle(rng, table.clone(FILLER))
		local pages = {}
		for i = 1, 5 do pages[i] = { date = list[i][1], text = list[i][2] } end
		st.correct = rng:NextInteger(2, 6)
		table.insert(pages, st.correct, { date = "Aug 11", text = "County search & rescue: if anyone goes missing, call it in on the emergency channel — "
			.. ctx.frequency .. " MHz. Keep it clear otherwise.", rescue = true })
		return { pages = pages }
	end,
	handle = function(st, action, payload)
		if action ~= "submit" or typeof(payload) ~= "number" then return end
		if math.floor(payload) == st.correct then return { done = true } end
		return { ok = false, msg = "THAT ISN'T A RADIO CHANNEL" }
	end }

---------------------------------------------------------------- tune the station radio (Task13)
G.tuning = { minTime = 1.5,
	make = function(st, rng, ctx)
		local c, f = ctx.frequency:match("(%d+)%.(%d+)")
		st.c, st.f = tonumber(c), tonumber(f)
		return { frequency = ctx.frequency }
	end,
	handle = function(st, action, payload)
		if action ~= "submit" or typeof(payload) ~= "table" then return end
		if tonumber(payload.c) == st.c and tonumber(payload.f) == st.f then return { done = true } end
		return { ok = false, msg = "STATIC — WRONG FREQUENCY" }
	end }

---------------------------------------------------------------- repeat the beacon pattern (Task14)
G.beacon = { minTime = 1.5,
	make = function(st, rng, ctx)
		local n = 2 + ctx.round
		st.p = {}
		for i = 1, n do st.p[i] = rng:NextNumber() < 0.5 and "S" or "L" end
		return { pattern = st.p }
	end,
	handle = function(st, action, payload)
		if action ~= "submit" or typeof(payload) ~= "table" or #payload ~= #st.p then return end
		for i = 1, #st.p do if payload[i] ~= st.p[i] then return { ok = false, msg = "PATTERN BROKEN — WATCH AGAIN" } end end
		return { done = true }
	end }

---------------------------------------------------------------- key S.O.S. (Task15)
G.morse = { minTime = 2.5,
	make = function() return {} end,
	handle = function(st, action, payload, now, opened)
		if action ~= "submit" or typeof(payload) ~= "table" or #payload ~= 9 then return { ok = false, msg = "GARBLED — KEY S.O.S." } end
		local expect, sum = "SSSLLLSSS", 0
		for i = 1, 9 do
			local d = tonumber(payload[i]) or 0
			sum += d
			local sym = d < 0.3 and "S" or (d <= 1.6 and "L" or "X")
			if sym ~= expect:sub(i, i) then return { ok = false, msg = "GARBLED — SHORT ×3, LONG ×3, SHORT ×3" } end
		end
		if now - opened < sum then return { ok = false, msg = "GARBLED" } end
		return { done = true }
	end }

---------------------------------------------------------------- tower radio wires (Task16)
G.wires = { minTime = 1.2,
	make = function(st, rng)
		st.left = shuffle(rng, { 1, 2, 3, 4 })
		-- terminals never line up with the wires, so there's always something to untangle
		repeat st.right = shuffle(rng, { 1, 2, 3, 4 }) until st.right[1] ~= st.left[1] or st.right[2] ~= st.left[2] or st.right[3] ~= st.left[3]
		return { left = st.left, right = st.right }
	end,
	handle = function(st, action, payload)
		if action ~= "submit" or typeof(payload) ~= "table" then return end
		local used, wrong = {}, {}
		for i = 1, 4 do
			local j = tonumber(payload[i])
			if not j or used[j] or st.right[j] ~= st.left[i] then table.insert(wrong, i) end
			if j then used[j] = true end
		end
		if #wrong == 0 then return { done = true } end
		return { ok = false, msg = "WRONG CONNECTION — SPARKS", extra = { wrong = wrong } }
	end }

return G
