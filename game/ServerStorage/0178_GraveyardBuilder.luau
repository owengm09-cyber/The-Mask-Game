-- Builds the camp graveyard (south-east corner of the forest). Run once in Edit mode:
--   require(game.ServerStorage.GraveyardBuilder).Build()
-- Gameplay lives in ServerScriptService.GraveyardService; this only makes the geometry.
local B = {}
local T = workspace.Terrain
local rng = Random.new(1871)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { T }
local function gy(x, z)
	local r = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp)
	return r and r.Position.Y or 8
end
B.GroundY = gy

local STONE = {
	Color3.fromRGB(82, 86, 80), Color3.fromRGB(72, 76, 71), Color3.fromRGB(94, 93, 86),
	Color3.fromRGB(66, 70, 66), Color3.fromRGB(101, 99, 91), Color3.fromRGB(78, 83, 75),
}
local MOSS = { Color3.fromRGB(92, 124, 36), Color3.fromRGB(106, 136, 42), Color3.fromRGB(82, 110, 32), Color3.fromRGB(118, 142, 50) }
local DIRT = Color3.fromRGB(74, 57, 42)
local BONE = Color3.fromRGB(198, 189, 164)
local WOOD = Color3.fromRGB(70, 50, 34)
local IRON = Color3.fromRGB(46, 42, 39)
local function pick(t) return t[rng:NextInteger(1, #t)] end
local function rad(d) return math.rad(d) end

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.new(1, 1, 1)
	p.Material = material or Enum.Material.Slate
	p.Parent = parent
	return p
end
B.Part = part
local function cyl(parent, name, length, diameter, cf, color, material)
	-- cylinder whose axis is the local X of cf
	return part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end
local function union(base, others, name)
	local parent = base.Parent
	local color, material = base.Color, base.Material
	local ok, u = pcall(function() return base:UnionAsync(others) end)
	if not ok then warn("union failed", u) return base end
	u.Name = name or base.Name
	u.UsePartColor = true
	u.Color = color
	u.Material = material
	u.Anchored = true
	u.Parent = parent
	base:Destroy()
	for _, o in others do o:Destroy() end
	return u
end
local function subtract(base, cutters, name)
	local parent = base.Parent
	local color, material = base.Color, base.Material
	local ok, u = pcall(function() return base:SubtractAsync(cutters) end)
	if not ok then warn("subtract failed", u) return base end
	u.Name = name or base.Name
	u.UsePartColor = true
	u.Color = color
	u.Material = material
	u.Anchored = true
	u.Parent = parent
	base:Destroy()
	for _, o in cutters do o:Destroy() end
	return u
end
B.Union, B.Subtract = union, subtract

-- Ground inside the walls: moss everywhere, a dirt path from the north gate. Material-only edits (occupancy untouched).
function B.PaintGround()
	local before = game.ServerStorage:FindFirstChild("GraveyardBackup") and game.ServerStorage.GraveyardBackup:FindFirstChild("TerrainBefore")
	if before then T:PasteRegion(before, Vector3int16.new(50, -6, 50), true) end
	local function paint(minV, maxV, from, to) T:ReplaceMaterial(Region3.new(minV, maxV), 4, from, to) end
	for _, m in { Enum.Material.Grass, Enum.Material.Ground, Enum.Material.Mud } do
		paint(Vector3.new(208, -12, 212), Vector3.new(268, 32, 264), m, Enum.Material.LeafyGrass)
	end
	local function dirt(x0, z0, x1, z1) paint(Vector3.new(x0, -12, z0), Vector3.new(x1, 32, z1), Enum.Material.LeafyGrass, Enum.Material.Ground) end
	dirt(232, 204, 236, 264)
	dirt(220, 228, 232, 232)
	dirt(236, 244, 252, 248)
end

---------------------------------------------------------------- inscriptions
local function inscribe(surfacePart, lines, face)
	local g = Instance.new("SurfaceGui")
	g.Name = "Inscription"
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 1
	g.Brightness = 1
	g.MaxDistance = 60
	g.Parent = surfacePart
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(0.8, 0.48)
	holder.Position = UDim2.fromScale(0.1, 0.24)
	holder.Parent = g
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.02, 0)
	list.Parent = holder
	for i, line in lines do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, i == 2 and 0.24 or 0.15)
		t.Font = Enum.Font.Garamond
		t.TextScaled = true
		t.Text = line
		t.TextColor3 = Color3.fromRGB(46, 48, 44)
		t.TextTransparency = 0.12
		t.LayoutOrder = i
		t.Parent = holder
		local sh = Instance.new("UIStroke")
		sh.Color = Color3.fromRGB(150, 150, 140)
		sh.Transparency = 0.82
		sh.Thickness = 1
		sh.Parent = t
	end
	return g
end

---------------------------------------------------------------- moss helpers
local function mossPatch(parent, cf, w, h)
	-- a thin irregular moss crust stuck to a surface; cf faces outward along -Z
	local p = part(parent, "Moss", Vector3.new(w, h, 0.05), cf, pick(MOSS), Enum.Material.LeafyGrass)
	p.CanCollide = false
	p.CastShadow = false
	return p
end
local function mossSkirt(parent, cf, w, t)
	local p = part(parent, "MossSkirt", Vector3.new(w + 0.35, 0.32, t + 0.35), cf, pick(MOSS), Enum.Material.LeafyGrass)
	p.CanCollide = false
	return p
end

---------------------------------------------------------------- headstones (front faces -Z / north, base cf at ground)
local Styles = {}
function Styles.rounded(m, base, w, h, t, color)
	local bodyH = h - w / 2
	local body = part(m, "Headstone", Vector3.new(w, bodyH, t), base * CFrame.new(0, bodyH / 2, 0), color)
	local cap = cyl(m, "Cap", t, w, base * CFrame.new(0, bodyH, 0) * CFrame.Angles(0, rad(90), 0), color)
	local stone = union(body, { cap }, "Headstone")
	-- moss crust over the curved top
	local outer = cyl(m, "MossTop", t + 0.1, w + 0.12, base * CFrame.new(0, bodyH, 0) * CFrame.Angles(0, rad(90), 0), pick(MOSS), Enum.Material.LeafyGrass)
	local inner = cyl(m, "Cut", t + 0.6, w - 0.55, base * CFrame.new(0, bodyH, 0) * CFrame.Angles(0, rad(90), 0))
	local below = part(m, "Cut", Vector3.new(w + 1, w, t + 1), base * CFrame.new(0, bodyH - w / 2 + 0.25, 0))
	local moss = subtract(outer, { inner, below }, "MossTop")
	moss.CanCollide = false
	return stone, bodyH
