local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local Input=game:GetService("UserInputService")
local GuiService=game:GetService("GuiService")
local Content=game:GetService("ContentProvider")
local StarterGui=game:GetService("StarterGui")
local Prompts=game:GetService("ProximityPromptService")
local player=Players.LocalPlayer
local Config=require(game.ReplicatedStorage:WaitForChild("FortuneConfig"))
local View=require(game.ReplicatedStorage:WaitForChild("FortuneView"))
local Rolls=require(game.ReplicatedStorage:WaitForChild("FortuneRoll"))
local remote=game.ReplicatedStorage:WaitForChild("FortuneRemotes"):WaitForChild("FortuneEvent")
local gui=player:WaitForChild("PlayerGui")
if gui:FindFirstChild("ZoltarFortunes") then return end
local ui=View.Build(gui)
local wallet={MOINS=0,Owned={}}
local session,selected,mode,retryOnly=nil,nil,"closed",false
local savedSelection
local modalState
local RunService=game:GetService("RunService")
local cursorBinding="ZoltarFortuneCursor"
ui.Close.Modal=true
ui.RevealClose.Modal=true
local function freeCursor()
 Input.MouseBehavior=Enum.MouseBehavior.Default
 Input.MouseIconEnabled=true
end
local function modal(on)
 ui.Wallet.Visible=not on
 if on and not modalState then
  modalState={Backpack=StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack),Prompts=Prompts.Enabled,MouseBehavior=Input.MouseBehavior,MouseIconEnabled=Input.MouseIconEnabled}
  StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false);Prompts.Enabled=false
  game:GetService("Players").LocalPlayer:SetAttribute("HotbarHidden",true) -- CampHotbar
  RunService:BindToRenderStep(cursorBinding,Enum.RenderPriority.Last.Value+1,freeCursor)
  freeCursor()
 elseif not on and modalState then
  RunService:UnbindFromRenderStep(cursorBinding)
  Input.MouseBehavior=modalState.MouseBehavior;Input.MouseIconEnabled=modalState.MouseIconEnabled
  StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,modalState.Backpack);Prompts.Enabled=modalState.Prompts;modalState=nil
  game:GetService("Players").LocalPlayer:SetAttribute("HotbarHidden",nil) -- CampHotbar
 end
end
ui.Gui.Destroying:Connect(function() modal(false) end)
local toastVersion=0
local function tween(object,properties,duration)
	Tween:Create(object,TweenInfo.new(duration or .18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties):Play()
end
local function notice(message,seconds)
	toastVersion+=1;local version=toastVersion
	ui.Toast.Text=message or "";ui.Toast.Visible=message~=nil and message~=""
	if seconds then task.delay(seconds,function() if version==toastVersion then ui.Toast.Visible=false end end) end
end
local function resize()
	local camera=workspace.CurrentCamera;if not camera then return end
	local size=camera.ViewportSize
	ui.Board.Size=UDim2.fromOffset(math.min(760,size.X*.88),math.min(500,size.Y*.76))
	ui.Reveal.Size=UDim2.fromOffset(math.min(332,size.X*.78),math.min(490,size.Y*.84))
	ui.Toast.Size=UDim2.new(size.X<650 and .86 or .58,0,0,54)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	resize();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
end)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
resize()
local function updateWallet(data)
	if data and type(data.MOINS)=="number" and type(data.Owned)=="table" then wallet=data else data=nil end
	local amount=player:GetAttribute("MOINS")
	if data then amount=data.MOINS elseif type(amount)=="number" then wallet.MOINS=amount end
	ui.WalletAmount.Text=(player:GetAttribute("MOINSLoaded") and tostring(amount or wallet.MOINS or 0) or "...")
end
player:GetAttributeChangedSignal("MOINS"):Connect(function() updateWallet();remote:FireServer("Sync") end)
player:GetAttributeChangedSignal("MOINSLoaded"):Connect(function() updateWallet();remote:FireServer("Sync") end)
local function hide()
	ui.Board.Visible=false;ui.Reveal.Visible=false;ui.Dimmer.Visible=false
	modal(false)
	GuiService.SelectedObject=savedSelection and savedSelection.Parent and savedSelection or nil
	mode="closed";session=nil
