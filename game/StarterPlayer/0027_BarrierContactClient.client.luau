local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local player=Players.LocalPlayer
local remote=RS:WaitForChild('Remotes'):WaitForChild('BarrierContact')
local geometry=RS:WaitForChild('BarrierBoundaryData')
local Ripple=require(RS:WaitForChild('BarrierRipple'))
local effects=Instance.new('Folder') effects.Name='LocalBarrierRipples' effects.Parent=workspace
local active={} local nextContact=0 local accumulator=0
remote.OnClientEvent:Connect(function(point,normal)
 local camera=workspace.CurrentCamera
 if not camera or (camera.CFrame.Position-point).Magnitude>140 then return end
 if #active>=6 then active[1].view:Destroy() table.remove(active,1) end
 table.insert(active,{view=Ripple.Create(effects,point,normal),time=os.clock()})
 effects:SetAttribute('ContactsShown',(effects:GetAttribute('ContactsShown') or 0)+1)
end)
Run.Heartbeat:Connect(function(dt)
 accumulator+=dt if accumulator<1/30 then return end accumulator=0
 local now=os.clock()
 for i=#active,1,-1 do local e=active[i] local age=now-e.time
  if age>1.8 then e.view:Destroy() table.remove(active,i) else e.view:Step(age) end
 end
 if now<nextContact then return end
 local char=player.Character local root=char and char:FindFirstChild('HumanoidRootPart')
 local hum=char and char:FindFirstChildOfClass('Humanoid')
 if not root or not hum or hum.Health<=0 or root.Anchored then return end
 for _,wall in geometry:GetChildren() do
  local normal=wall:GetAttribute('InwardNormal') local face=wall:GetAttribute('InnerFace')
  local d=(root.Position-face):Dot(normal)
  if d>=-.5 and d<3.3 and hum.MoveDirection:Dot(-normal)>.2 then
   remote:FireServer(wall.Name) nextContact=now+.95 break
  end
 end
end)
