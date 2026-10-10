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

test("zone queue behaviour is unchanged",function()
 local state=Q.new()
 local count,remaining,launch=Q.step(state,{"a","b"},0,false,2)
 assert(count==2 and remaining==10 and launch==nil)
 count,remaining,launch=Q.step(state,{"a","b"},10,false,2)
 assert(remaining==0 and launch and #launch==2)
end)

if failures>0 then error(failures.." Luau test(s) failed") end
print("all ReadyQueueCore tests passed")
