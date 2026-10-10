local p=game.Players.LocalPlayer
local Market=game:GetService("MarketplaceService")
local UIS=game:GetService("UserInputService")
local Config=require(game.ReplicatedStorage:WaitForChild("MoinsShopConfig"))
local catalog=game.ReplicatedStorage:WaitForChild("MoinsCatalog")
local remote=game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MoinsShop")
local gui=Instance.new("ScreenGui") gui.Name="MoinsShopHUD" gui.ResetOnSpawn=false gui.DisplayOrder= 70 gui.Parent=p:WaitForChild("PlayerGui")
local gold=Color3.fromRGB(238,193,91) local ivory=Color3.fromRGB(251,231,170) local purple=Color3.fromRGB( 30,9, 40)
local function fmt(n) return tostring(n):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","") end
local function edge(o,c,t) local e=Instance.new("UIStroke",o) e.Color=c e.Thickness=t or 1 return e end
local function round(o,r) local c=Instance.new("UICorner",o) c.CornerRadius=UDim.new(0,r) end
local function frame(parent,name,size,pos,c)
 local f=Instance.new("Frame",parent) f.Name=name f.Size=size f.Position=pos f.BackgroundColor3=c or purple f.BorderSizePixel=0 return f
end
local function text(parent,name,str,size,pos,fs,font,c)
 local t=Instance.new("TextLabel",parent) t.Name=name t.Text=str t.Size=size t.Position=pos t.BackgroundTransparency=1 t.TextColor3=c or ivory t.Font=font or Enum.Font.Garamond t.TextSize=fs return t
end
local function button(parent,name,str,size,pos,fn)
 local b=Instance.new("TextButton",parent) b.Name=name b.Text=str b.Size=size b.Position=pos b.BackgroundColor3=gold b.TextColor3=Color3.fromRGB(33,16,7) b.Font=Enum.Font.Garamond b.TextSize=22 b.BorderSizePixel=0 b.Activated:Connect(fn) return b
end
-- The approved Roblox thumbnail keeps the supplied artwork available if the full
-- image is still refreshing its experience permissions.
local function sprite(image,offset,size)
 image.Image=Config.Artwork image.ImageRectOffset=offset image.ImageRectSize=size
 task.delay(5,function()
  if image.Parent and not image.IsLoaded then
   image.Image="rbxthumb://type=Asset&id=121980822433798&w=420&h=420"
   image.ImageRectOffset=offset*(420/1536) image.ImageRectSize=size*(420/1536)
  end
 end)
end

local opened=false local pending=nil local prices={} local cards={}
local launch=button(gui,"ShopButton","✦ MOINS SHOP",UDim2.fromOffset(146,36),UDim2.new(1,-254,0,142),function() opened=not opened end)
launch.BackgroundColor3=purple launch.TextColor3=gold launch.TextSize=19 edge(launch,gold) round(launch,5)
local shade=frame(gui,"ShopShade",UDim2.fromScale(1,1),UDim2.fromScale(0,0),Color3.new()) shade.BackgroundTransparency=.22 shade.Visible=false
local Run=game:GetService("RunService")
local cursorBinding="MoinsShopCursor"
local mouseState
local function releaseShopCursor()
 if not mouseState then return end
 Run:UnbindFromRenderStep(cursorBinding)
 UIS.MouseBehavior=mouseState.Behavior
 UIS.MouseIconEnabled=mouseState.IconEnabled
 mouseState=nil
end
local function syncShopCursor()
 if opened and not mouseState then
  mouseState={Behavior=UIS.MouseBehavior,IconEnabled=UIS.MouseIconEnabled}
  Run:BindToRenderStep(cursorBinding,Enum.RenderPriority.Last.Value+2,function()
   UIS.MouseBehavior=Enum.MouseBehavior.Default
   UIS.MouseIconEnabled=true
  end)
 elseif not opened then
  releaseShopCursor()
 end
end
gui.Destroying:Connect(releaseShopCursor)

