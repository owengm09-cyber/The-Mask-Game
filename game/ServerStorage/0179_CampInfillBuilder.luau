-- Fills the bare camp clearing (cabins + fire circle) with grass terrain and the forest's own installed vegetation.
-- Keeps clear of the stone paths, cabins, the fire circle / tents / seats, lanterns + signs, vents and task stations.
--   require(game.ServerStorage.CampInfillBuilder).Build()   -- (re)build; restores the original terrain first
--   require(game.ServerStorage.CampInfillBuilder).Remove()  -- undo everything (terrain + props + map icons)
-- Everything it places lives in workspace.Forest.CampInfill.
--   require(game.ServerStorage.CampInfillBuilder).Thicken()       -- a second, denser layer on top (CampUnderstory)
--   require(game.ServerStorage.CampInfillBuilder).RemoveThicken() -- undo just that layer (terrain + props + map icons)
local B = {}
local T = workspace.Terrain
local R = { x0 = 36, x1 = 236, z0 = -152, z1 = 100, y0 = -20, y1 = 40 }
local FIRE = Vector2.new(160, 0)
local G = 2 -- distance-field resolution (studs)
local NX, NZ = (R.x1 - R.x0) / G, (R.z1 - R.z0) / G
-- clearances (studs)
local FIRE_DIRT = 13      -- worn dirt just around the fire circle (the log seats end ~12 out)
local FIRE_PROPS = 13.6   -- plants start right outside the log seats
local PATH_DIRT = 1.2     -- thin worn edge either side of the stone paths
local PATH_PROPS = 1.2    -- gap between a plant's edge and the nearest path stone
local STRUCT_DIRT = -3    -- grass grows right up to (and under) cabins and tents; terrain cells are 4 studs, so any dirt edge reads as a wide band
local STRUCT_PROPS = 0.5  -- plants can sit right up against walls (the overlap check stops them going through)
local DENSITY = 0.6       -- chance a candidate spot gets a plant (lower = sparser)
local SPACING = 1.2       -- multiplies every plant type's minimum spacing

local rng
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 140, z), Vector3.new(0, -280, 0), rp)
	if hit then return hit.Position.Y, hit.Normal, hit.Material end
end

---------------------------------------------------------------- distance fields
local function idx(i, j) return j * NX + i + 1 end
local function cellOf(x, z) return math.floor((x - R.x0) / G), math.floor((z - R.z0) / G) end
local function sample(f, x, z)
	local i, j = cellOf(x, z)
	if i < 0 or j < 0 or i >= NX or j >= NZ then return 0 end
	return f[idx(i, j)]
end
local function stampOBB(f, cf, size, reach)
	local hx, hz = size.X / 2, size.Z / 2
	local ci, cj = cellOf(cf.X, cf.Z)
	local n = math.ceil((math.sqrt(hx * hx + hz * hz) + reach) / G)
	local flatCF = CFrame.new(cf.Position) * CFrame.Angles(0, select(2, cf:ToEulerAnglesYXZ()), 0)
	for j = math.max(0, cj - n), math.min(NZ - 1, cj + n) do
		for i = math.max(0, ci - n), math.min(NX - 1, ci + n) do
			local l = flatCF:PointToObjectSpace(Vector3.new(R.x0 + (i + 0.5) * G, cf.Y, R.z0 + (j + 0.5) * G))
			local dx, dz = math.max(math.abs(l.X) - hx, 0), math.max(math.abs(l.Z) - hz, 0)
			local d = math.sqrt(dx * dx + dz * dz)
			local k = idx(i, j)
			if d < f[k] then f[k] = d end
		end
	end
end
local function stampCircle(f, x0, z0, r, reach)
	local ci, cj = cellOf(x0, z0)
	local n = math.ceil((r + reach) / G)
	for j = math.max(0, cj - n), math.min(NZ - 1, cj + n) do
		for i = math.max(0, ci - n), math.min(NX - 1, ci + n) do
			local x, z = R.x0 + (i + 0.5) * G, R.z0 + (j + 0.5) * G
			local d = math.max(0, math.sqrt((x - x0) ^ 2 + (z - z0) ^ 2) - r)
			local k = idx(i, j)
			if d < f[k] then f[k] = d end
		end
	end
end
local function horizontalSize(p)
	-- world-space footprint of a (possibly tilted) part
	local cf, s = p.CFrame, p.Size
	local ex = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
	local ez = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
	return ex, ez
end
local function buildFields()
	local path = table.create(NX * NZ, 99)
	local struct = table.create(NX * NZ, 99)
	-- stone paths (thousands of individual stones)
	for _, p in workspace.SummerCampCabins.GroundPaths:GetDescendants() do
		if p:IsA("BasePart") then
			local ex, ez = horizontalSize(p)
			stampCircle(path, p.Position.X, p.Position.Z, math.max(ex, ez) * 0.5, 7)
		end
	end
	-- cabins and everything else people walk up to
	local function model(m) local cf, s = m:GetBoundingBox() stampOBB(struct, cf, s, 12) end
	local function part(p) local ex, ez = horizontalSize(p) stampOBB(struct, CFrame.new(p.Position), Vector3.new(math.max(ex, 1), 1, math.max(ez, 1)), 12) end
	-- cabins: only the parts near the ground (walls, porch, steps) count, so plants can tuck in under the eaves
	for _, c in workspace.SummerCampCabins:GetChildren() do
		if c:IsA("Model") and c.Name ~= "CampCabinsWayfinding" then
			local cf, s = c:GetBoundingBox()
			local floorY = cf.Y - s.Y / 2
			for _, p in c:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local _, ey = p.CFrame, math.abs(p.CFrame.RightVector.Y) * p.Size.X + math.abs(p.CFrame.UpVector.Y) * p.Size.Y + math.abs(p.CFrame.LookVector.Y) * p.Size.Z
					if p.Position.Y - ey / 2 < floorY + 4 then part(p) end
				end
			end
		end
	end
	for _, p in workspace.SummerCampCabins.CampCabinsWayfinding:GetDescendants() do if p:IsA("BasePart") then part(p) end end
	-- every piece of the fire circle / tents / seats / flare display, part by part
	for _, c in workspace.EmergencyCampsite:GetDescendants() do if c:IsA("BasePart") then part(c) end end
	for _, name in { "ForestRescueTasks", "Vents", "SpawnPoints", "ForestExpedition" } do
		local f = workspace:FindFirstChild(name)
		if f then for _, c in f:GetChildren() do if c:IsA("Model") then model(c) elseif c:IsA("BasePart") then part(c) end end end
	end
	for _, name in { "RescueSites", "LootChests", "Landmarks" } do
		local f = workspace.Forest:FindFirstChild(name)
		if f then for _, c in f:GetChildren() do if c:IsA("Model") then model(c) elseif c:IsA("BasePart") then part(c) end end end
	end
	return path, struct