end
function Styles.gothic(m, base, w, h, t, color)
	local bodyH = h - w / 2
	local body = part(m, "Headstone", Vector3.new(w, bodyH, t), base * CFrame.new(0, bodyH / 2, 0), color)
	local s = w / math.sqrt(2)
	local gable = part(m, "Gable", Vector3.new(s, s, t), base * CFrame.new(0, bodyH, 0) * CFrame.Angles(0, 0, rad(45)), color)
	local ledge = part(m, "Ledge", Vector3.new(w + 0.16, 0.14, t + 0.12), base * CFrame.new(0, bodyH - 0.07, 0), color)
	local stone = union(body, { gable, ledge }, "Headstone")
	for side = -1, 1, 2 do
		local sl = part(m, "MossTop", Vector3.new(s * 0.75, 0.08, t + 0.08),
			base * CFrame.new(side * w / 4.3, bodyH + w / 4.3, 0) * CFrame.Angles(0, 0, rad(-45 * side)), pick(MOSS), Enum.Material.LeafyGrass)
		sl.CanCollide = false
	end
	return stone, bodyH
end
function Styles.shouldered(m, base, w, h, t, color)
	local bodyH = h - 0.7
	local body = part(m, "Headstone", Vector3.new(w, bodyH, t), base * CFrame.new(0, bodyH / 2, 0), color)
	local crown = cyl(m, "Crown", t, w * 0.62, base * CFrame.new(0, bodyH, 0) * CFrame.Angles(0, rad(90), 0), color)
	local l = cyl(m, "Shoulder", t, 0.62, base * CFrame.new(-w / 2 + 0.31, bodyH, 0) * CFrame.Angles(0, rad(90), 0), color)
	local r = cyl(m, "Shoulder", t, 0.62, base * CFrame.new(w / 2 - 0.31, bodyH, 0) * CFrame.Angles(0, rad(90), 0), color)
	local stone = union(body, { crown, l, r }, "Headstone")
	local mt = part(m, "MossTop", Vector3.new(w * 0.5, 0.07, t + 0.08), base * CFrame.new(0, bodyH + w * 0.3, 0), pick(MOSS), Enum.Material.LeafyGrass)
	mt.CanCollide = false
	return stone, bodyH
end
function Styles.cross(m, base, w, h, t, color, celtic)
	local p1 = part(m, "Headstone", Vector3.new(2.3, 0.75, 1.5), base * CFrame.new(0, 0.375, 0), color)
	local p2 = part(m, "Plinth", Vector3.new(1.7, 0.55, 1.1), base * CFrame.new(0, 1.0, 0), color)
	local post = part(m, "Post", Vector3.new(0.5, h - 1.25, 0.45), base * CFrame.new(0, 1.25 + (h - 1.25) / 2, 0), color)
	local armY = 1.25 + (h - 1.25) * 0.68
	local arm = part(m, "Arm", Vector3.new(1.85, 0.5, 0.45), base * CFrame.new(0, armY, 0), color)
	local extra = { p2, post, arm }
	if celtic then
		local ring = cyl(m, "Ring", 0.36, 1.45, base * CFrame.new(0, armY, 0) * CFrame.Angles(0, rad(90), 0), color)
		local hole = cyl(m, "Hole", 0.8, 1.05, base * CFrame.new(0, armY, 0) * CFrame.Angles(0, rad(90), 0), color)
		ring = subtract(ring, { hole }, "Ring")
		table.insert(extra, ring)
	end
	local stone = union(p1, extra, "Headstone")
	local mt = part(m, "MossTop", Vector3.new(2.25, 0.08, 1.45), base * CFrame.new(0, 0.78, 0), pick(MOSS), Enum.Material.LeafyGrass)
	mt.CanCollide = false
	return stone, 0.75
end
B.Styles = Styles

function B.Headstone(m, base, style, w, h, t, color, lines)
	local stone, faceH = Styles[style == "celtic" and "cross" or style](m, base, w, h, t, color, style == "celtic")
	stone.Name = "Headstone"
	local isCross = style == "cross" or style == "celtic"
	mossSkirt(m, base * CFrame.new(0, 0.05, 0), isCross and 2.3 or w, isCross and 1.5 or t)
	if lines then
		if style == "cross" or style == "celtic" then
			-- plaque on the plinth front
			local plaque = part(m, "Plaque", Vector3.new(1.6, 0.6, 0.05), base * CFrame.new(0, 0.42, -0.77), color)
			plaque.CanCollide = false
			local g = inscribe(plaque, { lines[2] }, Enum.NormalId.Front)
			g.Frame.Size = UDim2.fromScale(0.94, 0.9) g.Frame.Position = UDim2.fromScale(0.03, 0.05)
			for _, c in g.Frame:GetChildren() do if c:IsA("TextLabel") then c.Size = UDim2.fromScale(1, 0.9) end end
		else
			inscribe(stone, lines, Enum.NormalId.Front)
		end
	end
	-- a couple of moss patches low on the face
	if style ~= "cross" and style ~= "celtic" then
		for _ = 1, rng:NextInteger(1, 2) do
			local pw, ph = rng:NextNumber(0.4, w * 0.45), rng:NextNumber(0.25, 0.6)
			mossPatch(m, base * CFrame.new(rng:NextNumber(-w / 2 + pw / 2, w / 2 - pw / 2), rng:NextNumber(0.25, 0.8), -t / 2 - 0.02), pw, ph)
		end
	end
	return stone
