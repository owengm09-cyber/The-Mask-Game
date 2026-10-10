local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local RS=game:GetService("ReplicatedStorage")
local p=Players.LocalPlayer
local cfg=workspace:WaitForChild("MaskSystem")
local vents=workspace:WaitForChild("Vents")
local data=RS:WaitForChild("VentMapData")
local remote=RS:WaitForChild("Remotes"):WaitForChild("KillerVent")
local Tunnel=require(RS:WaitForChild("VentTunnel"))
local gui=Instance.new("ScreenGui") gui.Name="KillerVents" gui.ResetOnSpawn=false gui.DisplayOrder=85 gui.Parent=p:WaitForChild("PlayerGui")
local red=Color3.fromRGB(193,39,51) local paper=Color3.fromRGB(225,218,221)
local function make(class,parent,props)
 local o=Instance.new(class) for k,v in props do o[k]=v end o.Parent=parent return o
end
local function text(parent,str,size,pos,fontSize)
 return make("TextLabel",parent,{BackgroundTransparency=1,Text=str,Size=size,Position=pos,Font=Enum.Font.Oswald,TextSize=fontSize,TextColor3=paper,TextXAlignment=Enum.TextXAlignment.Left})
end
local panel=make("Frame",gui,{Name="DestinationPicker",Visible=false,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(570,440),BackgroundColor3=Color3.fromRGB(15,11,20),BorderSizePixel=0})
make("UIStroke",panel,{Color=Color3.fromRGB(103,37,58),Thickness=1})
make("Frame",panel,{Size=UDim2.new(0,3,1,0),BackgroundColor3=red,BorderSizePixel=0})
text(panel,"BENEATH THE FOREST",UDim2.new(1,-80,0,34),UDim2.fromOffset(22,12),24)
local subtitle=text(panel,"CHOOSE AN EXIT / 2 SECOND TRANSIT",UDim2.new(1,-44,0,26),UDim2.fromOffset(22,47),13)
subtitle.TextColor3=Color3.fromRGB(156,138,168)
local close=make("TextButton",panel,{Name="Close",Text="×",Font=Enum.Font.Gotham,TextSize=24,TextColor3=paper,BackgroundTransparency=1,Size=UDim2.fromOffset(42,42),Position=UDim2.new(1,-52,0,8),Modal=true})
local list=make("ScrollingFrame",panel,{Name="Exits",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,-44,1,-116),Position=UDim2.fromOffset(22,84),ScrollBarThickness=3,ScrollBarImageColor3=red,CanvasSize=UDim2.new()})
local notice=text(panel,"30 SECOND COOLDOWN AFTER EMERGING",UDim2.new(1,-44,0,22),UDim2.new(0,22,1,-28),12)
local badge=make("TextButton",gui,{Name="TunnelStatus",Visible=false,AnchorPoint=Vector2.new(.5,1),Size=UDim2.fromOffset(250,30),Position=UDim2.new(.5,0,1,-20),BackgroundColor3=Color3.fromRGB(18,12,23),BackgroundTransparency=.15,BorderSizePixel=0,TextColor3=paper,Font=Enum.Font.Oswald,TextSize=13,Text=""})
make("UIStroke",badge,{Color=Color3.fromRGB(108,30,43)})
local source,view,viewStart,viewDuration
local highlights,prompts,markers,minis={},{},{},{}
local statusUntil=0
local function killer()
 return p:GetAttribute("Role")=="Killer" and p:GetAttribute("InRound")==true and cfg:GetAttribute("MatchActive")==true
end
local function remaining() return math.max(0,math.ceil((p:GetAttribute("VentReadyAt") or 0)-workspace:GetServerTimeNow())) end
local function root() return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function nearest()
 local r=root() if not r then return end
 local best,d=nil,12
 for _,v in data:GetChildren() do local pos=v:GetAttribute("Position")
  if pos then local dist=(r.Position-pos).Magnitude if dist<d then best=v d=dist end end
 end
 return best
end
local function message(str)
 badge.Text=str statusUntil=os.clock()+2.5
 notice.Text=str
end
local function open(from)
 if not killer() or p:GetAttribute("Venting") then return end
 if cfg:GetAttribute("MeetingActive") then message("TUNNELS PAUSED / MEETING") return end
 if Lighting:GetAttribute("Phase")~="Night" then message("TUNNELS OPEN AT NIGHT") return end
 if remaining()>0 then message("TUNNEL RECHARGING / "..remaining().."s") return end
 from=from or nearest() if not from then message("APPROACH A RED ENTRANCE TO TUNNEL") return end
 source=from panel.Visible=true list:ClearAllChildren()
 notice.Text="30 SECOND COOLDOWN AFTER EMERGING"
 subtitle.Text="FROM "..string.upper(from:GetAttribute("Region") or from.Name).." / SELECT EXIT"
 local ordered=data:GetChildren() table.sort(ordered,function(a,b)return a:GetAttribute("VentId")<b:GetAttribute("VentId") end)
 local y=0
 for _,v in ordered do if v~=from then
  local id=v:GetAttribute("VentId")
  local b=make("TextButton",list,{Name="Exit_"..id,Text="",AutoButtonColor=true,Size=UDim2.new(1,-8,0,43),Position=UDim2.fromOffset(0,y),BackgroundColor3=Color3.fromRGB(32,21,36),BorderSizePixel=0})
  local n=text(b,string.format("%02d",id),UDim2.fromOffset(36,43),UDim2.fromOffset(12,0),19) n.TextColor3=red
  text(b,string.upper(v:GetAttribute("Region") or v.Name),UDim2.new(1,-116,1,0),UDim2.fromOffset(57,0),14)
  local r=root() local distance=r and math.floor((v:GetAttribute("Position")-r.Position).Magnitude) or 0
  local d=text(b,tostring(distance).." st",UDim2.fromOffset(60,43),UDim2.new(1,-66,0,0),12) d.TextColor3=Color3.fromRGB(142,125,147)
  b.Activated:Connect(function()
   if source and not p:GetAttribute("Venting") then panel.Visible=false remote:FireServer(source:GetAttribute("VentId"),id) end
  end)
  y+=49
 end end
 list.CanvasSize=UDim2.fromOffset(0,y) list.CanvasPosition=Vector2.zero