end
local function reveal(card,count)
	if not card then return end
	modal(true)
	ui.Board.Visible=false;ui.Dimmer.Visible=true;ui.Reveal.Visible=true;mode="reveal"
	ui.RevealImage.Image=Config.Category(card.Kind).Image
	ui.RevealTitle.Text=card.Name..(card.Rarity=="Rare" and " · RARE" or "");ui.RevealBody.Text=card.Description
	ui.RevealSaved.Text=count and count>1 and ("Saved to your collection • "..count.." copies") or "Saved to your collection • Equipped"
	ui.RevealClose.Text="Keep my fortune"
	ui.Reveal.Position=UDim2.fromScale(.5,.53);tween(ui.Reveal,{Position=UDim2.fromScale(.5,.5)},.35)
	if Input.GamepadEnabled then GuiService.SelectedObject=ui.RevealClose end
end
local function refreshDecks()
    ui.Odds.Visible=mode=="choose"
    if selected then
        local entries={}
        for _,entry in Rolls.Odds(selected,player:GetAttribute("OwnsPerkLuck")==true) do
            table.insert(entries,entry.Card.Name.." ("..(entry.Card.Rarity or "Guaranteed")..") "..string.format("%.0f%%",entry.Chance*100))
        end
        ui.Odds.Text=table.concat(entries,"   |   ")
    else ui.Odds.Text="Select a deck to see its drop chances." end
	if mode=="choose" then ui.Subtitle.Text="50 MOINS per fortune · Your balance: "..tostring(wallet.MOINS or 0) end
	for key,deck in ui.Decks do
		local active=selected==key
		deck.Rule.Visible=active
		deck.Caption.TextColor3=active and deck.Category.Color or Color3.fromRGB(245,231,203)
		tween(deck.Scale,{Scale=active and 1.06 or 1})
		tween(deck.Button,{Position=UDim2.new(.5,0,.5,active and -9 or 0),Rotation=active and 0 or deck.Rotation})
	end
	local available=player:GetAttribute("RandomItemsAllowed")==true and player:GetAttribute("PerkLuckOwnershipLoaded")==true
	local canDraw=available and mode=="choose" and selected~=nil and (wallet.MOINS or 0)>=Config.Price
	ui.Draw.Active=canDraw;ui.Draw.Selectable=canDraw
	ui.Draw.Text=not available and "Fortunes unavailable" or not selected and "Choose a deck" or ((wallet.MOINS or 0)<Config.Price and "You need 50 MOINS" or (retryOnly and "Retry this fortune" or "Draw fortune · 50 MOINS"))
	ui.Draw.BackgroundColor3=canDraw and Color3.fromRGB(115,79,43) or Color3.fromRGB(61,46,60)
	ui.Draw.TextTransparency=canDraw and 0 or .25
end
for _,attribute in {"OwnsPerkLuck","PerkLuckOwnershipLoaded","RandomItemsAllowed"} do player:GetAttributeChangedSignal(attribute):Connect(refreshDecks) end
local function openCollection()
	if mode=="saving" or mode=="drawing" or mode=="awakening" or session then return end
	modal(true)
	savedSelection=GuiService.SelectedObject;mode="collection";retryOnly=false;ui.Reveal.Visible=false;ui.Board.Visible=true;ui.Dimmer.Visible=true
	ui.Title.Text="Your fortunes";ui.Subtitle.Text="Collected cards are saved and automatically equipped."
	ui.Draw.Visible=false;ui.Close.Visible=true;ui.Status.Text="Select a collected deck to read its card."
	selected=nil;refreshDecks()
	for key,deck in ui.Decks do
		local card=Config.Cards[key][1];local count=wallet.Owned[card.Id] or 0
		deck.Caption.Text=deck.Category.Title..(count>0 and (" · "..count) or " · Uncollected")
	end
	remote:FireServer("Sync")