end

---------------------------------------------------------------- a diggable grave plot
-- The pit is cut out of the terrain on the 4-stud voxel grid (x centre = 4k+2, z centre = 4m) so the ground
-- around it stays untouched. Inside: earth lining, a coffin with remains, a dirt Fill and a mossy Turf mound.
-- GraveyardService lowers Fill one layer at a time and resets it every round.
local FLOOR = -5.05 -- pit floor (top face) relative to ground
local LID_TOP = -3.87
function B.Grave(parent, index, info)
	local m = Instance.new("Model")
	m.Name = string.format("Grave%02d", index)
	m:SetAttribute("DisplayName", info.title)
	m:SetAttribute("Index", index)
	m.Parent = parent
	local x, zc = info.x, info.zc
	local G = math.min(gy(x, zc), gy(x - 1.8, zc - 3.8), gy(x + 1.8, zc - 3.8), gy(x - 1.8, zc + 3.8), gy(x + 1.8, zc + 3.8), gy(x - 1.8, zc), gy(x + 1.8, zc)) - 0.05
	m:SetAttribute("GroundY", G)
	local C = CFrame.new(x, G, zc)
	-- cut the voxels out (grid aligned, so neighbours keep their shape)
	local y0 = math.floor((G + FLOOR - 0.6) / 4) * 4
	local y1 = math.floor(G / 4) * 4 + 8
	local reg = Region3.new(Vector3.new(x - 2, y0, zc - 4), Vector3.new(x + 2, y1, zc + 4))
	local mats, occ = T:ReadVoxels(reg, 4)
	for a = 1, mats.Size.X do for b = 1, mats.Size.Y do for c = 1, mats.Size.Z do mats[a][b][c] = Enum.Material.Air occ[a][b][c] = 0 end end end
	T:WriteVoxels(reg, 4, mats, occ)
	-- headstone just past the head of the pit
	local zH = zc + 4.6
	local hsY = gy(x, zH + 0.3)
	local yaw = rad(rng:NextNumber(-3, 3))
	local base = CFrame.new(x + rng:NextNumber(-0.2, 0.2), hsY - 0.55, zH) * CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(rad(rng:NextNumber(-4, 5)), 0, rad(rng:NextNumber(-4, 4)))
	local hs = Instance.new("Model") hs.Name = "Marker" hs.Parent = m
	B.Headstone(hs, base, info.style, info.w or 2.5, (info.h or 4) + 0.55, info.t or 0.5, pick(STONE), info.lines)
	-- pit lining (outer faces sit on the voxel boundaries)
	local pit = Instance.new("Model") pit.Name = "Pit" pit.Parent = m
	local earth = Color3.fromRGB(60, 46, 34)
	local wallH = -FLOOR + 0.35
	part(pit, "WallW", Vector3.new(0.3, wallH, 8), C * CFrame.new(-1.85, FLOOR + wallH / 2 - 0.3, 0), earth, Enum.Material.Ground)
	part(pit, "WallE", Vector3.new(0.3, wallH, 8), C * CFrame.new(1.85, FLOOR + wallH / 2 - 0.3, 0), earth, Enum.Material.Ground)
	part(pit, "WallN", Vector3.new(3.4, wallH, 0.3), C * CFrame.new(0, FLOOR + wallH / 2 - 0.3, -3.85), earth, Enum.Material.Ground)
	part(pit, "WallS", Vector3.new(3.4, wallH, 0.3), C * CFrame.new(0, FLOOR + wallH / 2 - 0.3, 3.85), earth, Enum.Material.Ground)
	part(pit, "Floor", Vector3.new(4, 0.3, 8), C * CFrame.new(0, FLOOR - 0.15, 0), earth, Enum.Material.Ground)
	-- coffin on the floor
	local coffin = Instance.new("Model") coffin.Name = "Coffin" coffin.Parent = m
	local wood = Color3.fromRGB(70 + rng:NextInteger(-8, 8), 50 + rng:NextInteger(-6, 6), 34)
	part(coffin, "Bottom", Vector3.new(2.5, 0.15, 5.9), C * CFrame.new(0, FLOOR + 0.075, 0), wood, Enum.Material.WoodPlanks)
	part(coffin, "SideW", Vector3.new(0.15, 0.85, 5.9), C * CFrame.new(-1.175, FLOOR + 0.575, 0), wood, Enum.Material.WoodPlanks)
	part(coffin, "SideE", Vector3.new(0.15, 0.85, 5.9), C * CFrame.new(1.175, FLOOR + 0.575, 0), wood, Enum.Material.WoodPlanks)
	part(coffin, "EndN", Vector3.new(2.2, 0.85, 0.15), C * CFrame.new(0, FLOOR + 0.575, -2.875), wood, Enum.Material.WoodPlanks)
	part(coffin, "EndS", Vector3.new(2.2, 0.85, 0.15), C * CFrame.new(0, FLOOR + 0.575, 2.875), wood, Enum.Material.WoodPlanks)
	part(coffin, "Lid", Vector3.new(2.6, 0.18, 6.0), C * CFrame.new(0, LID_TOP - 0.09, 0), wood:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.WoodPlanks)
	-- remains
	local rem = Instance.new("Model") rem.Name = "Remains" rem.Parent = m
	local fy = FLOOR + 0.15
	local function bone(name, len, d, cf)
		local p = cyl(rem, name, len, d, C * cf, BONE, Enum.Material.Limestone)
		p.CanCollide = false return p
	end
	local skull = part(rem, "Skull", Vector3.new(0.52, 0.52, 0.52), C * CFrame.new(0.05, fy + 0.26, 2.2), BONE, Enum.Material.Limestone, Enum.PartType.Ball)
	skull.CanCollide = false
	local jaw = part(rem, "Jaw", Vector3.new(0.3, 0.1, 0.2), C * CFrame.new(0.05, fy + 0.06, 1.93), BONE, Enum.Material.Limestone) jaw.CanCollide = false
	bone("Spine", 1.7, 0.08, CFrame.new(0, fy + 0.06, 1.05) * CFrame.Angles(0, rad(90), 0))
	for k = 0, 3 do bone("Rib", 0.62, 0.06, CFrame.new(0, fy + 0.08, 1.5 - k * 0.2) * CFrame.Angles(0, 0, rad(k % 2 == 0 and 4 or -4))) end
	local pel = part(rem, "Pelvis", Vector3.new(0.56, 0.1, 0.3), C * CFrame.new(0, fy + 0.05, 0.1), BONE, Enum.Material.Limestone) pel.CanCollide = false
	bone("Femur", 1.25, 0.09, CFrame.new(-0.17, fy + 0.05, -0.65) * CFrame.Angles(0, rad(86), 0))
	bone("Femur", 1.25, 0.09, CFrame.new(0.19, fy + 0.05, -0.67) * CFrame.Angles(0, rad(95), 0))
	bone("Shin", 1.15, 0.08, CFrame.new(-0.2, fy + 0.05, -1.85) * CFrame.Angles(0, rad(88), 0))
	bone("Shin", 1.15, 0.08, CFrame.new(0.24, fy + 0.05, -1.9) * CFrame.Angles(0, rad(97), 0))
	bone("Arm", 1.1, 0.07, CFrame.new(-0.45, fy + 0.05, 0.95) * CFrame.Angles(0, rad(80), 0))
	bone("Arm", 1.1, 0.07, CFrame.new(0.45, fy + 0.05, 0.9) * CFrame.Angles(0, rad(100), 0))
	-- dirt fill up to ground, mossy mound on top
	local fill = part(m, "Fill", Vector3.new(3.4, -LID_TOP, 7.4), C * CFrame.new(0, LID_TOP / 2, 0), DIRT, Enum.Material.Ground)
	local moss = pick(MOSS)
	local turfBlock = part(m, "Turf", Vector3.new(4.25, 0.5, 8.25), C * CFrame.new(0, -0.17, 0), moss, Enum.Material.LeafyGrass)
	local mound = cyl(m, "Mound", 7.2, 3.0, C * CFrame.new(0, -1.02, -0.05) * CFrame.Angles(0, rad(90), 0), moss, Enum.Material.LeafyGrass)
	local headEnd = part(m, "Mound", Vector3.new(2.2, 0.9, 1.2), C * CFrame.new(0, -0.25, -3.45) * CFrame.Angles(rad(-28), 0, 0), moss, Enum.Material.LeafyGrass)
	local turf = union(turfBlock, { mound, headEnd }, "Turf")
	turf.CanCollide = true
	-- mossy flanks slope down from the bed so a dip in the terrain next to the pit never shows the lining
	local flanks = Instance.new("Model") flanks.Name = "Flanks" flanks.Parent = m
	local padTop = 0.08
	for _, f in { { Vector3.new(1, 0, 0), 2.125, 10.85 }, { Vector3.new(-1, 0, 0), 2.125, 10.85 }, { Vector3.new(0, 0, -1), 4.125, 4.25 }, { Vector3.new(0, 0, 1), 4.125, 4.25 } } do
		local d, edge, len = f[1], f[2], f[3]
		local pos = (C * CFrame.new(d * (edge + 0.65) + Vector3.new(0, padTop - 0.5, 0))).Position
		local w = Instance.new("WedgePart")
		w.Name = "Flank" w.Anchored = true w.Size = Vector3.new(len, 1.0, 1.3)
		w.CFrame = CFrame.lookAt(pos, pos + d) w.Color = moss:Lerp(Color3.fromRGB(56, 72, 42), 0.35) w.Material = Enum.Material.LeafyGrass
		w.TopSurface = Enum.SurfaceType.Smooth w.BottomSurface = Enum.SurfaceType.Smooth
		w.Parent = flanks
	end
	-- interaction anchor + resting spots
	local anchor = part(m, "DigAnchor", Vector3.new(0.4, 0.4, 0.4), C * CFrame.new(0, 1.2, -1.5), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1 anchor.CanCollide = false anchor.CanTouch = false anchor.CanQuery = false
	local function att(name, cf) local a = Instance.new("Attachment") a.Name = name a.Parent = anchor a.WorldCFrame = cf return a end
	att("ShovelRest", C * CFrame.new(0.25, 0.68, -0.6) * CFrame.Angles(0, rad(rng:NextNumber(10, 22)), 0) * CFrame.Angles(rad(90), 0, 0))
	att("ShovelLean", CFrame.new(x, hsY, zH) * CFrame.Angles(0, yaw, 0) * CFrame.new(1.0, 2.25, -(info.t or 0.5) / 2 - 0.62) * CFrame.Angles(rad(14), rad(15), 0))
	att("KeysRest", C * CFrame.new(0.12, fy + 0.22, 1.0) * CFrame.Angles(0, rad(rng:NextNumber(-40, 40)), 0))
	att("PileSpot", C * CFrame.new(0.4, 0, -6.6))
	att("PitCentre", C)
	m.PrimaryPart = anchor
	return m
end


---------------------------------------------------------------- decorative monuments (not diggable)
local function trunkClear(px, pz, r)
	for _, p in workspace.Forest.Trees:GetDescendants() do
		if p.Name == "TrunkCollider" and (Vector2.new(p.Position.X, p.Position.Z) - Vector2.new(px, pz)).Magnitude < r + p.Size.Y / 2 then return false end
	end
	return true
end
B.TrunkClear = trunkClear
function B.ChestTomb(parent, x, z, lines)
	local m = Instance.new("Model") m.Name = "ChestTomb" m.Parent = parent
	local G = gy(x, z)
	local c = pick(STONE)
	local C = CFrame.new(x, G, z) * CFrame.Angles(0, rad(rng:NextNumber(-2, 2)), 0)
	part(m, "Base", Vector3.new(4.2, 0.9, 7.2), C * CFrame.new(0, -0.2, 0), c:Lerp(Color3.new(0, 0, 0), 0.1))
	local box = part(m, "Chest", Vector3.new(3.4, 2.1, 6.4), C * CFrame.new(0, 1.3, 0), c)
	part(m, "Lid", Vector3.new(4.0, 0.38, 7.0), C * CFrame.new(0, 2.54, 0), c)
	local top = part(m, "MossTop", Vector3.new(3.9, 0.16, 6.9), C * CFrame.new(0, 2.78, 0), pick(MOSS), Enum.Material.LeafyGrass) top.CanCollide = false
	for side = -1, 1, 2 do
		local d = part(m, "MossDrip", Vector3.new(0.06, rng:NextNumber(0.5, 1.2), rng:NextNumber(1.5, 3.5)), C * CFrame.new(side * 1.73, 1.9, rng:NextNumber(-1.5, 1.5)), pick(MOSS), Enum.Material.LeafyGrass)
		d.CanCollide = false
	end
	mossSkirt(m, C * CFrame.new(0, 0.2, 0), 4.2, 7.2)
	if lines then local g = inscribe(box, lines, Enum.NormalId.Front) g.Frame.Position = UDim2.fromScale(0.1, 0.18) g.Frame.Size = UDim2.fromScale(0.8, 0.7) end
	return m
end
function B.UrnPillar(parent, x, z)
	local m = Instance.new("Model") m.Name = "UrnPillar" m.Parent = parent
	local G = gy(x, z) local c = pick(STONE)
	local C = CFrame.new(x, G, z) * CFrame.Angles(rad(rng:NextNumber(-2, 2)), rad(rng:NextNumber(0, 90)), rad(rng:NextNumber(-2, 2)))
	part(m, "Plinth", Vector3.new(2.3, 1.0, 2.3), C * CFrame.new(0, 0.2, 0), c)
	part(m, "Die", Vector3.new(1.6, 2.2, 1.6), C * CFrame.new(0, 1.8, 0), c)
	part(m, "Cornice", Vector3.new(2.0, 0.32, 2.0), C * CFrame.new(0, 3.06, 0), c)
	cyl(m, "Foot", 0.35, 0.8, C * CFrame.new(0, 3.38, 0) * CFrame.Angles(0, 0, rad(90)), c)
	part(m, "Urn", Vector3.new(1.15, 1.15, 1.15), C * CFrame.new(0, 4.1, 0), c, Enum.Material.Slate, Enum.PartType.Ball)
	cyl(m, "Neck", 0.4, 0.6, C * CFrame.new(0, 4.75, 0) * CFrame.Angles(0, 0, rad(90)), c)
	local mt = part(m, "MossTop", Vector3.new(1.95, 0.08, 1.4), C * CFrame.new(0, 3.24, 0.25), pick(MOSS), Enum.Material.LeafyGrass) mt.CanCollide = false
	mossSkirt(m, C * CFrame.new(0, 0.05, 0), 2.3, 2.3)
	return m
end
function B.Ledger(parent, x, z, name)
	local m = Instance.new("Model") m.Name = "LedgerCross" m.Parent = parent
	local G = gy(x, z) local c = pick(STONE)
	local C = CFrame.new(x, G, z) * CFrame.Angles(rad(rng:NextNumber(-1.5, 1.5)), rad(rng:NextNumber(-3, 3)), rad(rng:NextNumber(-1.5, 1.5)))
	part(m, "Slab", Vector3.new(3.6, 0.7, 6.8), C * CFrame.new(0, -0.1, -0.2), c)
	for _ = 1, 3 do
		local p = part(m, "Moss", Vector3.new(rng:NextNumber(1, 2.6), 0.07, rng:NextNumber(1.2, 3)), C * CFrame.new(rng:NextNumber(-0.6, 0.6), 0.27, rng:NextNumber(-2.2, 1.8)), pick(MOSS), Enum.Material.LeafyGrass)
		p.CanCollide = false
	end
	B.Headstone(m, C * CFrame.new(0, -0.4, 3.6), "celtic", 2.3, 5.2, 0.45, c, { "", name })
	return m
end
function B.Fallen(parent, x, z)
	local m = Instance.new("Model") m.Name = "FallenHeadstone" m.Parent = parent
	local G = gy(x, z) local c = pick(STONE)
	local C = CFrame.new(x, G - 0.5, z) * CFrame.Angles(rad(-6), rad(rng:NextNumber(-8, 8)), rad(5))
	local stump = part(m, "Stump", Vector3.new(2.5, 1.9, 0.5), C * CFrame.new(0, 0.95, 0), c)
	local cut = part(m, "Cut", Vector3.new(4, 1.2, 1), C * CFrame.new(0.3, 2.0, 0) * CFrame.Angles(0, 0, rad(-14)))
	stump = subtract(stump, { cut }, "Stump")
	-- the broken top lies face-up in the moss in front
	local top = part(m, "Top", Vector3.new(2.5, 1.4, 0.5), CFrame.new(x - 0.3, G - 0.05, z - 1.8) * CFrame.Angles(rad(-86), rad(rng:NextNumber(-20, 20)), 0), c)
	local cap = cyl(m, "Cap", 0.5, 2.5, top.CFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, rad(90), 0), c)
	top = union(top, { cap }, "Top")
	local mt = part(m, "Moss", Vector3.new(1.6, 0.06, 1.1), top.CFrame * CFrame.new(-0.2, 0.2, -0.27) * CFrame.Angles(rad(90), 0, 0), pick(MOSS), Enum.Material.LeafyGrass)
	mt.CanCollide = false
	mossSkirt(m, CFrame.new(x, G + 0.02, z), 2.5, 0.5)
	return m
