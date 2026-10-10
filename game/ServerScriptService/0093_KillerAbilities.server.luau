-- Killer abilities for daylight, when the killer looks like any other counselor:
--   * Sabotage: wreck a station. It loses its progress (a finished task has to be redone) and jams for a while.
--     Everyone gets an alert naming the station, so who was near it becomes evidence.
--   * Kill spots (CollectionService tag "KillSpot"): push a survivor standing there to their death. Each spot has its
--     own fall: down the well (the body stays at the bottom), or over the railing of the radio tower platform
--     (the body lies at the foot of the tower).
--   * The radio tower ladder: tear it down (twice per match, by day; RadioTowerService does the wrecking and the repair).
--   * Anyone can look down the well to check for bodies, but while they lean over the rim they can be pushed too.
-- The killer's prompts only exist on the killer's own client (KillerClient), so nobody else ever sees them.
-- Tunables live on workspace.MaskSystem: SabotageCooldown, SabotageJam, SabotageRange, PushCooldown, PushRange, WellPeekSeconds.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Tags = game:GetService("CollectionService")
local Rescue = require(script.Parent:WaitForChild("ForestRescueService"))
local Mask = require(script.Parent:WaitForChild("MaskService"))
local Progression = require(script.Parent:WaitForChild("ProgressionService"))
local Tower = nil
task.spawn(function()
	local m = script.Parent:WaitForChild("RadioTowerService", 20)
	if m then Tower = require(m) end
end)
local config = workspace:WaitForChild("MaskSystem")
local tasks = workspace:WaitForChild("ForestRescueTasks")
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local remote = remotes:FindFirstChild("KillerAction") or Instance.new("RemoteEvent")
remote.Name = "KillerAction"
remote.Parent = remotes

local function setting(name, default)
	local v = config:GetAttribute(name)
	if v == nil then config:SetAttribute(name, default) v = default end
	return v
end
setting("SabotageCooldown", 75) setting("SabotageJam", 20) setting("SabotageRange", 9)
setting("PushCooldown", 45) setting("PushRange", 6.5) setting("WellPeekSeconds", 3)

local SITE_NAMES = { CAMP = "CAMP", SHED = "MAINTENANCE SHED", RANGER = "RANGER STATION", PUMP = "PUMP HOUSE", INTAKE = "WATER INTAKE",
	TOWER = "WELL / BEACON", TRUCK = "THE TRUCK", LOOKOUT = "LOOKOUT", WATCHTOWER = "WATCH TOWER", GRAVEYARD = "OLD CEMETERY",
	RADIOTOWER = "RADIO TOWER" }
local bodies = workspace:FindFirstChild("KillSpotBodies") or Instance.new("Folder")
bodies.Name = "KillSpotBodies"
bodies.Parent = workspace
local ready = {} -- [player] = {sabotage = t, push = t}
local busy = {} -- characters in the middle of being pushed
local peeking = {} -- [player] = {zone, restore}
local rng = Random.new()

local function now() return workspace:GetServerTimeNow() end
local function alive(p)
	local c = p and p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and h.Health > 0 and r then return c, h, r end
end
local function flat(a, b) return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude end
local function isKiller(p) return p and p:GetAttribute("Role") == "Killer" and p:GetAttribute("InRound") == true end
local function cooldowns(p)
	local t = ready[p]
	if not t then t = { sabotage = 0, push = 0 } ready[p] = t end
	return t
end
local function sendCooldowns(p) local t = cooldowns(p) remote:FireClient(p, "cooldowns", { sabotage = t.sabotage, push = t.push }) end
local function alertAll(msg) for _, p in Players:GetPlayers() do if p:GetAttribute("InRound") then remote:FireClient(p, "alert", msg) end end end
local function canAct(p)
	local c, h, r = alive(p)
	if not c or not isKiller(p) or config:GetAttribute("MatchActive") ~= true or config:GetAttribute("MeetingActive") == true
		or p:GetAttribute("Venting") == true or busy[c] or c:FindFirstChild("MaskCreature") then return nil end
	return c, h, r
end

