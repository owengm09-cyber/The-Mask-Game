-- RadioTowerBuilder (ServerStorage) — builds workspace.RadioTower, west of the middle of the map.
--   require(game.ServerStorage.RadioTowerBuilder).Build()
-- The lattice tower itself is a Creator Store model (asset 8788183000, red/white with dishes), kept in
-- ServerStorage.RadioTowerKit. Everything people touch is added here: concrete footings, invisible leg
-- colliders (the lattice mesh doesn't collide), the climbing ladder up the outside of the north face, the work
-- platform with railings on top of the lattice, the transmitter cabinet (task 19) with its empty module socket,
-- the push-off kill spot, the aviation light, and the spots round the map where the spare module and the
-- ladder-repair items can turn up.
-- The ladder comes up through a notch in the north edge of the platform. The notch has an invisible lid and
-- gate that only exist for people who are not climbing (RadioTowerClient switches them per player), so nobody
-- walks off the platform through it, while climbers come straight up.
local B = {}

local KIT = game.ServerStorage:WaitForChild("RadioTowerKit")
local MESH_AT = Vector3.new(-36, 0, 0)  -- x,z of the mesh's bounding box centre
local BASE_Y = -2.5                     -- bottom of the lattice
local SCALE = 0.8
-- measured on the scaled mesh: the lattice's centre line sits off its bounding-box centre (the dishes stick out)
local AXIS_OFFSET = Vector3.new(-2.53, 0, -3.10)
local function hw(h) return 8.58 - 0.0839 * (h - 1) end -- outer half-width of the tapering lattice, h studs up
local DECK_H = 65.6                     -- top of the platform, studs above the lattice base
local DECK_HALF = 5
local LADDER_X = 0                      -- the ladder runs up the middle of the north face
local RAIL_GAP = 0.95                   -- rails at ±this along X
local STANDOFF = 0.35                   -- how far the rails sit out from the face
local NOTCH = 1.3                       -- half-width of the opening in the platform where the ladder comes up
local RAIL_H = 3.3
local CABINET = Vector3.new(3.7, 0, -3.5)

local STEEL = Color3.fromRGB(150, 154, 156)
local GRATE = Color3.fromRGB(88, 90, 92)
local CONCRETE = Color3.fromRGB(150, 146, 138)
local RED = Color3.fromRGB(178, 40, 34)
local YELLOW = Color3.fromRGB(214, 180, 40)

local folder, C
local function part(name, size, cf, colour, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour or STEEL
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do p[k] = v end
	return p
end
local INVISIBLE = { Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false }
local function at(x, h, z) return C + Vector3.new(x, h, z) end
local function ladderZ(h) return hw(h) + STANDOFF end -- the ladder follows the slope of the face
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include
groundRay.FilterDescendantsInstances = { workspace.Terrain }
local function ground(x, z)
	local r = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), groundRay)
	return r and r.Position.Y or BASE_Y
end
local function beam(name, a, b, thick, colour, parent, props)
	local len = (b - a).Magnitude
	local p = part(name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), colour, Enum.Material.Metal, props)
	p.Parent = parent
	return p
end

---------------------------------------------------------------- pieces
local function buildTower()
	local mesh = KIT.Tower:Clone()
	mesh.Name = "Lattice"
	mesh.Size = KIT.Tower.Size * SCALE
	mesh.CFrame = CFrame.new(MESH_AT.X, BASE_Y + mesh.Size.Y / 2, MESH_AT.Z)
	mesh.Anchored = true
	mesh.CanCollide = false  -- the lattice itself can't be climbed; the ladder is the way up
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.CollisionFidelity = Enum.CollisionFidelity.Box
	mesh.Parent = folder
	-- concrete footings under the four legs, down into the slope
	local legs = Instance.new("Folder")
	legs.Name = "Legs"
	legs.Parent = folder
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local i0 = hw(0) - 0.35
			local x, z = C.X + sx * i0, C.Z + sz * i0
			local g = ground(x, z)
			local top = C.Y + 0.15
			local bottomY = math.min(g, top) - 1.6
			part("Footing", Vector3.new(2.6, top - bottomY, 2.6), CFrame.new(x, (top + bottomY) / 2, z), CONCRETE, Enum.Material.Concrete).Parent = legs
			-- the lattice is see-through to physics, so each leg gets an invisible collider
			local h1 = DECK_H - 0.6
			beam("LegCollider", Vector3.new(x, C.Y, z), at(sx * (hw(h1) - 0.35), h1, sz * (hw(h1) - 0.35)), 0.9, STEEL, legs, INVISIBLE)
		end
	end
