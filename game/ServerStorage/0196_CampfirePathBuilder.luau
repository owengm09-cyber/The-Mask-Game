-- CampfirePathBuilder: carries the camp's stone paths (west from the cabins, east from the spawn, north from
-- Pine cabin) the last stretch up to the campfire's ring of log seats, so they no longer stop in bare dirt.
--   require(game.ServerStorage.CampfirePathBuilder).Build()   -- (re)lay the new stretches
--   require(game.ServerStorage.CampfirePathBuilder).Remove()  -- take them out again
-- The stones are copies of the paths' own fieldstones and pebbles, laid the same way (same density, turned at
-- random, sitting a quarter stud proud of the ground). They go in SummerCampCabins.GroundPaths.CampfireApproach,
-- so the vegetation builders treat them as path. Plants from the generated layers (CampInfill, CampUnderstory,
-- CampCanopy) that would sit on the new stretch are set aside in ServerStorage.CampfirePathCleared.
local B = {}
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain
local FIRE = Vector3.new(160, 0, 0)
local LOG_RING = 12.6 -- just behind the log seats
local WIDTH = 6.2
local GENERATED = { CampInfill = true, CampUnderstory = true, CampCanopy = true }

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	local h = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), rp)
	return h and h.Position.Y or 0
end

local function paths() return workspace.SummerCampCabins.GroundPaths end

