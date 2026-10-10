-- Wristbands: every player wears one flat coloured band snug around the RIGHT wrist.
-- * Colours are unique within each ready ring and the round it becomes, so the 11 players in a
--   match can always be told apart. Everyone also gets a colour on joining (all different while
--   the server has 11 or fewer players), and keeps it between rings whenever it's free.
-- * The band vanishes while its wearer is in creature form (a "MaskCreature" model in the
--   character), so it can never reveal who the monster is.
-- * Other scripts can read a player's colour: player:GetAttribute("BandName") / ("BandColor").
-- * The counselor outfit (StarterCharacter.Outfit) wears the colour too: every part with a
--   "MatchColour" attribute (hat band, neckerchief, boots, sleeve badge, sock stripes, wristband) is
--   painted in it, the attribute being a shade (1 = exact colour, lower = darker). When the outfit has
--   its own fitted wristband (parts with the "Wristband" attribute) the plain box band isn't added.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local COLOURS = {
	{ "Red",    Color3.fromRGB(235, 40, 40) },
	{ "Blue",   Color3.fromRGB(40, 95, 255) },
	{ "Green",  Color3.fromRGB(30, 185, 70) },
	{ "Yellow", Color3.fromRGB(255, 225, 40) },
	{ "Orange", Color3.fromRGB(255, 135, 20) },
	{ "Purple", Color3.fromRGB(145, 55, 225) },
	{ "Pink",   Color3.fromRGB(255, 105, 190) },
	{ "Cyan",   Color3.fromRGB(35, 225, 225) },
	{ "White",  Color3.fromRGB(240, 240, 240) },
	{ "Lime",   Color3.fromRGB(165, 255, 60) },
	{ "Brown",  Color3.fromRGB(140, 85, 45) },
}

local groupSince, lastGroup = {}, {}

local function colourIndex(p) return p:GetAttribute("BandIndex") end
local function setColour(p, i)
	p:SetAttribute("BandIndex", i)
	p:SetAttribute("BandName", COLOURS[i][1])
	p:SetAttribute("BandColor", COLOURS[i][2])
end
local function groupKey(p)
	if p:GetAttribute("InRound") then return "Round" .. tostring(p:GetAttribute("RoundId")) end
	local z = p:GetAttribute("ReadyZone")
	if z then return "Zone" .. z end
	return nil
end
-- the colour worn by the fewest players, skipping any in `exclude`
local function leastUsed(exclude)
	local count = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local i = colourIndex(p)
		if i then count[i] = (count[i] or 0) + 1 end
	end
	local best, bestN
	for i = 1, #COLOURS do
		if not (exclude and exclude[i]) then
			local n = count[i] or 0
			if not bestN or n < bestN then best, bestN = i, n end
		end
	end
	return best
end

local function assign()
	local now = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		if not colourIndex(p) then setColour(p, leastUsed(nil)) end
		local k = groupKey(p)
		if k ~= lastGroup[p] then lastGroup[p] = k; groupSince[p] = now end
	end
	local groups = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local k = lastGroup[p]
		if k then groups[k] = groups[k] or {}; table.insert(groups[k], p) end
	end
	for _, members in pairs(groups) do
		-- whoever has been in the group longest keeps their colour; later arrivals change on a clash
		table.sort(members, function(a, b)
			if groupSince[a] ~= groupSince[b] then return (groupSince[a] or 0) < (groupSince[b] or 0) end
			return a.UserId < b.UserId
		end)
		local taken = {}
		for _, p in ipairs(members) do
			local i = colourIndex(p)
			if taken[i] then
				-- go back to the colour this player picked if it's free here, else the least used one
				local pref = p:GetAttribute("PreferredBand")
				local new = (pref and COLOURS[pref] and not taken[pref]) and pref or leastUsed(taken)
				if new then setColour(p, new); i = new end
			end
			taken[i] = true
		end
	end
end

