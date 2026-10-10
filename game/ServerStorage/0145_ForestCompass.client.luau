local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local p=Players.LocalPlayer
local data=game.ReplicatedStorage:WaitForChild("RescueMapData")
local sites=data:WaitForChild("Sites")
local tasks=data:WaitForChild("Tasks")
local cfg=workspace:WaitForChild("MaskSystem")
local gui=Instance.new("ScreenGui") gui.Name="ForestCompass" gui.ResetOnSpawn=false gui.DisplayOrder=60 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.Parent=p:WaitForChild("PlayerGui")
local ink=Color3.fromRGB(13,13,15)
local paper=Color3.fromRGB(232,229,218)
local green=Color3.fromRGB(24,24,26)
local gold=Color3.fromRGB(173, 50, 50)
local red=Color3.fromRGB(157,32,39)
local function frame(parent,name,size,pos,color)
 local f=Instance.new("Frame") f.Name=name f.Size=size f.Position=pos f.BackgroundColor3=color or ink f.BorderSizePixel=0 f.Parent=parent return f
end
local function text(parent,name,str,size,pos,fs,color)
 local t=Instance.new("TextLabel") t.Name=name t.Text=str t.Size=size t.Position=pos t.BackgroundTransparency=1 t.Font=Enum.Font.Oswald t.TextSize=fs t.TextColor3=color or paper t.Parent=parent return t
end
local function edge(o,c,width) local e=Instance.new("UIStroke",o) e.Color=c e.Thickness=width or 1 return e end
local function circle(o) local c=Instance.new("UICorner",o) c.CornerRadius=UDim.new(1,0) end
local function button(parent,name,str,size,pos,fn)
 local b=Instance.new("TextButton") b.Name=name b.Text=str b.Size=size b.Position=pos b.BackgroundColor3=ink b.TextColor3=paper b.Font=Enum.Font.Oswald b.TextSize=14 b.BorderSizePixel=0 b.Parent=parent b.Activated:Connect(fn) return b
end
local function canUseMap()
 local c=p.Character local root=c and c:FindFirstChild("HumanoidRootPart") local h=c and c:FindFirstChildOfClass("Humanoid")
 return cfg:GetAttribute("MatchActive")==true and p:GetAttribute("InRound")==true and root~=nil and h~=nil and h.Health>0
 and math.abs(root.Position.X)<=280 and math.abs(root.Position.Z)<=280 and root.Position.Y<120
end
local opened=false local selected=nil local renderList

local compass=button(gui,"CompassButton","",UDim2.fromOffset( 80, 80),UDim2.fromOffset(18,18),function() if canUseMap() then opened=not opened end end)
compass.Visible=false
compass.BackgroundColor3=Color3.fromRGB(17,17,19) edge(compass,red,1)
frame(compass,"BloodEdge",UDim2.new(0,3,1,0),UDim2.fromScale(0,0),red)
local dial=frame(compass,"RadarFace",UDim2.fromOffset( 60, 60),UDim2.fromOffset(10,10),green)
for i=1,3 do
 local line=frame(dial,"Grid",UDim2.fromOffset( 40,1),UDim2.fromOffset(10,14+i*8),Color3.fromRGB(65,61,60)) line.BackgroundTransparency=.3
