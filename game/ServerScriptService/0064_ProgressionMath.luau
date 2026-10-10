local M={}
local PassConfig=require(game.ReplicatedStorage:WaitForChild("GamePassConfig"))
function M.Cost(level) return 100+50*(level-1) end
function M.Level(total)
 total=math.max(0,math.floor(total or 0))
 local n=math.floor((-75+math.sqrt(5625+100*total))/50)
 local spent=25*n*n+75*n
 return n+1,total-spent,M.Cost(n+1)
end
function M.Reward(record,winner)
 local win=record.team==winner and not record.left
 local parts={Participation=record.left and 0 or 50,Victory=win and 100 or 0,Tasks=25*math.min(record.tasks or 0,15),Survival=record.team=="Innocents" and math.min(40,2*math.floor((record.seconds or 0)/15)) or 0,Eliminations=35*math.min(record.kills or 0,5)}
 local total=0 for _,v in parts do total+=v end
 return total,parts,win
end
function M.AddVIP(amount,parts,ownsVIP)
 local updated=table.clone(parts)
 updated.VIP=ownsVIP and math.floor(amount*PassConfig.VIPXPBonus+.5) or 0
 return amount+updated.VIP,updated
end
function M.Apply(old,receipt,amount,won)
 old=old or {XP=0,Wins=0,Receipts={}}
 local data={XP=old.XP or 0,Wins=old.Wins or 0,Receipts=table.clone(old.Receipts or {})}
 if table.find(data.Receipts,receipt) then return data end
 data.XP+=amount if won then data.Wins+=1 end
 table.insert(data.Receipts,receipt) if #data.Receipts>100 then table.remove(data.Receipts,1) end
 return data
end
return M