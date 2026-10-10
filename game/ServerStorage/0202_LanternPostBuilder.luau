-- LanternPostBuilder: the camp's lantern posts as old hanging-lantern posts: a weathered square post with a pointed top,
-- an arm out over the path held up by a diagonal brace, both rope-lashed, and the rusty hurricane lantern
-- (ServerStorage.CampfireKit.HurricaneLantern, a Creator Store mesh) hanging from an iron hook on a short chain.
--   require(game.ServerStorage.LanternPostBuilder).Build()    -- replace the posts (wayfinding posts and the two at the meeting sign)
--   require(game.ServerStorage.LanternPostBuilder).Restore()  -- put the old posts back
-- The old post, its cap and lantern are moved to ServerStorage.BeforeHangingLanternPosts, not deleted.
-- The lantern's light is tagged "LanternLight" (BaseBrightness / BaseRange) so CampfireFlicker still flickers it.
local B = {}
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local KIT = SS:WaitForChild("CampfireKit")

local HEIGHT = 8.1 -- post height above the ground
local POST = 0.46 -- post thickness
local ARM_Y = 7.45 -- arm height (its centre)
local ARM_LEN = 3.0 -- how far the arm reaches out past the post
local ARM = 0.36 -- arm thickness
local LANTERN = 2.15 -- lantern height
local WARM = Color3.fromRGB(255, 166, 70)
local WOOD = Color3.fromRGB(128, 108, 88) -- weathered grey-brown
local WOOD_DARK = Color3.fromRGB(96, 82, 70)
local ROPE = Color3.fromRGB(150, 118, 78)
local IRON = Color3.fromRGB(58, 50, 46)

local function backup()
	local f = SS:FindFirstChild("BeforeHangingLanternPosts")
	if not f then f = Instance.new("Folder") f.Name = "BeforeHangingLanternPosts" f.Parent = SS end
	return f
end
local function stash(inst)
	inst:SetAttribute("From", inst.Parent:GetFullName())
	inst.Parent = backup()
end

local model
local function part(name, size, cf, colour, material, shape)
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	p.Name = name
	if shape and shape ~= "Wedge" then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
-- a rope lashing: a few turns of rope hugging a square beam (cf's X runs along the beam)
local function lashing(cf, across, turns)
	for i = 1, turns do
		local off = (i - (turns + 1) / 2) * 0.075
		part("Lashing", Vector3.new(0.06, across + 0.05, across + 0.05), cf * CFrame.new(off, 0, 0), ROPE, Enum.Material.Fabric)
	end
end

local function ground(pos, ignore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local r = workspace:Raycast(pos + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), rp)
	return r and r.Position.Y or pos.Y
end

local function lantern()
	local m = KIT.HurricaneLantern:Clone()
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * LANTERN / size.Y)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false
			d.CastShadow = d.Name == "Body"
		end
	end
	-- the flame: a bright yellow-orange core, a little bigger than the mesh's own; the glass round it glows warm orange
	local flame, globe = m:FindFirstChild("Flame", true), m:FindFirstChild("Globe", true)
	if flame then
		flame.Material = Enum.Material.Neon
		flame.Color = Color3.fromRGB(255, 186, 64)
		flame.Size = flame.Size * 1.2
		flame.Transparency = 0
	end
	if globe then
		-- the lantern mesh paints its glass chimney into its texture (opaque, pale), so a glowing orange glass
		-- cylinder sits just over it: from outside the chimney looks lit from within
		local glass = Instance.new("Part")
		glass.Name = "GlassGlow"
		glass.Shape = Enum.PartType.Cylinder
		glass.Size = Vector3.new(globe.Size.Y * 1.15, globe.Size.X * 1.2, globe.Size.X * 1.2)
		glass.CFrame = CFrame.new(globe.Position) * CFrame.Angles(0, 0, math.pi / 2)
		glass.Material = Enum.Material.Neon
		glass.Color = Color3.fromRGB(255, 112, 24)
		glass.Transparency = 0.25
		glass.Anchored = true glass.CanCollide = false glass.CanQuery = false glass.CanTouch = false glass.CastShadow = false
		glass.Parent = m
	end
	local light = m:FindFirstChildWhichIsA("PointLight", true)
	if light then
		light.Name = "LanternLight"
		light.Color = WARM
		light.Brightness = 2.2
		light.Range = 24
		light.Shadows = false
		light:SetAttribute("BaseBrightness", light.Brightness)
		light:SetAttribute("BaseRange", light.Range)
		CS:AddTag(light, "LanternLight")
	end
	m.Name = "HurricaneLantern"
	return m
end

