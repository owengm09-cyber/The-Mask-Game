local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RescueInteraction")

local gui = Instance.new("ScreenGui")
gui.Name = "RescueCompletionFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 105
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "CompletionCard"
card.AnchorPoint = Vector2.new(1, 0)
card.Size = UDim2.fromOffset(390, 80)
card.Position = UDim2.new(1, 410, 0, 102)
card.BackgroundColor3 = Color3.fromRGB(19, 27, 23)
card.BackgroundTransparency = .07
card.BorderSizePixel = 0
card.Visible = false
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 7)
corner.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(157, 219, 162)
stroke.Thickness = 2
stroke.Transparency = .1
stroke.Parent = card

local stripe = Instance.new("Frame")
stripe.Name = "SuccessStripe"
stripe.Size = UDim2.new(0, 7, 1, 0)
stripe.BackgroundColor3 = Color3.fromRGB(157, 219, 162)
stripe.BorderSizePixel = 0
stripe.Parent = card

local kicker = Instance.new("TextLabel")
kicker.Name = "Kicker"
kicker.Position = UDim2.fromOffset(21, 10)
kicker.Size = UDim2.new(1, -35, 0, 22)
kicker.BackgroundTransparency = 1
kicker.Text = "CAMP SYSTEM RESTORED"
kicker.TextColor3 = Color3.fromRGB(157, 219, 162)
kicker.TextXAlignment = Enum.TextXAlignment.Left
kicker.Font = Enum.Font.Oswald
kicker.TextSize = 18
kicker.Parent = card

local detail = Instance.new("TextLabel")
detail.Name = "TaskName"
detail.Position = UDim2.fromOffset(21, 36)
detail.Size = UDim2.new(1, -35, 0, 32)
detail.BackgroundTransparency = 1
detail.Text = "TASK COMPLETE"
detail.TextColor3 = Color3.fromRGB(235, 224, 197)
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.TextWrapped = true
detail.Font = Enum.Font.Oswald
detail.TextSize = 24
detail.Parent = card

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(174, 242, 174)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 3
flash.Parent = card
local flashCorner = Instance.new("UICorner")
flashCorner.CornerRadius = UDim.new(0, 7)
flashCorner.Parent = flash

local lastTitle = "TASK COMPLETE"
local generation = 0
local function showCompletion()
    generation += 1
    local current = generation
    detail.Text = string.upper(lastTitle)
    card.Visible = true
    card.Position = UDim2.new(1, 410, 0, 102)
    flash.BackgroundTransparency = .28
    TweenService:Create(card, TweenInfo.new(.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -24, 0, 102)}):Play()
    TweenService:Create(flash, TweenInfo.new(.75), {BackgroundTransparency = 1}):Play()
    task.delay(3, function()
        if current ~= generation or not card.Parent then return end
        local exit = TweenService:Create(card, TweenInfo.new(.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(1, 410, 0, 102)})
        exit:Play()
        exit.Completed:Wait()
        if current == generation then card.Visible = false end
    end)
end

remote.OnClientEvent:Connect(function(action, data)
    if action == "open" and type(data) == "table" then
        lastTitle = data.title or "TASK COMPLETE"
    elseif action == "close" and data == "TASK COMPLETE" then
        showCompletion()
    end
end)
