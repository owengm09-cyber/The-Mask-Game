-- ArrowSignBuilder: the direction signs as old wooden signposts: a round post with arrow-shaped planks nailed across it,
-- each plank pointing at the real place it names (its bearing is worked out from where that place is in the map).
--   require(game.ServerStorage.ArrowSignBuilder).Build()    -- replace the direction signs
--   require(game.ServerStorage.ArrowSignBuilder).Restore()  -- put the old signs back
-- Old signs are moved to ServerStorage.BeforeArrowSigns, not deleted. Edit SIGNS below to change names or targets.
local B = {}
local SS = game:GetService("ServerStorage")

local POST_H = 6.5 -- post height above the ground
local POST_D = 0.44
local PLANK_H = 0.74
local PLANK_T = 0.14
local ROWS = { 5.55, 4.75, 3.95 } -- plank heights above the ground, top first
local POST_WOOD = Color3.fromRGB(116, 90, 66)
local PLANK_WOOD = { Color3.fromRGB(178, 140, 98), Color3.fromRGB(166, 128, 88), Color3.fromRGB(184, 148, 106) }
local INK = Color3.fromRGB(56, 36, 22)
local NAIL = Color3.fromRGB(46, 40, 36)

local CAMP = Vector3.new(160, 0, 0) -- the campfire
local function centre(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	local sum, n = Vector3.zero, 0
	for _, d in inst:GetDescendants() do if d:IsA("BasePart") then sum += d.Position n += 1 end end
	return n > 0 and sum / n or nil
end
local function cabin(name) return centre(workspace.SummerCampCabins:FindFirstChild(name)) end
local function site(name) return centre(workspace.Forest.RescueSites:FindFirstChild(name)) end

-- every signpost: where it stands (a point, or an old sign to stand in place of), and its arrows { text, target }
-- the first of a few spots near `p` (starting with p itself) where nothing solid but the ground is within reach of the planks
local function clearSpot(p, y, toward, ignore)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ignore
	op.RespectCanCollide = true
	local d = Vector3.new(toward.X - p.X, 0, toward.Z - p.Z).Unit
	local side = Vector3.yAxis:Cross(d)
	for _, off in { Vector3.zero, d * 2.5, d * 4, side * 2.5, -side * 2.5, d * 6, d * 2.5 + side * 2.5, d * 2.5 - side * 2.5 } do
		local c = p + off
		local hits = workspace:GetPartBoundsInBox(CFrame.new(c.X, y + 4.6, c.Z), Vector3.new(6, 2.6, 6), op)
		local solid = false
		for _, h in hits do if not h:IsA("Terrain") then solid = true break end end
		if not solid then return c end
	end
	return p
end
local function signs()
	local list = {}
	local w = workspace.SummerCampCabins:FindFirstChild("CampCabinsWayfinding")
	local function nearCamp(x, z) -- 2.5 studs behind a lantern post (away from its arm, which reaches toward the fire)
		local p = Vector3.new(x, 0, z)
		local d = (Vector3.new(CAMP.X, 0, CAMP.Z) - p).Unit
		return p - d * 2.5
	end
	table.insert(list, { at = nearCamp(122, 5), arrows = {
		{ "01  CEDAR", cabin("Cabin01_CEDAR") }, { "02  BIRCH", cabin("Cabin02_BIRCH") }, { "03  PINE", cabin("Cabin03_PINE") } } })
	table.insert(list, { at = nearCamp(198, 5), arrows = {
		{ "04  ASH", cabin("Cabin04_ASH") }, { "OLD CEMETERY", centre(workspace:FindFirstChild("Graveyard")) }, { "CAMPFIRE", CAMP } } })
	table.insert(list, { at = nearCamp(137, -6), arrows = {
		{ "05  WILLOW", cabin("Cabin05_WILLOW") }, { "06  HOLLOW", cabin("Cabin06_HOLLOW") }, { "RADIO TOWER", Vector3.new(-38.5, 0, -3.1) } } })
	if w then for _, p in w:GetChildren() do if p.Name == "CampCabinsSignpost" then table.insert(list, { replaces = { p } }) end end end
	-- the forest trail signs
	local t = workspace.ForestExpedition:FindFirstChild("TrailAndGroundDetail")
	if t then
		for _, d in t:GetChildren() do
			if d.Name == "TrailDirection" then
				local post
				for _, q in t:GetChildren() do
					if q.Name == "TrailSignPost" and (Vector2.new(q.Position.X, q.Position.Z) - Vector2.new(d.Position.X, d.Position.Z)).Magnitude < 1 then post = q end
				end
				local text = ""
				for _, g in d:GetDescendants() do if g:IsA("TextLabel") then text = text .. g.Text end end
				local arrows
				if text:upper():find("OLD CABIN") then
					arrows = { { "OLD CABIN", centre(workspace.ForestExpedition:FindFirstChild("AbandonedForestCabin")) }, { "CAMP", CAMP }, { "RADIO TOWER", Vector3.new(-38.5, 0, -3.1) } }
				else
					arrows = { { "ALDER RIDGE LOOKOUT", centre(workspace.ForestExpedition:FindFirstChild("AlderRidge_Lookout")) }, { "PUMP HOUSE", site("PUMP") }, { "CAMP", CAMP } }
				end
				table.insert(list, { at = Vector3.new(d.Position.X, 0, d.Position.Z), from = d.Position.Y + 1, replaces = { d, post }, arrows = arrows })
			end
		end
	end
	-- the "RESCUE ->" markers at the rescue sites: the site's name pointing in, CAMP pointing home
	for _, s in workspace.Forest.RescueSites:GetChildren() do
		local m = s:FindFirstChild("TrailMarker")
		if m then
			local post = s:FindFirstChild("TrailPost")
			local name = s.Name
			local ls = s:FindFirstChild("LocationSign")
			if ls then for _, g in ls:GetDescendants() do if g:IsA("TextLabel") and #g.Text > 0 then name = g.Text break end end end
			table.insert(list, { at = clearSpot(Vector3.new(m.Position.X, 0, m.Position.Z), (post and post.Position.Y - post.Size.Y / 2) or (m.Position.Y - 3), CAMP, { m, post }), from = m.Position.Y + 1, replaces = { m, post }, arrows = { { name, centre(s) }, { "CAMP", CAMP } } })
		end
	end
	return list
end

local function backup()
	local f = SS:FindFirstChild("BeforeArrowSigns")
	if not f then f = Instance.new("Folder") f.Name = "BeforeArrowSigns" f.Parent = SS end
	return f
end
local function stash(inst)
	if not inst or not inst.Parent or inst:IsDescendantOf(SS) then return end
	inst:SetAttribute("From", inst.Parent:GetFullName())
	inst.Parent = backup()
end

local model
local function part(name, size, cf, colour, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
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

local function ground(p, ignore, from)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	rp.RespectCanCollide = true
	local r = workspace:Raycast(Vector3.new(p.X, from or 14, p.Z), Vector3.new(0, -60, 0), rp)
	return r and r.Position.Y or p.Y
end

local function label(plank, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 90
	gui.LightInfluence = 1
	gui.Parent = plank
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.52)
	t.Size = UDim2.new(1, -24, 0.62, 0)
	t.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
	t.TextScaled = true
	t.TextColor3 = INK
	t.TextTransparency = 0.08
	t.Text = text
	t.Parent = gui
end

-- one signpost at `foot` (on the ground) with arrows = { { text, target }, ... } (top plank first)
function B.Post(foot, arrows, parent)
	model = Instance.new("Model")
	model.Name = "ArrowSignpost"
	local sunk = 0.7
	local post = part("Post", Vector3.new(POST_H + sunk, POST_D, POST_D), CFrame.new(foot + Vector3.new(0, (POST_H - sunk) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), POST_WOOD, nil, Enum.PartType.Cylinder)
	post.CanCollide = true
	post.CanQuery = true
	part("PostCap", Vector3.new(0.12, POST_D * 0.96, POST_D * 0.96), CFrame.new(foot + Vector3.new(0, POST_H + 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(96, 74, 54), nil, Enum.PartType.Cylinder)
	for i, a in arrows do
		local text, target = a[1], a[2]
		if target and ROWS[i] then
			local flat = Vector3.new(target.X - foot.X, 0, target.Z - foot.Z)
			local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.xAxis
			local L = math.clamp(1.5 + 0.2 * #text, 2.9, 5.0)
			local y = foot.Y + ROWS[i]
			-- the post goes through the plank 0.75 from its back end; planks sit just in front of / behind the post
			local side = (i % 2 == 0) and -1 or 1
			local across = Vector3.yAxis:Cross(dir) * side * (POST_D / 2 + PLANK_T / 2)
			local c = Vector3.new(foot.X, y, foot.Z) + dir * (L / 2 - 0.75) + across
			local cf = CFrame.fromMatrix(c, dir, Vector3.yAxis)
			local wood = PLANK_WOOD[(i - 1) % #PLANK_WOOD + 1]
			-- a slight droop, like boards that have been up a while
			cf = cf * CFrame.Angles(0, 0, math.rad(((i * 37) % 5 - 2) * 0.8))
			local plank = part("ArrowPlank", Vector3.new(L, PLANK_H, PLANK_T), cf, wood)
			plank:SetAttribute("Points", text)
			-- the arrow's point: a square turned 45 degrees, half of it past the end of the plank
			local s = PLANK_H / math.sqrt(2)
			part("ArrowTip", Vector3.new(s, s, PLANK_T), cf * CFrame.new(L / 2, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), wood)
			label(plank, Enum.NormalId.Front, text)
			label(plank, Enum.NormalId.Back, text)
			-- nails where it's fixed to the post, both sides
			local np = cf * CFrame.new(-(L / 2 - 0.75), 0, 0)
			for _, z in { -1, 1 } do
				for _, ny in { 0.17, -0.17 } do
					part("Nail", Vector3.new(0.02, 0.06, 0.06), np * CFrame.new(0, ny, z * (PLANK_T / 2 + 0.005)) * CFrame.Angles(0, math.pi / 2, 0), NAIL, Enum.Material.Metal, Enum.PartType.Cylinder)
				end
			end
		end
	end
	model.Parent = parent
	return model
end

function B.Build()
	B.Restore()
	local out = Instance.new("Folder")
	out.Name = "ArrowSigns"
	out.Parent = workspace
	local made = 0
	for _, s in signs() do
		for _, old in s.replaces or {} do stash(old) end
		if s.at and s.arrows then
			local y = ground(s.at, { out, workspace.SummerCampCabins:FindFirstChild("CampCabinsWayfinding") }, s.from)
			B.Post(Vector3.new(s.at.X, y, s.at.Z), s.arrows, out)
			made += 1
		end
	end
	return made
end

function B.Restore()
	local f = workspace:FindFirstChild("ArrowSigns") if f then f:Destroy() end
	local bk = SS:FindFirstChild("BeforeArrowSigns")
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