end
function B.SmallMarker(parent, x, z, style)
	local m = Instance.new("Model") m.Name = "SmallMarker" m.Parent = parent
	local G = gy(x, z)
	local base = CFrame.new(x, G - 0.45, z) * CFrame.Angles(0, rad(rng:NextNumber(-12, 12)), 0) * CFrame.Angles(rad(rng:NextNumber(-12, 10)), 0, rad(rng:NextNumber(-10, 10)))
	B.Headstone(m, base, style or "rounded", rng:NextNumber(1.0, 1.4), rng:NextNumber(1.6, 2.2), 0.34, pick(STONE), nil)
	return m
end

---------------------------------------------------------------- boundary wall, gate, lanterns, mist
local WALL = { x0 = 208.5, x1 = 269.5, z0 = 211, z1 = 265, gate0 = 229.8, gate1 = 240.2 }
B.WALL = WALL
local function wallRun(parent, ax, az, bx, bz)
	local len = (Vector2.new(bx, bz) - Vector2.new(ax, az)).Magnitude
	local n = math.max(1, math.floor(len / 3.2 + 0.5))
	local dir = Vector3.new(bx - ax, 0, bz - az).Unit
	for k = 0, n - 1 do
		local t0 = k / n
		local cx, cz = ax + (bx - ax) * (t0 + 0.5 / n), az + (bz - az) * (t0 + 0.5 / n)
		if trunkClear(cx, cz, 2.2) then
			local G = math.min(gy(cx - dir.X * 1.4, cz - dir.Z * 1.4), gy(cx, cz), gy(cx + dir.X * 1.4, cz + dir.Z * 1.4))
			local collapsed = rng:NextNumber() < 0.14
			local h = collapsed and rng:NextNumber(0.5, 1.0) or rng:NextNumber(2.0, 2.5)
			local look = CFrame.lookAt(Vector3.new(cx, 0, cz), Vector3.new(cx + dir.X, 0, cz + dir.Z))
			local segLen = len / n + 0.05
			local col = Color3.fromRGB(88, 90, 84):Lerp(Color3.fromRGB(70, 74, 66), rng:NextNumber())
			local seg = part(parent, "Wall", Vector3.new(1.0, h + 0.9, segLen), look.Rotation + Vector3.new(cx, G - 0.9 + (h + 0.9) / 2, cz), col, Enum.Material.Cobblestone)
			if not collapsed then
				local cap = part(parent, "Coping", Vector3.new(1.25, 0.22, segLen), seg.CFrame * CFrame.new(0, (h + 0.9) / 2 + 0.11, 0), Color3.fromRGB(74, 76, 72), Enum.Material.Slate)
				if rng:NextNumber() < 0.55 then
					local mp = part(parent, "Moss", Vector3.new(1.28, 0.07, segLen * rng:NextNumber(0.3, 0.9)), cap.CFrame * CFrame.new(0, 0.13, rng:NextNumber(-0.4, 0.4)), pick(MOSS), Enum.Material.LeafyGrass)
					mp.CanCollide = false
				end
			else
				for _ = 1, rng:NextInteger(2, 4) do
					local sz = rng:NextNumber(0.5, 1.0)
					local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-1.4, 1.4))
					local px, pz = cx + off.X, cz + off.Z
					part(parent, "Rubble", Vector3.new(sz, sz * 0.7, sz * 1.2), CFrame.new(px, gy(px, pz) + sz * 0.15, pz) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)), col, Enum.Material.Cobblestone)
				end
			end
		end
	end
