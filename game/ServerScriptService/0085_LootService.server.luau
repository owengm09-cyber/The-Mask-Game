-- LootService: runs every model tagged "LootContainer" (steel cabinets, chests, chests of drawers).
--  * E opens/closes a container part (doors, lid, or a single drawer). Items can only be taken while it is open.
--  * F takes an item; it goes into the player's Backpack as the Tool from ServerStorage.LootItems.
--  * What spawns where is set in the LootConfig module (child of this script).
--  * Fire ServerStorage.LootEvents.Restock (BindableEvent) to close everything and roll fresh loot, e.g. at round start.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Config = require(script:WaitForChild("LootConfig"))
local ItemsFolder = ServerStorage:WaitForChild("LootItems")

local events = ServerStorage:FindFirstChild("LootEvents")
if not events then events = Instance.new("Folder"); events.Name = "LootEvents"; events.Parent = ServerStorage end
local restockEvent = events:FindFirstChild("Restock")
if not restockEvent then restockEvent = Instance.new("BindableEvent"); restockEvent.Name = "Restock"; restockEvent.Parent = events end

local rng = Random.new()
local containers = {}

local function weightedPick(weights)
	local total = 0
	for _, w in pairs(weights) do total += w end
	if total <= 0 then return nil end
	local roll = rng:NextNumber(0, total)
	for id, w in pairs(weights) do
		roll -= w
		if roll <= 0 then return id end
	end
	return next(weights)
end

---------------------------------------------------------------- giving items
local function findStack(player, itemId)
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if holder then
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("LootItemId") == itemId then return t end
			end
		end
	end
end

local function giveItem(player, itemId)
	local def = Config.Items[itemId]
	local template = def and ItemsFolder:FindFirstChild(def.Template)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (template and backpack) then return false end
	if def.Stack then
		local existing = findStack(player, itemId)
		if existing then
			local count = (existing:GetAttribute("Count") or 1) + 1
			existing:SetAttribute("Count", count)
			existing.Name = def.DisplayName .. " x" .. count
			return true
		end
	end
	local tool = template:Clone()
	tool:SetAttribute("LootItemId", itemId)
	tool:SetAttribute("Count", 1)
	tool.Parent = backpack
	return true
end

---------------------------------------------------------------- display props
local function poseFor(handle, pose)
	local s = handle.Size
	local longest = (s.X >= s.Y and s.X >= s.Z) and "X" or ((s.Y >= s.Z) and "Y" or "Z")
	if pose == "Flat" then
		if longest == "Y" then return CFrame.Angles(0, 0, math.rad(90)) end
		if longest == "Z" then return CFrame.Angles(0, math.rad(90), 0) end
		return CFrame.new()
	else
		if longest == "X" then return CFrame.Angles(0, 0, math.rad(90)) end
		if longest == "Z" then return CFrame.Angles(math.rad(90), 0, 0) end
		return CFrame.new()
	end
end

local function spawnDisplay(state, slot, itemId)
	local def = Config.Items[itemId]
	local template = def and ItemsFolder:FindFirstChild(def.Template)
	if not template then warn("[LootService] missing item template", itemId) return end
	local src = template:Clone()
	local handle = src:FindFirstChild("Handle")
	if not handle then src:Destroy() return end
	local model = Instance.new("Model")
	model.Name = "Loot_" .. itemId
	model:SetAttribute("LootItemId", itemId)
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Parent = model
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	src:Destroy()
	model.PrimaryPart = handle
	local pose = poseFor(handle, slot:GetAttribute("Pose") or "Upright")
	local yaw = CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
	model:PivotTo(slot.WorldCFrame * yaw * pose)
	local cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, slot.WorldPosition.Y - (cf.Position.Y - size.Y / 2) + 0.01, 0))

	local surface = slot.Parent
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = surface.Anchored end
	end
	if not surface.Anchored then
		local w = Instance.new("WeldConstraint"); w.Part0 = surface; w.Part1 = handle; w.Parent = handle
	end

	local att = Instance.new("Attachment"); att.Name = "TakeAttachment"; att.Parent = handle
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = "Take"
	prompt.ObjectText = def.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = att

	local lootFolder = state.model:FindFirstChild("SpawnedLoot")
	if not lootFolder then lootFolder = Instance.new("Folder"); lootFolder.Name = "SpawnedLoot"; lootFolder.Parent = state.model end
	model.Parent = lootFolder

	local entry = { model = model, prompt = prompt, itemId = itemId, mover = slot:GetAttribute("Mover") }
	state.loot[model] = entry
	local mover = state.movers[entry.mover]
	prompt.Enabled = mover ~= nil and mover.open

	prompt.Triggered:Connect(function(player)
		if not state.loot[model] then return end
		local m = state.movers[entry.mover]
		if not (m and m.open) then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or (root.Position - handle.Position).Magnitude > 12 then return end
		if giveItem(player, itemId) then
			state.loot[model] = nil
			model:Destroy()
		end
	end)