---------------------------------------------------------------- sabotage
local function sabotageFx(m)
	local pp = m.PrimaryPart
	local old = pp:FindFirstChild("SabotageFx") if old then old:Destroy() end
	local oldSmoke = pp:FindFirstChild("SabotageSmoke") if oldSmoke then oldSmoke:Destroy() end
	local att = Instance.new("Attachment") att.Name = "SabotageFx" att.Position = Vector3.new(0, 0.6, 0) att.Parent = pp
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks" sparks.Enabled = false sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 120, 40))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.25, 0.6) sparks.Speed = NumberRange.new(8, 15) sparks.SpreadAngle = Vector2.new(75, 75)
	sparks.Acceleration = Vector3.new(0, -45, 0) sparks.LightEmission = 1 sparks.Drag = 2 sparks.Parent = att
	sparks:Emit(45)
	local flash = Instance.new("PointLight") flash.Color = Color3.fromRGB(255, 160, 70) flash.Range = 14 flash.Brightness = 5 flash.Parent = att
	TweenService:Create(flash, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	local smoke = Instance.new("Smoke") smoke.Name = "SabotageSmoke" smoke.Color = Color3.fromRGB(45, 42, 40) smoke.Opacity = 0.18
	smoke.RiseVelocity = 2.5 smoke.Size = 1.4 smoke.TimeScale = 0.8 smoke.Parent = pp
	local crackle = Instance.new("Sound") crackle.SoundId = "rbxasset://sounds/electronicpingshort.wav" crackle.Volume = 0.8
	crackle.PlaybackSpeed = 0.55 crackle.RollOffMaxDistance = 70 crackle.Parent = att crackle:Play()
	-- keep sputtering until somebody redoes the task
	task.spawn(function()
		while att.Parent and m:GetAttribute("Sabotaged") == true do
			task.wait(rng:NextNumber(1.2, 2.4))
			if m:GetAttribute("Sabotaged") == true and att.Parent then sparks:Emit(rng:NextInteger(6, 14)) end
		end
		if att.Parent then att:Destroy() end
		if smoke.Parent then smoke.Enabled = false game:GetService("Debris"):AddItem(smoke, 4) end
	end)
end
local function sabotage(p, m)
	local c, h, r = canAct(p)
	if not c or Lighting:GetAttribute("Phase") ~= "Day" then return end
	if typeof(m) ~= "Instance" or m.Parent ~= tasks or not m:IsA("Model") or not m.PrimaryPart then return end
	local cd = cooldowns(p)
	if now() < cd.sabotage then return end
	if (r.Position - m.PrimaryPart.Position).Magnitude > config:GetAttribute("SabotageRange") then return end
	local ok, wasDone = Rescue.Sabotage(m, config:GetAttribute("SabotageJam"))
	if not ok then return end
	cd.sabotage = now() + config:GetAttribute("SabotageCooldown")
	sendCooldowns(p)
	sabotageFx(m)
	local site = SITE_NAMES[m:GetAttribute("Site")] or tostring(m:GetAttribute("Site"))
	alertAll("SABOTAGE — " .. string.upper(m:GetAttribute("Title") or "A STATION") .. " / " .. site .. (wasDone and "  (UNDONE)" or ""))
end

---------------------------------------------------------------- kill spots
local function zoneAt(pos)
	for _, z in Tags:GetTagged("KillSpot") do
		if z:IsA("BasePart") and z:IsDescendantOf(workspace) and flat(pos, z.Position) <= (z:GetAttribute("Radius") or 6) and math.abs(pos.Y - z.Position.Y) < 8 then return z end
	end
end
local function bodiesIn(zone)
	local list = {}
	for _, b in bodies:GetChildren() do if b:GetAttribute("ZoneId") == zone:GetAttribute("ZoneId") then table.insert(list, b) end end
	return list
end
-- `place` (optional): where the body lies, as a CFrame for its root (the radio tower); otherwise it's slumped at the
-- zone's "Bottom" (the well)
local function makeBody(victim, char, zone, place)
	char.Archivable = true
	local ok, copy = pcall(function() return char:Clone() end)
	char.Archivable = false
	if not ok or not copy then return end
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Sound") or d:IsA("BillboardGui")
			or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Model") and d.Name == "WornMask" then d:Destroy() end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanTouch = false d.CanQuery = false d.Massless = true end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
		hum.EvaluateStateMachine = false
	end
	copy.Name = "Body"
	copy:SetAttribute("ZoneId", zone:GetAttribute("ZoneId"))
	copy:SetAttribute("VictimUserId", victim and victim.UserId or 0)
	copy:SetAttribute("BandName", victim and victim:GetAttribute("BandName") or "")
	if place then
		copy:PivotTo(place)
	else
		-- slumped on its back against the shaft wall
		local bottom = zone:GetAttribute("Bottom")
		local yaw = rng:NextNumber(0, math.pi * 2)
		local n = #bodiesIn(zone)
		local spot = bottom + Vector3.new(math.cos(yaw) * 0.9, 1.0 + n * 0.6, math.sin(yaw) * 0.9)
		copy:PivotTo(CFrame.new(spot) * CFrame.Angles(0, -yaw + math.pi / 2, 0) * CFrame.Angles(math.rad(-68), 0, math.rad(rng:NextNumber(-25, 25))))
	end
	copy.Parent = bodies
	return copy
end
local function hideCharacter(char)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then d.Transparency = 1 end
	end
end
-- the killer's two-handed shove: arms snap forward, torso leans in (Motor6D offsets replicate to everyone)
local function shove(killerChar)
	local joints = {}
	for _, spec in {
		{ "RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(95), 0, math.rad(-10)) },
		{ "LeftUpperArm", "LeftShoulder", CFrame.Angles(math.rad(95), 0, math.rad(10)) },
		{ "UpperTorso", "Waist", CFrame.Angles(math.rad(-16), 0, 0) },
	} do
		local part = killerChar:FindFirstChild(spec[1])
		local j = part and part:FindFirstChild(spec[2])
		if j and j:IsA("Motor6D") then
			local base = j:GetAttribute("RestC0") or j.C0
			j:SetAttribute("RestC0", base)
			table.insert(joints, { j, base })
			TweenService:Create(j, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base * spec[3] }):Play()
		end
	end
	task.delay(0.6, function()
		for _, e in joints do if e[1].Parent then TweenService:Create(e[1], TweenInfo.new(0.35), { C0 = e[2] }):Play() end end
	end)
end
local function zoneSound(zone, id, volume, speed)
	local s = Instance.new("Sound") s.SoundId = id s.Volume = volume s.PlaybackSpeed = speed or 1 s.RollOffMaxDistance = 80 s.Parent = zone
	s:Play() game:GetService("Debris"):AddItem(s, 6)
end
local endPeek
-- victimChar can be an NPC (testing); victim is the Player when there is one
local function pushIntoWell(killer, victim, victimChar, zone)
	local vh = victimChar:FindFirstChildOfClass("Humanoid")
	local vr = victimChar:FindFirstChild("HumanoidRootPart")
	if not vh or not vr or busy[victimChar] then return false end
	busy[victimChar] = true
	victimChar:SetAttribute("BeingPushed", true)
	if victim and peeking[victim] then endPeek(victim, nil) end
	local kc, _, kr = alive(killer)
	if kc then
		pcall(function() kr.CFrame = CFrame.lookAt(kr.Position, Vector3.new(vr.Position.X, kr.Position.Y, vr.Position.Z)) end)
		shove(kc)
	end
	-- the server takes the body for the fall
	pcall(function() vr:SetNetworkOwner(nil) end)
	vh.PlatformStand = true
	vr.Anchored = true
	local centre = zone.Position
	local rimR, rimY = zone:GetAttribute("RimRadius") or 3.45, zone:GetAttribute("RimHeight") or 3.9
	local bottom = zone:GetAttribute("Bottom")
	local dir = Vector3.new(vr.Position.X - centre.X, 0, vr.Position.Z - centre.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
	local face = CFrame.lookAt(Vector3.zero, -dir) -- facing into the well
	local edge = Vector3.new(centre.X, 0, centre.Z) + dir * (rimR + 0.2)
	local k1 = CFrame.new(edge.X, rimY + 1.9, edge.Z) * face * CFrame.Angles(math.rad(-60), 0, 0)
	local mid = Vector3.new(centre.X, 0, centre.Z) + dir * 0.5
	local k2 = CFrame.new(mid.X, rimY + 0.6, mid.Z) * face * CFrame.Angles(math.rad(-150), 0, math.rad(15))
	local k3 = CFrame.new(bottom.X, bottom.Y + 1.4, bottom.Z) * face * CFrame.Angles(math.rad(-215), math.rad(35), math.rad(25))
	local value = Instance.new("CFrameValue")
	value.Value = vr.CFrame
	value.Changed:Connect(function(cf) if vr.Parent then vr.CFrame = cf end end)
	task.wait(0.12) -- let the shove land
	zoneSound(zone, "rbxasset://sounds/action_falling.mp3", 0.9, 0.9)
	local t1 = TweenService:Create(value, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = k1 }) t1:Play() t1.Completed:Wait()
	local t2 = TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { Value = k2 }) t2:Play() t2.Completed:Wait()
	local t3 = TweenService:Create(value, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = k3 }) t3:Play() t3.Completed:Wait()
	value:Destroy()
	zoneSound(zone, "rbxasset://sounds/impact_water.mp3", 1, 0.8)
	local body = makeBody(victim, victimChar, zone)
	hideCharacter(victimChar)
	vh.Health = 0
	if victim and killer then pcall(function() Progression.Kill(killer, victim) end) end
	task.delay(1, function() busy[victimChar] = nil end)
	return true, body