end
local function pillar(parent, x, z, tall)
	local G = math.min(gy(x, z), gy(x + 0.8, z + 0.8), gy(x - 0.8, z - 0.8))
	local stone = Color3.fromRGB(84, 86, 80)
	part(parent, "PillarBase", Vector3.new(2.0, 1.4, 2.0), CFrame.new(x, G - 0.1, z), stone, Enum.Material.Cobblestone)
	local shaft = part(parent, "Pillar", Vector3.new(1.5, tall, 1.5), CFrame.new(x, G + 0.6 + tall / 2, z), stone, Enum.Material.Cobblestone)
	part(parent, "PillarCap", Vector3.new(2.0, 0.36, 2.0), CFrame.new(x, G + 0.6 + tall + 0.18, z), Color3.fromRGB(72, 74, 70), Enum.Material.Slate)
	part(parent, "Finial", Vector3.new(0.85, 0.85, 0.85), CFrame.new(x, G + 0.6 + tall + 0.75, z), Color3.fromRGB(72, 74, 70), Enum.Material.Slate, Enum.PartType.Ball)
	local mp = part(parent, "Moss", Vector3.new(2.03, 0.08, 1.2), CFrame.new(x, G + 0.6 + tall + 0.38, z + 0.3), pick(MOSS), Enum.Material.LeafyGrass)
	mp.CanCollide = false
	return G + 0.6 + tall
