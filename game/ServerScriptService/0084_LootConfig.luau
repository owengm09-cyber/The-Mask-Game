-- What can be found where. Add a Tool to ServerStorage.LootItems, list it under Items,
-- then give it a weight in any of the Tables below.
return {
	Items = {
		Bandage = { Template = "Bandage", DisplayName = "Bandage", Stack = false },
		Battery = { Template = "Battery", DisplayName = "Battery", Stack = true },
	},

	Tables = {
		-- Steel supply cabinet: 6 spots on the middle + top slabs, each has a chance to hold something.
		Cabinet = { Mode = "Slots", SlotChance = 0.5, MinItems = 2, Weights = { Bandage = 3, Battery = 2 } },
		-- Iron-banded chests: always exactly one item.
		Chest = { Mode = "One", Weights = { Bandage = 1, Battery = 1 } },
		-- Chest of drawers: each drawer has a chance to hold 1-2 batteries.
		Drawers = { Mode = "PerMover", MoverChance = 0.4, MaxPerMover = 2, Weights = { Battery = 1 } },
	},

	Timing = { Cabinet = 0.55, Chest = 0.7, Drawer = 0.35 },

	Sounds = {
		Cabinet = { Id = "rbxassetid://9114135682", Volume = 0.45, OpenSpeed = 1.45, CloseSpeed = 1.6 },
		Chest = { Id = "rbxassetid://9114135682", Volume = 0.55, OpenSpeed = 0.8, CloseSpeed = 0.95 },
		Drawer = { Id = "rbxassetid://9113658569", Volume = 0.5, OpenSpeed = 1, CloseSpeed = 1.1 },
	},
}
