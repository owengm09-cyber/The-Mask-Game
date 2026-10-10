local p=game.Players.LocalPlayer
local config=workspace:WaitForChild("MaskSystem")
local gui=Instance.new("ScreenGui") gui.Name="RoundStatus" gui.ResetOnSpawn=false gui.Parent=p:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel") label.Size=UDim2.new(.7,0,0,42) label.AnchorPoint=Vector2.new(.5,0) label.Position=UDim2.new(.5,0,0,16) label.BackgroundColor3=Color3.fromRGB(15,15,17) label.BackgroundTransparency=.18 label.TextColor3=Color3.fromRGB(236,230,211) label.Font=Enum.Font.Oswald label.TextSize=16 label.Parent=gui
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,0) corner.Parent=label
local constraint=Instance.new("UISizeConstraint") constraint.MaxSize=Vector2.new(540,42) constraint.Parent=label
local Clock=require(game.ReplicatedStorage:WaitForChild("ForestClock"))
local time=Instance.new("TextLabel")
time.Name="Clock" time.BackgroundTransparency=1 time.Size=UDim2.new(1,0,0,24)
time.Position=UDim2.fromOffset(0,0) time.Font=Enum.Font.Oswald time.TextSize=20
time.TextColor3=Color3.fromRGB(245,230,200) time.Parent=label
label.TextYAlignment=Enum.TextYAlignment.Bottom
label.Name="TrialStatus"
constraint.MaxSize=Vector2.new(540,58)
label.Size=UDim2.new(.7,0,0,58)
while gui.Parent do
 time.Visible=p:GetAttribute("InRound")==true
 time.Text=Clock.Format(game.Lighting:GetAttribute("GameTimeHours") or Clock.StartHour)

 local zoneName=p:GetAttribute("ReadyZone")
 local lobbyZones=workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("ReadyZones")
  local zone=zoneName and lobbyZones and lobbyZones:FindFirstChild(zoneName)
 if p:GetAttribute("InRound") then
  local seconds=math.max(0,math.ceil((config:GetAttribute("RoundEndsAt") or workspace:GetServerTimeNow())-workspace:GetServerTimeNow()))
  label.Text="FOREST TRIAL  •  "..string.upper(game.Lighting:GetAttribute("Phase") or "Day") label.Visible=true
 elseif zone then
  label.Text=tostring(zone:GetAttribute("Count") or 0).."/"..tostring(zone:GetAttribute("Capacity") or 6).."  •  "..(zone:GetAttribute("Status") or "Ready up").."  •  Walk out to leave"
  label.Visible=true
 else label.Visible=false end
 task.wait(.2)
end
