AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local REACH = 4096
local HANG = 2
local CEILING = -0.7
local FUNGUS_MASS = 20
local FUNGUS_PER_STRAND = 0.3

local function Ceiling(tr)
	if tr.HitNormal.z < CEILING then return tr.HitPos, tr.HitNormal end
	local start = tr.HitPos + tr.HitNormal * HANG
	local up = util.TraceLine({ start = start, endpos = start + Vector(0, 0, REACH), mask = MASK_SOLID_BRUSHONLY })
	if up.Hit and not up.HitSky and up.HitNormal.z < CEILING then return up.HitPos, up.HitNormal end
end

local function Fungus(pos, normal, ply)
	local strands = EvilBarnacle.Settings:Get("fungus")
	if strands <= 0 or not (EvilFungus and EvilFungus.Plant) then return end
	EvilFungus.Plant(pos, normal, FUNGUS_MASS + strands * FUNGUS_PER_STRAND, nil, ply, strands)
end

function ENT:SpawnFunction(ply, tr)
	if not tr.Hit then return end
	local pos, normal = Ceiling(tr)
	if not pos then return end
	local barnacle = EvilBarnacle.Spawn(pos, ply:EyeAngles().y + 180)
	if not barnacle then return end
	Fungus(pos, normal, ply)
	return barnacle
end
