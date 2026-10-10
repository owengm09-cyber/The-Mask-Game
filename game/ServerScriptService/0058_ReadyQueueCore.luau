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
return Q