local panel=frame(shade,"ShopPanel",UDim2.fromOffset(930,650),UDim2.fromScale(.5,.5)) panel.AnchorPoint=Vector2.new(.5,.5) round(panel, 14) edge(panel,gold,3)
local gradient=Instance.new("UIGradient",panel) gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB( 50, 12, 60)),ColorSequenceKeypoint.new(1,Color3.fromRGB( 19,5,29))}) gradient.Rotation=90
local header=text(panel,"Title","MOINS SHOP",UDim2.fromOffset(300, 40),UDim2.fromOffset(25,14),36)
header.TextXAlignment=Enum.TextXAlignment.Left header.TextColor3=gold
local sub=text(panel,"Subtitle","Choose your bundle",UDim2.fromOffset(260,24),UDim2.fromOffset(25,55),15,Enum.Font.Gotham)
sub.TextXAlignment=Enum.TextXAlignment.Left
local masks=Instance.new("ImageLabel",panel) masks.Name="TheatreMasks" masks.BackgroundTransparency=1 sprite(masks,Vector2.new(550,0),Vector2.new(430,245)) masks.Size=UDim2.fromOffset(160, 90) masks.Position=UDim2.new(.5,-80,0,2) masks.ScaleType=Enum.ScaleType.Fit
local balance=text(panel,"Balance","MOINS: ...",UDim2.fromOffset(230,26),UDim2.new(1,-285,0, 20),18,Enum.Font.GothamBold)
balance.TextXAlignment=Enum.TextXAlignment.Right
local close=button(panel,"Close","X",UDim2.fromOffset(34,34),UDim2.new(1,-46,0,12),function() opened=false end) close.Modal=true round(close, 17)
local trim=frame(panel,"GoldTrim",UDim2.new(1,-48,0,1),UDim2.fromOffset(24,92),gold)
local scroll=Instance.new("ScrollingFrame",panel) scroll.Name="Bundles" scroll.Position=UDim2.fromOffset(24,108) scroll.Size=UDim2.new(1,-48,1,-168) scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.ScrollBarThickness=4 scroll.ScrollBarImageColor3=gold
local layout=Instance.new("UIGridLayout",scroll) layout.SortOrder=Enum.SortOrder.LayoutOrder layout.CellPadding=UDim2.fromOffset(14,14)
local footer=text(panel,"Footer","Purchases are confirmed securely by Roblox.",UDim2.new(1,-48,0,22),UDim2.new(0,24,1,-49),12,Enum.Font.Gotham)
local notice=text(panel,"Notice","",UDim2.new(1,-48,0,22),UDim2.new(0,24,1,-27),12,Enum.Font.Gotham,Color3.fromRGB(255,212,130))
local crops={{180,410,365,132},{595,410,365,132},{1005,410,365,132},{180,681,365,145},{595,681,365,145},{1005,681,365,145}}
local function setNotice(message) notice.Text=message end
local function purchase(b)
 if pending then return end
 local cat=catalog:FindFirstChild(b.Key)
 if not cat or not cat:GetAttribute("Ready") or not prices[b.Key] then setNotice("This bundle is coming soon.") return end
 if not p:GetAttribute("MoinsLoaded") then setNotice("Your wallet is loading. Please try again shortly.") return end
 pending=b.ProductId setNotice("Opening Roblox purchase confirmation…")
 remote:FireServer(b.Key)
 local id=pending task.delay(120,function()if pending==id then pending=nil end end)
end
for i,b in Config.Bundles do
 local card=frame(scroll,b.Key,UDim2.fromOffset(270,220),UDim2.fromOffset(0,0),Color3.fromRGB(27,7,37)) card.LayoutOrder=i round(card, 12) edge(card,gold,2)
 local amount=text(card,"Amount",fmt(b.Amount).." MOINS",UDim2.new(1,-12,0,36),UDim2.fromOffset(6,4),28)
 amount.TextColor3=gold
 frame(card,"Underline",UDim2.new(.7,0,0,1),UDim2.new(.15,0,0, 40),gold)
 local art=Instance.new("ImageLabel",card) art.Name="BundleArt" art.BackgroundTransparency=1 sprite(art,Vector2.new(crops[i][1],crops[i][2]),Vector2.new(crops[i][3],crops[i][4])) art.Size=UDim2.new(1,-16,1,- 90) art.Position=UDim2.fromOffset(8, 40) art.ScaleType=Enum.ScaleType.Fit
 local fallback=frame(card,"FallbackArt",UDim2.new(1,-16,1,-90),UDim2.fromOffset(8,40),purple) fallback.BackgroundTransparency=1
for pile=1,math.min(i+1,5) do
 for layer=1,2+pile do
 local coin=frame(fallback,"Coin",UDim2.fromOffset(38,12),UDim2.new(.5,-80+(pile-1)*31,.8,-layer*6),Color3.fromRGB(218,155,48))
 round(coin,6) edge(coin,Color3.fromRGB(255,217,110))
 end