end

---------------------------------------------------------------- spatial hash of vegetation (existing + new)
local hash
local function hkey(a, b) return a * 100000 + b end
local function addVeg(x, z, kind)
	local k = hkey(math.floor(x / 8), math.floor(z / 8))
	hash[k] = hash[k] or {}
	table.insert(hash[k], { x = x, z = z, kind = kind })
end
local function near(x, z, dist, kind)
	local n = math.ceil(dist / 8)
	local cx, cz = math.floor(x / 8), math.floor(z / 8)
	for a = cx - n, cx + n do
		for b = cz - n, cz + n do
			local l = hash[hkey(a, b)]
			if l then
				for _, v in l do
					if (kind == nil or v.kind == kind) and (v.x - x) ^ 2 + (v.z - z) ^ 2 < dist * dist then return true end
				end
			end
		end
	end
	return false
end
local function kindOf(name)
	if name:match("Tree") then return "tree" end
	if name:match("GrassClump") then return "grassclump" end
	if name:match("TallGrass") then return "tallgrass" end
	if name:match("Fern") or name == "Ground_1" then return "fern" end
	if name:match("Bush") then return "bush" end
	if name:match("Log") then return "log" end
	if name:match("Mushroom") then return "mushroom" end
	if name:match("^Rock") then return "rock" end
	if name == "Ground_2" then return "ivy" end
	return "other"
end
local function indexExisting()
	hash = {}
	for _, f in workspace.Forest:GetChildren() do
		if f:IsA("Folder") and f.Name ~= "DistantForest" and f.Name ~= "CampInfill" then
			for _, c in f:GetChildren() do
				local pos = c:IsA("Model") and c:GetPivot().Position or (c:IsA("BasePart") and c.Position)
				if pos and pos.X > R.x0 - 20 and pos.X < R.x1 + 20 and pos.Z > R.z0 - 20 and pos.Z < R.z1 + 20 then addVeg(pos.X, pos.Z, kindOf(c.Name)) end
			end
		end
	end
end

