EvilBarnacle = EvilBarnacle or {}
EvilBarnacle.HEAD = "ValveBiped.Bip01_Head1"
EvilBarnacle.HELD_VAR = "EvilBarnacleHeld"
EvilBarnacle.GIVE_UP = 3

EvilBarnacle.Settings = Evil.Settings({
	id = "evil_barnacle",
	title = "Evil barnacles",
	rows = {
		{ name = "escape_presses", default = 12, min = 3, max = 100, decimals = 0, label = "Jump presses to escape", help = "Roughly how many jump presses a player needs to struggle off the tongue" },
		{ name = "fungus", default = 150, min = 0, max = 1000, decimals = 0, label = "Fungus", needs = "EvilFungus",
			help = "How many strands of Evil Fungus a new barnacle grows on the ceiling around itself. At 0 it grows none" },
		{ name = "fungus_time", default = 900, min = 30, max = 3600, decimals = 0, label = "Fungus takeover", needs = "EvilFungus",
			help = "Seconds the fungus takes to turn a kept body over to itself, all but the head" },
	},
})
