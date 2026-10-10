local Fortune=require(script.Parent.FortuneService)
-- The Zoltar machine lives in the lobby experience; here only the MOINS wallet + rewards run.
local lobby=workspace:FindFirstChild("Lobby")
local machine=lobby and lobby:FindFirstChild("ZoltarFortuneMachine")
if machine then Fortune.Start(machine) else Fortune.StartWithoutMachine() end