-- one post standing at `foot` (on the ground), its arm reaching out toward `toward`
function B.Post(foot, toward, parent, name)
	model = Instance.new("Model")
	model.Name = name or "HangingLanternPost"
	local flat = Vector3.new(toward.X - foot.X, 0, toward.Z - foot.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
	-- frame: X along the arm, Y up
	local base = CFrame.lookAt(foot, foot + dir) * CFrame.Angles(0, math.pi / 2, 0)
	local function at(x, y, z) return base * CFrame.new(x, y, z or 0) end
	-- the post, sunk a little into the ground, with a pointed top
	local sunk = 0.6
	local post = part("Post", Vector3.new(POST, HEIGHT + sunk, POST), at(0, (HEIGHT - sunk) / 2), WOOD)
	post.CanCollide = true
	post.CanQuery = true
	part("PostTop", Vector3.new(POST, 0.28, POST / 2), at(0, HEIGHT + 0.14, POST / 4) , WOOD, nil, "Wedge")
	part("PostTop", Vector3.new(POST, 0.28, POST / 2), at(0, HEIGHT + 0.14, -POST / 4) * CFrame.Angles(0, math.pi, 0), WOOD, nil, "Wedge")
	-- the arm: through the post's top, sticking out a little behind it, ending in a point over the path
	local back = 0.35
	local len = ARM_LEN + back
	part("Arm", Vector3.new(len, ARM, ARM), at(ARM_LEN / 2 - back / 2, ARM_Y), WOOD)
	part("ArmTip", Vector3.new(ARM, ARM, 0.28), at(ARM_LEN + 0.14, ARM_Y) * CFrame.Angles(0, -math.pi / 2, 0), WOOD, nil, "Wedge")
	-- the brace: from the post down below the arm up to under the arm, two thirds of the way out
	local b0 = at(POST / 2, ARM_Y - 2.0).Position
	local b1 = at(ARM_LEN * 0.62, ARM_Y - ARM / 2).Position
	local bc = CFrame.lookAt((b0 + b1) / 2, b1)
	part("Brace", Vector3.new(0.24, 0.24, (b1 - b0).Magnitude + 0.1), bc, WOOD_DARK)
	-- rope lashings where the arm crosses the post and where the brace meets each
	lashing(at(0, ARM_Y + ARM / 2 + 0.12) * CFrame.Angles(0, 0, math.pi / 2), POST, 2) -- round the post above the arm
	lashing(at(0, ARM_Y - ARM / 2 - 0.12) * CFrame.Angles(0, 0, math.pi / 2), POST, 2) -- and below it
	lashing(at(ARM_LEN * 0.62, ARM_Y), ARM, 3) -- round the arm where the brace meets it
	lashing(at(0, ARM_Y - 2.0) * CFrame.Angles(0, 0, math.pi / 2), POST, 3) -- round the post at the brace's foot
	-- the iron hook under the arm's end and a short chain down to the lantern
	local hookAt = at(ARM_LEN - 0.3, ARM_Y - ARM / 2)
	part("HookPlate", Vector3.new(0.3, 0.05, 0.22), hookAt * CFrame.new(0, -0.02, 0), IRON, Enum.Material.Metal)
	local y = ARM_Y - ARM / 2 - 0.05
	for i = 1, 3 do
		local link = part("ChainLink", Vector3.new(0.05, 0.16, 0.1), at(ARM_LEN - 0.3, y - 0.07) * CFrame.Angles(0, i % 2 == 0 and math.pi / 2 or 0, 0), IRON, Enum.Material.Metal)
		y -= 0.13
	end
	-- the lantern, hanging by its handle from the last link
	local l = lantern()
	local cf, size = l:GetBoundingBox()
	local hang = at(ARM_LEN - 0.3, y - size.Y / 2 + 0.06)
	l:PivotTo(CFrame.new(hang.Position) * (base - base.Position) * CFrame.Angles(0, 0.5, 0) * cf:ToObjectSpace(l:GetPivot()))
	l.Parent = model
	model.Parent = parent
	return model
end

local function oldPosts()
	local list = {}
	local w = workspace.SummerCampCabins:FindFirstChild("CampCabinsWayfinding")
	if w then for _, p in w:GetChildren() do if p.Name == "PathLanternPost" then table.insert(list, { post = p, toward = Vector3.new(160, 0, 0) }) end end end
	for _, p in workspace.EmergencyCampsite:GetChildren() do
		if p.Name == "LanternPost" then table.insert(list, { post = p, toward = Vector3.new(160, 0, p.Position.Z) }) end -- arms in over the sign
	end
	return list
end

function B.Build()
	local made = 0
	for _, it in oldPosts() do
		local post = it.post
		local top = post.Position + Vector3.new(0, post.Size.Y / 2, 0)
		local parent = post.Parent
		-- set aside the old post, its cap and the lantern standing on it
		for _, d in parent:GetChildren() do
			if d ~= post and (d.Name == "LanternCapBlock" or d.Name == "HurricaneLantern") then
				local p = d:IsA("Model") and d:GetBoundingBox().Position or d.Position
				if Vector2.new(p.X - top.X, p.Z - top.Z).Magnitude < 0.8 and math.abs(p.Y - top.Y) < 2.5 then stash(d) end
			end
		end
		local foot = Vector3.new(post.Position.X, 0, post.Position.Z)
		foot = Vector3.new(foot.X, ground(foot), foot.Z)
		local name = post.Name
		stash(post)
		B.Post(foot, it.toward, parent, name == "LanternPost" and "HangingLanternPost" or "HangingPathLanternPost")
		made += 1
	end
	return made
end

function B.Restore()
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and (d.Name == "HangingLanternPost" or d.Name == "HangingPathLanternPost") then d:Destroy() end
	end
	local bk = SS:FindFirstChild("BeforeHangingLanternPosts")
	if not bk then return 0 end
	local n = 0
	for _, p in bk:GetChildren() do
		local parent = game
		for seg in string.gmatch(p:GetAttribute("From") or "", "[^%.]+") do parent = parent and parent:FindFirstChild(seg) end
		if parent then p:SetAttribute("From", nil) p.Parent = parent n += 1 end
	end
	return n
end

return B
