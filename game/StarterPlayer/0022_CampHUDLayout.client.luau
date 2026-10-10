local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local p=Players.LocalPlayer local pg=p:WaitForChild("PlayerGui")
local dread=pg:WaitForChild("DreadHUD") dread:SetAttribute("ManagedLayout",true)
local gui=Instance.new("ScreenGui") gui.Name="CampHUDLayout" gui.ResetOnSpawn=false gui.DisplayOrder=25 gui.Parent=pg
local ink=Color3.fromRGB(17,18,19) local cream=Color3.fromRGB(230,225,210)
local muted=Color3.fromRGB(185,180,166) local red=Color3.fromRGB(151,45,45)
local sections={}
local function section(name,title)
 local root=Instance.new("Frame",gui) root.Name=name root.BackgroundTransparency=1 root.Size=UDim2.fromOffset(270,32)
 local scale=Instance.new("UIScale",root)
 local header=Instance.new("TextButton",root) header.Name="Toggle" header.Size=UDim2.new(1,0,0,34) header.BackgroundColor3=ink header.BackgroundTransparency=.08 header.BorderSizePixel=0 header.Text="" header.Selectable=true header.AutoButtonColor=true
 local text=Instance.new("TextLabel",header) text.Name="Label" text.BackgroundTransparency=1 text.Position=UDim2.fromOffset(12,0) text.Size=UDim2.new(1,-52,1,0) text.Text=title text.TextColor3=cream text.TextSize=15 text.Font=Enum.Font.Oswald text.TextXAlignment=Enum.TextXAlignment.Left
 local icon=Instance.new("Frame",header) icon.Name="Arrow" icon.BackgroundTransparency=1 icon.AnchorPoint=Vector2.new(.5,.5) icon.Position=UDim2.new(1,-20,.5,0) icon.Size=UDim2.fromOffset(16,16)
 for i=1,2 do local line=Instance.new("Frame",icon) line.BorderSizePixel=0 line.BackgroundColor3=cream line.Size=UDim2.fromOffset(8,2) line.Position=UDim2.fromOffset(i==1 and 1 or 6,7) line.Rotation=i==1 and 45 or -45 end
 local body=Instance.new("Frame",root) body.Name="Body" body.BackgroundTransparency=1 body.Position=UDim2.fromOffset(0,36) body.Size=UDim2.new(1,0,0,100)
 local entry={Root=root,Body=body,Header=header,Text=text,Icon=icon,Scale=scale,Open=true}
 sections[name]=entry
 header.Activated:Connect(function()
  entry.Open=not entry.Open
  if name=="Survivors" then dread:SetAttribute("SurvivorsHidden",not entry.Open) end
  gui:SetAttribute(name.."Collapsed",not entry.Open)
 end)
 return entry
