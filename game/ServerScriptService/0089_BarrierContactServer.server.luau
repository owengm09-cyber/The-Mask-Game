local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local remote=RS:WaitForChild('Remotes'):WaitForChild('BarrierContact')
local walls=workspace:WaitForChild('MapBarrier')
local ready={}
local function contact(player,name)
 if typeof(name)~='string' then return end
 local wall=walls:FindFirstChild(name)
 if not wall or not wall:IsA('BasePart') or not wall.CanCollide then return end
 local char=player.Character local root=char and char:FindFirstChild('HumanoidRootPart')
 local hum=char and char:FindFirstChildOfClass('Humanoid')
 if not root or not hum or hum.Health<=0 or root.Anchored then return end
 local t=os.clock() if t<(ready[player] or 0) then return end
 local normal=wall:GetAttribute('InwardNormal') local face=wall:GetAttribute('InnerFace')
 if typeof(normal)~='Vector3' or typeof(face)~='Vector3' then return end
 local d=(root.Position-face):Dot(normal)
 local tangent=Vector3.yAxis:Cross(normal)
 if d < -.5 or d>4.3 or math.abs((root.Position-face):Dot(tangent))>298.8 then return end
 ready[player]=t+.85
 local point=root.Position-normal*d-Vector3.new(0,1.6,0)+normal*.13
 remote:FireAllClients(point,normal,player.UserId)
end
remote.OnServerEvent:Connect(contact)
for _,wall in walls:GetChildren() do if wall:IsA('BasePart') then
 wall.Touched:Connect(function(part)
  local char=part:FindFirstAncestorOfClass('Model')
  local player=char and Players:GetPlayerFromCharacter(char)
  if player then contact(player,wall.Name) end
 end)
end end
Players.PlayerRemoving:Connect(function(p) ready[p]=nil end)
