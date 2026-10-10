-- CampfireRebuilder: the realistic campfire in workspace.EmergencyCampsite
--   require(game.ServerStorage.CampfireRebuilder).Build()    -- swap in the big realistic fire and the log seats
--   require(game.ServerStorage.CampfireRebuilder).Restore()  -- put the old fire circle back (ServerStorage.BeforeRealisticCampfire)
-- The pieces come from ServerStorage.CampfireKit (Creator Store assets with their scripts removed; see its
-- Sources attribute): a teepee of logs on an ash bed inside a stone ring, flipbook flames, smoke and sparks,
-- and the forest's own log mesh for the seats. The meeting seats (MeetingSeats) keep their places round the
-- fire and are lifted onto the new, thicker logs. StarterPlayerScripts.CampfireFlicker makes the light flicker.
local B = {}
local SS = game:GetService("ServerStorage")
local KIT = SS:WaitForChild("CampfireKit")
local CENTER = Vector3.new(160, 0, 0)
local FIRE_SCALE = 1.6 -- the kit's campfire is about 7 studs across; this one is about 11
local LOG_SCALE = Vector3.new(0.76, 0.62, 0.62) -- seat logs: about 10.7 long and 2.3 thick (the old ones were 9.6 x 1.7)
-- the old fire circle's pieces this replaces
local OLD = { FireGlow = true, Firewood = true, GlowingCoal = true, CharredEarth = true, FireRingStones = true, SeatingLog = true, CutLogEnd = true, Heartwood = true, Campfire = true }

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), rp)
	return hit and hit.Position.Y or 0
