AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local REACH = 4096
local HANG = 2
local CEILING = -0.7

local function Ceiling(tr)
	if tr.HitNormal.z < CEILING then return tr.HitPos end
	local start = tr.HitPos + tr.HitNormal * HANG
	local up = util.TraceLine({ start = start, endpos = start + Vector(0, 0, REACH), mask = MASK_SOLID_BRUSHONLY })
	if up.Hit and not up.HitSky and up.HitNormal.z < CEILING then return up.HitPos end
end

function ENT:SpawnFunction(ply, tr)
	if not tr.Hit then return end
	local pos = Ceiling(tr)
	if not pos then return end
	local barnacle = ents.Create("npc_barnacle")
	barnacle:SetPos(pos - Vector(0, 0, HANG))
	barnacle:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	barnacle:Spawn()
	barnacle:Activate()
	barnacle.EvilBarnacle = true
	return barnacle
end
