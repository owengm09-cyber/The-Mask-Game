local S={}
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local config=workspace:WaitForChild("MaskSystem")
local folder=workspace:WaitForChild("ForestRescueTasks")
local remotes=game.ReplicatedStorage:WaitForChild("Remotes")
local remote=Instance.new("RemoteEvent",remotes) remote.Name="RescueInteraction"
local Progression=require(script.Parent.ProgressionService)
-- Each task's mini-game is built and judged in TaskGames (model attribute "Game", rounds in "Rounds").
local Games=require(script:WaitForChild("TaskGames"))
local sessions={} local locks={} local epoch=0 local count=0 local maskLocked=false local active=false
local rng=Random.new()
local function total() return #folder:GetChildren() end
local function rollFrequency()
 local fine=rng:NextInteger(1,19)*5
 config:SetAttribute("RescueFrequency",string.format("%d.%02d",rng:NextInteger(141,149),fine))
end
if not config:GetAttribute("RescueFrequency") then rollFrequency() end
local function online()
 return active and config:GetAttribute("MatchActive")==true and Lighting:GetAttribute("Phase")=="Day" and not maskLocked and config:GetAttribute("MeetingActive")~=true
end
local function dependencies(m)
 for n in string.gmatch(m:GetAttribute("Dependencies") or "","%d+") do
 local dep=folder:FindFirstChild(string.format("Task%02d",tonumber(n)))
 if not dep or not dep:GetAttribute("Done") then return false end
 end return true
end
local function valid(p,m)
 local c=p.Character local h=c and c:FindFirstChildOfClass("Humanoid") local r=c and c:FindFirstChild("HumanoidRootPart")
 if not online() or p:GetAttribute("InRound")~=true or p:GetAttribute("HasMask") or p:GetAttribute("Role")=="Killer" or not h or h.Health<=0 or not r or (r.Position-m.PrimaryPart.Position).Magnitude>11 or m:GetAttribute("Done") or not dependencies(m) then return false end
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={c,m} ray.RespectCanCollide=true
 return workspace:Raycast(r.Position,m.PrimaryPart.Position-r.Position,ray)==nil
end
local function cancel(p,reason)
 local session=sessions[p] if session then locks[session.model]=nil sessions[p]=nil remote:FireClient(p,"close",reason or "TASK INTERRUPTED") end
end
local function refresh()
 local on=online()
 config:SetAttribute("RescueCompleted",count) config:SetAttribute("RescueTotal",total())
 config:SetAttribute("RescueOnline",on)
 config:SetAttribute("RescueStatus",not active and "WAITING FOR ROUND" or config:GetAttribute("MeetingActive") and "MEETING — TASKS PAUSED" or maskLocked and "MASK RELEASED — TASKS OFFLINE" or Lighting:GetAttribute("Phase")~="Day" and "NIGHTFALL — TASKS OFFLINE" or "DAYLIGHT — RESTORE THE RESCUE SYSTEM")
 for _,m in folder:GetChildren() do
 local ready=on and not m:GetAttribute("Done") and dependencies(m)
 m.PrimaryPart.RescuePrompt.Enabled=ready and locks[m]==nil
 m:SetAttribute("Available",ready)
 local mapTask=game.ReplicatedStorage.RescueMapData.Tasks:FindFirstChild(m.Name)
 if mapTask then mapTask:SetAttribute("Available",ready) mapTask:SetAttribute("Done",m:GetAttribute("Done")) end
 local lamp=m:FindFirstChild("StatusLamp") if lamp then lamp.Color=m:GetAttribute("Done") and Color3.fromRGB(112,145,95) or ready and Color3.fromRGB(208,160, 70) or Color3.fromRGB(76, 30, 20) lamp.Material=ready and Enum.Material.Neon or Enum.Material.Glass end
 end
 if not on then local list={} for p in sessions do table.insert(list,p) end for _,p in list do cancel(p,config:GetAttribute("RescueStatus")) end end
