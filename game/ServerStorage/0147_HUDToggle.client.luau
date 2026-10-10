local CAS=game:GetService("ContextActionService")
local gui=game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("DreadHUD")
CAS:BindAction("ToggleHUD",function(_,state)
 if state==Enum.UserInputState.Begin then gui:SetAttribute("SurvivorsHidden",not gui:GetAttribute("SurvivorsHidden")) end
 return Enum.ContextActionResult.Pass
end,true,Enum.KeyCode.H)
CAS:SetTitle("ToggleHUD","HUD")
CAS:SetPosition("ToggleHUD",UDim2.new(1,-140,0,10))
