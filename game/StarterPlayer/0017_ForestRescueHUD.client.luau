-- Rescue progress panel + the mini-game window for each rescue task (see the TaskWindow module).
-- Two task lists run side by side: CAMP POWER and ESCAPE VAN (task model attribute "List"). When both are
-- finished the van starts and the escape begins (EscapeVanService).
local p=game.Players.LocalPlayer
local config=workspace:WaitForChild("MaskSystem")
local tasks=workspace:WaitForChild("ForestRescueTasks")
local remote=game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RescueInteraction")
local TaskWindow=require(script:WaitForChild("TaskWindow"))
local gui=Instance.new("ScreenGui") gui.Name="ForestRescueHUD" gui.ResetOnSpawn=false gui.DisplayOrder=45 gui.Parent=p:WaitForChild("PlayerGui")
local white=Color3.fromRGB(224,221,209)
local muted=Color3.fromRGB(177,173,165)
local EMPTY=Color3.fromRGB(45,40,30)
local LISTS={
 {key="Power",label="CAMP POWER",done=Color3.fromRGB(169,163,139)},
 {key="Van",label="CAMP BUS",done=Color3.fromRGB(205,128,58)}, -- list key stays "Van"
}
local function frame(parent,n,size,pos)
 local f=Instance.new("Frame",parent) f.Name=n f.Size=size f.Position=pos f.BackgroundColor3=Color3.fromRGB(15,17,17) f.BackgroundTransparency=.1 f.BorderSizePixel=0 return f
end
local function text(parent,n,str,size,pos,fontSize)
 local t=Instance.new("TextLabel",parent) t.Name=n t.Text=str t.Size=size t.Position=pos t.Font=Enum.Font.Oswald t.TextSize=fontSize t.BackgroundTransparency=1 t.TextColor3=white t.TextXAlignment=Enum.TextXAlignment.Left t.TextWrapped=true return t
end
-- the panel lays itself out for whatever width it's given (CampHUDLayout docks it at 310 wide)
local bar=frame(gui,"TeamProgress",UDim2.fromOffset(430,122),UDim2.new(.5,0,0,64)) bar.AnchorPoint=Vector2.new(.5,0)
local bs=Instance.new("UIScale",bar)
local title=text(bar,"Title","ESCAPE PLAN",UDim2.new(1,-24,0,23),UDim2.fromOffset(12,4),15)
local rows={}
for i,l in LISTS do
 local row=Instance.new("Frame",bar) row.Name=l.key.."Row" row.BackgroundTransparency=1 row.Size=UDim2.new(1,-24,0,14) row.Position=UDim2.fromOffset(12,30+(i-1)*19)
 local name=text(row,"Label",l.label,UDim2.fromOffset(84,14),UDim2.fromOffset(0,0),12) name.TextColor3=muted
 local count=text(row,"Count","0/0",UDim2.new(0,40,0,14),UDim2.new(1,-40,0,0),12) count.TextXAlignment=Enum.TextXAlignment.Right
 local track=Instance.new("Frame",row) track.Name="Segments" track.BackgroundTransparency=1 track.Position=UDim2.fromOffset(88,5) track.Size=UDim2.new(1,-134,0,5)
 rows[l.key]={row=row,count=count,track=track,segments={},spec=l}
end
local status=text(bar,"Status","",UDim2.new(1,-24,0,18),UDim2.fromOffset(12,70),12)
local objective=text(bar,"Next","",UDim2.new(1,-24,0,28),UDim2.fromOffset(12,90),11)
local notice=text(gui,"Notice","",UDim2.fromOffset(440,32),UDim2.new(.5,0,.78,0),19) notice.AnchorPoint=Vector2.new(.5,0) notice.TextXAlignment=Enum.TextXAlignment.Center
local noticeToken=0
local function notify(msg)
 noticeToken+=1 local token=noticeToken notice.Text=msg task.delay(3,function() if token==noticeToken then notice.Text="" end end)
end
local active=nil
local function act(action,payload) if active then remote:FireServer("act",active.token,action,payload) end end
local function cancel() if active then active=nil remote:FireServer("cancel") end end
remote.OnClientEvent:Connect(function(action,data)
 if action=="close" then
  active=nil TaskWindow.close()
  if data and data~="TASK COMPLETE" then notify(data) elseif data=="TASK COMPLETE" then notify("TASK COMPLETE") end
 elseif action=="open" then
  active=data TaskWindow.open(data,act,cancel)
 elseif action=="result" then
  TaskWindow.result(data)
 end
end)
-- one segment per task in the list, in task order; finished ones fill in
local function drawList(r,list,on)
 local n=#list
 if #r.segments~=n then
  for _,s in r.segments do s:Destroy() end r.segments={}
  for i=1,n do
   local s=Instance.new("Frame",r.track) s.Name="Segment"..i s.BorderSizePixel=0
   s.Size=UDim2.new(1/n,-2,1,0) s.Position=UDim2.new((i-1)/n,0,0,0)
   r.segments[i]=s
  end
 end
 local done=0
 for i,m in list do
  local finished=m:GetAttribute("Done")==true
  if finished then done+=1 end
  local s=r.segments[i]
  s.BackgroundColor3=finished and r.spec.done or EMPTY
  s.BackgroundTransparency=on and 0 or .35
 end
 r.count.Text=done.."/"..n
 r.count.TextColor3=done==n and n>0 and r.spec.done or white
end
local function refresh()
 bar.Visible=p:GetAttribute("InRound")==true
 local lists={Power={},Van={}}
 for _,m in tasks:GetChildren() do local l=lists[m:GetAttribute("List") or "Power"] if l then table.insert(l,m) end end
 for _,l in lists do table.sort(l,function(a,b) return (a:GetAttribute("TaskId") or 0)<(b:GetAttribute("TaskId") or 0) end) end
 local on=config:GetAttribute("RescueOnline")
 for key,r in rows do drawList(r,lists[key],on) end
 local count=config:GetAttribute("RescueCompleted") or 0
 local total=config:GetAttribute("RescueTotal") or #tasks:GetChildren()
 local van=config:GetAttribute("VanState")
 if van=="Running" then
  title.Text="THE CAMP BUS IS HERE"
  status.Text="GET ON THE BUS BEFORE IT LEAVES"
 elseif van=="Gone" then
  title.Text="THE CAMP BUS HAS LEFT"
  status.Text=""
 else
  title.Text="ESCAPE PLAN  /  "..count.." OF "..total
  status.Text=config:GetAttribute("RescueStatus") or ""
 end
 local nextTask
 for _,m in tasks:GetChildren() do if m:GetAttribute("Available") and (not nextTask or m:GetAttribute("TaskId")<nextTask:GetAttribute("TaskId")) then nextTask=m end end
 local sites={RADIOTOWER="RADIO TOWER"}
 if van=="Running" or van=="Gone" then objective.Text=""
 else objective.Text=nextTask and ("NEXT: "..string.upper(nextTask:GetAttribute("Title")).."  /  "..(sites[nextTask:GetAttribute("Site")] or nextTask:GetAttribute("Site"))) or (on and "TEAMMATES ARE WORKING ON IT" or "UNFINISHED TASKS RETURN AT SUNRISE") end
 if (not on or not bar.Visible) and active then active=nil TaskWindow.close() remote:FireServer("cancel") end
 local cam=workspace.CurrentCamera if cam then local scale=math.clamp(math.min(cam.ViewportSize.X/520,cam.ViewportSize.Y/600),.55,1) if not gui:GetAttribute("ManagedLayout") then bs.Scale=scale end end
end
task.spawn(function() while gui.Parent do refresh() task.wait(.2) end end)
