-- ViewHands: builds the first-person hand that holds things (used by StarterPlayerScripts.FirstPersonHands).
-- The hand is a realistic closed right fist (ReplicatedStorage.ViewHandsKit.Fist, a Creator Store mesh) in your skin colour,
-- a rounded forearm, and your wristband. The held thing is copied, shrunk to suit the fist, and set in the fist in one of
-- two grips:
--   "point"   the thumb side faces forward and the item sticks out of it, pointing where you look (flashlight, key, battery)
--   "upright" the thumb side faces up and the forearm points forward, like holding a pistol or a torch (flare gun,
--             hatchet, bandage, anything carried)
-- Items arrive relative to your real (blocky) hand, the way the game holds them in third person; each grip says how
-- that hand's directions map onto the fist. A tool or carried model can fine-tune itself with attributes:
--   ViewPose ("point"/"upright"), ViewItemScale (number), ViewLift (bool),
--   ViewItemOffset (Vector3) / ViewItemTurn (Vector3 degrees): slide / turn it in the grip, in the grip's own axes:
--     X along the knuckles (the way the forearm points), Y out of the thumb side, Z out of the back of the hand;
--     offsets are in real-hand studs (scaled with the item)
--   ViewOffset (Vector3): moves the whole hand in view (right, up, forward)
local M = {}

local kit = script.Parent:WaitForChild("ViewHandsKit")
local FIST = kit:WaitForChild("Fist")
local REF = 2.4 -- the kit's fist is 2.4 studs from wrist to knuckles

M.FIST_LEN = 0.32 -- in view: studs from wrist to knuckles
M.ITEM_K = 0.36 -- held things: view studs per stud of real hand (a blocky hand is about a fist long)
-- the middle of the grip inside the fist, in the fist's own axes at REF size (measured on the mesh)
M.GRIP = Vector3.new(0.55, 0, 0.1)
-- the wrist end of the fist (centre of its flat cut) and how thick the wrist is, at REF size
M.WRIST = Vector3.new(-1.18, 0.08, -0.12)
M.WRIST_R = 0.47

-- where the grip sits in view (right, up, forward), which way the thumb side faces, which way the knuckles face,
-- and which way the forearm runs from the wrist (bent at the wrist so it always comes in from the bottom right corner)
M.POSES = {
	point = { at = Vector3.new(0.36, -0.3, -1.1), thumb = Vector3.new(-0.3, 0.12, -1), knuckles = Vector3.new(-0.2, 1, 0.25),
		arm = Vector3.new(0.42, -0.62, 0.66) },
	upright = { at = Vector3.new(0.4, -0.34, -1.12), thumb = Vector3.new(-0.1, 1, 0.12), knuckles = Vector3.new(-0.32, 0.1, -1),
		arm = Vector3.new(0.4, -0.5, 0.77) },
}
-- how your real hand's directions (from the third-person grip) land in the fist's grip frame (columns: where X, Y, Z go)
-- point:   the real hand's "forward along the arm" (-Y) comes out of the thumb side; its "up" (-Z) goes along the knuckles
-- upright: its "up" (-Z) comes out of the thumb side; its "forward" (-Y) runs along the forearm
local MAP = {
	point = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, -1, 0), Vector3.new(-1, 0, 0)),
	upright = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, -1, 0)),
}

