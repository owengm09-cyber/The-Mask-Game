local Config=require(game.ReplicatedStorage.FortuneConfig)
local View={}
local gold=Color3.fromRGB(203,171,111)
local cream=Color3.fromRGB(245,231,203)
local plum=Color3.fromRGB(35,23,43)
local function make(class,props,parent)
	local o=Instance.new(class);for k,v in props do o[k]=v end;o.Parent=parent;return o
end
local function text(parent,name,content,pos,size,font,max,color)
	local t=make("TextLabel",{Name=name,Text=content,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=color or cream,Font=font or Enum.Font.Garamond,TextScaled=true,TextWrapped=true,ZIndex=4},parent)
	make("UITextSizeConstraint",{MaxTextSize=max or 22,MinTextSize=10},t)
	return t
end
local function button(parent,name,content,pos,size)
	local b=make("TextButton",{Name=name,Text=content,Position=pos,Size=size,BackgroundColor3=plum,TextColor3=cream,Font=Enum.Font.Garamond,TextSize=21,BorderSizePixel=0,AutoButtonColor=false,Selectable=true,ZIndex=10},parent)
	make("UIStroke",{Color=gold,Thickness=1,Transparency=.25,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
	return b
end
function View.Build(parent)
	local ui={}
	ui.Gui=make("ScreenGui",{Name="ZoltarFortunes",ResetOnSpawn=false,DisplayOrder=35,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false},parent)
	ui.Wallet=make("Frame",{Name="Wallet",Position=UDim2.new(1,-174,0,150),Size=UDim2.fromOffset(154,48),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=10},ui.Gui)
    ui.WalletIcon=make("ImageLabel",{Name="MoinsIcon",Image="rbxthumb://type=Asset&id=79626820412304&w=150&h=150",BackgroundTransparency=1,Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(40,40),ScaleType=Enum.ScaleType.Fit,ZIndex=11},ui.Wallet)
    ui.WalletAmount=text(ui.Wallet,"Amount","...",UDim2.fromOffset(52,4),UDim2.new(1,-60,1,-8),Enum.Font.GothamBold,22,cream)
    ui.WalletAmount.ZIndex=11
    ui.WalletAmount.TextXAlignment=Enum.TextXAlignment.Left
    ui.WalletAmount.TextWrapped=false
    ui.WalletAmount.TextScaled=false
    ui.WalletAmount.TextSize=22
    ui.WalletAmount.TextTruncate=Enum.TextTruncate.AtEnd
	-- Balance-only HUD.
	ui.Toast=make("TextLabel",{Name="Notice",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,.12),Size=UDim2.new(.58,0,0,54),BackgroundColor3=plum,BackgroundTransparency=.08,TextColor3=cream,Font=Enum.Font.Garamond,TextSize=23,TextWrapped=true,Visible=false,ZIndex=20,BorderSizePixel=0},ui.Gui)
	make("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)},ui.Toast)
	ui.Dimmer=make("Frame",{Name="Dimmer",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(13,8,17),BackgroundTransparency=.68,BorderSizePixel=0,Visible=false,ZIndex=1,Active=true},ui.Gui)
	ui.Board=make("Frame",{Name="TarotTable",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.52),Size=UDim2.fromOffset(760,500),BackgroundColor3=plum,BackgroundTransparency=.07,BorderSizePixel=0,Visible=false,ZIndex=2},ui.Gui)
	make("UIStroke",{Color=gold,Thickness=1.5,Transparency=.1},ui.Board)
	local inner=make("Frame",{Name="InsetRule",Position=UDim2.fromOffset(7,7),Size=UDim2.new(1,-14,1,-14),BackgroundTransparency=1,ZIndex=3},ui.Board)
	make("UIStroke",{Color=gold,Thickness=1,Transparency=.66},inner)
	make("ImageLabel",{Name="ProvidedTarotTable",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=Config.TableImage,ImageTransparency=.32,ScaleType=Enum.ScaleType.Crop,ZIndex=2},ui.Board)
	ui.Title=text(ui.Board,"Title","Choose your fortune",UDim2.fromScale(.12,.055),UDim2.fromScale(.76,.085),Enum.Font.Garamond,36)
	ui.Subtitle=text(ui.Board,"Subtitle","Three paths. One card. 50 MOINS.",UDim2.fromScale(.16,.14),UDim2.fromScale(.68,.047),Enum.Font.Garamond,20,Color3.fromRGB(224,205,177))
	ui.Odds=text(ui.Board,"DropOdds","Select a deck to see its drop chances.",UDim2.fromScale(.06,.19),UDim2.fromScale(.88,.055),Enum.Font.Gotham,13,gold)
    ui.Odds.TextWrapped=false
	ui.Close=button(ui.Board,"Close","Close",UDim2.new(1,-78,0,12),UDim2.fromOffset(64,38))
	ui.Decks={}
	for i,category in Config.Categories do
		local x=.245+(i-1)*.255
		local slot=make("Frame",{Name=category.Key.."Stack",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,.465),Size=UDim2.fromScale(.22,.43),BackgroundTransparency=1,ZIndex=4},ui.Board)
		for layer=2,1,-1 do
			make("ImageLabel",{Name="StackLayer"..layer,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,layer*4,.5,layer*4),Size=UDim2.fromScale(1,1),Rotation=(i-2)*2+layer*2,BackgroundTransparency=1,Image=category.Image,ImageColor3=Color3.fromRGB(158,140,163),ScaleType=Enum.ScaleType.Fit,ZIndex=4},slot)
		end
		local b=make("ImageButton",{Name=category.Key,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=category.Image,ScaleType=Enum.ScaleType.Fit,AutoButtonColor=false,Selectable=true,Rotation=(i-2)*2,ZIndex=6},slot)
		local scale=make("UIScale",{Scale=1},b)
		local label=text(ui.Board,category.Key.."Caption",category.Title,UDim2.fromScale(x-.115,.704),UDim2.fromScale(.23,.072),Enum.Font.Garamond,23)
		local rule=make("Frame",{Name="SelectedRule",Position=UDim2.fromScale(x-.045,.785),Size=UDim2.fromScale(.09,.003),BackgroundColor3=category.Color,BorderSizePixel=0,Visible=false,ZIndex=7},ui.Board)
		ui.Decks[category.Key]={Button=b,Scale=scale,Caption=label,Rule=rule,Slot=slot,Category=category,Rotation=(i-2)*2}
	end
	ui.Status=text(ui.Board,"Status","Hover over a deck to explore it.",UDim2.fromScale(.10,.805),UDim2.fromScale(.80,.05),Enum.Font.Garamond,18,Color3.fromRGB(235,216,187))
	ui.Draw=button(ui.Board,"Draw","Choose a deck",UDim2.new(.5,-135,1,-57),UDim2.fromOffset(270,43))
	ui.Draw.BackgroundColor3=Color3.fromRGB(81,56,43)
	ui.Reveal=make("Frame",{Name="FortuneReveal",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(332,490),BackgroundColor3=Color3.fromRGB(40,27,48),BorderSizePixel=0,Visible=false,ZIndex=15},ui.Gui)
	make("UIStroke",{Color=gold,Thickness=2},ui.Reveal)
	ui.RevealImage=make("ImageLabel",{Name="CardArt",Position=UDim2.fromScale(.15,.035),Size=UDim2.fromScale(.7,.48),BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,ZIndex=16},ui.Reveal)
	ui.RevealTitle=text(ui.Reveal,"CardTitle","Your fortune",UDim2.fromScale(.07,.54),UDim2.fromScale(.86,.075),Enum.Font.Garamond,31)
	ui.RevealBody=text(ui.Reveal,"Description","",UDim2.fromScale(.09,.63),UDim2.fromScale(.82,.18),Enum.Font.Garamond,21)
	ui.RevealSaved=text(ui.Reveal,"Saved","Saved to your collection • Equipped",UDim2.fromScale(.07,.81),UDim2.fromScale(.86,.05),Enum.Font.Garamond,16,gold)
	ui.RevealClose=button(ui.Reveal,"KeepFortune","Keep my fortune",UDim2.new(.5,-110,1,-57),UDim2.fromOffset(220,43))
	return ui
end
return View