---------------------------------------------------------------- templates (the forest's own installed assets)
local KINDS = {
	-- size = target {min,max} of the measured dimension ("h" height or "w" widest footprint)
	grassclump = { names = { "Ground_GrassClump" }, dim = "w", size = { 6.5, 10.5 }, spacing = 7.5, foot = 0.4, sink = 0.15, flat = true },
	tallgrass = { names = { "Ground_TallGrass" }, dim = "h", size = { 2.4, 4.0 }, spacing = 3.4, foot = 0.4, sink = 0.2, flat = true },
	fern = { names = { "Ground_Fern", "Ground_1" }, dim = "h", size = { 1.8, 3.2 }, spacing = 4.5, foot = 0.42, sink = 0.25, flat = true },
	ivy = { names = { "Ground_2" }, dim = "w", size = { 4.5, 8.0 }, spacing = 7, foot = 0.45, sink = 0.05, flat = true },
	bush = { names = { "Bush_1", "Bush_3", "Bush_4", "Bush_5" }, dim = "h", size = { 2.3, 3.6 }, spacing = 6, foot = 0.45, sink = 0.3, flat = true },
	log = { names = { "Ground_SmallLog" }, dim = "w", size = { 4.5, 10 }, spacing = 15, foot = 0.5, sink = 0.35, collide = true },
	mushroom = { names = { "Ground_MushroomCluster", "Ground_Mushrooms" }, dim = "h", size = { 0.6, 1.2 }, spacing = 7, foot = 0.5, sink = 0.1, flat = true },
	rock = { names = { "Rock_" }, dim = "w", size = { 1.4, 3.6 }, spacing = 9, foot = 0.5, sink = 0.35, collide = true },
	tree = { names = { "Tree_13", "Tree_5", "Tree_12", "Tree_11", "CampTree_" }, dim = "h", size = { 15, 25 }, spacing = 15, foot = 0.2, sink = 0.6, collide = true },
}
local templates = {}
local function collectTemplates()
	templates = {}
	local sources = { workspace.Forest.Detail, workspace.Forest.Rocks, workspace.Forest.CampsiteVegetation, workspace.Forest.CampWoodlandAccents, workspace.Forest.Trees }
	for kind, k in KINDS do
		local list = {}
		for _, name in k.names do
			local found = 0
			for _, src in sources do
				for _, c in src:GetChildren() do
					if found < 3 and (c.Name == name or (name:sub(-1) == "_" and c.Name:sub(1, #name) == name)) then
						local s = c:IsA("Model") and select(2, c:GetBoundingBox()) or c.Size
						if kind ~= "tree" or s.Y < 30 then table.insert(list, c) found += 1 end
					end
				end
			end
		end
		templates[kind] = list
	end
end

---------------------------------------------------------------- placing one asset
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
local function lowestY(inst)
	local low, lowAny = math.huge, math.huge
	for _, p in (inst:IsA("BasePart") and { inst } or inst:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf, s = p.CFrame, p.Size / 2
			local y = cf.Y - (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
			lowAny = math.min(lowAny, y)
			if p.Transparency < 1 then low = math.min(low, y) end
		end
	end
	return low < math.huge and low or lowAny
end
local function dims(inst)
	if inst:IsA("Model") then local _, s = inst:GetBoundingBox() return s end
	return inst.Size
end
local function scaleBy(inst, f)
	if inst:IsA("Model") then inst:ScaleTo(inst:GetScale() * f) else inst.Size *= f end
end
local IGNORE_PEBBLES = false -- the understory layer lets low plants grow over the loose pebbles beside a trail
local FLAT_NO_QUERY = false -- understory: low plants never block a prompt's line of sight or a raycast
local TREE_STRUCT_PAD = 5 -- how far (beyond its footprint) a tree keeps from cabins, tents and props
local function blocked(x, z, gy, rad, h)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(x, gy + h / 2 - 0.3, z), Vector3.new(rad * 2, h, rad * 2), overlap)
	for _, p in parts do
		if not (IGNORE_PEBBLES and p.Name == "RoughPebble") and (p.Transparency < 1 or p.CanCollide) then return true end
	end
	return false
end
local folders = {}
local function try(kind, x, z, f, sizeMul, pathPad)
	local k = KINDS[kind]
	local list = templates[kind]
	if not list or #list == 0 then return false end
	local src = list[rng:NextInteger(1, #list)]
	-- size first, so the clearance checks use the real footprint
	local s0 = dims(src)
	local measure = k.dim == "h" and s0.Y or math.max(s0.X, s0.Z)
	local scale = rng:NextNumber(k.size[1], k.size[2]) * (sizeMul or 1) / math.max(measure, 0.05)
	local w = math.max(s0.X, s0.Z) * scale
	local rad = w * k.foot
	local why = B.Rejects
	if sample(f.path, x, z) < rad + (pathPad or PATH_PROPS) then why.path = (why.path or 0) + 1 return false end
	-- the field is a 2-stud grid, so it's only a rough filter here; the exact overlap test below decides
	if sample(f.struct, x, z) < rad * 0.5 + (kind == "tree" and TREE_STRUCT_PAD or 0) then why.struct = (why.struct or 0) + 1 return false end
	local gy, normal, mat = ground(x, z)
	if not gy or mat == Enum.Material.Water or normal.Y < (k.collide and 0.88 or 0.75) then why.ground = (why.ground or 0) + 1 return false end
	-- exact test with the plant's full width (leaf tips included), so nothing reaches over a porch or through a wall
	local fullHalf = kind == "tree" and math.max(rad, 1.5) or w * 0.5
	if blocked(x, z, gy, fullHalf + STRUCT_PROPS, kind == "tree" and 12 or math.max(2, s0.Y * scale)) then why.blocked = (why.blocked or 0) + 1 return false end
	local inst = src:Clone()
	scaleBy(inst, scale)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local tilt = kind == "log" and CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.06, 0.06))
		or kind == "rock" and CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
		or CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.04, 0.04))
	local cf = CFrame.new(x, gy + 60, z) * CFrame.Angles(0, yaw, 0) * tilt
	if inst:IsA("Model") then inst:PivotTo(cf) else inst.CFrame = cf end
	-- sit it on the lowest ground under its footprint, so nothing floats on a slope
	local low = math.huge
	local r = math.max(0.4, rad * 0.6)
	for _, o in { { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } } do
		local y = ground(x + o[1], z + o[2])
		if y then low = math.min(low, y) end
	end
	local dy = (low - k.sink * (kind == "rock" and s0.Y * scale or 1)) - lowestY(inst)
	if inst:IsA("Model") then inst:PivotTo(inst:GetPivot() + Vector3.new(0, dy, 0)) else inst.CFrame += Vector3.new(0, dy, 0) end
	for _, p in (inst:IsA("BasePart") and { inst } or inst:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanTouch = false
			if k.flat then
				p.CanCollide = false p.CastShadow = kind == "bush" or kind == "fern"
				if FLAT_NO_QUERY then p.CanQuery = false end
			end
		end
	end
	inst.Name = kind .. "_" .. src.Name
	inst.Parent = folders[kind]
	addVeg(x, z, kind)
	return true, inst
end

---------------------------------------------------------------- terrain: grass over the bare dirt, worn dirt kept where people walk
local function paintTerrain(f)
	local reg = Region3.new(Vector3.new(R.x0, R.y0, R.z0), Vector3.new(R.x1, R.y1, R.z1))
	local mats, occ = T:ReadVoxels(reg, 4)
	local changed = 0
	for a = 1, mats.Size.X do
		for c = 1, mats.Size.Z do
			local x, z = R.x0 + (a - 0.5) * 4, R.z0 + (c - 0.5) * 4
			local wobble = math.noise(x / 23, z / 23, 3.1) * 5
			local fireD = (Vector2.new(x, z) - FIRE).Magnitude
			if sample(f.struct, x, z) < 4.5 then
				-- grass that was already here before the infill also grows blades through porches
				for b = 1, mats.Size.Y do
					if mats[a][b][c] == Enum.Material.Grass then mats[a][b][c] = Enum.Material.LeafyGrass changed += 1 end
				end
			end
			if fireD > FIRE_DIRT and sample(f.struct, x, z) < 7 and sample(f.path, x, z) > 0.9 then
				-- a cabin hemmed in by paths (Pine) would otherwise sit in a ring of bare dirt; blade-free Leafy Grass
				-- right up to the stones keeps it green without anything poking through the path
				for b = 1, mats.Size.Y do
					local m = mats[a][b][c]
					if m == Enum.Material.Ground or m == Enum.Material.Mud then mats[a][b][c] = Enum.Material.LeafyGrass changed += 1 end
				end
			end
			if fireD > FIRE_DIRT + wobble * 0.5 and sample(f.path, x, z) > PATH_DIRT + wobble * 0.3 and sample(f.struct, x, z) > STRUCT_DIRT + wobble * 0.3 then
				-- the Grass material grows animated blades that poke through porch floors and tent canvas,
				-- so anything under or close to a building gets blade-free Leafy Grass
				local leafy = sample(f.struct, x, z) < 4.5 or math.noise(x / 37, z / 37, 7.7) > 0.12
				for b = 1, mats.Size.Y do
					local m = mats[a][b][c]
					if m == Enum.Material.Ground or m == Enum.Material.Mud then
						mats[a][b][c] = leafy and Enum.Material.LeafyGrass or Enum.Material.Grass
						changed += 1
					end
				end
			end
		end
	end
	T:WriteVoxels(reg, 4, mats, occ)
	return changed
end

---------------------------------------------------------------- public
local function backupFolder()
	local bk = game.ServerStorage:FindFirstChild("CampInfillBackup")
	if not bk then bk = Instance.new("Folder") bk.Name = "CampInfillBackup" bk.Parent = game.ServerStorage end
	return bk
end
local function terrainRegion()
	return Region3int16.new(Vector3int16.new(R.x0 / 4, R.y0 / 4, R.z0 / 4), Vector3int16.new(R.x1 / 4 - 1, R.y1 / 4 - 1, R.z1 / 4 - 1))
end
function B.Remove()
	local bk = game.ServerStorage:FindFirstChild("CampInfillBackup")
	if bk and bk:FindFirstChild("TerrainBefore") then T:PasteRegion(bk.TerrainBefore, Vector3int16.new(R.x0 / 4, R.y0 / 4, R.z0 / 4), true) end
	local old = workspace.Forest:FindFirstChild("CampInfill")
	if old then old:Destroy() end
	local trees = game.ReplicatedStorage:FindFirstChild("RescueMapData") and game.ReplicatedStorage.RescueMapData:FindFirstChild("Trees")
	if trees then for _, t in trees:GetChildren() do if t.Name:match("^CampInfillTree") then t:Destroy() end end end
end
function B.Build(seed)
	rng = Random.new(seed or 4417)
	local bk = backupFolder()
	if not bk:FindFirstChild("TerrainBefore") then
		local snap = T:CopyRegion(terrainRegion())
		snap.Name = "TerrainBefore" snap.Parent = bk
	end
	B.Remove()
	local root = Instance.new("Folder") root.Name = "CampInfill" root.Parent = workspace.Forest
	folders = {}
	for kind in KINDS do local f = Instance.new("Folder") f.Name = kind f.Parent = root folders[kind] = f end
	-- ignore other plants (spacing handles those), but never ignore chests, rescue sites or landmarks inside Forest
	local ignore = { T, workspace:FindFirstChild("Atmospherics"), workspace:FindFirstChild("MapBarrier"), workspace.CurrentCamera }
	for _, sub in workspace.Forest:GetChildren() do
		if sub.Name ~= "LootChests" and sub.Name ~= "RescueSites" and sub.Name ~= "Landmarks" then table.insert(ignore, sub) end
	end
	overlap.FilterDescendantsInstances = ignore
	local f = {}
	f.path, f.struct = buildFields()
	task.wait()
	local painted = paintTerrain(f)
	task.wait()
	indexExisting()
	collectTemplates()
	local counts = {}
	B.Rejects = {}
	local function add(kind) counts[kind] = (counts[kind] or 0) + 1 end
	-- 1) a handful of small/medium trees in the widest gaps
	local tries = 0
	for _ = 1, 900 do
		local x, z = rng:NextNumber(R.x0 + 4, R.x1 - 4), rng:NextNumber(R.z0 + 4, R.z1 - 4)
		if (Vector2.new(x, z) - FIRE).Magnitude > 34 and sample(f.path, x, z) > 7 and sample(f.struct, x, z) > 9 and not near(x, z, 14, "tree") then
			if try("tree", x, z, f) then add("tree") end
		end
		tries += 1
		if (counts.tree or 0) >= 22 then break end
	end
	task.wait()
	-- 2) ground cover on a jittered grid; what grows where depends on how close it is to cabins and paths
	local cands = {}
	for x = R.x0 + 1, R.x1 - 1, 2.8 do
		for z = R.z0 + 1, R.z1 - 1, 2.8 do
			table.insert(cands, { x + rng:NextNumber(-1, 1), z + rng:NextNumber(-1, 1) })
		end
	end
	for i = #cands, 2, -1 do local j = rng:NextInteger(1, i) cands[i], cands[j] = cands[j], cands[i] end
	for n, c in cands do
		local x, z = c[1], c[2]
		local fireD = (Vector2.new(x, z) - FIRE).Magnitude
		local pd, sd = sample(f.path, x, z), sample(f.struct, x, z)
		if fireD > FIRE_PROPS and pd > PATH_PROPS + 0.5 and sd > STRUCT_PROPS + 0.5 then
			local w
			if fireD < 26 then
				w = { tallgrass = 2.2, fern = 1.4, grassclump = 0.8, mushroom = 0.5, ivy = 0.5 } -- a loose ring just outside the log seats
			elseif sd < 9 then
				w = { fern = 3, bush = 2.4, tallgrass = 2, ivy = 1.2, grassclump = 1, mushroom = 0.5 } -- along cabin walls
			elseif pd < 6 then
				w = { tallgrass = 2.4, grassclump = 2, fern = 1, ivy = 1.2, rock = 0.5, mushroom = 0.3 } -- path verges
			else
				w = { grassclump = 3, tallgrass = 2.6, ivy = 1.6, fern = 1.6, bush = 1.1, log = 0.3, rock = 0.45, mushroom = 0.25 }
			end
			local total = 0 for _, v in w do total += v end
			local roll = rng:NextNumber() * total
			local kind
			for kname, v in w do roll -= v if roll <= 0 then kind = kname break end end
			kind = kind or "tallgrass"
			local k = KINDS[kind]
			local density = fireD < 26 and DENSITY * 0.6 or DENSITY
			if rng:NextNumber() < density and not near(x, z, k.spacing * SPACING, kind) and not near(x, z, kind == "ivy" and 1.0 or 2.4, nil) then
				if try(kind, x, z, f) then add(kind) end
			end
		end
		if n % 400 == 0 then task.wait() end
	end
	-- 3) a planted edge along every cabin wall, and a loose ring just outside the fire's log seats
	local function pickKind(w)
		local total = 0 for _, v in w do total += v end
		local roll = rng:NextNumber() * total
		for kname, v in w do roll -= v if roll <= 0 then return kname end end
		return "tallgrass"
	end
	B.Rejects = {}
	local function plantAt(x, z, w, chance)
		if rng:NextNumber() > chance then return end
		local kind = pickKind(w)
		if near(x, z, KINDS[kind].spacing * 0.6, kind) or near(x, z, 1.6, nil) then B.Rejects.spacing = (B.Rejects.spacing or 0) + 1 return end
		-- along cabin walls and the fire ring a plant's footprint just has to clear the stones (no extra verge gap)
		if try(kind, x, z, f, 0.8, 0.5) then add(kind) B.Rejects.placed = (B.Rejects.placed or 0) + 1 end
	end
	local EDGE = { fern = 3, bush = 2.2, tallgrass = 2.4, grassclump = 0.6, mushroom = 0.6, ivy = 0.8 }
	for _, cab in workspace.SummerCampCabins:GetChildren() do
		if cab:IsA("Model") and cab.Name:match("^Cabin") then
			local cf, s = cab:GetBoundingBox()
			local frame = CFrame.new(cf.Position) * CFrame.Angles(0, select(2, cf:ToEulerAnglesYXZ()), 0)
			local floorY = cf.Y - s.Y / 2
			local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
			for _, p in cab:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 and p.Position.Y < floorY + 6 then
					-- the part's real edges (all 8 corners) in the cabin's frame
					local hs = p.Size / 2
					for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
						local l = frame:PointToObjectSpace((p.CFrame * CFrame.new(hs.X * sx, hs.Y * sy, hs.Z * sz)).Position)
						lo = Vector3.new(math.min(lo.X, l.X), 0, math.min(lo.Z, l.Z)) hi = Vector3.new(math.max(hi.X, l.X), 0, math.max(hi.Z, l.Z))
					end end end
				end
			end
			for _, off in { 2.4, 4.0 } do
				local x0, x1, z0, z1 = lo.X - off, hi.X + off, lo.Z - off, hi.Z + off
				local sides = { { x0, z0, x1, z0 }, { x1, z0, x1, z1 }, { x1, z1, x0, z1 }, { x0, z1, x0, z0 } }
				for _, sd in sides do
					local len = math.sqrt((sd[3] - sd[1]) ^ 2 + (sd[4] - sd[2]) ^ 2)
					for d = 0, len, 3.2 do
						local a = d / math.max(len, 0.01)
						local wp = frame * Vector3.new(sd[1] + (sd[3] - sd[1]) * a + rng:NextNumber(-0.6, 0.6), 0, sd[2] + (sd[4] - sd[2]) * a + rng:NextNumber(-0.6, 0.6))
						plantAt(wp.X, wp.Z, EDGE, off < 3 and 0.7 or 0.5)
					end
				end
			end
		end
	end
	local RING = { tallgrass = 2.2, fern = 1.8, grassclump = 0.6, mushroom = 0.6, bush = 0.5, ivy = 0.4 }
	-- right behind the log seats only low cover (grass, ferns), so the seats stay easy to reach and see
	local RING_LOW = { tallgrass = 2.4, fern = 2, grassclump = 1, ivy = 0.4 }
	for _, r in { 14.2, 16.8, 19.6, 22.5 } do
		local steps = math.floor(2 * math.pi * r / 3.2)
		for i = 1, steps do
			local a = (i + rng:NextNumber(-0.3, 0.3)) / steps * math.pi * 2
			plantAt(FIRE.X + math.cos(a) * r, FIRE.Y + math.sin(a) * r, r < 18 and RING_LOW or RING, r < 18 and 0.6 or 0.55)
		end
	end
	-- the new trees go on the field map too
	local mapTrees = game.ReplicatedStorage:FindFirstChild("RescueMapData") and game.ReplicatedStorage.RescueMapData:FindFirstChild("Trees")
	if mapTrees then
		for i, t in folders.tree:GetChildren() do
			local e = Instance.new("Folder") e.Name = "CampInfillTree" .. i e:SetAttribute("Position", t:GetPivot().Position) e.Parent = mapTrees
		end
	end
	local parts = 0
	for _, d in root:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
	return { painted = painted, counts = counts, parts = parts, edgeRejects = B.Rejects }
end

---------------------------------------------------------------- understory: a second, denser layer
-- Clumps of ferns, bushes and tall grass between the cabins, young trees in the open gaps, and grass terrain
-- right up to the trail. The first layer treated every loose pebble as path, which left the junction
-- between the cabins as one wide patch of bare dirt; here only the flat fieldstones count as the trail.
local function trailField()
	local f = table.create(NX * NZ, 99)
	for _, p in workspace.SummerCampCabins.GroundPaths:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "RoughPebble" then
			local ex, ez = horizontalSize(p)
			stampCircle(f, p.Position.X, p.Position.Z, math.max(ex, ez) * 0.5, 9)
		end
	end
	return f
end
-- places the first layer didn't know about: where the escape van pulls in, and loose props in the workspace
local function stampExtras(struct)
	local spots = workspace:FindFirstChild("EscapeVanSpots")
	if spots then
		for _, s in spots:GetChildren() do
			local cf = s:IsA("BasePart") and s.CFrame or s:GetPivot()
			stampCircle(struct, cf.X, cf.Z, 14, 12)
			-- and the lane it drives in along (EscapeVanService: from 32 studs behind the spot)
			stampOBB(struct, cf * CFrame.new(0, 0, 20), Vector3.new(12, 1, 44), 12)
		end
	end
	for _, c in workspace:GetChildren() do
		if c:IsA("Model") and c ~= workspace.SummerCampCabins and c ~= workspace.EmergencyCampsite and not c:FindFirstChildOfClass("Humanoid") then
			local cf, s = c:GetBoundingBox()
			if s.Magnitude < 90 then stampOBB(struct, cf, s, 12) end
		end
	end
end
-- every plant already in the camp, both layers included
local function indexAll()
	hash = {}
	for _, f in workspace.Forest:GetChildren() do
		if f:IsA("Folder") and f.Name ~= "DistantForest" then
			local items = {}
			for _, c in f:GetChildren() do
				if c:IsA("Folder") then for _, d in c:GetChildren() do table.insert(items, d) end else table.insert(items, c) end
			end
			for _, c in items do
				local pos = c:IsA("Model") and c:GetPivot().Position or (c:IsA("BasePart") and c.Position)
				if pos and pos.X > R.x0 - 20 and pos.X < R.x1 + 20 and pos.Z > R.z0 - 20 and pos.Z < R.z1 + 20 then
					local kind = kindOf(c.Name)
					if kind == "other" then kind = c.Name:match("^(%a+)_") or kind end
					addVeg(pos.X, pos.Z, kind)
				end
			end
		end
	end
end
local function countNear(x, z, dist)
	local n, cx, cz, r = 0, math.floor(x / 8), math.floor(z / 8), math.ceil(dist / 8)
	for a = cx - r, cx + r do
		for b = cz - r, cz + r do
			local l = hash[hkey(a, b)]
			if l then for _, v in l do if (v.x - x) ^ 2 + (v.z - z) ^ 2 < dist * dist then n += 1 end end end
		end
	end
	return n
end
-- grass terrain everywhere except a strip along the trail stones and round the fire
local function paintUnderstory(f)
	local reg = Region3.new(Vector3.new(R.x0, R.y0, R.z0), Vector3.new(R.x1, R.y1, R.z1))
	local mats, occ = T:ReadVoxels(reg, 4)
	local changed = 0
	for a = 1, mats.Size.X do
		for c = 1, mats.Size.Z do
			local x, z = R.x0 + (a - 0.5) * 4, R.z0 + (c - 0.5) * 4
			local td = sample(f.path, x, z)
			local fireD = (Vector2.new(x, z) - FIRE).Magnitude
			if fireD > FIRE_DIRT + 2 and td > 1.6 + math.noise(x / 19, z / 19, 5.3) * 1.2 then
				-- blade-free Leafy Grass beside the trail and under the eaves, so nothing pokes through stones or floors
				local leafy = sample(f.struct, x, z) < 4.5 or td < 4 or math.noise(x / 37, z / 37, 7.7) > 0.12
				for b = 1, mats.Size.Y do
					local m = mats[a][b][c]
					if m == Enum.Material.Ground or m == Enum.Material.Mud then
						mats[a][b][c] = leafy and Enum.Material.LeafyGrass or Enum.Material.Grass
						changed += 1
					end
				end
			end
		end
	end
	T:WriteVoxels(reg, 4, mats, occ)
	return changed
end
function B.RemoveThicken()
	local bk = game.ServerStorage:FindFirstChild("CampInfillBackup")
	if bk and bk:FindFirstChild("TerrainBeforeUnderstory") then T:PasteRegion(bk.TerrainBeforeUnderstory, Vector3int16.new(R.x0 / 4, R.y0 / 4, R.z0 / 4), true) end
	local old = workspace.Forest:FindFirstChild("CampUnderstory")
	if old then old:Destroy() end
	local trees = game.ReplicatedStorage:FindFirstChild("RescueMapData") and game.ReplicatedStorage.RescueMapData:FindFirstChild("Trees")
	if trees then for _, t in trees:GetChildren() do if t.Name:match("^CampUnderstoryTree") then t:Destroy() end end end
end
function B.Thicken(seed)
	rng = Random.new(seed or 9127)
	local bk = backupFolder()
	if not bk:FindFirstChild("TerrainBeforeUnderstory") then
		local snap = T:CopyRegion(terrainRegion())
		snap.Name = "TerrainBeforeUnderstory" snap.Parent = bk
	end
	B.RemoveThicken()
	local root = Instance.new("Folder") root.Name = "CampUnderstory" root.Parent = workspace.Forest
	folders = {}
	for kind in KINDS do local f = Instance.new("Folder") f.Name = kind f.Parent = root folders[kind] = f end
	local ignore = { T, workspace:FindFirstChild("Atmospherics"), workspace:FindFirstChild("MapBarrier"), workspace.CurrentCamera }
	for _, sub in workspace.Forest:GetChildren() do
		if sub.Name ~= "LootChests" and sub.Name ~= "RescueSites" and sub.Name ~= "Landmarks" then table.insert(ignore, sub) end
	end
	overlap.FilterDescendantsInstances = ignore
	local f = {}
	local _
	_, f.struct = buildFields()
	stampExtras(f.struct)
	f.path = trailField()
	task.wait()
	local painted = paintUnderstory(f)
	task.wait()
	indexAll()
	collectTemplates()
	IGNORE_PEBBLES = true
	FLAT_NO_QUERY = true
	B.Rejects = {}
	local counts = {}
	local function add(kind) counts[kind] = (counts[kind] or 0) + 1 end
	-- 1) more trees: young ones near the cabins, full-size ones out in the open gaps
	local trees = 0
	for _ = 1, 2500 do
		local x, z = rng:NextNumber(R.x0 + 4, R.x1 - 4), rng:NextNumber(R.z0 + 4, R.z1 - 4)
		local sd, td = sample(f.struct, x, z), sample(f.path, x, z)
		if (Vector2.new(x, z) - FIRE).Magnitude > 28 and td > 6 and sd > 7 and not near(x, z, 10, "tree") then
			local young = sd < 14 or rng:NextNumber() < 0.4
			if try("tree", x, z, f, young and rng:NextNumber(0.45, 0.62) or 1, 4) then add(young and "youngtree" or "tree") trees += 1 end
		end
		if trees >= 44 then break end
	end
	task.wait()
	-- 2) clumps: plants grow in groups, not evenly spaced
	local CLUMPS = {
		thicket = { r = 4.5, { "bush", 2, 4 }, { "fern", 2, 3 }, { "tallgrass", 2, 4 } },
		fernbed = { r = 3.6, { "fern", 3, 6 }, { "mushroom", 0, 1 }, { "ivy", 0, 1 } },
		meadow = { r = 4.8, { "tallgrass", 4, 7 }, { "grassclump", 1, 2 }, { "fern", 0, 2 } },
	}
	local function pick(w)
		local total = 0 for _, v in w do total += v end
		local roll = rng:NextNumber() * total
		for k, v in w do roll -= v if roll <= 0 then return k end end
		return "meadow"
	end
	local cands = {}
	for x = R.x0 + 2, R.x1 - 2, 5 do
		for z = R.z0 + 2, R.z1 - 2, 5 do table.insert(cands, { x + rng:NextNumber(-2, 2), z + rng:NextNumber(-2, 2) }) end
	end
	for i = #cands, 2, -1 do local j = rng:NextInteger(1, i) cands[i], cands[j] = cands[j], cands[i] end
	local clumps = 0
	for n, c in cands do
		local x, z = c[1], c[2]
		local fireD = (Vector2.new(x, z) - FIRE).Magnitude
		local sd, td = sample(f.struct, x, z), sample(f.path, x, z)
		if fireD > FIRE_PROPS + 1.5 and td > 1.8 and sd > 1 and rng:NextNumber() < 0.85 and countNear(x, z, 4) < 6 then
			local kindOfClump = sd < 8 and pick({ fernbed = 0.5, thicket = 0.35, meadow = 0.15 })
				or td < 5 and pick({ meadow = 0.6, fernbed = 0.4 })
				or fireD < 24 and pick({ meadow = 0.6, fernbed = 0.4 })
				or pick({ thicket = 0.45, meadow = 0.35, fernbed = 0.2 })
			local spec = CLUMPS[kindOfClump]
			local placed = 0
			for _, member in ipairs(spec) do
				for _ = 1, rng:NextInteger(member[2], member[3]) do
					local a, d = rng:NextNumber(0, math.pi * 2), spec.r * math.sqrt(rng:NextNumber())
					local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
					local kind = member[1]
					if not near(px, pz, 1.0, nil) and not near(px, pz, KINDS[kind].spacing * 0.35, kind) then
						local pad = kind == "bush" and 1.0 or 0.4
						-- meadow grass grows a little taller out in the open
						local size = (kind == "tallgrass" and kindOfClump == "meadow" and td > 4) and rng:NextNumber(1.0, 1.35) or rng:NextNumber(0.85, 1.1)
						if try(kind, px, pz, f, size, pad) then add(kind) placed += 1 end
					end
				end
			end
			if placed > 0 then clumps += 1 end
		end
		if n % 150 == 0 then task.wait() end
	end
	IGNORE_PEBBLES = false
	FLAT_NO_QUERY = false
	-- the new trees go on the field map too
	local mapTrees = game.ReplicatedStorage:FindFirstChild("RescueMapData") and game.ReplicatedStorage.RescueMapData:FindFirstChild("Trees")
	if mapTrees then
		for i, t in folders.tree:GetChildren() do
			local e = Instance.new("Folder") e.Name = "CampUnderstoryTree" .. i e:SetAttribute("Position", t:GetPivot().Position) e.Parent = mapTrees
		end
	end
	local parts = 0
	for _, d in root:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
	return { painted = painted, counts = counts, clumps = clumps, parts = parts, rejects = B.Rejects }
