local Q={}
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
return Q
