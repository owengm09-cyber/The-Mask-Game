-- Pure transaction rules, shared by live storage and Studio verification.
local L={}
function L.Normalize(old, starting)
	local data=type(old)=="table" and table.clone(old) or {MOINS=starting}
	data.Version=1
	data.MOINS=math.max(0, math.floor(tonumber(data.MOINS) or 0))
	data.Owned=type(data.Owned)=="table" and table.clone(data.Owned) or {}
	data.Equipped=type(data.Equipped)=="table" and table.clone(data.Equipped) or {}
	data.Receipts=type(data.Receipts)=="table" and table.clone(data.Receipts) or {}
	data.ReceiptOrder=type(data.ReceiptOrder)=="table" and table.clone(data.ReceiptOrder) or {}
	return data
end
function L.Purchase(old, starting, cost, receipt, card, now)
	local data=L.Normalize(old,starting)
	if data.Receipts[receipt] then return data,"already",data.Receipts[receipt] end
	if data.MOINS<cost then return data,"insufficient" end
	data.MOINS-=cost
	data.Owned[card.Id]=(tonumber(data.Owned[card.Id]) or 0)+1
	data.Equipped[card.Kind]=card.Id
	local award={Id=card.Id,Kind=card.Kind,At=now,Receipt=receipt}
	data.Latest=award
	data.Receipts[receipt]=award
	table.insert(data.ReceiptOrder,receipt)
	while #data.ReceiptOrder>100 do data.Receipts[table.remove(data.ReceiptOrder,1)]=nil end
	return data,"purchased",award
end
return L