end
text(compass,"North","N",UDim2.fromOffset(16,16),UDim2.fromOffset(32,1),12,gold)
text(compass,"South","S",UDim2.fromOffset(16,16),UDim2.fromOffset(32,63),12)
text(compass,"West","W",UDim2.fromOffset(16,16),UDim2.fromOffset(0,32),11)
text(compass,"East","E",UDim2.fromOffset(16,16),UDim2.fromOffset(64,32),11)
local needle=text(compass,"HeadingArrow","▲",UDim2.fromOffset(24,30),UDim2.fromOffset(28,25),26,red)
local caption=text(gui,"CompassCaption","MAP · M",UDim2.fromOffset( 80,16),UDim2.fromOffset(18,100),11) caption.Visible=false
local shade=frame(gui,"MapShade",UDim2.fromScale(1,1),UDim2.fromScale(0,0),Color3.new()) shade.BackgroundTransparency=.35 shade.Visible=false
local panel=frame(shade,"MapPanel",UDim2.fromOffset(760,510),UDim2.fromScale(.5,.5),ink) panel.AnchorPoint=Vector2.new(.5,.5) edge(panel,Color3.fromRGB( 60,55,55))
frame(panel,"BloodEdge",UDim2.new(0,3,1,0),UDim2.fromScale(0,0),red)
local heading=text(panel,"Title","FOREST / FIELD MAP",UDim2.new(1,-70,0,30),UDim2.fromOffset(18,10),23) heading.TextXAlignment=Enum.TextXAlignment.Left
local status=text(panel,"Status","",UDim2.new(1,-36,0,23),UDim2.fromOffset(18, 40),12) status.TextXAlignment=Enum.TextXAlignment.Left
button(panel,"Close","X",UDim2.fromOffset(36,36),UDim2.new(1,-46,0,8),function() opened=false end).Modal=true
local plot=frame(panel,"ForestMap",UDim2.fromOffset(400,400),UDim2.fromOffset(25, 80),Color3.fromRGB( 20, 20,22))
edge(plot,Color3.fromRGB( 80, 50, 50))
-- North is world -Z; east is +X. All markers use real world coordinates.
local function mapPoint(pos) return Vector2.new((pos.X+280)/560,(pos.Z+280)/560) end
for i=1,7 do
 local a=frame(plot,"Grid",UDim2.new(1,0,0,1),UDim2.fromScale(0,i/8),Color3.fromRGB( 60,56,56)) a.BackgroundTransparency=.5
 local b=frame(plot,"Grid",UDim2.new(0,1,1,0),UDim2.fromScale(i/8,0),Color3.fromRGB( 60,56,56)) b.BackgroundTransparency=.5
end
text(plot,"North","N",UDim2.fromOffset(24,22),UDim2.new(.5,-12,0,-24),16,gold)
text(plot,"South","S",UDim2.fromOffset(24,22),UDim2.new(.5,-12,1,0),16)
text(plot,"West","W",UDim2.fromOffset(20,22),UDim2.new(0,-22,.5,-11),14)
text(plot,"East","E",UDim2.fromOffset(20,22),UDim2.new(1,2,.5,-11),14)
local pond=data:GetAttribute("PondPosition")
if pond then
 local size=data:GetAttribute("PondSize") local uv=mapPoint(pond)
 local lake=frame(plot,"Pond",UDim2.fromScale(math.clamp(size.X/560,.04,.22),math.clamp(size.Z/560,.04,.22)),UDim2.fromScale(uv.X,uv.Y),Color3.fromRGB( 40,45, 50)) lake.AnchorPoint=Vector2.new(.5,.5) circle(lake)