end

local function buildDeck()
	local deck = Instance.new("Model")
	deck.Name = "Platform"
	deck.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the notch lid and gate arrive with the platform
	deck.Parent = folder
	local y = C.Y + DECK_H
	local T = 0.35
	local H = DECK_HALF
	local zn = hw(DECK_H) + 0.1 -- inner edge of the notch (the face side)
	local function slab(x0, x1, z0, z1)
		if x1 - x0 < 0.05 or z1 - z0 < 0.05 then return end
		part("Grating", Vector3.new(x1 - x0, T, z1 - z0), CFrame.new(C.X + (x0 + x1) / 2, y - T / 2, C.Z + (z0 + z1) / 2), GRATE, Enum.Material.DiamondPlate).Parent = deck
	end
	slab(-H, -NOTCH, -H, H)      -- west of the notch
	slab(NOTCH, H, -H, H)        -- east of the notch
	slab(-NOTCH, NOTCH, -H, zn)  -- between them, up to the notch
	-- frame under the grating (the north beam stops either side of the notch), braced down to the lattice
	local by = DECK_H - T - 0.2
	beam("DeckBeam", at(-H, by, -H), at(H, by, -H), 0.35, RED, deck)
	beam("DeckBeam", at(-H, by, -H), at(-H, by, H), 0.35, RED, deck)
	beam("DeckBeam", at(H, by, -H), at(H, by, H), 0.35, RED, deck)
	beam("DeckBeam", at(-H, by, H), at(-NOTCH - 0.2, by, H), 0.35, RED, deck)
	beam("DeckBeam", at(NOTCH + 0.2, by, H), at(H, by, H), 0.35, RED, deck)
	beam("DeckBeam", at(-NOTCH - 0.2, by, zn), at(-NOTCH - 0.2, by, H), 0.3, RED, deck)
	beam("DeckBeam", at(NOTCH + 0.2, by, zn), at(NOTCH + 0.2, by, H), 0.3, RED, deck)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local h0 = DECK_H - 7
			beam("Strut", at(sx * (hw(h0) - 0.35), h0, sz * (hw(h0) - 0.35)), at(sx * (H - 0.2), DECK_H - T - 0.3, sz * (H - 0.2)), 0.28, STEEL, deck)
		end
	end
	-- railing: posts, top rail, knee rail, toe board; plus an invisible wall so nobody tumbles off by accident
	-- (pushes go over it by script)
	local function railSide(a, b)
		beam("TopRail", a + Vector3.new(0, RAIL_H, 0), b + Vector3.new(0, RAIL_H, 0), 0.22, YELLOW, deck)
		beam("KneeRail", a + Vector3.new(0, RAIL_H / 2, 0), b + Vector3.new(0, RAIL_H / 2, 0), 0.16, STEEL, deck)
		local d = b - a
		part("ToeBoard", Vector3.new(0.08, 0.35, d.Magnitude), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.18, 0), b + Vector3.new(0, 0.18, 0)), STEEL).Parent = deck
		local n = math.max(1, math.floor(d.Magnitude / 2.5))
		for i = 0, n do
			local p = a + d * (i / n)
			part("Post", Vector3.new(0.2, RAIL_H, 0.2), CFrame.new(p + Vector3.new(0, RAIL_H / 2, 0)), STEEL).Parent = deck
		end
		part("SafetyWall", Vector3.new(0.3, RAIL_H, d.Magnitude), CFrame.lookAt((a + b) / 2 + Vector3.new(0, RAIL_H / 2, 0), b + Vector3.new(0, RAIL_H / 2, 0)), STEEL, Enum.Material.Metal, INVISIBLE).Parent = deck
	end
	local e = H - 0.1
	railSide(at(-e, DECK_H, -e), at(e, DECK_H, -e))
	railSide(at(e, DECK_H, -e), at(e, DECK_H, e))
	railSide(at(-e, DECK_H, e), at(-e, DECK_H, -e))
	railSide(at(e, DECK_H, e), at(NOTCH + 0.1, DECK_H, e))     -- north side, east of the gap
	railSide(at(-NOTCH - 0.1, DECK_H, e), at(-e, DECK_H, e))   -- north side, west of the gap
	-- low yellow guards along both sides of the notch
	for _, sx in { -1, 1 } do
		beam("NotchGuard", at(sx * NOTCH, DECK_H + 1.1, zn), at(sx * NOTCH, DECK_H + 1.1, e), 0.14, YELLOW, deck)
		for _, z in { zn, e } do
			part("NotchPost", Vector3.new(0.14, 1.1, 0.14), CFrame.new(at(sx * NOTCH, DECK_H + 0.55, z)), STEEL).Parent = deck
		end
	end
	-- the lid and gate over the notch: solid for people walking about, switched off for climbers (RadioTowerClient)
	local lid = part("NotchLid", Vector3.new(2 * NOTCH - 0.1, 0.3, H - zn), CFrame.new(at(0, DECK_H - 0.15, (zn + H) / 2)), STEEL, Enum.Material.Metal, INVISIBLE)
	lid.Parent = deck
	local gate = part("NotchGate", Vector3.new(2 * NOTCH, RAIL_H, 0.3), CFrame.new(at(0, DECK_H + RAIL_H / 2, e)), STEEL, Enum.Material.Metal, INVISIBLE)
	gate.Parent = deck
	-- the walk-on footprint of the notch (used by the client to tell climbers from walkers)
	deck:SetAttribute("NotchMin", at(-NOTCH, DECK_H, zn))
	deck:SetAttribute("NotchMax", at(NOTCH, DECK_H, H))
	return deck
