-- RadioTowerFrame: a plainer radio tower. The Creator Store tower mesh carried seven dishes and antennas, two of
-- them right across the ladder, and a mesh can't be partly deleted, so this rebuilds the same lattice from steel
-- members: exactly the old shape (same legs, same taper, same deck height, same mast) with just two dishes left,
-- both well away from the ladder on the north face.
--   require(game.ServerStorage.RadioTowerFrame).Build()    -- swap the mesh for the frame
--   require(game.ServerStorage.RadioTowerFrame).Restore()  -- put the original mesh back
-- The ladder, platform, colliders, cabinet and everything else in workspace.RadioTower are untouched.
local B = {}
local SS = game:GetService("ServerStorage")
local C = Vector3.new(-38.53, -2.5, -3.10) -- tower centre line at its base (RadioTowerBuilder: MESH_AT + AXIS_OFFSET)
local function hw(h) return 8.58 - 0.0839 * (h - 1) end -- outer half-width h studs up (RadioTowerBuilder)
local LATTICE_TOP = 65.0 -- the lattice ends just under the deck (deck top at 65.6)
local MAST_HW = 1.75 -- the mast's outer half-width (measured on the old mesh)
local MAST_TOP = 94.0
local WHITE = Color3.fromRGB(222, 222, 216)
local RED = Color3.fromRGB(178, 40, 34)
local DISH = Color3.fromRGB(196, 198, 196)

local folder
local function beam(name, a, b, thick, colour)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(thick, thick, (b - a).Magnitude + thick * 0.6)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Color = colour
	p.Material = Enum.Material.Metal
	p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end
local function at(x, h, z) return C + Vector3.new(x, h, z) end
local function paint(h) return h < 52 and WHITE or RED end

-- a square tapering section between heights h0 and h1 with half-widths w0, w1 (to the member centre lines)
local function section(h0, h1, w0, w1, thick, cross)
	local colour = paint((h0 + h1) / 2)
	local corners0 = { at(-w0, h0, -w0), at(w0, h0, -w0), at(w0, h0, w0), at(-w0, h0, w0) }
	local corners1 = { at(-w1, h1, -w1), at(w1, h1, -w1), at(w1, h1, w1), at(-w1, h1, w1) }
	for i = 1, 4 do
		local j = i % 4 + 1
		beam("Girt", corners1[i], corners1[j], thick * 0.7, colour)
		beam("Brace", corners0[i], corners1[j], thick * 0.55, colour)
		if cross then beam("Brace", corners0[j], corners1[i], thick * 0.55, colour) end
	end
end

function B.Restore()
	local rt = workspace.RadioTower
	local f = rt:FindFirstChild("LatticeFrame") if f then f:Destroy() end
	local bk = SS:FindFirstChild("BeforeTowerFrame")
	if bk and bk:FindFirstChild("Lattice") then bk.Lattice.Parent = rt end
end

