-- RadioTowerService (ModuleScript; started by RadioTowerBootstrap, also used by KillerAbilities)
-- The radio tower west of the middle of the map (built by ServerStorage.RadioTowerBuilder).
--   * Task 19, the transmitter on the platform, starts LOCKED: its module socket is empty. Each round a spare
--     transmitter module turns up beside one of the other stations. Carry it up the ladder and fit it, and the
--     task opens like any other station.
--   * The killer can tear the ladder down, twice per match, by day (KillerAbilities calls T.Wreck). Nobody gets up
--     or down until a toolbox and a bundle of new rungs (they turn up beside two stations) are carried to the
--     foot of the ladder and someone holds "Repair ladder".
--   * "Climb down" at the top lowers you down the ladder on a script, so nobody drops through the notch.
--   * A long fall at the tower hurts, and from high enough it kills.
-- Carried items are never Tools: like the cemetery shovel they're welded to the right hand. While holding one the
-- player has the attribute "Carrying" = "Module" | "Toolbox" | "Rungs". One item at a time.
local T = {}
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Rescue = require(script.Parent:WaitForChild("ForestRescueService"))
local config = workspace:WaitForChild("MaskSystem")
local tower = workspace:WaitForChild("RadioTower")
local ladder = tower:WaitForChild("Ladder")
local rungsFolder = ladder:WaitForChild("Rungs")
local base = ladder:WaitForChild("LadderBase")
local top = ladder:WaitForChild("LadderTop")
local spots = tower:WaitForChild("ItemSpots")
local task19 = workspace:WaitForChild("ForestRescueTasks"):WaitForChild("Task19")
local socket = task19:WaitForChild("Socket")
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local remote = remotes:FindFirstChild("RadioTower") or Instance.new("RemoteEvent")
remote.Name = "RadioTower"
remote.Parent = remotes

local WRECKS_PER_MATCH = 2
local WRECK_LOW, WRECK_HIGH = 3.5, 23.5   -- rungs between these heights come off
local REPAIR_HOLD = 7
local DESCEND_SPEED = 10                  -- studs per second
local FALL_SAFE, FALL_LETHAL = 20, 44     -- studs
local CENTRE = tower:GetAttribute("Centre")
local OUT = Vector3.new(0, 0, 1)          -- the climbing side of the ladder (north, away from the face)
local rng = Random.new()

local function notice(p, msg) if p and p.Parent and msg then remote:FireClient(p, "notice", msg) end end
local function alive(p)
	local c = p and p.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and h.Health > 0 and r then return c, h, r end
end
local function flat(a, b) return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude end
local function survivor(p) return p:GetAttribute("InRound") == true and p:GetAttribute("Role") ~= "Killer" and not p:GetAttribute("HasMask") end
local function sound(parent, id, volume, speed)
	local s = Instance.new("Sound") s.SoundId = id s.Volume = volume s.PlaybackSpeed = speed or 1 s.RollOffMaxDistance = 120 s.Parent = parent
	s:Play() game:GetService("Debris"):AddItem(s, 5)
end
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude
groundRay.RespectCanCollide = true
local function groundBelow(pos, ignore)
	groundRay.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -300, 0), groundRay)
	return hit and hit.Position or Vector3.new(pos.X, pos.Y - 3, pos.Z)
end

---------------------------------------------------------------- item models (small props built from parts)
local function piece(model, name, size, cf, colour, material, shape)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = colour p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true p.CanCollide = false p.CanTouch = false p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = model
	return p
