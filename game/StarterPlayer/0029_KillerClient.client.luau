-- KillerAbilities on the client.
--   Killer only: "Sabotage" prompts on stations, "Tear down" on the radio tower ladder, and "Push" prompts on
--   survivors standing at a kill spot (the well, the radio tower platform).
--   They are created here, on the killer's own machine, so no other player can ever see them. Key F / gamepad Y.
--   Everyone: sabotage alerts, and the camera that leans over the well when you look down it.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Tags = game:GetService("CollectionService")
local p = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("KillerAction")
local tasks = workspace:WaitForChild("ForestRescueTasks")
local config = workspace:WaitForChild("MaskSystem")

local PAPER = Color3.fromRGB(232, 229, 218)
local ALERT = Color3.fromRGB(235, 70, 60)
local cooldown = { sabotage = 0, push = 0 }
local function now() return workspace:GetServerTimeNow() end

---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "KillerHUD" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true gui.DisplayOrder = 57
gui.Parent = p:WaitForChild("PlayerGui")
local alert = Instance.new("TextLabel")
alert.Name = "Alert" alert.AnchorPoint = Vector2.new(0.5, 0) alert.Position = UDim2.new(0.5, 0, 0, 182)
alert.Size = UDim2.fromOffset(620, 30) alert.BackgroundTransparency = 1 alert.Font = Enum.Font.Oswald alert.TextSize = 21
alert.TextColor3 = ALERT alert.TextStrokeTransparency = 0.4 alert.TextTransparency = 1 alert.TextStrokeColor3 = Color3.new(0, 0, 0)
alert.TextWrapped = true alert.Text = "" alert.Parent = gui
local alertToken = 0
local function showAlert(msg, colour, seconds)
	if not msg or msg == "" then return end
	alertToken += 1
	local token = alertToken
	alert.Text = msg alert.TextColor3 = colour or ALERT
	alert.TextTransparency = 0 alert.TextStrokeTransparency = 0.4
	task.delay(seconds or 4.5, function()
		if token == alertToken then TweenService:Create(alert, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play() end
	end)
end
-- the killer's own cooldown readout (only ever shown on the killer's screen)
local status = Instance.new("TextLabel")
status.Name = "KillerCooldowns" status.AnchorPoint = Vector2.new(1, 1) status.Position = UDim2.new(1, -18, 1, -74)
status.Size = UDim2.fromOffset(240, 40) status.BackgroundTransparency = 1 status.Font = Enum.Font.Oswald status.TextSize = 14
status.TextColor3 = Color3.fromRGB(205, 70, 60) status.TextXAlignment = Enum.TextXAlignment.Right status.TextYAlignment = Enum.TextYAlignment.Bottom
status.TextStrokeTransparency = 0.5 status.Visible = false status.Parent = gui

---------------------------------------------------------------- killer prompts
local function isKiller() return p:GetAttribute("Role") == "Killer" and p:GetAttribute("InRound") == true end
local function myRoot() local c = p.Character return c and c:FindFirstChild("HumanoidRootPart") end
local sabotagePrompts = {} -- [taskModel] = prompt
local pushPrompts = {} -- [player] = prompt
local function makePrompt(parent, action, object, hold, range, los)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "KillerPrompt" pr.ActionText = action pr.ObjectText = object
	pr.KeyboardKeyCode = Enum.KeyCode.F pr.GamepadKeyCode = Enum.KeyCode.ButtonY
	pr.HoldDuration = hold pr.MaxActivationDistance = range pr.RequiresLineOfSight = los
	pr.UIOffset = Vector2.new(0, 72) -- sits under the normal task prompt instead of on top of it
	pr.Parent = parent
	return pr
end
local ladderPrompt = nil
local function clearPrompts()
	for m, pr in sabotagePrompts do pr:Destroy() sabotagePrompts[m] = nil end
	for q, pr in pushPrompts do pr:Destroy() pushPrompts[q] = nil end
	if ladderPrompt then ladderPrompt:Destroy() ladderPrompt = nil end
end
local function inZone(pos)
	for _, z in Tags:GetTagged("KillSpot") do
		if z:IsA("BasePart") and (Vector2.new(pos.X, pos.Z) - Vector2.new(z.Position.X, z.Position.Z)).Magnitude <= (z:GetAttribute("Radius") or 6)
			and math.abs(pos.Y - z.Position.Y) < 8 then return z end
	end
