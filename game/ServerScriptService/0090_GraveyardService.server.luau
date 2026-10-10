-- Task 17: the old cemetery (south-east corner).
-- Every round one shovel lies on a random grave and the car keys are buried in one random grave of the 11.
-- The shovel is never a Tool: "Pick up" welds it to the counselor's right hand. Without it, "Dig" only tells
-- you to find the shovel. Each grave is 3 layers deep (Fisch-style tap mini-game in GraveyardClient).
-- Taking the keys completes the task; nothing goes into the inventory.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Rescue = require(script.Parent:WaitForChild("ForestRescueService"))
local config = workspace:WaitForChild("MaskSystem")
local yard = workspace:WaitForChild("Graveyard")
local gravesFolder = yard:WaitForChild("Graves")
local assets = game:GetService("ServerStorage"):WaitForChild("GraveyardAssets")
local taskModel = workspace:WaitForChild("ForestRescueTasks"):WaitForChild("Task17")
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local remote = remotes:FindFirstChild("GraveyardDig") or Instance.new("RemoteEvent")
remote.Name = "GraveyardDig"
remote.Parent = remotes

local LAYERS = 3
local TAPS_PER_LAYER = 4
local MIN_TAP_GAP = 0.15
local LAYER_PAUSE = 0.55
local DIG_RANGE = 11
local FILL_TOPS = { -1.3, -2.6 } -- dirt surface (studs below ground) after layers 1 and 2; layer 3 clears it
local PILE_SIZES = { 2.1, 2.8, 3.4 }
local BOUNDS = { minX = 202, maxX = 276, minZ = 203, maxZ = 272 } -- carrier must stay inside the cemetery
local DIRT = Color3.fromRGB(74, 57, 42)
-- shovel held at the hip, blade forward and down / blade planted in front while digging
local HOLD = CFrame.Angles(math.rad(70), 0, 0) * CFrame.new(0, -1.55, 0)
local DIG = CFrame.new(0, 0.1, -0.8) * CFrame.Angles(math.rad(22), 0, 0) * CFrame.new(0, -1.45, 0)
local THRUST = CFrame.new(0, -0.7, -1.0) * CFrame.Angles(math.rad(34), 0, 0) * CFrame.new(0, -1.45, 0)
local rng = Random.new()

local graves = {}
local shovel, shovelPrompt, shovelWeld
local carrier, carrierConns, outsideSince = nil, {}, nil
local homeGrave, keysGrave, keys, keysPrompt
local sessions = {} -- [player] = {grave, token, taps, last, wait}

local function notice(p, msg) if p and p.Parent then remote:FireClient(p, "notice", msg) end end
local function tween(inst, t, goal, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end
local function rootOf(p)
	local c = p and p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return c and c:FindFirstChild("HumanoidRootPart"), h, c
end
local function flat(a, b) return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude end
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Include
groundRay.FilterDescendantsInstances = { workspace.Terrain }
local function groundY(pos)
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), groundRay)
	return hit and hit.Position.Y or pos.Y
end

---------------------------------------------------------------- graves
local function setFill(g, top, t)
	-- keep the bottom of the dirt fixed, move its surface to `top` (relative to ground)
	local bottom = -g.fillSize.Y
	local h = math.max(0.05, top - bottom)
	local goal = { Size = Vector3.new(g.fillSize.X, h, g.fillSize.Z), CFrame = g.centre * CFrame.new(0, bottom + h / 2, 0) }
	if t then tween(g.fill, t, goal) else g.fill.Size = goal.Size g.fill.CFrame = goal.CFrame end
end
local function resetGrave(g)
	g.layer = 0
	g.fill.Transparency = 0 g.fill.CanCollide = true
	setFill(g, 0)
	g.turf.Transparency = g.turfT g.turf.CanCollide = true
	g.lidValue.Value = 0
	g.pile.Size = Vector3.new(0.2, 0.2, 0.2) g.pile.Transparency = 1
	g.model:SetAttribute("Layer", 0)
