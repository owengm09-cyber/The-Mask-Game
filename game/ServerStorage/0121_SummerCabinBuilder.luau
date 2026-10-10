-- Native, editable summer-camp architecture. Floor walking surface is local Y = 0.
-- The front faces local -Z; a 6-stud entrance opens onto a furnished porch.
local B = {}
local V, CF = Vector3.new, CFrame.new
local names = {"CEDAR", "BIRCH", "PINE", "ASH", "WILLOW", "HOLLOW"}
local wood = Color3.fromRGB(116, 76, 46)
local pine = Color3.fromRGB(162, 113, 65)
local frame = Color3.fromRGB(91, 57, 34)
local trim = Color3.fromRGB(190, 150, 99)
local iron = Color3.fromRGB(39, 44, 42)
local roof = Color3.fromRGB(51, 62, 57)
local bedding = {
	Color3.fromRGB(55, 92, 99), Color3.fromRGB(121, 45, 42),
	Color3.fromRGB(171, 134, 62), Color3.fromRGB(59, 68, 91),
	Color3.fromRGB(87, 103, 73), Color3.fromRGB(111, 78, 81),
}

function B.Build(name, originCFrame, index)
	index = math.clamp(math.floor(index or 1), 1, 6)
	originCFrame = originCFrame or CFrame.identity
	local cabin = Instance.new("Model")
	cabin.Name = name or ("Cabin" .. index)
	cabin.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	cabin:SetAttribute("CabinNumber", index)
	cabin:SetAttribute("CabinName", names[index])
	cabin:SetAttribute("Width", 22)
	cabin:SetAttribute("Depth", 36)
	cabin:SetAttribute("Height", 18)
	cabin:SetAttribute("FloorSurfaceY", 0)
	cabin:SetAttribute("FrontIsNegativeZ", true)
	cabin:SetAttribute("BunkBerths", 8)
	cabin:SetAttribute("EntranceWidth", 6)
	cabin:SetAttribute("AisleWidth", 7)
	local function group(n)
		local m = Instance.new("Model")
		m.Name = n
		m.Parent = cabin
		return m
	end
	local shell, inside, veranda, fittings = group("TimberShell"), group("Interior"), group("PorchAndSteps"), group("LightingAndSigns")
	local function part(n, size, pose, color, material, parent, collidable)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.CFrame = originCFrame * (typeof(pose) == "Vector3" and CF(pose) or pose)
		p.Color = color or wood
		p.Material = material or Enum.Material.Wood
		p.Anchored = true
		p.CanCollide = collidable ~= false
		p.CanTouch = false
		p.CanQuery = collidable ~= false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = parent or shell
		return p
	end
	local function beam(n, a, b, width, depth, color, parent, collidable)
		return part(n, V(width, depth or width, (b-a).Magnitude), CFrame.lookAt((a+b)/2, b), color, Enum.Material.Wood, parent, collidable)
	end
	local function textSign(board, text, color, scale)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Lettering"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(640, 160)
		gui.LightInfluence = 1
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color or Color3.fromRGB(220, 198, 146)
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft, padding.PaddingRight = UDim.new(scale or .06, 0), UDim.new(scale or .06, 0)
		padding.PaddingTop, padding.PaddingBottom = UDim.new(.1, 0), UDim.new(.1, 0)
		padding.Parent = label
		return gui
	end
	local root = part("CabinOrigin", V(.2,.2,.2), V(0,-.1,0), frame, Enum.Material.Wood, cabin, false)
	root.Transparency = 1
	cabin.PrimaryPart = root
	local arrival = part("EntranceMarker", V(.2,.2,.2), V(0,.1,-21.1), frame, Enum.Material.Wood, cabin, false)
	arrival.Transparency = 1

	-- A slightly raised, fully supported timber floor and weathered skirt.
	part("Foundation", V(20,.7,26), V(0,-.55,0), frame)
	for x = -9.4, 9.4, 1.175 do
		local tone = pine:Lerp(trim, ((math.floor((x+10)*10)+index)%5)*.025)
		part("Floorboard", V(1.15,.24,25.5), V(x,-.12,0), tone, Enum.Material.WoodPlanks, inside)
	end
	for _, x in ipairs({-9, 0, 9}) do
		for _, z in ipairs({-12, 0, 12}) do
			part("FoundationPier", V(1.05,2.4,1.05), V(x,-1.5,z), Color3.fromRGB(85,83,74), Enum.Material.Slate)
		end
	end
	for _, x in ipairs({-9.8,9.8}) do
		part("RaisedSkirt", V(.32,1.35,25.8), V(x,-.92,0), frame)
	end
	part("RearSkirt", V(20,1.35,.32), V(0,-.92,12.8), frame)

	-- Side walls have real openings, so the glass never sits over opaque walls.
	for _, side in ipairs({-1,1}) do
		local x = side*9.85
		part("WallBelowWindows", V(.38,5.8,26), V(x,2.9,0), wood, Enum.Material.WoodPlanks)
		part("WallAboveWindows", V(.38,1.05,26), V(x,9.475,0), wood, Enum.Material.WoodPlanks)
		for _, span in ipairs({{-13,-9.5},{-3.5,1.5},{7.5,13}}) do
			part("WindowWallPier", V(.38,3.15,span[2]-span[1]), V(x,7.375,(span[1]+span[2])/2), wood, Enum.Material.WoodPlanks)
		end
		for _, z in ipairs({-6.5,4.5}) do
			local glass = part("WindowGlass", V(.12,2.95,5.85), V(x,7.38,z), Color3.fromRGB(134,169,158), Enum.Material.Glass, shell)
			glass.Transparency = .67
			glass.Reflectance = .07
			for _, edgeZ in ipairs({z-3,z+3}) do
				part("WindowUpright", V(.55,3.4,.2), V(x,7.38,edgeZ), trim)
			end
			for _, y in ipairs({5.82,8.95}) do
				part("WindowFrame", V(.58,.22,6.2), V(x,y,z), trim)
			end
			part("WindowMullion", V(.4,3,.1), V(x,7.38,z), frame)
			part("WindowSill", V(.82,.2,6.35), V(x,5.74,z), pine)
		end
		for z = -12.7, 12.7, 1.6 do
			part("ExteriorBoardSeam", V(.07,5.65,.055), V(side*10.065,2.86,z), frame, Enum.Material.Wood, shell, false)
		end
		part("InteriorBaseboard", V(.14,.35,25.5), V(side*9.57,.18,0), trim, Enum.Material.Wood, inside)
		part("InteriorUpperRail", V(.22,.25,25.5), V(side*9.53,9.1,0), pine, Enum.Material.Wood, inside)
	end
	-- Front: six clear studs between jambs, with an eight-stud doorway.
	for _, x in ipairs({-6.5,6.5}) do
		part("FrontWall", V(7,10,.38), V(x,5,-12.85), wood, Enum.Material.WoodPlanks)
	end
	part("DoorHeaderWall", V(6,1.9,.38), V(0,9.05,-12.85), wood, Enum.Material.WoodPlanks)
	for _, x in ipairs({-3.16,3.16}) do
		part("DoorJamb", V(.24,8.15,.7), V(x,4.08,-12.96), trim)
	end
	part("DoorLintel", V(6.6,.35,.7), V(0,8.17,-12.96), trim)
	part("Threshold", V(6.1,.11,.9), V(0,.025,-12.9), pine)
	-- A fixed open leaf rests along the outside left wall of the porch.
	local door = Instance.new("Model")
	door.Name = "OpenDoor"
	door:SetAttribute("FixedOpen", true)
	door.Parent = veranda
	local doorCF = CF(-3.22,0,-13.1)*CFrame.Angles(0,math.rad(100),0)
	local leaf = part("DoorLeaf", V(5.75,7.8,.22), doorCF*CF(2.875,3.95,0), pine, Enum.Material.WoodPlanks, door)
	door.PrimaryPart = leaf
	for _, y in ipairs({.6,4.3,7.45}) do
		part("DoorBrace", V(5.65,.18,.16), doorCF*CF(2.875,y,-.18), frame, Enum.Material.Wood, door, false)
	end
	local knob = part("DoorHandle", V(.15,.2,.28), doorCF*CF(5.3,3.7,-.25), iron, Enum.Material.Metal, door, false)
	knob.Shape = Enum.PartType.Ball
	-- Rear wall, one high window and an open central sightline through the room.
	part("RearWallBase", V(20,5.8,.38), V(0,2.9,12.85), wood, Enum.Material.WoodPlanks)
	part("RearWallTop", V(20,1.2,.38), V(0,9.4,12.85), wood, Enum.Material.WoodPlanks)
	for _, x in ipairs({-6.25,6.25}) do
		part("RearWallSide", V(7.5,3,.38), V(x,7.3,12.85), wood, Enum.Material.WoodPlanks)
	end
	local rearGlass = part("RearWindowGlass", V(4.8,2.9,.12), V(0,7.3,12.85), Color3.fromRGB(134,169,158), Enum.Material.Glass)
	rearGlass.Transparency = .67
	for _, x in ipairs({-2.5,0,2.5}) do part("RearWindowFrame", V(.16,3.2,.5), V(x,7.3,12.85), trim) end
	for _, y in ipairs({5.8,8.8}) do part("RearWindowFrame", V(5.15,.18,.5), V(0,y,12.85), trim) end
	for _, x in ipairs({-9.7,9.7}) do
		for _, z in ipairs({-12.7,12.7}) do part("CornerPost", V(.65,10.2,.65), V(x,5,z), frame) end
	end

	-- A closed gable built from tapered timber courses, covered by diagonal fascia.
	for _, z in ipairs({-12.85,12.85}) do
		for course=0,19 do
			local h = .25
			local y = 10 + (course+.5)*h
			local w = 20 - course
			if w > .01 then part("GableTimberCourse", V(w+.08,h+.025,.38), V(0,y,z), pine, Enum.Material.WoodPlanks) end
		end
		beam("GableLeftFascia", V(-10.45,9.85,z-.05), V(0,15.08,z-.05), .7,.5, frame)
		beam("GableRightFascia", V(0,15.08,z-.05), V(10.45,9.85,z-.05), .7,.5, frame)
		part("GableKingPost", V(.38,4.9,.48), V(0,12.45,z), frame)
		part("GableTieBeam", V(20,.38,.55), V(0,10.06,z), frame)
	end
	local pitch = math.atan(.5)
	for _, side in ipairs({-1,1}) do
		local roofCF = CF(side*5.25,12.48,0)*CFrame.Angles(0,0,-side*pitch)
		part("PineRoofUnderside", V(11.9,.35,28.4), roofCF, pine, Enum.Material.WoodPlanks)
		part("WeatheredRoof", V(12,.22,28.7), roofCF*CF(0,.285,0), roof, Enum.Material.Slate)
		for z=-13.75,13.75,2.5 do
			part("RoofStandingSeam", V(12.05,.075,.065), roofCF*CF(0,.445,z), Color3.fromRGB(68,76,65), Enum.Material.Metal, shell, false)
		end
		part("EaveFascia", V(.3,.62,28.7), V(side*10.55,9.92,0), frame)
	end
	part("RidgeCap", V(.8,.24,29), V(0,15.34,0), roof, Enum.Material.Metal)
	for _, z in ipairs({-11,-5,1,7,12}) do
		beam("ExposedRafter", V(-9.6,9.75,z), V(0,14.55,z), .3,.38, frame, inside, false)
		beam("ExposedRafter", V(0,14.55,z), V(9.6,9.75,z), .3,.38, frame, inside, false)
		part("ExposedTieBeam", V(19.3,.32,.32), V(0,10.45,z), pine, Enum.Material.Wood, inside, false)
	end
	part("InteriorRidgeBeam", V(.35,.5,25.4), V(0,14.62,0), frame, Enum.Material.Wood, inside, false)

	-- A covered porch, open central steps and railings where there is a drop.
	part("PorchJoist", V(20,.65,5.6), V(0,-.55,-15.7), frame, Enum.Material.Wood, veranda)
	for x=-9.45,9.45,1.05 do
		part("PorchDeckPlank", V(1.02,.24,5.55), V(x,-.12,-15.7), pine, Enum.Material.WoodPlanks, veranda)
	end
	for _, side in ipairs({-1,1}) do
		for _, z in ipairs({-18.15,-13.4}) do
			part("PorchSupport", V(.52,10.0,.52), V(side*9.45,3.9,z), frame, Enum.Material.Wood, veranda)
		end
		part("PorchSideTopRail", V(.35,.35,4.9), V(side*9.45,3,-15.75), trim, Enum.Material.Wood, veranda)
		part("PorchSideBottomRail", V(.25,.25,4.9), V(side*9.45,.6,-15.75), frame, Enum.Material.Wood, veranda)
		for z=-17.8,-13.6,.7 do part("PorchBaluster", V(.15,2.3,.15), V(side*9.45,1.7,z), pine, Enum.Material.Wood, veranda) end
		part("PorchFrontTopRail", V(5.95,.35,.35), V(side*6.55,3,-18.15), trim, Enum.Material.Wood, veranda)
		part("PorchFrontBottomRail", V(5.95,.25,.25), V(side*6.55,.6,-18.15), frame, Enum.Material.Wood, veranda)
		part("PorchNewel", V(.42,3.6,.42), V(side*3.6,1.65,-18.15), frame, Enum.Material.Wood, veranda)
		for j=0,7 do part("PorchBaluster", V(.15,2.3,.15), V(side*(3.9+j*.73),1.7,-18.15), pine, Enum.Material.Wood, veranda) end
	end
	for step=1,4 do
		local top = -step*.45
		part("EntranceStep", V(7.1,.35,.8), V(0,top-.175,-18.15-step*.72), pine, Enum.Material.WoodPlanks, veranda)
	end
	for _, x in ipairs({-3,3}) do beam("StairStringer", V(x,-.48,-18.1),V(x,-2.25,-21.12),.25,.4,frame,veranda) end
	-- Shallow porch lean-to roof sits beneath the cabin gable.
	local leanAngle = math.atan(1.45/5.8)
	part("PorchRoofUnderside",V(21,.28,6.15),CF(0,9.35,-15.6)*CFrame.Angles(-leanAngle,0,0),pine,Enum.Material.WoodPlanks,veranda)
	part("PorchRoof",V(21.2,.18,6.35),CF(0,9.6,-15.6)*CFrame.Angles(-leanAngle,0,0),roof,Enum.Material.Slate,veranda)
	part("PorchFrontBeam",V(20,.55,.4),V(0,8.5,-18.35),frame,Enum.Material.Wood,veranda)
	for _, x in ipairs({-8.8,-4.4,0,4.4,8.8}) do beam("PorchRafter",V(x,8.62,-18.4),V(x,10,-12.8),.23,.28,frame,veranda,false) end

	-- Four bunks: upper rails, ladders and eight separately dressed berths.
	local function bunk(side, z, bedNumber)
		local bed = Instance.new("Model")
		bed.Name = "Bunk" .. bedNumber
		bed.Parent = inside
		local x = side*6.55
		local cloth = bedding[((index+bedNumber-2)%#bedding)+1]
		for _, dx in ipairs({-2.48,2.48}) do
			for _, dz in ipairs({-4,4}) do part("BedPost",V(.25,7.25,.25),V(x+dx,3.625,z+dz),pine,Enum.Material.Wood,bed) end
		end
		for level, y in ipairs({1.1,5.05}) do
			part("BedSlatBase",V(5,.25,8),V(x,y,z),frame,Enum.Material.Wood,bed)
			part("Mattress",V(4.7,.48,7.7),V(x,y+.36,z),Color3.fromRGB(198,181,146),Enum.Material.Fabric,bed)
			part("Blanket",V(4.78,.16,5.65),CF(x,y+.68,z+.93)*CFrame.Angles(0,math.rad((index+bedNumber+level)%3-1),0),cloth,Enum.Material.Fabric,bed,false)
			part("FoldedBlanketEdge",V(4.78,.19,.5),V(x,y+.79,z-1.8),cloth:Lerp(Color3.new(1,1,1),.12),Enum.Material.Fabric,bed,false)
			local pillow=part("Pillow",V(3,.38,1.2),CF(x,y+.77,z-2.85)*CFrame.Angles(0,math.rad((bedNumber%3-1)*4),0),Color3.fromRGB(209,198,167),Enum.Material.Fabric,bed,false)
			for _, dz in ipairs({-4,4}) do
				part("HeadAndFootRail",V(4.9,.55,.2),V(x,y+1.4,z+dz),pine,Enum.Material.Wood,bed)
			end
			if level==2 then
				part("UpperOuterGuardrail",V(.2,.45,7.8),V(x+side*2.48,y+1.6,z),pine,Enum.Material.Wood,bed)
				part("UpperAisleGuardrail",V(.2,.45,5.2),V(x-side*2.48,y+1.6,z-1.25),pine,Enum.Material.Wood,bed)
			end
		end
		local ladderX=x-side*2.65
		for _, dz in ipairs({2.2,3.65}) do part("LadderRail",V(.19,5.8,.19),V(ladderX,2.9,z+dz),trim,Enum.Material.Wood,bed) end
		for y=.55,5.55,1 do part("LadderRung",V(.3,.16,1.5),V(ladderX,y,z+2.925),pine,Enum.Material.Wood,bed) end
		-- Climbable collision tucked inside the visible wooden ladder.
		local climb=Instance.new("TrussPart")
		climb.Name="ClimbableLadder"
		climb.Size=V(.4,5.7,1.5)
		climb.CFrame=originCFrame*CF(ladderX,2.85,z+2.925)
		climb.Anchored=true
		climb.Transparency=1
		climb.CanTouch=false
		climb.Parent=bed
		local trunkColor=Color3.fromRGB(62+bedNumber*6,68+index*3,53+bedNumber*3)
		part("UnderbedTrunk",V(3.4,.65,2.2),V(x,.36,z+.1),trunkColor,Enum.Material.Metal,bed)
		for _, dx in ipairs({-1.15,1.15}) do part("TrunkStrap",V(.11,.69,2.25),V(x+dx,.37,z+.1),iron,Enum.Material.Metal,bed,false) end
		part("TrunkLatch",V(.23,.25,.08),V(x,.48,z-1.04),Color3.fromRGB(157,144,101),Enum.Material.Metal,bed,false)
		local towel=part("HangingTowel",V(.08,1.5,1.3),V(x-side*2.56,4.2,z-1.5),cloth:Lerp(Color3.fromRGB(155,149,124),.4),Enum.Material.Fabric,bed,false)
		return bed
	end
	local number=0
	for _, side in ipairs({-1,1}) do for _, z in ipairs({-6.7,4.4}) do number+=1 bunk(side,z,number) end end

	-- Small lived-in details stay out of the central escape route.
	part("RearCabinet",V(3.3,2.5,1.45),V(0,1.25,11.55),pine,Enum.Material.Wood,inside)
	part("CabinetTop",V(3.55,.18,1.65),V(0,2.58,11.55),frame,Enum.Material.Wood,inside)
	for _, y in ipairs({.65,1.45,2.1}) do
		part("DrawerFront",V(3.07,.56,.08),V(0,y,10.77),wood,Enum.Material.Wood,inside,false)
		part("DrawerPull",V(.5,.1,.15),V(0,y,10.67),iron,Enum.Material.Metal,inside,false)
	end
	part("OldRadio",V(1.4,.9,.6),V(-.6,3.09,11.55),Color3.fromRGB(56,58,43),Enum.Material.Metal,inside,false)
	part("RadioSpeaker",V(.72,.6,.03),V(-.83,3.1,11.23),iron,Enum.Material.DiamondPlate,inside,false)
	part("RadioDial",V(.25,.25,.05),V(-.13,3.17,11.23),trim,Enum.Material.Metal,inside,false)
	beam("RadioAntenna",V(-1.05,3.52,11.5),V(-.8,4.45,11.5),.035,.035,iron,inside,false)
	for book=1,3 do part("CampJournal",V(.7,.12,1),CF(.9,2.75+(book-1)*.12,11.5)*CFrame.Angles(0,math.rad(book*5-10),0),bedding[(index+book-1)%6+1],Enum.Material.Fabric,inside,false) end
	local rules=part("CampRules",V(2.8,2.1,.12),V(5.4,5,-12.52),Color3.fromRGB(96,68,40),Enum.Material.Wood,inside,false)
	rules.CFrame=rules.CFrame*CFrame.Angles(0,math.pi,0)
	textSign(rules,"CAMP RULES\nBUDDY SYSTEM AFTER DARK\nRETURN AT THE BELL",Color3.fromRGB(202,185,140),.07)
	for _, side in ipairs({-1,1}) do
		part("PorchBench",V(3.8,.25,1.35),V(side*6.7,1.55,-14.2),pine,Enum.Material.Wood,veranda)
		for _, dx in ipairs({-1.35,1.35}) do part("BenchLeg",V(.2,1.55,1.15),V(side*6.7+dx,.75,-14.2),frame,Enum.Material.Wood,veranda) end
	end

	local function lantern(n, x, y, z, brightness, range)
		local lanternGroup=Instance.new("Model")
		lanternGroup.Name=n
		lanternGroup.Parent=fittings
		part("LanternChain",V(.045,.8,.045),V(x,y+.76,z),iron,Enum.Material.Metal,lanternGroup,false)
		part("LanternCap",V(.62,.12,.62),V(x,y+.31,z),iron,Enum.Material.Metal,lanternGroup,false)
		part("LanternBase",V(.62,.12,.62),V(x,y-.36,z),iron,Enum.Material.Metal,lanternGroup,false)
		local glass=part("WarmGlass",V(.43,.58,.43),V(x,y,z),Color3.fromRGB(248,185,90),Enum.Material.Neon,lanternGroup,false)
		glass.Transparency=.23
		for _, dx in ipairs({-.25,.25}) do for _, dz in ipairs({-.25,.25}) do part("LanternCage",V(.055,.67,.055),V(x+dx,y,z+dz),iron,Enum.Material.Metal,lanternGroup,false) end end
		local light=Instance.new("PointLight")
		light.Name=(index==6 and n=="RearLantern") and "FlickerLight" or "CampLanternLight"
		light.Color=Color3.fromRGB(255,193,111)
		light.Brightness=brightness
		light.Range=range
		light.Shadows=true
		light:SetAttribute("NormalBrightness",brightness)
		light.Parent=glass
		return light
	end
	lantern("FrontLantern",0,9.12,-6,1.1,19)
	lantern("RearLantern",0,9.12,6,.95,18)
	lantern("PorchLantern",6.6,7.35,-13.65,.8,13)
	local sign=part("CabinNameSign",V(5.5,.9,.2),V(0,8.91,-13.14),frame,Enum.Material.Wood,fittings,false)
	textSign(sign,string.format("%02d  •  %s",index,names[index]))
	-- Restrained unsettling details: no gore, and every doorway remains usable.
	if index==6 then
		beam("BoardedWindow",V(10.12,6.1,1.9),V(10.12,8.5,7),.22,.55,Color3.fromRGB(122,107,76),shell,false)
		beam("BoardedWindow",V(10.14,8.3,2),V(10.14,6.3,7),.22,.48,Color3.fromRGB(92,81,59),shell,false)
		for scratch=1,3 do
			beam("OldScratch",V(4.6+scratch*.25,4.8,-13.07),V(4.5+scratch*.25,3.8,-13.07),.035,.027,Color3.fromRGB(49,38,25),shell,false)
		end
	elseif index==3 then
		for printIndex=1,4 do
			part("FadedMuddyBootprint",V(.38,.012,.75),CF((printIndex%2==0 and .35 or -.35),.008,-11.8+printIndex*.8)*CFrame.Angles(0,.15,0),Color3.fromRGB(80,72,48),Enum.Material.Ground,inside,false)
		end
	end
	return cabin
end

return B

