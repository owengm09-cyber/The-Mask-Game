local Players=game:GetService("Players")
local Market=game:GetService("MarketplaceService")
local Policy=game:GetService("PolicyService")
local Config=require(game.ReplicatedStorage:WaitForChild("GamePassConfig"))
local S={}
local ownership,busy,eligibility={},{},{}
local started=false

local function nameTag(player)
    local character=player.Character
    local head=character and character:FindFirstChild("Head")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not head or not humanoid then return end
    local existing=head:FindFirstChild("VIPNameTag")
    if existing then existing:Destroy() end
    if not ownership[player.UserId] or ownership[player.UserId].VIP~=true then return end
    humanoid.NameDisplayDistance=0
    local tag=Instance.new("BillboardGui")
    tag.Name="VIPNameTag" tag.Adornee=head tag.Size=UDim2.fromOffset(190,50)
    tag.StudsOffsetWorldSpace=Vector3.new(0,2.8,0)
    tag.MaxDistance=65 tag.AlwaysOnTop=false tag.LightInfluence=0
    local plate=Instance.new("Frame")
    plate.Size=UDim2.fromScale(1,1) plate.BackgroundColor3=Color3.fromRGB(30,12,39)
    plate.BackgroundTransparency=0.18 plate.BorderSizePixel=0 plate.Parent=tag
    local corner=Instance.new("UICorner",plate) corner.CornerRadius=UDim.new(0,10)
    local edge=Instance.new("UIStroke",plate) edge.Color=Color3.fromRGB(238,193,91) edge.Thickness=1.4
    local badge=Instance.new("TextLabel",plate)
    badge.Name="Badge" badge.Size=UDim2.new(1,-12,0,18) badge.Position=UDim2.fromOffset(6,3)
    badge.BackgroundTransparency=1 badge.Text="V I P" badge.Font=Enum.Font.GothamBold
    badge.TextSize=13 badge.TextColor3=Color3.fromRGB(255,215,113)
    local name=Instance.new("TextLabel",plate)
    name.Name="PlayerName" name.Size=UDim2.new(1,-12,0,23) name.Position=UDim2.fromOffset(6,22)
    name.BackgroundTransparency=1 name.Text=player.DisplayName name.Font=Enum.Font.GothamBold
    name.TextSize=17 name.TextTruncate=Enum.TextTruncate.AtEnd name.TextColor3=Color3.fromRGB(255,240,194)
    tag.Parent=head
end

local function publish(id,key,value)
    local player=Players:GetPlayerByUserId(id)
    if not player then return end
    player:SetAttribute("Owns"..key,value)
    player:SetAttribute(key.."OwnershipLoaded",value~=nil)
    if key=="VIP" and value==true then nameTag(player) end
end

-- Ownership is checked on the server; client attributes and remotes cannot grant passes.
function S.OwnsAsync(id,key)
    local pass=Config.Get(key)
    assert(pass,"Unknown game pass")
    ownership[id]=ownership[id] or {}
    local values=ownership[id]
    if values[key]~=nil then publish(id,key,values[key]) return values[key] end
    local request=tostring(id)..":"..key
    if busy[request] then
        local deadline=os.clock()+20
        repeat task.wait(.05) until not busy[request] or os.clock()>deadline
        return values[key]
    end
    busy[request]=true
    local ok,value=pcall(function() return Market:UserOwnsGamePassAsync(id,pass.Id) end)
    busy[request]=nil
    if ok then
        -- A completed purchase must not be overwritten by an older in-flight lookup.
        values[key]=values[key]==true or value==true
        publish(id,key,values[key])
        return values[key]
    end
    if values[key]==true then publish(id,key,true) return true end
    publish(id,key,nil)
    return nil
end

function S.CanDrawAsync(player)
    local id=player.UserId
    if eligibility[id]~=nil then return eligibility[id] end
    local ok,info=pcall(function() return Policy:GetPolicyInfoForPlayerAsync(player) end)
    if ok then eligibility[id]=info.ArePaidRandomItemsRestricted~=true end
    if player.Parent==Players then
        player:SetAttribute("RandomItemsPolicyLoaded",ok)
        player:SetAttribute("RandomItemsAllowed",ok and eligibility[id]==true)
    end
    if ok then return eligibility[id] end
    return nil
end

local function setup(player)
    for _,pass in Config.Passes do
        player:SetAttribute(pass.Key.."OwnershipLoaded",false)
        task.spawn(function()
            repeat
                if S.OwnsAsync(player.UserId,pass.Key)~=nil then return end
                task.wait(10)
            until player.Parent~=Players
        end)
    end
    task.spawn(function()
        repeat
            S.CanDrawAsync(player)
            if eligibility[player.UserId]~=nil then return end
            task.wait(10)
        until player.Parent~=Players
    end)
    player.CharacterAdded:Connect(function(character)
        character:WaitForChild("Head",10)
        character:WaitForChild("Humanoid",10)
        if player.Character==character then nameTag(player) end
    end)
    if player.Character then task.defer(nameTag,player) end
end

function S.Start()
    if started then return end
    started=true
    Market.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
        if not purchased then return end
        for _,pass in Config.Passes do
            if pass.Id==id then
                ownership[player.UserId]=ownership[player.UserId] or {}
                ownership[player.UserId][pass.Key]=true
                publish(player.UserId,pass.Key,true)
                break
            end
        end
    end)
    Players.PlayerAdded:Connect(setup)
    for _,player in Players:GetPlayers() do setup(player) end
    Players.PlayerRemoving:Connect(function(player)
        eligibility[player.UserId]=nil
        -- Retain ownership briefly for XP awards from a round the player left.
        task.delay(120,function()
            if not Players:GetPlayerByUserId(player.UserId) then ownership[player.UserId]=nil end
        end)
    end)
end
return S