end
local function applyLayer(g, layer)
	g.model:SetAttribute("Layer", layer)
	if layer == 1 then
		tween(g.turf, 0.35, { Transparency = 1 })
		g.turf.CanCollide = false
	end
	if layer < LAYERS then
		setFill(g, FILL_TOPS[layer], 0.45)
	else
		setFill(g, -g.fillSize.Y + 0.05, 0.45)
		task.delay(0.45, function() if g.layer >= LAYERS then g.fill.Transparency = 1 g.fill.CanCollide = false end end)
	end
	-- the spoil heap beside the grave grows
	local d = PILE_SIZES[layer]
	g.pile.Transparency = 0
	tween(g.pile, 0.45, { Size = Vector3.new(d * 1.25, d, d), CFrame = CFrame.new(g.pileBase + Vector3.new(0, d * 0.22, 0)) })
end
local function burst(g)
	local top = g.layer < 1 and 0.4 or (g.layer < LAYERS and FILL_TOPS[g.layer] or -3.8)
	g.burstAtt.WorldPosition = (g.centre * CFrame.new(0, top + 0.2, -0.8)).Position
	g.burst:Emit(10)
end

for _, m in gravesFolder:GetChildren() do
	local anchor = m:FindFirstChild("DigAnchor")
	if anchor and m:FindFirstChild("Fill") then
		local g = { model = m, anchor = anchor, fill = m.Fill, fillSize = m.Fill.Size, turf = m.Turf, turfT = m.Turf.Transparency,
			lid = m.Coffin.Lid, lidCF = m.Coffin.Lid.CFrame, centre = anchor.PitCentre.WorldCFrame, layer = 0 }
		-- lid hinge on its west edge
		g.lidValue = Instance.new("NumberValue")
		g.lidValue.Changed:Connect(function(a)
			local w = g.lid.Size.X / 2
			g.lid.CFrame = g.lidCF * CFrame.new(-w, 0, 0) * CFrame.Angles(0, 0, math.rad(a)) * CFrame.new(w, 0, 0)
		end)
		local spot = anchor.PileSpot.WorldPosition
		g.pileBase = Vector3.new(spot.X, groundY(spot), spot.Z)
		local pile = m:FindFirstChild("SpoilHeap") or Instance.new("Part")
		pile.Name = "SpoilHeap" pile.Shape = Enum.PartType.Ball pile.Material = Enum.Material.Ground pile.Color = DIRT
		pile.Anchored = true pile.CanCollide = false pile.CanQuery = false pile.CanTouch = false
		pile.CFrame = CFrame.new(g.pileBase) pile.Parent = m
		g.pile = pile
		g.burstAtt = Instance.new("Attachment") g.burstAtt.Name = "DirtBurst" g.burstAtt.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Name = "Dirt" e.Enabled = false e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(92, 70, 50), Color3.fromRGB(60, 45, 32))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.5, 0.9) e.Speed = NumberRange.new(5, 9) e.SpreadAngle = Vector2.new(35, 35)
		e.Acceleration = Vector3.new(0, -30, 0) e.Rotation = NumberRange.new(0, 360) e.LightInfluence = 1
		e.EmissionDirection = Enum.NormalId.Top e.Parent = g.burstAtt
		g.burst = e
		local pr = anchor:FindFirstChild("DigPrompt") or Instance.new("ProximityPrompt")
		pr.Name = "DigPrompt" pr.ActionText = "Dig" pr.ObjectText = m:GetAttribute("DisplayName") or "Grave"
		pr.HoldDuration = 0.2 pr.MaxActivationDistance = 8 pr.RequiresLineOfSight = false pr.Parent = anchor
		g.prompt = pr
		table.insert(graves, g)
	end
end
table.sort(graves, function(a, b) return a.model.Name < b.model.Name end)

---------------------------------------------------------------- the shovel
local function disconnectCarrier()
	for _, c in carrierConns do c:Disconnect() end
	carrierConns = {}
