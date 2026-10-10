-- CounselorBuilder
-- Builds StarterPlayer.StarterCharacter: the camp-counselor outfit on the bulky blocky R15 body
-- (CounselorKit.BulkyBody). Set BODY_SOURCE to "RthroBody" to go back to the slim realistic body.
--   require(game.ServerStorage.CounselorBuilder).Build()             -- rebuild + install the StarterCharacter
--   require(game.ServerStorage.CounselorBuilder).Build(false)        -- build a draft in workspace to look at
--   require(game.ServerStorage.CounselorBuilder).Preview(colour, at) -- a posed copy for screenshots
-- Every clothing piece is fitted by raycasting against the real body meshes and then welded on, so it
-- hugs the body instead of floating. Detail sizes were first measured on the slim body; each fitter
-- scales them by how much bigger its body part is than the slim one (REF), so they fit either body. Pieces that wear the player's match colour carry a "MatchColour"
-- attribute (a shade: 1 = the exact colour, lower = darker); the Wristbands script paints them.
-- The original blocky counselor (old outfit) is kept in ServerStorage.CounselorKit.BlockyCounselor.
local B = {}

local KIT = game.ServerStorage:WaitForChild("CounselorKit")
local BODY_SOURCE = "BulkyBody"
-- slim-body sizes the detail measurements were taken on
local REF = {
	UpperTorso = Vector3.new(1.471, 1.625, 0.951),
	UpperArm = Vector3.new(0.532, 1.265, 0.592),
	UpperLeg = Vector3.new(0.610, 1.769, 0.787),
	Head = Vector3.new(0.685, 1.103, 0.762),
}
local BUILD_AT = CFrame.new(0, 900, 4000)

local C = {
	skin = Color3.fromRGB(214, 136, 88),
	shirt = Color3.fromRGB(208, 168, 96),
	shirtDark = Color3.fromRGB(168, 130, 70),
	flap = Color3.fromRGB(184, 145, 80),
	shorts = Color3.fromRGB(74, 98, 36),
	shortsDark = Color3.fromRGB(56, 76, 26),
	cargoFlap = Color3.fromRGB(65, 87, 31),
	belt = Color3.fromRGB(94, 60, 36),
	brass = Color3.fromRGB(186, 150, 72),
	sock = Color3.fromRGB(222, 218, 206),
	rubber = Color3.fromRGB(52, 40, 32),
	lace = Color3.fromRGB(214, 200, 168),
	hat = Color3.fromRGB(110, 112, 52),
	hatBrim = Color3.fromRGB(99, 100, 46),
	hair = Color3.fromRGB(110, 60, 26),
	wood = Color3.fromRGB(196, 170, 120),
	button = Color3.fromRGB(128, 117, 91),
	eye = Color3.fromRGB(46, 32, 24),
	shine = Color3.fromRGB(250, 246, 236),
	brow = Color3.fromRGB(83, 53, 30),
	freckle = Color3.fromRGB(168, 104, 72),
	mouth = Color3.fromRGB(150, 84, 70),
	lips = Color3.fromRGB(190, 92, 98),
	match = Color3.fromRGB(235, 40, 40), -- preview only: the player's own colour replaces it in game
}
local function M(shade) return { match = shade } end -- "wear the player's colour at this shade"

-- the body itself: shirt and shorts are the body meshes, coloured like cloth
local BODY = {
	Head = { C.skin, "SmoothPlastic" },
	UpperTorso = { C.shirt, "Fabric" }, LowerTorso = { C.shorts, "Fabric" },
	LeftUpperArm = { C.shirt, "Fabric" }, RightUpperArm = { C.shirt, "Fabric" },
	LeftLowerArm = { C.skin, "SmoothPlastic" }, RightLowerArm = { C.skin, "SmoothPlastic" },
	LeftHand = { C.skin, "SmoothPlastic" }, RightHand = { C.skin, "SmoothPlastic" },
	LeftUpperLeg = { C.shorts, "Fabric" }, RightUpperLeg = { C.shorts, "Fabric" },
	LeftLowerLeg = { C.skin, "SmoothPlastic" }, RightLowerLeg = { C.skin, "SmoothPlastic" },
	LeftFoot = { M(0.82), "Leather" }, RightFoot = { M(0.82), "Leather" }, -- the boots
}
-- A Humanoid paints every part of a limb (and the whole torso) in ONE colour: the colour of its top part.
-- So the parts that must differ from the rest of their limb (sleeves, shorts, boots) are shown by an
-- exact copy of the mesh in the Outfit folder, and the real part underneath is made invisible and given
-- the limb's colour (skin for arms and legs, shirt for the torso).
local LOOK = { "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftFoot", "RightFoot" }
local GROUP = { LowerTorso = C.shirt }

---------------------------------------------------------------- helpers
local char, outfit, welds, report
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include

local function shade(c, s) return Color3.new(c.R * s, c.G * s, c.B * s) end
local function paint(p, colour)
	if typeof(colour) == "table" then
		p.Color = shade(C.match, colour.match)
		p:SetAttribute("MatchColour", colour.match)
	else
		p.Color = colour
	end
end

local function newPart(name, size, colour, material, class)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Size = size
	p.Material = Enum.Material[material or "Fabric"]
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = size.X * size.Y * size.Z > 0.004
	p.EnableFluidForces = false
	paint(p, colour)
	return p
end

local function put(p, cf, weldTo)
	p.CFrame = cf
	p.Parent = outfit
	welds[p] = weldTo
	return p
end

local function cast(parts, from, to)
	rp.FilterDescendantsInstances = parts
	return workspace:Raycast(from, to - from, rp)
end

