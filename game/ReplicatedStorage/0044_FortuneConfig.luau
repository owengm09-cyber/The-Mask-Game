local C = {
	Price = 50,
	StartingMOINS = 100,
	SessionSeconds = 75,
	DataStoreName = "TheMaskFortunes_v1",
	TableImage = "rbxassetid://97147353911452",
	Categories = {
		{Key="SurvivorPerks", Title="Survivor Perk", Image="rbxassetid://115754903339880", Color=Color3.fromRGB(167,204,222)},
		{Key="KillerPerks", Title="Killer Perk", Image="rbxassetid://102394176823032", Color=Color3.fromRGB(207,135,128)},
		{Key="SurvivorWeapons", Title="Survivor Weapon", Image="rbxassetid://119330139895410", Color=Color3.fromRGB(192,173,216)},
	},
	-- Initial playable rewards. Extend these lists when the full card catalogue is ready.
	Cards = {
		SurvivorPerks = {
            {Id="high_ground", Name="High Ground", Rarity="Common", Description="As a survivor, gain 1.5 studs of jump height (or 8 jump power).", Kind="SurvivorPerks", JumpHeightBonus=1.5, JumpPowerBonus=8},
            {Id="high_ground_rare", Name="High Ground II", Rarity="Rare", Description="Rare upgrade: gain 3 studs of jump height (or 16 jump power) as a survivor.", Kind="SurvivorPerks", JumpHeightBonus=3, JumpPowerBonus=16},
        },
		KillerPerks = {
            {Id="long_reach", Name="Long Reach", Rarity="Common", Description="Your killer strike gains 1.5 studs of reach.", Kind="KillerPerks", ReachBonus=1.5},
            {Id="long_reach_rare", Name="Long Reach II", Rarity="Rare", Description="Rare upgrade: your killer strike gains 3 studs of reach.", Kind="KillerPerks", ReachBonus=3},
        },
		SurvivorWeapons = {{Id="camp_hatchet", Name="Camp Hatchet", Description="A camp hatchet for survivors. Strike nearby killers for 25 damage. It cannot hurt other survivors.", Kind="SurvivorWeapons"}},
	},
}
function C.Category(key)
	for _, category in C.Categories do if category.Key==key then return category end end
end
function C.Card(id)
	for _, cards in C.Cards do for _, card in cards do if card.Id==id then return card end end end
end
return C