end

---------------------------------------------------------------- canopy: real forest trees through the camp
-- The camp's own trees are small (15-25 studs) next to the forest round it (30-70), so the clearing read as
-- open ground. B.Canopy() adds full-size forest trees between the cabins and round the campfire clearing,
-- with ferns and bushes at their feet, and a thick ring of undergrowth just outside the campsite's seats.
-- Everything goes in workspace.Forest.CampCanopy; B.RemoveCanopy() takes it all out again.
local CANOPY_TALL = { "Tree_6", "Tree_7", "Tree_9", "Tree_10", "Tree_11", "Tree_14", "Tree_15", "Tree_4", "Tree_1", "Tree_3", "Tree_8", "Tree_2" }
local CANOPY_MID = { "Tree_5", "Tree_12", "Tree_13", "Tree_11", "Tree_8", "Tree_3" }
local function forestTrees(names)
	local list = {}
	for _, name in names do
		local found = 0
		for _, c in workspace.Forest.Trees:GetChildren() do
			if found < 3 and c.Name == name and c:IsA("Model") then table.insert(list, c) found += 1 end
		end
	end
	return list
end
function B.RemoveCanopy()
	local old = workspace.Forest:FindFirstChild("CampCanopy")
	if old then old:Destroy() end
	local trees = game.ReplicatedStorage:FindFirstChild("RescueMapData") and game.ReplicatedStorage.RescueMapData:FindFirstChild("Trees")
	if trees then for _, t in trees:GetChildren() do if t.Name:match("^CampCanopyTree") then t:Destroy() end end end
