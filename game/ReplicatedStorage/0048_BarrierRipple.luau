-- Client visual only. A contact produces expanding, uneven water-tension wavefronts.
local Ripple={}
function Ripple.Create(parent,position,normal)
 local folder=Instance.new('Folder') folder.Name='BarrierWaterRipple' folder.Parent=parent
 local anchor=Instance.new('Part') anchor.Name='RippleOrigin' anchor.Size=Vector3.one*.1
 anchor.Anchored=true anchor.Transparency=1 anchor.CanCollide=false anchor.CanTouch=false anchor.CanQuery=false
 anchor.CFrame=CFrame.lookAt(position,position+normal) anchor.Parent=folder
 local rings={}
 for n=1,3 do
  local ring={points={},beams={},delay=(n-1)*.16}
  for i=1,49 do local a=Instance.new('Attachment') a.Parent=anchor ring.points[i]=a end
  for i=1,48 do
   local b=Instance.new('Beam') b.Attachment0=ring.points[i] b.Attachment1=ring.points[i+1]
   b.FaceCamera=true b.Color=ColorSequence.new(Color3.fromRGB(242,249,255))
   b.LightEmission=1 b.LightInfluence=0 b.Segments=1 b.Width0=.065 b.Width1=.065
   b.Transparency=NumberSequence.new(1) b.Parent=anchor ring.beams[i]=b
  end
  rings[n]=ring
 end
 local self={Folder=folder}
 function self:Step(age)
  for n,ring in rings do
   local t=math.clamp((age-ring.delay)/1.45,0,1)
   local radius=.18+13*(1-(1-t)^1.45)
   local opacity=math.sin(math.min(t*8,math.pi/2))*(1-t)^1.3
   for i,a in ring.points do
    local angle=(i-1)/48*math.pi*2
    local wave=math.sin(angle*5-age*8+n)*.10+math.sin(angle*11+age*5)*.05
    local r=radius*(1+wave*(.3+t*.55))
    a.Position=Vector3.new(math.cos(angle)*r,math.sin(angle)*r*.85,math.sin(angle*7-age*6)*.055)
   end
   for i,b in ring.beams do
    local glint=.6+.4*(.5+.5*math.sin(i*.73-age*10+n))
    b.Transparency=NumberSequence.new(1-opacity*glint)
    b.Width0=.04+.075*(1-t) b.Width1=b.Width0
   end
  end
  folder:SetAttribute('Age',age)
 end
 function self:Destroy() folder:Destroy() end
 return self
end
return Ripple