end
-- over the railing of the radio tower platform, straight away from the killer, and all the way down
local function pushOffTower(killer, victim, victimChar, zone)
	local vh = victimChar:FindFirstChildOfClass("Humanoid")
	local vr = victimChar:FindFirstChild("HumanoidRootPart")
	if not vh or not vr or busy[victimChar] then return false end
	busy[victimChar] = true
	victimChar:SetAttribute("BeingPushed", true)
	local centre = zone:GetAttribute("Centre") or zone.Position
	local half = zone:GetAttribute("DeckHalf") or 5
	local deckY = zone:GetAttribute("DeckY") or zone.Position.Y
	local kc, _, kr = alive(killer)
	local away = kr and Vector3.new(vr.Position.X - kr.Position.X, 0, vr.Position.Z - kr.Position.Z) or Vector3.zero
	if away.Magnitude < 0.1 then away = Vector3.new(vr.Position.X - centre.X, 0, vr.Position.Z - centre.Z) end
	if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
	-- the platform is square: go over the side the shove points at
	local dir = math.abs(away.X) > math.abs(away.Z) and Vector3.new(math.sign(away.X), 0, 0) or Vector3.new(0, 0, math.sign(away.Z))
	if kc then
		pcall(function() kr.CFrame = CFrame.lookAt(kr.Position, Vector3.new(vr.Position.X, kr.Position.Y, vr.Position.Z)) end)
		shove(kc)
	end
	pcall(function() vr:SetNetworkOwner(nil) end)
	vh.PlatformStand = true
	vr.Anchored = true
	local rel = vr.Position - centre
	local lateral = dir.X ~= 0 and Vector3.new(0, 0, math.clamp(rel.Z, -half + 0.8, half - 0.8)) or Vector3.new(math.clamp(rel.X, -half + 0.8, half - 0.8), 0, 0)
	local edge = Vector3.new(centre.X, deckY, centre.Z) + lateral + dir * half
	local out = CFrame.lookAt(Vector3.zero, dir) -- facing out, going over head first
	local k1 = CFrame.new(edge + Vector3.new(0, 3.9, 0) - dir * 0.3) * out * CFrame.Angles(math.rad(-40), 0, 0)
	local k2 = CFrame.new(edge + dir * 2.4 + Vector3.new(0, 2.6, 0)) * out * CFrame.Angles(math.rad(-115), 0, math.rad(12))
	local ray = RaycastParams.new() ray.FilterType = Enum.RaycastFilterType.Exclude ray.RespectCanCollide = true
	ray.FilterDescendantsInstances = { victimChar, kc, bodies }
	local landXZ = edge + dir * 5.5
	local hit = workspace:Raycast(Vector3.new(landXZ.X, deckY - 4, landXZ.Z), Vector3.new(0, -200, 0), ray)
	local ground = hit and hit.Position or Vector3.new(landXZ.X, deckY - 66, landXZ.Z)
	local yaw = math.atan2(-dir.X, -dir.Z) + rng:NextNumber(-0.5, 0.5)
	local k3 = CFrame.new(ground + Vector3.new(0, 1.2, 0)) * out * CFrame.Angles(math.rad(-230), math.rad(25), math.rad(18))
	local value = Instance.new("CFrameValue")
	value.Value = vr.CFrame
	value.Changed:Connect(function(cf) if vr.Parent then vr.CFrame = cf end end)
	task.wait(0.12) -- let the shove land
	zoneSound(zone, "rbxasset://sounds/action_falling.mp3", 1, 0.85)
	local t1 = TweenService:Create(value, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = k1 }) t1:Play() t1.Completed:Wait()
	local t2 = TweenService:Create(value, TweenInfo.new(0.3, Enum.EasingStyle.Sine), { Value = k2 }) t2:Play() t2.Completed:Wait()
	local t3 = TweenService:Create(value, TweenInfo.new(1.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = k3 }) t3:Play() t3.Completed:Wait()
	value:Destroy()
	local thud = Instance.new("Sound") thud.SoundId = "rbxasset://sounds/collide.wav" thud.Volume = 1 thud.PlaybackSpeed = 0.45 thud.RollOffMaxDistance = 90
	thud.Parent = vr thud:Play()
	-- the body lies on its back where it landed
	local place = CFrame.new(ground + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(90), 0, math.rad(rng:NextNumber(-20, 20)))
	makeBody(victim, victimChar, zone, place)
	hideCharacter(victimChar)
	vh.Health = 0
	if victim and killer then pcall(function() Progression.Kill(killer, victim) end) end
	task.delay(1, function() busy[victimChar] = nil end)
	return true
