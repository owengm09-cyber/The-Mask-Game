-- Run by tests/test_bandage_authority.py: the shipped Bandage server script is wrapped as `run(script, os, game, workspace)`.
local failures = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then print("ok   " .. name) else failures += 1 print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn) table.insert(self.handlers, fn) return { Disconnect = function() end } end
	function s:fire(...) for _, h in self.handlers do h(...) end end
	return s
end
-- one bandage held by one player; `now` is the fake clock
local function setup(opts)
	opts = opts or {}
	local now = 0
	local humanoid = { Health = opts.health or 40, MaxHealth = 100 }
	local character = {}
	function character:FindFirstChildOfClass() return humanoid end
	local player = { Character = character }
	local played = 0
	local tool = { Activated = signal(), Deactivated = signal(), Unequipped = signal(), Use = { OnServerEvent = signal() }, destroyed = false }
	tool.Parent = opts.holding == false and {} or character
	tool.Handle = { Clone = function() return { Used = { Play = function() played += 1 end } } end }
	function tool:Destroy() self.destroyed = true end
	local fakeOs = { clock = function() return now end }
	run({ Parent = tool }, fakeOs, { Debris = { AddItem = function() end } }, {})
	return {
		tool = tool, player = player, humanoid = humanoid, character = character,
		advance = function(s) now += s end,
		use = function(...) tool.Use.OnServerEvent:fire(player, ...) end,
		played = function() return played end,
	}
end

test("a normal use heals the fixed amount and consumes the bandage", function()
	local t = setup()
	t.tool.Activated:fire() t.advance(3.3) t.use(35)
	assert(t.humanoid.Health == 75 and t.tool.destroyed and t.played() == 1)
end)

test("the client cannot choose the heal amount", function()
	local t = setup()
	t.tool.Activated:fire() t.advance(3.3) t.use(1e9)
	assert(t.humanoid.Health == 75, "got " .. t.humanoid.Health)
	local u = setup({ health = 90 })
	u.tool.Activated:fire() u.advance(3.3) u.use(-1000)
	assert(u.humanoid.Health == 100, "heal is capped at max health, got " .. u.humanoid.Health)
end)

test("no heal without holding the use button", function()
	local t = setup()
	t.use(35)
	assert(t.humanoid.Health == 40 and not t.tool.destroyed)
end)

test("firing the remote immediately after clicking is rejected", function()
	local t = setup()
	t.tool.Activated:fire() t.advance(0.5) t.use(35)
	assert(t.humanoid.Health == 40 and not t.tool.destroyed)
end)

test("releasing the button or unequipping cancels the use", function()
	local t = setup()
	t.tool.Activated:fire() t.advance(1) t.tool.Deactivated:fire() t.advance(5) t.use(35)
	assert(t.humanoid.Health == 40)
	local u = setup()
	u.tool.Activated:fire() u.advance(1) u.tool.Unequipped:fire() u.advance(5) u.use(35)
	assert(u.humanoid.Health == 40)
end)

test("a bandage that is not in the sender's hands cannot be used", function()
	local t = setup({ holding = false })
	t.tool.Activated:fire() t.advance(3.3) t.use(35)
	assert(t.humanoid.Health == 40 and not t.tool.destroyed)
end)

test("a dead player cannot use it, and it works only once", function()
	local t = setup({ health = 0 })
	t.tool.Activated:fire() t.advance(3.3) t.use(35)
	assert(t.humanoid.Health == 0 and not t.tool.destroyed)
	local u = setup()
	u.tool.Activated:fire() u.advance(3.3) u.use(35) u.humanoid.Health = 40 u.use(35)
	assert(u.humanoid.Health == 40, "second use must do nothing")
end)

if failures > 0 then error(failures .. " Luau test(s) failed") end
print("all bandage tests passed")