end
local function lantern(parent, cf)
	local m = Instance.new("Model") m.Name = "Lantern" m.Parent = parent
	part(m, "Bracket", Vector3.new(0.1, 0.1, 0.7), cf * CFrame.new(0, 0.55, 0.35), IRON, Enum.Material.Metal)
	part(m, "Hook", Vector3.new(0.06, 0.25, 0.06), cf * CFrame.new(0, 0.42, 0), IRON, Enum.Material.Metal)
	part(m, "Roof", Vector3.new(0.5, 0.08, 0.5), cf * CFrame.new(0, 0.28, 0), IRON, Enum.Material.Metal)
	part(m, "Peak", Vector3.new(0.26, 0.26, 0.26), cf * CFrame.new(0, 0.34, 0) * CFrame.Angles(rad(45), 0, rad(45)), IRON, Enum.Material.Metal)
	local glass = part(m, "Glass", Vector3.new(0.36, 0.48, 0.36), cf, Color3.fromRGB(255, 196, 120), Enum.Material.Glass)
	glass.Transparency = 0.45
	for _, o in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part(m, "Frame", Vector3.new(0.05, 0.5, 0.05), cf * CFrame.new(o[1] * 0.19, 0, o[2] * 0.19), IRON, Enum.Material.Metal)
	end
	part(m, "Base", Vector3.new(0.46, 0.07, 0.46), cf * CFrame.new(0, -0.27, 0), IRON, Enum.Material.Metal)
	local flame = part(m, "Flame", Vector3.new(0.08, 0.16, 0.08), cf * CFrame.new(0, -0.1, 0), Color3.fromRGB(255, 170, 80), Enum.Material.Neon)
	local light = Instance.new("PointLight") light.Name = "Glow" light.Color = Color3.fromRGB(255, 160, 85) light.Range = 16 light.Brightness = 1.1 light.Shadows = true light.Parent = flame
	for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.CanCollide = false end end
	return m