end
local function push(p, victim)
	local c, _, r = canAct(p)
	if not c or typeof(victim) ~= "Instance" or not victim:IsA("Player") or victim == p or not victim:GetAttribute("InRound") then return end
	local cd = cooldowns(p)
	if now() < cd.push then return end
	local vc, _, vr = alive(victim)
	if not vc or busy[vc] or vc:FindFirstChildOfClass("ForceField") or Mask.IsSafe(vr.Position) then return end
	if (vr.Position - r.Position).Magnitude > config:GetAttribute("PushRange") then return end
	local zone = zoneAt(vr.Position)
	local kind = zone and zone:GetAttribute("Kind")
	if kind ~= "Well" and kind ~= "Tower" then return end
	if vc:GetAttribute("OnLadder") then return end
	-- off the tower only from the platform itself (not from the ladder below it)
	if kind == "Tower" and vr.Position.Y < (zone:GetAttribute("DeckY") or zone.Position.Y) + 1 then return end
	local ray = RaycastParams.new() ray.FilterType = Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances = { c, vc, bodies } ray.RespectCanCollide = true
	local hit = workspace:Raycast(r.Position, vr.Position - r.Position, ray)
	if hit and not hit.Instance:IsDescendantOf(zone.Parent) then return end
	cd.push = now() + config:GetAttribute("PushCooldown")
	sendCooldowns(p)
	task.spawn(kind == "Tower" and pushOffTower or pushIntoWell, p, victim, vc, zone)