local function prep(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

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

-- the grip frame in view: origin at the grip, Y out of the thumb side, X along the knuckles, Z the back of the hand
function M.gripFrame(pose, offset)
	local p = M.POSES[pose] or M.POSES.upright
	local gy = p.thumb.Unit
	local gx = (p.knuckles - gy * p.knuckles:Dot(gy)).Unit
	return CFrame.fromMatrix(p.at + (offset or Vector3.zero), gx, gy, gx:Cross(gy))
end

local function attr(thing, name, default)
	local v = thing and thing:GetAttribute(name)
	if v == nil then return default end
	return v
end

-- items: list of { copy = <stripped clone>, rel = <CFrame relative to your real hand> }
-- gripPoint: the real hand's grip point (its RightGripAttachment position)
-- returns the model and a table of { part = CFrame in grip-frame space }
function M.build(opts)
	local thing = opts.thing
	local pose = attr(thing, "ViewPose", opts.defaultPose or "upright")
	local vm = Instance.new("Model")
	vm.Name = "HeldViewModel"
	local offs = {}

	-- the fist
	local s = M.FIST_LEN / REF
	local fist = FIST:Clone()
	prep(fist)
	fist.Size = FIST.Size * s
	fist.Color = opts.skin or Color3.fromRGB(214, 136, 88)
	fist.Material = Enum.Material.SmoothPlastic
	fist.Name = "ViewFist"
	-- mesh axes in the grip frame: +X knuckles = gx, +Y = -gy (thumb side is -Y), +Z palm = -gz
	local meshRot = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, -Vector3.yAxis, -Vector3.zAxis)
	local fistCF = meshRot * CFrame.new(-M.GRIP * s)
	offs[fist] = fistCF
	fist.Parent = vm

	-- the forearm: from the wrist out of view toward the bottom right corner, thickening toward the elbow,
	-- with the wristband just above the wrist
	local gripCF = M.gripFrame(pose)
	local poseDef = M.POSES[pose] or M.POSES.upright
	local wristPos = fistCF * (M.WRIST * s)
	local back = gripCF:VectorToObjectSpace(poseDef.arm.Unit) -- from the wrist toward the elbow, in grip-frame space
	local r = M.WRIST_R * s
	local function limb(name, from, length, radius, colour, material)
		local c = Instance.new("Part")
		c.Name = name
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(length, radius * 2, radius * 2)
		c.Color = colour
		c.Material = material or Enum.Material.SmoothPlastic
		prep(c)
		local centre = from + back * (length / 2)
		offs[c] = CFrame.lookAt(centre, centre + back) * CFrame.Angles(0, math.pi / 2, 0) -- cylinder runs along X
		c.Parent = vm
		return c
	end
	local skin = opts.skin or Color3.fromRGB(214, 136, 88)
	-- a ball at the wrist hides the bend between the fist and the forearm
	local joint = Instance.new("Part")
	joint.Name = "ViewWrist"
	joint.Shape = Enum.PartType.Ball
	joint.Size = Vector3.one * (r * 2.02)
	joint.Color = skin
	joint.Material = Enum.Material.SmoothPlastic
	prep(joint)
	offs[joint] = CFrame.new(wristPos + back * (r * 0.15))
	joint.Parent = vm
	limb("ViewForearm", wristPos + back * (r * 0.15), 0.22, r * 1.01, skin)
	limb("ViewForearm", wristPos + back * 0.22, 0.28, r * 1.2, skin)
	limb("ViewForearm", wristPos + back * 0.48, 0.9, r * 1.4, skin)
	if opts.band then
		limb("ViewWristband", wristPos + back * (r * 0.9), r * 1.25, r * 1.1, opts.band, Enum.Material.Fabric)
	end

	-- the held thing
	local k = attr(thing, "ViewItemScale", opts.defaultScale or 1) * M.ITEM_K
	local slide = attr(thing, "ViewItemOffset", Vector3.zero)
	local t = attr(thing, "ViewItemTurn", Vector3.zero)
	local turn = CFrame.Angles(math.rad(t.X), math.rad(t.Y), math.rad(t.Z))
	local gripInv = CFrame.new(opts.gripPoint or Vector3.zero):Inverse()
	local map = MAP[pose] or MAP.upright
	local lift = attr(thing, "ViewLift", false)
	for _, it in opts.items do
		local rel = gripInv * it.rel -- relative to the real grip point, in the real hand's axes
		local c = it.copy
		resize(c, k)
		-- near-black parts (the flashlight) lightened to gunmetal so they read in the dark
		if lift and c.Transparency < 0.9 then
			local col = c.Color
			if 0.299 * col.R + 0.587 * col.G + 0.114 * col.B < 0.25 then
				pcall(function() c.UsePartColor = true end)
				c.Color = Color3.fromRGB(62, 64, 70)
			end
		end
		offs[c] = CFrame.new(slide * k) * turn * map * (CFrame.new(rel.Position * k) * (rel - rel.Position))
		c.Parent = vm
	end
	return vm, offs, M.gripFrame(pose, attr(thing, "ViewOffset", Vector3.zero))
end

return M