function B.Build()
	local rt = workspace.RadioTower
	local old = rt:FindFirstChild("LatticeFrame") if old then old:Destroy() end
	-- set the mesh aside (not deleted)
	local bk = SS:FindFirstChild("BeforeTowerFrame")
	if not bk then bk = Instance.new("Folder") bk.Name = "BeforeTowerFrame" bk.Parent = SS end
	local mesh = rt:FindFirstChild("Lattice")
	if mesh then mesh.Parent = bk end
	folder = Instance.new("Model") folder.Name = "LatticeFrame" folder.Parent = rt
	-- the lattice: four legs on the old taper, a girt every 6.5 studs and X-bracing on every face
	local LEG = 0.55
	local function wc(h) return hw(h) - LEG / 2 end
	for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		-- legs in two lengths so the paint can change colour part way up
		beam("Leg", at(s[1] * wc(0), 0, s[2] * wc(0)), at(s[1] * wc(52), 52, s[2] * wc(52)), LEG, WHITE)
		beam("Leg", at(s[1] * wc(52), 52, s[2] * wc(52)), at(s[1] * wc(LATTICE_TOP), LATTICE_TOP, s[2] * wc(LATTICE_TOP)), LEG, RED)
	end
	local levels = { 0.4 }
	local step = (LATTICE_TOP - 0.4) / 10
	for i = 1, 10 do table.insert(levels, 0.4 + step * i) end
	beam("Girt", at(-wc(0.4), 0.4, -wc(0.4)), at(wc(0.4), 0.4, -wc(0.4)), LEG * 0.7, WHITE)
	beam("Girt", at(wc(0.4), 0.4, -wc(0.4)), at(wc(0.4), 0.4, wc(0.4)), LEG * 0.7, WHITE)
	beam("Girt", at(wc(0.4), 0.4, wc(0.4)), at(-wc(0.4), 0.4, wc(0.4)), LEG * 0.7, WHITE)
	beam("Girt", at(-wc(0.4), 0.4, wc(0.4)), at(-wc(0.4), 0.4, -wc(0.4)), LEG * 0.7, WHITE)
	for i = 1, #levels - 1 do
		local h0, h1 = levels[i], levels[i + 1]
		section(h0, h1, wc(h0), wc(h1), LEG, true)
	end
	-- the mast from inside the lattice top up past the deck, red and white bands, zig-zag braced
	local MW = MAST_HW - 0.2
	local mh0 = LATTICE_TOP - 4
	for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local h = mh0
		while h < MAST_TOP - 0.01 do
			local h2 = math.min(h + 7, MAST_TOP)
			local band = math.floor((h - mh0) / 7) % 2 == 0 and RED or WHITE
			beam("MastLeg", at(s[1] * MW, h, s[2] * MW), at(s[1] * MW, h2, s[2] * MW), 0.4, band)
			h = h2
		end
	end
	local h = mh0
	local k = 0
	while h < MAST_TOP - 0.01 do
		local h2 = math.min(h + 3.5, MAST_TOP)
		local band = math.floor((h - mh0) / 7) % 2 == 0 and RED or WHITE
		local c0 = { at(-MW, h, -MW), at(MW, h, -MW), at(MW, h, MW), at(-MW, h, MW) }
		local c1 = { at(-MW, h2, -MW), at(MW, h2, -MW), at(MW, h2, MW), at(-MW, h2, MW) }
		for i = 1, 4 do
			local j = i % 4 + 1
			beam("MastGirt", c1[i], c1[j], 0.22, band)
			if k % 2 == 0 then beam("MastBrace", c0[i], c1[j], 0.18, band) else beam("MastBrace", c0[j], c1[i], 0.18, band) end
		end
		h = h2
		k += 1
	end
	-- the cap and the light's pole
	local cap = Instance.new("Part")
	cap.Name = "MastCap" cap.Size = Vector3.new(MAST_HW * 2 + 0.2, 0.3, MAST_HW * 2 + 0.2)
	cap.CFrame = CFrame.new(at(0, MAST_TOP + 0.15, 0)) cap.Color = RED cap.Material = Enum.Material.Metal
	cap.Anchored = true cap.CanCollide = false cap.CanQuery = false cap.CanTouch = false cap.Parent = folder
	local light = rt:FindFirstChild("AviationLight")
	if light then
		light.Position = at(0, MAST_TOP + 1.6, 0)
		beam("LightPole", at(0, MAST_TOP + 0.3, 0), at(0, MAST_TOP + 1.3, 0), 0.18, RED)
	end
	-- the two dishes that stay: on the mast's south-west and south-east corners above the deck, facing out,
	-- nowhere near the ladder (which comes up the north face)
	local function dish(hh, corner, dia)
		local dir = Vector3.new(corner.X, 0, corner.Z).Unit
		local mount = at(corner.X * MW, hh, corner.Z * MW)
		local face = mount + dir * 1.1
		beam("DishArm", mount, face - dir * 0.2, 0.2, Color3.fromRGB(120, 122, 124))
		local d = Instance.new("Part")
		d.Name = "Dish" d.Shape = Enum.PartType.Cylinder
		d.Size = Vector3.new(0.5, dia, dia)
		d.CFrame = CFrame.lookAt(face, face + dir) * CFrame.Angles(0, math.pi / 2, 0)
		d.Color = DISH d.Material = Enum.Material.SmoothPlastic
		d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false d.Parent = folder
		local rim = d:Clone()
		rim.Name = "DishBack" rim.Size = Vector3.new(0.6, dia * 0.55, dia * 0.55)
		rim.CFrame = CFrame.lookAt(face - dir * 0.4, face + dir) * CFrame.Angles(0, math.pi / 2, 0)
		rim.Color = Color3.fromRGB(150, 152, 152) rim.Parent = folder
	end
	dish(LATTICE_TOP + 9, Vector3.new(-1, 0, -1), 3.2)
	dish(LATTICE_TOP + 16, Vector3.new(1, 0, -1), 2.4)
	B.Extras(folder)
	local n = 0
	for _, p in folder:GetDescendants() do if p:IsA("BasePart") then n += 1 end end
	return n
