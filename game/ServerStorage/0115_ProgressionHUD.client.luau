local p=game.Players.LocalPlayer
local gui=Instance.new("ScreenGui") gui.Name="ProgressionHUD" gui.ResetOnSpawn=false gui.DisplayOrder=15 gui.Parent=p:WaitForChild("PlayerGui")
local panel=Instance.new("Frame",gui) panel.Size=UDim2.fromOffset(240,68) panel.Position=UDim2.new(1,-256,1,-88) panel.BackgroundColor3=Color3.fromRGB(22,23,20) panel.BackgroundTransparency=.15
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,8)
local text=Instance.new("TextLabel",panel) text.Size=UDim2.new(1,-20,0,28) text.Position=UDim2.fromOffset(10,5) text.BackgroundTransparency=1 text.TextColor3=Color3.fromRGB(219,208,171) text.Font=Enum.Font.GothamBold text.TextSize=15 text.TextXAlignment=Enum.TextXAlignment.Left
local bar=Instance.new("Frame",panel) bar.Position=UDim2.fromOffset(10,38) bar.Size=UDim2.new(1,-20,0,8) bar.BackgroundColor3=Color3.fromRGB(58,58,48)
local fill=Instance.new("Frame",bar) fill.BorderSizePixel=0 fill.BackgroundColor3=Color3.fromRGB(167,141,80)
local small=Instance.new("TextLabel",panel) small.Position=UDim2.fromOffset(10,49) small.Size=UDim2.new(1,-20,0,14) small.BackgroundTransparency=1 small.TextColor3=Color3.fromRGB(179,176,155) small.TextSize=11 small.Font=Enum.Font.Gotham
local toast=Instance.new("TextLabel",gui) toast.AnchorPoint=Vector2.new(.5,0) toast.Position=UDim2.new(.5,0,.15,0) toast.Size=UDim2.new(.7,0,0,100) toast.BackgroundColor3=Color3.fromRGB(22,23,20) toast.BackgroundTransparency=.12 toast.TextColor3=Color3.fromRGB(226,213,175) toast.Font=Enum.Font.GothamBold toast.TextSize=17 toast.TextWrapped=true toast.Visible=false Instance.new("UICorner",toast)
local previousLevel=p:GetAttribute("Level") local token=0
local function show(message)
 token+=1 local current=token toast.Text=message toast.Visible=true task.delay(8,function() if current==token then toast.Visible=false end end)
end
local function refresh()
 local loaded=p:GetAttribute("ProgressionLoaded")
 local level=p:GetAttribute("Level") or 1 local xp=p:GetAttribute("LevelXP") or 0 local cost=p:GetAttribute("NextLevelXP") or 100
 text.Text=loaded and ("LEVEL "..level.."  •  "..xp.." / "..cost.." XP") or "Loading progression..."
 fill.Size=UDim2.fromScale(math.clamp(xp/cost,0,1),1)
 small.Text=p:GetAttribute("XPSavePending") and "XP save pending — retrying" or (p:GetAttribute("StudioXPPreview") and "Studio preview • progress is not saved" or (p:GetAttribute("InRound") and ("Supplies searched: "..(p:GetAttribute("RoundTasks") or 0).."/3") or "Win rounds • complete tasks • survive"))
 if previousLevel and level>previousLevel then show("LEVEL UP!\nYou reached level "..level) end
 previousLevel=level
end
for _,key in {"Level","LevelXP","NextLevelXP","ProgressionLoaded","XPSavePending","RoundTasks","InRound"} do p:GetAttributeChangedSignal(key):Connect(refresh) end refresh()
game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RoundXPResults").OnClientEvent:Connect(function(winner,amount,parts,won)
 show(string.upper(winner).." WIN  •  +"..amount.." XP\nRound "..parts.Participation.."  |  Victory "..parts.Victory.."  |  Tasks "..parts.Tasks.."\nSurvival "..parts.Survival.."  |  Eliminations "..parts.Eliminations)
end)