end

---------------------------------------------------------------- the radio tower ladder
local function wreckLadder(p)
	local c, _, r = canAct(p)
	if not c or not Tower or Lighting:GetAttribute("Phase") ~= "Day" then return end
	local cd = cooldowns(p)
	if now() < cd.sabotage or not Tower.CanWreck() then return end
	local tower = workspace:FindFirstChild("RadioTower")
	local base = tower and tower:FindFirstChild("Ladder") and tower.Ladder:FindFirstChild("LadderBase")
	if not base or (r.Position - base.Position).Magnitude > config:GetAttribute("SabotageRange") + 2 then return end
	if not Tower.Wreck() then return end
	cd.sabotage = now() + config:GetAttribute("SabotageCooldown")
	sendCooldowns(p)
	alertAll("SABOTAGE — THE RADIO TOWER LADDER WAS TORN DOWN / RADIO TOWER")
end

---------------------------------------------------------------- looking down the well
endPeek = function(p, result)
	local data = peeking[p]
	if not data then return end
	peeking[p] = nil
	local h = data.humanoid
	if h and h.Parent then
		h.WalkSpeed = data.speed h.JumpHeight = data.jumpHeight h.JumpPower = data.jumpPower h.AutoRotate = data.autoRotate
	end
	if data.conn then data.conn:Disconnect() end
	if p.Parent then remote:FireClient(p, "peekEnd", result) end
