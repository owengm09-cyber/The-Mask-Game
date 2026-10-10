-- The Harlequin: native Roblox articulated creature, no external assets required.
local Rig={}
local V=Vector3.new
local C=CFrame.new
local A=CFrame.Angles
local BLACK=Color3.fromRGB(18,17,20)
local BONE=Color3.fromRGB(42,36,37)
local IVORY=Color3.fromRGB(221,216,197)
local SOOT=Color3.fromRGB(8,7,10)
local function part(name,size,color,parent)
 local p=Instance.new("Part")
 p.Name=name p.Size=size p.Color=color or BLACK
 p.Material=Enum.Material.SmoothPlastic
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 p.CanCollide=false p.CanTouch=false p.CanQuery=false p.Massless=true
 p.CastShadow=true p.Parent=parent
 local mesh=Instance.new("SpecialMesh") mesh.MeshType=Enum.MeshType.Sphere mesh.Parent=p
 return p
end
local function detail(name,base,offset,size,color)
 local p=part(name,size,color,base.Parent)
 p.CFrame=base.CFrame*offset
 local w=Instance.new("Weld") w.Name="DetailWeld" w.Part0=base w.Part1=p w.C0=offset w.Parent=p
 return p
end
local function stroke(name,base,a,b,width,color)
 local offset=CFrame.lookAt((a+b)/2,b)*A(math.pi/2,0,0)
 return detail(name,base,offset,V(width,(b-a).Magnitude,width*.75),color)
end
function Rig.Build(name)
 local m=Instance.new("Model") m.Name=name or "HarlequinCreature" m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local root=Instance.new("Part") root.Name="CreatureRoot" root.Size=V(.3,.3,.3)
 root.Transparency=1 root.CanCollide=false root.CanTouch=false root.CanQuery=false root.Massless=true root.Parent=m
 m.PrimaryPart=root
 local function bone(name,size,col)
  local p=part(name,size,col,m)
  local motor=Instance.new("Motor6D") motor.Name=name.."Joint" motor.Part0=root motor.Part1=p motor.Parent=root
  return p
 end
 bone("Pelvis",V(.95,1.05,.7),BONE)
 local chest=bone("Chest",V(1.15,2.55,.72),BLACK)
 bone("Abdomen",V(.56,1.65,.5),BLACK)
 bone("Neck",V(.33,1.3,.34),BONE)
 local head=bone("Skull",V(1.3,1.95,.91),BLACK)
 for i=1,6 do
  local y=.95-(i-1)*.33
  for _,side in ipairs({-1,1}) do
   stroke("Rib"..i.."_"..side,chest,V(0,y,-.4),V(side*.61,y-.10,-.36),.095,BONE)
   stroke("RibReturn"..i.."_"..side,chest,V(side*.61,y-.1,-.36),V(side*.53,y-.29,.12),.085,BONE)
  end
  detail("Vertebra"..i,chest,C(0,y,.42),V(.24,.23,.3),BONE)
 end
 for _,side in ipairs({-1,1}) do
  stroke("Collarbone"..side,chest,V(0,1.05,-.25),V(side*.92,.98,-.12),.14,BONE)
  for _,limb in ipairs({"Arm","Leg"}) do
   bone(limb..side.."Upper",V(.25,3,.27),BLACK)
   bone(limb..side.."Lower",V(.17,3,.2),BLACK)
   bone(limb..side.."Joint",V(.38,.41,.37),BONE)
   local extremity=bone(limb..side.."End",limb=="Arm" and V(.45,.28,.85) or V(.4,.36,1.1),BLACK)
   for finger=1,3 do
    local x=(finger-2)*.17
    local len=limb=="Arm" and (1.05-math.abs(finger-2)*.18) or .55
    stroke(limb.."Talon"..side.."_"..finger,extremity,V(x,0,-.28),V(x*1.45,-.06,-.28-len),.075,BONE)
    stroke(limb.."Tip"..side.."_"..finger,extremity,V(x*1.45,-.06,-.28-len),V(x*1.55,-.22,-.43-len),.042,SOOT)
   end
  end
 end
 -- The two actual faces sit on opposing sides of a rotating skull.
 for _,face in ipairs({{name="Comedy",yaw=0,sad=false},{name="Tragedy",yaw=math.pi,sad=true}}) do
  local turn=A(0,face.yaw,0)
  local mask=detail(face.name,head,turn*C(0,-.05,-.48),V(1.53,2.05,.36),IVORY)
  detail(face.name.."Chin",mask,C(0,-.68,-.03),V(.86,.72,.3),IVORY)
  for _,side in ipairs({-1,1}) do
   local eyeRot=face.sad and side*-.26 or side*.16
   detail("EyeSocket"..side,mask,C(side*.36,.25,-.19)*A(0,0,eyeRot),V(.48,.23,.09),SOOT)
   detail("EyePin"..side,mask,C(side*.34,.24,-.246),V(.045,.05,.015),Color3.fromRGB(105,68,59))
   local a=V(side*.12,.65,-.16)
   local b=V(side*.58,face.sad and .41 or .74,-.14)
   stroke("Brow"..side,mask,a,b,.095,SOOT)
   detail("Cheek"..side,mask,C(side*.45,-.18,-.17),V(.4,.32,.16),Color3.fromRGB(230,225,208))
   if face.sad then
    stroke("Tear"..side,mask,V(side*.42,.11,-.22),V(side*.52,-.43,-.16),.045,Color3.fromRGB(67,58,61))
   end
  end
  detail("Nose",mask,C(0,.02,-.27)*A(.14,0,0),V(.19,.53,.3),IVORY)
  for _,side in ipairs({-1,1}) do detail("Nostril"..side,mask,C(side*.09,-.18,-.34),V(.095,.055,.045),SOOT) end
  -- Strong curved mouth silhouette, with a porcelain lip and asymmetrical corners.
  for j=0,10 do
   local x=-.51+j*.102
   local curve=1-(x/.53)^2
   local y=face.sad and (-.6+.25*curve) or (-.31-.40*curve)
   detail("Mouth"..j,mask,C(x,y,-.2),V(.155,face.sad and .23 or .3,.065),SOOT)
   detail("Lip"..j,mask,C(x,y-.14,-.197),V(.13,.06,.08),Color3.fromRGB(187,179,163))
  end
  stroke("Crack",mask,V(.54,.86,-.12),V(.42,.64,-.21),.023,Color3.fromRGB(76,66,63))
  stroke("CrackFork",mask,V(.42,.64,-.21),V(.53,.54,-.21),.021,Color3.fromRGB(76,66,63))
 end
 -- A crooked, tapering crest echoes the needle-like reference silhouette.
 local crest={V(0,.78,.08),V(.06,1.45,.16),V(.19,2.08,.26),V(.39,2.74,.34),V(.60,3.18,.40)}
 for i=1,#crest-1 do
  stroke("Crest"..i,head,crest[i],crest[i+1],.53*(1-(i-1)/4)^1.3,BLACK)
 end
 m:SetAttribute("CreatureVersion",1)
 m:SetAttribute("AttackAt",-100)
 m:SetAttribute("KillAt",-100)
 return m
