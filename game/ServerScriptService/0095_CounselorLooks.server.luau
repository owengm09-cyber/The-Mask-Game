-- CounselorLooks
-- Players pick their counselor: a BOY or GIRL look and one of the 11 match colours.
-- * The look swaps a few pieces of the outfit (hair, eyes, brows, lips). Both looks live in
--   ServerStorage.CounselorKit.Template; each piece carries a "Variant" attribute ("Boy"/"Girl").
--   The StarterCharacter spawns as the boy and is switched here straight away if needed.
-- * The colour is handed to the Wristbands script, which keeps colours unique inside a ready ring and
--   a round and paints every "MatchColour" piece of the outfit.
-- * Both can be changed between matches, not during one (colours tell players apart in meetings).
--   In a solo Studio test they can be changed any time, for trying them out.
-- * The choice is remembered between visits (DataStore "CounselorChoice"; a failed save is harmless).
-- Client side: StarterPlayerScripts.CounselorPicker. Remote: ReplicatedStorage.Remotes.CounselorChoice.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KIT = game.ServerStorage:WaitForChild("CounselorKit")
local TEMPLATE = KIT:WaitForChild("Template")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = remotes:FindFirstChild("CounselorChoice")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "CounselorChoice"
	remote.Parent = remotes
end
local chooseColour = game.ServerStorage:WaitForChild("WristbandChoose") -- BindableFunction from Wristbands

local LOOKS = { Boy = true, Girl = true }
local NUM_COLOURS = 11

-- every look-specific piece of the template, as an offset from the body part it is welded to
local pieces = { Boy = {}, Girl = {} }
for _, p in TEMPLATE.Outfit:GetChildren() do
	local look = p:GetAttribute("Variant")
	if look and pieces[look] and p:IsA("BasePart") then
		local w = p:FindFirstChildOfClass("WeldConstraint")
		local body = w and (w.Part0 == p and w.Part1 or w.Part0)
		if body then
			table.insert(pieces[look], { part = p, body = body.Name, offset = body.CFrame:ToObjectSpace(p.CFrame) })
		end
	end
end

local function applyLook(player, char)
	char = char or player.Character
	local outfit = char and char:FindFirstChild("Outfit")
	if not outfit then return end
	local look = player:GetAttribute("CounselorLook")
	if not LOOKS[look] then look = "Boy" end
	local have = false
	for _, p in outfit:GetChildren() do
		local v = p:GetAttribute("Variant")
		if v and v ~= look then p:Destroy() elseif v == look then have = true end
	end
	if not have then
		for _, e in pieces[look] do
			local body = char:FindFirstChild(e.body)
			if body then
				local c = e.part:Clone()
				for _, w in c:GetChildren() do if w:IsA("WeldConstraint") then w:Destroy() end end
				c.Anchored = false
				c.CFrame = body.CFrame * e.offset
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = c
				w.Parent = c
				c.Parent = outfit
			end
		end
	end
	char:SetAttribute("Look", look)
end

-- remembered choices
local store
pcall(function() store = DataStoreService:GetDataStore("CounselorChoice") end)
local dirty = {}
local function load(player)
	if not store then return end
	local ok, data = pcall(function() return store:GetAsync("u" .. player.UserId) end)
	if not ok and tostring(data):find("StudioAccessToApisNotAllowed") then
		store = nil -- Studio without API access: don't keep trying (and warning) for the rest of the test
		return
	end
	if ok and type(data) == "table" then
		if LOOKS[data.look] and player:GetAttribute("CounselorLook") == nil then player:SetAttribute("CounselorLook", data.look) end
		if type(data.colour) == "number" and player:GetAttribute("PreferredBand") == nil and not player:GetAttribute("InRound") then
			pcall(function() chooseColour:Invoke(player, data.colour) end)
		end
	end
end
local function save(player)
	if not store or not dirty[player] then return end
	dirty[player] = nil
	local data = { look = player:GetAttribute("CounselorLook"), colour = player:GetAttribute("PreferredBand") }
	pcall(function() store:SetAsync("u" .. player.UserId, data) end)
end

local function canChange(player)
	if not player:GetAttribute("InRound") then return true end
	return RunService:IsStudio() and #Players:GetPlayers() == 1
end

local lastRequest = {}
remote.OnServerEvent:Connect(function(player, kind, value)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.25 then return end
	lastRequest[player] = now
	if not canChange(player) then
		remote:FireClient(player, "Result", false, "You can change your camper between matches.")
		return
	end
	if kind == "Look" then
		if not LOOKS[value] then return end
		player:SetAttribute("CounselorLook", value)
		applyLook(player)
		dirty[player] = true
		remote:FireClient(player, "Result", true, value == "Girl" and "Girl camper" or "Boy camper")
	elseif kind == "Colour" then
		if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 1 or value > NUM_COLOURS then return end
		local ok, why = chooseColour:Invoke(player, value)
		if ok then
			dirty[player] = true
			remote:FireClient(player, "Result", true, tostring(player:GetAttribute("BandName")))
		else
			remote:FireClient(player, "Result", false, why == "taken" and "Someone in your group already has that colour." or "Can't pick that colour right now.")
		end
	end
end)

local function hook(player)
	player.CharacterAdded:Connect(function(char)
		-- the outfit arrives with the character; switch the look before anyone sees it
		char:WaitForChild("Outfit", 10)
		applyLook(player, char)
	end)
	if player.Character then applyLook(player, player.Character) end
	task.spawn(load, player)
	player:GetAttributeChangedSignal("CounselorLook"):Connect(function() applyLook(player) end)
end
Players.PlayerAdded:Connect(hook)
for _, p in Players:GetPlayers() do hook(p) end
Players.PlayerRemoving:Connect(function(p) save(p) lastRequest[p] = nil dirty[p] = nil end)
game:BindToClose(function() for _, p in Players:GetPlayers() do save(p) end end)
-- save changes every so often too (not on every click)
task.spawn(function()
	while true do
		task.wait(30)
		for p in dirty do if p.Parent then save(p) end end
	end
end)
