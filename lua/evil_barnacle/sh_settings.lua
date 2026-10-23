EvilBarnacle = EvilBarnacle or {}
EvilBarnacle.HEAD = "ValveBiped.Bip01_Head1"
EvilBarnacle.HELD_VAR = "EvilBarnacleHeld"
EvilBarnacle.GIVE_UP = 3
EvilBarnacle.LEASH_VAR = "EvilLeash"
EvilBarnacle.LEASH_BONE_VAR = "EvilLeashBone"
EvilBarnacle.ROOTED_VAR = "EvilBarnacleRooted"
EvilBarnacle.ROOT_R_VAR = "EvilBarnacleRootR"
EvilBarnacle.ROOT_L_VAR = "EvilBarnacleRootL"
EvilBarnacle.CAIRNE_VAR = "EvilCairne"
EvilBarnacle.CAIRNE_AT_VAR = "EvilCairneAt"
EvilBarnacle.CAIRNE_UP_VAR = "EvilCairneUp"
EvilBarnacle.CAIRNE_ROPE_VAR = "EvilCairneRope"
EvilBarnacle.CAIRNE_HOIST = 7
EvilBarnacle.CAIRNE_WRAP = 12
EvilBarnacle.CAIRNE_SPREAD = 0.4
EvilBarnacle.CAIRNE_ROPES = {
	"ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Foot", "ValveBiped.Bip01_L_Foot",
	"ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Pelvis",
}
EvilBarnacle.CAIRNE_ORDER = {
	["ValveBiped.Bip01_Pelvis"] = 0,
	["ValveBiped.Bip01_Spine"] = 0.1, ["ValveBiped.Bip01_Spine1"] = 0.1, ["ValveBiped.Bip01_Spine2"] = 0.1, ["ValveBiped.Bip01_Spine4"] = 0.1,
	["ValveBiped.Bip01_R_Thigh"] = 0.2, ["ValveBiped.Bip01_L_Thigh"] = 0.2,
	["ValveBiped.Bip01_R_UpperArm"] = 0.25, ["ValveBiped.Bip01_L_UpperArm"] = 0.25,
	["ValveBiped.Bip01_Head1"] = 0.35,
	["ValveBiped.Bip01_R_Calf"] = 0.4, ["ValveBiped.Bip01_L_Calf"] = 0.4,
	["ValveBiped.Bip01_R_Forearm"] = 0.45, ["ValveBiped.Bip01_L_Forearm"] = 0.45,
	["ValveBiped.Bip01_R_Foot"] = 0.55, ["ValveBiped.Bip01_L_Foot"] = 0.55,
	["ValveBiped.Bip01_R_Hand"] = 0.6, ["ValveBiped.Bip01_L_Hand"] = 0.6,
}

function EvilBarnacle.Wrapped(t, bone)
	local wrap = EvilBarnacle.CAIRNE_WRAP
	local start = EvilBarnacle.CAIRNE_HOIST + (EvilBarnacle.CAIRNE_ORDER[bone] or 0.3) * wrap
	return math.Clamp((t - start) / (wrap * EvilBarnacle.CAIRNE_SPREAD), 0, 1)
end

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
		{ name = "grown", default = 6, min = 0, max = 50, decimals = 0, label = "Grown from fungus", needs = "EvilFungus",
			help = "Most barnacles fungus growing over a ceiling can sprout on its own. At 0 it sprouts none" },
		{ name = "cairne", default = 0, min = 0, max = 1, label = "Ceiling cairne", needs = "EvilFungus",
			help = "Whoever a barnacle grabs gets hoisted flat against the ceiling by tentacles and cocooned there in fungus instead of eaten" },
	},
})