end
local function NS(points) local k = {} for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end return NumberSequence.new(k) end
local function CS(points) local k = {} for _, p in points do table.insert(k, ColorSequenceKeypoint.new(p[1], p[2])) end return ColorSequence.new(k) end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local function anchorAll(m)
	for _, d in (m:IsA("BasePart") and { m } or m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true d.CanTouch = false end
	end
end
local function invisible(name, size, cf, parent)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Transparency = 1
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false p.CastShadow = false
	p.Parent = parent
	return p
end
local function flame(name, parent, o)
	local e = KIT.Flame:Clone()
	e.Name = name
	e.Rate = o.rate
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Size = NS(o.size)
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.SpreadAngle = Vector2.new(o.spread, o.spread)
	e.Acceleration = Vector3.new(0, o.rise, 0)
	-- the flame sprites are additive (they glow): they need to be very bright to read in daylight, and much less
	-- at night or they burn out to white. CampfireFlicker switches between the two with the Lighting Phase.
	e.Brightness = o.night
	e:SetAttribute("DayBrightness", o.day)
	e:SetAttribute("NightBrightness", o.night)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.ZOffset = o.z or 1
	e.Rotation = NumberRange.new(-12, 12)
	e.Color = CS({ { 0, rgb(255, 120, 45) }, { 0.5, rgb(255, 84, 24) }, { 1, rgb(190, 36, 10) } })
	e.Transparency = NS({ { 0, 1 }, { 0.08, 0.12 }, { 0.65, 0.3 }, { 1, 1 } })
	e.Parent = parent
	return e
end

function B.Build()
	local camp = workspace.EmergencyCampsite
	if not SS:FindFirstChild("BeforeRealisticCampfire") then
		local bk = camp:Clone() bk.Name = "BeforeRealisticCampfire" bk.Parent = SS
	end
	local before = SS.BeforeRealisticCampfire
	for _, c in camp:GetChildren() do if OLD[c.Name] then c:Destroy() end end
	local fire = Instance.new("Model") fire.Name = "Campfire" fire.Parent = camp
	local gy = ground(CENTER.X, CENTER.Z)

	-- the fire: logs in a teepee on a bed of ash, inside a ring of dark stones
	local base = KIT.CampfireBase:Clone()
	base:ScaleTo(FIRE_SCALE)
	local ash = base:FindFirstChild("Ash")
	-- keep the ash inside the stone ring: a low bed of pale grey ash, like a fire that's been burning a while
	-- (not a black disc), flattened so the earth shows round its edge
	ash.Size = ash.Size * Vector3.new(0.7, 0.55, 0.7)
	ash.Color = rgb(122, 116, 108)
	for _, d in ash:GetChildren() do if d:IsA("Decal") then d.Color3 = rgb(150, 142, 132) end end
	base:PivotTo(base:GetPivot() + Vector3.new(CENTER.X - ash.Position.X, (gy - 0.25) - (ash.Position.Y - ash.Size.Y / 2), CENTER.Z - ash.Position.Z))
	anchorAll(base)
	local rng = Random.new(31)
	-- the stone ring: real textured field stones (KIT.FireStone) set edge to edge round the ash, half buried,
	-- blackened by the fire on the inside row, with a few smaller stones wedged on top and in the gaps
	base.Rocks:Destroy()
	local ring = Instance.new("Model") ring.Name = "FireRingStones"
	local rrng = Random.new(77)
	local function stone(src, pos, len, tall, yaw, tilt, shade)
		local r = src:Clone()
		local k = len / math.max(r.Size.X, r.Size.Z)
		r.Size = Vector3.new(r.Size.X * k, tall, r.Size.Z * k)
		r.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt.X, 0, tilt.Y)
		-- the stone's photo texture is very pale and a plain texture can't be tinted, so it's worn as a
		-- SurfaceAppearance colour map, which can: weathered grey, darker where the fire has sooted it
		if r.TextureID ~= "" and not r:FindFirstChildOfClass("SurfaceAppearance") then
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = r.TextureID
			sa.Color = Color3.fromRGB(shade, shade - 4, shade - 10)
			sa.Parent = r
			r.TextureID = ""
		end
		r.Color = Color3.fromRGB(shade, shade - 2, shade - 6)
		r.Anchored = true r.CanTouch = false r.CanCollide = len > 1 r.CastShadow = true
		r.Name = "FireRingStone"
		r.Parent = ring
		return r
	end
	local R0 = 4.95 -- ring radius (the ash bed is about 4.2)
	local N = 19
	for i = 1, N do
		local a = (i + rrng:NextNumber(-0.18, 0.18)) / N * math.pi * 2
		local len = rrng:NextNumber(1.75, 2.25)
		local tall = rrng:NextNumber(0.95, 1.35)
		local rr = R0 + rrng:NextNumber(-0.15, 0.2)
		local pos = Vector3.new(CENTER.X + math.cos(a) * rr, gy + tall * 0.18, CENTER.Z + math.sin(a) * rr)
		-- long side along the ring, leaning a little in towards the fire
		local yaw = -a + math.pi / 2 + rrng:NextNumber(-0.25, 0.25)
		stone(KIT.FireStone, pos, len, tall, yaw, Vector2.new(rrng:NextNumber(-0.12, 0.12), rrng:NextNumber(-0.1, 0.1)), rrng:NextInteger(98, 142))
	end
	-- smaller stones: some sitting on the ring's top, some packed into the outside of it
	for i = 1, 13 do
		local a = rrng:NextNumber(0, math.pi * 2)
		local onTop = i <= 6
		local len = onTop and rrng:NextNumber(0.8, 1.1) or rrng:NextNumber(0.7, 1.1)
		local tall = len * rrng:NextNumber(0.45, 0.6)
		local rr = onTop and R0 + rrng:NextNumber(-0.1, 0.15) or R0 + rrng:NextNumber(0.9, 1.4)
		local y = onTop and gy + 0.95 + tall * 0.25 or gy + tall * 0.15
		local pos = Vector3.new(CENTER.X + math.cos(a) * rr, y, CENTER.Z + math.sin(a) * rr)
		stone(onTop and KIT.FireStone or KIT.RiverStone, pos, len, tall, rrng:NextNumber(0, math.pi * 2), Vector2.new(rrng:NextNumber(-0.25, 0.25), rrng:NextNumber(-0.25, 0.25)), onTop and rrng:NextInteger(100, 130) or rrng:NextInteger(140, 175))
	end
	ring.Parent = base
	for _, s in base.Sticks:GetDescendants() do if s:IsA("BasePart") then s.CanCollide = false end end
	ash.CanCollide = false
	base.Parent = fire
	-- embers glowing in the ash under the logs
	for i = 1, 16 do
		local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * 2.6
		local x, z = CENTER.X + math.cos(a) * d, CENTER.Z + math.sin(a) * d
		local e = Instance.new("Part")
		e.Name = "Ember" e.Size = Vector3.new(rng:NextNumber(0.4, 0.9), 0.18, rng:NextNumber(0.3, 0.6))
		e.CFrame = CFrame.new(x, ash.Position.Y + ash.Size.Y * 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2))
		e.Material = Enum.Material.Neon
		e.Color = ({ rgb(255, 92, 20), rgb(236, 64, 14), rgb(255, 128, 40) })[rng:NextInteger(1, 3)]
		e.Anchored = true e.CanCollide = false e.CanQuery = false e.CanTouch = false e.CastShadow = false
		e.Parent = fire
	end

	-- flames, sparks and smoke
	local core = invisible("FireCore", Vector3.new(3.4, 0.4, 3.4), CFrame.new(CENTER.X, gy + 1.0, CENTER.Z), fire)
	local bed = invisible("FireBed", Vector3.new(6, 0.3, 6), CFrame.new(CENTER.X, gy + 0.7, CENTER.Z), fire)
	local root = Instance.new("Attachment") root.Name = "FlameRoot" root.Position = Vector3.new(0, 0.3, 0) root.Parent = core
	local top = Instance.new("Attachment") top.Name = "SmokeRoot" top.Position = Vector3.new(0, 6.5, 0) top.Parent = core
	local lightAt = Instance.new("Attachment") lightAt.Name = "LightPoint" lightAt.Position = Vector3.new(0, 3.2, 0) lightAt.Parent = core
	-- the body of the fire across the logs, a tall column up the middle, low flames licking round the edge
	flame("FlameBody", core, { rate = 30, life = { 0.75, 1.2 }, size = { { 0, 5.2 }, { 0.55, 4.2 }, { 1, 1.4 } }, speed = { 0.5, 1.5 }, spread = 8, rise = 10, day = 70, night = 7, z = 1.2 })
	flame("FlameTall", root, { rate = 11, life = { 1.0, 1.5 }, size = { { 0, 7.2 }, { 0.5, 5.6 }, { 1, 2 } }, speed = { 1, 2 }, spread = 6, rise = 12, day = 65, night = 6, z = 1.4 })
	flame("FlameLick", bed, { rate = 16, life = { 0.5, 0.9 }, size = { { 0, 2.2 }, { 0.5, 1.8 }, { 1, 0.6 } }, speed = { 0.3, 1 }, spread = 12, rise = 7, day = 70, night = 7, z = 0.8 })
	local sp = KIT.Sparks:Clone()
	sp.Name = "Sparks"
	sp.Rate = 14
	sp.Lifetime = NumberRange.new(2, 3.6)
	sp.Speed = NumberRange.new(4, 8)
	sp.SpreadAngle = Vector2.new(25, 25)
	sp.Acceleration = Vector3.new(0.6, 1.4, 0.3)
	sp.Drag = 0.6
	sp.Size = NS({ { 0, 0.2 }, { 1, 0.04 } })
	sp.LightEmission = 1
	sp.Brightness = 6
	sp.Color = CS({ { 0, rgb(255, 190, 100) }, { 1, rgb(255, 80, 25) } })
	sp.Transparency = NS({ { 0, 0 }, { 0.8, 0.25 }, { 1, 1 } })
	sp.Parent = core
	for _, n in { "Smoke1", "Smoke2" } do
		local s = KIT[n]:Clone()
		s.Rate = 4
		s.Lifetime = NumberRange.new(5, 8)
		s.Speed = NumberRange.new(2.5, 3.5)
		s.SpreadAngle = Vector2.new(8, 8)
		s.Acceleration = Vector3.new(0.8, 1.1, 0.3)
		s.Drag = 0.15
		s.Size = NS({ { 0, 3 }, { 0.4, 9 }, { 1, 16 } })
		s.Transparency = NS({ { 0, 1 }, { 0.15, 0.82 }, { 0.6, 0.9 }, { 1, 1 } })
		s.Color = CS({ { 0, rgb(58, 56, 54) }, { 1, rgb(84, 84, 86) } })
		s.LightInfluence = 0.35 -- lit a little by the fire, not glowing orange
		s.RotSpeed = NumberRange.new(-10, 10)
		s.Parent = top
	end
	-- light: a big warm one up in the flames (CampfireFlicker makes it flicker) and a low glow off the embers
	local light = Instance.new("PointLight")
	light.Name = "CampfireLight" light.Color = rgb(255, 138, 58) light.Brightness = 3 light.Range = 48 light.Shadows = true
	light:SetAttribute("BaseBrightness", 3) light:SetAttribute("BaseRange", 48)
	light.Parent = lightAt
	local glow = Instance.new("PointLight")
	glow.Name = "CoalGlow" glow.Color = rgb(255, 90, 35) glow.Brightness = 2 glow.Range = 12 glow.Shadows = false
	glow:SetAttribute("BaseBrightness", 2) glow:SetAttribute("BaseRange", 12)
	glow.Parent = root
	local crackle = KIT.Crackle:Clone()
	crackle.Looped = true crackle.Volume = 0.9
	crackle.RollOffMode = Enum.RollOffMode.InverseTapered crackle.RollOffMinDistance = 8 crackle.RollOffMaxDistance = 70
	crackle.Playing = true
	crackle.Parent = core

	-- the seat logs: the forest's log mesh, thicker and longer, lying where the old ones did, cut faces at the ends
	local logs = {}
	for _, old in before:GetChildren() do
		if old.Name == "SeatingLog" and old:IsA("BasePart") then
			local mid = old.Position
			local t = old.CFrame.RightVector
			t = Vector3.new(t.X, 0, t.Z).Unit
			local out = Vector3.new(mid.X - CENTER.X, 0, mid.Z - CENTER.Z).Unit
			-- any snag on the log's side faces away from the fire, so the seat side is smooth
			if t:Cross(Vector3.yAxis):Dot(out) < 0 then t = -t end
			local log = KIT.SeatLog:Clone()
			log.Name = "SeatingLog"
			log.Size = KIT.SeatLog.Size * LOG_SCALE
			local low = math.min(ground(mid.X, mid.Z), ground(mid.X + t.X * 4, mid.Z + t.Z * 4), ground(mid.X - t.X * 4, mid.Z - t.Z * 4))
			log.CFrame = CFrame.fromMatrix(Vector3.new(mid.X, low + log.Size.Y / 2 - 0.3, mid.Z), t, Vector3.yAxis)
			log.Anchored = true log.CanCollide = true log.CanTouch = false
			log.Parent = camp
			table.insert(logs, log)
		end
	end
	-- set each meeting seat into the top of its log: a sitting counselor's thighs end up resting on the bark
	-- (measured: with the seat's top at the log's top they hovered about 0.15 above it)
	local lp = RaycastParams.new()
	lp.FilterType = Enum.RaycastFilterType.Include
	lp.FilterDescendantsInstances = logs
	local seated = 0
	for _, seat in camp.MeetingSeats:GetChildren() do
		local hit = workspace:Raycast(seat.Position + Vector3.new(0, 8, 0), Vector3.new(0, -16, 0), lp)
		if hit then
			seat.CFrame = (seat.CFrame - seat.Position) + Vector3.new(seat.Position.X, hit.Position.Y - 0.22, seat.Position.Z)
			seated += 1
		end
	end
	return { logs = #logs, seatsOnLogs = seated, groundY = gy }
end

function B.Restore()
	local camp = workspace.EmergencyCampsite
	local before = SS:FindFirstChild("BeforeRealisticCampfire")
	if not before then return false end
	for _, c in camp:GetChildren() do if OLD[c.Name] then c:Destroy() end end
	for _, c in before:GetChildren() do if OLD[c.Name] then c:Clone().Parent = camp end end
	for _, seat in camp.MeetingSeats:GetChildren() do
		local o = before.MeetingSeats:FindFirstChild(seat.Name)
		if o then seat.CFrame = o.CFrame end
	end
	return true
end

return B
