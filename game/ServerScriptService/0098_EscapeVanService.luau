-- EscapeVanService (ModuleScript; started by EscapeVanBootstrap, used by ReadyQueueServer) — how a round ends.
-- The escape vehicle is a yellow camp bus (ServerStorage.EscapeVanKit.Bus; the old van is kept beside it as Van).
-- The code still says "van" for the vehicle, and its attributes keep their Van* names so nothing else breaks.
-- When every task on both lists is done (ForestRescueService sets MaskSystem.RescueWon), the van starts up:
--   * It pulls in at a random spot (workspace.EscapeVanSpots), engine running, lights on, and everyone is told
--     "THE VAN IS RUNNING — GET TO IT BEFORE THE KILLER CATCHES YOU".
--   * Survivors hold "Get in" at the sliding door. They're out of the round from then on, sat in the van, safe.
--   * After 3 minutes it drives off and turns up once more somewhere else, far away, so the killer can't camp it.
--   * After 5 minutes in all it leaves for good. Anyone not on board is left behind.
-- The survivors win if at least one of them got away; otherwise the killer does. The clock stops during meetings.
-- MaskSystem attributes for clients: VanState ("Running" | "Gone" | nil), VanEndsAt / VanMovesAt (server time),
-- VanPaused, VanEscaped (how many got away). Client side: StarterPlayerScripts.EscapeVanClient.
local V = {}
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Rescue = require(script.Parent:WaitForChild("ForestRescueService"))
local config = workspace:WaitForChild("MaskSystem")
local kit = game:GetService("ServerStorage"):WaitForChild("EscapeVanKit"):WaitForChild("Bus")
local spotsFolder = workspace:WaitForChild("EscapeVanSpots")
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local remote = remotes:FindFirstChild("EscapeVan") or Instance.new("RemoteEvent")
remote.Name = "EscapeVan"
remote.Parent = remotes
local Tower = nil
task.spawn(function()
	local m = script.Parent:WaitForChild("RadioTowerService", 20)
	if m then Tower = require(m) end
end)

local TOTAL = 300   -- seconds the van waits, in all
local MOVE_AT = 180 -- it moves once, after this long
local FAR = 140     -- the second spot is at least this far from the first (when there's one that far)
local SIT_ANIM = "http://www.roblox.com/asset/?id=2506281703"
-- where passengers sit, relative to the bus's pivot (on the ground under its middle; x right, y up, -z forward):
-- the bus's bench seats either side of the aisle, front rows first (seat tops 4.7 up, so a sitting root is at 6.3)
local SEATS = {}
for _, z in { -5.2, -2.2, 0.8, 3.8, 6.8, 9.8 } do
	table.insert(SEATS, Vector3.new(2.3, 6.3, z))
	table.insert(SEATS, Vector3.new(-2.3, 6.3, z))
end
local rng = Random.new()

local van, prompt, vanCF
local phase = nil        -- nil | "Arriving" | "Running" | "Moving" | "Leaving" | "Gone"
local elapsed, moved, outcome = 0, false, nil
local passengers = {}    -- [player] = {char, root, humanoid, seat, track}
local escapedCount = 0
local firstSpot = nil

local function alive(p)
	local c = p and p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and h.Health > 0 and r then return c, h, r end
end
local function survivor(p) return p:GetAttribute("InRound") == true and p:GetAttribute("Role") ~= "Killer" and not p:GetAttribute("HasMask") end
local function now() return workspace:GetServerTimeNow() end

---------------------------------------------------------------- the van itself
local function placeAll(cf)
	vanCF = cf
	if van then van:PivotTo(cf) end
	for _, e in passengers do
		if e.root.Parent then e.root.CFrame = cf * CFrame.new(SEATS[e.seat]) end
	end
end
-- slide the van (and everyone in it) from where it is to `target`
local function drive(from, target, seconds, style, dir)
	local value = Instance.new("CFrameValue")
	value.Value = from
	value.Changed:Connect(placeAll)
	local tw = TweenService:Create(value, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), { Value = target })
	tw:Play()
	tw.Completed:Wait()
	value:Destroy()
	placeAll(target)