end
local function startPeek(p, zone)
	local c, h, r = alive(p)
	if not c or peeking[p] or busy[c] or p:GetAttribute("InRound") ~= true or config:GetAttribute("MeetingActive") == true then return end
	if flat(r.Position, zone.Position) > (zone:GetAttribute("Radius") or 6) then return end
	local data = { humanoid = h, speed = h.WalkSpeed, jumpHeight = h.JumpHeight, jumpPower = h.JumpPower, autoRotate = h.AutoRotate }
	peeking[p] = data
	h.WalkSpeed = 0 h.JumpHeight = 0 h.JumpPower = 0 h.AutoRotate = false
	data.conn = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function() if peeking[p] == data and h.WalkSpeed ~= 0 then h.WalkSpeed = 0 end end)
	pcall(function() r.CFrame = CFrame.lookAt(r.Position, Vector3.new(zone.Position.X, r.Position.Y, zone.Position.Z)) end)
	local seconds = config:GetAttribute("WellPeekSeconds")
	remote:FireClient(p, "peek", { centre = zone.Position, bottom = zone:GetAttribute("Bottom"), rim = zone:GetAttribute("RimRadius") or 3.45, rimHeight = zone:GetAttribute("RimHeight") or 3.9, seconds = seconds })
	task.delay(seconds, function()
		if peeking[p] ~= data then return end
		local found = bodiesIn(zone)
		local msg
		if #found == 0 then
			msg = "JUST DARK WATER DOWN THERE"
		else
			local bands = {}
			for _, b in found do local band = b:GetAttribute("BandName") if band and band ~= "" then table.insert(bands, string.upper(band)) end end
			msg = (#found == 1 and "THERE'S A BODY AT THE BOTTOM" or (#found .. " BODIES AT THE BOTTOM")) .. (#bands > 0 and (" — " .. table.concat(bands, ", ") .. " BAND" .. (#bands > 1 and "S" or "")) or "")
		end
		endPeek(p, msg)
	end)
end
local function setupZone(zone)
	if not zone:IsA("BasePart") then return end
	if not zone:GetAttribute("ZoneId") then zone:SetAttribute("ZoneId", zone:GetFullName()) end
	if zone:GetAttribute("Kind") == "Well" then
		local pr = zone:FindFirstChild("PeekPrompt") or Instance.new("ProximityPrompt")
		pr.Name = "PeekPrompt" pr.ActionText = "Look down" pr.ObjectText = "The well" pr.HoldDuration = 0.5
		pr.MaxActivationDistance = 8 pr.RequiresLineOfSight = false pr.Parent = zone
		pr.Triggered:Connect(function(p) startPeek(p, zone) end)
	end
end
for _, z in Tags:GetTagged("KillSpot") do setupZone(z) end
Tags:GetInstanceAddedSignal("KillSpot"):Connect(setupZone)

remote.OnServerEvent:Connect(function(p, action, arg)
	if action == "sabotage" then sabotage(p, arg)
	elseif action == "push" then push(p, arg)
	elseif action == "ladder" then wreckLadder(p)
	elseif action == "hello" then sendCooldowns(p) end
end)

---------------------------------------------------------------- rounds, cleanup, and keeping the mask off the killer's face by day
local function clearRound()
	bodies:ClearAllChildren()
	ready = {}
	local list = {} for p in peeking do table.insert(list, p) end
	for _, p in list do endPeek(p, nil) end
end
Rescue.RoundStarted.Event:Connect(clearRound)
config:GetAttributeChangedSignal("MatchActive"):Connect(function() if config:GetAttribute("MatchActive") ~= true then clearRound() end end)
Players.PlayerRemoving:Connect(function(p) peeking[p] = nil ready[p] = nil end)

-- server-only test hook (ServerStorage is never sent to clients): push an NPC victim
local hook = game:GetService("ServerStorage"):FindFirstChild("KillerAbilitiesTest") or Instance.new("BindableFunction")
hook.Name = "KillerAbilitiesTest"
hook.Parent = game:GetService("ServerStorage")
hook.OnInvoke = function(action, killer, victimChar)
	if action == "pushNPC" then
		local zone = zoneAt(victimChar.HumanoidRootPart.Position)
		if not zone then return false, "victim not in a kill spot" end
		task.spawn(zone:GetAttribute("Kind") == "Tower" and pushOffTower or pushIntoWell, killer, nil, victimChar, zone)
		return true
	end
end

task.spawn(function()
	while true do
		local holder = Mask.GetHolder()
		local c = holder and holder.Character
		local worn = c and c:FindFirstChild("WornMask")
		-- leave it alone while the creature form is hiding everything at night
		if worn and not c:FindFirstChild("MaskCreature") then
			local day = Lighting:GetAttribute("Phase") ~= "Night"
			for _, d in worn:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then
					if d:GetAttribute("BaseTransparency") == nil then d:SetAttribute("BaseTransparency", d.Transparency) end
					local want = day and 1 or d:GetAttribute("BaseTransparency")
					if d.Transparency ~= want then d.Transparency = want end
				end
			end
		end
		-- a peeker who dies or leaves the spot stops peeking
		for p, data in peeking do
			if not data.humanoid.Parent or data.humanoid.Health <= 0 then endPeek(p, nil) end
		end
		task.wait(0.4)
	end
end)
