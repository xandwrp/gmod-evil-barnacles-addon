EvilBarnacle = EvilBarnacle or {}
EvilBarnacle.HEAD = "ValveBiped.Bip01_Head1"
EvilBarnacle.HELD_VAR = "EvilBarnacleHeld"
EvilBarnacle.GIVE_UP = 3
EvilBarnacle.LEASH_VAR = "EvilLeash"
EvilBarnacle.LEASH_BONE_VAR = "EvilLeashBone"
EvilBarnacle.ROOTED_VAR = "EvilBarnacleRooted"
EvilBarnacle.ROOT_R_VAR = "EvilBarnacleRootR"
EvilBarnacle.ROOT_L_VAR = "EvilBarnacleRootL"

EvilBarnacle.Settings = Evil.Settings({
	id = "evil_barnacle",
	title = "Evil barnacles",
	rows = {
		{ name = "escape_presses", default = 12, min = 3, max = 100, decimals = 0, label = "Jump presses to escape", help = "Roughly how many jump presses a player needs to struggle off the tongue" },
		{ name = "fungus", default = 150, min = 0, max = 1000, decimals = 0, label = "Fungus", needs = "EvilFungus",
			help = "How many strands of Evil Fungus a new barnacle grows on the ceiling around itself. At 0 it grows none" },
		{ name = "fungus_time", default = 900, min = 30, max = 3600, decimals = 0, label = "Fungus takeover", needs = "EvilFungus",
			help = "Seconds the fungus takes to turn a kept body over to itself, all but the head" },
		{ name = "leash", default = 250, min = 0, max = 1000, decimals = 0, label = "Leash", needs = "EvilFungus",
			help = "How far a body let down on the tongue can walk out from under the barnacle. At 0 it keeps them hanging" },
		{ name = "leash_after", default = 120, min = 10, max = 3600, decimals = 0, label = "Let down after", needs = "EvilFungus",
			help = "Seconds a body hangs in the fungus before the barnacle lets it down on the tongue" },
	},
})