end
local function layShovel(g, lean)
	if shovelWeld then shovelWeld:Destroy() shovelWeld = nil end
	for _, p in shovel:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true p.AssemblyLinearVelocity = Vector3.zero end end
	shovel:PivotTo(g.anchor[lean and "ShovelLean" or "ShovelRest"].WorldCFrame)
	shovel.Parent = yard
	if not lean then homeGrave = g end
end
local closeSession
local function releaseShovel(msg, leanOn)
	local p = carrier
	carrier = nil outsideSince = nil
	disconnectCarrier()
	if p then
		if sessions[p] then closeSession(p, nil) end
		if p.Parent then p:SetAttribute("CarryingShovel", false) end
		if msg then notice(p, msg) end
	end
	if leanOn then layShovel(leanOn, true) else layShovel(homeGrave or graves[1], false) end
end
local function makeShovel()
	if shovel then shovel:Destroy() end
	shovel = assets:WaitForChild("Shovel"):Clone()
	shovel.Name = "GraveShovel"
	local main = shovel.PrimaryPart
	for _, d in shovel:GetDescendants() do if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end end
	for _, p in shovel:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true p.CanCollide = false p.CanTouch = false p.Massless = true
			if p ~= main then local w = Instance.new("WeldConstraint") w.Part0 = main w.Part1 = p w.Parent = p end
		end
	end
	shovelPrompt = Instance.new("ProximityPrompt")
	shovelPrompt.Name = "PickUpPrompt" shovelPrompt.ActionText = "Pick up" shovelPrompt.ObjectText = "Shovel"
	shovelPrompt.HoldDuration = 0.35 shovelPrompt.MaxActivationDistance = 8 shovelPrompt.RequiresLineOfSight = false
	shovelPrompt.Parent = main
	shovelPrompt.Triggered:Connect(function(p)
		if carrier or taskModel:GetAttribute("Done") or not Rescue.CanWork(p, taskModel) then return end
		if p:GetAttribute("Carrying") then notice(p, "YOUR HANDS ARE FULL") return end
		local root, h, c = rootOf(p)
		local hand = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
		if not hand or not root or flat(root.Position, main.Position) > 11 then return end
		carrier = p outsideSince = nil
		-- put the shovel in the hand first, then unanchor, then weld: if the weld ever reaches the client while the
		-- shovel is still anchored, the character would be yanked onto the shovel instead of the other way round
		shovel:PivotTo(hand.CFrame * HOLD)
		for _, part in shovel:GetDescendants() do if part:IsA("BasePart") then part.Anchored = false end end
		local w = Instance.new("Weld") w.Name = "ShovelGrip" w.Part0 = hand w.Part1 = main w.C0 = HOLD w.Parent = main
		shovelWeld = w
		p:SetAttribute("CarryingShovel", true)
		table.insert(carrierConns, h.Died:Connect(function() if carrier == p then releaseShovel(nil) end end))
		table.insert(carrierConns, p.CharacterRemoving:Connect(function() if carrier == p then releaseShovel(nil) end end))
		notice(p, "YOU PICKED UP THE SHOVEL — DIG THE GRAVES")
	end)
end

---------------------------------------------------------------- digging sessions
local function anyDigging()
	for _ in sessions do return true end
	return false
end
closeSession = function(p, msg)
	local s = sessions[p]
	if not s then return end
	sessions[p] = nil
	if shovelWeld and carrier == p then tween(shovelWeld, 0.25, { C0 = HOLD }) end
	taskModel:SetAttribute("ExternalWorkers", anyDigging() and 1 or 0)
	Rescue.Refresh()
	if p.Parent then remote:FireClient(p, "close", msg) end
end