end
local function gateLeaf(parent, hinge, width, openDeg, sag)
	local m = Instance.new("Model") m.Name = "GateLeaf" m.Parent = parent
	local H = 4.1
	local frame = hinge * CFrame.Angles(0, rad(openDeg), rad(sag))
	part(m, "RailTop", Vector3.new(width, 0.12, 0.12), frame * CFrame.new(width / 2, H - 0.2, 0), IRON, Enum.Material.Metal)
	part(m, "RailMid", Vector3.new(width, 0.1, 0.1), frame * CFrame.new(width / 2, 1.7, 0), IRON, Enum.Material.Metal)
	part(m, "RailLow", Vector3.new(width, 0.12, 0.12), frame * CFrame.new(width / 2, 0.45, 0), IRON, Enum.Material.Metal)
	local bars = math.floor(width / 0.42)
	for k = 0, bars do
		local bx = k * width / bars
		cyl(m, "Bar", H - 0.2, 0.09, frame * CFrame.new(bx, 0.2 + (H - 0.2) / 2, 0) * CFrame.Angles(0, 0, rad(90)), IRON, Enum.Material.Metal)
		part(m, "Spike", Vector3.new(0.16, 0.16, 0.16), frame * CFrame.new(bx, H + 0.08, 0) * CFrame.Angles(0, rad(45), rad(45)), IRON, Enum.Material.Metal)
	end
	return m
end
function B.WallsAndGate(parent)
	local walls = Instance.new("Folder") walls.Name = "Walls" walls.Parent = parent
	wallRun(walls, WALL.x0, WALL.z0, WALL.gate0 - 1, WALL.z0)
	wallRun(walls, WALL.gate1 + 1, WALL.z0, WALL.x1, WALL.z0)
	wallRun(walls, WALL.x1, WALL.z0, WALL.x1, WALL.z1)
	wallRun(walls, WALL.x1, WALL.z1, WALL.x0, WALL.z1)
	wallRun(walls, WALL.x0, WALL.z1, WALL.x0, WALL.z0)
	for _, c in { { WALL.x0, WALL.z0 }, { WALL.x1, WALL.z0 }, { WALL.x1, WALL.z1 }, { WALL.x0, WALL.z1 } } do
		if trunkClear(c[1], c[2], 1.5) then pillar(walls, c[1], c[2], 2.4) end
	end
	local gate = Instance.new("Model") gate.Name = "Gate" gate.Parent = parent
	local topL = pillar(gate, WALL.gate0, WALL.z0, 5.0)
	local topR = pillar(gate, WALL.gate1, WALL.z0, 5.0)
	local G = gy(235, WALL.z0)
	local leafW = (WALL.gate1 - WALL.gate0 - 1.6) / 2
	gateLeaf(gate, CFrame.new(WALL.gate0 + 0.8, G - 0.1, WALL.z0), leafW, -72, 0)
	gateLeaf(gate, CFrame.new(WALL.gate1 - 0.8, G - 0.1, WALL.z0) * CFrame.Angles(0, rad(180), 0), leafW, 104, -7)
	-- iron arch between the pillars
	local cx, cy = 235, math.min(topL, topR) - 0.3
	local r = (WALL.gate1 - WALL.gate0) / 2 - 0.75
	local segs = 14
	for k = 0, segs - 1 do
		local a0, a1 = math.pi * k / segs, math.pi * (k + 1) / segs
		local p0 = Vector3.new(cx + math.cos(a0) * r, cy + math.sin(a0) * r * 0.55, WALL.z0)
		local p1 = Vector3.new(cx + math.cos(a1) * r, cy + math.sin(a1) * r * 0.55, WALL.z0)
		local mid = (p0 + p1) / 2
		part(gate, "Arch", Vector3.new((p1 - p0).Magnitude + 0.05, 0.16, 0.16), CFrame.lookAt(mid, mid + (p1 - p0)) * CFrame.Angles(0, rad(90), 0), IRON, Enum.Material.Metal)
	end
	part(gate, "ArchCross", Vector3.new(0.12, 1.0, 0.12), CFrame.new(cx, cy + r * 0.55 + 0.5, WALL.z0), IRON, Enum.Material.Metal)
	part(gate, "ArchCross", Vector3.new(0.6, 0.12, 0.12), CFrame.new(cx, cy + r * 0.55 + 0.68, WALL.z0), IRON, Enum.Material.Metal)
	-- lanterns on the outer faces of the gate pillars
	lantern(gate, CFrame.new(WALL.gate0, topL - 1.3, WALL.z0 - 1.45) * CFrame.Angles(0, rad(180), 0))
	lantern(gate, CFrame.new(WALL.gate1, topR - 1.3, WALL.z0 - 1.45) * CFrame.Angles(0, rad(180), 0))
	return walls, gate
end
function B.Mist(parent)
	local f = Instance.new("Folder") f.Name = "Mist" f.Parent = parent
	for k, c in { { 224, 238 }, { 254, 238 } } do
		local p = part(f, "MistVolume" .. k, Vector3.new(28, 1, 50), CFrame.new(c[1], gy(c[1], c[2]) + 0.8, c[2]), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		p.Transparency = 1 p.CanCollide = false p.CanTouch = false p.CanQuery = false p.CastShadow = false
		local e = Instance.new("ParticleEmitter")
		e.Name = "GroundMist"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = 3.5
		e.Lifetime = NumberRange.new(10, 15)
		e.Speed = NumberRange.new(0.1, 0.35)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Drag = 0.4
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-6, 6)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(0.5, 9), NumberSequenceKeypoint.new(1, 12) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(206, 210, 216))
		e.LightInfluence = 1
		e.Parent = p
	end
	return f