-- distance from point p to segment a-b (all on the ground plane) and how far along it is (0..1)
local function segDist(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude, t
end
local function flat(v) return Vector2.new(v.X, v.Z) end

function B.Remove()
	local old = paths():FindFirstChild("CampfireApproach")
	if old then old:Destroy() end
	local bk = SS:FindFirstChild("CampfirePathCleared")
	if bk then
		for _, p in bk:GetChildren() do
			local from = p:GetAttribute("From")
			local parent = game
			for seg in string.gmatch(from or "", "[^%.]+") do parent = parent and parent:FindFirstChild(seg) end
			if parent then p:SetAttribute("From", nil) p.Parent = parent end
		end
	end
	local tb = SS:FindFirstChild("CampfirePathTerrain")
	if tb then
		local c = tb:GetAttribute("Corner")
		T:PasteRegion(tb, Vector3int16.new(c.X, c.Y, c.Z), true)
	end
end

function B.Build(seed)
	B.Remove()
	local rng = Random.new(seed or 1207)
	-- templates: the existing path's own stones (not the new ones)
	local stones, pebbles = {}, {}
	local ends = {}
	for _, p in paths():GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "RoughPebble" then
				if #pebbles < 60 and rng:NextNumber() < 0.1 then table.insert(pebbles, p) end
			else
				if #stones < 80 and rng:NextNumber() < 0.15 then table.insert(stones, p) end
				table.insert(ends, p)
			end
		end
	end
	-- each stretch: from the nearest existing fieldstone in that direction to just behind the log seats
	local dirs = { W = Vector2.new(-1, 0), E = Vector2.new(1, 0), N = Vector2.new(0, 1) }
	local segments = {}
	for name, d in dirs do
		local target = flat(FIRE) + d * LOG_RING
		local best, bestD
		for _, p in ends do
			local v = flat(p.Position) - flat(FIRE)
			if v.Magnitude > LOG_RING + 3 and v.Unit:Dot(d) > 0.82 then
				local dd = (flat(p.Position) - target).Magnitude
				if not bestD or dd < bestD then best, bestD = p, dd end
			end
		end
		if best then
			-- start a little way back inside the old path so the two blend
			local a = flat(best.Position)
			local back = (a - target).Unit
			table.insert(segments, { name = name, a = a + back * 1.5, b = target })
		end
	end
	local folder = Instance.new("Model") folder.Name = "CampfireApproach" folder.Parent = paths()
	local placed = {}
	local function free(x, z, r)
		for _, q in placed do if (q.p - Vector2.new(x, z)).Magnitude < (q.r + r) * 0.78 then return false end end
		return true
	end
	local function lay(src, x, z, name)
		local s = src:Clone()
		local rot = src.CFrame - src.Position
		local gy = ground(x, z)
		-- the same height as the old stones: their tops a quarter stud above the ground
		s.CFrame = CFrame.new(x, gy + 0.25 - s.Size.Y / 2 + 0.05, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * rot
		s.Name = name
		s.Anchored = true s.CanCollide = false s.CanQuery = false s.CanTouch = false
		s.Parent = folder
		return s
	end
	local counts = {}
	for _, sg in segments do
		local len = (sg.b - sg.a).Magnitude
		local n = 0
		-- each stretch is laid with the stones of the path it carries on (their sizes vary from path to path)
		local local_ = {}
		for _, p in ends do if (flat(p.Position) - sg.a).Magnitude < 14 then table.insert(local_, p) end end
		if #local_ < 6 then local_ = stones end
		-- the stretch, plus a rounded apron where it meets the log seats
		local dir = (sg.b - sg.a).Unit
		local sideV = Vector2.new(-dir.Y, dir.X)
		local function inside(p)
			local d, t = segDist(p, sg.a, sg.b)
			local w = WIDTH / 2 + (t > 0.6 and (t - 0.6) / 0.4 * 1.6 or 0) -- widens towards the fire
			return d < w, d / w
		end
		local tries = math.floor(len * (WIDTH + 2) * 1.6)
		for _ = 1, tries do
			local along = sg.a + (sg.b - sg.a) * rng:NextNumber()
			local p = along + sideV * rng:NextNumber(-1, 1) * (WIDTH / 2 + 1.6)
			local ok, edge = inside(p)
			local wobble = math.noise(p.X / 4, p.Y / 4, 9.1) * 0.3
			if ok and rng:NextNumber() > edge ^ 3 + wobble then
				local src = local_[rng:NextInteger(1, #local_)]
				local r = math.max(src.Size.X, src.Size.Z) / 2
				if free(p.X, p.Y, r) and (p - flat(FIRE)).Magnitude > LOG_RING - 1.2 then
					lay(src, p.X, p.Y, "WeatheredFieldstone")
					table.insert(placed, { p = p, r = r })
					n += 1
				end
			end
		end
		-- pebbles everywhere in the strip and spilling a little past its edges
		for _ = 1, math.floor(len * WIDTH * 0.35) do
			local t = rng:NextNumber()
			local along = sg.a + (sg.b - sg.a) * t
			local side = (sg.b - sg.a).Unit
			side = Vector2.new(-side.Y, side.X)
			local p = along + side * rng:NextNumber(-1, 1) * (WIDTH / 2 + 0.8)
			if free(p.X, p.Y, 0.2) and (p - flat(FIRE)).Magnitude > LOG_RING - 0.8 then
				lay(pebbles[rng:NextInteger(1, #pebbles)], p.X, p.Y, "RoughPebble")
			end
		end
		counts[sg.name] = string.format("%d stones over %.1f studs", n, len)
	end
	-- plants from the generated layers that would stand on the new stretches
	local bk = SS:FindFirstChild("CampfirePathCleared") or Instance.new("Folder")
	bk.Name = "CampfirePathCleared" bk.Parent = SS
	local cleared = 0
	for layer in GENERATED do
		local f = workspace.Forest:FindFirstChild(layer)
		if f then
			for _, kind in f:GetChildren() do
				for _, m in kind:GetChildren() do
					local pos = m:IsA("Model") and m:GetPivot().Position or (m:IsA("BasePart") and m.Position)
					if pos then
						for _, sg in segments do
							if segDist(flat(pos), sg.a, sg.b) < WIDTH / 2 + 1.4 then
								m:SetAttribute("From", kind:GetFullName())
								m.Parent = bk
								cleared += 1
								break
							end
						end
					end
				end
			end
		end
	end
	-- worn earth under the new stretches, like the old paths (no grass blades poking through the stones)
	local x0, x1, z0, z1 = 136, 184, -8, 28
	local corner = Vector3int16.new(x0 / 4, -20 / 4, z0 / 4)
	local reg = Region3.new(Vector3.new(x0, -20, z0), Vector3.new(x1, 20, z1))
	if not SS:FindFirstChild("CampfirePathTerrain") then
		local snap = T:CopyRegion(Region3int16.new(corner, Vector3int16.new(x1 / 4 - 1, 20 / 4 - 1, z1 / 4 - 1)))
		snap.Name = "CampfirePathTerrain" snap:SetAttribute("Corner", Vector3.new(corner.X, corner.Y, corner.Z)) snap.Parent = SS
	end
	local mats, occ = T:ReadVoxels(reg, 4)
	local painted = 0
	for a = 1, mats.Size.X do
		for c = 1, mats.Size.Z do
			local p = Vector2.new(x0 + (a - 0.5) * 4, z0 + (c - 0.5) * 4)
			for _, sg in segments do
				if segDist(p, sg.a, sg.b) < WIDTH / 2 + 0.6 then
					for b = 1, mats.Size.Y do
						local m = mats[a][b][c]
						if m == Enum.Material.Grass or m == Enum.Material.LeafyGrass then mats[a][b][c] = Enum.Material.Ground painted += 1 end
					end
					break
				end
			end
		end
	end
	T:WriteVoxels(reg, 4, mats, occ)
	return { segments = counts, cleared = cleared, painted = painted, parts = #folder:GetChildren() }
end

return B
