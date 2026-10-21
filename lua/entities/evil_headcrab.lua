AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil headcrab"
ENT.Category = "Syhgma's Evil Entities"
ENT.Spawnable = true
ENT.IconOverride = "entities/npc_headcrab.png"

if CLIENT then return end

function ENT:SpawnFunction(ply, tr)
	if not tr.Hit then return end
	local crab = ents.Create("prop_ragdoll")
	crab:SetModel("models/headcrabclassic.mdl")
	crab:SetPos(tr.HitPos + tr.HitNormal * 8)
	crab:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	crab:Spawn()
	crab:Activate()
	return crab
end
