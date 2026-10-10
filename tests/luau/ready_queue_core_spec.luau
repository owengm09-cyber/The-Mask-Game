-- Run by tests/test_ready_queue_core.py with the ReadyQueueCore source bound to the local `Q`.
local function entry(id,ready,arrivedAt,tie) return {id=id,ready=ready,arrivedAt=arrivedAt or 0,tie=tie or id} end
local function ids(list) return table.concat(list,",") end
local function many(n,ready,from) local t={} for i=1,n do table.insert(t,entry((from or 0)+i,ready,i)) end return t end
local failures=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then print("ok   "..name) else failures+=1 print("FAIL "..name..": "..tostring(err)) end
end

test("match size is one killer plus nine survivors",function()
 assert(Q.MAX_PLAYERS==10)
end)

test("a lone ready player starts at once when one is expected",function()
 local batch=Q.planLaunch({entry(1,true)},100,100,1,10,12)
 assert(batch and ids(batch)=="1")
end)

test("waits for a player who is connected but still loading",function()
 local batch,loading=Q.planLaunch({entry(1,true),entry(2,false)},105,100,1,10,12)
 assert(batch==nil and loading==1)
end)

test("launches without the loader once the arrival window runs out",function()
 local batch,loading=Q.planLaunch({entry(1,true),entry(2,false)},112,100,1,10,12)
 assert(batch and ids(batch)=="1" and loading==1)
end)

