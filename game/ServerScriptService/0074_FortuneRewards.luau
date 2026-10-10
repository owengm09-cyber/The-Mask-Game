local Players=game:GetService("Players")
local Storage=game:GetService("ServerStorage")
local Config=require(game.ReplicatedStorage:WaitForChild("FortuneConfig"))
local S={}
local states={}
local function alive(player)
	local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid");local r=c and c:FindFirstChild("HumanoidRootPart")
	if c and h and h.Health>0 and r then return c,h,r end
end
local function equipWeapon(player)
	local backpack=player:FindFirstChild("Backpack");if not backpack then return end
	local c=player.Character
	local wanted=player:GetAttribute("Fortune_SurvivorWeapons")=="camp_hatchet" and not player:GetAttribute("HasMask")
	for _,container in {backpack,c} do if container then
		for _,tool in container:GetChildren() do if tool:GetAttribute("FortuneWeapon") then
			if wanted then return else tool:Destroy() end
		end end
	end end
	if not wanted then return end
	local tool=Storage.FortuneCampHatchet:Clone();tool.Name="Camp Hatchet"
	local last=0
	tool.Activated:Connect(function()
		if tool.Parent~=player.Character or player:GetAttribute("HasMask") or not player:GetAttribute("InRound") then return end
		local config=workspace:FindFirstChild("MaskSystem")
		if config and config:GetAttribute("MeetingActive") then return end
		local char,h,root=alive(player);if not char or os.clock()-last<1.1 then return end;last=os.clock()
		local Mask=require(script.Parent.MaskService)
		if Mask.IsSafe(root.Position) then return end
		local targets={}
		for _,other in Players:GetPlayers() do
			if other~=player and other:GetAttribute("HasMask") and other:GetAttribute("InRound") then
				local oc,oh,orr=alive(other);if oc then table.insert(targets,{oc,oh,orr}) end
			end
		end
		local npc=workspace:FindFirstChild("NightHarlequin")
		if npc and npc:FindFirstChild("HumanoidRootPart") and npc:FindFirstChildOfClass("Humanoid") then table.insert(targets,{npc,npc:FindFirstChildOfClass("Humanoid"),npc.HumanoidRootPart}) end
		local nearest,distance
		for _,target in targets do
			local delta=target[3].Position-root.Position;local d=delta.Magnitude
			if d<=6 and (d<.01 or root.CFrame.LookVector:Dot(delta.Unit)>.15) and not Mask.IsSafe(target[3].Position) and target[2].Health>0 and not target[1]:FindFirstChildOfClass("ForceField") then
				local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude;rp.FilterDescendantsInstances={char};rp.RespectCanCollide=true
				local hit=workspace:Raycast(root.Position,delta,rp)
				if (not hit or hit.Instance:IsDescendantOf(target[1])) and (not distance or d<distance) then nearest=target;distance=d end
			end
		end
		if nearest then nearest[2]:TakeDamage(25) end
	end)
	tool.Parent=backpack
end
function S.Apply(player)
	local c,h=alive(player)
	local killerPerk=Config.Card(player:GetAttribute("Fortune_KillerPerks"))
	player:SetAttribute("FortuneReachBonus",killerPerk and killerPerk.ReachBonus or 0)
	if h then
		local state=states[player]
		if not state or state.h~=h then state={h=h,height=h.JumpHeight,power=h.JumpPower};states[player]=state end
		local perk=not player:GetAttribute("HasMask") and Config.Card(player:GetAttribute("Fortune_SurvivorPerks"))
		h.JumpHeight=state.height+(perk and perk.JumpHeightBonus or 0)
		h.JumpPower=state.power+(perk and perk.JumpPowerBonus or 0)
	end
	equipWeapon(player)
end
function S.Start()
	local function setup(player)
		for _,name in {"HasMask","Fortune_SurvivorPerks","Fortune_KillerPerks","Fortune_SurvivorWeapons"} do player:GetAttributeChangedSignal(name):Connect(function()S.Apply(player)end) end
		player.CharacterAdded:Connect(function(c) c:WaitForChild("Humanoid",10);c:WaitForChild("HumanoidRootPart",10);task.wait(.2);S.Apply(player) end)
		task.defer(S.Apply,player)
	end
	for _,player in Players:GetPlayers() do setup(player) end
	Players.PlayerAdded:Connect(setup);Players.PlayerRemoving:Connect(function(p) states[p]=nil end)
end
return S
