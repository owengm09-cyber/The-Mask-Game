-- Run by tests/test_hud_text.py with the ForestClock source bound to the local `C`.
local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then print("ok   " .. name) else failures += 1 print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function utf8len(s) return utf8.len(s) end

test("existing clock behaviour is unchanged", function()
	assert(C.StartHour == 8 and C.CycleSeconds == 1440)
	assert(C.Phase(8) == "Day" and C.Phase(19) == "Night" and C.Phase(5.9) == "Night")
	assert(C.Format(13.5) == "1:30 PM")
end)

test("an eliminated player sees who is left and how the escape plan stands", function()
	assert(C.SideRole("Eliminated") == "ELIMINATED")
	assert(C.SideLine("Eliminated", true, "Playing", 3, 7, 19, nil) == "3 LEFT • PLAN 7/19")
	assert(C.SideLine("Eliminated", true, "Playing", 1, 19, 19, "Running") == "1 LEFT • BUS IS HERE")
	assert(C.SideLine("Eliminated", true, "Playing", 0, 19, 19, "Gone") == "0 LEFT • BUS HAS GONE")
end)

test("an escaped player is told to wait for the bus", function()
	assert(C.SideRole("Escaped") == "ESCAPED")
	assert(C.SideLine("Escaped", true, "Playing", 5, 19, 19, "Running") == "WAIT FOR THE BUS")
end)

test("players not in a trial get an honest status, never the old ready-zone text", function()
	assert(C.SideRole(nil) == "LOBBY")
	assert(C.SideLine(nil, true, "Playing", 4, 0, 19, nil) == "JOINING NEXT TRIAL")
	assert(C.SideLine(nil, false, "Picking", 0, 0, 19, nil) == "TRIAL STARTING")
	assert(C.SideLine(nil, false, "Lobby", 0, 0, 19, nil) == "WAITING FOR PLAYERS")
end)

test("every line fits the 175 px label (about 24 characters at size 15)", function()
	local lines = {
		C.SideLine("Eliminated", true, "Playing", 9, 19, 19, nil), C.SideLine("Eliminated", true, "Playing", 9, 19, 19, "Running"),
		C.SideLine("Eliminated", true, "Playing", 9, 19, 19, "Gone"), C.SideLine("Escaped"), C.SideLine(nil, true), C.SideLine(nil, false, "Picking"), C.SideLine(nil, false, "Lobby"),
	}
	for _, line in lines do assert(utf8len(line) <= 24, line .. " is " .. utf8len(line)) end
end)

if failures > 0 then error(failures .. " Luau test(s) failed") end
print("all ForestClock tests passed")
