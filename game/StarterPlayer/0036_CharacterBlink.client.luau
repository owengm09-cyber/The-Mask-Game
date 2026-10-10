-- CharacterBlink: every camper's eyes blink now and then, on this player's screen (characters in the world and copies in viewports).
-- The eyes are the "Eye" discs CounselorBuilder puts on each face: a part with a cylinder SpecialMesh whose Y axis runs up the face.
-- A cylinder mesh stays round however it's scaled, so for the length of a blink the eye becomes a flat ellipsoid the same size,
-- which can be squashed down to a line; it goes back to the cylinder when the eye is open again.
-- The little "EyeShine" highlight is shrunk away while the eye is shut.
-- Each mesh's open scale and type are kept in its "BlinkBase"/"BlinkType" attributes, so a copy made mid-blink still opens fully.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CLOSE, HOLD, OPEN = 0.055, 0.045, 0.09 -- seconds to shut, stay shut, and open again
local LID = 0.16 -- a shut eye is a line this fraction of the eye's width tall
local GAP_MIN, GAP_MAX = 2.2, 5.8 -- seconds between blinks
local DOUBLE = 0.18 -- chance a blink comes as a quick double
local FAR = 120 -- don't bother animating faces further than this from the camera

local rng = Random.new()
local faces = {} -- model -> { eyes = {mesh}, shines = {mesh}, t0 = start of the current blink, next = time of the next one, twice/second = double-blink flags }

local function baseOf(mesh)
	local b = mesh:GetAttribute("BlinkBase")
	if typeof(b) ~= "Vector3" then
		b = mesh.Scale
		mesh:SetAttribute("BlinkBase", b)
		mesh:SetAttribute("BlinkType", mesh.MeshType.Name)
	end
	return b
end

local function restore(mesh)
	local b = baseOf(mesh)
	local t = mesh:GetAttribute("BlinkType")
	for _, item in Enum.MeshType:GetEnumItems() do
		if item.Name == t then mesh.MeshType = item break end
	end
	mesh.Scale = b
end

local function forget(face, mesh)
	for _, list in { face.eyes, face.shines } do
		local i = table.find(list, mesh)
		if i then table.remove(list, i) end
	end
end

local function track(part)
	if part.Name ~= "Eye" and part.Name ~= "EyeShine" then return end
	if not part:IsA("BasePart") then return end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	local model = part:FindFirstAncestorOfClass("Model")
	if not mesh or not model then return end
	local face = faces[model]
	if not face then
		face = { eyes = {}, shines = {}, next = os.clock() + rng:NextNumber(0.5, GAP_MAX) }
		faces[model] = face
	end
	local list = part.Name == "Eye" and face.eyes or face.shines
	if table.find(list, mesh) then return end
	restore(mesh)
	table.insert(list, mesh)
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(game) then
			forget(face, mesh)
			if #face.eyes == 0 and #face.shines == 0 and faces[model] == face then faces[model] = nil end
		end
	end)
end

local function watch(root)
	for _, d in root:GetDescendants() do track(d) end
	root.DescendantAdded:Connect(track)
end

-- how open the eye is, t seconds into a blink (1 open, LID shut); nil once the blink is over
local function openness(t)
	if t < CLOSE then return 1 - (1 - LID) * (t / CLOSE) end
	t -= CLOSE
	if t < HOLD then return LID end
	t -= HOLD
	if t < OPEN then
		local a = t / OPEN
		return LID + (1 - LID) * (1 - (1 - a) * (1 - a))
	end
	return nil
end

local function shapeEye(m, k)
	if k >= 0.999 then restore(m) return end
	local b = baseOf(m)
	local part = m.Parent
	if not part or not part:IsA("BasePart") then return end
	local sy, sz = part.Size.Y * b.Y, part.Size.Z * b.Z
	local d = math.min(sy, sz) -- how wide the round eye looks (a cylinder mesh is as wide as its smaller side)
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = Vector3.new(b.X, b.Y * d * k / sy, b.Z * d / sz)
end

local function setOpen(face, k)
	for _, m in face.eyes do shapeEye(m, k) end
	local s = math.clamp((k - 0.45) / 0.55, 0, 1) -- the highlight goes before the lid is halfway down
	for _, m in face.shines do
		local b = baseOf(m)
		m.Scale = b * math.max(s, 0.001)
	end
end

local function alive(model)
	local h = model:FindFirstChildOfClass("Humanoid")
	return not h or h.Health > 0
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position
	for model, face in faces do
		if face.t0 then
			local k = openness(now - face.t0)
			if k then
				setOpen(face, k)
			else
				setOpen(face, 1)
				face.t0 = nil
				if face.twice then
					face.twice = false
					face.second = true -- the follow-up blink doesn't roll for another double
					face.next = now + 0.12
				else
					face.next = now + rng:NextNumber(GAP_MIN, GAP_MAX)
				end
			end
		elseif now >= face.next then
			local eye = face.eyes[1]
			local part = eye and eye.Parent
			local near = true
			if part and part:IsA("BasePart") and part:IsDescendantOf(workspace) and camPos then
				near = (part.Position - camPos).Magnitude < FAR
			end
			if part and near and alive(model) then
				face.t0 = now
				if face.second then
					face.second = false
				else
					face.twice = rng:NextNumber() < DOUBLE
				end
			else
				face.next = now + rng:NextNumber(GAP_MIN, GAP_MAX)
			end
		end
	end
end)

watch(workspace)
local player = Players.LocalPlayer
watch(player:WaitForChild("PlayerGui"))