end

---------------------------------------------------------------- movers
local function setMover(state, name, open, instant)
	local mover = state.movers[name]
	if not mover or (mover.open == open and not instant) then return end
	mover.open = open
	for _, t in ipairs(mover.tweens) do t:Cancel() end
	table.clear(mover.tweens)
	for _, pv in ipairs(mover.pivots) do
		local target = open and (pv.closed * pv.offset) or pv.closed
		if instant then
			pv.part.CFrame = target
		else
			local t = TweenService:Create(pv.part, TweenInfo.new(Config.Timing[mover.kind] or 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = target })
			table.insert(mover.tweens, t)
			t:Play()
		end
	end
	if mover.prompt then mover.prompt.ActionText = open and "Close" or "Open" end
	if not instant and mover.sound then
		local snd = Config.Sounds[mover.kind]
		mover.sound.PlaybackSpeed = open and snd.OpenSpeed or snd.CloseSpeed
		mover.sound.TimePosition = 0
		mover.sound:Play()
	end
	for _, entry in pairs(state.loot) do
		if entry.mover == name then entry.prompt.Enabled = open end
	end
end

---------------------------------------------------------------- stocking
local function stock(state)
	for model in pairs(state.loot) do model:Destroy() end
	table.clear(state.loot)
	for name in pairs(state.movers) do setMover(state, name, false, true) end

	local tbl = Config.Tables[state.tableName]
	if not tbl then return end
	local slots = table.clone(state.slots)
	-- shuffle
	for i = #slots, 2, -1 do local j = rng:NextInteger(1, i); slots[i], slots[j] = slots[j], slots[i] end

	if tbl.Mode == "One" then
		if slots[1] then spawnDisplay(state, slots[1], weightedPick(tbl.Weights)) end
	elseif tbl.Mode == "Slots" then
		local placed = 0
		for i, slot in ipairs(slots) do
			local mustFill = placed < (tbl.MinItems or 0) and (#slots - i + 1) <= ((tbl.MinItems or 0) - placed)
			if mustFill or rng:NextNumber() < tbl.SlotChance then
				spawnDisplay(state, slot, weightedPick(tbl.Weights)); placed += 1
			end
		end
	elseif tbl.Mode == "PerMover" then
		local byMover = {}
		for _, slot in ipairs(slots) do
			local m = slot:GetAttribute("Mover")
			byMover[m] = byMover[m] or {}
			table.insert(byMover[m], slot)
		end
		for _, list in pairs(byMover) do
			if rng:NextNumber() < tbl.MoverChance then
				local n = math.min(#list, rng:NextInteger(1, tbl.MaxPerMover or 1))
				for i = 1, n do spawnDisplay(state, list[i], weightedPick(tbl.Weights)) end
			end
		end
	end
end

---------------------------------------------------------------- setup
local function setup(model)
	if containers[model] then return end
	local state = { model = model, tableName = model:GetAttribute("LootTable"), movers = {}, slots = {}, loot = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("IsMover") then
			local kind = d:GetAttribute("Kind") or "Drawer"
			local mover = { name = d.Name, kind = kind, open = false, pivots = {}, tweens = {} }
			for _, p in ipairs(d:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Pivot" and p:GetAttribute("OpenOffset") then
					table.insert(mover.pivots, { part = p, closed = p.CFrame, offset = p:GetAttribute("OpenOffset") })
				end
			end
			mover.prompt = d:FindFirstChild("LootPrompt", true)
			local snd = Config.Sounds[kind]
			if snd and mover.pivots[1] then
				local sound = Instance.new("Sound")
				sound.SoundId = snd.Id; sound.Volume = snd.Volume or 0.5
				sound.RollOffMinDistance = 5; sound.RollOffMaxDistance = 50
				sound.Parent = mover.pivots[1].part
				mover.sound = sound
			end
			if mover.prompt then
				mover.prompt.Triggered:Connect(function()
					setMover(state, mover.name, not mover.open, false)
				end)
			end
			state.movers[d.Name] = mover
		elseif d:IsA("Attachment") and d.Name == "LootSlot" then
			table.insert(state.slots, d)
		end
	end
	containers[model] = state
	model.Destroying:Connect(function() containers[model] = nil end)
	stock(state)
end

for _, m in ipairs(CollectionService:GetTagged("LootContainer")) do task.spawn(setup, m) end
CollectionService:GetInstanceAddedSignal("LootContainer"):Connect(setup)

restockEvent.Event:Connect(function()
	for _, state in pairs(containers) do stock(state) end
end)
