local p=game.Players.LocalPlayer
local config=workspace:WaitForChild("MaskSystem")
local tasks=workspace:WaitForChild("ForestRescueTasks")
local remote=game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RescueInteraction")
local Run=game:GetService("RunService")
local gui=Instance.new("ScreenGui") gui.Name="ForestRescueHUD" gui.ResetOnSpawn=false gui.DisplayOrder=45 gui.Parent=p:WaitForChild("PlayerGui")
local white=Color3.fromRGB(224,221,209) local red=Color3.fromRGB(151,39, 40)
local function frame(parent,n,size,pos)
 local f=Instance.new("Frame",parent) f.Name=n f.Size=size f.Position=pos f.BackgroundColor3=Color3.fromRGB(15,17,17) f.BackgroundTransparency=.1 f.BorderSizePixel=0 return f
end
local function text(parent,n,str,size,pos,fontSize)
 local t=Instance.new("TextLabel",parent) t.Name=n t.Text=str t.Size=size t.Position=pos t.Font=Enum.Font.Oswald t.TextSize=fontSize t.BackgroundTransparency=1 t.TextColor3=white t.TextXAlignment=Enum.TextXAlignment.Left t.TextWrapped=true return t
end
local function button(parent,str,size,pos,fn)
 local b=Instance.new("TextButton",parent) b.Text=str b.Size=size b.Position=pos b.BackgroundColor3=Color3.fromRGB(45, 40,37) b.TextColor3=white b.Font=Enum.Font.Oswald b.TextSize=18 b.BorderSizePixel=0 b.Activated:Connect(fn) return b
end
local bar=frame(gui,"TeamProgress",UDim2.fromOffset(430,82),UDim2.new(.5,0,0,64)) bar.AnchorPoint=Vector2.new(.5,0)
local bs=Instance.new("UIScale",bar)
local title=text(bar,"Title","RESCUE PROGRESS",UDim2.new(1,-24,0,23),UDim2.fromOffset(12,4),16)
local status=text(bar,"Status","",UDim2.new(1,-24,0,18),UDim2.fromOffset(12, 50),12)
local segments={}
for i=1,15 do local f=frame(bar,"Segment"..i,UDim2.fromOffset(24,5),UDim2.fromOffset(12+(i-1)*27,36)) segments[i]=f end
local objective=text(bar,"Next","",UDim2.new(1,-24,0,15),UDim2.fromOffset(12,66),11)
local panel=frame(gui,"TaskPanel",UDim2.fromOffset(460,310),UDim2.fromScale(.5,.55)) panel.AnchorPoint=Vector2.new(.5,.5) panel.Visible=false
local ps=Instance.new("UIScale",panel)
local heading=text(panel,"Heading","",UDim2.new(1,-65,0,40),UDim2.fromOffset(18,10),21)
local instruction=text(panel,"Instruction","",UDim2.new(1,-36,0,48),UDim2.fromOffset(18,55),16)
local stage=text(panel,"Stage","",UDim2.new(1,-36,0,24),UDim2.fromOffset(18,108),15)
local controls=frame(panel,"Controls",UDim2.new(1,-36,0,145),UDim2.fromOffset(18,145)) controls.BackgroundTransparency=1
local active=nil local busy=false local needle=nil local dialValue=1
local notice=text(gui,"Notice","",UDim2.fromOffset(440,32),UDim2.new(.5,0,.78,0),19) notice.AnchorPoint=Vector2.new(.5,0)
local noticeToken=0
local function notify(msg)
 noticeToken+=1 local token=noticeToken notice.Text=msg task.delay(3,function() if token==noticeToken then notice.Text="" end end)
end
button(panel,"X",UDim2.fromOffset(32,32),UDim2.new(1,- 40,0,12),function() panel.Visible=false active=nil remote:FireServer("cancel") end)
local function submit(value)
 if not active or busy then return end busy=true remote:FireServer("submit",active.token,value)
 task.delay(.7,function() busy=false end)
