local Players=game:GetService("Players")
local Market=game:GetService("MarketplaceService")
local Run=game:GetService("RunService")
local Config=require(game.ReplicatedStorage.MoinsShopConfig)
local Ledger=require(script.Parent.MoinsLedger)
local store=not Run:IsStudio() and game:GetService("DataStoreService"):GetDataStore("MaskMoinsWallet_v1") or nil
local remotes=game.ReplicatedStorage:WaitForChild("Remotes")
local remote=Instance.new("RemoteEvent",remotes) remote.Name="MoinsShop"
local catalog=Instance.new("Folder",game.ReplicatedStorage) catalog.Name="MoinsCatalog"
local byId,byKey={},{}
local busy={} local nextPrompt={}
for _,b in Config.Bundles do
 assert(not byKey[b.Key],"Duplicate bundle key") byKey[b.Key]=b
 if b.ProductId>0 then assert(not byId[b.ProductId],"Duplicate developer product ID") byId[b.ProductId]=b end
 local item=Instance.new("Folder",catalog) item.Name=b.Key item:SetAttribute("Amount",b.Amount) item:SetAttribute("ProductId",b.ProductId) item:SetAttribute("Ready",false)
end
local function publish(p,data)
 if not p or p.Parent~=Players then return end
 if data.Revision<(p:GetAttribute("MoinsRevision") or -1) then return end
 p:SetAttribute("Moins",data.Balance) p:SetAttribute("MoinsRevision",data.Revision) p:SetAttribute("MoinsLoaded",true) p:SetAttribute("MoinsLoadFailed",false)
end
local function load(p)
 p:SetAttribute("MoinsLoaded",false)
 if not store then publish(p,Ledger.Normalize(nil)) p:SetAttribute("MoinsPreview",true) return end
 for attempt=1,4 do
 local ok,data=pcall(function()return Ledger.Normalize(store:GetAsync("User_"..p.UserId))end)
 if ok then publish(p,data) return end task.wait(2^attempt)
 if p.Parent~=Players then return end
 end
 p:SetAttribute("MoinsLoadFailed",true)
end
Players.PlayerAdded:Connect(load) for _,p in Players:GetPlayers() do task.spawn(load,p) end
-- Only offer products belonging to this experience; do not trust arbitrary client IDs.
task.spawn(function()
 if next(byId)==nil then return end
 for attempt=1,3 do
 local ok=pcall(function()
 local pages=Market:GetDeveloperProductsAsync()
 repeat
 for _,info in pages:GetCurrentPage() do
 local id=info.ProductId or info.DeveloperProductId
 local b=id and byId[id]
 if b then catalog[b.Key]:SetAttribute("Ready",true) end
 end
 if pages.IsFinished then break end pages:AdvanceToNextPageAsync()
 until false
 end)
 if ok then return end task.wait(attempt*5)
 end
end)
remote.OnServerEvent:Connect(function(p,key)
 if type(key)~="string" or #key>40 then return end
 if os.clock()<(nextPrompt[p] or 0) then return end nextPrompt[p]=os.clock()+2
 local b=byKey[key]
 if not b or b.ProductId<=0 or not catalog[b.Key]:GetAttribute("Ready") then remote:FireClient(p,"Unavailable","This bundle is coming soon.") return end
 if Run:IsStudio() then remote:FireClient(p,"Unavailable","Purchases are disabled in this Studio preview.") return end
 if not p:GetAttribute("MoinsLoaded") then remote:FireClient(p,"Unavailable","Your wallet is still loading. Please try again.") return end
 local ok=pcall(function()Market:PromptProductPurchase(p,b.ProductId)end)
 if not ok then remote:FireClient(p,"Unavailable","Roblox could not open the purchase window. Try again.") end
end)
Market.ProcessReceipt=function(receipt)
 local b=byId[receipt.ProductId]
 local p=Players:GetPlayerByUserId(receipt.PlayerId)
 if not b or not p or not store or busy[receipt.PlayerId] then return Enum.ProductPurchaseDecision.NotProcessedYet end
 busy[receipt.PlayerId]=true
 local newlyGranted=false
 -- Coin balance and receipt ID are saved together, making retries/cross-server calls safe.
 local ok,data=pcall(function()
 return store:UpdateAsync("User_"..receipt.PlayerId,function(old)
 local nextData,added=Ledger.Apply(old,tostring(receipt.PurchaseId),b.Amount)
 newlyGranted=added return nextData
 end)
 end)
 busy[receipt.PlayerId]=nil
 if not ok or not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
 publish(p,data)
 remote:FireClient(p,"Granted",newlyGranted and b.Amount or 0,data.Balance)
 return Enum.ProductPurchaseDecision.PurchaseGranted
end
Players.PlayerRemoving:Connect(function(p) nextPrompt[p]=nil end)
