local Players=game:GetService("Players")
local player=Players.LocalPlayer
local config=workspace:WaitForChild("MaskSystem")
local gui=Instance.new("ScreenGui") gui.Name="EmergencyMeetingHUD" gui.ResetOnSpawn=false gui.DisplayOrder=40 gui.Parent=player:WaitForChild("PlayerGui")
local frame=Instance.new("Frame") frame.AnchorPoint=Vector2.new(.5,0) frame.Position=UDim2.new(.5,0,0,60) frame.Size=UDim2.new(.64,0,0,114) frame.BackgroundColor3=Color3.fromRGB(18,20,20) frame.BackgroundTransparency=.08 frame.BorderSizePixel=0 frame.Visible=false frame.Parent=gui
local limit=Instance.new("UISizeConstraint") limit.MaxSize=Vector2.new(570,114) limit.MinSize=Vector2.new(240,114) limit.Parent=frame
local line=Instance.new("Frame") line.Size=UDim2.new(1,0,0,3) line.BorderSizePixel=0 line.BackgroundColor3=Color3.fromRGB(217,105,48) line.Parent=frame
local function label(name,y,height,font,size,color)
 local t=Instance.new("TextLabel") t.Name=name t.BackgroundTransparency=1 t.Position=UDim2.new(0,12,0,y) t.Size=UDim2.new(1,-24,0,height) t.Font=font t.TextSize=size t.TextColor3=color t.TextWrapped=true t.Parent=frame return t
end
local title=label("Title",12,23,Enum.Font.GothamBold,17,Color3.fromRGB(240,222,190))
local caller=label("Caller",39,24,Enum.Font.Gotham,13,Color3.fromRGB(218,214,200))
local desc=label("Description",72,30,Enum.Font.Gotham,12,Color3.fromRGB(163,172,165))
local tip=Instance.new("TextLabel") tip.AnchorPoint=Vector2.new(.5,1) tip.Position=UDim2.new(.5,0,1,-92) tip.Size=UDim2.new(.58,0,0,48) tip.BackgroundColor3=Color3.fromRGB(20,23,22) tip.BackgroundTransparency=.15 tip.BorderSizePixel=0 tip.Font=Enum.Font.GothamMedium tip.TextSize=14 tip.TextColor3=Color3.fromRGB(245,220,175) tip.TextWrapped=true tip.Text="FLARE EQUIPPED\nClick / tap / trigger to call a meeting" tip.Visible=false tip.Parent=gui
while gui.Parent do
 local meeting=config:GetAttribute("MeetingActive")==true and player:GetAttribute("InEmergencyMeeting")==true
 frame.Visible=meeting
 if meeting then
  local remaining=math.max(0,math.ceil((config:GetAttribute("MeetingEndsAt") or 0)-workspace:GetServerTimeNow()))
  title.Text="EMERGENCY MEETING  ·  "..remaining.."s"
  caller.Text=(config:GetAttribute("MeetingCaller") or "A survivor").." fired the flare"
  desc.Text="Discuss in chat. The day/night cycle and round timer are paused."
 end
 local c=player.Character local tool=c and c:FindFirstChildOfClass("Tool")
 tip.Visible=not meeting and tool~=nil and tool:GetAttribute("MeetingFlare")==true
 task.wait(.1)
end