end
local MAKERS = {}
function MAKERS.Module()
	local m = Instance.new("Model") m.Name = "TransmitterModule"
	local o = CFrame.new()
	local body = piece(m, "Body", Vector3.new(0.9, 0.62, 0.2), o, Color3.fromRGB(58, 62, 64), Enum.Material.Metal)
	m.PrimaryPart = body
	piece(m, "Board", Vector3.new(0.78, 0.5, 0.03), o * CFrame.new(0, 0.02, -0.11), Color3.fromRGB(34, 96, 54))
	for i, x in { -0.22, 0.05, 0.27 } do
		piece(m, "Chip", Vector3.new(i == 2 and 0.2 or 0.13, 0.12, 0.03), o * CFrame.new(x, 0.1, -0.13), Color3.fromRGB(22, 22, 24))
	end
	piece(m, "Capacitor", Vector3.new(0.07, 0.1, 0.07), o * CFrame.new(-0.25, -0.12, -0.15), Color3.fromRGB(40, 70, 150), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece(m, "Pins", Vector3.new(0.7, 0.07, 0.05), o * CFrame.new(0, -0.33, 0), Color3.fromRGB(204, 170, 80), Enum.Material.Metal)
	piece(m, "Handle", Vector3.new(0.5, 0.06, 0.08), o * CFrame.new(0, 0.38, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local led = piece(m, "LED", Vector3.new(0.06, 0.06, 0.06), o * CFrame.new(0.3, -0.16, -0.13), Color3.fromRGB(120, 255, 140), Enum.Material.Neon, Enum.PartType.Ball)
	local glow = Instance.new("PointLight") glow.Name = "Glow" glow.Color = Color3.fromRGB(120, 255, 150) glow.Range = 5 glow.Brightness = 0.8 glow.Parent = led
	-- lying on its back, board up
	return m, "Spare transmitter module", CFrame.new(0, -0.4, -0.15) * CFrame.Angles(0, math.pi / 2, 0), CFrame.Angles(math.rad(90), 0, 0)
end
function MAKERS.Toolbox()
	local m = Instance.new("Model") m.Name = "Toolbox"
	local o = CFrame.new()
	local body = piece(m, "Body", Vector3.new(1.3, 0.5, 0.55), o, Color3.fromRGB(176, 36, 30), Enum.Material.Metal)
	m.PrimaryPart = body
	piece(m, "Lid", Vector3.new(1.32, 0.12, 0.57), o * CFrame.new(0, 0.31, 0), Color3.fromRGB(150, 30, 26), Enum.Material.Metal)
	for _, x in { -0.42, 0.42 } do
		piece(m, "Latch", Vector3.new(0.12, 0.14, 0.04), o * CFrame.new(x, 0.2, -0.29), Color3.fromRGB(190, 192, 194), Enum.Material.Metal)
		piece(m, "HandlePost", Vector3.new(0.05, 0.2, 0.05), o * CFrame.new(x * 0.6, 0.47, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	end
	piece(m, "Handle", Vector3.new(0.6, 0.06, 0.08), o * CFrame.new(0, 0.58, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	return m, "Toolbox", CFrame.new(0, -0.62, -0.05) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new()
end
function MAKERS.Rungs()
	local m = Instance.new("Model") m.Name = "LadderRungs"
	local o = CFrame.new()
	local core = piece(m, "Core", Vector3.new(1.9, 0.2, 0.2), o, Color3.fromRGB(150, 154, 156), Enum.Material.Metal, Enum.PartType.Cylinder)
	m.PrimaryPart = core
	for _, off in { Vector3.new(0, 0, 0.21), Vector3.new(0, 0, -0.21), Vector3.new(0, 0.19, 0.105), Vector3.new(0, 0.19, -0.105) } do
		piece(m, "Rung", Vector3.new(1.9, 0.2, 0.2), o + off, Color3.fromRGB(150, 154, 156), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	for _, x in { -0.55, 0.55 } do
		piece(m, "Strap", Vector3.new(0.08, 0.46, 0.66), o * CFrame.new(x, 0.08, 0), Color3.fromRGB(110, 78, 46), Enum.Material.Fabric)
	end
	return m, "Ladder rungs", CFrame.new(0, -0.32, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new()
end

---------------------------------------------------------------- items: lying about, carried, delivered
local items = {} -- [kind] = {kind, model, main, label, hold, prompt, state = "lying"|"carried"|"placed"|"fitted", carrier, weld, conns}
local carriers = {} -- [player] = item
local function setLabel(it, on)
	local bb = it.main:FindFirstChild("ItemLabel")
	if bb then bb.Enabled = on end
end
local function anchorAll(it, anchored)
	for _, d in it.model:GetDescendants() do if d:IsA("BasePart") then d.Anchored = anchored d.AssemblyLinearVelocity = Vector3.zero end end
end
-- the lowest point of a model in world space
local function lowestY(model)
	local lo = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf, s = d.CFrame, d.Size / 2
			local ey = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
			lo = math.min(lo, cf.Position.Y - ey)
		end
	end
	return lo
end
-- where the pivot goes so the item rests on the ground at pos
local function restCFrame(it, pos, yaw)
	return CFrame.new(pos + Vector3.new(0, it.lift, 0)) * CFrame.Angles(0, yaw or rng:NextNumber(0, math.pi * 2), 0) * it.rest
end
local function layAt(it, pos, yaw)
	if it.weld then it.weld:Destroy() it.weld = nil end
	anchorAll(it, true)
	it.model:PivotTo(restCFrame(it, pos, yaw))
	it.model.Parent = tower
	it.state = "lying"
	it.prompt.Enabled = true
	setLabel(it, true)
end
local function freeSpot(avoidSites)
	local list = {}
	for _, s in spots:GetChildren() do
		local used = false
		for _, it in items do if it.spot == s and it.state ~= "fitted" then used = true end end
		if not used and not (avoidSites and avoidSites[s:GetAttribute("Site")]) then table.insert(list, s) end
	end
	if #list == 0 then list = spots:GetChildren() end
	return list[rng:NextInteger(1, #list)]
end
local function disconnect(it) for _, c in it.conns or {} do c:Disconnect() end it.conns = {} end
local release
local function destroyItem(kind)
	local it = items[kind]
	if not it then return end
	if it.carrier then release(it.carrier, nil, true) end
	disconnect(it)
	it.model:Destroy()
	items[kind] = nil
end
local function makeItem(kind, spot)
	destroyItem(kind)
	local model, label, hold, rest = MAKERS[kind]()
	local it = { kind = kind, model = model, main = model.PrimaryPart, label = label, hold = hold, rest = rest, conns = {} }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= it.main then
			local w = Instance.new("WeldConstraint") w.Part0 = it.main w.Part1 = d w.Parent = d
		end
	end
	model:PivotTo(rest)
	it.lift = -lowestY(model) + 0.02
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "PickUpPrompt" pr.ActionText = "Pick up" pr.ObjectText = label
	pr.HoldDuration = 0.35 pr.MaxActivationDistance = 8 pr.RequiresLineOfSight = false
	pr.Parent = it.main
	it.prompt = pr
	-- a small name tag so it can be spotted from a few steps away
	local bb = Instance.new("BillboardGui")
	bb.Name = "ItemLabel" bb.Size = UDim2.fromOffset(170, 22) bb.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0) bb.MaxDistance = 28 bb.LightInfluence = 0
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.Oswald t.TextSize = 15
	t.TextColor3 = Color3.fromRGB(232, 229, 218) t.TextStrokeTransparency = 0.35 t.Text = string.upper(label) t.Parent = bb
	bb.Parent = it.main
	items[kind] = it
	pr.Triggered:Connect(function(p) T.PickUp(p, it) end)
	it.spot = spot
	layAt(it, spot.Position)
	return it
end
-- drop whatever p is holding where they stand (or, when `keep` is set, just let go of it: the caller moves it)
release = function(p, at, keep)
	local it = carriers[p]
	if not it then return end
	carriers[p] = nil
	it.carrier = nil
	disconnect(it)
	if p.Parent then p:SetAttribute("Carrying", nil) end
	if keep then
		if it.weld then it.weld:Destroy() it.weld = nil end
		anchorAll(it, true)
		return it
	end
	local c = p.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local from = at or (r and r.Position) or it.main.Position
	local g = groundBelow(from, { c, it.model })
	it.spot = nil
	layAt(it, g)
	return it
end
function T.PickUp(p, it)
	if items[it.kind] ~= it or it.state ~= "lying" then return end
	local c, h, r = alive(p)
	if not c or not survivor(p) or config:GetAttribute("MatchActive") ~= true then
		if c and p:GetAttribute("Role") == "Killer" then notice(p, "LEAVE IT — SOMEONE MIGHT SEE YOU") end
		return
	end
	if carriers[p] or p:GetAttribute("CarryingShovel") then notice(p, "YOUR HANDS ARE FULL") return end
	local hand = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
	if not hand or (r.Position - it.main.Position).Magnitude > 11 then return end
	carriers[p] = it
	it.carrier = p
	it.state = "carried"
	it.spot = nil
	it.prompt.Enabled = false
	setLabel(it, false)
	-- in the hand first, then unanchored, then welded (see GraveyardService: the other way round yanks the player)
	it.model:PivotTo(hand.CFrame * it.hold)
	anchorAll(it, false)
	local w = Instance.new("Weld") w.Name = "CarryGrip" w.Part0 = hand w.Part1 = it.main w.C0 = it.hold w.Parent = it.main
	it.weld = w
	p:SetAttribute("Carrying", it.kind)
	table.insert(it.conns, h.Died:Connect(function() if carriers[p] == it then release(p) end end))
	table.insert(it.conns, p.CharacterRemoving:Connect(function() if carriers[p] == it then release(p) end end))
	table.insert(it.conns, p:GetAttributeChangedSignal("InRound"):Connect(function() if not p:GetAttribute("InRound") and carriers[p] == it then release(p) end end))
	local hints = {
		Module = "SPARE TRANSMITTER MODULE — TAKE IT UP THE RADIO TOWER",
		Toolbox = "TOOLBOX — BRING IT TO THE FOOT OF THE RADIO TOWER LADDER",
		Rungs = "LADDER RUNGS — BRING THEM TO THE FOOT OF THE RADIO TOWER LADDER",
	}
	notice(p, hints[it.kind])
end
function T.Drop(p) release(p) end
function T.IsBusy(char) return char and char:GetAttribute("OnLadder") == true end

---------------------------------------------------------------- the transmitter module and task 19
local fitPrompt = socket:FindFirstChild("FitPrompt") or Instance.new("ProximityPrompt")
fitPrompt.Name = "FitPrompt" fitPrompt.ActionText = "Fit module" fitPrompt.ObjectText = "Transmitter socket"
fitPrompt.HoldDuration = 1 fitPrompt.MaxActivationDistance = 7 fitPrompt.RequiresLineOfSight = false
fitPrompt.UIOffset = Vector2.new(0, -60)
fitPrompt.Parent = socket
local function setLocked(locked)
	task19:SetAttribute("Locked", locked)
	task19:SetAttribute("NeedsPart", locked)
	fitPrompt.Enabled = locked
	Rescue.Refresh()
end
fitPrompt.Triggered:Connect(function(p)
	local c, _, r = alive(p)
	if not c or not task19:GetAttribute("Locked") or (r.Position - socket.Position).Magnitude > 10 then return end
	local it = carriers[p]
	if not it or it.kind ~= "Module" then
		notice(p, p:GetAttribute("Role") == "Killer" and "THE SOCKET IS EMPTY" or "THE TRANSMITTER IS MISSING A MODULE — FIND THE SPARE ONE AROUND CAMP")
		return
	end
	release(p, nil, true)
	it.state = "fitted"
	it.prompt.Enabled = false
	setLabel(it, false)
	it.model:PivotTo(socket.ModuleSeat.WorldCFrame)
	it.model.Parent = task19
	sound(socket, "rbxasset://sounds/electronicpingshort.wav", 0.7, 1.2)
	setLocked(false)
	notice(p, "MODULE FITTED — NOW REPAIR THE TRANSMITTER")
end)

---------------------------------------------------------------- the ladder: wrecking and repairing
local debrisFolder = tower:FindFirstChild("LadderDebris") or Instance.new("Folder")
debrisFolder.Name = "LadderDebris"
debrisFolder.Parent = tower
local status = base:FindFirstChild("LadderStatus") or Instance.new("BillboardGui")
status.Name = "LadderStatus" status.Size = UDim2.fromOffset(260, 58) status.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
status.MaxDistance = 70 status.LightInfluence = 0 status.Enabled = false status.Parent = base
local statusTitle = status:FindFirstChild("Title") or Instance.new("TextLabel")
statusTitle.Name = "Title" statusTitle.Size = UDim2.new(1, 0, 0, 30) statusTitle.BackgroundTransparency = 1 statusTitle.Font = Enum.Font.Oswald statusTitle.TextSize = 22
statusTitle.TextColor3 = Color3.fromRGB(235, 70, 60) statusTitle.TextStrokeTransparency = 0.3 statusTitle.Text = "LADDER TORN DOWN" statusTitle.Parent = status
local statusNeeds = status:FindFirstChild("Needs") or Instance.new("TextLabel")
statusNeeds.Name = "Needs" statusNeeds.Position = UDim2.fromOffset(0, 30) statusNeeds.Size = UDim2.new(1, 0, 0, 24) statusNeeds.BackgroundTransparency = 1
statusNeeds.Font = Enum.Font.Oswald statusNeeds.TextSize = 16 statusNeeds.TextColor3 = Color3.fromRGB(232, 229, 218) statusNeeds.TextStrokeTransparency = 0.35 statusNeeds.Parent = status
local repairPrompt = base:FindFirstChild("RepairPrompt") or Instance.new("ProximityPrompt")
repairPrompt.Name = "RepairPrompt" repairPrompt.ActionText = "Repair ladder" repairPrompt.ObjectText = "Radio tower ladder"
repairPrompt.HoldDuration = REPAIR_HOLD repairPrompt.MaxActivationDistance = 8 repairPrompt.RequiresLineOfSight = false repairPrompt.Enabled = false
repairPrompt.Parent = base
local downPrompt = top:FindFirstChild("ClimbDownPrompt") or Instance.new("ProximityPrompt")
downPrompt.Name = "ClimbDownPrompt" downPrompt.ActionText = "Climb down" downPrompt.ObjectText = "Ladder"
downPrompt.HoldDuration = 0.25 downPrompt.MaxActivationDistance = 6 downPrompt.RequiresLineOfSight = false
downPrompt.Parent = top

local function delivered(kind) local it = items[kind] return it ~= nil and it.state == "placed" end
local function refreshLadder()
	local wrecked = ladder:GetAttribute("Wrecked") == true
	status.Enabled = wrecked
	local tb, rg = delivered("Toolbox"), delivered("Rungs")
	statusNeeds.Text = tb and rg and "READY TO REPAIR" or tb and "STILL NEEDS LADDER RUNGS" or rg and "STILL NEEDS A TOOLBOX" or "NEEDS A TOOLBOX AND LADDER RUNGS"
	repairPrompt.Enabled = wrecked and delivered("Toolbox") and delivered("Rungs")
	downPrompt.Enabled = not wrecked
end
local function placeAtBase(it, side)
	it.state = "placed"
	it.prompt.Enabled = false
	setLabel(it, false)
	local at = base.Position + Vector3.new(side * 1.7, 0, 0.8)
	local g = groundBelow(at, { it.model })
	it.model:PivotTo(restCFrame(it, g, math.rad(side * 20)))
	it.model.Parent = tower
end
function T.CanWreck()
	return ladder:GetAttribute("Wrecked") ~= true and (ladder:GetAttribute("WrecksLeft") or 0) > 0
end
function T.WrecksLeft() return ladder:GetAttribute("WrecksLeft") or 0 end
-- Called by KillerAbilities once it has checked the killer, the range, daylight and the cooldown.
function T.Wreck()
	if not T.CanWreck() then return false end
	ladder:SetAttribute("Wrecked", true)
	ladder:SetAttribute("WrecksLeft", T.WrecksLeft() - 1)
	local dangling = 0
	for _, rung in rungsFolder:GetChildren() do
		local hgt = rung:GetAttribute("Height") or 0
		if hgt >= WRECK_LOW and hgt <= WRECK_HIGH then
			-- most rungs come off and fall; a couple are left hanging from one rail
			if (math.abs(hgt - 9) < 0.5 or math.abs(hgt - 17) < 0.5) and dangling < 2 then
				dangling += 1
				local side = dangling == 1 and 1 or -1
				local pivot = rung.CFrame * CFrame.new(side * rung.Size.X / 2, 0, 0)
				rung.CFrame = pivot * CFrame.Angles(0, 0, math.rad(side * 58)) * CFrame.new(-side * rung.Size.X / 2, 0, 0)
				rung.CanCollide = false rung.CanQuery = false
			else
				local bit = rung:Clone()
				bit.Name = "BrokenRung"
				bit.Anchored = false bit.CanCollide = true bit.Massless = false
				bit.Parent = debrisFolder
				pcall(function() bit:SetNetworkOwner(nil) end)
				bit.AssemblyLinearVelocity = OUT * rng:NextNumber(3, 9) + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(0, 5), 0)
				bit.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
				rung.Transparency = 1 rung.CanCollide = false rung.CanQuery = false
			end
		end
	end
	-- let the pieces land, then pin them where they lie
	task.delay(6, function() for _, b in debrisFolder:GetChildren() do if b:IsA("BasePart") then b.Anchored = true end end end)
	for i = 1, 4 do task.delay((i - 1) * 0.18, function() sound(base, "rbxasset://sounds/collide.wav", 1, rng:NextNumber(0.55, 0.85)) end) end
	-- dust where the rungs tore off
	local att = Instance.new("Attachment") att.Name = "WreckDust" att.WorldPosition = base.Position + Vector3.new(0, 10, -1) att.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter") e.Texture = "rbxasset://textures/particles/smoke_main.dds" e.Enabled = false
	e.Color = ColorSequence.new(Color3.fromRGB(120, 112, 100)) e.Size = NumberSequence.new(1, 3) e.Transparency = NumberSequence.new(0.5, 1)
	e.Lifetime = NumberRange.new(1, 2) e.Speed = NumberRange.new(2, 5) e.SpreadAngle = Vector2.new(180, 180) e.Parent = att
	e:Emit(30)
	game:GetService("Debris"):AddItem(att, 4)
	-- the repair parts turn up beside two different stations
	local a = freeSpot()
	makeItem("Toolbox", a)
	makeItem("Rungs", freeSpot({ [a:GetAttribute("Site")] = true }))
	refreshLadder()
	return true
end
local function repairLadder()
	ladder:SetAttribute("Wrecked", false)
	for _, rung in rungsFolder:GetChildren() do
		local home = rung:GetAttribute("Home")
		if home then rung.CFrame = home end
		rung.Transparency = 0 rung.CanCollide = true rung.CanQuery = true
	end
	debrisFolder:ClearAllChildren()
	destroyItem("Toolbox")
	destroyItem("Rungs")
	refreshLadder()
end
repairPrompt.Triggered:Connect(function(p)
	local c, _, r = alive(p)
	if not c or not survivor(p) or ladder:GetAttribute("Wrecked") ~= true then return end
	if not (delivered("Toolbox") and delivered("Rungs")) or flat(r.Position, base.Position) > 10 then return end
	repairLadder()
	sound(base, "rbxasset://sounds/electronicpingshort.wav", 0.6, 0.8)
	notice(p, "LADDER REPAIRED")
	for _, q in Players:GetPlayers() do if q ~= p and q:GetAttribute("InRound") then notice(q, "THE RADIO TOWER LADDER HAS BEEN REPAIRED") end end
end)

---------------------------------------------------------------- climbing down (on a script)
local rb, rt = ladder:GetAttribute("RungBottom"), ladder:GetAttribute("RungTop")
local function lineAt(y) return rb:Lerp(rt, (y - rb.Y) / (rt.Y - rb.Y)) end
local climbAnim = Instance.new("Animation")
climbAnim.AnimationId = "http://www.roblox.com/asset/?id=507765644"
local function descend(p)
	local c, h, r = alive(p)
	if not c or c:GetAttribute("OnLadder") or c:GetAttribute("BeingPushed") or ladder:GetAttribute("Wrecked") then return end
	if (r.Position - top.Position).Magnitude > 9 then return end
	c:SetAttribute("OnLadder", true)
	local face = CFrame.lookAt(Vector3.zero, -OUT) -- facing the ladder
	local startY = rt.Y - 1.0
	local g = groundBelow(lineAt(rb.Y) + OUT * 1.4, { c, ladder })
	local endY = g.Y + h.HipHeight + r.Size.Y / 2 + 0.05
	local p0 = lineAt(startY) + OUT * 0.95
	local p1 = lineAt(endY) + OUT * 0.95
	pcall(function() r:SetNetworkOwner(nil) end)
	local autoRotate = h.AutoRotate
	h.AutoRotate = false
	r.Anchored = true
	local value = Instance.new("CFrameValue")
	value.Value = r.CFrame
	value.Changed:Connect(function(cf) if r.Parent then r.CFrame = cf end end)
	local track
	local animator = h:FindFirstChildOfClass("Animator")
	if animator then
		pcall(function()
			track = animator:LoadAnimation(climbAnim)
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
		end)
	end
	local ok = true
	local t0 = TweenService:Create(value, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = CFrame.new(p0) * face })
	t0:Play() t0.Completed:Wait()
	if track then track:Play(0.15) end
	local dist = (p0 - p1).Magnitude
	local t1 = TweenService:Create(value, TweenInfo.new(dist / DESCEND_SPEED, Enum.EasingStyle.Linear), { Value = CFrame.new(p1) * face })
	t1:Play()
	-- stop early if they die on the way down
	while t1.PlaybackState == Enum.PlaybackState.Playing do
		if h.Health <= 0 or not r.Parent then ok = false t1:Cancel() break end
		task.wait(0.1)
	end
	value:Destroy()
	if track then track:Stop(0.2) end
	if r.Parent then
		if ok then r.CFrame = CFrame.new(p1 + OUT * 0.6) * face end
		r.Anchored = false
		r.AssemblyLinearVelocity = Vector3.zero
		if p.Parent then pcall(function() r:SetNetworkOwner(p) end) end
	end
	if h.Parent then h.AutoRotate = autoRotate end
	if c.Parent then c:SetAttribute("OnLadder", nil) end
end
downPrompt.Triggered:Connect(function(p) task.spawn(descend, p) end)

---------------------------------------------------------------- long falls at the tower
local falling = {} -- [character] = {startY, falling}
task.spawn(function()
	while true do
		for _, p in Players:GetPlayers() do
			local c, h, r = alive(p)
			if c and not r.Anchored and flat(r.Position, CENTRE) < 16 then
				local f = falling[c]
				if not f then f = { startY = r.Position.Y, falling = false } falling[c] = f end
				local vy = r.AssemblyLinearVelocity.Y
				if not f.falling then
					if vy < -14 then f.falling = true else f.startY = r.Position.Y end
				elseif vy > -2 then
					local drop = f.startY - r.Position.Y
					f.falling = false
					f.startY = r.Position.Y
					if drop > FALL_SAFE and not c:GetAttribute("BeingPushed") then
						local damage = (drop - FALL_SAFE) / (FALL_LETHAL - FALL_SAFE) * 100
						h:TakeDamage(math.min(damage, h.Health))
						sound(r, "rbxasset://sounds/collide.wav", 0.8, 0.5)
					end
				end
			elseif c then
				falling[c] = nil
			end
		end
		for c in falling do if not c.Parent then falling[c] = nil end end
		task.wait(0.08)
	end
end)

---------------------------------------------------------------- rounds
local function deliverLoop()
	while true do
		task.wait(0.2)
		if ladder:GetAttribute("Wrecked") then
			for p, it in carriers do
				if it.kind == "Toolbox" or it.kind == "Rungs" then
					local c, _, r = alive(p)
					if c and flat(r.Position, base.Position) < 7 and math.abs(r.Position.Y - base.Position.Y) < 7 then
						release(p, nil, true)
						placeAtBase(it, it.kind == "Toolbox" and -1 or 1)
						notice(p, (it.kind == "Toolbox" and "TOOLBOX" or "RUNGS") .. " LEFT AT THE LADDER")
						refreshLadder()
					end
				end
			end
		end
	end
end
task.spawn(deliverLoop)

local function clearCarriers()
	local list = {}
	for p in carriers do table.insert(list, p) end
	for _, p in list do release(p) end
	for _, p in Players:GetPlayers() do if p:GetAttribute("Carrying") then p:SetAttribute("Carrying", nil) end end
end
local function resetRound()
	clearCarriers()
	repairLadder()
	ladder:SetAttribute("WrecksLeft", WRECKS_PER_MATCH)
	destroyItem("Module")
	for _, d in task19:GetChildren() do if d.Name == "TransmitterModule" then d:Destroy() end end
	setLocked(true)
	makeItem("Module", freeSpot())
end
local function endRound()
	clearCarriers()
	destroyItem("Toolbox")
	destroyItem("Rungs")
end
Rescue.RoundStarted.Event:Connect(resetRound)
Rescue.RoundEnded.Event:Connect(endRound)
Players.PlayerRemoving:Connect(function(p) if carriers[p] then release(p) end end)

-- outside a round the tower sits ready: ladder up, socket empty, module lying somewhere
ladder:SetAttribute("WrecksLeft", WRECKS_PER_MATCH)
repairLadder()
setLocked(true)
if not items.Module then makeItem("Module", freeSpot()) end

-- server-only test hook
local hook = game:GetService("ServerStorage"):FindFirstChild("RadioTowerTest") or Instance.new("BindableFunction")
hook.Name = "RadioTowerTest"
hook.Parent = game:GetService("ServerStorage")
hook.OnInvoke = function(action, arg)
	if action == "wreck" then return T.Wreck()
	elseif action == "repair" then repairLadder() return true
	elseif action == "items" then
		local out = {}
		for k, it in items do out[k] = { state = it.state, at = it.main.Position, carrier = it.carrier and it.carrier.Name } end
		return out
	elseif action == "reset" then resetRound() return true
	elseif action == "descend" then task.spawn(descend, arg) return true
	end
end

return T
