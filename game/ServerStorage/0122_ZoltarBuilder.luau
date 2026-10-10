-- Editable mechanical fortune-teller cabinet. Front is -Z, base is Y=0.
local B={}
function B.Build(origin)
 local V,CF=Vector3.new,CFrame.new
 local gold=Color3.fromRGB(188,139,55)
 local bright=Color3.fromRGB(233,190,91)
 local dark=Color3.fromRGB(21,25,23)
 local walnut=Color3.fromRGB(139,84,36)
 local amber=Color3.fromRGB(193,132,62)
 local skin=Color3.fromRGB(155,92,49)
 local silk=Color3.fromRGB(224,177,60)
 local beard=Color3.fromRGB(29,43,31)
 local m=Instance.new("Model");m.Name="ZoltarFortuneMachine";m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 m:SetAttribute("BuildVersion",1);m:SetAttribute("CardDispensingReady",false);m:SetAttribute("PurchaseEnabled",false)
 m:SetAttribute("CardCategories","Survivor Perks|Killer Perks|Killer Variants|Survivor Weapons")
 local function group(name,parent) local o=Instance.new("Model");o.Name=name;o.Parent=parent or m;return o end
 local cabinet=group("Cabinet");local trim=group("GildedMarquetry");local booth=group("GlassBooth");local puppet=group("FortuneTeller");local lamps=group("Illumination");local details=group("ControlsAndCardSlot")
 local function p(name,size,pose,color,mat,parent,shape)
  local o=Instance.new("Part");o.Name=name;o.Size=size;o.CFrame=origin*(typeof(pose)=="Vector3" and CF(pose) or pose);o.Color=color or gold;o.Material=mat or Enum.Material.Metal
  o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false;o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth
  if shape then o.Shape=shape end;o.Parent=parent or cabinet;return o
 end
 local function box(n,s,c,col,mat,parent) return p(n,s,c,col,mat,parent) end
 local function oval(n,s,c,col,mat,parent) return p(n,s,c,col,mat,parent,Enum.PartType.Ball) end
 local function rod(n,a,b,r,col,mat,parent)
  return p(n,V((b-a).Magnitude,r*2,r*2),CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0),col,mat,parent,Enum.PartType.Cylinder)
 end
 local function text(board,content,col,font)
  local g=Instance.new("SurfaceGui");g.Name="Lettering";g.Face=Enum.NormalId.Front;g.CanvasSize=Vector2.new(1000,300);g.LightInfluence=.35;g.Parent=board
  local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=content;t.Font=font or Enum.Font.Garamond;t.TextColor3=col;t.TextScaled=true;t.TextWrapped=true;t.Parent=g
  local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(.04,0);pad.PaddingRight=UDim.new(.04,0);pad.PaddingTop=UDim.new(.06,0);pad.PaddingBottom=UDim.new(.06,0);pad.Parent=t
 end
 local base=box("CabinetBase",V(6.15,.32,4.7),V(0,.16,0),dark,Enum.Material.Wood);base.CanCollide=true;base.CanQuery=true;m.PrimaryPart=base
 local solid=box("LowerCabinetCollision",V(5.8,5.7,4.25),V(0,3.03,0),walnut,Enum.Material.Wood);solid.CanCollide=true;solid.CanQuery=true
 for _,y in ipairs({.38,3.08,5.82,12.79,13.12}) do
  box("MouldedGoldPlinth",V(y>12.8 and 6.35 or 6.02,.18,y>12.8 and 4.9 or 4.55),V(0,y,0),gold,Enum.Material.Metal,trim)
  box("BlackShadowLine",V(5.94,.065,4.48),V(0,y+.13,0),dark,Enum.Material.Wood,trim)
 end
 box("CrownCap",V(6.55,.2,5.08),V(0,13.37,0),dark,Enum.Material.Wood,trim)
 box("CrownGoldLip",V(6.45,.055,4.98),V(0,13.24,0),bright,Enum.Material.Metal,trim)
 box("LowerInsetPanel",V(5.15,2.36,.12),V(0,1.73,-2.19),amber,Enum.Material.Wood,cabinet)
 box("PaymentPanel",V(5.15,2.35,.12),V(0,4.48,-2.19),amber,Enum.Material.Wood,cabinet)
 for _,side in ipairs({-1,1}) do
  for _,y in ipairs({1.72,4.45}) do box("SideWoodPanel",V(.13,2.36,3.7),V(side*2.93,y,0),amber,Enum.Material.Wood,cabinet) end
  for _,z in ipairs({-2.16,2.16}) do
   box("CornerPillar",V(.32,12.8,.32),V(side*2.76,6.77,z),gold,Enum.Material.Metal,trim)
   box("BlackInlayVertical",V(.19,12.48,.035),V(side*2.76,6.75,z-.18),dark,Enum.Material.SmoothPlastic,trim)
   for y=.65,12.7,.28 do
    box("GoldInlayDiamond",V(.115,.14,.045),CF(side*2.76,y,z-.21)*CFrame.Angles(0,0,math.pi/4),bright,Enum.Material.Metal,trim)
   end
  end
 end
 for _,y in ipairs({.61,3.19,5.68,6.03,12.74,13.05}) do
  box("BlackInlayRail",V(5.35,.21,.055),V(0,y,-2.345),dark,Enum.Material.SmoothPlastic,trim)
  for x=-2.5,2.51,.27 do
   box("GoldRailRosette",V(.12,.12,.06),CF(x,y,-2.386)*CFrame.Angles(0,0,math.pi/4),bright,Enum.Material.Metal,trim)
   box("GoldRailLeaf",V(.10,.047,.065),CF(x+.1,y+.07,-2.39)*CFrame.Angles(0,0,.3),gold,Enum.Material.Metal,trim)
  end
  for _,side in ipairs({-1,1}) do
   box("SideBlackInlayRail",V(.06,.21,4.27),V(side*2.96,y,0),dark,Enum.Material.SmoothPlastic,trim)
   for z=-2,2,.29 do box("SideGoldRosette",V(.06,.12,.12),CF(side*3,y,z)*CFrame.Angles(math.pi/4,0,0),bright,Enum.Material.Metal,trim) end
  end
 end
 for _,side in ipairs({-1,1}) do for _,y in ipairs({.52,3.17,5.88,12.8}) do
  box("CornerSquareEscutcheon",V(.4,.35,.085),V(side*2.77,y,-2.39),bright,Enum.Material.Metal,trim)
  box("EscutcheonInset",V(.23,.2,.035),V(side*2.77,y,-2.447),gold,Enum.Material.Metal,trim)
 end end
 box("CabinetBack",V(5.6,6.75,.2),V(0,9.36,2.12),walnut,Enum.Material.Wood,booth)
 box("VelvetBackdrop",V(5.34,6.2,.09),V(0,9.3,1.98),Color3.fromRGB(25,26,39),Enum.Material.Fabric,booth)
 for _,side in ipairs({-1,1}) do
  local glass=box("SideGlass",V(.065,6.3,4.13),V(side*2.71,9.38,0),Color3.fromRGB(185,208,195),Enum.Material.Glass,booth);glass.Transparency=.83;glass.Reflectance=.06;glass.CanCollide=true
  for fold=0,6 do
   oval("VelvetCurtainFold",V(.19,5.25,.25),CF(side*(1.88+fold*.1),9.4,1.67-.06*math.cos(fold)),Color3.fromRGB(24+fold%2*5,25+fold%2*5,38+fold%2*8),Enum.Material.Fabric,booth)
  end
  rod("CurtainTie",V(side*2.28,8.8,1.43),V(side*1.83,8.9,1.43),.07,bright,Enum.Material.Fabric,booth)
 end
 local glass=box("FrontGlass",V(5.1,5.62,.055),V(0,9.08,-2.17),Color3.fromRGB(191,214,202),Enum.Material.Glass,booth);glass.Transparency=.9;glass.Reflectance=.025;glass.CanCollide=true
 local sign=box("IlluminatedMarquee",V(5.08,1.16,.13),V(0,12.04,-2.12),Color3.fromRGB(210,184,103),Enum.Material.Neon,booth)
 text(sign,"ZOLTAR",Color3.fromRGB(119,21,21))
 for x=-2.4,2.41,.16 do
  local length=.22+.20*(.5+.5*math.cos(x*3))
  rod("GoldValanceFringe",V(x,11.49,-1.91),V(x,11.49-length,-1.91),.025,bright,Enum.Material.Fabric,booth)
 end
 local lettering=box("SpeaksLettering",V(3.7,.58,.025),V(0,6.65,-2.225),gold,Enum.Material.Glass,booth);lettering.Transparency=1;text(lettering,"SPEAKS",bright)
 box("VelvetTable",V(5.15,.19,3.92),V(0,6.35,0),Color3.fromRGB(55,31,41),Enum.Material.Fabric,booth)
 -- The figure is a dimensional, layered puppet with a separate jaw assembly.
 oval("SilkTorso",V(2.64,2.85,1.19),V(0,8.13,.55),silk,Enum.Material.Fabric,puppet)
 for _,side in ipairs({-1,1}) do
  oval("VestPanel",V(.86,2.64,.33),CF(side*.82,8.2,-.06)*CFrame.Angles(0,0,side*.11),dark,Enum.Material.Fabric,puppet)
  rod("VestGoldBraid",V(side*.42,6.99,-.285),V(side*.43,9.29,-.285),.035,gold,Enum.Material.Fabric,puppet)
  for row=0,7 do for col=0,2 do
   oval("VestBrocade",V(.085,.16,.035),CF(side*(.66+col*.17),7.2+row*.27,-.245)*CFrame.Angles(0,0,side*.5),Color3.fromRGB(107,100,54),Enum.Material.Fabric,puppet)
  end end
  oval("SilkUpperSleeve",V(.94,1.89,.92),CF(side*1.48,8.16,.3)*CFrame.Angles(0,0,side*.34),silk,Enum.Material.Fabric,puppet)
  oval("SilkForearm",V(.88,1.57,.87),CF(side*1.55,7.38,-.44)*CFrame.Angles(-.76,0,side*-.2),silk,Enum.Material.Fabric,puppet)
  oval("FoldedGoldCuff",V(.69,.35,.69),CF(side*1.43,7.16,-1.01)*CFrame.Angles(-.5,0,side*.15),bright,Enum.Material.Fabric,puppet)
  oval("PuppetHand",V(.65,.33,.63),CF(side*1.32,7.23,-1.28)*CFrame.Angles(-.1,0,side*.15),skin,Enum.Material.SmoothPlastic,puppet)
  for finger=0,3 do
   local x=side*1.32+(finger-1.5)*.135
   rod("CarvedFinger",V(x,7.25,-1.36),V(x+side*.025,7.02,-1.63),.07,skin,Enum.Material.SmoothPlastic,puppet)
   oval("Fingernail",V(.085,.035,.12),CF(x+side*.025,7.065,-1.6)*CFrame.Angles(-.7,0,0),Color3.fromRGB(193,143,95),Enum.Material.SmoothPlastic,puppet)
  end
  oval("Thumb",V(.19,.28,.43),CF(side*1.05,7.19,-1.31)*CFrame.Angles(0,side*.4,0),skin,Enum.Material.SmoothPlastic,puppet)
 end
 rod("Neck",V(0,9.12,.49),V(0,9.9,.49),.34,skin,Enum.Material.SmoothPlastic,puppet)
 for _,s in ipairs({-1,1}) do box("HighSilkCollar",V(.47,.52,.25),CF(s*.26,9.3,.12)*CFrame.Angles(0,0,s*.24),bright,Enum.Material.Fabric,puppet) end
 oval("CarvedHead",V(1.16,1.66,1.07),V(0,10.39,.42),skin,Enum.Material.SmoothPlastic,puppet)
 for _,s in ipairs({-1,1}) do
  oval("Cheek",V(.42,.57,.34),V(s*.35,10.17,-.08),Color3.fromRGB(166,101,54),Enum.Material.SmoothPlastic,puppet)
  oval("Ear",V(.22,.48,.28),V(s*.61,10.27,.39),skin,Enum.Material.SmoothPlastic,puppet)
  oval("EarConcha",V(.12,.27,.07),V(s*.64,10.25,.23),Color3.fromRGB(112,62,35),Enum.Material.SmoothPlastic,puppet)
  oval("EyeSocket",V(.43,.28,.14),CF(s*.26,10.56,-.044)*CFrame.Angles(0,0,s*.08),Color3.fromRGB(93,55,31),Enum.Material.SmoothPlastic,puppet)
  oval("IvoryEye",V(.32,.19,.11),V(s*.26,10.56,-.115),Color3.fromRGB(216,207,172),Enum.Material.SmoothPlastic,puppet)
  oval("EmeraldIris",V(.118,.14,.055),V(s*.24,10.555,-.172),Color3.fromRGB(61,111,81),Enum.Material.Glass,puppet)
  oval("Pupil",V(.054,.102,.025),V(s*.24,10.555,-.204),dark,Enum.Material.SmoothPlastic,puppet)
  oval("EyeGlint",V(.028,.035,.018),V(s*.24-.018,10.587,-.222),Color3.fromRGB(255,243,194),Enum.Material.Neon,puppet)
  oval("HeavyEyebrow",V(.45,.095,.12),CF(s*.28,10.755,-.073)*CFrame.Angles(0,0,-s*.15),beard,Enum.Material.SmoothPlastic,puppet)
  oval("Moustache",V(.55,.22,.25),CF(s*.22,10.0,-.25)*CFrame.Angles(0,0,-s*.25),beard,Enum.Material.SmoothPlastic,puppet)
  oval("MoustacheTip",V(.16,.35,.16),CF(s*.42,9.86,-.19)*CFrame.Angles(0,0,-s*.25),beard,Enum.Material.SmoothPlastic,puppet)
 end
 oval("NoseBridge",V(.24,.52,.31),V(0,10.4,-.15),Color3.fromRGB(177,110,59),Enum.Material.SmoothPlastic,puppet)
 oval("NoseTip",V(.31,.26,.3),V(0,10.23,-.29),skin,Enum.Material.SmoothPlastic,puppet)
 for _,s in ipairs({-1,1}) do oval("Nostril",V(.095,.055,.03),V(s*.095,10.15,-.345),Color3.fromRGB(62,34,22),Enum.Material.SmoothPlastic,puppet) end
 oval("MouthCavity",V(.51,.36,.06),V(0,9.82,-.14),Color3.fromRGB(25,13,13),Enum.Material.SmoothPlastic,puppet)
 local jaw=group("PuppetJaw",puppet)
 local pivot=box("JawHinge",V(.08,.08,.08),V(0,9.93,.38),skin,Enum.Material.SmoothPlastic,jaw);pivot.Transparency=1;jaw.PrimaryPart=pivot
 oval("LowerJaw",V(.69,.49,.63),V(0,9.7,.11),skin,Enum.Material.SmoothPlastic,jaw)
 oval("LowerLip",V(.4,.08,.11),V(0,9.855,-.22),Color3.fromRGB(130,68,42),Enum.Material.SmoothPlastic,jaw)
 oval("PointedBeard",V(.63,.93,.46),CF(0,9.38,.005)*CFrame.Angles(-.13,0,0),beard,Enum.Material.SmoothPlastic,jaw)
 for i=-3,3 do rod("CarvedBeardGroove",V(i*.076,9.63,-.235),V(i*.044,9.04,-.105),.013,Color3.fromRGB(68,75,43),Enum.Material.SmoothPlastic,jaw) end
 oval("TurbanSilhouette",V(1.48,.9,1.24),V(0,11.28,.46),silk,Enum.Material.Fabric,puppet)
 for i=0,4 do
  oval("TurbanWrappedFold",V(1.48-i*.08,.17,1.19-i*.06),CF(0,10.99+i*.14,.43)*CFrame.Angles(0,0,(i%2==0 and .1 or -.07)),Color3.fromRGB(213+i*5,162+i*6,48+i*7),Enum.Material.Fabric,puppet)
 end
 oval("TurbanJewelSetting",V(.37,.47,.12),V(0,11.3,-.17),bright,Enum.Material.Metal,puppet)
 oval("TurbanRuby",V(.2,.28,.12),V(0,11.3,-.25),Color3.fromRGB(143,18,29),Enum.Material.Glass,puppet)
 for i=0,15 do local a=i*math.pi*2/16;oval("JewelPearl",V(.047,.047,.047),V(math.cos(a)*.158,11.3+math.sin(a)*.2,-.245),Color3.fromRGB(232,223,169),Enum.Material.Metal,puppet) end
 for i=0,15 do local a=i*math.pi*2/16;local b=(i+1)*math.pi*2/16;rod("GoldHoopEarring",V(.66+math.cos(a)*.115,9.94+math.sin(a)*.19,.25),V(.66+math.cos(b)*.115,9.94+math.sin(b)*.19,.25),.024,bright,Enum.Material.Metal,puppet) end
 for i=0,26 do local t=i/26;oval("NecklaceLink",V(.095,.14,.075),CF(-.58+t*1.16,9.16-.74*math.sin(math.pi*t),-.22)*CFrame.Angles(0,0,t*1.4-.7),bright,Enum.Material.Metal,puppet) end
 oval("NecklacePendant",V(.27,.36,.08),V(0,8.27,-.26),gold,Enum.Material.Metal,puppet)
 for _,s in ipairs({-1,1}) do
  rod("SconceArm",V(s*1.83,9.15,1.45),V(s*1.83,9.7,1.08),.055,gold,Enum.Material.Metal,lamps)
  oval("SconceBowl",V(.61,.38,.61),V(s*1.83,9.77,1.08),gold,Enum.Material.Metal,lamps)
  local globe=oval("SconceGlow",V(.55,.7,.55),V(s*1.83,10.14,1.08),Color3.fromRGB(255,187,91),Enum.Material.Neon,lamps)
  oval("SconceCrown",V(.59,.15,.59),V(s*1.83,10.51,1.08),dark,Enum.Material.Metal,lamps)
  local light=Instance.new("PointLight");light.Name="WarmBoothLight";light.Brightness=1.1;light.Range=9;light.Color=Color3.fromRGB(255,194,109);light.Shadows=true;light.Parent=globe
 end
 for _,entry in ipairs({{.19,.64,6.49},{.14,.5,6.64},{.1,.39,6.75}}) do p("CrystalBallPedestal",V(entry[1],entry[2]*2,entry[2]*2),CF(-1.24,entry[3],-1.05)*CFrame.Angles(0,0,math.pi/2),gold,Enum.Material.Metal,booth,Enum.PartType.Cylinder) end
 local ball=oval("AmethystCrystalBall",V(1.13,1.13,1.13),V(-1.24,7.29,-1.05),Color3.fromRGB(179,105,219),Enum.Material.Neon,booth)
 local aura=Instance.new("PointLight");aura.Name="CrystalGlow";aura.Color=Color3.fromRGB(182,110,238);aura.Brightness=.65;aura.Range=5;aura.Parent=ball
 local cardPose=CF(1.16,7.47,-1.24)*CFrame.Angles(-.19,0,.3)
 box("HeldFortuneCardBorder",V(.53,.76,.035),cardPose,bright,Enum.Material.Metal,puppet)
 box("HeldFortuneCardBack",V(.45,.68,.02),cardPose*CF(0,0,-.031),Color3.fromRGB(36,44,71),Enum.Material.Fabric,puppet)
 oval("CardStarSeal",V(.18,.18,.025),cardPose*CF(0,0,-.052),gold,Enum.Material.Metal,puppet)
 -- Actual openings and lips are separate parts for the later card and Moin sequence.
 box("CardSlotSurround",V(1.23,.56,.16),V(-1.52,4.87,-2.29),gold,Enum.Material.Metal,details)
 box("CardSlotDarkOpening",V(.93,.16,.018),V(-1.52,4.86,-2.384),Color3.fromRGB(9,10,8),Enum.Material.SmoothPlastic,details)
 box("CardCollectionLip",V(1.14,.08,.34),V(-1.52,4.61,-2.44),gold,Enum.Material.Metal,details)
 local label=box("CardSlotLabel",V(1.38,.25,.024),V(-1.52,4.36,-2.275),gold,Enum.Material.Metal,details);text(label,"YOUR FORTUNE",dark)
 p("SpeakerBrassBezel",V(.10,.99,.99),CF(0,4.25,-2.3)*CFrame.Angles(0,math.pi/2,0),gold,Enum.Material.Metal,details,Enum.PartType.Cylinder)
 p("SpeakerBlackGrille",V(.03,.84,.84),CF(0,4.25,-2.371)*CFrame.Angles(0,math.pi/2,0),dark,Enum.Material.Metal,details,Enum.PartType.Cylinder)
 for x=-3,3 do for y=-3,3 do if x*x+y*y<10 then oval("SpeakerPerforation",V(.04,.04,.018),V(x*.1,4.25+y*.1,-2.395),Color3.fromRGB(74,67,42),Enum.Material.Metal,details) end end end
 box("CoinMechanismBlackPlate",V(.68,1.0,.18),V(1.85,4.82,-2.30),dark,Enum.Material.Metal,details)
 box("CoinMechanismBrassFrame",V(.53,.76,.07),V(1.85,4.76,-2.416),bright,Enum.Material.Metal,details)
 box("MoinEntrySlot",V(.07,.32,.018),V(1.85,4.92,-2.467),dark,Enum.Material.SmoothPlastic,details)
 local coinLabel=box("MoinLabel",V(.46,.24,.02),V(1.85,4.53,-2.462),Color3.fromRGB(232,219,154),Enum.Material.SmoothPlastic,details);text(coinLabel,"MOIN",dark)
 box("CoinReadyIndicator",V(.41,.055,.03),V(1.85,5.28,-2.414),Color3.fromRGB(154,198,101),Enum.Material.Neon,lamps)
 for _,x in ipairs({-2.36,2.36}) do for _,y in ipairs({.97,2.47,3.58,5.34}) do oval("PanelScrew",V(.052,.052,.025),V(x,y,-2.265),gold,Enum.Material.Metal,details) end end
 local anchors=Instance.new("Folder");anchors.Name="SequenceAnchors";anchors.Parent=m
 for name,pos in pairs({MoinEntry=V(1.85,4.92,-2.65),SlideMount=V(2.15,10.45,-1.5),MouthTarget=V(0,9.82,-.48),CardExit=V(-1.52,4.86,-2.6),CardPickup=V(-1.52,4.77,-3.15)}) do local o=box(name,V(.08,.08,.08),pos,gold,Enum.Material.Metal,anchors);o.Transparency=1 end
 local prompt=Instance.new("ProximityPrompt");prompt.Name="ConsultZoltar";prompt.ActionText="Awaken Zoltar";prompt.ObjectText="Zoltar Speaks";prompt.MaxActivationDistance=10;prompt.HoldDuration=.35;prompt.RequiresLineOfSight=false;prompt.Parent=details.CoinMechanismBlackPlate
 return m
end
return B