end
function B.Sign(parent)
	-- Task17's anchor: an old wooden sign outside the gate
	local x, z = 243.6, 208.4
	local G = gy(x, z)
	local wood = Color3.fromRGB(92, 72, 54)
	part(parent, "Post", Vector3.new(0.35, 4.2, 0.35), CFrame.new(x - 1.3, G + 1.4, z), wood:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood)
	part(parent, "Post", Vector3.new(0.35, 4.2, 0.35), CFrame.new(x + 1.3, G + 1.4, z), wood:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood)
	local board = part(parent, "GraveyardSign", Vector3.new(3.4, 1.25, 0.18), CFrame.new(x, G + 2.7, z - 0.25) * CFrame.Angles(0, 0, rad(-3)), wood, Enum.Material.WoodPlanks)
	local g = Instance.new("SurfaceGui") g.Name = "Text" g.Face = Enum.NormalId.Front g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = 60 g.LightInfluence = 1 g.Parent = board
	local t = Instance.new("TextLabel") t.BackgroundTransparency = 1 t.Size = UDim2.fromScale(0.92, 0.8) t.Position = UDim2.fromScale(0.04, 0.1)
	t.Font = Enum.Font.Garamond t.TextScaled = true t.Text = "OLD CEMETERY" t.TextColor3 = Color3.fromRGB(34, 25, 18) t.TextTransparency = 0.08 t.Parent = g
	return board
end

---------------------------------------------------------------- everything
B.GRAVES = {
	{ x = 214, zc = 224, style = "rounded", w = 2.6, h = 4.1, title = "Elias Wren", lines = { "IN MEMORY OF", "ELIAS WREN", "1841 – 1889", "REST IN PEACE" } },
	{ x = 226, zc = 224, style = "gothic", w = 2.4, h = 4.3, title = "Margaret Holloway", lines = { "IN LOVING MEMORY", "MARGARET HOLLOWAY", "1852 – 1897", "GONE BUT NOT FORGOTTEN" } },
	{ x = 246, zc = 224, style = "cross", h = 4.6, title = "Thomas Ashgrove", lines = { "", "THOMAS ASHGROVE" } },
	{ x = 254, zc = 224, style = "shouldered", w = 2.8, h = 3.9, t = 0.55, title = "Ada Pruitt", lines = { "HERE LIES", "ADA PRUITT", "1870 – 1871", "OUR LITTLE LAMB" } },
	{ x = 214, zc = 240, style = "rounded", w = 2.4, h = 3.7, title = "Jonah Calder", lines = { "IN MEMORY OF", "JONAH CALDER", "1838 – 1901", "ASLEEP IN THE PINES" } },
	{ x = 226, zc = 240, style = "shouldered", w = 2.6, h = 4.2, title = "Beatrice Morrow", lines = { "BELOVED WIFE", "BEATRICE MORROW", "1859 – 1913", "AT REST" } },
	{ x = 242, zc = 240, style = "celtic", h = 5.0, title = "Samuel Fenwick", lines = { "", "SAMUEL FENWICK" } },
	{ x = 262, zc = 240, style = "gothic", w = 2.3, h = 4.0, title = "Clara Dunmore", lines = { "HERE LIES", "CLARA DUNMORE", "1877 – 1906", "SHE WALKED INTO THE WOODS" } },
	{ x = 218, zc = 256, style = "rounded", w = 2.7, h = 4.4, title = "Walter Grimsby", lines = { "IN MEMORY OF", "WALTER GRIMSBY", "1829 – 1888", "THY WILL BE DONE" } },
	{ x = 246, zc = 256, style = "rounded", w = 2.5, h = 3.6, title = "Henrietta Voss", lines = { "BELOVED", "HENRIETTA VOSS", "1861 – 1919", "SLEEP WELL" } },
	{ x = 258, zc = 256, style = "gothic", w = 2.2, h = 3.8, title = "an unknown camper", lines = { "HERE LIES", "UNKNOWN", "FOUND 1974", "NEVER CLAIMED" } },
}
function B.Build()
	rng = Random.new(1871)
	local old = workspace:FindFirstChild("Graveyard")
	if old then old:Destroy() end
	B.PaintGround()
	task.wait(1) -- let terrain collision catch up before sampling heights
	local root = Instance.new("Model") root.Name = "Graveyard" root.Parent = workspace
	local graves = Instance.new("Folder") graves.Name = "Graves" graves.Parent = root
	for i, info in B.GRAVES do B.Grave(graves, i, info) end
	local decor = Instance.new("Folder") decor.Name = "Decor" decor.Parent = root
	B.ChestTomb(decor, 250, 240, { "THE", "ASHCOMBE", "FAMILY", "" })
	B.UrnPillar(decor, 220, 238.5)
	B.Ledger(decor, 266, 255.5, "IN GOD'S KEEPING")
	B.Fallen(decor, 252.4, 255)
	B.Headstone(decor, CFrame.new(240.5, gy(240.5, 222) - 0.5, 222) * CFrame.Angles(rad(-6), rad(8), rad(4)), "cross", 2, 3.6, 0.45, pick(STONE), nil)
	for _, s in { { 210.8, 251, "rounded" }, { 229.4, 259.5, "gothic" }, { 262.5, 230.5, "rounded" }, { 223, 262.6, "shouldered" }, { 250.5, 262.5, "rounded" }, { 212.5, 215.5, "gothic" }, { 229.5, 251.5, "rounded" } } do
		if trunkClear(s[1], s[2], 1.2) then B.SmallMarker(decor, s[1], s[2], s[3]) end
	end
	B.WallsAndGate(root)
	B.Mist(root)
	-- pristine terrain for GraveyardService to restore each round
	local assets = game.ServerStorage:FindFirstChild("GraveyardAssets") or Instance.new("Folder")
	assets.Name = "GraveyardAssets" assets.Parent = game.ServerStorage
	local old2 = assets:FindFirstChild("TerrainPristine") if old2 then old2:Destroy() end
	local snap = T:CopyRegion(Region3int16.new(Vector3int16.new(50, -6, 50), Vector3int16.new(69, 12, 69)))
	snap.Name = "TerrainPristine" snap.Parent = assets
	return root
end

return B
