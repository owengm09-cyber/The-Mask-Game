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
local sessions={} local epoch=0 local count=0 local maskLocked=false local active=false
-- Among Us rule: at most this many counselors can work the same task at once (MaskSystem attribute TaskCapacity).
if config:GetAttribute("TaskCapacity")==nil then config:SetAttribute("TaskCapacity",2) end
local function capacity() return config:GetAttribute("TaskCapacity") or 2 end
local function workers(m) local n=0 for _,s in sessions do if s.model==m then n+=1 end end return n+(m:GetAttribute("ExternalWorkers") or 0) end
S.Workers=workers S.Capacity=capacity
S.RoundStarted=Instance.new("BindableEvent") S.RoundEnded=Instance.new("BindableEvent")
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
-- Killer sabotage: a wrecked station loses its progress (and its completion) and is jammed for a short while.
local function jammed(m) return (m:GetAttribute("SabotagedUntil") or 0)>workspace:GetServerTimeNow() end
local function dependencies(m)
 -- "Locked": the station is missing a part someone has to bring and fit first (Task19: RadioTowerService)
 if m:GetAttribute("Locked") then return false end
 for n in string.gmatch(m:GetAttribute("Dependencies") or "","%d+") do
 local dep=folder:FindFirstChild(string.format("Task%02d",tonumber(n)))
 if not dep or not dep:GetAttribute("Done") then return false end
 end return true
end
local function valid(p,m)
 local c=p.Character local h=c and c:FindFirstChildOfClass("Humanoid") local r=c and c:FindFirstChild("HumanoidRootPart")
 if not online() or p:GetAttribute("InRound")~=true or p:GetAttribute("HasMask") or p:GetAttribute("Role")=="Killer" or not h or h.Health<=0 or not r or (r.Position-m.PrimaryPart.Position).Magnitude>11 or m:GetAttribute("Done") or jammed(m) or not dependencies(m) then return false end
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={c,m} ray.RespectCanCollide=true
 return workspace:Raycast(r.Position,m.PrimaryPart.Position-r.Position,ray)==nil
end
local function cancel(p,reason)
 local session=sessions[p] if session then sessions[p]=nil remote:FireClient(p,"close",reason or (session.model:GetAttribute("Done") and "TASK COMPLETE") or "TASK INTERRUPTED") end
end
local function refresh()
 local on=online()
 config:SetAttribute("RescueCompleted",count) config:SetAttribute("RescueTotal",total())
 -- two task lists: camp power, and the escape van (model attribute "List"); the van runs once both are done
 local lists={Power={0,0},Van={0,0}}
 for _,m in folder:GetChildren() do local l=lists[m:GetAttribute("List") or "Power"] if l then l[2]+=1 if m:GetAttribute("Done") then l[1]+=1 end end end
 config:SetAttribute("RescuePowerDone",lists.Power[1]) config:SetAttribute("RescuePowerTotal",lists.Power[2])
 config:SetAttribute("RescueVanDone",lists.Van[1]) config:SetAttribute("RescueVanTotal",lists.Van[2])
 config:SetAttribute("RescueOnline",on)
 config:SetAttribute("RescueStatus",not active and "WAITING FOR ROUND" or config:GetAttribute("MeetingActive") and "MEETING — TASKS PAUSED" or maskLocked and "MASK RELEASED — TASKS OFFLINE" or Lighting:GetAttribute("Phase")~="Day" and "NIGHTFALL — TASKS OFFLINE" or "DAYLIGHT — RESTORE POWER AND GET THE CAMP BUS RUNNING")
 for _,m in folder:GetChildren() do
 local isJammed=jammed(m)
 local ready=on and not m:GetAttribute("Done") and not isJammed and dependencies(m)
 local n=workers(m)
 m:SetAttribute("Jammed",isJammed)
 local pr=m.PrimaryPart:FindFirstChild("RescuePrompt") if pr then pr.Enabled=ready and n<capacity() end
 m:SetAttribute("Available",ready) m:SetAttribute("Workers",n)
 local mapTask=game.ReplicatedStorage.RescueMapData.Tasks:FindFirstChild(m.Name)
 if mapTask then mapTask:SetAttribute("Available",ready) mapTask:SetAttribute("Done",m:GetAttribute("Done")) end
 local lamp=m:FindFirstChild("StatusLamp") if lamp then
  local wrecked=m:GetAttribute("Sabotaged")==true
  lamp.Color=wrecked and Color3.fromRGB(225,38,30) or m:GetAttribute("Done") and Color3.fromRGB(112,145,95) or ready and Color3.fromRGB(208,160, 70) or Color3.fromRGB(76, 30, 20)
  lamp.Material=(ready or wrecked) and Enum.Material.Neon or Enum.Material.Glass
 end
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
 for _,m in folder:GetChildren() do m:SetAttribute("Done",false) m:SetAttribute("Step",0) m:SetAttribute("Sabotaged",false) m:SetAttribute("SabotagedUntil",nil) end
 rollFrequency()
 config:SetAttribute("RescueWon",false) refresh()
 S.RoundStarted:Fire()