end
function Rig.Bind(m)
 local root=m:WaitForChild("CreatureRoot",5)
 if not root then return nil end
 local ctx={model=m,root=root,motors={},parts={}}
 for _,v in ipairs(root:GetChildren()) do if v:IsA("Motor6D") then ctx.motors[v.Part1.Name]=v ctx.parts[v.Part1.Name]=v.Part1 end end
 return ctx
end
function Rig.Pose(ctx,t,blend,attackAge,killAge)
 local function place(name,cf)
  local motor=ctx.motors[name] if motor then motor.C0=cf end
 end
 local function segment(name,a,b)
  local p=ctx.parts[name] if not p then return end
  p.Size=V(p.Size.X,math.max(.05,(b-a).Magnitude),p.Size.Z)
  place(name,CFrame.lookAt((a+b)/2,b)*A(math.pi/2,0,0))
 end
 local kill=killAge>=0 and killAge<2.05
 local attack=attackAge>=0 and attackAge<.65
 if kill then blend=blend*(1-math.min(killAge*3,1)) end
 local breath=math.sin(t*1.4)*.055
 local gait=t*8.5
 local bob=math.sin(gait*2)*.12*blend
 local hip=V(0,2.05,0):Lerp(V(0,.15+bob,.8),blend)
 local chest=V(0,4.0+breath,-.28):Lerp(V(0,.85+bob,-1.1),blend)
 local neck=chest+V(.03,.96,-.35):Lerp(V(0,.24,-.93),blend)
 local skull=neck+V(.02,.94,-.06):Lerp(V(0,.3,-.66),blend)
 local headYaw=0
 if killAge>=0 and killAge<7 then
  if killAge<.45 then headYaw=0
  elseif killAge<1.45 then local q=(killAge-.45) headYaw=math.pi*(q*q*(3-2*q))
  elseif killAge<5.8 then headYaw=math.pi
  else local q=math.clamp((killAge-5.8)/1.2,0,1) headYaw=math.pi*(1+q*q*(3-2*q)) end
 end
 place("Pelvis",C(hip)*A(-.1-blend*.3,0,0))
 segment("Abdomen",hip,chest)
 place("Chest",C(chest)*A(-blend*1.15,0,math.sin(t*.65)*.028))
 segment("Neck",chest+V(0,.6,0),neck)
 place("Skull",C(skull)*A(.05+blend*.1,headYaw,math.sin(t*.53)*.09))
 for _,side in ipairs({-1,1}) do
  local phase=gait+(side==1 and math.pi or 0)
  local stride=math.sin(phase)*1.05*blend
  local lift=math.max(0,math.cos(phase))*.8*blend
  local shoulder=chest+V(side*.82,.72,-.03):Lerp(V(side*.8,-.06,-.37),blend)
  local elbow=V(side*1.11,1.60,-.05):Lerp(V(side*1.72,-.35,-1.9+stride*.3),blend)
  local hand=V(side*1.1,-.75,-.6):Lerp(V(side*1.42,-2.78+lift,-3.3+stride),blend)
  if attack or kill then
   local age=kill and math.min(killAge,.7) or attackAge
   local swing=math.sin(math.clamp(age/.65,0,1)*math.pi)
   elbow=elbow:Lerp(V(side*1.9,3.2,-1.6),swing)
   hand=hand:Lerp(V(side*.8,2.9,-4.1),swing)
  end
  segment("Arm"..side.."Upper",shoulder,elbow)
  segment("Arm"..side.."Lower",elbow,hand)
  place("Arm"..side.."Joint",C(elbow))
  place("Arm"..side.."End",C(hand)*A(blend*-.08,side*.14,side*-.1))
  local joint=hip+V(side*.52,0,0)
  local knee=V(side*.78,-.1,.60):Lerp(V(side*1.15,-.60,2.15-stride*.2),blend)
  local foot=V(side*.65,-2.82,.10):Lerp(V(side*.98,-2.82+math.max(0,-math.cos(phase))*.75*blend,1.38-stride),blend)
  segment("Leg"..side.."Upper",joint,knee)
  segment("Leg"..side.."Lower",knee,foot)
  place("Leg"..side.."Joint",C(knee))
  place("Leg"..side.."End",C(foot)*A(0,side*-.13,0))
 end
end
return Rig
