EvilHeadcrab = EvilHeadcrab or {}
EvilHeadcrab.HEAD = "ValveBiped.Bip01_Head1"

EvilHeadcrab.Settings = Evil.Settings({
	id = "evil_headcrab",
	title = "Evil headcrabs",
	rows = {
		{ name = "targets_npcs", default = 1, min = 0, max = 1, label = "Targets NPCs", help = "Leaps onto NPCs' heads and takes them over" },
		{ name = "capture_time", default = 12.5, min = 1, max = 60, decimals = 1, label = "Capture time", lock = "instant_capture", help = "Seconds a victim struggles before the headcrab fully has them" },
		{ name = "instant_capture", default = 0, min = 0, max = 1, label = "Instantly capture victims", help = "Victims are taken over the moment it lands on them" },
	},
})