---------------------------------------------------------------- the keys
local function revealKeys(g)
	if keys then keys:Destroy() end
	keys = assets:WaitForChild("CarKeys"):Clone()
	keys.Name = "BuriedCarKeys"
	keys:PivotTo(g.anchor.KeysRest.WorldCFrame)
	keysPrompt = Instance.new("ProximityPrompt")
	keysPrompt.Name = "TakeKeys" keysPrompt.ActionText = "Take" keysPrompt.ObjectText = "Car keys"
	keysPrompt.HoldDuration = 0.4 keysPrompt.MaxActivationDistance = 12 keysPrompt.RequiresLineOfSight = false
	keysPrompt.Parent = keys.PrimaryPart
	keys.Parent = yard
	keysPrompt.Triggered:Connect(function(p)
		local root = rootOf(p)
		if not keys or not root or flat(root.Position, keys:GetPivot().Position) > 12 then return end
		if not Rescue.CompleteExternal(p, taskModel) then return end
		local k = keys keys = nil keysPrompt = nil
		for _, d in k:GetDescendants() do
			if d:IsA("BasePart") then tween(d, 0.5, { Transparency = 1, CFrame = d.CFrame + Vector3.new(0, 2.5, 0) }) end
			if d:IsA("ProximityPrompt") then d.Enabled = false end
			if d:IsA("ParticleEmitter") then d.Enabled = false end
		end
		task.delay(0.6, function() k:Destroy() end)
		for other in sessions do closeSession(other, nil) end
		-- the job's done: the shovel gets left leaning on that headstone
		local holder = carrier
		if holder then releaseShovel(nil, g) else layShovel(g, true) end
		notice(p, "CAR KEYS FOUND — TASK COMPLETE")
		if holder and holder ~= p then notice(holder, "SOMEONE TOOK THE CAR KEYS — TASK COMPLETE") end
	end)
end

local function stillDigging(p, s)
	local root = rootOf(p)
	return carrier == p and root ~= nil and Rescue.CanWork(p, taskModel) and s.grave.layer < LAYERS
		and flat(root.Position, s.grave.centre.Position) <= DIG_RANGE
end
local function finishGrave(p, g)
	task.delay(0.5, function()
		tween(g.lidValue, 0.9, { Value = 96 }, Enum.EasingStyle.Back)
		if g == keysGrave then revealKeys(g) end
	end)
	task.delay(1.1, function()
		if sessions[p] and sessions[p].grave == g then
			closeSession(p, g == keysGrave and "THE CAR KEYS! TAKE THEM FROM THE COFFIN" or "NOTHING BUT BONES… TRY ANOTHER GRAVE")
		end
	end)
end
local function tap(p, token)
	local s = sessions[p]
	if not s or s.token ~= token or s.wait then return end
	local now = os.clock()
	if now - s.last < MIN_TAP_GAP then return end
	s.last = now
	if not stillDigging(p, s) then closeSession(p, "DIGGING STOPPED") return end
	local g = s.grave
	s.taps += 1
	burst(g)
	if shovelWeld then
		local down = tween(shovelWeld, 0.09, { C0 = THRUST })
		down.Completed:Once(function() if shovelWeld and sessions[p] then tween(shovelWeld, 0.14, { C0 = DIG }) end end)
	end
	if s.taps < TAPS_PER_LAYER then
		remote:FireClient(p, "tap", { taps = s.taps, need = TAPS_PER_LAYER })
		return
	end
	s.taps = 0
	g.layer += 1
	applyLayer(g, g.layer)
	local finished = g.layer >= LAYERS
	remote:FireClient(p, "layer", { layer = g.layer, layers = LAYERS, need = TAPS_PER_LAYER, finished = finished })
	s.wait = true
	if finished then
		finishGrave(p, g)
	else
		task.delay(LAYER_PAUSE, function() if sessions[p] == s then s.wait = false end end)
	end