end

local function buildLadder()
	local ladder = Instance.new("Model")
	ladder.Name = "Ladder"
	ladder.Parent = folder
	local zb = ladderZ(0)
	local g = math.min(ground(C.X + LADDER_X, C.Z + zb), ground(C.X + LADDER_X, C.Z + zb + 1.5))
	local hb = g - C.Y - 0.3 -- bottom of the rails, just into the ground
	local function line(h) return at(LADDER_X, h, ladderZ(h)) end
	local rails = Instance.new("Folder") rails.Name = "Rails" rails.Parent = ladder
	local rungs = Instance.new("Folder") rungs.Name = "Rungs" rungs.Parent = ladder
	for _, s in { -1, 1 } do
		local off = Vector3.new(s * RAIL_GAP, 0, 0)
		beam("Rail", line(hb) + off, line(DECK_H) + off, 0.24, STEEL, rails)
		-- the hand-holds above the platform don't collide, so climbers can step through onto it
		beam("GrabRail", line(DECK_H) + off, line(DECK_H + 3.4) + off, 0.24, STEEL, rails, { CanCollide = false, CanQuery = false, CanTouch = false })
	end
	-- the rungs (climbable), one stud apart, the top one level with the platform
	local i = 0
	for h = hb + 1.0, DECK_H - 0.05, 1.0 do
		i += 1
		local rung = part("Rung", Vector3.new(RAIL_GAP * 2, 0.22, 0.22), CFrame.new(line(h)), STEEL)
		rung.Shape = Enum.PartType.Cylinder -- a cylinder runs along X, the same way as the rung
		rung:SetAttribute("Index", i)
		rung:SetAttribute("Height", h - hb)
		rung:SetAttribute("Home", rung.CFrame)
		rung.Parent = rungs
	end
	-- stand-offs from the rails back to the face every 10 studs
	for h = hb + 4, DECK_H - 2, 10 do
		for _, s in { -1, 1 } do
			beam("StandOff", line(h) + Vector3.new(s * RAIL_GAP, 0, 0), at(LADDER_X + s * RAIL_GAP, h, hw(h) - 0.1), 0.14, STEEL, ladder)
		end
	end
	-- the climbing line, for the scripted climb down: rung centres at the bottom and the top
	ladder:SetAttribute("RungBottom", line(hb + 1.0))
	ladder:SetAttribute("RungTop", line(DECK_H - 0.05))
	ladder:SetAttribute("BottomY", C.Y + hb)
	ladder:SetAttribute("TopY", C.Y + DECK_H)
	-- where the repair items are left and the repair prompt lives (the climbing side, on the ground)
	local bz = zb + 1.7
	local base = part("LadderBase", Vector3.new(2, 0.2, 2), CFrame.new(at(LADDER_X, ground(C.X + LADDER_X, C.Z + bz) - C.Y + 0.1, bz)), STEEL, Enum.Material.Metal,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	base.Parent = ladder
	-- the top of the ladder, on the platform over the notch: the "Climb down" prompt lives here
	local zn = hw(DECK_H) + 0.1
	local top = part("LadderTop", Vector3.new(1, 1, 1), CFrame.new(at(LADDER_X, DECK_H + 1.2, (zn + DECK_HALF) / 2)), STEEL, Enum.Material.Metal,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	top.Parent = ladder
	-- a warning plate beside the ladder at head height, facing out
	local sh = hb + 5.5
	local signAt = at(LADDER_X + 2.1, sh, hw(sh) + 0.06)
	local sign = part("WarningSign", Vector3.new(1.6, 1.2, 0.08), CFrame.lookAt(signAt, signAt + Vector3.new(0, 0, 1)), Color3.fromRGB(232, 198, 40), Enum.Material.SmoothPlastic)
	local sg = Instance.new("SurfaceGui") sg.Face = Enum.NormalId.Front sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud sg.PixelsPerStud = 80 sg.Parent = sign
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.Oswald t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(20, 18, 16) t.Text = "DANGER\nCLIMB AT\nYOUR OWN RISK" t.Parent = sg
	sign.Parent = ladder
	return ladder
end

local function buildCabinet()
	-- task 19: the transmitter cabinet on the platform, with an empty socket for the spare module
	local tasks = workspace.ForestRescueTasks
	local old = tasks:FindFirstChild("Task19")
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = "Task19"
	local face = CFrame.lookAt(at(CABINET.X, DECK_H + 1.3, CABINET.Z), at(CABINET.X - 5, DECK_H + 1.3, CABINET.Z)) -- front faces west
	local console = part("Console", Vector3.new(2.3, 2.6, 1.1), face, Color3.fromRGB(196, 198, 194), Enum.Material.Metal)
	console.Parent = m
	m.PrimaryPart = console
	part("Plinth", Vector3.new(2.5, 0.25, 1.3), face * CFrame.new(0, -1.42, 0), Color3.fromRGB(70, 72, 74)).Parent = m
	part("Roof", Vector3.new(2.5, 0.12, 1.4), face * CFrame.new(0, 1.36, 0.08), Color3.fromRGB(70, 72, 74)).Parent = m
	-- the front: a vent grille up top, the empty socket in the middle, a dial row below
	part("Vent", Vector3.new(1.6, 0.5, 0.06), face * CFrame.new(0, 0.8, -0.56), Color3.fromRGB(60, 62, 64), Enum.Material.DiamondPlate).Parent = m
	local socket = part("Socket", Vector3.new(1.0, 0.7, 0.08), face * CFrame.new(-0.2, 0.05, -0.53), Color3.fromRGB(18, 18, 20), Enum.Material.SmoothPlastic)
	socket.Parent = m
	-- where a fitted module sits (its face flush with the cabinet front)
	local seat = Instance.new("Attachment") seat.Name = "ModuleSeat" seat.CFrame = CFrame.new(0, 0, -0.12) seat.Parent = socket
	for i, dx in { -0.35, 0.05 } do
		local w = part("LooseWire", Vector3.new(0.05, 0.42, 0.05), face * CFrame.new(-0.2 + dx, -0.25, -0.6) * CFrame.Angles(0, 0, math.rad(i == 1 and 12 or -16)),
			i == 1 and Color3.fromRGB(190, 40, 30) or Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic)
		w.Parent = m
	end
	part("ControlFace", Vector3.new(1.8, 0.5, 0.06), face * CFrame.new(0, -0.75, -0.56), Color3.fromRGB(40, 42, 44), Enum.Material.SmoothPlastic).Parent = m
	for i = 0, 2 do
		local dial = part("Instrument", Vector3.new(0.08, 0.3, 0.3), face * CFrame.new(-0.55 + i * 0.55, -0.75, -0.6) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(230, 226, 210), Enum.Material.SmoothPlastic)
		dial.Shape = Enum.PartType.Cylinder
		dial.Parent = m
	end
	part("StatusLamp", Vector3.new(0.2, 0.2, 0.1), face * CFrame.new(0.85, 0.05, -0.58), Color3.fromRGB(76, 30, 20), Enum.Material.Glass).Parent = m
	-- coax running from the cabinet up into the mast
	beam("Coax", at(CABINET.X, DECK_H + 2.6, CABINET.Z), at(0.15, DECK_H + 7, -1.65), 0.12, Color3.fromRGB(25, 25, 25), m)
	-- a work lamp on the cabinet roof
	local lampAt = face * CFrame.new(0, 1.62, -0.45)
	part("WorkLampArm", Vector3.new(0.1, 0.4, 0.1), lampAt * CFrame.new(0, -0.1, 0), Color3.fromRGB(40, 42, 44)).Parent = m
	local work = part("WorkLamp", Vector3.new(0.5, 0.22, 0.3), lampAt * CFrame.new(0, 0.12, -0.08), Color3.fromRGB(255, 236, 200), Enum.Material.Neon,
		{ CanCollide = false, CanQuery = false, CanTouch = false })
	local wl = Instance.new("SpotLight") wl.Face = Enum.NormalId.Front wl.Angle = 110 wl.Range = 12 wl.Brightness = 1.4 wl.Color = Color3.fromRGB(255, 232, 196) wl.Parent = work
	work.CFrame = work.CFrame * CFrame.Angles(math.rad(-35), 0, 0)
	work.Parent = m
	-- prompt + map marker, copied from an existing station so it behaves the same
	local src = tasks.Task08.Console
	local pr = src.RescuePrompt:Clone()
	pr.ActionText = "Repair transmitter"
	pr.ObjectText = "Fix the radio tower transmitter"
	pr.MaxActivationDistance = 7
	pr.Parent = console
	local marker = src:FindFirstChild("TaskMarker")
	if marker then
		local mk = marker:Clone()
		for _, d in mk:GetDescendants() do if d:IsA("TextLabel") then d.Text = "19  /  FIX THE RADIO TOWER TRANSMITTER" end end
		mk.Parent = console
	end
	for k, v in {
		TaskId = 19, Title = "Fix the radio tower transmitter", Site = "RADIOTOWER", Game = "components", Rounds = 1, Kind = "repair",
		Action = "Repair transmitter", Instruction = "Fit the new parts into the transmitter board",
		Guide = "Find the spare transmitter module somewhere around camp, carry it up the radio tower and fit it into the empty socket. Then wire up the board.",
		Dependencies = "", Sabotageable = false, Done = false, Step = 0, List = "Van", NeedsPart = true, Locked = true,
	} do m:SetAttribute(k, v) end
	m.Parent = tasks
	return m
end

local function buildExtras()
	-- red aviation light on top of the mast, the kill spot on the platform
	local top = folder.Lattice.Position.Y + folder.Lattice.Size.Y / 2
	local beacon = part("AviationLight", Vector3.new(0.6, 0.6, 0.6), CFrame.new(C.X, top + 0.2, C.Z + 0.35), Color3.fromRGB(255, 40, 30), Enum.Material.Neon,
		{ Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false, CanTouch = false })
	local light = Instance.new("PointLight") light.Name = "Glow" light.Color = Color3.fromRGB(255, 50, 40) light.Range = 18 light.Brightness = 2 light.Parent = beacon
	beacon.Parent = folder
	local zone = part("TowerPushZone", Vector3.new(1, 1, 1), CFrame.new(at(0, DECK_H + 1, 0)), STEEL, Enum.Material.Metal,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	zone:SetAttribute("Kind", "Tower")
	zone:SetAttribute("Radius", 7.2)
	zone:SetAttribute("ZoneId", "RadioTower")
	zone:SetAttribute("PushText", "Off the tower")
	zone:SetAttribute("DeckHalf", DECK_HALF)
	zone:SetAttribute("DeckY", C.Y + DECK_H)
	zone:SetAttribute("Centre", C)
	zone.Parent = folder
	game:GetService("CollectionService"):AddTag(zone, "KillSpot")
end

-- spots near the other task stations where the spare module, the toolbox and the ladder rungs can turn up.
-- They sit 10-13 studs from every station console, so an item's "Pick up" prompt never competes with a station's.
local function buildItemSpots()
	local old = folder:FindFirstChild("ItemSpots")
	if old then old:Destroy() end
	local spots = Instance.new("Folder")
	spots.Name = "ItemSpots"
	spots.Parent = folder
	local consoles = {}
	for _, m in workspace.ForestRescueTasks:GetChildren() do if m.PrimaryPart then table.insert(consoles, m.PrimaryPart.Position) end end
	local ex = OverlapParams.new()
	ex.FilterType = Enum.RaycastFilterType.Exclude
	ex.FilterDescendantsInstances = { workspace.Terrain }
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Exclude
	down.FilterDescendantsInstances = { workspace.ForestRescueTasks }
	down.RespectCanCollide = true
	local n = 0
	for _, m in workspace.ForestRescueTasks:GetChildren() do
		local pp = m.PrimaryPart
		-- not at the radio tower itself, the graveyard task, or anywhere high up
		if pp and m.Name ~= "Task19" and not m:GetAttribute("External") and pp.Position.Y < 30 then
			local placed = false
			for i = 0, 15 do
				if placed then break end
				local a = math.rad(i * 67.5) -- wanders round the station
				local rad = 11 + (i % 3)
				local o = Vector3.new(math.cos(a) * rad, 0, math.sin(a) * rad)
				local from = pp.Position + o + Vector3.new(0, 4, 0)
				local hit = workspace:Raycast(from, Vector3.new(0, -14, 0), down)
				if hit and hit.Normal.Y > 0.8 and hit.Instance == workspace.Terrain or (hit and hit.Normal.Y > 0.8 and hit.Instance:IsA("BasePart") and hit.Instance.Size.Y < 3) then
					local clear = true
					for _, cpos in consoles do if (cpos - hit.Position).Magnitude < 10 then clear = false break end end
					for _, s in spots:GetChildren() do if (s.Position - hit.Position).Magnitude < 6 then clear = false break end end
					if clear then
						local room = workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 1.6, 0)), Vector3.new(1.6, 2.8, 1.6), ex)
						for _, q in room do if q.CanCollide and q.Transparency < 1 then clear = false break end end
					end
					if clear then
						n += 1
						local spot = Instance.new("Part")
						spot.Name = "Spot" .. n
						spot.Size = Vector3.new(1, 0.2, 1)
						spot.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.1, 0))
						spot.Anchored = true spot.CanCollide = false spot.CanQuery = false spot.CanTouch = false spot.Transparency = 1
						spot:SetAttribute("Site", m:GetAttribute("Site"))
						spot.Parent = spots
						placed = true
					end
				end
			end
		end
	end
	return n
end
B.BuildItemSpots = function()
	folder = workspace:WaitForChild("RadioTower")
	return buildItemSpots()
end

function B.Build()
	local old = workspace:FindFirstChild("RadioTower")
	if old then old:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "RadioTower"
	folder.Parent = workspace
	C = Vector3.new(MESH_AT.X + AXIS_OFFSET.X, BASE_Y, MESH_AT.Z + AXIS_OFFSET.Z)
	folder:SetAttribute("Centre", C)
	buildTower()
	buildDeck()
	buildLadder()
	buildCabinet()
	buildExtras()
	local spots = buildItemSpots()
	return { centre = C, spots = spots, rungs = #folder.Ladder.Rungs:GetChildren() }
end

return B
