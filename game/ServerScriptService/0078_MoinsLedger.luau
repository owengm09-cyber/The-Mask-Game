local M={}
function M.Normalize(old)
 if old==nil then return {Balance=0,Revision=0,Receipts={}} end
 assert(type(old)=="table" and type(old.Balance)=="number" and old.Balance>=0 and old.Balance%1==0,"Invalid wallet")
 assert(type(old.Receipts)=="table","Invalid receipt history")
 return {Balance=old.Balance,Revision=old.Revision or 0,Receipts=table.clone(old.Receipts)}
end
function M.Apply(old,purchaseId,amount)
 assert(type(purchaseId)=="string" and #purchaseId>0,"Missing receipt ID")
 assert(type(amount)=="number" and amount>0 and amount%1==0,"Invalid coin amount")
 local data=M.Normalize(old)
 if data.Receipts[purchaseId] then return data,false end
 data.Balance+=amount data.Revision+=1 data.Receipts[purchaseId]=true
 return data,true
end
return M
