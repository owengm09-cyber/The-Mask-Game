-- DBD-inspired presentation for The MASK. Perk slots display Perk1..Perk4 attributes.
-- Gameplay authority stays with the existing MaskService.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local gui=script.Parent
local left=gui.Survivors
local right=gui.Loadout
local lastState=nil
local noticeVersion=0
local function notify(message,detail)
 noticeVersion+=1 local version=noticeVersion
 gui.Event.Visible=true gui.Event.Message.Text=message gui.Event.Detail.Text=detail
 gui.Event.Message.TextTransparency=0 gui.Event.Detail.TextTransparency=0
 task.delay(4,function()
  if version~=noticeVersion or not gui.Parent then return end
  TweenService:Create(gui.Event.Message,TweenInfo.new(.6),{TextTransparency=1}):Play()
  TweenService:Create(gui.Event.Detail,TweenInfo.new(.6),{TextTransparency=1}):Play()
  task.wait(.65)
  if version==noticeVersion and gui.Parent then gui.Event.Visible=false end
 end)
end
local function update()
 local camera=workspace.CurrentCamera
 if camera then
  local v=camera.ViewportSize
  local scale=math.clamp(math.min(v.X/1200,v.Y/780),.52,1)
  for _,name in ipairs({"Survivors","Loadout","Identity","Event"}) do
   gui[name].ResponsiveScale.Scale=scale
  end
  -- Keep touch movement/jump controls clear in phone layouts.
  local touch=game:GetService("UserInputService").TouchEnabled
  left.Position=UDim2.new(0,16,1,touch and -155 or -26)
  right.Position=UDim2.new(1,-20,1,touch and -155 or -25)
 end
 local config=workspace:FindFirstChild("MaskSystem")
 local maskState=config and config:GetAttribute("MaskState") or "Hidden"
 local inRound=player:GetAttribute("InRound")==true
 local killer=player:GetAttribute("HasMask")==true
 local role=player:GetAttribute("Role") or "Survivor"
 gui.Identity.Role.Text=not inRound and "LOBBY" or killer and "KILLER / THE MASK CHOSE YOU" or string.upper(tostring(role))
 left.Objective.Instruction.Text=not inRound and "ENTER A READY ZONE • 6 PLAYERS" or killer and "HUNT THE SURVIVORS" or (maskState=="Worn" and "SURVIVE THE HUNT" or "FIND THE MASK")
 if inRound and lastState~=nil and lastState~=maskState then
  if maskState=="Worn" then notify("THE HUNT HAS BEGUN",killer and "The mask chose you." or "The killer is hunting. Stay alert.")
  else notify("THE MASK IS WAITING","Find the mask hidden in the forest.") end
 end
 lastState=maskState
 local roster={}
 for _,p in ipairs(Players:GetPlayers()) do
  if p:GetAttribute("InRound")==true and p:GetAttribute("HasMask")~=true and string.lower(tostring(p:GetAttribute("Role") or ""))~="killer" then table.insert(roster,p) end
 end
 table.sort(roster,function(a,b) if a==player then return true elseif b==player then return false else return a.UserId<b.UserId end end)
 local alive=0
 for _,p in ipairs(roster) do
  local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  if h and h.Health>0 then alive+=1 end
 end
 left.Objective.Count.Text=tostring(alive)
 for i=1,4 do
  local row=left["Survivor"..i] local p=roster[i]
  local h=p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  local hp=h and math.clamp(h.Health/math.max(h.MaxHealth,1),0,1) or 0
  local status=not p and "EMPTY SLOT" or (not h and "SPAWNING" or (hp<=0 and "ELIMINATED" or (hp<.99 and "INJURED" or "HEALTHY")))
  local col=(status=="INJURED" or status=="ELIMINATED") and Color3.fromRGB(203,58,62) or Color3.fromRGB(229,225,215)
  row.NameLabel.Text=p and ((p==player and "YOU / " or "")..p.DisplayName) or "WAITING FOR SURVIVOR"
  row.NameLabel.TextColor3=p and col or Color3.fromRGB(133,133,132)
  row.StateLabel.Text=status
  row.StateLabel.TextColor3=col
  row.Portrait.Head.BackgroundColor3=col row.Portrait.Body.BackgroundColor3=col
  row.Portrait.Head.BackgroundTransparency=p and 0 or .7 row.Portrait.Body.BackgroundTransparency=p and 0 or .7
  row.HealthTrack.Fill.Size=UDim2.new(hp,0,1,0) row.HealthTrack.Fill.BackgroundColor3=col
 end
 left.Overflow.Text=#roster>4 and ("+"..tostring(#roster-4).." MORE SURVIVORS") or ""
 local equipped=player.Character and player.Character:FindFirstChildOfClass("Tool")
 right.Item.ItemLabel.Text=equipped and string.upper(equipped.Name) or (killer and "EQUIP MASK STRIKE" or "NO ITEM EQUIPPED")
 local perkCount=0
 for i=1,4 do
  local name=player:GetAttribute("Perk"..i)
  local filled=type(name)=="string" and name~=""
  local slot=right["Perk"..i]
  slot.Symbol.Text=filled and string.sub(string.upper(name),1,3) or "+"
  slot.Symbol.TextSize=filled and 14 or 26
  slot.Edge.Color=filled and Color3.fromRGB(174,123,196) or Color3.fromRGB(102,86,113)
  if filled then perkCount+=1 end
 end
 right.PerkCaption.Text=perkCount>0 and ("P E R K S  /  "..perkCount.." EQUIPPED") or "P E R K S  /  EMPTY"
end
while gui.Parent do
 update()
 task.wait(.25)
end