end
local function refreshKiller()
	if not isKiller() then
		clearPrompts()
		status.Visible = false
		return
	end
	local day = Lighting:GetAttribute("Phase") == "Day"
	local meeting = config:GetAttribute("MeetingActive") == true
	local c = p.Character
	local creature = c and c:FindFirstChild("MaskCreature")
	local t = now()
	-- sabotage
	for _, m in tasks:GetChildren() do
		if m:GetAttribute("Sabotageable") == true and m.PrimaryPart then
			local pr = sabotagePrompts[m]
			if not pr or not pr.Parent then
				pr = makePrompt(m.PrimaryPart, "Sabotage", m:GetAttribute("Title") or "Station", 1.2, 8, false)
				pr.Triggered:Connect(function() remote:FireServer("sabotage", m) end)
				sabotagePrompts[m] = pr
			end
			pr.Enabled = day and not meeting and not creature and t >= cooldown.sabotage and not m:GetAttribute("Jammed")
		end
	end
	-- the radio tower ladder: tear it down (twice a match)
	local tower = workspace:FindFirstChild("RadioTower")
	local ladder = tower and tower:FindFirstChild("Ladder")
	local base = ladder and ladder:FindFirstChild("LadderBase")
	local wrecksLeft = ladder and ladder:GetAttribute("WrecksLeft") or 0
	if base then
		if not ladderPrompt or ladderPrompt.Parent ~= base then
			if ladderPrompt then ladderPrompt:Destroy() end
			ladderPrompt = makePrompt(base, "Tear down", "Radio tower ladder", 1.5, 9, false)
			ladderPrompt.Triggered:Connect(function() remote:FireServer("ladder") end)
		end
		ladderPrompt.Enabled = day and not meeting and not creature and t >= cooldown.sabotage and wrecksLeft > 0 and ladder:GetAttribute("Wrecked") ~= true
	end
	-- push: anyone standing at a kill spot near you
	local root = myRoot()
	for _, q in Players:GetPlayers() do
		local qc = q.Character
		local qr = qc and qc:FindFirstChild("HumanoidRootPart")
		local qh = qc and qc:FindFirstChildOfClass("Humanoid")
		local zone = qr and inZone(qr.Position)
		-- off the tower only from the platform itself, and not while they're climbing down
		if zone and zone:GetAttribute("Kind") == "Tower" and (qr.Position.Y < (zone:GetAttribute("DeckY") or zone.Position.Y) + 1 or qc:GetAttribute("OnLadder")) then zone = nil end
		local want = q ~= p and root and qr and qh and qh.Health > 0 and q:GetAttribute("InRound") == true
			and (qr.Position - root.Position).Magnitude < 9 and zone ~= nil
		local pr = pushPrompts[q]
		if want then
			if not pr or pr.Parent ~= qr then
				if pr then pr:Destroy() end
				pr = makePrompt(qr, "Push", "Down the well", 0.15, config:GetAttribute("PushRange") or 6.5, false) -- the server checks line of sight
				pr.UIOffset = Vector2.new(0, 0)
				local target = q
				pr.Triggered:Connect(function() remote:FireServer("push", target) end)
				pushPrompts[q] = pr
			end
			pr.ObjectText = zone:GetAttribute("PushText") or "Down the well"
			pr.Enabled = not meeting and not creature and t >= cooldown.push
		elseif pr then
			pr:Destroy()
			pushPrompts[q] = nil
		end
	end
	local function line(name, at, extra)
		local left = math.ceil(at - t)
		return name .. (left > 0 and ("  " .. left .. "s") or (extra or "  READY"))
	end
	status.Visible = true
	status.Size = UDim2.fromOffset(240, 58)
	status.Text = line("SABOTAGE", cooldown.sabotage, not day and "  DAYTIME ONLY" or nil) .. "\n" .. line("PUSH", cooldown.push)
		.. "\nTOWER LADDER  " .. wrecksLeft .. " LEFT"
end
Players.PlayerRemoving:Connect(function(q) local pr = pushPrompts[q] if pr then pr:Destroy() pushPrompts[q] = nil end end)

---------------------------------------------------------------- looking down the well
local peek
local function endPeek(result)
	local cam = workspace.CurrentCamera
	if peek then
		if peek.tween then peek.tween:Cancel() end
		if peek.died then peek.died:Disconnect() end
		if peek.hide then peek.hide:Disconnect() end
		for part in peek.hidden do if part.Parent then part.LocalTransparencyModifier = 0 end end
		cam.CameraType = peek.cameraType
		cam.FieldOfView = peek.fov
		peek = nil
	end
	if result then showAlert(result, PAPER, 4) end
end
local function startPeek(data)
	local cam = workspace.CurrentCamera
	local root = myRoot()
	if not root then return end
	if peek then endPeek(nil) end
	peek = { cameraType = cam.CameraType, fov = cam.FieldOfView, hidden = {} }
	local h = p.Character:FindFirstChildOfClass("Humanoid")
	if h then peek.died = h.Died:Connect(function() endPeek(nil) end) end
	-- you're leaning over the rim: your own body would fill the view, so hide it from yourself (like first person)
	local state = peek
	local function hideAll()
		for _, d in p.Character:GetDescendants() do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1 state.hidden[d] = true end
		end
	end
	hideAll()
	peek.hide = game:GetService("RunService").RenderStepped:Connect(function() if peek == state then hideAll() end end)
	local centre = data.centre
	local dir = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
	local eye = Vector3.new(centre.X, data.rimHeight + 1.3, centre.Z) + dir * (data.rim - 1.1)
	local target = data.bottom + Vector3.new(0, 0.8, 0) - dir * 0.6
	cam.CameraType = Enum.CameraType.Scriptable
	peek.tween = TweenService:Create(cam, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(eye, target), FieldOfView = 52 })
	peek.tween:Play()
end

---------------------------------------------------------------- server messages
remote.OnClientEvent:Connect(function(action, data)
	if action == "alert" then showAlert(data, ALERT, 5)
	elseif action == "cooldowns" then cooldown = data
	elseif action == "peek" then startPeek(data)
	elseif action == "peekEnd" then endPeek(data) gui:SetAttribute("LastPeekResult", data or "")
	end
end)
p:GetAttributeChangedSignal("Role"):Connect(function() if isKiller() then remote:FireServer("hello") end refreshKiller() end)
if isKiller() then remote:FireServer("hello") end
task.spawn(function()
	while gui.Parent do
		refreshKiller()
		task.wait(0.2)
	end
end)