end
local trees=data:FindFirstChild("Trees")
if trees then
 local list=trees:GetChildren() local stride=math.max(1,math.ceil(#list/120))
 for i=1,#list,stride do local tree=list[i] local pos=tree:GetAttribute("Position")
 if pos then local uv=mapPoint(pos) if uv.X>0 and uv.X<1 and uv.Y>0 and uv.Y<1 then
 text(plot,"Tree","♠",UDim2.fromOffset(9,12),UDim2.fromScale(uv.X,uv.Y),10,Color3.fromRGB( 70,68,64))
 end end end
end
local details=frame(panel,"TaskDetails",UDim2.fromOffset(270,400),UDim2.fromOffset(470, 80),ink)
local detailTitle=text(details,"Location","ALL TASK LOCATIONS",UDim2.new(1,0,0,26),UDim2.fromOffset(0,0),16) detailTitle.TextXAlignment=Enum.TextXAlignment.Left
local all=button(details,"AllLocations","SHOW ALL",UDim2.fromOffset(88,26),UDim2.new(1,-88,0, 30),function() selected=nil if renderList then renderList() end end)
local distance=text(details,"Distance","Tap a map marker to inspect",UDim2.new(1,-90,0,28),UDim2.fromOffset(0, 30),11) distance.TextXAlignment=Enum.TextXAlignment.Left
local scroll=Instance.new("ScrollingFrame",details) scroll.Name="TaskList" scroll.Size=UDim2.new(1,0,1,- 90) scroll.Position=UDim2.fromOffset(0,64) scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.ScrollBarThickness=4 scroll.ScrollBarImageColor3=gold scroll.CanvasSize=UDim2.fromOffset(0,0)
local legend=text(details,"Legend","● READY   ◇ LOCKED   ✓ DONE",UDim2.new(1,0,0,22),UDim2.new(0,0,1,-22),11) legend.TextXAlignment=Enum.TextXAlignment.Left
local names={CAMP="CAMP",SHED="MAINTENANCE",RANGER="RANGER STATION",PUMP="PUMP HOUSE",INTAKE="INTAKE",TOWER="WATER / BEACON",TRUCK="TRUCK",LOOKOUT="LOOKOUT"}
local markers={} local minis={}
local ordered=sites:GetChildren() table.sort(ordered,function(a,b)return a.Name<b.Name end)
for i,site in ordered do
 local uv=mapPoint(site:GetAttribute("Position"))
 local b=button(plot,"Marker_"..site.Name,tostring(i),UDim2.fromOffset( 30, 30),UDim2.fromScale(uv.X,uv.Y),function() selected=site.Name if renderList then renderList() end end)
 b.AnchorPoint=Vector2.new(.5,.5) b.BackgroundColor3=Color3.fromRGB(48, 20,24) edge(b,gold) b.ZIndex=3
 local label=text(b,"SiteName",names[site.Name] or site.Name,UDim2.fromOffset(100,16),UDim2.fromOffset(-35,30),10) label.ZIndex=3
 markers[site.Name]=b
 local dot=frame(dial,"TaskDot",UDim2.fromOffset(3,3),UDim2.fromScale(.15+uv.X*.7,.15+uv.Y*.7),gold) circle(dot) minis[site.Name]=dot
end
local playerDot=text(plot,"You","▲",UDim2.fromOffset(24,24),UDim2.fromScale(.5,.5),22,Color3.fromRGB(235,225,200)) playerDot.AnchorPoint=Vector2.new(.5,.5) playerDot.ZIndex=5
local outside=text(panel,"OutsideForest","",UDim2.new(1,-36,0,18),UDim2.new(0,18,1,-22),11) outside.TextXAlignment=Enum.TextXAlignment.Left
renderList=function()
 scroll:ClearAllChildren()
 local y=0
 detailTitle.Text=selected and (names[selected] or selected) or "ALL TASK LOCATIONS"
 all.Visible=selected~=nil
 local sorted=tasks:GetChildren() table.sort(sorted,function(a,b)return a:GetAttribute("TaskId")<b:GetAttribute("TaskId") end)
 for _,m in sorted do if not selected or m:GetAttribute("Site")==selected then
 local done=m:GetAttribute("Done") local ready=m:GetAttribute("Available")
 local prefix=done and "✓ " or ready and "● " or "◇ "
 local b=button(scroll,m.Name,"",UDim2.new(1,-6,0,128),UDim2.fromOffset(0,y),function() selected=m:GetAttribute("Site") renderList() end)
 b.BackgroundColor3=Color3.fromRGB(23,23,26) b.BackgroundTransparency=.1
 local accent=frame(b,"StateEdge",UDim2.new(0,2,1,-10),UDim2.fromOffset(0,5),done and paper or ready and red or Color3.fromRGB(68,64,64))
 local title=text(b,"TaskTitle",prefix..m:GetAttribute("TaskId")..". "..string.upper(m:GetAttribute("Title")),UDim2.new(1,-18,0,36),UDim2.fromOffset(10,5),14,done and Color3.fromRGB(162,160,151) or paper)
 title.TextXAlignment=Enum.TextXAlignment.Left title.TextWrapped=true
 local guide=text(b,"Guide",m:GetAttribute("Guide") or m:GetAttribute("Instruction") or "",UDim2.new(1,-20,0,78),UDim2.fromOffset(10,43),12,Color3.fromRGB(177,173,165))
 guide.Font=Enum.Font.Gotham guide.TextXAlignment=Enum.TextXAlignment.Left guide.TextYAlignment=Enum.TextYAlignment.Top guide.TextWrapped=true
 y+=134
 end end
 scroll.CanvasSize=UDim2.fromOffset(0,y) scroll.CanvasPosition=Vector2.zero
end
renderList()
local function layout()
 local cam=workspace.CurrentCamera if not cam then return end
 local v=cam.ViewportSize local w=math.min(760,v.X-24) local h=math.min(540,v.Y- 70)
 panel.Size=UDim2.fromOffset(w,h)
 local portrait=w<600
 local mapSize=portrait and math.min(w- 70,(h-150)*.55) or math.min(h-115,w*.55)
 plot.Size=UDim2.fromOffset(mapSize,mapSize)
 if portrait then
 plot.Position=UDim2.fromOffset((w-mapSize)/2,85)
 details.Position=UDim2.fromOffset(18,85+mapSize+30) details.Size=UDim2.fromOffset(w-36,math.max(140,h-mapSize-140))
 else
 plot.Position=UDim2.fromOffset( 30,85)
 details.Position=UDim2.fromOffset(mapSize+ 60,80) details.Size=UDim2.fromOffset(w-mapSize-78,h-110)
 end
 for _,b in markers do b.SiteName.Visible=mapSize>=300 end
 local dread=p.PlayerGui:FindFirstChild("DreadHUD")
 if dread and dread:FindFirstChild("Identity") then dread.Identity.Visible=v.X>=650
 dread.Identity.Position=UDim2.fromOffset(canUseMap() and 116 or 20,18) end
end
UIS.InputBegan:Connect(function(input,processed)
 if processed then return end
 if input.KeyCode==Enum.KeyCode.M and canUseMap() then opened=not opened
 elseif input.KeyCode==Enum.KeyCode.Escape and opened then opened=false end
end)
local lastSignature=""
task.spawn(function() while gui.Parent do
 local allowed=canUseMap()
 if not allowed then opened=false end
 compass.Visible=allowed caption.Visible=allowed shade.Visible=opened and allowed
 layout()
 local sig=tostring(cfg:GetAttribute("RescueOnline"))..":"..tostring(cfg:GetAttribute("RescueCompleted"))
 for _,m in tasks:GetChildren() do sig..=tostring(m:GetAttribute("Available")) end
 if sig~=lastSignature then lastSignature=sig renderList() end
 local inMatch=cfg:GetAttribute("MatchActive")
 status.Text=(inMatch and (cfg:GetAttribute("RescueStatus") or "") or "FOREST GUIDE — TASKS ACTIVATE DURING A ROUND").."  /  "..(cfg:GetAttribute("RescueCompleted") or 0).."/15"
 for name,b in markers do
 local total,done,ready=0,0,false
 for _,m in tasks:GetChildren() do if m:GetAttribute("Site")==name then total+=1 if m:GetAttribute("Done") then done+=1 end if m:GetAttribute("Available") then ready=true end end end
 b.BackgroundColor3=done==total and Color3.fromRGB(66,65, 60) or ready and Color3.fromRGB(100, 30,36) or Color3.fromRGB( 30, 30,32)
 b.UIStroke.Color=selected==name and paper or gold
 minis[name].BackgroundColor3=done==total and Color3.fromRGB(190,185,174) or gold
 end
 task.wait(.2)
end end)
Run.RenderStepped:Connect(function()
 local cam=workspace.CurrentCamera local c=p.Character local root=c and c:FindFirstChild("HumanoidRootPart")
 if cam then local d=cam.CFrame.LookVector needle.Rotation=math.deg(math.atan2(d.X,-d.Z)) end
 if root then
 local uv=mapPoint(root.Position) local inside=uv.X>=0 and uv.X<=1 and uv.Y>=0 and uv.Y<=1 and root.Position.Y<120
 playerDot.Visible=inside
 if inside then playerDot.Position=UDim2.fromScale(uv.X,uv.Y) local d=root.CFrame.LookVector playerDot.Rotation=math.deg(math.atan2(d.X,-d.Z)) end
 outside.Text=inside and "▲ YOU  /  NORTH IS UP • SELECT A LOCATION FOR TASKS" or "YOU ARE OUTSIDE THE FOREST — TASK LOCATIONS REMAIN VISIBLE"
 if selected and sites:FindFirstChild(selected) then
 local dest=sites[selected]:GetAttribute("Position")
 distance.Text=math.floor(Vector2.new(dest.X-root.Position.X,dest.Z-root.Position.Z).Magnitude).." STUDS AWAY"
 else distance.Text="Tap a numbered marker" end
 end
end)