end
local token=frame(fallback,"MaskCoin",UDim2.fromOffset(42,42),UDim2.new(.5,-21,.45,-10),gold) round(token,21) edge(token,ivory,2)
text(token,"MoinsMark","M",UDim2.fromScale(1,1),UDim2.fromScale(0,0),30,Enum.Font.Garamond,Color3.fromRGB(80, 40,15))
local function artLoaded() fallback.Visible=not art.IsLoaded end art:GetPropertyChangedSignal("IsLoaded"):Connect(artLoaded) artLoaded()
local buy=button(card,"Buy","COMING SOON",UDim2.new(1,- 20,0,38),UDim2.new(0,10,1,-46),function()purchase(b)end) round(buy, 17) edge(buy,ivory)
 local bg=Instance.new("UIGradient",buy) bg.Color=ColorSequence.new(Color3.fromRGB(255,222,138),Color3.fromRGB(190,131,45)) bg.Rotation=90
 cards[b.Key]=card
 local function fetch()
 local cat=catalog:WaitForChild(b.Key)
 if b.ProductId<=0 or not cat:GetAttribute("Ready") then buy.Text="COMING SOON" buy.AutoButtonColor=false return end
 buy.Text="LOADING PRICE"
 local ok,info=pcall(function()return Market:GetProductInfoAsync(b.ProductId,Enum.InfoType.Product)end)
 if ok and type(info.PriceInRobux)=="number" and info.IsForSale~=false then
 prices[b.Key]=info.PriceInRobux buy.Text=fmt(info.PriceInRobux).." ROBUX" buy.AutoButtonColor=true
 else prices[b.Key]=nil buy.Text="UNAVAILABLE" buy.AutoButtonColor=false end
 end
 task.spawn(fetch)
 catalog:WaitForChild(b.Key):GetAttributeChangedSignal("Ready"):Connect(fetch)
end
remote.OnClientEvent:Connect(function(action,message,balanceValue)
 if action=="Granted" then pending=nil
 if message>0 then setNotice("+"..fmt(message).." Moins added to your wallet.") else setNotice("Your wallet is up to date.") end
 elseif action=="Unavailable" then pending=nil setNotice(message) end
end)
Market.PromptProductPurchaseFinished:Connect(function(userId,productId,purchased)
 if userId==p.UserId and productId==pending then
 if purchased then setNotice("Purchase submitted. Waiting for Roblox confirmation…")
 else pending=nil setNotice("Purchase cancelled. No Moins were added.") end
 end
end)
UIS.InputBegan:Connect(function(input,processed)
 if not processed and input.KeyCode==Enum.KeyCode.B then opened=not opened end
 if input.KeyCode==Enum.KeyCode.Escape and opened then opened=false end
end)
task.spawn(function()while gui.Parent do
 shade.Visible=opened
 syncShopCursor()
 balance.Text=p:GetAttribute("MoinsLoaded") and ("MOINS: "..fmt(p:GetAttribute("Moins") or 0)) or p:GetAttribute("MoinsLoadFailed") and "WALLET UNAVAILABLE" or "WALLET LOADING…"
 local ready=false for _,v in catalog:GetChildren() do if v:GetAttribute("Ready") then ready=true end end
 footer.Text=ready and "Purchases are confirmed securely by Roblox." or "Bundles coming soon."
 local camera=workspace.CurrentCamera
 if camera then
 local v=shade.AbsoluteSize local w=math.min(930,v.X-24) local h=math.min(650,v.Y-24)
 panel.Size=UDim2.fromOffset(w,h)
 local compact=h<480
 local contentTop=w<600 and 98 or compact and 68 or 108
 trim.Position=UDim2.fromOffset(24,contentTop-10)
 scroll.Position=UDim2.fromOffset(24,contentTop)
 scroll.Size=UDim2.new(1,-48,1,-contentTop-60)

 local cols=w>=690 and 3 or w>=450 and 2 or 1
 local cardW=(w-54-(cols-1)*14)/cols local cardH=math.clamp(cardW*.76,180,245)
 if compact then cardH=math.max(150,math.min(cardH,h-contentTop-64)) end
 layout.CellSize=UDim2.fromOffset(cardW,cardH)
 scroll.CanvasSize=UDim2.fromOffset(0,math.ceil(#Config.Bundles/cols)*(cardH+14))
 masks.Visible=w>=700 and not compact
 header.TextSize=w<450 and 28 or 36 header.Size=UDim2.fromOffset(math.min(300,w- 70),40)
 balance.Position=w<600 and UDim2.new(1,-255,0,55) or UDim2.new(1,-285,0, 20) balance.TextSize=w<450 and 12 or 18
 sub.Visible=w>=600 and not compact
 for _,card in cards do
 card.Amount.TextSize=cardW<230 and 23 or 28
 card.FallbackArt.Visible=not card.BundleArt.IsLoaded
 end
 end
 task.wait(.2)
end end)
