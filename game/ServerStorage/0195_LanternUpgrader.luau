-- LanternUpgrader: swaps the glowing-box lanterns round the camp for a real rusty hurricane lantern
-- (ServerStorage.CampfireKit.HurricaneLantern, a Creator Store mesh).
--   require(game.ServerStorage.LanternUpgrader).Build()    -- upgrade them all
--   require(game.ServerStorage.LanternUpgrader).Restore()  -- put the old box lanterns back
-- * the lantern posts by the signs (the wayfinding posts and the two at the meeting sign): the lantern stands
--   on a little wooden cap on top of the post
-- * the cabins' hanging lanterns: the lantern hangs from the end of the existing chain
-- Every lantern light is tagged "LanternLight" (with BaseBrightness / BaseRange) so CampfireFlicker gives it a
-- gentle flame flicker on each player's machine.
local B = {}
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local KIT = SS:WaitForChild("CampfireKit")
local POST_LANTERN = 1.5 -- lantern height on a post
local HANG_LANTERN = 1.15 -- lantern height on a chain
local WARM = Color3.fromRGB(255, 160, 80)

local function backupFolder()
	local f = SS:FindFirstChild("BeforeLanternUpgrade")
	if not f then f = Instance.new("Folder") f.Name = "BeforeLanternUpgrade" f.Parent = SS end
	return f
end
-- set an old piece aside (remembering where it lived) instead of deleting it
local function stash(part)
	part:SetAttribute("From", part.Parent:GetFullName())
	part.Parent = backupFolder()
end

local function lantern(height, baseLight)
	local m = KIT.HurricaneLantern:Clone()
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * height / size.Y)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false
			d.CastShadow = d.Name == "Body"
		end
	end
	local flame, globe = m:FindFirstChild("Flame", true), m:FindFirstChild("Globe", true)
	if flame then flame.Color = Color3.fromRGB(255, 118, 36) end -- a warm wick glow, not a white bulb
	if globe then globe.Color = Color3.fromRGB(255, 132, 60) globe.Transparency = 0.5 end
	local light = m:FindFirstChildWhichIsA("PointLight", true)
	if light then
		light.Name = "LanternLight"
		light.Color = WARM
		light.Brightness = math.max(baseLight and baseLight.Brightness or 0, 0.9)
		light.Range = math.max(baseLight and baseLight.Range or 0, 14)
		light.Shadows = false
		light:SetAttribute("BaseBrightness", light.Brightness)
		light:SetAttribute("BaseRange", light.Range)
		CS:AddTag(light, "LanternLight")
	end
	m.Name = "HurricaneLantern"
	return m
end

-- a lantern standing on a post, on a little wooden cap
local function onPost(post, oldLight)
	local top = post.CFrame * CFrame.new(0, post.Size.Y / 2, 0)
	local cap = Instance.new("Part")
	cap.Name = "LanternCapBlock"
	cap.Size = Vector3.new(0.5, 0.1, 0.5)
	cap.CFrame = top * CFrame.new(0, 0.05, 0)
	cap.Material = Enum.Material.Wood cap.Color = Color3.fromRGB(70, 46, 32)
	cap.Anchored = true cap.CanCollide = false cap.CanQuery = false cap.CanTouch = false
	cap.Parent = post.Parent
	local m = lantern(POST_LANTERN, oldLight)
	local cf, size = m:GetBoundingBox()
	local yaw = select(2, post.CFrame:ToEulerAnglesYXZ())
	m:PivotTo(CFrame.new(top.Position) * CFrame.Angles(0, yaw + 0.4, 0) * (cf:ToObjectSpace(m:GetPivot())) + Vector3.new(0, 0.1 + size.Y / 2, 0))
	m.Parent = post.Parent
	return m
end

-- a lantern hanging by its handle from the bottom of a chain
local function onChain(chain, oldLight, parent)
	local bottom = chain.Position - Vector3.new(0, chain.Size.Y / 2, 0)
	local m = lantern(HANG_LANTERN, oldLight)
	local cf, size = m:GetBoundingBox()
	local yaw = select(2, chain.CFrame:ToEulerAnglesYXZ())
	m:PivotTo(CFrame.new(bottom) * CFrame.Angles(0, yaw, 0) * (cf:ToObjectSpace(m:GetPivot())) - Vector3.new(0, size.Y / 2 - 0.22, 0)) -- the handle's ring hooks over the chain's end
	m.Parent = parent
	return m
end

local BOX = { LanternGlass = true, LanternBase = true, LanternCap = true, LanternFrame = true }
local CAGE = { LanternCage = true, LanternCap = true, LanternBase = true, WarmGlass = true }

function B.Build()
	-- building again starts from the original lanterns
	if #CS:GetTagged("LanternLight") > 0 then B.Restore() end
	local made = 0
	-- posts: the wayfinding posts and the two at the meeting sign
	local posts = {}
	for _, p in workspace.SummerCampCabins.CampCabinsWayfinding:GetChildren() do if p.Name == "PathLanternPost" then table.insert(posts, p) end end
	for _, p in workspace.EmergencyCampsite:GetChildren() do if p.Name == "LanternPost" then table.insert(posts, p) end end
	for _, post in posts do
		local top = post.Position + Vector3.new(0, post.Size.Y / 2, 0)
		local oldLight
		for _, p in post.Parent:GetChildren() do
			if p:IsA("BasePart") and BOX[p.Name] and (Vector2.new(p.Position.X, p.Position.Z) - Vector2.new(top.X, top.Z)).Magnitude < 0.6 and math.abs(p.Position.Y - top.Y) < 1.5 then
				oldLight = oldLight or p:FindFirstChildWhichIsA("PointLight")
				stash(p)
			end
		end
		onPost(post, oldLight)
		made += 1
	end
	-- the cabins' hanging lanterns
	for _, cabin in workspace.SummerCampCabins:GetChildren() do
		local ls = cabin:FindFirstChild("LightingAndSigns")
		if ls then
			for _, group in ls:GetChildren() do
				local chain = group:IsA("Model") and group:FindFirstChild("LanternChain")
				if chain and not group:FindFirstChild("HurricaneLantern") then
					local oldLight
					for _, p in group:GetChildren() do
						if p:IsA("BasePart") and CAGE[p.Name] then
							oldLight = oldLight or p:FindFirstChildWhichIsA("PointLight")
							stash(p)
						end
					end
					onChain(chain, oldLight, group)
					made += 1
				end
			end
		end
	end
	return made
end

function B.Restore()
	for _, l in CS:GetTagged("LanternLight") do
		local m = l:FindFirstAncestor("HurricaneLantern")
		if m then m:Destroy() end
	end
	for _, d in workspace:GetDescendants() do if d.Name == "LanternCapBlock" then d:Destroy() end end
	local bk = SS:FindFirstChild("BeforeLanternUpgrade")
	if not bk then return 0 end
	local n = 0
	for _, p in bk:GetChildren() do
		local from = p:GetAttribute("From")
		local parent = game
		for seg in string.gmatch(from or "", "[^%.]+") do parent = parent and parent:FindFirstChild(seg) end
		if parent then p:SetAttribute("From", nil) p.Parent = parent n += 1 end
	end
	return n
end

return B
