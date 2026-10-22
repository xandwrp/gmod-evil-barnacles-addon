include("shared.lua")

language.Add("evil_headcrab_latched", "Evil headcrab")

local function Facing(v)
	return Angle(0, v:GetNW2Float("EvilCrabYaw", v:GetRenderAngles().y), 0)
end

function ENT:EvilPose(v)
	if v:IsPlayer() then return v:GetPos(), Facing(v) end
end

function ENT:Draw(flags)
	local v = self:GetParent()
	if not IsValid(v) or not v:IsPlayer() or not Evil.Posed(v) then
		self:DrawModel(flags)
		return
	end
	local origin, was = v:GetPos(), self:GetRenderAngles()
	local lp, la = WorldToLocal(self:GetPos(), self:GetAngles(), origin, Angle(0, v:GetRenderAngles().y, 0))
	local pos, ang = LocalToWorld(lp, la, origin, Facing(v))
	self:SetRenderOrigin(pos)
	self:SetRenderAngles(ang)
	self:InvalidateBoneCache()
	self:SetupBones()
	self:DrawModel(flags)
	self:SetRenderOrigin(nil)
	self:SetRenderAngles(was)
	self:InvalidateBoneCache()
end