end

-- More dishes (none on the +Z face, where the ladder climbs) and a thin antenna on top of the mast with the red
-- AviationLight at its tip. The light stays dark until the radio is fixed (ServerScriptService.AntennaLight).
-- Safe to run again on its own: require(game.ServerStorage.RadioTowerFrame).Extras()
local ANTENNA = 12 -- how far the antenna rises above the mast cap
function B.Extras(into)
	local rt = workspace.RadioTower
	local frame = into or rt:FindFirstChild("LatticeFrame")
	if not frame then return 0 end
	local old = frame:FindFirstChild("Extras") if old then old:Destroy() end
	folder = Instance.new("Model") folder.Name = "Extras" folder.Parent = frame
	local MW = MAST_HW - 0.2
	-- a drum dish (the covered microwave dishes real towers carry) on a short arm, facing straight out
	local function drum(mount, dir, dia)
		local face = mount + dir * 1.1
		beam("DishArm", mount, face - dir * 0.2, 0.2, Color3.fromRGB(120, 122, 124))
		local d = Instance.new("Part")
		d.Name = "Dish" d.Shape = Enum.PartType.Cylinder
		d.Size = Vector3.new(0.5, dia, dia)
		d.CFrame = CFrame.lookAt(face, face + dir) * CFrame.Angles(0, math.pi / 2, 0)
		d.Color = DISH d.Material = Enum.Material.SmoothPlastic
		d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false d.Parent = folder
		local rim = d:Clone()
		rim.Name = "DishBack" rim.Size = Vector3.new(0.6, dia * 0.55, dia * 0.55)
		rim.CFrame = CFrame.lookAt(face - dir * 0.4, face + dir) * CFrame.Angles(0, math.pi / 2, 0)
		rim.Color = Color3.fromRGB(150, 152, 152) rim.Parent = folder
		-- a dark face so it reads as a dish from the ground
		local f = d:Clone()
		f.Name = "DishFace" f.Size = Vector3.new(0.05, dia * 0.86, dia * 0.86)
		f.CFrame = CFrame.lookAt(face + dir * 0.26, face + dir * 2) * CFrame.Angles(0, math.pi / 2, 0)
		f.Color = Color3.fromRGB(176, 178, 176) f.Parent = folder
	end
	-- on the mast above the deck (well over head height)
	drum(at(-MW, LATTICE_TOP + 12.5, 0), Vector3.new(-1, 0, 0), 2.8)
	drum(at(MW, LATTICE_TOP + 20, 0), Vector3.new(1, 0, 0), 2.2)
	-- on the lattice, on the faces away from the ladder
	local h1, h2 = 46, 40
	drum(at(-hw(h1) + 0.3, h1, -1.5), Vector3.new(-1, 0, 0), 3.0)
	drum(at(0.5, h2, -hw(h2) + 0.3), Vector3.new(0, 0, -1), 3.4)

	-- the antenna: a thin red-and-white whip from the mast cap, a little thinner toward the tip
	local base = MAST_TOP + 0.3
	local segs = 6
	for i = 0, segs - 1 do
		local a, b = base + ANTENNA * i / segs, base + ANTENNA * (i + 1) / segs
		beam("Antenna", at(0, a, 0), at(0, b, 0), 0.22 - 0.1 * i / (segs - 1), i % 2 == 0 and RED or WHITE)
	end
	-- the red dot on top
	local light = rt:FindFirstChild("AviationLight")
	if light then
		light.Shape = Enum.PartType.Ball
		light.Size = Vector3.new(0.55, 0.55, 0.55)
		light.CFrame = CFrame.new(at(0, base + ANTENNA + 0.2, 0))
		light.Anchored = true light.CanCollide = false light.CanQuery = false light.CanTouch = false
		local lp = frame:FindFirstChild("LightPole", true) if lp then lp:Destroy() end
	end
	local n = 0
	for _, p in folder:GetDescendants() do if p:IsA("BasePart") then n += 1 end end
	return n
end

return B
