AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MODEL = "models/headcrabclassic.mdl"
local HEALTH = 10
local SEAT = Angle(-90, 180, 90)
local MINS, MAXS = Vector(-12, -12, -6), Vector(12, 12, 16)
local STRUGGLE_MIN, STRUGGLE_MAX = 10, 15
local CLING = 176 / 30
local RUN_SPEED = 190
local STEP = 18
local DROP = 48
local TURN = 360
local FADE = 0.8
local SLUMP_FROM = 0.75
local CORPSE_PUSH = 150
local RUNS = { ACT_RUN_PROTECTED, ACT_RUN_PANICKED, ACT_RUN }
local IDLES = { "idle_unarmed", "idle_subtle" }
local SLUMP = {
	["ValveBiped.Bip01_Spine"] = Angle(0, 6, 0),
	["ValveBiped.Bip01_Spine1"] = Angle(0, 8, 0),
	["ValveBiped.Bip01_Spine2"] = Angle(0, 8, 0),
	["ValveBiped.Bip01_Spine4"] = Angle(0, 6, 0),
	["ValveBiped.Bip01_Neck1"] = Angle(0, -15, 0),
	["ValveBiped.Bip01_Head1"] = Angle(8, -25, 0),
}

local function Valid(seq)
	return seq and seq > 0 and seq or nil
end

local function RunSequence(v)
	for _, act in ipairs(RUNS) do
		local seq = Valid(v:SelectWeightedSequence(act))
		if seq then return seq end
	end
end

local function IdleSequence(v)
	for _, name in ipairs(IDLES) do
		local seq = Valid(v:LookupSequence(name))
		if seq then return seq end
	end
	return Valid(v:SelectWeightedSequence(ACT_IDLE))
end

function ENT:Initialize()
	self:SetModel(MODEL)
	self:SetHealth(self.carried or HEALTH)
	self:SetMaxHealth(HEALTH)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionBounds(MINS, MAXS)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetBloodColor(BLOOD_COLOR_GREEN)
end

function ENT:Cling(seq, rate)
	self:ResetSequence(seq)
	self:SetCycle(0)
	self:SetPlaybackRate(rate)
end

function ENT:Grab(v)
	local head = v:LookupBone(EvilHeadcrab.HEAD)
	if not head then return false end
	self.victim = v
	self.pos = v:GetPos()
	self.yaw = v:GetAngles().y
	self.heading = self.yaw
	self.speed = 0
	self.runSeq = RunSequence(v)
	self.idleSeq = IdleSequence(v)
	self.prySeq = Valid(v:LookupSequence("headcrabbed"))
	self.runGround = self.runSeq and v:GetSequenceGroundSpeed(self.runSeq) or 0
	if self.runGround < 1 then self.runGround = RUN_SPEED end
	if not Evil.Pose(v, self, { sequence = self.idleSeq }) then
		self.victim = nil
		return false
	end
	self.seed = math.Rand(0, 100)
	self.start = CurTime()
	self.done = self.start + math.Rand(STRUGGLE_MIN, STRUGGLE_MAX)
	self.beatEnd = 0
	self.last = self.start
	self.bones = {}
	for name, ang in pairs(SLUMP) do
		local b = v:LookupBone(name)
		if b then self.bones[b] = { base = v:GetManipulateBoneAngles(b), add = ang } end
	end
	v:SetNW2Float("EvilCrabbed", self.start)
	v:SetNW2Float("EvilCrabDone", self.done)
	self:FollowBone(v, head)
	self:SetLocalPos(vector_origin)
	self:SetLocalAngles(SEAT)
	self:Cling("headcrabbed", CLING / (self.done - self.start))
	self:EmitSound("NPC_HeadCrab.Bite")
	return true
end

function ENT:EvilPose()
	if self.pos then return self.pos, Angle(0, self.yaw, 0) end
end

function ENT:Play(seq, rate, loop, cycle)
	local v = self.victim
	if not seq then return end
	if not cycle and seq == v:GetSequence() then cycle = v:GetCycle() end
	Evil.Pose(v, self, { sequence = seq, rate = rate, loop = loop })
	if cycle then v:SetCycle(cycle) end
end

function ENT:Pry(seconds)
	self.speed = math.Rand(0, 20)
	self.heading = self.yaw + math.Rand(-60, 60)
	self.beatEnd = CurTime() + (seconds or math.Rand(1, 2.2))
	if self.prySeq then
		self:Play(self.prySeq, 1, false, math.Rand(0, 0.35))
	else
		self:Play(self.idleSeq, 1.5, true)
	end
end

function ENT:Beat(p)
	if p > FADE then
		self.speed = math.Rand(0, 12)
		self.heading = self.yaw + math.Rand(-40, 40)
		self.beatEnd = self.done
		self:Play(self.idleSeq, 0.6, true)
		return
	end
	local k = p / FADE
	if self.runSeq and math.random() < Lerp(k, 0.75, 0.35) then
		self.speed = RUN_SPEED * Lerp(k, 1, 0.45)
		self.heading = self.yaw + math.Rand(-120, 120)
		self.beatEnd = CurTime() + math.Rand(0.8, 2)
		self:Play(self.runSeq, self.speed / self.runGround, true)
	else
		self:Pry()
	end
	self.beatEnd = math.min(self.beatEnd, self.start + (self.done - self.start) * FADE)
