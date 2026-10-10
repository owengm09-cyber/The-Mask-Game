local Q={}
-- One killer plus up to nine survivors.
Q.MAX_PLAYERS=10
-- Seconds a launch may be held for players who are connected but still loading (counted from the first arrival).
Q.ARRIVAL_WINDOW=12
function Q.new()
 return {members={},deadline=nil}
end
-- cap = how many players this zone needs (the zone's Capacity attribute)
function Q.step(state,candidates,now,busy,cap)
 cap=cap or 6
 local present={} for _,p in candidates do present[p]=true end
 local members={} local selected={} local changed=false
 for _,p in state.members do
  if present[p] and #members<cap then table.insert(members,p) selected[p]=true else changed=true end
 end
 for _,p in candidates do
  if not selected[p] and #members<cap then table.insert(members,p) selected[p]=true changed=true end
 end
 state.members=members
 if busy or #members<cap or changed then state.deadline=nil end
 if #members==cap and not busy and not state.deadline then state.deadline=now+10 end
 local remaining=state.deadline and math.max(0,math.ceil(state.deadline-now)) or nil
 local launch
 if remaining==0 then launch=table.clone(members) state.members={} state.deadline=nil end
 return #members,remaining,launch
end
-- Arrival-queue planner for ReadyQueueServer. Pure (no Roblox types) so it can be tested in a bare Luau VM.
-- entries: array of {id=any, ready=boolean (character loaded), arrivedAt=number, tie=number}
-- Returns the ids to launch (earliest arrivals first, at most maxPlayers) or nil to keep waiting,
-- plus how many entries are still loading. Everyone not returned stays queued for a later round.
function Q.planLaunch(entries,now,firstAt,expected,maxPlayers,window)
 maxPlayers=math.max(1,maxPlayers or Q.MAX_PLAYERS)
 window=window or Q.ARRIVAL_WINDOW
 local ready,loading={},0
 for _,e in entries do
  if e.ready then table.insert(ready,e) else loading+=1 end
 end
 if #ready==0 or not firstAt then return nil,loading end
 local complete=loading==0 and #ready>=math.min(math.max(1,expected or 1),maxPlayers)
 if not complete and now-firstAt<window then return nil,loading end
 table.sort(ready,function(a,b)
  if a.arrivedAt~=b.arrivedAt then return a.arrivedAt<b.arrivedAt end
  return a.tie<b.tie
 end)
 local batch={}
 for i=1,math.min(#ready,maxPlayers) do batch[i]=ready[i].id end
 return batch,loading
end
-- After a launch, drop only the launched players from the queue (arrivals: {[id]=arrivedAt}); anyone still loading
-- or over the cap stays queued. Returns the new first-arrival time: now if others are waiting, nil if the queue is empty.
function Q.settle(arrivals,batch,now)
 for _,id in batch do arrivals[id]=nil end
 return next(arrivals) and now or nil
end
-- Development-only round telemetry (pure state machine; ReadyQueueServer feeds it snapshots and prints the summary).
-- It stores nothing and touches no player data. Times are seconds since the round began.
local function round1(x) return x and math.floor(x*10+0.5)/10 or nil end
function Q.telemetryNew(startedAt,players,roundId)
 return {round=roundId,startedAt=startedAt,players=players,killers={},killerCount=0,deaths=0,deathsWhileMasked=0,
  killerDeaths=0,meetings=0,wasMeeting=false,escaped=0}
end
-- snap: {phase, killerUserId, rescueDone, rescueTotal, rescueWon, vanState, vanEscaped, meeting}
function Q.telemetrySample(tm,now,snap)
 local t=now-tm.startedAt
 if snap.phase=="Night" and not tm.firstNightAt then tm.firstNightAt=t end
 local killer=snap.killerUserId or 0
 if killer~=0 then
  if not tm.firstKillerAt then tm.firstKillerAt=t end
  if not tm.killers[killer] then tm.killers[killer]=true tm.killerCount+=1 end
 end
 local done,total=snap.rescueDone or 0,snap.rescueTotal or 0
 tm.tasksDone=done tm.tasksTotal=total
 if done>=1 and not tm.firstTaskAt then tm.firstTaskAt=t end
 if total>0 and done*2>=total and not tm.halfTasksAt then tm.halfTasksAt=t end
 if snap.rescueWon and not tm.allTasksAt then tm.allTasksAt=t end
 if snap.vanState=="Running" and not tm.busAt then tm.busAt=t end
 tm.escaped=math.max(tm.escaped,snap.vanEscaped or 0)
 local meeting=snap.meeting==true
 if meeting and not tm.wasMeeting then tm.meetings+=1 end
 tm.wasMeeting=meeting
end
-- a player in the round died (snap: {killerUserId, victimUserId, phase})
function Q.telemetryDeath(tm,now,snap)
 local t=now-tm.startedAt
 tm.deaths+=1
 if not tm.firstDeathAt then tm.firstDeathAt=t end
 local killer=snap.killerUserId or 0
 if killer~=0 and snap.victimUserId==killer then tm.killerDeaths+=1
 elseif killer~=0 then tm.deathsWhileMasked+=1 end
end
function Q.telemetrySummary(tm,now,winner,innocentsAlive)
 return {round=tm.round,players=tm.players,winner=winner or "none",duration=round1(now-tm.startedAt),
  firstNightAt=round1(tm.firstNightAt),firstMaskWornAt=round1(tm.firstKillerAt),killersSeen=tm.killerCount,
  firstDeathAt=round1(tm.firstDeathAt),deaths=tm.deaths,deathsWhileMasked=tm.deathsWhileMasked,killerDeaths=tm.killerDeaths,
  firstTaskAt=round1(tm.firstTaskAt),halfTasksAt=round1(tm.halfTasksAt),allTasksAt=round1(tm.allTasksAt),
  tasksDone=tm.tasksDone or 0,tasksTotal=tm.tasksTotal or 0,busAt=round1(tm.busAt),escaped=tm.escaped,
  meetings=tm.meetings,innocentsAlive=innocentsAlive or 0}
end
return Q