end
-- start (or advance to) the next round of this task's mini-game
local function challenge(p,session)
 local m=session.model
 session.game=m:GetAttribute("Game") or "search"
 session.rounds=m:GetAttribute("Rounds") or 1
 session.round=(m:GetAttribute("Step") or 0)+1
 session.token=HttpService:GenerateGUID(false)
 session.opened=workspace:GetServerTimeNow()
 session.state={}
 local g=Games[session.game]
 local data=g.make(session.state,rng,{round=session.round,opened=session.opened,id=m:GetAttribute("TaskId"),frequency=config:GetAttribute("RescueFrequency") or "146.55"})
 remote:FireClient(p,"open",{id=m:GetAttribute("TaskId"),title=m:GetAttribute("Title"),instruction=m:GetAttribute("Instruction"),guide=m:GetAttribute("Guide"),site=m:GetAttribute("Site"),
  game=session.game,round=session.round,rounds=session.rounds,token=session.token,start=session.opened,data=data})
end
function S.Begin()
 epoch+=1 active=true count=0 maskLocked=false
 local list={} for p in sessions do table.insert(list,p) end for _,p in list do cancel(p,"NEW ROUND") end
 for _,m in folder:GetChildren() do m:SetAttribute("Done",false) m:SetAttribute("Step",0) end
 rollFrequency()
 config:SetAttribute("RescueWon",false) refresh()
end
function S.End()
 active=false epoch+=1 refresh()
end
function S.MaskDropped()
 if active then maskLocked=true refresh() end
end
function S.Open(p,m)
 if not valid(p,m) or locks[m] then return false end
 cancel(p)
 local session={model=m,epoch=epoch} sessions[p]=session locks[m]=p challenge(p,session) refresh() return true
end
function S.Act(p,token,action,payload)
 local s=sessions[p]
 if not s or s.token~=token or s.epoch~=epoch then return false end
 if not valid(p,s.model) then cancel(p) refresh() return false end
 local now=workspace:GetServerTimeNow()
 if s.lastAct and now-s.lastAct<.05 then return false end
 s.lastAct=now
 local g=Games[s.game]
 local res=g.handle(s.state,action,payload,now,s.opened)
 if not res then return false end
 if not res.done then remote:FireClient(p,"result",{ok=res.ok,msg=res.msg,extra=res.extra}) return false end
 if now-s.opened<(g.minTime or .45) then remote:FireClient(p,"result",{ok=false,msg="TOO FAST — TRY AGAIN",extra=res.extra}) return false end
 s.token=nil
 remote:FireClient(p,"result",{ok=true,roundDone=true,msg=res.msg,extra=res.extra})
 local m=s.model
 m:SetAttribute("Step",s.round)
 if s.round<s.rounds then
  task.delay(.9,function() if sessions[p]==s then challenge(p,s) end end)
 else
  m:SetAttribute("Done",true) count+=1
  Progression.Task(p,"Rescue_"..m.Name)
  task.delay(.9,function() if sessions[p]==s then cancel(p,"TASK COMPLETE") end end)
  if count>=total() then config:SetAttribute("RescueWon",true) end
  refresh()
 end
 return true
end
function S.Snapshot() return {active=active,online=online(),completed=count,locked=maskLocked,epoch=epoch} end
remote.OnServerEvent:Connect(function(p,action,token,act,payload)
 if action=="cancel" then cancel(p) refresh()
 elseif action=="act" and typeof(token)=="string" and #token<64 and typeof(act)=="string" and #act<24 then S.Act(p,token,act,payload) end
end)
for _,m in folder:GetChildren() do m.PrimaryPart.RescuePrompt.Triggered:Connect(function(p) S.Open(p,m) end) end
Lighting:GetAttributeChangedSignal("Phase"):Connect(function()
 if Lighting:GetAttribute("Phase")=="Day" then maskLocked=false end refresh()
end)
config:GetAttributeChangedSignal("MeetingActive"):Connect(refresh)
config:GetAttributeChangedSignal("MatchActive"):Connect(function() if not config:GetAttribute("MatchActive") then S.End() end end)
Players.PlayerRemoving:Connect(function(p) cancel(p) refresh() end)
task.spawn(function() while folder.Parent do
 local list={} for p,s in sessions do if not valid(p,s.model) or workspace:GetServerTimeNow()-s.opened>90 then table.insert(list,p) end end
 for _,p in list do cancel(p) end
 if #list>0 then refresh() end
 task.wait(.15)
end end)
refresh()
return S