end
close.Activated:Connect(function() panel.Visible=false end)
badge.Activated:Connect(function() open() end)
UIS.InputBegan:Connect(function(input,processed)
 if not processed and input.KeyCode==Enum.KeyCode.Escape then panel.Visible=false end
end)
local function bindVent(m)
 if not m:IsA("Model") or highlights[m] then return end
 local h=make("Highlight",m,{Name="KillerVentOutline",Adornee=m,Enabled=false,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,FillColor=red,FillTransparency=.82,OutlineColor=red,OutlineTransparency=0}) highlights[m]=h
 task.spawn(function()
  local part=m:WaitForChild("LeafPatch",10) if not part then return end
  local pr=make("ProximityPrompt",part,{Name="KillerTunnelPrompt",ActionText="Choose tunnel exit",ObjectText="THE MASK / TUNNEL",KeyboardKeyCode=Enum.KeyCode.E,GamepadKeyCode=Enum.KeyCode.ButtonX,MaxActivationDistance=10,RequiresLineOfSight=false,HoldDuration=0,Enabled=false})
  prompts[m]=pr
  pr.Triggered:Connect(function(who) if who==p then open(data:FindFirstChild(m.Name)) end end)
 end)
end
for _,m in vents:GetChildren() do bindVent(m) end
vents.ChildAdded:Connect(bindVent)
local function bindMap()
 local map=p.PlayerGui:FindFirstChild("ForestCompass")
 local plot=map and map:FindFirstChild("ForestMap",true)
 local dial=map and map:FindFirstChild("RadarFace",true)
 if not plot then return end
 for _,v in data:GetChildren() do if not markers[v] or not markers[v].Parent then
  local pos=v:GetAttribute("Position") local x,z=(pos.X+280)/560,(pos.Z+280)/560
  local marker=make("TextButton",plot,{Name="VentMarker_"..v:GetAttribute("VentId"),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,z),Size=UDim2.fromOffset(23,23),BackgroundColor3=Color3.fromRGB(45,8,19),Text="V"..v:GetAttribute("VentId"),TextColor3=Color3.fromRGB(255,81,88),TextSize=10,Font=Enum.Font.GothamBold,BorderSizePixel=0,ZIndex=7,Visible=false})
  make("UICorner",marker,{CornerRadius=UDim.new(1,0)}) make("UIStroke",marker,{Color=red,Thickness=1.5})
  marker.Activated:Connect(function() message(string.upper(v:GetAttribute("Region") or v.Name)) end)
  markers[v]=marker
  if dial then minis[v]=make("Frame",dial,{Name="VentDot_"..v:GetAttribute("VentId"),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.15+x*.7,.15+z*.7),Size=UDim2.fromOffset(4,4),BackgroundColor3=red,BorderSizePixel=0,Visible=false,ZIndex=4}) end
 end end
end
local function stopView()
 if view then view:Destroy() view=nil end
end
remote.OnClientEvent:Connect(function(action,payload)
 if action=="Begin" then
  panel.Visible=false stopView()
  viewStart=payload.start viewDuration=payload.duration
  view=Tunnel.Create(p.PlayerGui,payload.region)
 elseif action=="End" then stopView() if not payload.ok then message(payload.reason or "TRAVEL INTERRUPTED") end
 elseif action=="Denied" then message(payload.reason or "CANNOT TUNNEL") end
end)
p.CharacterRemoving:Connect(function() panel.Visible=false stopView() end)
Run.RenderStepped:Connect(function()
 if view then
  local age=workspace:GetServerTimeNow()-viewStart
  if age>=viewDuration or not killer() then stopView() else view:Step(age) end
 end
end)
task.spawn(function() while gui.Parent do
 bindMap()
 local show=killer()
 local canPrompt=show and Lighting:GetAttribute("Phase")=="Night" and not cfg:GetAttribute("MeetingActive") and not p:GetAttribute("Venting")
 for m,h in highlights do if not m.Parent then highlights[m]=nil prompts[m]=nil else h.Enabled=show end end
 for _,pr in prompts do if pr.Parent then pr.Enabled=canPrompt pr.ActionText=remaining()>0 and ("Recharging / "..remaining().."s") or "Choose tunnel exit" end end
 for _,b in markers do b.Visible=show end for _,b in minis do b.Visible=show end
 badge.Visible=show and not p:GetAttribute("Venting")
 if not canPrompt or not nearest() then panel.Visible=false end
 if not show then stopView() end
 if os.clock()>statusUntil then
  badge.Text=cfg:GetAttribute("MeetingActive") and "TUNNELS PAUSED / MEETING" or Lighting:GetAttribute("Phase")~="Night" and "TUNNELS OPEN AT NIGHT" or remaining()>0 and ("TUNNEL RECHARGING / "..remaining().."s") or "TUNNELS READY / APPROACH AN ENTRANCE"
 end
 local cam=workspace.CurrentCamera if cam then panel.Size=UDim2.fromOffset(math.min(570,cam.ViewportSize.X-28),math.min(440,cam.ViewportSize.Y-90)) end
 task.wait(.2)
end end)
