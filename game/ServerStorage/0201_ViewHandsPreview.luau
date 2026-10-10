-- Edit-mode preview of the first-person hand (for tuning ReplicatedStorage.ViewHands without playtesting).
-- require(this).Show(tool, camCF) builds the hand holding `tool` in workspace._VHPreview, placed as if `camCF` were the camera.
local P = {}

local function fresh()
	-- a fresh copy of ViewHands so source edits are picked up
	local src = game.ReplicatedStorage.ViewHands
	local c = src:Clone()
	c.Name = "_ViewHandsPreviewCopy"
	c.Parent = game.ReplicatedStorage
	local ok, m = pcall(require, c)
	c:Destroy()
	assert(ok, m)
	return m
end

local function strip(c)
	for _, d in c:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") or d:IsA("LuaSourceContainer")
			or d:IsA("Light") or d:IsA("Beam") or d:IsA("Sound") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui")
			or d:IsA("ParticleEmitter") or d:IsA("BasePart") then d:Destroy() end
	end
	c.Anchored = true c.CanCollide = false c.CanQuery = false c.CastShadow = false
end

function P.Show(thing, camCF, holdRel)
	local VH = fresh()
	local old = workspace:FindFirstChild("_VHPreview") if old then old:Destroy() end
	local body = game.ServerStorage.CounselorKit.BulkyBody
	local hand = body:FindFirstChild("RightHand", true)
	local att = hand.RightGripAttachment
	local items = {}
	if thing:IsA("Tool") then
		local handle = thing.Handle
		local handleRel = att.CFrame * thing.Grip:Inverse()
		for _, p in thing:GetDescendants() do
			if p:IsA("BasePart") then
				local c = p:Clone() strip(c)
				table.insert(items, { copy = c, rel = handleRel * handle.CFrame:ToObjectSpace(p.CFrame) })
			end
		end
	else
		-- a carried model: holdRel is its main part relative to the hand (like a CarryGrip weld's C0)
		local main = thing.PrimaryPart or thing:FindFirstChildWhichIsA("BasePart", true)
		for _, p in thing:GetDescendants() do
			if p:IsA("BasePart") then
				local c = p:Clone() strip(c)
				table.insert(items, { copy = c, rel = holdRel * main.CFrame:ToObjectSpace(p.CFrame) })
			end
		end
	end
	local vm, offs, grip = VH.build({ thing = thing, items = items, gripPoint = att.Position, skin = hand.Color,
		band = Color3.fromRGB(235, 40, 40), defaultPose = "upright" })
	vm.Name = "_VHPreview"
	local base = camCF * grip
	for part, off in offs do part.CFrame = base * off end
	vm.Parent = workspace
	return vm
end

return P
