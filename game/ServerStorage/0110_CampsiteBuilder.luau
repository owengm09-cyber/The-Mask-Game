-- Native editable campsite and signal pistol; no downloaded assets or scripts.
local B={}
local V,C=Vector3.new,CFrame.new
local brown=Color3.fromRGB(73,47,31)
local function part(parent,name,size,cf,color,material,shape)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=color
 p.Material=material or Enum.Material.Wood p.Anchored=true p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end p.Parent=parent return p
end
local function cylinder(parent,name,a,b,r,color,material)
 local d=b-a
 return part(parent,name,V(d.Magnitude,r*2,r*2),CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0),color,material,Enum.PartType.Cylinder)
end
function B.Gun()
 local tool=Instance.new("Tool") tool.Name="Emergency Flare" tool.CanBeDropped=false tool.ToolTip="Fire into the sky to call an emergency meeting"
 tool:SetAttribute("MeetingFlare",true)
 local orange=Color3.fromRGB(202,66,42) local black=Color3.fromRGB(33,35,34) local metal=Enum.Material.Metal
 local handle=part(tool,"Handle",V(.42,.92,.52),C(0,-.48,.5)*CFrame.Angles(math.rad(-20),0,0),orange,metal)
 part(tool,"RubberGrip",V(.45,.79,.36),C(0,-.49,.57)*CFrame.Angles(math.rad(-20),0,0),black,Enum.Material.SmoothPlastic)
 cylinder(tool,"SignalBarrel",V(0,.37,-1.24),V(0,.37,.33),.27,orange,metal)
 cylinder(tool,"BreechBand",V(0,.37,.25),V(0,.37,.42),.30,Color3.fromRGB(84,85,79),metal)
 cylinder(tool,"MuzzleRim",V(0,.37,-1.28),V(0,.37,-1.18),.285,orange,metal)
 cylinder(tool,"DarkBore",V(0,.37,-1.291),V(0,.37,-1.283),.21,Color3.fromRGB(8,9,9),metal)
 part(tool,"Frame",V(.40,.40,.98),C(0,.02,.05),orange,metal)
 part(tool,"Hammer",V(.18,.18,.46),C(0,.55,.56)*CFrame.Angles(math.rad(-25),0,0),black,metal)
 part(tool,"Trigger",V(.11,.32,.10),C(0,-.22,-.16)*CFrame.Angles(math.rad(22),0,0),black,metal)
 for i=0,9 do
  local a=math.pi*.05+i*math.pi*1.9/10 local b=math.pi*.05+(i+1)*math.pi*1.9/10
  cylinder(tool,"TriggerGuard",V(0,-.21+math.cos(a)*.37,-.16+math.sin(a)*.41),V(0,-.21+math.cos(b)*.37,-.16+math.sin(b)*.41),.045,orange,metal)
 end
 for _,z in ipairs({-.35,.25}) do cylinder(tool,"FrameRivet",V(-.212,.05,z),V(.212,.05,z),.055,black,metal) end
 for _,p in ipairs(tool:GetChildren()) do if p:IsA("BasePart") then
  p.Anchored=false p.CanCollide=false p.CanTouch=false p.Massless=true
  if p~=handle then local w=Instance.new("WeldConstraint") w.Part0=handle w.Part1=p w.Parent=p end
 end end
 tool.Grip=CFrame.new(0,-.15,.05)*CFrame.Angles(math.rad(-35),0,0)
 return tool