end
local function tryDig(p, g)
	if taskModel:GetAttribute("Done") or g.layer >= LAYERS then return end
	if not Rescue.Online() then notice(p, config:GetAttribute("RescueStatus") or "TASKS ARE OFFLINE") return end
	if carrier ~= p then
		notice(p, carrier and "ANOTHER COUNSELOR IS CARRYING THE SHOVEL" or "FIND THE SHOVEL LYING ON ONE OF THE GRAVES FIRST")
		return
	end
	if sessions[p] or not Rescue.CanWork(p, taskModel) then return end
	local s = { grave = g, token = HttpService:GenerateGUID(false), taps = 0, last = 0 }
	if not stillDigging(p, s) then return end
	sessions[p] = s
	taskModel:SetAttribute("ExternalWorkers", 1)
	Rescue.Refresh()
	if shovelWeld then tween(shovelWeld, 0.25, { C0 = DIG }) end
	remote:FireClient(p, "open", { token = s.token, title = g.model:GetAttribute("DisplayName"), layer = g.layer + 1, layers = LAYERS, need = TAPS_PER_LAYER })
end
for _, g in graves do g.prompt.Triggered:Connect(function(p) tryDig(p, g) end) end

remote.OnServerEvent:Connect(function(p, action, token)
	if action == "tap" and typeof(token) == "string" and #token < 64 then tap(p, token)
	elseif action == "cancel" then closeSession(p, nil) end
end)

---------------------------------------------------------------- rounds
local function resetRound()
	for p in sessions do closeSession(p, "NEW ROUND") end
	if carrier then local p = carrier carrier = nil disconnectCarrier() if p.Parent then p:SetAttribute("CarryingShovel", false) end end
	if keys then keys:Destroy() keys = nil keysPrompt = nil end
	for _, g in graves do resetGrave(g) end
	if not shovel or not shovel.Parent then makeShovel() end
	local a = rng:NextInteger(1, #graves)
	local b
	repeat b = rng:NextInteger(1, #graves) until b ~= a or #graves < 2
	layShovel(graves[a])
	keysGrave = graves[b]
	assets:SetAttribute("KeysGrave", keysGrave.model.Name) -- server-only (ServerStorage), handy when testing
	taskModel:SetAttribute("ExternalWorkers", 0)
end
Rescue.RoundStarted.Event:Connect(resetRound)
Rescue.RoundEnded.Event:Connect(function()
	for p in sessions do closeSession(p, nil) end
end)
Players.PlayerRemoving:Connect(function(p)
	sessions[p] = nil
	if carrier == p then releaseShovel(nil) end
end)
makeShovel()
resetRound()

local function inside(pos) return pos.X > BOUNDS.minX and pos.X < BOUNDS.maxX and pos.Z > BOUNDS.minZ and pos.Z < BOUNDS.maxZ end
while true do
	local online = Rescue.Online()
	local done = taskModel:GetAttribute("Done") == true
	-- the shovel can vanish if its holder fell out of the world; put a fresh one back
	if not shovel or not shovel.Parent or not shovel.PrimaryPart then
		shovel = nil carrier = nil disconnectCarrier() makeShovel() layShovel(homeGrave or graves[1])
	end
	if carrier then
		local root, h = rootOf(carrier)
		if not carrier.Parent or not root or not h or h.Health <= 0 or carrier:GetAttribute("InRound") ~= true
			or not shovelWeld or not shovelWeld.Part0 or not shovelWeld.Part0:IsDescendantOf(workspace) then
			releaseShovel(nil)
		elseif not inside(root.Position) then
			outsideSince = outsideSince or os.clock()
			if os.clock() - outsideSince > 2 then releaseShovel("YOU LEFT THE CEMETERY — THE SHOVEL WENT BACK ON ITS GRAVE") end
		else
			outsideSince = nil
		end
	end
	for p, s in sessions do if not s.wait and not stillDigging(p, s) then closeSession(p, "DIGGING STOPPED") end end
	for _, g in graves do
		local busy = false
		for _, s in sessions do if s.grave == g then busy = true end end
		-- while the shovel lies on this grave its "Pick up" prompt must win the E key, so this grave's "Dig" steps aside
		local shovelHere = carrier == nil and homeGrave == g
		g.prompt.Enabled = online and not done and g.layer < LAYERS and not busy and not shovelHere
	end
	if shovelPrompt then shovelPrompt.Enabled = online and not done and carrier == nil end
	if keysPrompt then keysPrompt.Enabled = online and not done end
	task.wait(0.2)
end
