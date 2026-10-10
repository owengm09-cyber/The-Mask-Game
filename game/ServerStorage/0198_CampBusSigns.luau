-- CampBusSigns: covers the "SCHOOL BUS" lettering printed on the bus mesh's front and back with "CAMP BUS" sign plates.
-- Build(model) adds the plates to a bus model (ServerStorage.EscapeVanKit.Bus, or a placed copy); Remove(model) takes them off.
-- Positions are in the bus's pivot space (pivot on the ground under its middle, x = driver's right, -z = forward).
-- The bus's end walls are slightly V-shaped, so each sign is two plates angled to sit flush, "CAMP" on one and "BUS" on the other.
local M = {}

M.YELLOW = Color3.fromRGB(210, 160, 58)
M.INK = Color3.fromRGB(26, 22, 18)

-- cz: the wall's z at the middle; slope: how far the wall leans out per stud sideways; out: -1 front wall, +1 back wall
M.SIGNS = {
	Front = { y = 8.75, h = 0.8, w = 2.02, cz = -9.91, slope = 0.13, out = -1 },
	Back = { y = 8.47, h = 0.82, w = 1.72, cz = 14.67, slope = 0.156, out = 1 },
}

local THICK = 0.05
local PPS = 120 -- SurfaceGui pixels per stud

local function bar(parent, pos, size)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = M.INK
	f.Position = pos
	f.Size = size
	f.Parent = parent
end

local function plate(folder, pivot, name, spec, s)
	local xc = s * spec.w / 2
	local zs = spec.cz + spec.out * spec.slope * math.abs(xc)
	local pos = Vector3.new(xc, spec.y, zs + spec.out * (THICK / 2 + 0.015))
	local n = Vector3.new(-spec.slope * s, 0, spec.out).Unit -- outward, the way the sign faces
	local vZ = -n
	local vY = Vector3.yAxis
	local vX = vY:Cross(vZ)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(spec.w / math.cos(math.atan(spec.slope)) + 0.01, spec.h, THICK)
	p.CFrame = pivot * CFrame.fromMatrix(pos, vX, vY, vZ)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = M.YELLOW
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth

	-- seen from in front, +x of the bus is on the viewer's left for the front wall and on the right for the back wall
	local viewerLeft = (spec.out == -1) == (s == 1)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 1
	gui.Brightness = 1
	gui.ClipsDescendants = true
	gui.Parent = p
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = M.YELLOW
	bg.Parent = gui
	local edge = math.floor(0.055 * PPS)
	bar(bg, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, edge))
	bar(bg, UDim2.new(0, 0, 1, -edge), UDim2.new(1, 0, 0, edge))
	if viewerLeft then
		bar(bg, UDim2.new(0, 0, 0, 0), UDim2.new(0, edge, 1, 0))
	else
		bar(bg, UDim2.new(1, -edge, 0, 0), UDim2.new(0, edge, 1, 0))
	end
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	-- the two words meet at the crease with a normal word space between them
	local gap = math.floor(0.07 * PPS)
	t.AnchorPoint = viewerLeft and Vector2.new(1, 0.5) or Vector2.new(0, 0.5)
	t.Position = viewerLeft and UDim2.new(1, -gap, 0.5, 0) or UDim2.new(0, gap, 0.5, 0)
	t.Size = UDim2.new(1, -gap - edge * 2, 0.8, 0)
	t.FontFace = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold)
	t.TextSize = math.min(100, math.floor(spec.h * 0.64 * PPS))
	t.TextColor3 = M.INK
	t.Text = viewerLeft and "CAMP" or "BUS"
	t.TextXAlignment = viewerLeft and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	t.Parent = bg
	p.Parent = folder
	return p
end

function M.Remove(model)
	local f = model:FindFirstChild("CampBusSigns")
	if f then f:Destroy() end
end

function M.Build(model)
	M.Remove(model)
	local pivot = model:GetPivot()
	local folder = Instance.new("Model")
	folder.Name = "CampBusSigns"
	for key, spec in M.SIGNS do
		plate(folder, pivot, key .. "SignA", spec, 1)
		plate(folder, pivot, key .. "SignB", spec, -1)
	end
	folder.Parent = model
	return folder
end

return M