end
-- opts.append: add to the trees already there instead of starting over; opts.space: closest two trees may be;
-- opts.pad: how far a tree keeps from cabins, tents and props (beyond its trunk footprint)
function B.Canopy(seed, maxTrees, opts)
	opts = opts or {}
	rng = Random.new(seed or 5531)
	if not opts.append then B.RemoveCanopy() end
	local root = workspace.Forest:FindFirstChild("CampCanopy")
	if not root then root = Instance.new("Folder") root.Name = "CampCanopy" root.Parent = workspace.Forest end
	folders = {}
	for kind in KINDS do
		local f = root:FindFirstChild(kind)
		if not f then f = Instance.new("Folder") f.Name = kind f.Parent = root end
		folders[kind] = f
	end
	TREE_STRUCT_PAD = opts.pad or 5
	local ignore = { T, workspace:FindFirstChild("Atmospherics"), workspace:FindFirstChild("MapBarrier"), workspace.CurrentCamera }
	for _, sub in workspace.Forest:GetChildren() do
		if sub.Name ~= "LootChests" and sub.Name ~= "RescueSites" and sub.Name ~= "Landmarks" then table.insert(ignore, sub) end
	end
	overlap.FilterDescendantsInstances = ignore
	local f = {}
	local _
	_, f.struct = buildFields()
	stampExtras(f.struct)
	f.path = trailField()
	task.wait()
	indexAll()
	collectTemplates()
	local tall, mid = forestTrees(CANOPY_TALL), forestTrees(CANOPY_MID)
	local keepList, keepSize = templates.tree, KINDS.tree.size
	IGNORE_PEBBLES = true
	FLAT_NO_QUERY = true
	B.Rejects = {}
	local counts = {}
	local function add(kind) counts[kind] = (counts[kind] or 0) + 1 end
	local FOOT = { fern = 2.4, bush = 1.6, tallgrass = 1.8, grassclump = 0.4, mushroom = 0.5 }
	local function pickW(w)
		local total = 0 for _, v in w do total += v end
		local roll = rng:NextNumber() * total
		for k, v in w do roll -= v if roll <= 0 then return k end end
		return "fern"
	end
	-- 1) trees: dart-throwing, so they end up roughly evenly spread, never closer than SPACE to another tree
	local SPACE = opts.space or 8.5
	local planted = 0
	maxTrees = maxTrees or 260
	-- opts.doorClear: no tree this close to a cabin door, step or stair (so every way in stays open and visible)
	local doors = {}
	if opts.doorClear then
		for _, cab in workspace.SummerCampCabins:GetChildren() do
			if cab:IsA("Model") and cab.Name:match("^Cabin") then
				for _, p in cab:GetDescendants() do
					local n = p.Name:lower()
					if p:IsA("BasePart") and (n:match("door") or n:match("step") or n:match("stair")) then table.insert(doors, Vector2.new(p.Position.X, p.Position.Z)) end
				end
			end
		end
	end
	local function nearDoor(x, z)
		for _, d in doors do if (d - Vector2.new(x, z)).Magnitude < opts.doorClear then return true end end
		return false
	end
	for n = 1, 9000 do
		local x, z = rng:NextNumber(R.x0 + 3, R.x1 - 3), rng:NextNumber(R.z0 + 3, R.z1 - 3)
		local fireD = (Vector2.new(x, z) - FIRE).Magnitude
		local sd, td = sample(f.struct, x, z), sample(f.path, x, z)
		-- the campsite's four openings between its tents (N, S, E, W) stay clear out to 30 studs
		local ang = math.deg(math.atan2(z - FIRE.Y, x - FIRE.X))
		local inGap = fireD < 30 and math.min(math.abs(ang - 90), math.abs(ang + 90), math.abs(ang), 180 - math.abs(ang)) < 22
		if not inGap and fireD > (opts.fireMin or 23) and td > (opts.trailMin or 4) and sd > (opts.structMin or 4.5) and not near(x, z, SPACE, "tree") and not nearDoor(x, z) then
			-- tall forest trees out in the open; middling ones close to the cabins, the trail and the campsite
			local isTall = fireD > 30 and sd > 9 and td > 6 and rng:NextNumber() < 0.7
			templates.tree = isTall and tall or mid
			KINDS.tree.size = isTall and { 30, 52 } or { 17, 28 }
			local ok, inst = try("tree", x, z, f, 1, isTall and 3 or 2)
			if ok then
				add(isTall and "tallTree" or "midTree")
				planted += 1
				-- something growing at its foot
				for _ = 1, rng:NextInteger(0, 3) do
					local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(2.2, 4.5)
					local kind = pickW(FOOT)
					local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
					if not near(px, pz, 1.0, nil) and try(kind, px, pz, f, rng:NextNumber(0.9, 1.15), kind == "bush" and 1 or 0.4) then add(kind) end
				end
			end
		end
		if planted >= maxTrees then break end
		if n % 300 == 0 then task.wait() end
	end
	templates.tree, KINDS.tree.size = keepList, keepSize
	-- 2) a thick ring of undergrowth just outside the campsite: low right behind the log seats, taller further out
	local LOW = { tallgrass = 2.4, fern = 2.2, grassclump = 0.8 }
	local HIGH = { fern = 2.2, bush = 1.8, tallgrass = 2.4, grassclump = 0.5, mushroom = 0.4 }
	for _, r in { 15.5, 17.3, 19.1, 20.9, 22.7, 24.5, 26.3 } do
		local steps = math.floor(2 * math.pi * r / 2.3)
		for i = 1, steps do
			if rng:NextNumber() < 0.8 then
				local a = (i + rng:NextNumber(-0.35, 0.35)) / steps * math.pi * 2
				local rr = r + rng:NextNumber(-0.6, 0.6)
				local x, z = FIRE.X + math.cos(a) * rr, FIRE.Y + math.sin(a) * rr
				local kind = pickW(r < 18 and LOW or HIGH)
				if sample(f.path, x, z) > 1.6 and not near(x, z, 1.4, nil) then
					if try(kind, x, z, f, rng:NextNumber(0.85, 1.1), kind == "bush" and 1 or 0.5) then add(kind) end
				end
			end
		end
	end
	IGNORE_PEBBLES = false
	FLAT_NO_QUERY = false
	TREE_STRUCT_PAD = 5
	local mapTrees = game.ReplicatedStorage:FindFirstChild("RescueMapData") and game.ReplicatedStorage.RescueMapData:FindFirstChild("Trees")
	if mapTrees then
		for _, t in mapTrees:GetChildren() do if t.Name:match("^CampCanopyTree") then t:Destroy() end end
		for i, t in folders.tree:GetChildren() do
			local e = Instance.new("Folder") e.Name = "CampCanopyTree" .. i e:SetAttribute("Position", t:GetPivot().Position) e.Parent = mapTrees
		end
	end
	local parts = 0
	for _, d in root:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
	return { counts = counts, trees = planted, parts = parts, rejects = B.Rejects }
