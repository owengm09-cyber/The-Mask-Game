-- FirstPersonHands: in first person, whatever you're holding is shown in YOUR hand at the bottom right of the screen.
-- The arm (a scaled-down copy of your counselor's own right arm, outfit and all) and how each item sits in it
-- come from ReplicatedStorage.ViewHands; this script finds what you're holding, builds that once, and keeps it locked to
-- the camera with a little walking bob. It covers tools (flashlight, key, bandage, battery, hatchet, flare gun) and things
-- carried in the hand (radio module, toolbox, ladder rungs, shovel...): anything joined to your right hand from outside
-- your character. The real items stay in your character's hand for everyone else; they're hidden only on your screen,
-- only while you're in first person (cutscenes and the escape camera show your real character).
-- The flashlight takes its beam from the copy's lens (camera > HeldViewModel > "p").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewHands = require(ReplicatedStorage:WaitForChild("ViewHands"))
local player = Players.LocalPlayer

local FIRST_PERSON = 1.6 -- camera this close to your head counts as first person
local CARRY_SCALE = 0.75 -- carried things (module, toolbox, shovel) are drawn a little smaller than tools
local BOB = 0.012 -- studs the hand bobs while you walk

local vm, offs, grip, real
local heldKey, heldKind, buildAt
local hiddenNow = false
local bobT, bobAmt = 0, 0

-- remove everything from a copy that could tie it to the real character, double up an effect, or run code
local function strip(c)
	for _, d in c:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") or d:IsA("NoCollisionConstraint")
			or d:IsA("LuaSourceContainer") or d:IsA("Light") or d:IsA("Beam") or d:IsA("Sound") or d:IsA("TouchTransmitter")
			or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter")
			or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("BasePart")
			or d:IsA("WrapTarget") or d:IsA("WrapLayer") then
			d:Destroy()
		end
	end
end

local function copy(p)
	local ok, c = pcall(function() return p:Clone() end)
	if not ok or not c then return nil end
	strip(c)
	c.Anchored = true
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.CastShadow = false
	c.Massless = true
	return c
end

-- what's in your right hand: an equipped tool, or something welded to the hand from outside your character
local function heldThing(char, hand)
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then
		local h = tool:FindFirstChild("Handle")
		if h and h:IsA("BasePart") then return tool, "tool" end
	end
	for _, j in hand:GetJoints() do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
			local other = (j.Part0 == hand and j.Part1) or (j.Part1 == hand and j.Part0) or nil
			if other and not other:IsDescendantOf(char) then
				return other:FindFirstAncestorOfClass("Model") or other, "carry"
			end
		end
	end
	return nil
end

-- your wristband colour: the outfit's band, or your band colour
local function bandColour(char)
	local outfit = char:FindFirstChild("Outfit")
	if outfit then
		for _, d in outfit:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Wristband" then return d.Color end
		end
	end
	return player:GetAttribute("BandColor")
end

local function restoreReal()
	if real and hiddenNow then
		for _, p in real do if p.Parent then p.LocalTransparencyModifier = 0 end end
	end
	hiddenNow = false
end

local function destroyVM()
	restoreReal()
	if vm then vm:Destroy() end
	vm, offs, grip, real = nil, nil, nil, nil
end

local function build(char, hand, thing, kind)
	destroyVM()
	local att = hand:FindFirstChild("RightGripAttachment")
	local gripPoint = att and att.Position or Vector3.new(0, -hand.Size.Y / 2, 0)
	local items, parts = {}, {}
	if thing:IsA("BasePart") then parts = { thing } else
		for _, d in thing:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end
	end
	-- a tool's grip is fixed, so work it out exactly instead of trusting this frame's physics
	local handle = kind == "tool" and thing:FindFirstChild("Handle") or nil
	local handleRel = (handle and att) and (att.CFrame * thing.Grip:Inverse()) or nil
	real = {}
	for _, p in parts do
		local c = copy(p)
		if c then
			local rel = handleRel and (handleRel * handle.CFrame:ToObjectSpace(p.CFrame)) or hand.CFrame:ToObjectSpace(p.CFrame)
			table.insert(items, { copy = c, rel = rel })
			table.insert(real, p)
		end
	end
	vm, offs, grip = ViewHands.build({
		char = char, hand = hand, thing = thing, items = items, gripPoint = gripPoint,
		defaultScale = kind == "carry" and CARRY_SCALE or 1,
	})
end

RunService:BindToRenderStep("FirstPersonHands", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local char = player.Character
	local cam = workspace.CurrentCamera
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local thing, kind
	if hand and hum and hum.Health > 0 then thing, kind = heldThing(char, hand) end
	-- a tool only counts once it's actually gripped
	if thing and kind == "tool" and not hand:FindFirstChild("RightGrip") then thing = nil end
	if thing ~= heldKey then
		destroyVM()
		heldKey, heldKind = thing, kind
		buildAt = os.clock() + 0.05 -- let the grip settle for a frame or two
	end
	if heldKey and not vm and os.clock() >= buildAt and heldKey.Parent then
		local ok, err = pcall(build, char, hand, heldKey, heldKind)
		if not ok then warn("[FirstPersonHands] " .. tostring(err)) heldKey = nil destroyVM() end
	end
	if not vm then return end
	local firstPerson = head and cam and (cam.CFrame.Position - head.Position).Magnitude < FIRST_PERSON
	if firstPerson then
		-- a gentle bob while you walk
		local speed = hum and (hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air) and 1 or 0
		bobAmt += (speed - bobAmt) * math.min(1, dt * 8)
		bobT += dt * (hum and hum.WalkSpeed or 16) * 0.55
		local bob = CFrame.new(math.cos(bobT) * BOB * bobAmt, -math.abs(math.sin(bobT)) * BOB * bobAmt, 0)
		vm.Parent = cam
		local base = cam.CFrame * bob * grip
		for c, off in offs do
			c.CFrame = base * off
			c.LocalTransparencyModifier = 0
		end
		for _, p in real do p.LocalTransparencyModifier = 1 end
		hiddenNow = true
	else
		vm.Parent = nil
		restoreReal()
	end
end)
