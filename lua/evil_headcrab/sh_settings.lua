EvilHeadcrab = EvilHeadcrab or {}
EvilHeadcrab.HEAD = "ValveBiped.Bip01_Head1"
EvilHeadcrab.SEAT = Angle(-90, 180, 90)

EvilHeadcrab.Settings = Evil.Settings({
	id = "evil_headcrab",
	title = "Evil headcrabs",
	rows = {
		{ name = "targets_npcs", default = 1, min = 0, max = 1, label = "Targets NPCs", help = "Leaps onto NPCs' heads and takes them over" },
		{ name = "targets_players", default = 0, min = 0, max = 1, label = "Targets players", help = "Leaps onto players' heads too, they have to mash jump to pry it off" },
		{ name = "escape_presses", default = 25, min = 5, max = 100, decimals = 0, label = "Jump presses to escape", help = "Roughly how many jump presses a player needs to pry it off" },
		{ name = "hold_time", default = 20, min = 1, max = 120, decimals = 1, label = "Hold time", help = "Seconds the headcrab holds on before an NPC pries it off" },
		{ name = "barnacle_range", default = 2000, min = 0, max = 10000, decimals = 0, label = "Barnacle sense range", help = "How far the headcrab senses an evil barnacle to steer its victim toward, 0 for never" },
	},
})
