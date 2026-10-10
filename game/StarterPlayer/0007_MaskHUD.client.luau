local player=game:GetService("Players").LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="MaskRoleHUD" gui.ResetOnSpawn=false gui.IgnoreGuiInset=false
gui.Parent=player:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel")
label.Name="Role" label.AnchorPoint=Vector2.new(.5,1)
label.Position=UDim2.new(.5,0,1,-28) label.Size=UDim2.new(.9,0,0,62)
label.BackgroundColor3=Color3.fromRGB(18,21,20) label.BackgroundTransparency=.18
label.TextColor3=Color3.fromRGB(226,231,217)
label.Font=Enum.Font.GothamMedium label.TextSize=16 label.TextWrapped=true
label.Parent=gui
local limit=Instance.new("UISizeConstraint") limit.MaxSize=Vector2.new(570,70) limit.Parent=label
local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(0,10) corner.Parent=label
local config=workspace:WaitForChild("MaskSystem")
local function update()
 if player:GetAttribute("HasMask") then
  label.Text="KILLER  •  The mask chose you\nEquip Mask Strike • Click / tap to strike nearby players"
  label.TextColor3=Color3.fromRGB(255,164,150)
 else
  label.Text=string.upper(player:GetAttribute("Role") or "Survivor").."  •  "..(config:GetAttribute("MaskState")=="Worn" and "The killer is hunting. Stay alert." or "Find the mask hidden in the forest.")
  label.TextColor3=Color3.fromRGB(226,231,217)
 end
end
player:GetAttributeChangedSignal("Role"):Connect(update)
player:GetAttributeChangedSignal("HasMask"):Connect(update)
config:GetAttributeChangedSignal("MaskState"):Connect(update)
update()