end
remote.OnClientEvent:Connect(function(action,data)
 if action=="close" then panel.Visible=false active=nil needle=nil if data and data~="TASK COMPLETE" then notify(data) end
 elseif action=="feedback" then notify(data)
 elseif action=="open" then
 active=data busy=false panel.Visible=true heading.Text=string.upper(data.title) instruction.Text=data.guide or data.instruction
 stage.Text="STEP "..data.step.." / 3" needle=nil controls:ClearAllChildren()
 if data.kind=="timing" then
 instruction.Text=(data.guide or data.instruction).." Find the marked band three times."
 local track=frame(controls,"Gauge",UDim2.new(1,0,0,22),UDim2.fromOffset(0,12)) track.BackgroundColor3=Color3.fromRGB( 40, 40,38)
 local zone=frame(track,"Target",UDim2.fromScale(.24,1),UDim2.fromScale(data.center-.12,0)) zone.BackgroundColor3=Color3.fromRGB(150,145,115)
 needle=frame(track,"Needle",UDim2.fromOffset(3,30),UDim2.fromOffset(0,-4)) needle.BackgroundColor3=red
 button(controls,({[2]="STOP FUEL GAUGE",[5]="IGNITE GENERATOR",[9]="STABILIZE CHARGE",[15]="TRANSMIT SIGNAL"})[data.id] or "LOCK SIGNAL",UDim2.new(1,0,0,44),UDim2.fromOffset(0,65),function() submit(0) end)
 elseif data.kind=="dial" then
 dialValue=1 instruction.Text=(data.guide or data.instruction).."  TARGET: "..data.target
 local value=text(controls,"DialValue","1",UDim2.fromOffset(80,50),UDim2.fromOffset(170,0),32) value.TextXAlignment=Enum.TextXAlignment.Center
 button(controls,"−",UDim2.fromOffset( 60,45),UDim2.fromOffset( 90,0),function() dialValue=math.max(1,dialValue-1) value.Text=tostring(dialValue) end)
 button(controls,"+",UDim2.fromOffset( 60,45),UDim2.fromOffset(270,0),function() dialValue=math.min(5,dialValue+1) value.Text=tostring(dialValue) end)
 button(controls,"CONFIRM SETTING",UDim2.new(1,0,0,44),UDim2.fromOffset(0, 70),function() submit(dialValue) end)
 else
 instruction.Text=data.kind=="search" and ("Inspect the container marked "..data.target..". Recovered clues are kept if interrupted.") or ("Connect terminal "..data.target..". Match the numbered labels.")
 for i=1,5 do button(controls,tostring(i),UDim2.fromOffset( 70, 60),UDim2.fromOffset((i-1)* 80,20),function() submit(i) end) end
 end
 end
end)
local function refresh()
 bar.Visible=p:GetAttribute("InRound")==true
 local count=config:GetAttribute("RescueCompleted") or 0
 title.Text="RESCUE PROGRESS  /  "..count.." OF 15"
 status.Text=config:GetAttribute("RescueStatus") or ""
 local on=config:GetAttribute("RescueOnline")
 for i,f in segments do f.BackgroundColor3=i<=count and Color3.fromRGB(169,163,139) or Color3.fromRGB(45, 40, 30) f.BackgroundTransparency=on and 0 or .35 end
 local nextTask
 for _,m in tasks:GetChildren() do if m:GetAttribute("Available") and (not nextTask or m:GetAttribute("TaskId")<nextTask:GetAttribute("TaskId")) then nextTask=m end end
 objective.Text=nextTask and ("NEXT: "..string.upper(nextTask:GetAttribute("Title")).."  /  "..nextTask:GetAttribute("Site")) or (on and "TEAMMATES ARE RESTORING THE SYSTEM" or "UNFINISHED TASKS RETURN AT SUNRISE")
 if not on or not bar.Visible then if active then active=nil panel.Visible=false remote:FireServer("cancel") end end
 local cam=workspace.CurrentCamera if cam then local scale=math.clamp(math.min(cam.ViewportSize.X/520,cam.ViewportSize.Y/600),.55,1) if not gui:GetAttribute("ManagedLayout") then bs.Scale=scale end ps.Scale=scale end
end
Run.RenderStepped:Connect(function()
 if active and needle then local f=((workspace:GetServerTimeNow()-active.start)%active.period)/active.period needle.Position=UDim2.new(f,-1,0,-4) end
end)
task.spawn(function() while gui.Parent do refresh() task.wait(.2) end end)