end
local function engine(on)
	if not van then return end
	for _, d in van:GetDescendants() do
		if d:IsA("Light") then d.Enabled = on
		elseif d:IsA("ParticleEmitter") then d.Enabled = on
		elseif d:IsA("Sound") and d.Name == "EngineIdle" then if on then d:Play() else d:Stop() end
		elseif d:IsA("BasePart") and (d.Name == "Headlight" or d.Name == "Taillight") then
			d.Material = on and Enum.Material.Neon or Enum.Material.Glass
			if d.Name == "Headlight" then d.Color = on and Color3.fromRGB(255, 236, 196) or Color3.fromRGB(205, 205, 190)
			else d.Color = on and Color3.fromRGB(255, 40, 30) or Color3.fromRGB(90, 16, 14) end
		end
	end
end
local function pickSpot(awayFrom)
	local list = spotsFolder:GetChildren()
	if awayFrom then
		local far = {}
		for _, s in list do if (s.Position - awayFrom).Magnitude >= FAR then table.insert(far, s) end end
		if #far == 0 then
			table.sort(list, function(a, b) return (a.Position - awayFrom).Magnitude > (b.Position - awayFrom).Magnitude end)
			far = { list[1], list[2] }
		end
		list = far
	end
	return list[rng:NextInteger(1, #list)]
end
local function publish()
	config:SetAttribute("VanState", (phase == "Gone" and "Gone") or (phase and "Running") or nil)
	if phase and phase ~= "Gone" then
		config:SetAttribute("VanEndsAt", now() + math.max(0, TOTAL - elapsed))
		config:SetAttribute("VanMovesAt", not moved and (now() + math.max(0, MOVE_AT - elapsed)) or nil)
	else
		config:SetAttribute("VanEndsAt", nil)
		config:SetAttribute("VanMovesAt", nil)
	end
	config:SetAttribute("VanPaused", config:GetAttribute("MeetingActive") == true)
	config:SetAttribute("VanEscaped", escapedCount)
end

---------------------------------------------------------------- getting in
local sitAnim = Instance.new("Animation")
sitAnim.AnimationId = SIT_ANIM
local function freeSeat()
	local used = {}
	for _, e in passengers do used[e.seat] = true end
	for i = 1, #SEATS do if not used[i] then return i end end
	return rng:NextInteger(1, #SEATS)
end
local function board(p)
	if passengers[p] or not van or (phase ~= "Running" and phase ~= "Arriving") then return end
	local c, h, r = alive(p)
	if not c or not survivor(p) or config:GetAttribute("MeetingActive") == true then
		if c and (p:GetAttribute("Role") == "Killer" or p:GetAttribute("HasMask")) then remote:FireClient(p, "notice", "NOT WITHOUT THEM") end
		return
	end
	local door = van.Body:FindFirstChild("Door")
	if not door or (r.Position - door.WorldPosition).Magnitude > 12 then return end
	if Tower then pcall(Tower.Drop, p) end
	escapedCount += 1
	p:SetAttribute("Escaped", true)
	p:SetAttribute("InRound", false) -- out of the round: nothing can target them any more
	local ff = Instance.new("ForceField") ff.Name = "EscapedSafe" ff.Visible = false ff.Parent = c
	pcall(function() r:SetNetworkOwner(nil) end)
	h.AutoRotate = false
	r.Anchored = true
	local e = { char = c, root = r, humanoid = h, seat = freeSeat(), autoRotate = true }
	passengers[p] = e
	r.CFrame = vanCF * CFrame.new(SEATS[e.seat])
	local animator = h:FindFirstChildOfClass("Animator")
	if animator then
		pcall(function()
			e.track = animator:LoadAnimation(sitAnim)
			e.track.Priority = Enum.AnimationPriority.Action
			e.track.Looped = true
			e.track:Play(0.2)
		end)
	end
	publish()
	remote:FireClient(p, "escaped")
	remote:FireAllClients("boarded", { name = p.DisplayName, band = p:GetAttribute("BandName") })
end
local function unboard(p, e)
	passengers[p] = nil
	if e.track then pcall(function() e.track:Stop(0.1) end) end
	if e.char.Parent then
		local ff = e.char:FindFirstChild("EscapedSafe") if ff then ff:Destroy() end
	end
	if e.root.Parent then
		e.root.Anchored = false
		e.root.AssemblyLinearVelocity = Vector3.zero
		if p.Parent then pcall(function() e.root:SetNetworkOwner(p) end) end
	end
	if e.humanoid.Parent then e.humanoid.AutoRotate = true end
	if p.Parent then p:SetAttribute("Escaped", nil) end
end

---------------------------------------------------------------- the escape, start to finish
local function spawnVan(spot)
	van = kit:Clone()
	van.Name = "EscapeVan"
	van.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- everyone can see where it is, from anywhere
	local door = van.Body:FindFirstChild("Door")
	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GetInPrompt" prompt.ActionText = "Get on" prompt.ObjectText = "Camp bus"
	prompt.HoldDuration = 1 prompt.MaxActivationDistance = 9 prompt.RequiresLineOfSight = false
	prompt.Parent = door or van.Body
	prompt.Triggered:Connect(board)
	local start = spot.CFrame * CFrame.new(0, 0, 40) -- pulls in from behind
	van:PivotTo(start)
	vanCF = start
	van.Parent = workspace
	engine(true)
	phase = "Arriving"
	drive(start, spot.CFrame, 2.6)
	if phase == "Arriving" then phase = "Running" end
end
function V.Start()
	if phase then return end
	elapsed, moved, outcome, escapedCount = 0, false, nil, 0
	local spot = pickSpot()
	firstSpot = spot.Position
	phase = "Arriving"
	publish()
	remote:FireAllClients("start")
	task.spawn(spawnVan, spot)
end
local function relocate()
	moved = true
	phase = "Moving"
	publish()
	if prompt then prompt.Enabled = false end
	remote:FireAllClients("moving")
	-- drive off down the track, then turn up at the far spot
	drive(vanCF, vanCF * CFrame.new(0, 0, -44), 2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local spot = pickSpot(firstSpot)
	local start = spot.CFrame * CFrame.new(0, 0, 40)
	placeAll(start)
	drive(start, spot.CFrame, 2.6)
	if phase ~= "Moving" then return end
	phase = "Running"
	if prompt then prompt.Enabled = true end
	publish()
	remote:FireAllClients("moved")
end
local function leave()
	phase = "Leaving"
	if prompt then prompt.Enabled = false end
	remote:FireAllClients("leaving")
	drive(vanCF, vanCF * CFrame.new(0, 0, -80), 4.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if phase ~= "Leaving" then return end -- the round was reset while it drove off
	phase = "Gone"
	outcome = escapedCount > 0 and "Innocents" or "Monster"
	publish()
	remote:FireAllClients("gone", { escaped = escapedCount })
end
function V.Reset()
	local list = {}
	for p, e in passengers do table.insert(list, { p, e }) end
	for _, pe in list do unboard(pe[1], pe[2]) end
	if van then van:Destroy() van = nil end
	prompt, vanCF, phase, elapsed, moved, outcome, escapedCount, firstSpot = nil, nil, nil, 0, false, nil, 0, nil
	publish()
end
-- ReadyQueueServer asks these every tick
function V.Outcome() return outcome end
function V.AnyEscaped() return escapedCount > 0 end
function V.Phase() return phase end

Rescue.RoundStarted.Event:Connect(V.Reset)
Rescue.RoundEnded.Event:Connect(V.Reset)
config:GetAttributeChangedSignal("MatchActive"):Connect(function() if config:GetAttribute("MatchActive") ~= true then V.Reset() end end)
Players.PlayerRemoving:Connect(function(p) passengers[p] = nil end)

-- the clock: runs while the van waits, stops for meetings
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	if not phase or phase == "Gone" or phase == "Leaving" then return end
	if config:GetAttribute("MeetingActive") == true then
		acc += dt
		if acc > 0.5 then acc = 0 publish() end -- keeps the end time sliding while paused
		return
	end
	elapsed += dt
	acc += dt
	if acc > 1 then acc = 0 publish() end
	if phase == "Running" then
		if not moved and elapsed >= MOVE_AT then task.spawn(relocate)
		elseif elapsed >= TOTAL then task.spawn(leave) end
	end
end)
-- start the van once both task lists are done
task.spawn(function()
	while true do
		task.wait(0.25)
		if not phase and config:GetAttribute("MatchActive") == true and config:GetAttribute("RescueWon") == true then V.Start() end
	end
end)
V.Reset()

-- server-only test hook
local hook = game:GetService("ServerStorage"):FindFirstChild("EscapeVanTest") or Instance.new("BindableFunction")
hook.Name = "EscapeVanTest"
hook.Parent = game:GetService("ServerStorage")
hook.OnInvoke = function(action, arg)
	if action == "start" then V.Start() return true
	elseif action == "skip" then elapsed = math.max(elapsed, (arg or 0)) return elapsed
	elseif action == "board" then board(arg) return passengers[arg] ~= nil
	elseif action == "state" then return { phase = phase, elapsed = elapsed, moved = moved, outcome = outcome, escaped = escapedCount, at = vanCF and vanCF.Position }
	elseif action == "reset" then V.Reset() return true
	end
end

return V