end

-- distance fields at some points (for checking why a spot stays empty): { {x, z} } -> { {struct, trail} }
function B.DebugFields(points)
	local _, struct = buildFields()
	stampExtras(struct)
	local trail = trailField()
	local out = {}
	for i, p in points do out[i] = { sample(struct, p[1], p[2]), sample(trail, p[1], p[2]) } end
	return out
end

-- Thick undergrowth round the campsite (into CampCanopy): low grass and ferns between the log seats and the
-- tents, then ferns, bushes and tall grass out past the tents. The four openings between the tents only get
-- low grass, so the way in stays easy to see and walk.
function B.CampfireUndergrowth(seed)
	rng = Random.new(seed or 2207)
	local root = workspace.Forest:FindFirstChild("CampCanopy")
	if not root then root = Instance.new("Folder") root.Name = "CampCanopy" root.Parent = workspace.Forest end
	folders = {}
	for kind in KINDS do
		local f = root:FindFirstChild(kind)
		if not f then f = Instance.new("Folder") f.Name = kind f.Parent = root end
		folders[kind] = f
	end
	local ignore = { T, workspace:FindFirstChild("Atmospherics"), workspace:FindFirstChild("MapBarrier"), workspace.CurrentCamera }
	for _, sub in workspace.Forest:GetChildren() do
		if sub.Name ~= "LootChests" and sub.Name ~= "RescueSites" and sub.Name ~= "Landmarks" then table.insert(ignore, sub) end
	end
	overlap.FilterDescendantsInstances = ignore
	local f = {}
	local _
	_, f.struct = buildFields()
	stampExtras(f.struct)
	f.path = trailField()
	indexAll()
	collectTemplates()
	IGNORE_PEBBLES = true
	FLAT_NO_QUERY = true
	B.Rejects = {}
	local counts = {}
	local function pickW(w)
		local total = 0 for _, v in w do total += v end
		local roll = rng:NextNumber() * total
		for k, v in w do roll -= v if roll <= 0 then return k end end
		return "tallgrass"
	end
	local LOW = { tallgrass = 2.6, fern = 2.0, grassclump = 1.0, mushroom = 0.3 }
	local HIGH = { fern = 2.4, bush = 2.0, tallgrass = 2.6, grassclump = 0.4, mushroom = 0.4 }
	for r = 14.5, 36, 1.6 do
		local steps = math.floor(2 * math.pi * r / 1.9)
		for i = 1, steps do
			local a = (i + rng:NextNumber(-0.4, 0.4)) / steps * math.pi * 2
			local rr = r + rng:NextNumber(-0.7, 0.7)
			local x, z = FIRE.X + math.cos(a) * rr, FIRE.Y + math.sin(a) * rr
			local ang = math.deg(a) % 360
			local gapAng = math.min(ang % 90, 90 - ang % 90) -- 0 on a cardinal opening, 45 at a tent
			local opening = gapAng < 20
			local chance = r < 18 and 0.55 or opening and 0.45 or 0.85
			if rng:NextNumber() < chance and sample(f.path, x, z) > 1.4 and not near(x, z, 1.3, nil) then
				local kind = pickW((r < 18 or opening) and LOW or HIGH)
				if try(kind, x, z, f, rng:NextNumber(0.85, 1.15), kind == "bush" and 1 or 0.5) then counts[kind] = (counts[kind] or 0) + 1 end
			end
		end
		task.wait()
	end
	IGNORE_PEBBLES = false
	FLAT_NO_QUERY = false
	return { counts = counts, rejects = B.Rejects }
end
return B
