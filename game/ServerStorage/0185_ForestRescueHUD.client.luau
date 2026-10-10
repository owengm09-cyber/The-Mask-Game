-- Rescue progress bar + the mini-game window for each rescue task (see the TaskWindow module).
local p=game.Players.LocalPlayer
local config=workspace:WaitForChild("MaskSystem")
local tasks=workspace:WaitForChild("ForestRescueTasks")
local remote=game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RescueInteraction")
local TaskWindow=require(script:WaitForChild("TaskWindow"))
local gui=Instance.new("ScreenGui") gui.Name="ForestRescueHUD" gui.ResetOnSpawn=false gui.DisplayOrder=45 gui.Parent=p:WaitForChild("PlayerGui")
local white=Color3.fromRGB(224,221,209)
local function frame(parent,n,size,pos)
 local f=Instance.new("Frame",parent) f.Name=n f.Size=size f.Position=pos f.BackgroundColor3=Color3.fromRGB(15,17,17) f.BackgroundTransparency=.1 f.BorderSizePixel=0 return f
end
local function text(parent,n,str,size,pos,fontSize)
 local t=Instance.new("TextLabel",parent) t.Name=n t.Text=str t.Size=size t.Position=pos t.Font=Enum.Font.Oswald t.TextSize=fontSize t.BackgroundTransparency=1 t.TextColor3=white t.TextXAlignment=Enum.TextXAlignment.Left t.TextWrapped=true return t
end
local bar=frame(gui,"TeamProgress",UDim2.fromOffset(430,82),UDim2.new(.5,0,0,64)) bar.AnchorPoint=Vector2.new(.5,0)
local bs=Instance.new("UIScale",bar)
local title=text(bar,"Title","RESCUE PROGRESS",UDim2.new(1,-24,0,23),UDim2.fromOffset(12,4),16)
local status=text(bar,"Status","",UDim2.new(1,-24,0,18),UDim2.fromOffset(12, 50),12)
local segments={}
local totalTasks=math.max(1,#tasks:GetChildren())
local segW=math.floor((406-(totalTasks-1)*3)/totalTasks)
for i=1,totalTasks do local f=frame(bar,"Segment"..i,UDim2.fromOffset(segW,5),UDim2.fromOffset(12+(i-1)*(segW+3),36)) segments[i]=f end
local objective=text(bar,"Next","",UDim2.new(1,-24,0,15),UDim2.fromOffset(12,66),11)
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
local function refresh()
 bar.Visible=p:GetAttribute("InRound")==true
 local count=config:GetAttribute("RescueCompleted") or 0
 title.Text="RESCUE PROGRESS  /  "..count.." OF "..(config:GetAttribute("RescueTotal") or totalTasks)
 status.Text=config:GetAttribute("RescueStatus") or ""
 local on=config:GetAttribute("RescueOnline")
 for i,f in segments do f.BackgroundColor3=i<=count and Color3.fromRGB(169,163,139) or Color3.fromRGB(45, 40, 30) f.BackgroundTransparency=on and 0 or .35 end
 local nextTask
 for _,m in tasks:GetChildren() do if m:GetAttribute("Available") and (not nextTask or m:GetAttribute("TaskId")<nextTask:GetAttribute("TaskId")) then nextTask=m end end
 objective.Text=nextTask and ("NEXT: "..string.upper(nextTask:GetAttribute("Title")).."  /  "..nextTask:GetAttribute("Site")) or (on and "TEAMMATES ARE RESTORING THE SYSTEM" or "UNFINISHED TASKS RETURN AT SUNRISE")
 if (not on or not bar.Visible) and active then active=nil TaskWindow.close() remote:FireServer("cancel") end
 local cam=workspace.CurrentCamera if cam then local scale=math.clamp(math.min(cam.ViewportSize.X/520,cam.ViewportSize.Y/600),.55,1) if not gui:GetAttribute("ManagedLayout") then bs.Scale=scale end end
end
task.spawn(function() while gui.Parent do refresh() task.wait(.2) end end)
