-- A local viewport: the forest camera and other players are never affected.
local Tunnel={}
local PURPLE=Color3.fromRGB(89,43,139)
local RED=Color3.fromRGB(175,17,35)
local function center(z) return Vector3.new(math.sin(z*.025)*10,math.cos(z*.031)*5,z) end
function Tunnel.Create(parent,region)
 local gui=Instance.new("ScreenGui") gui.Name="VentTunnel" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=500 gui.Parent=parent
 local view=Instance.new("ViewportFrame") view.Name="Wormhole" view.Size=UDim2.fromScale(1,1) view.BorderSizePixel=0 view.BackgroundColor3=Color3.fromRGB(3,1,7) view.Ambient=Color3.fromRGB(220,200,245) view.LightColor=Color3.fromRGB(100,60,140) view.Parent=gui
 local world=Instance.new("WorldModel",view)
 local camera=Instance.new("Camera",view) camera.FieldOfView=84 view.CurrentCamera=camera
 local tinted={} local stars={} local rng=Random.new(197)
 local function part(size,cf,shade,bright)
  local p=Instance.new("Part") p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false p.Size=size p.CFrame=cf p.Material=bright and Enum.Material.Neon or Enum.Material.SmoothPlastic p.Color=PURPLE:Lerp(Color3.new(),shade) p.Parent=world
  table.insert(tinted,{p=p,shade=shade,bright=bright}) return p
 end
 -- Closely packed curved walls, with irregular longitudinal luminous veins.
 for j=0,29 do
  local z=j*10
  for i=0,31 do
   local angle=i/32*math.pi*2
   local twist=math.sin(z*.038)*.22
   local radial=Vector3.new(math.cos(angle+twist),math.sin(angle+twist),0)
   local radius=8.5+math.sin(angle*3+z*.045)*.12
   local a=center(z)+radial*radius local b=center(z+10)+radial*radius
   local cf=CFrame.lookAt((a+b)/2,b,radial)
   local shade=.48+math.sin(angle*2+z*.025)*.12
   part(Vector3.new(1.94,.25,(b-a).Magnitude+2.6),cf,shade,false)
   if (i+j)%3==0 then
    local vein=part(Vector3.new(rng:NextNumber(.04,.17),.035,(b-a).Magnitude+1),cf*CFrame.new(rng:NextNumber(-.9,.9),-.16,0),rng:NextNumber(.0,.25),true)
    vein.Transparency=rng:NextNumber(.12,.5)
   end
  end
 end
 for i=1,100 do
  local p=part(Vector3.new(.025,.025,rng:NextNumber(.6,4)),CFrame.new(),0,true)
  table.insert(stars,{p=p,z=rng:NextNumber(4,105),angle=rng:NextNumber(0,math.pi*2),radius=rng:NextNumber(2.8,7.8)})
 end
 local title=Instance.new("TextLabel") title.Name="Destination" title.BackgroundTransparency=1 title.Size=UDim2.new(1,-40,0,28) title.Position=UDim2.new(0,20,1,-70) title.Font=Enum.Font.Oswald title.TextSize=18 title.TextColor3=Color3.fromRGB(222,213,229) title.Text="TUNNELING / "..string.upper(region or "FOREST") title.Parent=gui
 local track=Instance.new("Frame") track.Size=UDim2.new(.28,0,0,2) track.Position=UDim2.new(.36,0,1,-32) track.BorderSizePixel=0 track.BackgroundColor3=Color3.fromRGB(45,24,50) track.Parent=gui
 local fill=Instance.new("Frame") fill.BorderSizePixel=0 fill.Size=UDim2.fromScale(0,1) fill.Parent=track
 local fade=Instance.new("Frame") fade.Name="Fade" fade.Size=UDim2.fromScale(1,1) fade.BackgroundColor3=Color3.new() fade.BorderSizePixel=0 fade.ZIndex=10 fade.Parent=gui
 local lastColor=-1
 local obj={Gui=gui}
 function obj:Step(age)
  age=math.clamp(age,0,2)
  local redMix=math.clamp((age-1)/.8,0,1)
  local color=PURPLE:Lerp(RED,redMix)
  if math.abs(redMix-lastColor)>.025 then
   lastColor=redMix
   for _,a in tinted do a.p.Color=color:Lerp(a.bright and Color3.fromRGB(240,195,229) or Color3.new(),a.bright and .1 or a.shade) end
   view.LightColor=color fill.BackgroundColor3=color:Lerp(Color3.new(1,1,1),.22)
  end
  local z=8+age*88
  camera.CFrame=CFrame.lookAt(center(z),center(z+16))*CFrame.Angles(0,0,math.sin(age*2)*.08)
  camera.FieldOfView=84+math.sin(age/2*math.pi)*13
  for _,a in stars do
   local depth=4+(a.z-age*80)%100
   local radial=Vector3.new(math.cos(a.angle+age*.12),math.sin(a.angle+age*.12),0)*a.radius
   local at=center(z+depth)+radial
   a.p.CFrame=CFrame.lookAt(at,center(z+depth+5)+radial)
  end
  fill.Size=UDim2.fromScale(age/2,1)
  fade.BackgroundTransparency=math.min(math.clamp(age/.12,0,1),math.clamp((2-age)/.12,0,1))
  gui:SetAttribute("RedMix",redMix) gui:SetAttribute("AnimationAge",age)
 end
 function obj:Destroy() gui:Destroy() end
 obj:Step(0)
 return obj
end
return Tunnel
