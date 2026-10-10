-- ViewHands: builds the first-person arm that holds things (used by StarterPlayerScripts.FirstPersonHands).
-- It is YOUR counselor's own right arm: copies of your upper arm, forearm and hand with everything your outfit puts on
-- them (shirt sleeve, rolled cuff, wristband...), scaled down and held up in the bottom right of your view the way the
-- game holds tools in third person. The held thing is copied at the same scale and sits in the hand exactly as it does
-- in third person (its tool Grip, or how it's welded to the hand), so it reads like your character holding it.
-- A tool or carried model can fine-tune itself with attributes (all in the hand's own axes: X to the right of the hand,
-- Y back along the arm, Z out of the back; so -Y pushes the item further out of the fist):
--   ViewItemScale (number), ViewItemOffset (Vector3, real-size studs), ViewItemTurn (Vector3, degrees about the grip),
--   ViewOffset (Vector3, moves the whole arm in view: right, up, forward), ViewLift (bool, lightens near-black parts)
local M = {}

-- The pose (all in view space: x right, y up, -z forward; studs from the camera). The arm bends at the wrist and the
-- elbow like a real arm holding something out: the hand points what it holds forward, the forearm runs back across the
-- bottom right of the screen so the whole of it (and the wristband) is in view, and the upper arm leaves the screen at
-- the bottom right corner.
M.SCALE = 0.31 -- the arm's size in view against your real arm
-- the blocky forearm and upper arm are barely longer than they are thick, which reads as a box this close to the
-- camera; in view they're drawn a bit longer and slimmer (LONG along the arm, THIN across it) so they read as an arm
M.LONG = 1.05
M.THIN = 0.88
M.HAND_AT = Vector3.new(0.5, -0.36, -1.25) -- where your hand sits: down in the bottom right corner
M.AIM = Vector3.new(-0.2, 0.1, -1) -- the way the hand points: nearly straight ahead, so what it holds stays in the corner
M.FOREARM = Vector3.new(-0.45, 0.34, -0.83) -- the way the forearm runs, elbow to wrist: in from the bottom right corner
M.UPPER = Vector3.new(-0.28, 0.45, -0.85) -- the way the upper arm runs, shoulder to elbow
M.UP = Vector3.new(0.06, 1, 0.1) -- roughly where the top of the hand faces
-- any of these can be overridden with attributes on this ModuleScript (Scale, HandAt, Aim, Forearm, Upper, Up)
local function tuned()
	local s = script:GetAttribute("Scale")
	if typeof(s) == "number" then M.SCALE = s end
	for _, n in { "Long", "Thin" } do
		local v = script:GetAttribute(n)
		if typeof(v) == "number" then M[n:upper()] = v end
	end
	for key, name in { HAND_AT = "HandAt", AIM = "Aim", FOREARM = "Forearm", UPPER = "Upper", UP = "Up" } do
		local v = script:GetAttribute(name)
		if typeof(v) == "Vector3" then M[key] = v end
	end
end
-- a frame whose +Y runs `back` (toward the shoulder) with its -Z as close to `up` as it can be
local function limbFrame(back, up)
	local y = back.Unit
	local top = (up - y * up:Dot(y))
	if top.Magnitude < 1e-3 then top = Vector3.zAxis end
	local z = -top.Unit
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
end
-- where a joint sits in each of its two parts: the R15 rig attachments if present, else the Motor6D
local function jointPoints(part0, part1, attName, motorName)
	local a0, a1 = part0:FindFirstChild(attName), part1:FindFirstChild(attName)
	if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then return a0.Position, a1.Position end
	local m = part1:FindFirstChild(motorName)
	if m and m:IsA("Motor6D") then return m.C0.Position, m.C1.Position end
	return nil
end

local function prep(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

local function strip(c)
	for _, d in c:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") or d:IsA("NoCollisionConstraint")
			or d:IsA("LuaSourceContainer") or d:IsA("Light") or d:IsA("Beam") or d:IsA("Sound") or d:IsA("TouchTransmitter")
			or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter")
			or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("BasePart")
			or d:IsA("WrapTarget") or d:IsA("WrapLayer") or d:IsA("Attachment") or d:IsA("ValueBase") then
			d:Destroy()
		end
	end
end

local function copy(p)
	local ok, c = pcall(function() return p:Clone() end)
	if not ok or not c then return nil end
	strip(c)
	prep(c)
	return c
end
M.copy = copy

local function resize(c, k)
	c.Size = c.Size * k
	for _, m in c:GetChildren() do
		if m:IsA("SpecialMesh") then
			if m.MeshType == Enum.MeshType.FileMesh then m.Scale = m.Scale * k end
			m.Offset = m.Offset * k
		elseif m:IsA("DataModelMesh") then
			m.Offset = m.Offset * k
		elseif m:IsA("Texture") then
			m.StudsPerTileU *= k
			m.StudsPerTileV *= k
			m.OffsetStudsU *= k
			m.OffsetStudsV *= k
		end
	end
end

-- resize a copy by a different factor along each of its own axes
local function resize3(c, f)
	c.Size = Vector3.new(c.Size.X * f.X, c.Size.Y * f.Y, c.Size.Z * f.Z)
	for _, m in c:GetChildren() do
		if m:IsA("SpecialMesh") then
			if m.MeshType == Enum.MeshType.FileMesh then m.Scale = Vector3.new(m.Scale.X * f.X, m.Scale.Y * f.Y, m.Scale.Z * f.Z) end
			m.Offset = Vector3.new(m.Offset.X * f.X, m.Offset.Y * f.Y, m.Offset.Z * f.Z)
		end
	end
end
-- how much a piece sitting on a stretched limb grows along each of its own axes (r: the piece relative to the limb)
local function axisStretch(r, st)
	local function f(ax) return Vector3.new(ax.X * st.X, ax.Y * st.Y, ax.Z * st.Z).Magnitude end
	return Vector3.new(f(r.RightVector), f(r.UpVector), f(r.LookVector))
end

local function attr(thing, name, default)
	local v = thing and thing:GetAttribute(name)
	if v == nil then return default end
	return v
end

-- the body part an outfit piece is welded to
local function weldedTo(d)
	for _, w in d:GetChildren() do
		if w:IsA("WeldConstraint") or w:IsA("JointInstance") then
			if w.Part0 == d then return w.Part1 end
			if w.Part1 == d then return w.Part0 end
		end
	end
end

-- where your hand sits in view (camera space), as a CFrame for the hand part: its -Y points where it aims (that's
-- how a tool held in third person points along the raised arm) and its -Z faces up
function M.handFrame(offset)
	return CFrame.new(M.HAND_AT + (offset or Vector3.zero)) * limbFrame(-M.AIM, M.UP)
end

-- opts: char, hand, thing, items = { { copy, rel } } (rel: CFrame relative to the real hand), gripPoint (hand space),
-- defaultScale, band (unused; your outfit's own wristband is copied)
-- returns the model, { part = CFrame relative to the hand frame }, and the hand frame in camera space
function M.build(opts)
	tuned()
	local char, hand, thing = opts.char, opts.hand, opts.thing
	local vm = Instance.new("Model")
	vm.Name = "HeldViewModel"
	local offs = {}
	local S = M.SCALE

	-- your arm, bent at the wrist and elbow, relative to your hand (the forearm and upper arm drawn LONG and THIN)
	local handCF = M.handFrame(attr(thing, "ViewOffset", Vector3.zero))
	local limbs = { [hand] = CFrame.new() }
	local stretch = { [hand] = Vector3.one * S }
	local lower = char:FindFirstChild("RightLowerArm")
	local upper = char:FindFirstChild("RightUpperArm")
	local up = handCF:VectorToWorldSpace(-Vector3.zAxis)
	local armSt = Vector3.new(M.THIN, M.LONG, M.THIN) * S
	local function sv(p, st) return Vector3.new(p.X * st.X, p.Y * st.Y, p.Z * st.Z) end
	if lower then
		local wInLower, wInHand = jointPoints(lower, hand, "RightWristRigAttachment", "RightWrist")
		if wInLower then
			local wristPt = handCF * (wInHand * S)
			local rot = limbFrame(-M.FOREARM, up)
			local lowerCF = CFrame.new(wristPt - rot * sv(wInLower, armSt)) * rot
			limbs[lower] = handCF:ToObjectSpace(lowerCF)
			stretch[lower] = armSt
			if upper then
				local eInUpper, eInLower = jointPoints(upper, lower, "RightElbowRigAttachment", "RightElbow")
				if eInUpper then
					local elbowPt = lowerCF * sv(eInLower, armSt)
					local urot = limbFrame(-M.UPPER, up)
					limbs[upper] = handCF:ToObjectSpace(CFrame.new(elbowPt - urot * sv(eInUpper, armSt)) * urot)
					stretch[upper] = armSt
				end
			end
		end
	end
	for part, rel in limbs do
		local c = copy(part)
		if c then
			for _, d in c:GetChildren() do
				if not (d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("DataModelMesh")) then d:Destroy() end
			end
			c.Transparency = 0
			c.Name = "View" .. part.Name
			resize3(c, stretch[part])
			offs[c] = rel
			c.Parent = vm
		end
	end
	-- what your outfit puts on them. The wristband is a ring of 12 small plates on your real arm; drawn this close and
	-- this small they showed as separate red patches, so the view arm gets one solid band in its place instead
	local outfit = char:FindFirstChild("Outfit")
	local bandParts = {}
	if outfit then
		for _, d in outfit:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "Wristband" or d:GetAttribute("Wristband")) and lower and weldedTo(d) == lower then
				table.insert(bandParts, d)
			end
		end
	end
	if #bandParts > 0 and limbs[lower] then
		local sumY, h, colour = 0, 0, bandParts[1].Color
		for _, d in bandParts do
			sumY += lower.CFrame:PointToObjectSpace(d.Position).Y
			h = math.max(h, d.Size.Y)
		end
		local st = stretch[lower]
		local pad = 0.07 -- how far the band stands proud of the arm (real studs)
		local function ring(name, y, height, grow, col, mat)
			local b = Instance.new("Part")
			b.Name = name
			b.Size = Vector3.new((lower.Size.X + grow) * st.X, height * st.Y, (lower.Size.Z + grow) * st.Z)
			b.Color = col
			b.Material = mat
			prep(b)
			offs[b] = limbs[lower] * CFrame.new(0, y * st.Y, 0)
			b.Parent = vm
		end
		local y = sumY / #bandParts
		ring("ViewWristband", y, h * 1.1, pad, colour, Enum.Material.Fabric)
		-- a thin darker line round each edge, the stitching of a cloth band
		local edge = colour:Lerp(Color3.new(0, 0, 0), 0.35)
		ring("ViewWristbandEdge", y + h * 0.5, 0.025, pad + 0.012, edge, Enum.Material.Fabric)
		ring("ViewWristbandEdge", y - h * 0.5, 0.025, pad + 0.012, edge, Enum.Material.Fabric)
	end
	if outfit then
		for _, d in outfit:GetChildren() do
			if d:IsA("BasePart") and d.Transparency < 1 and not table.find(bandParts, d) then
				local on = weldedTo(d)
				local rel = on and limbs[on]
				if rel then
					local c = copy(d)
					if c then
						local r = on.CFrame:ToObjectSpace(d.CFrame)
						local st = stretch[on]
						resize3(c, axisStretch(r, st))
						offs[c] = rel * CFrame.new(sv(r.Position, st)) * (r - r.Position)
						c.Parent = vm
					end
				end
			end
		end
	end

	-- the held thing, at the same scale, around your grip
	local k = attr(thing, "ViewItemScale", opts.defaultScale or 1)
	local slide = attr(thing, "ViewItemOffset", Vector3.zero)
	local t = attr(thing, "ViewItemTurn", Vector3.zero)
	local g = opts.gripPoint or Vector3.new(0, -hand.Size.Y / 2, 0)
	local turn = CFrame.new(g) * CFrame.Angles(math.rad(t.X), math.rad(t.Y), math.rad(t.Z)) * CFrame.new(-g)
	local lift = attr(thing, "ViewLift", false)
	for _, it in opts.items do
		local rel = CFrame.new(slide) * turn * it.rel
		local c = it.copy
		if lift and c.Transparency < 0.9 then
			local col = c.Color
			if 0.299 * col.R + 0.587 * col.G + 0.114 * col.B < 0.25 then
				pcall(function() c.UsePartColor = true end)
				c.Color = Color3.fromRGB(62, 64, 70)
			end
		end
		resize(c, S * k)
		local pos = (g + (rel.Position - g) * k) * S
		offs[c] = CFrame.new(pos) * (rel - rel.Position)
		c.Parent = vm
	end
	return vm, offs, handCF
end

return M
