local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local folder = workspace:WaitForChild("ForestRescueTasks")

local GOLD = Color3.fromRGB(243, 193, 108)
local GREEN = Color3.fromRGB(148, 218, 155)
local componentNames = {
    [1] = {"DentedFuelCan"}, [2] = {"DentedFuelCan"},
    [3] = {"CeramicFuse"}, [4] = {"ExposedWire"},
    [5] = {"Instrument"}, [6] = {"Instrument"},
    [7] = {"ValveWheel", "ValveSpoke"},
    [8] = {"HeavyRadioBattery"}, [9] = {"HeavyRadioBattery", "CorrodedTerminal"},
    [10] = {"RadioAntenna", "ExposedWire"},
    [11] = {"ValveWheel", "ValveSpoke"},
    [12] = {"FadedLogbookPages", "RangerLogbook"},
    [13] = {"RadioAntenna", "RadioHousing"},
    [14] = {"ExposedWire"}, [15] = {"RadioAntenna", "RadioHousing"},
}
local actionNames = {
    [1] = "Search fuel", [2] = "Fill generator", [3] = "Fit fuses",
    [4] = "Connect wires", [5] = "Start generator", [6] = "Clear intake",
    [7] = "Turn valves", [8] = "Find battery", [9] = "Charge battery",
    [10] = "Repair radio", [11] = "Align antenna", [12] = "Read logbook",
    [13] = "Tune radio", [14] = "Repair beacon", [15] = "Send distress call",
}

local function tween(part, duration, goal)
    if not part or not part.Parent then return end
    TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function makeTag(model)
    local gui = Instance.new("BillboardGui")
    gui.Name = "RescueTaskMarker"
    gui.Adornee = model.PrimaryPart
    gui.AlwaysOnTop = true
    gui.MaxDistance = 26
    gui.Size = UDim2.fromOffset(230, 52)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
    gui.Parent = model.PrimaryPart
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundColor3 = Color3.fromRGB(17, 21, 19)
    label.BackgroundTransparency = .2
    label.BorderSizePixel = 0
    label.TextColor3 = GOLD
    label.TextStrokeTransparency = .65
    label.Font = Enum.Font.Oswald
    label.TextSize = 17
    label.TextWrapped = true
    label.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = label
    return gui, label
end

local function pulse(model)
    local anchor = Instance.new("Attachment")
    anchor.Name = "RepairBurst"
    anchor.Parent = model.PrimaryPart
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "RepairSparks"
    particles.Enabled = false
    particles.Rate = 0
    particles.Lifetime = NumberRange.new(.35, .8)
    particles.Speed = NumberRange.new(3, 6)
    particles.SpreadAngle = Vector2.new(80, 80)
    particles.RotSpeed = NumberRange.new(-130, 130)
    particles.LightEmission = .8
    particles.Color = ColorSequence.new(GOLD, GREEN)
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, .16),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Parent = anchor
    particles:Emit(28)
    local light = Instance.new("PointLight")
    light.Color = GREEN
    light.Brightness = 0
    light.Range = 13
    light.Parent = anchor
    tween(light, .25, {Brightness = 3.2})
    task.delay(.4, function()
        if light.Parent then tween(light, .8, {Brightness = 0}) end
    end)
    Debris:AddItem(anchor, 2)
end

local function setup(model)
    local id = model:GetAttribute("TaskId")
    if not id or not model.PrimaryPart then return end
    local prompt = model.PrimaryPart:FindFirstChild("RescuePrompt")
    if prompt then
        prompt.ObjectText = model:GetAttribute("Title") or "Camp task"
        prompt.ActionText = actionNames[id] or "Repair"
        prompt.HoldDuration = .25
    end

    local selected = {}
    local originals = {}
    for _, name in componentNames[id] or {"Instrument"} do
        for _, part in model:GetChildren() do
            if part:IsA("BasePart") and part.Name == name then
                table.insert(selected, part)
                originals[part] = {CFrame = part.CFrame, Size = part.Size,
                    Color = part.Color, Material = part.Material, Transparency = part.Transparency}
            end
        end
    end
    local face = model:FindFirstChild("ControlFace")
    local faceColor = face and face.Color
    local tag, label = makeTag(model)
    local previousStep = 0
    local wasDone = model:GetAttribute("Done") == true

    local function stepGoal(part, base, fraction)
        local name = part.Name
        if name == "CeramicFuse" then
            return {CFrame = base.CFrame * CFrame.new(0, -.24 * fraction, 0)}
        elseif name == "HeavyRadioBattery" then
            local toward = (model.PrimaryPart.Position - base.CFrame.Position) * .22 * fraction
            return {CFrame = base.CFrame + toward}
        elseif name == "FadedLogbookPages" or name == "RangerLogbook" then
            return {CFrame = base.CFrame * CFrame.new(0, .16 * fraction, 0)}
        elseif name == "RadioAntenna" then
            return {CFrame = base.CFrame * CFrame.new(0, .32 * fraction, 0)}
        elseif name == "ValveWheel" or name == "ValveSpoke" then
            return {CFrame = base.CFrame * CFrame.Angles(0, 0, math.rad(100 * fraction))}
        elseif name == "DentedFuelCan" then
            return {CFrame = base.CFrame * CFrame.Angles(0, 0, math.rad(-28 * fraction))}
        elseif name == "ExposedWire" then
            return {CFrame = base.CFrame * CFrame.new(0, .11 * fraction, 0), Color = GREEN}
        elseif name == "CorrodedTerminal" then
            return {Color = GOLD}
        end
        return {CFrame = base.CFrame * CFrame.Angles(0, 0, math.rad(24 * fraction))}
    end

    local function restore()
        for part, base in originals do
            if part.Parent then
                part.CFrame = base.CFrame
                part.Size = base.Size
                part.Color = base.Color
                part.Material = base.Material
                part.Transparency = base.Transparency
            end
        end
        if face and face.Parent then face.Color = faceColor end
        previousStep = 0
    end

    local function animateStep(step)
        if #selected == 0 then return end
        local part = selected[((step - 1) % #selected) + 1]
        local base = originals[part]
        if part.Parent and base then tween(part, .55, stepGoal(part, base, step / 3)) end
    end

    local function refreshTag()
        local done = model:GetAttribute("Done") == true
        local available = model:GetAttribute("Available") == true
        tag.Enabled = done or available
        if done then
            label.Text = "TASK COMPLETE  •  " .. string.upper(model:GetAttribute("Title") or "REPAIRED")
            label.TextColor3 = GREEN
        else
            label.Text = string.upper(model:GetAttribute("Title") or "CAMP TASK")
                .. "  •  " .. tostring(model:GetAttribute("Step") or 0) .. "/3"
            label.TextColor3 = GOLD
        end
    end

    model:GetAttributeChangedSignal("Step"):Connect(function()
        local step = model:GetAttribute("Step") or 0
        if step > previousStep and not model:GetAttribute("Done") then animateStep(step) end
        previousStep = step
        refreshTag()
    end)
    model:GetAttributeChangedSignal("Done"):Connect(function()
        local done = model:GetAttribute("Done") == true
        if done and not wasDone then
            for _, part in selected do
                local base = originals[part]
                if part.Parent and base then tween(part, .7, stepGoal(part, base, 1)) end
            end
            if face and face.Parent then tween(face, .6, {Color = GREEN}) end
            pulse(model)
        elseif not done and wasDone then
            restore()
        end
        wasDone = done
        refreshTag()
    end)
    model:GetAttributeChangedSignal("Available"):Connect(refreshTag)
    refreshTag()
end

for _, model in folder:GetChildren() do setup(model) end
