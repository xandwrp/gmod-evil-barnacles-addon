EvilBarnacle = EvilBarnacle or {}
EvilBarnacle.HEAD = "ValveBiped.Bip01_Head1"

EvilBarnacle.Settings = Evil.Settings({
	id = "evil_barnacle",
	title = "Evil barnacles",
	rows = {
		{ name = "escape_presses", default = 12, min = 3, max = 100, decimals = 0, label = "Jump presses to escape", help = "Roughly how many jump presses a player needs to struggle off the tongue" },
	},
})
