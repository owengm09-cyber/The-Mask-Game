-- Server-owned pickup, cooldown, and emergency meeting lifecycle.
local M={}
local Players=game:GetService("Players")
local Storage=game:GetService("ServerStorage")
local TweenService=game:GetService("TweenService")
local config=workspace:WaitForChild("MaskSystem")
local camp=workspace:WaitForChild("EmergencyCampsite")
local marker=camp:WaitForChild("FlareSpawn")
local prompt=marker:WaitForChild("FlarePickup")
local holder,heldTool,display,deathConnection,ancestryConnection
local participants={} local serial=0 local started=false
local readyAt=0
local function now() return workspace:GetServerTimeNow() end
local function alive(p)
 local c=p and p.Character local h=c and c:FindFirstChildOfClass("Humanoid") local r=c and c:FindFirstChild("HumanoidRootPart")
 if p and p.Parent==Players and h and h.Health>0 and r then return c,h,r end
end
local function playing(p)
 return config:GetAttribute("MatchActive")==true and p:GetAttribute("InRound")==true
end
local function drawGun()
 if display then display:Destroy() end
 for _,o in ipairs(camp:GetChildren()) do if o.Name=="FlareGunDisplay" then o:Destroy() end end
 local source=Storage:WaitForChild("MeetingFlareTemplate"):Clone()
 display=Instance.new("Model") display.Name="FlareGunDisplay"
 for _,o in ipairs(source:GetChildren()) do if o:IsA("BasePart") then o.Parent=display o.Anchored=true o.CanCollide=false end end
 display.PrimaryPart=display:FindFirstChild("Handle")
 display:PivotTo(marker.CFrame) display.Parent=camp source:Destroy()
end
local function refresh()
 local remaining=math.max(0,math.ceil(readyAt-now()))
 prompt.Enabled=not holder and remaining==0 and config:GetAttribute("MeetingActive")~=true
 prompt.ObjectText=remaining>0 and ("Flare reloading · "..remaining.."s") or "Emergency meeting"
 camp:SetAttribute("FlareReadyAt",readyAt)
 camp:SetAttribute("FlareHolderUserId",holder and holder.UserId or 0)
 -- the quiet FLARE GUN label over the stump: just the name while it's there; a small line under it when it's taken or reloading
 local label=marker:FindFirstChild("FlareStatus")
 if label then
  local plate=label:FindFirstChild("Plate") or label
  local line=plate:FindFirstChild("TextLabel") local title=plate:FindFirstChild("Title")
  if line then line.Text=holder and "TAKEN" or (remaining>0 and ("READY IN "..remaining.."s") or "") end
  if title then title.TextTransparency=(holder or remaining>0) and 0.5 or 0.12 end
 end
end
local function returnGun()
 if deathConnection then deathConnection:Disconnect() deathConnection=nil end
 if ancestryConnection then ancestryConnection:Disconnect() ancestryConnection=nil end
 local old=heldTool holder=nil heldTool=nil
 if old then old:Destroy() end
 drawGun() refresh()
end
local function flareEffect(position)
 local flare=Instance.new("Part") flare.Name="EmergencySignal" flare.Shape=Enum.PartType.Ball flare.Size=Vector3.new(.6,.6,.6) flare.Color=Color3.fromRGB(255,65,35) flare.Material=Enum.Material.Neon flare.Anchored=true flare.CanCollide=false flare.CanQuery=false flare.CanTouch=false flare.Position=position flare.Parent=workspace
 local a=Instance.new("Attachment") a.Position=Vector3.new(-.15,0,0) a.Parent=flare
 local b=Instance.new("Attachment") b.Position=Vector3.new(.15,0,0) b.Parent=flare
 local trail=Instance.new("Trail") trail.Attachment0=a trail.Attachment1=b trail.Color=ColorSequence.new(Color3.fromRGB(255,110,40)) trail.LightEmission=1 trail.Lifetime=1.5 trail.Parent=flare
 local light=Instance.new("PointLight") light.Color=flare.Color light.Range=50 light.Brightness=5 light.Parent=flare
 local fire=Instance.new("Fire") fire.Heat=2 fire.Size=3 fire.Color=Color3.fromRGB(255,105,40) fire.Parent=flare
 TweenService:Create(flare,TweenInfo.new(3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=position+Vector3.new(0,110,0)}):Play()
 task.delay(3,function() if flare.Parent then TweenService:Create(flare,TweenInfo.new(8,Enum.EasingStyle.Linear),{Position=flare.Position-Vector3.new(0,18,0),Transparency=1}):Play() TweenService:Create(light,TweenInfo.new(8),{Brightness=0}):Play() end end)
 game:GetService("Debris"):AddItem(flare,12)
