include("shared.lua")

language.Add("evil_headcrab_latched", "Evil headcrab")

local function Facing(v)
	return Angle(0, v:GetNW2Float("EvilCrabYaw", v:GetRenderAngles().y), 0)
end

local STILL = { "move_y", "aim_yaw", "aim_pitch", "head_yaw", "head_pitch" }

local function Stride(v)
	v:SetPoseParameter("move_x", v:GetNW2Bool("EvilCrabRunning") and 1 or 0)
	for _, name in ipairs(STILL) do v:SetPoseParameter(name, 0) end
end

function ENT:EvilPose(v)
	if not v:IsPlayer() then return end
	Stride(v)
	return v:GetPos(), Facing(v)
end

local function Head(v)
	local bone = v:LookupBone(EvilHeadcrab.HEAD)
	if not bone then return end
	Stride(v)
	local was = v:GetRenderAngles()
	v:SetRenderOrigin(v:GetPos())
	v:SetRenderAngles(Facing(v))
	v:InvalidateBoneCache()
	v:SetupBones()
	local m = v:GetBoneMatrix(bone)
	v:SetRenderOrigin(nil)
	v:SetRenderAngles(was)
	v:InvalidateBoneCache()
	return m
end

function ENT:Draw(flags)
	local v = self:GetParent()
	local m = IsValid(v) and v:IsPlayer() and Evil.Posed(v) and Head(v)
	if not m then
		self:DrawModel(flags)
		return
	end
	local was = self:GetRenderAngles()
	local pos, ang = LocalToWorld(vector_origin, EvilHeadcrab.SEAT, m:GetTranslation(), m:GetAngles())
	self:SetRenderOrigin(pos)
	self:SetRenderAngles(ang)
	self:InvalidateBoneCache()
	self:SetupBones()
	self:DrawModel(flags)
	self:SetRenderOrigin(nil)
	self:SetRenderAngles(was)
	self:InvalidateBoneCache()
end