local function makeBand(arm, colour, isR15)
	-- a thin fabric band that hugs the forearm just above the wrist (no glow: it's hard to read in the dark)
	local band = Instance.new("Part")
	band.Name = "Wristband"
	band.Material = Enum.Material.Fabric
	band.Color = colour
	band.CanCollide = false; band.CanQuery = false; band.CanTouch = false
	band.Massless = true; band.CastShadow = false
	band.TopSurface = Enum.SurfaceType.Smooth; band.BottomSurface = Enum.SurfaceType.Smooth
	band.Size = Vector3.new(arm.Size.X + 0.05, 0.2, arm.Size.Z + 0.05)
	local offsetY
	if isR15 then
		local att = arm:FindFirstChild("RightWristRigAttachment")
		offsetY = att and (att.Position.Y + 0.2) or (-arm.Size.Y / 2 + 0.2)
	else
		offsetY = -arm.Size.Y / 2 + 0.45
	end
	band.CFrame = arm.CFrame * CFrame.new(0, offsetY, 0)
	band:SetAttribute("FitSize", arm.Size)
	local w = Instance.new("WeldConstraint"); w.Part0 = arm; w.Part1 = band; w.Parent = band
	band.Parent = arm
	return band
end

-- the outfit pieces that wear the colour, found once per character
local outfitCache = setmetatable({}, { __mode = "k" })
local function paintOutfit(c, colour)
	local entry = outfitCache[c]
	if not entry then
		entry = { parts = {}, ownBand = false }
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("MatchColour") then
				table.insert(entry.parts, d)
				if d:GetAttribute("Wristband") then entry.ownBand = true end
			end
		end
		outfitCache[c] = entry
	end
	for _, d in ipairs(entry.parts) do
		local s = d:GetAttribute("MatchColour") or 1
		local want = Color3.new(colour.R * s, colour.G * s, colour.B * s)
		if d.Color ~= want then d.Color = want end
	end
	return entry.ownBand
end

local function maintain(p)
	local c = p.Character
	local idx = colourIndex(p)
	if not c or not idx then return end
	if paintOutfit(c, COLOURS[idx][2]) then
		-- the outfit's own fitted band is already on the wrist; no extra box band
		for _, armName in ipairs({ "RightLowerArm", "LeftLowerArm", "Right Arm", "Left Arm" }) do
			local arm = c:FindFirstChild(armName)
			local b = arm and arm:FindFirstChild("Wristband")
			if b then b:Destroy() end
		end
		return
	end
	local creature = false
	for _, ch in ipairs(c:GetChildren()) do
		if CollectionService:HasTag(ch, "MaskCreature") then creature = true break end
	end
	local colour = COLOURS[idx][2]
	local isR15 = c:FindFirstChild("RightLowerArm") ~= nil
	-- the left wrist never wears one (clears bands left over from the old two-band version)
	local left = c:FindFirstChild(isR15 and "LeftLowerArm" or "Left Arm")
	local oldLeft = left and left:FindFirstChild("Wristband")
	if oldLeft then oldLeft:Destroy() end
	for _, armName in ipairs(isR15 and { "RightLowerArm" } or { "Right Arm" }) do
		local arm = c:FindFirstChild(armName)
		if arm then
			local band = arm:FindFirstChild("Wristband")
			-- refit if the arm was resized (e.g. the height boost) after the band went on
			if band and band:GetAttribute("FitSize") ~= arm.Size then band:Destroy(); band = nil end
			band = band or makeBand(arm, colour, isR15)
			band.Color = colour
			band.Transparency = creature and 1 or 0
		end
	end
end

-- A player picking their own colour (CounselorLooks / the counselor picker). Refused when someone in
-- the same ready ring or round already wears it; otherwise it's theirs and remembered as preferred.
local function choose(p, i)
	if type(i) ~= "number" or i ~= i or i % 1 ~= 0 or not COLOURS[i] then return false, "bad" end
	local k = groupKey(p)
	if k then
		for _, o in ipairs(Players:GetPlayers()) do
			if o ~= p and groupKey(o) == k and colourIndex(o) == i then return false, "taken" end
		end
	end
	setColour(p, i)
	p:SetAttribute("PreferredBand", i)
	return true
end
local chooseFn = game.ServerStorage:FindFirstChild("WristbandChoose") or Instance.new("BindableFunction")
chooseFn.Name = "WristbandChoose"
chooseFn.OnInvoke = choose
chooseFn.Parent = game.ServerStorage

Players.PlayerRemoving:Connect(function(p) groupSince[p] = nil; lastGroup[p] = nil end)
while true do
	assign()
	for _, p in ipairs(Players:GetPlayers()) do maintain(p) end
	task.wait(0.3)
end