end
local function releaseParticipant(p,data)
 if data.freeze then data.freeze:Disconnect() end
 if data.forcefield then data.forcefield:Destroy() end
 local c,h,r=alive(p)
 if c==data.character then
  h.WalkSpeed=data.speed h.JumpPower=data.jumpPower h.JumpHeight=data.jumpHeight h.AutoRotate=data.autoRotate
  h:SetStateEnabled(Enum.HumanoidStateType.Jumping,data.jumping) h.Sit=false
  local weld=data.seat and data.seat:FindFirstChild("SeatWeld")
  if weld and (weld.Part1==r or weld.Part1 and weld.Part1:IsDescendantOf(c)) then weld:Destroy() end
  -- Resume at the pre-meeting location, so the killer cannot camp the meeting seats.
  -- The player's client still thinks it is seated and would snap the character back to the log,
  -- so the server owns the character's physics for the teleport, then hands it back.
  if playing(p) then
   if data.seat then for _,w in ipairs(data.seat:GetChildren()) do if w.Name=="SeatWeld" then w:Destroy() end end end
   h.Sit=false
   pcall(function() r:SetNetworkOwner(nil) end)
   c:PivotTo(data.original) r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero
   task.delay(.6,function() if r.Parent and p.Parent==Players then pcall(function() r:SetNetworkOwner(p) end) end end)
  end
 end
 p:SetAttribute("InEmergencyMeeting",false)
end
-- Meeting chat: a dedicated TextChatService channel (Roblox filters every message).
-- MeetingTablet (StarterPlayerScripts) is the Among Us-style UI that reads and writes it.
local TextChatService=game:GetService("TextChatService")
local function meetingChannel()
 local folder=TextChatService:FindFirstChild("TextChannels")
 if not folder then folder=Instance.new("Folder") folder.Name="TextChannels" folder.Parent=TextChatService end
 local ch=folder:FindFirstChild("EmergencyMeeting")
 if not ch then ch=Instance.new("TextChannel") ch.Name="EmergencyMeeting" ch.Parent=folder end
 return ch
end
local function clearMeetingChannel()
 local ch=meetingChannel()
 for _,src in ipairs(ch:GetChildren()) do if src:IsA("TextSource") then src:Destroy() end end
end
function M.EndMeeting()
 if config:GetAttribute("MeetingActive")~=true then return false end
 serial+=1
 for p,data in pairs(participants) do releaseParticipant(p,data) end
 participants={}
 config:SetAttribute("MeetingActive",false) config:SetAttribute("MeetingEndsAt",nil) config:SetAttribute("MeetingCaller",nil) config:SetAttribute("MeetingCallerUserId",nil)
 clearMeetingChannel()
 refresh() return true