test("holds a ten player group until everyone is ready, then starts immediately",function()
 local entries=many(9,true)
 table.insert(entries,entry(10,false,10))
 assert(Q.planLaunch(entries,101,100,10,10,12)==nil)
 entries[10].ready=true
 local batch=Q.planLaunch(entries,101,100,10,10,12)
 assert(batch and #batch==10)
end)

test("a lobby promising eleven cannot hold the launch past ten",function()
 local batch=Q.planLaunch(many(10,true),101,100,11,10,12)
 assert(batch and #batch==10)
end)

test("never launches more than the cap; earliest arrivals win",function()
 local batch=Q.planLaunch(many(12,true),100,100,1,10,12)
 assert(batch and #batch==10 and ids(batch)=="1,2,3,4,5,6,7,8,9,10")
end)

test("arrival time beats user id; user id breaks ties",function()
 local batch=Q.planLaunch({entry("late",true,5,1),entry("early",true,1,99),entry("tieB",true,3,8),entry("tieA",true,3,7)},100,100,4,10,12)
 assert(batch and ids(batch)=="early,tieA,tieB,late")
end)

test("nothing ready, or no first arrival, means no launch",function()
 assert(Q.planLaunch({entry(1,false)},200,100,1,10,12)==nil)
 assert(Q.planLaunch({},200,100,1,10,12)==nil)
 assert(Q.planLaunch({entry(1,true)},200,nil,1,10,12)==nil)
end)

test("a zero cap still launches one player",function()
 local batch=Q.planLaunch(many(3,true),100,100,1,0,12)
 assert(batch and #batch==1)
end)

test("launch leaves overflow and loaders queued instead of wiping them",function()
 local arrivals={}
 for i=1,12 do arrivals[i]=i end
 arrivals[13]=13 -- still loading, so not in the planned batch
 local entries={}
 for id,at in pairs(arrivals) do table.insert(entries,entry(id,id~=13,at)) end
 local batch=Q.planLaunch(entries,100,100,1,10,12)
 assert(batch==nil,"holds for the loader inside the arrival window")
 batch=Q.planLaunch(entries,112,100,1,10,12)
 assert(batch and #batch==10)
 local firstAt=Q.settle(arrivals,batch,112)
 assert(firstAt==112,"leftovers get a fresh first-arrival time")
 assert(arrivals[11] and arrivals[12] and arrivals[13] and not arrivals[1])
 -- the next round collects them, including the one that finished loading meanwhile
 local nextEntries={}
 for id,at in pairs(arrivals) do table.insert(nextEntries,entry(id,true,at)) end
 local second=Q.planLaunch(nextEntries,300,firstAt,1,10,12)
 assert(second and ids(second)=="11,12,13")
 assert(Q.settle(arrivals,second,300)==nil and next(arrivals)==nil)
end)

test("an emptied queue clears its first-arrival time",function()
 local arrivals={a=1}
 assert(Q.settle(arrivals,{"a"},50)==nil)
end)

test("telemetry records milestone times once and the winner",function()
 local tm=Q.telemetryNew(1000,9,7)
 local snap={phase="Day",killerUserId=0,rescueDone=0,rescueTotal=19,rescueWon=false,vanState=nil,vanEscaped=0,meeting=false}
 Q.telemetrySample(tm,1010,snap)
 snap.rescueDone=1 Q.telemetrySample(tm,1060,snap)
 snap.rescueDone=10 Q.telemetrySample(tm,1200,snap)
 snap.rescueDone=19 snap.rescueWon=true snap.vanState="Running" Q.telemetrySample(tm,1500,snap)
 snap.rescueDone=19 Q.telemetrySample(tm,1600,snap) -- later samples must not move earlier milestones
 snap.phase="Night" snap.killerUserId=42 Q.telemetrySample(tm,1660,snap)
 snap.vanEscaped=3 Q.telemetrySample(tm,1700,snap)
 local s=Q.telemetrySummary(tm,1710,"Innocents",4)
 assert(s.round==7 and s.players==9 and s.winner=="Innocents" and s.duration==710)
 assert(s.firstTaskAt==60 and s.halfTasksAt==200 and s.allTasksAt==500 and s.busAt==500)
 assert(s.firstNightAt==660 and s.firstMaskWornAt==660 and s.killersSeen==1)
 assert(s.tasksDone==19 and s.tasksTotal==19 and s.escaped==3 and s.innocentsAlive==4)
end)

test("telemetry separates deaths with and without a mask holder, and the killer's own death",function()
 local tm=Q.telemetryNew(0,5,1)
 Q.telemetryDeath(tm,30,{killerUserId=0,victimUserId=1})   -- before any mask
 Q.telemetryDeath(tm,700,{killerUserId=9,victimUserId=2})  -- killed while the mask is worn
 Q.telemetryDeath(tm,720,{killerUserId=9,victimUserId=9})  -- the killer dies
 local s=Q.telemetrySummary(tm,800,"Monster",0)
 assert(s.deaths==3 and s.firstDeathAt==30 and s.deathsWhileMasked==1 and s.killerDeaths==1)
end)

test("telemetry counts each contiguous meeting once and tracks several killers",function()
 local tm=Q.telemetryNew(0,4,1)
 for _,m in {false,true,true,false,true} do Q.telemetrySample(tm,1,{meeting=m}) end
 Q.telemetrySample(tm,2,{killerUserId=5}) Q.telemetrySample(tm,3,{killerUserId=6}) Q.telemetrySample(tm,4,{killerUserId=5})
 local s=Q.telemetrySummary(tm,10,nil,2)
 assert(s.meetings==2 and s.killersSeen==2 and s.winner=="none")
end)

test("a round with no mask and no tasks reports missing milestones as absent",function()
 local tm=Q.telemetryNew(0,2,1)
 Q.telemetrySample(tm,5,{phase="Day"})
 local s=Q.telemetrySummary(tm,6,"Monster",1)
 assert(s.firstNightAt==nil and s.firstMaskWornAt==nil and s.allTasksAt==nil and s.busAt==nil and s.killersSeen==0)
end)

test("zone queue behaviour is unchanged",function()
 local state=Q.new()
 local count,remaining,launch=Q.step(state,{"a","b"},0,false,2)
 assert(count==2 and remaining==10 and launch==nil)
 count,remaining,launch=Q.step(state,{"a","b"},10,false,2)
 assert(remaining==0 and launch and #launch==2)
end)

if failures>0 then error(failures.." Luau test(s) failed") end
print("all ReadyQueueCore tests passed")
