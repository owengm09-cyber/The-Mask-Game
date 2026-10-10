local p=game.Players.LocalPlayer
local config=workspace:WaitForChild("MaskSystem")
local gui=Instance.new("ScreenGui") gui.Name="RoundStatus" gui.ResetOnSpawn=false gui.Parent=p:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel") label.Size=UDim2.new(.7,0,0,42) label.AnchorPoint=Vector2.new(.5,0) label.Position=UDim2.new(.5,0,0,16) label.BackgroundColor3=Color3.fromRGB(15,15,17) label.BackgroundTransparency=.18 label.TextColor3=Color3.fromRGB(236,230,211) label.Font=Enum.Font.Oswald label.TextSize=16 label.Parent=gui
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,0) corner.Parent=label
local constraint=Instance.new("UISizeConstraint") constraint.MaxSize=Vector2.new(540,42) constraint.Parent=label
while gui.Parent do
 local zoneName=p:GetAttribute("ReadyZone")
 local zone=zoneName and workspace.Lobby.ReadyZones:FindFirstChild(zoneName)
 if p:GetAttribute("InRound") then
  local seconds=math.max(0,math.ceil((config:GetAttribute("RoundEndsAt") or workspace:GetServerTimeNow())-workspace:GetServerTimeNow()))
  label.Text=string.format("FOREST ROUND  •  %d:%02d",math.floor(seconds/60),seconds%60) label.Visible=true
 elseif zone then
  label.Text=tostring(zone:GetAttribute("Count") or 0).."/"..tostring(zone:GetAttribute("Capacity") or 6).."  •  "..(zone:GetAttribute("Status") or "Ready up").."  •  Walk out to leave"
  label.Visible=true
 else label.Visible=false end
 task.wait(.2)
end
