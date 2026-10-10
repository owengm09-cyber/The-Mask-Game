if not game:GetService("RunService"):IsStudio() then return end
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local config=workspace:WaitForChild("MaskSystem")
local Mask=require(game.ServerScriptService.MaskService)
local Rig=require(game.ReplicatedStorage.CreatureRig)
local reports={}
local function check(value,message)
 assert(value,message) table.insert(reports,message) print("CREATURE PASS: "..message)
end
local function waitFor(fn,seconds)
 local untilTime=os.clock()+seconds
 repeat local result=fn() if result then return result end task.wait(.2) until os.clock()>untilTime
 return nil
end
local phase
local mode=config:GetAttribute("CreatureControlMode")
local p,parkedForceFields={},{}
local function clearProtection(c)
 for _,o in ipairs(c:GetChildren()) do if o:IsA("ForceField") then table.insert(parkedForceFields,{o,c}) o.Parent=nil end end
end
task.wait(3)
phase=Lighting:GetAttribute("Phase")
local ok,err=xpcall(function()
 p=Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
 local char=waitFor(function() local c=p.Character return c and c:FindFirstChild("HumanoidRootPart") and c end,15)
 assert(char,"Player character not ready")
 local model=game.ServerStorage.HarlequinTemplate:Clone()
 local ctx=Rig.Bind(model)
 Rig.Pose(ctx,0,0,100,100)
 local standing=ctx.motors.SkullJoint
 local happy=ctx.motors.Skull.C0.LookVector
 local standingY=ctx.motors.Skull.C0.Position.Y
 Rig.Pose(ctx,0,1,100,100)
 check(ctx.motors.Skull.C0.Position.Y<standingY-3,"Four-legged run lowers the torso and head")
 Rig.Pose(ctx,0,0,100,2)
 check(ctx.motors.Skull.C0.LookVector:Dot(happy)<-.9,"Kill pose rotates to the opposing sad face")
 model:Destroy()
 config:SetAttribute("CreatureControlMode","Hybrid")
 config:SetAttribute("MatchActive",true) p:SetAttribute("InRound",true)
 Mask.Spawn()
 Lighting:SetAttribute("Phase","Night")
 local npc=waitFor(function() return workspace:FindFirstChild("NightHarlequin") end,25)
 check(npc~=nil,"Nighttime AI spawns outside safe zones")
 local nr=npc.HumanoidRootPart local first=nr.Position
 task.wait(5)
 check((nr.Position-first).Magnitude>1,"AI moves through the map")
 char=p.Character
 local hr=char.HumanoidRootPart local h=char:FindFirstChildOfClass("Humanoid")
 clearProtection(char)
 hr.CFrame=nr.CFrame*CFrame.new(0,0,-4)
 hr.Anchored=true
 local killed=waitFor(function() return h.Health<=0 end,9)
 hr.Anchored=false
 check(killed,"AI performs a server-validated kill")
 check(workspace:GetServerTimeNow()-(npc:GetAttribute("CreatureKillAt") or -100)<4,"Successful kill triggers the mask-change animation")
 local previous=char
 char=waitFor(function() local c=p.Character local hu=c and c:FindFirstChildOfClass("Humanoid") return c~=previous and hu and hu.Health>0 and c:FindFirstChild("HumanoidRootPart") and c end,12)
 assert(char,"Respawn did not finish")
 clearProtection(char) p:SetAttribute("InRound",true)
 Mask.Spawn()
 local pickup=waitFor(Mask.GetPickup,15) assert(pickup,"No mask pickup found")
 local destination=pickup:GetPivot().Position
 char:PivotTo(CFrame.lookAt(destination+Vector3.new(0,1,5),destination))
 task.wait(.3)
 check(Mask.TryPickup(p),"Existing mask pickup still works")
 local visual=waitFor(function()return char:FindFirstChild("MaskCreature")end,3)
 check(visual~=nil and char.Head.Transparency==1,"Mask wearer transforms into the creature")
 check(not workspace:FindFirstChild("NightHarlequin"),"Player ownership removes the duplicate AI killer")
 local humanoid=char:FindFirstChildOfClass("Humanoid")
 check(humanoid.WalkSpeed==config:GetAttribute("CreatureRunSpeed"),"Player killer receives running movement")
 Lighting:SetAttribute("Phase","Day") task.wait(.8)
 check(not char:FindFirstChild("MaskCreature") and char.Head.Transparency<1,"Daytime restores the player's appearance")
 check(Mask.Attack(p)==false,"Killer attacks are disabled during daytime")
 Mask.Release(p)
end,debug.traceback)
if type(p)~="table" and p.Parent then pcall(function()Mask.Release(p)end) end
for _,entry in ipairs(parkedForceFields) do if entry[2].Parent then entry[1].Parent=entry[2] end end
config:SetAttribute("CreatureControlMode",mode)
Lighting:SetAttribute("Phase",phase)
local result=Instance.new("StringValue") result.Name="CreatureTestResults"
result.Value=(ok and "PASS" or "FAIL").."\n"..table.concat(reports,"\n")..(err and "\n"..tostring(err) or "")
result.Parent=game.ServerStorage
if ok then print("CREATURE TESTS COMPLETE: "..#reports.." checks passed.")
else warn("CREATURE TEST FAILURE: "..tostring(err)) end