end
local tasks=section("Tasks","RESCUE TASKS")
local account=section("Account","PROGRESS")
local survivors=section("Survivors","SURVIVORS")
local equipment=section("Equipment","EQUIPMENT")
local rescue=pg:WaitForChild("ForestRescueHUD") rescue:SetAttribute("ManagedLayout",true)
-- the panel lays out its own rows (camp power + escape van lists) for the width it's given
local progress=rescue:WaitForChild("TeamProgress") progress.Parent=tasks.Body progress.AnchorPoint=Vector2.zero progress.Position=UDim2.fromOffset(0,0) progress.Size=UDim2.fromOffset(310,122) progress:FindFirstChildOfClass("UIScale").Scale=1
tasks.Body.Size=UDim2.new(1,0,0,122)
local progression=pg:WaitForChild("ProgressionHUD") progression:SetAttribute("ManagedLayout",true)
local rank=progression:WaitForChild("RankPanel") rank.Parent=account.Body rank.Position=UDim2.fromOffset(0,0) rank.Size=UDim2.fromOffset(250,74) rank:FindFirstChildOfClass("UIScale").Scale=1
rank.Caption.Text="SURVIVOR RANK" rank.Caption.TextColor3=muted rank.Caption.Size=UDim2.fromOffset(170,19)
rank.XP.Size=UDim2.fromOffset(168,20) rank.Track.Size=UDim2.fromOffset(168,3) rank.Status.Size=UDim2.fromOffset(168,16) rank.Status.TextColor3=muted
for _,v in rank:GetChildren() do if v.Name=="Scratch" then v.Visible=false end end
local fortune=pg:WaitForChild("ZoltarFortunes")
local wallet=fortune:WaitForChild("Wallet")
-- Keep the balance outside the collapsible Progress body.
wallet.Parent=account.Root
wallet.Position=UDim2.fromOffset(0,36) wallet.Size=UDim2.fromOffset(250,48)
account.Body.Position=UDim2.fromOffset(0,88)
local left=dread.Survivors local right=dread.Loadout
left.Size=UDim2.fromOffset(258,230)
left.Objective.Size=UDim2.fromOffset(258,59) left.Objective.Count.TextSize=30 left.Objective.Count.Size=UDim2.fromOffset(48,44)
left.Objective.Heading.Position=UDim2.fromOffset(69,5) left.Objective.Heading.TextSize=12
left.Objective.Instruction.Position=UDim2.fromOffset(69,24) left.Objective.Instruction.Size=UDim2.fromOffset(180,30) left.Objective.Instruction.TextSize=12
for i=1,4 do local row=left["Survivor"..i] row.Position=UDim2.fromOffset(0,64+(i-1)*41) row.Size=UDim2.fromOffset(258,38) row.NameLabel.TextSize=13 row.StateLabel.TextSize=11 row.HealthTrack.Position=UDim2.fromOffset(51,36) end
left.Overflow.Position=UDim2.fromOffset(0,230)
right.Size=UDim2.fromOffset(250,103)
for i=1,4 do local slot=right["Perk"..i] slot.Position=UDim2.fromOffset(31+(i-1)*62,32) slot.Size=UDim2.fromOffset(37,37) end
right.PerkCaption.Position=UDim2.fromOffset(0,60) right.PerkCaption.Size=UDim2.fromOffset(250,16) right.PerkCaption.TextSize=11
right.Item.Position=UDim2.fromOffset(0,80) right.Item.Size=UDim2.fromOffset(250,26) right.Item.ItemLabel.TextSize=12
local identity=dread.Identity identity.Size=UDim2.fromOffset(140,55)
identity.Title.Size=UDim2.fromOffset(140,26) identity.Title.TextSize=20 identity.Role.Position=UDim2.fromOffset(0,29) identity.Role.Size=UDim2.fromOffset(140,20) identity.Role.TextSize=12 identity.Rule.Visible=false
local roundGui=pg:WaitForChild("RoundStatus") local round=roundGui:FindFirstChildWhichIsA("TextLabel")
if round then round.Size=UDim2.fromOffset(240,58) round.Position=UDim2.new(.5,0,0,12) round.TextSize=15 round.BackgroundTransparency=.18 end
local compass=pg:WaitForChild("ForestCompass")
local cbutton=compass:WaitForChild("CompassButton") local cscale=Instance.new("UIScale",cbutton) cscale.Scale=.8 cbutton.Position=UDim2.fromOffset(16,12)
compass.CompassCaption.Position=UDim2.fromOffset(8,77) compass.CompassCaption.TextSize=10
local initial=true
local function layout()
 local cam=workspace.CurrentCamera if not cam then return end local v=cam.ViewportSize
 local small=v.X<720 local s=math.clamp(math.min(v.X/1000,v.Y/720),.8,1)
 local margin=16 local bottom=UIS.TouchEnabled and 148 or 20
 if initial then initial=false if small then account.Open=false survivors.Open=false equipment.Open=false dread:SetAttribute("SurvivorsHidden",true) end end
 survivors.Open=not dread:GetAttribute("SurvivorsHidden")
 local alive=0 for _,other in Players:GetPlayers() do if other:GetAttribute("InRound") and not other:GetAttribute("IsKiller") then alive+=1 end end
 local rows=math.clamp(alive,1,4) local leftHeight=64+rows*41+(alive>4 and 20 or 0)
 for i=1,4 do left["Survivor"..i].Visible=i<=rows end
 left.Overflow.Position=UDim2.fromOffset(0,64+rows*41) left.Size=UDim2.fromOffset(258,leftHeight)
 survivors.Text.Text="SURVIVORS  /  "..left.Objective.Count.Text
 equipment.Text.Text="EQUIPMENT"
 for _,entry in sections do entry.Body.Visible=entry.Open entry.Icon.Rotation=entry.Open and 180 or 0 entry.Scale.Scale=s end
 local cfg=workspace:FindFirstChild("MaskSystem") -- eliminated or escaped players keep the escape plan (OutBriefing = false restores the original)
 local out=cfg~=nil and cfg:GetAttribute("OutBriefing")~=false and cfg:GetAttribute("MatchActive")==true and (p:GetAttribute("Eliminated")==true or p:GetAttribute("Escaped")==true)
 tasks.Root.Size=UDim2.fromOffset(310,34) tasks.Root.Position=UDim2.fromOffset(margin,98) tasks.Root.Visible=p:GetAttribute("InRound")==true or out
 account.Root.Size=UDim2.fromOffset(250,34) account.Root.Position=UDim2.new(1,-margin-250*s,0,small and 54 or 12)
 local y=bottom+(survivors.Open and (leftHeight+38)*s or 34*s)
 survivors.Root.Size=UDim2.fromOffset(258,34) survivors.Root.Position=UDim2.new(0,margin,1,-y)
 left.AnchorPoint=Vector2.new(0,1) left.Position=UDim2.new(0,margin,1,-bottom) left.Visible=survivors.Open left.ResponsiveScale.Scale=s
 equipment.Root.Size=UDim2.fromOffset(250,34) equipment.Root.Position=UDim2.new(1,-margin-250*s,1,-bottom-(equipment.Open and 144 or 34)*s)
 right.AnchorPoint=Vector2.new(1,1) right.Position=UDim2.new(1,-margin,1,-bottom) right.Visible=equipment.Open right.ResponsiveScale.Scale=s
 identity.Position=UDim2.fromOffset(90,12) identity.Visible=not small identity.ResponsiveScale.Scale=s
 if round then round.Position=small and UDim2.new(1,-16,0,12) or UDim2.new(.5,0,0,12) round.AnchorPoint=Vector2.new(small and 1 or .5,0) round.Size=UDim2.fromOffset(small and 215 or 240,58) end
end
layout()
task.spawn(function() while gui.Parent do layout() task.wait(.25) end end)