end

function ENT:Walk(step)
	local v = self.victim
	local mins, maxs = v:OBBMins(), v:OBBMaxs()
	local up = Vector(0, 0, STEP)
	local filter = { v, self }
	local tr = util.TraceHull({ start = self.pos + up, endpos = self.pos + up + step, mins = mins, maxs = maxs, filter = filter, mask = MASK_NPCSOLID })
	if tr.StartSolid or tr.Hit then return end
	local down = util.TraceHull({ start = tr.HitPos, endpos = tr.HitPos - Vector(0, 0, STEP + DROP), mins = mins, maxs = maxs, filter = filter, mask = MASK_NPCSOLID })
	if down.StartSolid or not down.Hit then return end
	return down.HitPos
end

function ENT:Bump(p)
	if p < FADE then self:Pry(math.Rand(0.6, 1.2)) end
	self.speed = 0
	self.heading = self.yaw + 180 + math.Rand(-70, 70)
end

function ENT:Slump(p)
	local k = math.Clamp((p - SLUMP_FROM) / (1 - SLUMP_FROM), 0, 1)
	if self.slumped and (k == self.slumped or (k < 1 and math.abs(k - self.slumped) < 0.05)) then return end
	self.slumped = k
	k = math.ease.InOutSine(k)
	for b, s in pairs(self.bones) do
		self.victim:ManipulateBoneAngles(b, s.base + s.add * k)
	end
end

function ENT:Struggle(now, dt)
	local p = (now - self.start) / (self.done - self.start)
	if now >= self.beatEnd then self:Beat(p) end
	local vigor = 1 - p * 0.6
	local wobble = math.sin(now * 2.7 + self.seed) * 30 * vigor
	self.yaw = math.ApproachAngle(self.yaw, self.heading + wobble, TURN * vigor * dt)
	if self.speed > 0 then
		local to = self:Walk(Angle(0, self.yaw, 0):Forward() * self.speed * dt)
		if to then
			self.pos = to
		else
			self:Bump(p)
		end
	end
	self:Slump(p)
end

function ENT:Enthrall()
	self.thrall = true
	self.speed = 0
	self:Slump(1)
	self:Play(self.idleSeq, 0.5, true)
	self.victim:SetNotSolid(false)
	self:Cling("headcrabbedpost", 1)
end

function ENT:Think()
	local now = CurTime()
	local dt = now - (self.last or now)
	self.last = now
	local v = self.victim
	if v then
		if not IsValid(v) or v:Health() <= 0 or Evil.Owner(v) ~= self then
			self:FallOff()
			return
		end
		if not self.thrall then
			if now < self.done then
				self:Struggle(now, dt)
			else
				self:Enthrall()
			end
		end
	end
	self:NextThink(now)
	return true
end

function ENT:Release()
	local v = self.victim
	self.victim = nil
	if not IsValid(v) then return end
	for b, s in pairs(self.bones or {}) do
		v:ManipulateBoneAngles(b, s.base)
	end
	v:SetNW2Float("EvilCrabbed", 0)
	v:SetNW2Float("EvilCrabDone", 0)
	if Evil.Owner(v) == self then Evil.Unpose(v, self) end
end

function ENT:Handover(ent)
	local ply = self:GetCreator()
	if not IsValid(ply) then return end
	ent:SetCreator(ply)
	cleanup.Add(ply, "sents", ent)
end

function ENT:FallOff()
	local pos, yaw = self:GetPos(), self:GetAngles().y
	self:Release()
	local crab = ents.Create("evil_headcrab")
	crab:SetPos(pos)
	crab:SetAngles(Angle(0, yaw, 0))
	crab.carried = self:Health()
	crab:Spawn()
	crab:Activate()
	self:Handover(crab)
	self:Remove()
end

function ENT:OnTakeDamage(dmg)
	if self.dead then return end
	self:SetHealth(self:Health() - dmg:GetDamage())
	if self:Health() > 0 then
		self:EmitSound("NPC_HeadCrab.Pain")
		return
	end
	self.dead = true
	self:EmitSound("NPC_HeadCrab.Die")
	hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
	local pos, ang = self:GetPos(), self:GetAngles()
	self:Release()
	local body = ents.Create("prop_ragdoll")
	body:SetModel(MODEL)
	body:SetPos(pos)
	body:SetAngles(ang)
	body:Spawn()
	body:Activate()
	local push = dmg:GetDamageForce():GetNormalized() * CORPSE_PUSH
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:SetVelocity(push) end
	end
	self:Handover(body)
	self:Remove()
end

function ENT:OnRemove()
	self:Release()
end