end
local function beginMeeting(caller)
 require(script.Parent.VentService).CancelAll("Emergency meeting")
 config:SetAttribute("MeetingActive",true)
 config:SetAttribute("MeetingCaller",caller.DisplayName)
 local duration=math.clamp(camp:GetAttribute("MeetingDuration") or 45,5,180)
 local endAt=now()+duration
 config:SetAttribute("MeetingEndsAt",endAt)
 local seats=camp.MeetingSeats:GetChildren() table.sort(seats,function(a,b)return a.Name<b.Name end)
 local index=0
 for _,p in ipairs(Players:GetPlayers()) do
  local c,h,r=alive(p)
  if c and playing(p) then
   index+=1
   local seat=seats[(index-1)%#seats+1]
   local data={character=c,speed=h.WalkSpeed,jumpPower=h.JumpPower,jumpHeight=h.JumpHeight,autoRotate=h.AutoRotate,jumping=h:GetStateEnabled(Enum.HumanoidStateType.Jumping),original=c:GetPivot(),seat=seat}
   participants[p]=data p:SetAttribute("InEmergencyMeeting",true)
   h:UnequipTools() h.Sit=false
   h.WalkSpeed=0 h.JumpPower=0 h.JumpHeight=0 h.AutoRotate=false h:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
   local ff=Instance.new("ForceField") ff.Name="MeetingProtection" ff.Visible=false ff.Parent=c data.forcefield=ff
   c:PivotTo(seat.CFrame*CFrame.new(0,2.5,0)) r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero
   -- Sit is retried because a just-unequipped character may still be releasing a previous seat.
   task.defer(function() if participants[p]==data and h.Health>0 then seat:Sit(h) end end)
   data.freeze=h:GetPropertyChangedSignal("WalkSpeed"):Connect(function() if participants[p]==data and h.WalkSpeed~=0 then h.WalkSpeed=0 end end)
  end
 end
 clearMeetingChannel()
 local channel=meetingChannel()
 for p in pairs(participants) do task.spawn(function() pcall(function() channel:AddUserAsync(p.UserId) end) end) end
 serial+=1 local token=serial
 task.spawn(function()
  while config:GetAttribute("MeetingActive")==true and serial==token and now()<endAt and config:GetAttribute("MatchActive")==true do task.wait(.2) end
  if serial==token then M.EndMeeting() end
 end)
end
function M.Pickup(p)
 if holder or config:GetAttribute("MeetingActive")==true or now()<readyAt or not playing(p) then return false end
 local c,h,r=alive(p)
 if not c or (r.Position-marker.Position).Magnitude>11 then return false end
 local tool=Storage.MeetingFlareTemplate:Clone() tool.Name="Emergency Flare"
 holder=p heldTool=tool
 tool.Parent=p:FindFirstChildOfClass("Backpack") or p:WaitForChild("Backpack")
 h:EquipTool(tool)
 if display then display:Destroy() display=nil end
 deathConnection=h.Died:Connect(returnGun)
 ancestryConnection=tool.AncestryChanged:Connect(function()
  task.defer(function()
   if heldTool==tool and not tool:IsDescendantOf(p) and not tool:IsDescendantOf(c) then returnGun() end
  end)
 end)
 refresh() return true
end
-- Flare cinematic: every client sees the caller raise the gun and fire the flare (FlareCinematicClient),
-- then the meeting begins. Everyone in the round is frozen and protected while it plays.
local CINEMATIC_TIME=4.9
local cinematicRemote
local function freezeForCinematic()
 local list={}
 for _,pl in ipairs(Players:GetPlayers()) do
  local c,h=alive(pl)
  if c and playing(pl) then
   local d={h=h,speed=h.WalkSpeed,jumpHeight=h.JumpHeight,jumpPower=h.JumpPower}
   h.WalkSpeed=0 h.JumpHeight=0 h.JumpPower=0
   local ff=Instance.new("ForceField") ff.Name="FlareCinematicProtection" ff.Visible=false ff.Parent=c d.ff=ff
   d.conn=h:GetPropertyChangedSignal("WalkSpeed"):Connect(function() if h.WalkSpeed~=0 then h.WalkSpeed=0 end end)
   list[#list+1]=d
  end
 end
 return list
end
local function unfreeze(list)
 for _,d in ipairs(list) do
  if d.conn then d.conn:Disconnect() end
  if d.ff then d.ff:Destroy() end
  if d.h.Parent then d.h.WalkSpeed=d.speed d.h.JumpHeight=d.jumpHeight d.h.JumpPower=d.jumpPower end
 end
end
function M.Fire(p)
 if p~=holder or not heldTool or config:GetAttribute("MeetingActive")==true or now()<readyAt or not playing(p) then return false end
 local c,h,r=alive(p)
 if not c or heldTool.Parent~=c then return false end
 local handle=heldTool:FindFirstChild("Handle") if not handle then return false end
 -- No yielding before the cooldown is locked; repeated client requests cannot create duplicate meetings.
 readyAt=now()+math.max(60,camp:GetAttribute("FlareCooldown") or 60)
 -- Meeting state starts at the shot: the creature, vents, tasks and the clock pause during the cinematic.
 require(script.Parent.VentService).CancelAll("Emergency meeting")
 config:SetAttribute("MeetingActive",true)
 config:SetAttribute("MeetingCaller",p.DisplayName)
 config:SetAttribute("MeetingCallerUserId",p.UserId)
 serial+=1 local token=serial
 local frozen=freezeForCinematic()
 local tool=heldTool
 if cinematicRemote then cinematicRemote:FireAllClients(p.UserId,CINEMATIC_TIME) end
 refresh()
 task.delay(CINEMATIC_TIME,function()
  unfreeze(frozen)
  if heldTool==tool then returnGun() end
  if serial~=token then return end -- the match ended during the cinematic
  if config:GetAttribute("MatchActive")~=true then config:SetAttribute("MeetingActive",false) refresh() return end
  beginMeeting(p) refresh()
 end)
 return true
end
function M.GetHolder() return holder end
function M.ReadyAt() return readyAt end
function M.Start()
 if started then return end started=true
 config:SetAttribute("MeetingActive",false) config:SetAttribute("MeetingEndsAt",nil)
 local remotes=game.ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder",game.ReplicatedStorage) remotes.Name="Remotes"
 local remote=remotes:FindFirstChild("FireMeetingFlare") or Instance.new("RemoteEvent",remotes) remote.Name="FireMeetingFlare"
 remote.OnServerEvent:Connect(function(p) local result=M.Fire(p) print("FLARE SERVER: request",p.Name,result) end)
 cinematicRemote=remotes:FindFirstChild("FlareCinematic") or Instance.new("RemoteEvent",remotes) cinematicRemote.Name="FlareCinematic"
 prompt.Triggered:Connect(M.Pickup)
 Players.PlayerRemoving:Connect(function(p)
  if holder==p then returnGun() end
  local data=participants[p] if data then releaseParticipant(p,data) participants[p]=nil end
 end)
 config:GetAttributeChangedSignal("MatchActive"):Connect(function()
  if config:GetAttribute("MatchActive")~=true then
   M.EndMeeting() if holder then returnGun() end
   readyAt=0 -- the flare cooldown belongs to the round it was fired in
  end
 end)
 returnGun()
 task.spawn(function() while camp.Parent do refresh() task.wait(.25) end end)
end
return M
