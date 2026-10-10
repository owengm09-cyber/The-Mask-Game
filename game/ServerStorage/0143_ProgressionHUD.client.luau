local P=game.Players.LocalPlayer
local Tween=game:GetService("TweenService")
local gui=Instance.new("ScreenGui") gui.Name="ProgressionHUD" gui.ResetOnSpawn=false gui.DisplayOrder=20 gui.Parent=P:WaitForChild("PlayerGui")
local white=Color3.fromRGB(232,229,218) local red=Color3.fromRGB(157,32,39)
local function box(parent,name,size,pos,color)
 local f=Instance.new("Frame") f.Name=name f.Size=size f.Position=pos f.BackgroundColor3=color f.BorderSizePixel=0 f.Parent=parent return f
end
local function label(parent,name,text,size,pos,fontSize,color)
 local t=Instance.new("TextLabel") t.Name=name t.Text=text t.Size=size t.Position=pos t.BackgroundTransparency=1 t.Font=Enum.Font.Oswald t.TextSize=fontSize t.TextColor3=color or white t.TextXAlignment=Enum.TextXAlignment.Left t.Parent=parent return t
end
local panel=box(gui,"RankPanel",UDim2.fromOffset(265,74),UDim2.new(1,-285,0,18),Color3.fromRGB(13,13,15)) panel.BackgroundTransparency=.18
local scale=Instance.new("UIScale",panel)
local badge=box(panel,"RankDiamond",UDim2.fromOffset(40,40),UDim2.fromOffset(13,16),Color3.fromRGB(34,25,27)) badge.Rotation=45
local edge=Instance.new("UIStroke",badge) edge.Color=red edge.Thickness=2
local rank=label(badge,"Rank","1",UDim2.fromScale(1,1),UDim2.fromScale(0,0),25) rank.Rotation=-45 rank.TextXAlignment=Enum.TextXAlignment.Center
label(panel,"Caption","S U R V I V O R   R A N K",UDim2.fromOffset(187,19),UDim2.fromOffset(70,7),12,Color3.fromRGB(160,156,150))
local xp=label(panel,"XP","CONNECTING...",UDim2.fromOffset(185,20),UDim2.fromOffset(70,25),16)
local track=box(panel,"Track",UDim2.fromOffset(180,3),UDim2.fromOffset(70,50),Color3.fromRGB(58,55,54))
local fill=box(track,"Fill",UDim2.fromScale(0,1),UDim2.fromScale(0,0),red)
local state=label(panel,"Status","",UDim2.fromOffset(190,16),UDim2.fromOffset(70,55),10,Color3.fromRGB(155,151,145))
for i=1,5 do local scratch=box(panel,"Scratch",UDim2.fromOffset(1,8+i%3*3),UDim2.fromOffset(242+i*3,1),Color3.fromRGB(95,88,81)) scratch.Rotation=23 scratch.BackgroundTransparency=.5 end
local notice=box(gui,"Notice",UDim2.fromOffset(430,118),UDim2.new(.5,0,.18,0),Color3.fromRGB(12,12,14)) notice.AnchorPoint=Vector2.new(.5,0) notice.Visible=false
local ns=Instance.new("UIScale",notice)
box(notice,"BloodEdge",UDim2.new(0,3,1,0),UDim2.fromScale(0,0),red)
local title=label(notice,"Title","",UDim2.new(1,-40,0,33),UDim2.fromOffset(20,12),26)
local detail=label(notice,"Detail","",UDim2.new(1,-40,0,50),UDim2.fromOffset(20,50),15,Color3.fromRGB(179,175,166)) detail.TextWrapped=true detail.TextYAlignment=Enum.TextYAlignment.Top
local queue={} local running=false
local function show(a,b)
 table.insert(queue,{a,b}) if running then return end running=true
 task.spawn(function()
 while #queue>0 do local item=table.remove(queue,1) title.Text=item[1] detail.Text=item[2] notice.Visible=true
 notice.BackgroundTransparency=1 title.TextTransparency=1 detail.TextTransparency=1
 Tween:Create(notice,TweenInfo.new(.25),{BackgroundTransparency=.12}):Play()
 Tween:Create(title,TweenInfo.new(.25),{TextTransparency=0}):Play()
 Tween:Create(detail,TweenInfo.new(.25),{TextTransparency=0}):Play()
 task.wait(4.5) notice.Visible=false task.wait(.15)
 end running=false
 end)
end
local previous
local function refresh()
 local level=P:GetAttribute("Level") or 1 local current=P:GetAttribute("LevelXP") or 0 local cost=math.max(1,P:GetAttribute("NextLevelXP") or 100)
 local loaded=P:GetAttribute("ProgressionLoaded")
 rank.Text=tostring(level) xp.Text=loaded and (current.." / "..cost.." XP") or "CONNECTING..."
 Tween:Create(fill,TweenInfo.new(.35),{Size=UDim2.fromScale(math.clamp(current/cost,0,1),1)}):Play()
 state.Text=P:GetAttribute("XPSavePending") and "SAVE PENDING" or P:GetAttribute("ProgressionLoadFailed") and "PROGRESS UNAVAILABLE" or P:GetAttribute("InRound") and ("TASKS DONE  "..(P:GetAttribute("RoundTasks") or 0).."/15") or "SURVIVE.  RETURN.  GROW STRONGER."
 if loaded then if previous and level>previous then show("RANK INCREASED  /  "..level,"You survived the darkness.\nYour next trial awaits.") end previous=level end
end
for _,a in {"Level","LevelXP","NextLevelXP","ProgressionLoaded","ProgressionLoadFailed","XPSavePending","RoundTasks","InRound"} do P:GetAttributeChangedSignal(a):Connect(refresh) end
refresh()
local function resize()
 local cam=workspace.CurrentCamera if not cam then return end
 local s=math.clamp(math.min(cam.ViewportSize.X/1000,cam.ViewportSize.Y/700),.58,1)
 scale.Scale=s ns.Scale=s panel.Position=UDim2.new(1,-20-265*s,0,18)
end
task.spawn(function() while gui.Parent do resize() task.wait(.5) end end)
game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RoundXPResults").OnClientEvent:Connect(function(winner,amount,parts,won)
 show((won and "TRIAL WON" or "TRIAL ENDED").."  /  +"..amount.." XP",
 string.upper(winner).." WIN\nROUND "..(parts.Participation or 0).."  ·  VICTORY "..(parts.Victory or 0).."  ·  TASKS "..(parts.Tasks or 0).."\nSURVIVAL "..(parts.Survival or 0).."  ·  ELIMINATIONS "..(parts.Eliminations or 0))
end)
