-- Bandage (ServerStorage.LootItems.Bandage, the live loot template cloned by LootService).
-- The server decides the heal: the remote's arguments are ignored, the bandage must be in the sender's hands,
-- and the sender must have held the use button for most of the time the client's progress loop runs.
local tool = script.Parent
local HEAL_AMOUNT = 35        -- keep in step with the client LocalScript, which fires Use after its 3.3 s loop
local MIN_USE_SECONDS = 2.5   -- below the client's 3.3 s so ordinary latency never rejects a real use
local usingSince = nil
local used = false

tool.Activated:Connect(function() usingSince = os.clock() end)
tool.Deactivated:Connect(function() usingSince = nil end)
tool.Unequipped:Connect(function() usingSince = nil end)

tool.Use.OnServerEvent:Connect(function(player)
	if used or usingSince == nil or os.clock() - usingSince < MIN_USE_SECONDS then return end
	local character = player.Character
	if not character or tool.Parent ~= character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	used = true

	local clone = tool.Handle:Clone()
	clone.Parent = workspace
	clone.CanCollide = true
	tool:Destroy()
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + HEAL_AMOUNT)
	clone.Used:Play()
	game.Debris:AddItem(clone, 5)
end)