end
for key,deck in ui.Decks do
	local function hover(on)
		if mode~="choose" and mode~="collection" then return end
		if retryOnly and selected~=key then return end
		if selected~=key then
			tween(deck.Scale,{Scale=on and 1.045 or 1});tween(deck.Button,{Position=UDim2.new(.5,0,.5,on and -10 or 0),Rotation=on and 0 or deck.Rotation})
		end
		if on then ui.Status.Text=mode=="collection" and "Read your collected fortune." or ("Draw from the "..string.lower(deck.Category.Title).." deck.") end
	end
	deck.Button.MouseEnter:Connect(function()hover(true)end);deck.Button.MouseLeave:Connect(function()hover(false)end)
	deck.Button.SelectionGained:Connect(function()hover(true)end);deck.Button.SelectionLost:Connect(function()hover(false)end)
	deck.Button.Activated:Connect(function()
		if mode=="collection" then
			local card=Config.Cards[key][1];local count=wallet.Owned[card.Id] or 0
			if count>0 then reveal(card,count) else ui.Status.Text="Visit Zoltar to draw your first card from this deck." end
		elseif mode=="choose" and (not retryOnly or selected==key) then
			selected=key;ui.Status.Text="A "..string.lower(deck.Category.Title).." awaits. Confirm your draw below.";refreshDecks()
		end
	end)
end
local function close()
	if mode=="saving" or mode=="drawing" or mode=="awakening" then return end
	if session then remote:FireServer("Cancel",session) end
	hide()
end
ui.Close.Activated:Connect(close);ui.RevealClose.Activated:Connect(hide)
-- Wallet is a display.
ui.Draw.Activated:Connect(function()
	if mode~="choose" or not selected or not session or (wallet.MOINS or 0)<Config.Price then return end
	mode="saving";ui.Draw.Active=false;ui.Draw.Selectable=false;ui.Draw.Text="Preparing your fortune...";ui.Close.Visible=false
	remote:FireServer("Choose",session,selected)
end)
Input.InputBegan:Connect(function(input,processed)
	if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then close() end
end)
remote.OnClientEvent:Connect(function(kind,data)
	data=data or {}
	if data.Wallet then updateWallet(data.Wallet) end
	if kind=="Wallet" then updateWallet(data);if mode=="choose" then refreshDecks() end
	elseif kind=="Awakening" then hide();mode="awakening";notice(data.Message)
	elseif kind=="Open" then
		modal(true)
		mode="choose";session=data.Session;selected=data.RetryCategory;retryOnly=data.RetryCategory~=nil
		savedSelection=GuiService.SelectedObject
		ui.Toast.Visible=false;ui.Reveal.Visible=false;ui.Dimmer.Visible=true;ui.Board.Visible=true
		ui.Title.Text="Choose your fortune";ui.Subtitle.Text="Three paths. One card. 50 MOINS."
		ui.Draw.Visible=true;ui.Close.Visible=true
		for _,deck in ui.Decks do deck.Caption.Text=deck.Category.Title end
		ui.Status.Text="Hover over a deck to explore it.";refreshDecks()
		ui.Board.Position=UDim2.fromScale(.5,.55);tween(ui.Board,{Position=UDim2.fromScale(.5,.52)},.3)
		if Input.GamepadEnabled then GuiService.SelectedObject=ui.Decks.SurvivorPerks.Button end
	elseif kind=="Saving" then mode="saving";ui.Status.Text=data.Message
	elseif kind=="Drawing" then mode="drawing";ui.Board.Visible=false;ui.Dimmer.Visible=false;modal(false);notice(data.Message)
	elseif kind=="CardReady" then mode="card";session=data.Session;notice(data.Message,12)
	elseif kind=="Reveal" then notice(nil);session=nil;reveal(data.Card,data.Count)
	elseif kind=="Error" then
		mode="choose";retryOnly=data.RetryOnly==true;ui.Close.Visible=true;ui.Status.Text=data.Message;refreshDecks()
	elseif kind=="Closed" then hide();notice(data.Message,5)
	elseif kind=="Notice" then notice(data.Message,5)
	end
end)
player.CharacterRemoving:Connect(function() if session then remote:FireServer("Cancel",session) end;hide();notice(nil) end)
task.spawn(function()
	local assets={Config.TableImage};for _,category in Config.Categories do table.insert(assets,category.Image) end
	pcall(function()Content:PreloadAsync(assets)end)
end)
updateWallet();remote:FireServer("Sync")