-- a ray from outside along -D through local point P of `body`; first surface hit (local to body)
local function hitLocal(body, P, D, parts)
	local cf = body.CFrame
	local r = cast(parts or { body }, cf:PointToWorldSpace(P + D * 3), cf:PointToWorldSpace(P - D * 3))
	if r then return cf:PointToObjectSpace(r.Position), r.Instance end
end

-- Cross-section of a body part at one level: points on the real surface all the way round.
-- axis "Y": round a limb (angle 0 = front (-Z), 90 = the part's +X side). axis "Z": round a foot (0 = top).
local function section(body, level, n, a0, a1, axis, parts)
	axis = axis or "Y"
	local cf = body.CFrame
	local function L(u, v) if axis == "Y" then return Vector3.new(u, level, v) end return Vector3.new(u, v, level) end
	local function UV(p) if axis == "Y" then return p.X, p.Z end return p.X, p.Y end
	local function D(t) if axis == "Y" then return math.sin(t), -math.cos(t) end return math.sin(t), math.cos(t) end
	local function shoot(cu, cv, t)
		local du, dv = D(t)
		local r = cast(parts or { body }, cf:PointToWorldSpace(L(cu + du * 4, cv + dv * 4)), cf:PointToWorldSpace(L(cu - du * 4, cv - dv * 4)))
		if r then return cf:PointToObjectSpace(r.Position) end
	end
	-- pass 1: the middle of the cross-section
	local su, sv, k = 0, 0, 0
	for i = 0, 15 do
		local p = shoot(0, 0, i / 16 * math.pi * 2)
		if p then local u, v = UV(p) su += u sv += v k += 1 end
	end
	if k < 3 then return nil end
	local cu, cv = su / k, sv / k
	a0 = math.rad(a0 or 0)
	a1 = math.rad(a1 or 360)
	local closed = math.abs((a1 - a0) - math.pi * 2) < 1e-3
	local pts = {}
	for i = 0, closed and n - 1 or n do
		pts[i + 1] = shoot(cu, cv, a0 + (a1 - a0) * i / n) or false
	end
	return pts, closed, L(cu, cv)
end

-- A band of cloth round a body part between two levels, `t` thick, made of flat panels that follow
-- the surface (and its taper). opts: n, a0/a1 (arc in degrees), axis, parts (what to fit to), weldTo, gap
local function band(name, body, lo, hi, t, colour, material, opts)
	opts = opts or {}
	local n = opts.n or 16
	local A, closed, cA = section(body, lo, n, opts.a0, opts.a1, opts.axis, opts.parts)
	local Bs, _, cB = section(body, hi, n, opts.a0, opts.a1, opts.axis, opts.parts)
	local made = {}
	if not A or not Bs then table.insert(report, "band " .. name .. " missed " .. body.Name) return made end
	local mid = (cA + cB) / 2
	for i = 1, n do
		local j = closed and (i % n) + 1 or i + 1
		local a, b, c, d = A[i], A[j], Bs[i], Bs[j]
		if a and b and c and d then
			local mlo, mhi = (a + b) / 2, (c + d) / 2
			local chord = ((b - a) + (d - c)) / 2
			local upv = mhi - mlo
			local h = upv.Magnitude
			if h > 1e-3 and chord.Magnitude > 1e-3 then
				local up = upv.Unit
				local x = (chord - up * chord:Dot(up)).Unit
				local out = x:Cross(up)
				local centre = (mlo + mhi) / 2
				if out:Dot(centre - mid) < 0 then x = -x out = -out end
				local w = chord.Magnitude * 1.08 + t * 0.9
				local p = newPart(name, Vector3.new(w, h + (opts.extraH or 0), t), colour, material)
				local lcf = CFrame.fromMatrix(centre + out * (t / 2 + (opts.gap or 0.004)), x, up, out)
				table.insert(made, put(p, body.CFrame * lcf, opts.weldTo or body))
			end
		end
	end
	return made
end

-- A flat-ish frame on the body surface: centre point, outward normal, up, right (all local to body).
-- P is a local point on the line the rays travel along, D the outward direction to cast from.
local function surfaceFrame(body, P, D, w, h, upHint, parts)
	upHint = upHint or Vector3.yAxis
	local up0 = (upHint - D * upHint:Dot(D)).Unit
	local right0 = up0:Cross(D)
	local pts = {}
	for i, o in { { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		pts[i] = hitLocal(body, P + right0 * (o[1] * w / 2) + up0 * (o[2] * h / 2), D, parts) or false
	end
	local c = pts[1]
	if not c then return nil end
	local nrm = D
	if pts[2] and pts[3] and pts[4] and pts[5] then
		local nn = (pts[5] - pts[2]):Cross(pts[4] - pts[3])
		if nn.Magnitude > 1e-5 then
			nn = nn.Unit
			if nn:Dot(D) < 0 then nn = -nn end
			-- don't let a lumpy patch of surface tip the piece too far from the direction it faces
			if nn:Dot(D) > 0.6 then nrm = nn end
		end
	end
	local lift = 0
	for _, q in pts do if q then lift = math.max(lift, (q - c):Dot(nrm)) end end
	local up = (upHint - nrm * upHint:Dot(nrm)).Unit
	local right = up:Cross(nrm)
	return c + nrm * lift, nrm, up, right
end

-- a flat piece lying on the surface (pocket, patch, lace...). roll turns it about its normal (degrees).
local function patch(name, body, P, D, size, colour, material, opts)
	opts = opts or {}
	local pos, nrm, up, right = surfaceFrame(body, P, D, size.X, size.Y, opts.up, opts.parts)
	if not pos then table.insert(report, "patch " .. name .. " missed " .. body.Name) return nil end
	local p = newPart(name, size, colour, material)
	local lcf = CFrame.fromMatrix(pos + nrm * (size.Z / 2 + (opts.out or 0) - (opts.sink or 0.004)), right, up, nrm)
	if opts.roll then lcf = lcf * CFrame.Angles(0, 0, math.rad(opts.roll)) end
	return put(p, body.CFrame * lcf, opts.weldTo or body), pos, nrm, up, right
end

-- a round disc on the surface (eyes, badge, woggle): size = (diameter across, diameter up, thickness)
local function disc(name, body, P, D, size, colour, material, opts)
	opts = opts or {}
	local pos, nrm, up = surfaceFrame(body, P, D, size.X, size.Y, opts.up, opts.parts)
	if not pos then table.insert(report, "disc " .. name .. " missed " .. body.Name) return nil end
	local p = newPart(name, Vector3.new(size.Z, size.Y, size.X), colour, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Cylinder -- along X, so an oval disc lying on the surface
	m.Parent = p
	local lcf = CFrame.fromMatrix(pos + nrm * (size.Z / 2 + (opts.out or 0) - (opts.sink or 0.003)), nrm, up, nrm:Cross(up))
	return put(p, body.CFrame * lcf, opts.weldTo or body)
end

-- the height (in `ref` local Y) where looking along -D the surface stops being partA and becomes partB
local function seam(ref, partA, partB, x, z, D, yFrom, yTo)
	local step = (yTo < yFrom) and -0.01 or 0.01
	for y = yFrom, yTo, step do
		local _, inst = hitLocal(ref, Vector3.new(x, y, z), D, { partA, partB })
		if inst == partB then return y end
	end
	return nil
end

-- a point in one part's space expressed in another's
local function toLocal(from, to, p) return to.CFrame:PointToObjectSpace(from.CFrame:PointToWorldSpace(p)) end

local FRONT, BACK, UPV = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.yAxis

---------------------------------------------------------------- the outfit
local function buildTorso(P)
	local UT, LT, Head = P.UpperTorso, P.LowerTorso, P.Head
	local hy = UT.Size.Y / 2
	local kx, ky = UT.Size.X / REF.UpperTorso.X, UT.Size.Y / REF.UpperTorso.Y
	local f = (kx + ky) / 2 -- how much bigger the small details are
	-- where the shirt tucks into the shorts (front centre), and the base of the neck
	local waist = seam(UT, UT, LT, 0, 0, FRONT, -0.1 * hy, -hy - 0.4) or (-hy + 0.2)
	local neckBase = seam(UT, Head, UT, 0, 0, FRONT, hy + 0.3, hy - 0.4) or (hy - 0.1)
	table.insert(report, string.format("waist seam UT y=%.2f  neck base UT y=%.2f", waist, neckBase))

	-- belt round the waist seam, fitted over both shirt and shorts, with a brass buckle
	local beltMid = toLocal(UT, LT, Vector3.new(0, waist + 0.03, 0)).Y
	band("Belt", LT, beltMid - 0.065 * ky, beltMid + 0.065 * ky, 0.035, C.belt, "Leather", { n = 20, parts = { UT, LT } })
	patch("Buckle", LT, Vector3.new(0, beltMid, 0), FRONT, Vector3.new(0.15 * f, 0.115 * f, 0.03), C.brass, "Metal", { parts = { UT, LT }, out = 0.03 })
	patch("BuckleBar", LT, Vector3.new(0, beltMid, 0), FRONT, Vector3.new(0.02 * f, 0.1 * f, 0.02), C.belt, "Metal", { parts = { UT, LT }, out = 0.055 })

	-- neckerchief: a rolled band round the base of the neck, gathered at the front by a wooden woggle,
	-- the two ends hanging down the chest and the triangle down the back
	-- (fitted to the neck itself; at the sides it settles into the shoulders)
	local neckLo = toLocal(UT, Head, Vector3.new(0, neckBase + 0.07, 0)).Y
	band("NeckerchiefRoll", Head, neckLo, neckLo + 0.11 * ky, 0.075 * f, M(1), "Fabric", { n = 16, weldTo = UT, gap = 0.0 })
	local wogY = neckBase - 0.14 * ky
	disc("Woggle", UT, Vector3.new(0, wogY, 0), FRONT, Vector3.new(0.11 * f, 0.11 * f, 0.06), C.wood, "Wood", { out = 0.04 })
	for _, sx in { -1, 1 } do
		-- the two ends come down from the roll, through the woggle, and hang down the chest
		patch("NeckerchiefEnd", UT, Vector3.new(0.055 * sx * kx, wogY + 0.11 * ky, 0), FRONT, Vector3.new(0.075 * f, 0.25 * ky, 0.025), M(1), "Fabric", { roll = 14 * sx, out = 0.008 })
		patch("NeckerchiefTail", UT, Vector3.new(0.045 * sx * kx, wogY - 0.16 * ky, 0), FRONT, Vector3.new(0.075 * f, 0.3 * ky, 0.025), M(1), "Fabric", { roll = 10 * sx, out = 0.01 })
	end
	-- the back triangle: two wedges laid on the upper back
	do
		local W, Hh, T = 0.62 * kx, 0.46 * ky, 0.025
		local cy = neckBase + 0.05 - Hh / 2 -- top tucked up under the roll
		local pos, nrm, up, right = surfaceFrame(UT, Vector3.new(0, cy, 0), BACK, W, Hh)
		if pos then
			local top = pos + up * (Hh / 2) + nrm * (T / 2)
			for side = -1, 1, 2 do
				local R = right * side
				local w = newPart("NeckerchiefPoint", Vector3.new(T, Hh, W / 2), M(1), "Fabric", "WedgePart")
				local Y, Z = -up, R
				local X = Y:Cross(Z)
				put(w, UT.CFrame * CFrame.fromMatrix(top - up * (Hh / 2) - R * (W / 4), X, Y, Z), UT)
			end
		end
	end

	-- shirt front: collar points, two chest pockets with flaps and buttons, placket and buttons
	patch("Collar", UT, Vector3.new(-0.13 * kx, neckBase - 0.12 * ky, 0), FRONT, Vector3.new(0.12 * f, 0.2 * f, 0.025), C.shirtDark, "Fabric", { roll = 32 })
	patch("Collar", UT, Vector3.new(0.13 * kx, neckBase - 0.12 * ky, 0), FRONT, Vector3.new(0.12 * f, 0.2 * f, 0.025), C.shirtDark, "Fabric", { roll = -32 })
	for side = -1, 1, 2 do
		local x = 0.255 * side * kx
		local py = neckBase - 0.42 * ky
		patch("ChestPocket", UT, Vector3.new(x, py, 0), FRONT, Vector3.new(0.25 * f, 0.24 * f, 0.025), C.shirtDark, "Fabric")
		patch("PocketFlap", UT, Vector3.new(x, py + 0.12 * f + 0.01, 0), FRONT, Vector3.new(0.27 * f, 0.07 * f, 0.03), C.flap, "Fabric", { out = 0.012 })
		disc("PocketButton", UT, Vector3.new(x, py + 0.115 * f, 0), FRONT, Vector3.new(0.035 * f, 0.035 * f, 0.02), C.button, "SmoothPlastic", { out = 0.04 })
	end
	local plTop, plBot = wogY - 0.36 * ky, waist + 0.06
	local segs = 4
	for i = 0, segs - 1 do
		local y0 = plTop + (plBot - plTop) * i / segs
		local y1 = plTop + (plBot - plTop) * (i + 1) / segs
		patch("Placket", UT, Vector3.new(0, (y0 + y1) / 2, 0), FRONT, Vector3.new(0.065 * f, math.abs(y1 - y0) + 0.01, 0.018), C.shirtDark, "Fabric")
	end
	for i = 0, 2 do
		local y = plTop + (plBot - plTop) * (i + 0.5) / 3
		disc("ShirtButton", UT, Vector3.new(0, y, 0), FRONT, Vector3.new(0.035 * f, 0.035 * f, 0.02), C.button, "SmoothPlastic", { out = 0.016 })
	end
end

local function buildArms(P)
	for _, side in { "Left", "Right" } do
		local UA, LA, H = P[side .. "UpperArm"], P[side .. "LowerArm"], P[side .. "Hand"]
		local outX = side == "Left" and -1 or 1
		local OUT = Vector3.new(outX, 0, 0)
		local k = math.sqrt(UA.Size.X / REF.UpperArm.X) -- detail size on this arm
		-- the rolled sleeve: a thick cuff just above where the sleeve meets the forearm
		local elbow = seam(UA, UA, LA, 0, 0, OUT, 0, -UA.Size.Y / 2 - 0.3) or (-UA.Size.Y / 2 + 0.15)
		band("SleeveCuff", UA, elbow + 0.02, elbow + 0.02 + 0.15 * k, 0.05, C.shirtDark, "Fabric", { n = 12 })
		band("SleeveCuffRoll", UA, elbow + 0.1 * k, elbow + 0.14 * k, 0.065, shade(C.shirtDark, 0.9), "Fabric", { n = 12 })
		if side == "Left" then
			-- camp badge on the left sleeve, in the player's colour with a dark rim
			local py = elbow + 0.58 * UA.Size.Y / REF.UpperArm.Y
			local kp = (k + UA.Size.X / REF.UpperArm.X) / 2 -- the badge grows with the width of the sleeve
			disc("SleevePatchRim", UA, Vector3.new(0, py, 0), OUT, Vector3.new(0.21 * kp, 0.21 * kp, 0.02), M(0.45), "Fabric")
			disc("SleevePatch", UA, Vector3.new(0, py, 0), OUT, Vector3.new(0.17 * kp, 0.17 * kp, 0.02), M(1), "Fabric", { out = 0.008 })
		else
			-- the match wristband, snug round the right forearm just above the wrist
			local wrist = seam(LA, LA, H, 0, 0, OUT, 0, -LA.Size.Y / 2 - 0.3) or (-LA.Size.Y / 2 + 0.1)
			local made = band("Wristband", LA, wrist + 0.05, wrist + 0.05 + 0.12 * k, 0.035, M(1), "Fabric", { n = 12 })
			for _, p in made do p:SetAttribute("Wristband", true) end
		end
	end
end

local function buildLegs(P)
	for _, side in { "Left", "Right" } do
		local UL, LL, F = P[side .. "UpperLeg"], P[side .. "LowerLeg"], P[side .. "Foot"]
		local outX = side == "Left" and -1 or 1
		local OUT = Vector3.new(outX, 0, 0)
		local k = math.sqrt(UL.Size.X / REF.UpperLeg.X) -- detail size on this leg
		local kb = math.min(k, 1.15) -- boot and sock heights (the bulky shin is short)
		-- shorts: hem at the knee, cargo pocket and flap on the outside of the thigh
		local knee = seam(UL, UL, LL, 0, 0, FRONT, 0, -UL.Size.Y / 2 - 0.3) or (-UL.Size.Y / 2 + 0.2)
		band("ShortsHem", UL, knee + 0.02, knee + 0.02 + 0.08 * k, 0.035, C.shortsDark, "Fabric", { n = 12 })
		local pocketY = knee + 0.5 * UL.Size.Y / REF.UpperLeg.Y
		patch("CargoPocket", UL, Vector3.new(0, pocketY, 0), OUT, Vector3.new(0.3 * k, 0.3 * k, 0.03), C.shortsDark, "Fabric", { up = UPV })
		patch("CargoFlap", UL, Vector3.new(0, pocketY + 0.15 * k + 0.02, 0), OUT, Vector3.new(0.32 * k, 0.075 * k, 0.035), C.cargoFlap, "Fabric", { up = UPV, out = 0.012 })
		-- boots: shaft up the ankle with a padded collar and laces, sock showing above, sole and toe cap
		local ankle = seam(LL, LL, F, 0, 0, OUT, -LL.Size.Y / 2 + 0.5, -LL.Size.Y / 2 - 0.3) or (-LL.Size.Y / 2 + 0.15)
		local shaftTop = ankle + 0.36 * kb
		band("BootShaft", LL, math.max(ankle - 0.04, -LL.Size.Y / 2 + 0.03), shaftTop, 0.05, M(0.82), "Leather", { n = 12 })
		band("BootCollar", LL, shaftTop - 0.05 * kb, shaftTop, 0.065, M(0.6), "Leather", { n = 12 })
		band("Sock", LL, shaftTop - 0.02, shaftTop + 0.2 * kb, 0.028, C.sock, "Fabric", { n = 12 })
		band("SockStripe", LL, shaftTop + 0.11 * kb, shaftTop + 0.15 * kb, 0.036, M(1), "Fabric", { n = 12 })
		for _, y in { ankle + 0.1 * kb, ankle + 0.22 * kb } do
			for _, r in { 22, -22 } do
				patch("BootLace", LL, Vector3.new(0, y, 0), FRONT, Vector3.new(0.16 * k, 0.022 * k, 0.018), C.lace, "SmoothPlastic", { roll = r, out = 0.05 })
			end
		end
		-- foot: the boot body is the foot mesh itself (painted); add the toe cap, sole rim, sole and laces
		local fz0 = -F.Size.Z / 2
		band("ToeCap", F, fz0 + 0.05, fz0 + 0.3, 0.03, M(0.62), "Leather", { axis = "Z", n = 12 })
		local bottom
		do -- lowest point of the foot, straight down under its middle
			local hp = hitLocal(F, Vector3.new(0, 0, 0), Vector3.new(0, -1, 0))
			bottom = hp and hp.Y or -F.Size.Y / 2
		end
		band("SoleRim", F, bottom + 0.005, bottom + 0.085, 0.035, C.rubber, "Rubber", { n = 16 })
		local sole = newPart("Sole", Vector3.new(F.Size.X * 1.04, 0.05, F.Size.Z * 1.02), C.rubber, "Rubber")
		put(sole, F.CFrame * CFrame.new(0, bottom - 0.02, 0), F)
		-- laces over the top of the foot, where it sticks out in front of the shin (the blocky foot doesn't)
		if F.Size.Z > LL.Size.Z * 1.2 then
			for _, z in { fz0 + 0.42, fz0 + 0.55 } do
				patch("BootLace", F, Vector3.new(0, 0, z), UPV, Vector3.new(0.15, 0.022, 0.018), C.lace, "SmoothPlastic", { up = FRONT, out = 0.0 })
			end
		end
	end
end

-- parts made inside fn belong to one look only ("Boy" or "Girl"); CounselorLooks swaps them in game
local function variant(look, fn)
	local before = {}
	for _, c in outfit:GetChildren() do before[c] = true end
	fn()
	for _, c in outfit:GetChildren() do
		if not before[c] then c:SetAttribute("Variant", look) end
	end
end

-- one flat panel spanning four points (a,b along the top, c,d along the bottom; all local to `frame`)
local function quad(name, frame, a, b, c, d, t, colour, material, weldTo, axisPoint)
	local mlo, mhi = (c + d) / 2, (a + b) / 2
	local chord = ((b - a) + (d - c)) / 2
	local upv = mhi - mlo
	local h = upv.Magnitude
	if h < 1e-3 or chord.Magnitude < 1e-3 then return end
	local up = upv.Unit
	local x = (chord - up * chord:Dot(up)).Unit
	local out = x:Cross(up)
	local centre = (mlo + mhi) / 2
	local ref = Vector3.new(axisPoint.X, centre.Y, axisPoint.Z)
	if out:Dot(centre - ref) < 0 then x = -x out = -out end
	local p = newPart(name, Vector3.new(chord.Magnitude * 1.1 + t, h + 0.01, t), colour, material)
	return put(p, frame.CFrame * CFrame.fromMatrix(centre + out * (t / 2), x, up, out), weldTo)
end

-- Long hair: falls straight down from the back and sides of the head, then over the shoulders and
-- down the back. Short at the sides (to the shoulders), longest in the middle of the back, with
-- slightly uneven ends. The top half moves with the head, the lower half with the body.
local function longHair(P, eyeY, f)
	local Hd, UT = P.Head, P.UpperTorso
	local A0, A1, N = 78, 282, 16
	local hb = -Hd.Size.Y / 2 -- bottom of the head
	local TOP_Y, MID_Y = eyeY - 0.06 * f, hb + 0.1
	local pts, _, centre = section(Hd, TOP_Y, N, A0, A1)
	if not pts then table.insert(report, "long hair missed the head") return end
	local rng = Random.new(77)
	local cf = Hd.CFrame
	local function outward(p) local v = Vector3.new(p.X - centre.X, 0, p.Z - centre.Z) return v.Unit, v.Magnitude end
	-- how far out from the head's axis the body reaches at height y in direction d (head space)
	local function clear(y, d, parts)
		local o = Vector3.new(centre.X, y, centre.Z)
		local r = cast(parts, cf:PointToWorldSpace(o + d * 3), cf:PointToWorldSpace(o))
		if r then
			local l = cf:PointToObjectSpace(r.Position)
			return Vector2.new(l.X - centre.X, l.Z - centre.Z).Magnitude
		end
		return 0
	end
	-- top of the torso, in head space: hair that would have to spread over the shoulders stops just above them
	local shoulderY = toLocal(UT, Hd, Vector3.new(0, UT.Size.Y / 2, 0)).Y
	local top, mid, dirs = {}, {}, {}
	for i, p in pts do
		if p then
			local d, r = outward(p)
			dirs[i] = d
			top[i] = Vector3.new(centre.X, TOP_Y, centre.Z) + d * (r + 0.05)
			local rm = math.max(r + 0.05, clear(MID_Y, d, { Hd, UT }) + 0.05)
			mid[i] = Vector3.new(centre.X, MID_Y, centre.Z) + d * rm
		end
	end
	for i = 1, #pts - 1 do
		local a, b = top[i], top[i + 1]
		local c, d = mid[i], mid[i + 1]
		if a and b and c and d then
			quad("LongHair", Hd, a, b, c, d, 0.05, C.hair, "Fabric", Hd, centre)
			-- lower half: longest down the middle of the back, ending at the shoulders at the sides
			local ang = A0 + (A1 - A0) * (i - 0.5) / N
			local back = math.clamp(1 - math.abs(ang - 180) / 85, 0, 1)
			local botY = hb + 0.02 - 0.5 * f ^ 0.5 * back + rng:NextNumber(-0.05, 0.05)
			local function low(m, dir)
				local r0 = Vector2.new(m.X - centre.X, m.Z - centre.Z).Magnitude
				local c = clear(botY, dir, { UT })
				if c > r0 + 0.2 then
					-- a broad shoulder in the way: end above it instead of fanning out across it
					return Vector3.new(centre.X, math.max(shoulderY + 0.03, MID_Y - 0.06), centre.Z) + dir * (r0 + 0.04)
				end
				local r = math.max(r0 + 0.04, c + 0.05)
				return Vector3.new(centre.X, botY, centre.Z) + dir * r
			end
			quad("LongHair", Hd, c, d, low(c, dirs[i]), low(d, dirs[i + 1]), 0.05, C.hair, "Fabric", UT, centre)
		end
	end
end

local function buildHead(P)
	local Hd = P.Head
	local kx, ky, kz = Hd.Size.X / REF.Head.X, Hd.Size.Y / REF.Head.Y, Hd.Size.Z / REF.Head.Z
	local f = kx ^ 0.85 -- size of the face features (the blocky face is wide and flat: they grow with its width)
	local fx = kx ^ 0.95 -- how far apart across the face they sit
	-- the hat sits level with its brim across the forehead
	local BRIM_Y, CROWN_H = Hd.Size.Y / 2 - 0.25 * ky, 0.33 * ky
	local pts, _, centre = section(Hd, BRIM_Y, 24)
	local r = 0
	if pts then for _, q in pts do if q then r = math.max(r, Vector2.new(q.X - centre.X, q.Z - centre.Z).Magnitude) end end end
	r = math.max(r, 0.3) + 0.03 + 0.04 / kx -- just clear of the head all the way round (the corners, on the blocky one)
	local cx, cz = centre and centre.X or 0, centre and centre.Z or 0
	local vertical = CFrame.Angles(0, 0, math.pi / 2) -- cylinders run along X; stand them up
	local function cyl(name, y, height, radius, colour, mat)
		local p = newPart(name, Vector3.new(height, radius * 2, radius * 2), colour, mat or "Fabric")
		p.Shape = Enum.PartType.Cylinder
		return put(p, Hd.CFrame * CFrame.new(cx, y, cz) * vertical, Hd)
	end
	cyl("HatBrim", BRIM_Y, 0.04 * ky, r + 0.26 * math.sqrt(f), C.hatBrim)
	cyl("HatCrown", BRIM_Y + CROWN_H / 2, CROWN_H, r, C.hat)
	cyl("HatBand", BRIM_Y + 0.07 * ky, 0.12 * ky, r + 0.012, M(1))
	cyl("HatBandStripe", BRIM_Y + 0.07 * ky, 0.03 * ky, r + 0.018, M(0.6))
	do
		local top = newPart("HatTop", Vector3.new(r * 1.9, 0.22 * ky, r * 1.9), C.hat, "Fabric")
		local m = Instance.new("SpecialMesh") m.MeshType = Enum.MeshType.Sphere m.Parent = top
		put(top, Hd.CFrame * CFrame.new(cx, BRIM_Y + CROWN_H, cz), Hd)
	end

	local EYE_Y = BRIM_Y - 0.18 * f
	local ex = 0.1 * fx -- eyes: how far each sits from the middle of the face
	-- hair under the hat round the sides (both looks)
	band("Hair", Hd, EYE_Y, BRIM_Y + 0.02, 0.04, C.hair, "Fabric", { a0 = 80, a1 = 280, n = 12 })
	-- freckles (both looks)
	for _, sx in { -1, 1 } do
		for _, q in { { 0.1, -0.075 }, { 0.125, -0.09 }, { 0.15, -0.075 } } do
			disc("Freckle", Hd, Vector3.new(q[1] * fx * sx, EYE_Y + q[2] * f, 0), FRONT, Vector3.new(0.014 * f, 0.014 * f, 0.01), C.freckle, "SmoothPlastic", { sink = 0 })
		end
	end

	-- BOY: short back and sides with sideburns, round eyes, straight brows
	variant("Boy", function()
		band("Hair", Hd, EYE_Y - 0.15 * f, EYE_Y + 0.02 * f, 0.04, C.hair, "Fabric", { a0 = 132, a1 = 228, n = 8 })
		for _, sx in { -1, 1 } do
			patch("Sideburn", Hd, Vector3.new(0, EYE_Y + 0.01 * f, -0.06 * kz), Vector3.new(sx, 0, 0), Vector3.new(0.05 * f, 0.13 * f, 0.025), C.hair, "Fabric", { up = UPV })
			disc("Eye", Hd, Vector3.new(ex * sx, EYE_Y, 0), FRONT, Vector3.new(0.068 * f, 0.085 * f, 0.016), C.eye, "SmoothPlastic", { sink = 0.0 })
			disc("EyeShine", Hd, Vector3.new(ex * sx + 0.016 * f, EYE_Y + 0.02 * f, 0), FRONT, Vector3.new(0.022 * f, 0.024 * f, 0.012), C.shine, "SmoothPlastic", { out = 0.009 })
			patch("Brow", Hd, Vector3.new((ex + 0.005 * f) * sx, EYE_Y + 0.085 * f, 0), FRONT, Vector3.new(0.095 * f, 0.017 * f, 0.012), C.brow, "SmoothPlastic", { roll = -5 * sx, sink = 0 })
		end
		patch("Mouth", Hd, Vector3.new(0, EYE_Y - 0.195 * f, 0), FRONT, Vector3.new(0.1 * f, 0.02 * f, 0.014), C.mouth, "SmoothPlastic", { sink = 0, out = 0.006 })
	end)

	-- GIRL: long hair, slightly bigger eyes with lashes, thinner arched brows, rosier lips
	variant("Girl", function()
		band("Hair", Hd, EYE_Y - 0.18 * f, EYE_Y + 0.02 * f, 0.045, C.hair, "Fabric", { a0 = 96, a1 = 264, n = 12 })
		longHair(P, EYE_Y, f)
		for _, sx in { -1, 1 } do
			disc("Eye", Hd, Vector3.new(ex * sx, EYE_Y, 0), FRONT, Vector3.new(0.074 * f, 0.094 * f, 0.016), C.eye, "SmoothPlastic", { sink = 0.0 })
			disc("EyeShine", Hd, Vector3.new(ex * sx + 0.017 * f, EYE_Y + 0.022 * f, 0), FRONT, Vector3.new(0.024 * f, 0.026 * f, 0.012), C.shine, "SmoothPlastic", { out = 0.009 })
			-- lash line over the top of the eye, flicking up at the outer corner
			patch("Lash", Hd, Vector3.new((ex + 0.004 * f) * sx, EYE_Y + 0.044 * f, 0), FRONT, Vector3.new(0.08 * f, 0.013 * f, 0.012), C.eye, "SmoothPlastic", { roll = -10 * sx, sink = 0, out = 0.004 })
			patch("Lash", Hd, Vector3.new((ex + 0.046 * f) * sx, EYE_Y + 0.05 * f, 0), FRONT, Vector3.new(0.034 * f, 0.011 * f, 0.012), C.eye, "SmoothPlastic", { roll = -38 * sx, sink = 0, out = 0.004 })
			patch("Lash", Hd, Vector3.new((ex + 0.048 * f) * sx, EYE_Y + 0.033 * f, 0), FRONT, Vector3.new(0.03 * f, 0.01 * f, 0.012), C.eye, "SmoothPlastic", { roll = -16 * sx, sink = 0, out = 0.004 })
			-- brow: rises from the inside to an arch, then falls away
			patch("Brow", Hd, Vector3.new((ex - 0.02 * f) * sx, EYE_Y + 0.093 * f, 0), FRONT, Vector3.new(0.062 * f, 0.012 * f, 0.011), C.brow, "SmoothPlastic", { roll = -12 * sx, sink = 0 })
			patch("Brow", Hd, Vector3.new((ex + 0.032 * f) * sx, EYE_Y + 0.091 * f, 0), FRONT, Vector3.new(0.05 * f, 0.011 * f, 0.011), C.brow, "SmoothPlastic", { roll = 18 * sx, sink = 0 })
		end
		patch("Mouth", Hd, Vector3.new(0, EYE_Y - 0.195 * f, 0), FRONT, Vector3.new(0.085 * f, 0.022 * f, 0.014), C.lips, "SmoothPlastic", { sink = 0, out = 0.006 })
	end)
end

---------------------------------------------------------------- build
local function assemble()
	local src = KIT[BODY_SOURCE]
	local old = game.StarterPlayer:FindFirstChild("StarterCharacter") or KIT.BlockyCounselor
	char = src:Clone()
	char.Name = "StarterCharacter"
	-- humanoid + animation from the existing counselor so behaviour stays the same
	char.Humanoid:Destroy()
	local hum = (old:FindFirstChildOfClass("Humanoid") or KIT.BlockyCounselor.Humanoid):Clone()
	for _, v in hum:GetChildren() do if v:IsA("NumberValue") or v:IsA("HumanoidDescription") then v:Destroy() end end
	hum.AutomaticScalingEnabled = false -- the body is built at its final size; nothing may rescale it
	hum.Parent = char
	local animate = (old:FindFirstChild("Animate") or KIT.BlockyCounselor.Animate):Clone()
	animate.Parent = char
	-- collision / query flags per body part copied from the old counselor
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") then
			local o = KIT.BlockyCounselor:FindFirstChild(p.Name)
			if o and o:IsA("BasePart") then
				p.CanCollide = o.CanCollide p.CanQuery = o.CanQuery p.CanTouch = o.CanTouch p.Massless = o.Massless p.CastShadow = o.CastShadow
			end
			if p.Name == "HumanoidRootPart" then p.Transparency = 1 end
			p.Anchored = true
		end
	end
	for name, spec in BODY do
		local p = char:FindFirstChild(name)
		if p then
			paint(p, spec[1])
			p.Material = Enum.Material[spec[2]]
			pcall(function() p.TextureID = "" end)
		end
	end
	-- the Rthro rig's grip attachments use an old orientation (tools pointed at the sky): use the standard one
	for _, side in { "Right", "Left" } do
		local g = char[side .. "Hand"]:FindFirstChild(side .. "GripAttachment")
		if g then g.CFrame = CFrame.new(g.Position) * CFrame.Angles(-math.pi / 2, 0, 0) end
	end
	char.PrimaryPart = char.HumanoidRootPart
	char:PivotTo(BUILD_AT)
	outfit = Instance.new("Folder")
	outfit.Name = "Outfit"
	outfit.Parent = char
	welds = {}
	-- the look copies (see LOOK above)
	for _, name in LOOK do
		local real = char[name]
		local look = real:Clone()
		for _, c in look:GetChildren() do c:Destroy() end
		look.Name = "Look" .. name
		look.CanCollide = false look.CanQuery = false look.CanTouch = false look.Massless = true
		look:SetAttribute("LookOf", name)
		put(look, real.CFrame, real)
		real:SetAttribute("MatchColour", nil)
		real.Color = GROUP[name] or C.skin
		real.Material = Enum.Material.SmoothPlastic
		real.Transparency = 1
	end
	char.Parent = workspace
	-- exact mesh shapes while fitting (only recomputed once the parts are in the workspace)
	for _, p in char:GetChildren() do
		if p:IsA("MeshPart") then p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition end
	end
end

function B.Build(install)
	report = {}
	assemble()
	local P = {}
	for _, p in char:GetChildren() do if p:IsA("BasePart") then P[p.Name] = p end end
	-- the precise collision shapes are computed in the background: wait until a ray through the wrist
	-- stops hitting the thigh's bounding box (it only fits the real mesh once they're ready)
	local t0 = os.clock()
	repeat
		task.wait(0.25)
		local UL = P.LeftUpperLeg
		local hp = hitLocal(UL, Vector3.zero, FRONT)
		local ready = hp and hp.Z > -UL.Size.Z / 2 + 0.01
		-- the blocky thigh is flat in front: test a rounded corner of the head instead
		local Hd = P.Head
		local hh = hitLocal(Hd, Vector3.new(Hd.Size.X * 0.47, Hd.Size.Y * 0.47, 0), FRONT)
		ready = ready or (hh and hh.Z > -Hd.Size.Z / 2 + 0.01)
	until ready or os.clock() - t0 > 15
	table.insert(report, string.format("collision ready after %.1fs", os.clock() - t0))
	buildTorso(P)
	buildArms(P)
	buildLegs(P)
	buildHead(P)
	-- weld everything on
	local count = 0
	for p, body in welds do
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
		count += 1
	end
	-- stand on the soles: hip height from the lowest point of the boots
	local hrp = char.HumanoidRootPart
	local ground = math.huge
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") and p ~= hrp then
			local cf, s = p.CFrame, p.Size / 2
			local y = cf.Y - (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
			ground = math.min(ground, y)
		end
	end
	char.Humanoid.HipHeight = (hrp.Position.Y - hrp.Size.Y / 2) - ground
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CollisionFidelity = Enum.CollisionFidelity.Box end
	end
	char:SetAttribute("HeightScaled", 1) -- CharacterHeight: this body is already full height, don't rescale it
	-- Flashlight.Client shows the forearm (with the wristband) only on the slim body
	char:SetAttribute("Body", BODY_SOURCE == "RthroBody" and "Rthro" or "Bulky")
	table.insert(report, string.format("pieces=%d hipHeight=%.3f height=%.2f", count, char.Humanoid.HipHeight, (char.Head.Position.Y + char.Head.Size.Y / 2) - ground))
	if install == false then
		-- draft: leave it standing (anchored) where it was built, for a look
		local d = workspace:FindFirstChild("CounselorDraft")
		if d then d:Destroy() end
		char.Name = "CounselorDraft"
		return report
	end
	for _, p in char:GetDescendants() do if p:IsA("BasePart") then p.Anchored = false end end
	-- the template keeps both looks (CounselorLooks swaps them in game); the StarterCharacter starts as the boy
	local oldT = KIT:FindFirstChild("Template")
	if oldT then oldT:Destroy() end
	local tpl = char:Clone()
	tpl.Name = "Template"
	tpl.Parent = KIT
	for _, p in char.Outfit:GetChildren() do if p:GetAttribute("Variant") == "Girl" then p:Destroy() end end
	-- swap it in
	local old = game.StarterPlayer:FindFirstChild("StarterCharacter")
	if old then old:Destroy() end
	char.Parent = game.StarterPlayer
	return report
end

-- a copy of the StarterCharacter standing at `at` (CFrame), anchored, painted in `colour`, for screenshots
function B.Preview(colour, at, name, look)
	local src = KIT:FindFirstChild("Template") or game.StarterPlayer.StarterCharacter
	local m = src:Clone()
	m.Name = name or "CounselorPreview"
	look = look or "Boy"
	for _, p in m.Outfit:GetChildren() do
		local v = p:GetAttribute("Variant")
		if v and v ~= look then p:Destroy() end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
		if d:IsA("BasePart") then
			d.Anchored = true
			local s = d:GetAttribute("MatchColour")
			if s and colour then d.Color = shade(colour, s) end
		end
	end
	m:PivotTo(at)
	m.Parent = workspace
	return m
end

return B