end
function S.End()
 active=false epoch+=1 refresh()
 S.RoundEnded:Fire()
end
function S.MaskDropped()
 if active then maskLocked=true refresh() end
end
function S.Open(p,m)
 if m:GetAttribute("External") then return false end
 if sessions[p] and sessions[p].model==m then return false end
 if not valid(p,m) or workers(m)>=capacity() then return false end
 cancel(p)
 local session={model=m,epoch=epoch} sessions[p]=session challenge(p,session) refresh() return true
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
  m:SetAttribute("Done",true) m:SetAttribute("Sabotaged",false) count+=1
  Progression.Task(p,"Rescue_"..m.Name)
  task.delay(.9,function() if sessions[p]==s then cancel(p,"TASK COMPLETE") end end)
  if count>=total() then config:SetAttribute("RescueWon",true) end
  refresh()
 end
 return true
end
function S.Snapshot() return {active=active,online=online(),completed=count,locked=maskLocked,epoch=epoch} end
-- Tasks that run their own world mini-game (Task17 graveyard) use these instead of the station window.
S.Online=online
function S.CanWork(p,m)
 local c=p.Character local h=c and c:FindFirstChildOfClass("Humanoid")
 return online() and p:GetAttribute("InRound")==true and not p:GetAttribute("HasMask") and p:GetAttribute("Role")~="Killer"
  and h~=nil and h.Health>0 and not m:GetAttribute("Done") and dependencies(m)
end
function S.CompleteExternal(p,m)
 if not S.CanWork(p,m) then return false end
 m:SetAttribute("Step",m:GetAttribute("Rounds") or 1) m:SetAttribute("Done",true) count+=1
 Progression.Task(p,"Rescue_"..m.Name)
 if count>=total() then config:SetAttribute("RescueWon",true) end
 refresh() return true
end
S.Refresh=function() refresh() end
S.Jammed=jammed
-- Called by KillerAbilities. Returns ok, wasDone.
function S.Sabotage(m,jamSeconds)
 if not online() or m.Parent~=folder or m:GetAttribute("Sabotageable")~=true or m:GetAttribute("External") or jammed(m) then return false end
 local wasDone=m:GetAttribute("Done")==true
 if wasDone then m:SetAttribute("Done",false) count=math.max(0,count-1) config:SetAttribute("RescueWon",false) end
 m:SetAttribute("Step",0)
 m:SetAttribute("Sabotaged",true)
 m:SetAttribute("SabotagedUntil",workspace:GetServerTimeNow()+(jamSeconds or 20))
 local list={} for p,s in sessions do if s.model==m then table.insert(list,p) end end
 for _,p in list do cancel(p,"SABOTAGED — SOMEONE WRECKED THE STATION") end
 refresh()
 return true,wasDone
end
remote.OnServerEvent:Connect(function(p,action,token,act,payload)
 if action=="cancel" then cancel(p) refresh()
 elseif action=="act" and typeof(token)=="string" and #token<64 and typeof(act)=="string" and #act<24 then S.Act(p,token,act,payload) end
end)
for _,m in folder:GetChildren() do local pr=m.PrimaryPart:FindFirstChild("RescuePrompt") if pr then pr.Triggered:Connect(function(p) S.Open(p,m) end) end end
config:GetAttributeChangedSignal("TaskCapacity"):Connect(refresh)
Lighting:GetAttributeChangedSignal("Phase"):Connect(function()
 if Lighting:GetAttribute("Phase")=="Day" then maskLocked=false end refresh()
end)
config:GetAttributeChangedSignal("MeetingActive"):Connect(refresh)
config:GetAttributeChangedSignal("MatchActive"):Connect(function() if not config:GetAttribute("MatchActive") then S.End() end end)
Players.PlayerRemoving:Connect(function(p) cancel(p) refresh() end)
task.spawn(function() while folder.Parent do
 local list={} for p,s in sessions do if not valid(p,s.model) or workspace:GetServerTimeNow()-s.opened>90 then table.insert(list,p) end end
 for _,p in list do cancel(p) end
 local unjam=false
 for _,m in folder:GetChildren() do if m:GetAttribute("Jammed") and not jammed(m) then unjam=true end end
 if #list>0 or unjam then refresh() end
 task.wait(.15)
end end)
refresh()
return S
