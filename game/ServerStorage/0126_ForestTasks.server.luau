local P=require(script.Parent.ProgressionService)
local config=workspace:WaitForChild("MaskSystem")
for _,crate in workspace:WaitForChild("ForestXPTasks"):GetChildren() do
 local prompt=crate:FindFirstChildOfClass("ProximityPrompt") local began={}
 local function valid(p)
 local c=p.Character local h=c and c:FindFirstChildOfClass("Humanoid") local r=c and c:FindFirstChild("HumanoidRootPart")
 return config:GetAttribute("MatchActive")==true and config:GetAttribute("MeetingActive")~=true and p:GetAttribute("InRound")==true and not p:GetAttribute("HasMask") and h and h.Health>0 and r and (r.Position-crate.Position).Magnitude<=11
 end
 prompt.PromptButtonHoldBegan:Connect(function(p) if valid(p) then began[p]=os.clock() end end)
 prompt.Triggered:Connect(function(p)
 local start=began[p] began[p]=nil
 if not start or os.clock()-start<2.8 or not valid(p) then return end
 local root=p.Character.HumanoidRootPart local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude ray.FilterDescendantsInstances={p.Character}
 local hit=workspace:Raycast(root.Position,crate.Position-root.Position,ray)
 if hit and hit.Instance~=crate then return end
 P.Task(p,crate.Name)
 end)
 game.Players.PlayerRemoving:Connect(function(p) began[p]=nil end)
 config:GetAttributeChangedSignal("MatchActive"):Connect(function() table.clear(began) end)
end