end
function B.Build(origin)
 local m=Instance.new("Model") m.Name="EmergencyCampsite" m.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 m:SetAttribute("MeetingDuration",45) m:SetAttribute("FlareCooldown",60)
 local cf=C(origin)
 local function P(name,size,offset,color,mat,shape) return part(m,name,size,cf*offset,color,mat,shape) end
 local marker=P("CampCenter",V(.2,.2,.2),C(0,.1,0),brown) marker.Transparency=1 marker.CanCollide=false m.PrimaryPart=marker
 local soil=P("CharredEarth",V(.16,9,9),C(0,.06,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(43,36,28),Enum.Material.Ground,Enum.PartType.Cylinder)
 for i=1,18 do
  local a=i*math.pi*2/18
  P("FireRingStone",V(1.4,.75,1.05),C(math.cos(a)*4.1,.39,math.sin(a)*4.1)*CFrame.Angles(.12*math.sin(i),-a,.15*math.cos(i)),Color3.fromRGB(79+i%3*9,78+i%3*8,70+i%3*8),Enum.Material.Slate,Enum.PartType.Ball)
 end
 for i=1,7 do
  local a=i*math.pi*2/7
  cylinder(m,"Firewood",origin+V(math.cos(a)*2.6,.45,math.sin(a)*2.6),origin+V(math.cos(a+.2)*.35,2.55,math.sin(a+.2)*.35),.29,brown,Enum.Material.Wood)
 end
 for i=1,12 do
  local a=i*2.399
  P("GlowingCoal",V(.38,.20,.63),C(math.cos(a)*(i%3+.2),.28,math.sin(a)*(i%3+.2)),Color3.fromRGB(255,90+i%4*15,12),Enum.Material.Neon)
 end
 local fireBase=P("FireGlow",V(1,.2,1),C(0,.8,0),Color3.fromRGB(252,134,35),Enum.Material.Neon) fireBase.Transparency=1 fireBase.CanCollide=false
 local fire=Instance.new("Fire") fire.Color=Color3.fromRGB(255,176,47) fire.SecondaryColor=Color3.fromRGB(219,60,14) fire.Heat=9 fire.Size=7 fire.Parent=fireBase
 local light=Instance.new("PointLight") light.Name="CampfireLight" light.Color=Color3.fromRGB(255,156,63) light.Brightness=3 light.Range=40 light.Shadows=true light.Parent=fireBase
 local smoke=Instance.new("Smoke") smoke.Color=Color3.fromRGB(101,94,84) smoke.Opacity=.14 smoke.RiseVelocity=5 smoke.Size=4 smoke.Parent=fireBase
 local embers=Instance.new("ParticleEmitter") embers.Name="Embers" embers.Texture="rbxasset://textures/particles/sparkles_main.dds" embers.Color=ColorSequence.new(Color3.fromRGB(255,150,49)) embers.LightEmission=1 embers.Rate=7 embers.Lifetime=NumberRange.new(1.5,3) embers.Speed=NumberRange.new(3,7) embers.Acceleration=V(0,2,0) embers.SpreadAngle=Vector2.new(20,20) embers.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.10),NumberSequenceKeypoint.new(1,0)}) embers.Parent=fireBase
 local seats=Instance.new("Folder") seats.Name="MeetingSeats" seats.Parent=m
 for i=1,6 do
  local a=(i-1)*math.pi/3 local mid=origin+V(math.cos(a)*11,.85,math.sin(a)*11)
  local tangent=V(-math.sin(a),0,math.cos(a))
  cylinder(m,"SeatingLog",mid-tangent*4.8,mid+tangent*4.8,.84,brown,Enum.Material.Wood)
  for _,s in ipairs({-1,1}) do
   cylinder(m,"CutLogEnd",mid+tangent*(s*4.81),mid+tangent*(s*4.86),.73,Color3.fromRGB(154,114,70),Enum.Material.Wood)
   cylinder(m,"Heartwood",mid+tangent*(s*4.87),mid+tangent*(s*4.88),.32,Color3.fromRGB(112,76,44),Enum.Material.Wood)
   local seat=Instance.new("Seat") seat.Name=string.format("Seat%02d",(i-1)*2+(s==1 and 2 or 1)) seat.Size=V(2,.2,2)
   local pos=mid+tangent*s*2.2+V(0,.83,0)
   seat.CFrame=CFrame.lookAt(pos,V(origin.X,pos.Y,origin.Z)) seat.Transparency=1 seat.Anchored=true seat.CanCollide=false seat.Parent=seats
  end
 end
 local colors={Color3.fromRGB(45,84,91),Color3.fromRGB(170,113,55),Color3.fromRGB(88,99,60),Color3.fromRGB(104,69,54)}
 for i=1,4 do
  local a=(i-1)*math.pi/2+math.pi/4 local pos=origin+V(math.cos(a)*24,0,math.sin(a)*24)
  local t=Instance.new("Model") t.Name="CanvasTent"..i t.Parent=m
  local tc=CFrame.lookAt(pos,V(origin.X,pos.Y,origin.Z))
  part(t,"Groundsheet",V(8,.15,10),tc*C(0,.18,0),Color3.fromRGB(35,39,33),Enum.Material.Fabric)
  for _,s in ipairs({-1,1}) do
   part(t,"CanvasRoof",V(math.sqrt(32),.16,10.4),tc*C(s*2,2.3,0)*CFrame.Angles(0,0,-s*math.pi/4),colors[i],Enum.Material.Fabric)
   local back=Instance.new("WedgePart") back.Name="BackCanvas" back.Size=V(.12,4,4) back.CFrame=tc*C(s*2,2.2,4.9)*CFrame.Angles(0,s*math.pi/2,0) back.Color=colors[i] back.Material=Enum.Material.Fabric back.Anchored=true back.Parent=t
   cylinder(t,"TentPole",(tc*C(s*4,.25,-5)).Position,(tc*C(0,4.35,-5)).Position,.075,Color3.fromRGB(91,84,70),Enum.Material.Metal)
   cylinder(t,"GuyRope",(tc*C(0,4.35,s*5)).Position,(tc*C(0,.15,s*7)).Position,.026,Color3.fromRGB(187,170,129),Enum.Material.Fabric)
   part(t,"GroundPeg",V(.10,.5,.12),tc*C(0,.12,s*7)*CFrame.Angles(.3,0,0),Color3.fromRGB(90,88,80),Enum.Material.Metal)
  end
  part(t,"SleepingBag",V(2,.30,5.5),tc*C(1.8,.45,.7),Color3.fromRGB(66,73,60),Enum.Material.Fabric)
  part(t,"Pillow",V(1.8,.45,.9),tc*C(1.8,.62,2.8),Color3.fromRGB(153,144,118),Enum.Material.Fabric,Enum.PartType.Ball)
 end
 -- The gun always resets to this saved transform on the supply stump.
 local stump=V(0,0,-16)
 P("SignalStump",V(2.5,3.2,3.2),C(stump+V(0,1.25,0))*CFrame.Angles(0,0,math.pi/2),brown,Enum.Material.Wood,Enum.PartType.Cylinder)
 P("StumpCut",V(.06,3,3),C(stump+V(0,2.52,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(152,110,65),Enum.Material.Wood,Enum.PartType.Cylinder)
 local gunMarker=P("FlareSpawn",V(.3,.3,.3),C(stump+V(0,3.0,0))*CFrame.Angles(0,math.rad(-30),math.pi/2),brown) gunMarker.Transparency=1 gunMarker.CanCollide=false
 local prompt=Instance.new("ProximityPrompt") prompt.Name="FlarePickup" prompt.ActionText="Pick up flare gun" prompt.ObjectText="Emergency meeting" prompt.HoldDuration=.35 prompt.MaxActivationDistance=9 prompt.RequiresLineOfSight=false prompt.Parent=gunMarker
 local sign=P("MeetingSign",V(4,1.9,.2),C(0,3.7,-18.5),Color3.fromRGB(53,42,29))
 P("SignPost",V(.3,4,.3),C(0,1.9,-18.5),brown)
 local gui=Instance.new("SurfaceGui") gui.Face=Enum.NormalId.Front gui.CanvasSize=Vector2.new(640,260) gui.Parent=sign
 local text=Instance.new("TextLabel") text.Size=UDim2.fromScale(1,1) text.BackgroundTransparency=1 text.Text="EMERGENCY FLARE\nGATHER AT THE FIRE" text.Font=Enum.Font.GothamBold text.TextColor3=Color3.fromRGB(228,208,159) text.TextSize=37 text.Parent=gui
 for _,x in ipairs({-5,5}) do
  P("LanternPost",V(.25,4.3,.25),C(x,2.15,-18),brown)
  P("LanternFrame",V(.8,.15,.8),C(x,4.4,-18),Color3.fromRGB(35,38,34),Enum.Material.Metal)
  local glow=P("LanternGlass",V(.55,.75,.55),C(x,3.98,-18),Color3.fromRGB(255,194,97),Enum.Material.Neon) glow.CanCollide=false
  local l=Instance.new("PointLight") l.Color=Color3.fromRGB(255,184,102) l.Range=16 l.Brightness=.6 l.Parent=glow
  P("LanternBase",V(.8,.15,.8),C(x,3.55,-18),Color3.fromRGB(35,38,34),Enum.Material.Metal)
 end
 return m
end
return B
