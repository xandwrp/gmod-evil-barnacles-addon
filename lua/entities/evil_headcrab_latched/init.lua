AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MODEL = "models/headcrabclassic.mdl"
local HEALTH = 10
local SEAT = Angle(-90, 180, 90)
local MINS, MAXS = Vector(-12, -12, -6), Vector(12, 12, 16)
local CLING = 176 / 30
local SUCKLE = 0.25
local RUN_SLOW, RUN_FAST = 90, 270
local RUN_RATE_MAX = 1.7
local CIRCLE_SPEED = 110
local CIRCLE_TURN = 420
local STAGGER_SLOW, STAGGER_FAST = 8, 45
local TURN_SLOW, TURN_FAST = 140, 600
local SWERVE_SLOW, SWERVE_FAST = 8, 40
local SWERVE_HZ_SLOW, SWERVE_HZ_FAST = 0.3, 0.9
local JOLT = 12
local PRY_END = 0.4
local STEP = 18
local DROP = 48
local FADE = 0.88
local CORPSE_PUSH = 150
local RUNS = { ACT_RUN_PROTECTED, ACT_RUN_PANICKED, ACT_RUN }
local IDLES = { "idle_unarmed", "idle_subtle" }
local UNARMED_IDLES = {
	["models/monk.mdl"] = "LineIdle01",
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
	local unarmed = Valid(v:LookupSequence(UNARMED_IDLES[string.lower(v:GetModel() or "")] or ""))
	if unarmed then return unarmed end
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
	self.swerve = 0
	self.recoil = 0
	self.pryCycle = 0
	self.runSeq = RunSequence(v)
	self.idleSeq = IdleSequence(v)
	self.prySeq = Valid(v:LookupSequence("headcrabbed"))
	self.runGround = self.runSeq and v:GetSequenceGroundSpeed(self.runSeq) or 0
	if self.runGround < 1 then self.runGround = RUN_FAST end
	if not Evil.Pose(v, self, { sequence = self.idleSeq }) then
		self.victim = nil
		return false
	end
	self.seed = math.Rand(0, 100)
	self.start = CurTime()
	self.done = self.start + (EvilHeadcrab.Settings:Get("instant_capture") ~= 0 and 0 or EvilHeadcrab.Settings:Get("capture_time"))
	self.beatEnd = 0
	self.last = self.start
	v:SetNW2Float("EvilCrabbed", self.start)
	v:SetNW2Float("EvilCrabDone", self.done)
	self:FollowBone(v, head)
	self:SetLocalPos(vector_origin)
	self:SetLocalAngles(SEAT)
	if self.done > self.start then
		self:Cling("headcrabbed", CLING / (self.done - self.start))
	else
		self:Enthrall()
	end
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

function ENT:SavePry()
	local v = self.victim
	if self.mode ~= "pry" or not self.prySeq or v:GetSequence() ~= self.prySeq then return end
	local c = v:GetCycle()
	self.pryCycle = c < PRY_END and c or 0
end

function ENT:Pry(i, seconds)
	self:SavePry()
	self.mode = "pry"
	self.speed = Lerp(i, STAGGER_SLOW, STAGGER_FAST)
	self.heading = self.yaw + math.Rand(-90, 90)
	self.beatEnd = CurTime() + (seconds or math.Rand(0.6, 1.2) * Lerp(i, 1.8, 1))
	if self.prySeq then
		self:Play(self.prySeq, Lerp(i, 0.8, 1.3), false, self.pryCycle)
	else
		self:Play(self.idleSeq, Lerp(i, 1, 2), true)
	end
end

function ENT:Run(speed)
	self:SavePry()
	self.speed = speed
	self:Play(self.runSeq, math.min(speed / self.runGround, RUN_RATE_MAX), true)
end

function ENT:Beat(p, i)
	local now = CurTime()
	if p > FADE then
		self:SavePry()
		self.mode = "fade"
		self.speed = math.Rand(0, 10)
		self.heading = self.yaw + math.Rand(-30, 30)
		self.beatEnd = self.done
		self:Play(self.idleSeq, 0.5, true)
		return
	end
	local roll, run = math.random(), Lerp(i, 0.3, 0.8)
	if self.runSeq and roll < run then
		self.mode = "run"
		self.heading = self.yaw + math.Rand(-1, 1) * Lerp(i, 50, 160)
		self.beatEnd = now + math.Rand(0.5, 1.4) * Lerp(i, 1.5, 0.8)
		self:Run(Lerp(i, RUN_SLOW, RUN_FAST))
	elseif self.runSeq and roll < run + 0.2 * i then
		self.mode = "circle"
		self.spin = (math.random(2) == 1 and 1 or -1) * CIRCLE_TURN * i
		self.beatEnd = now + math.Rand(0.7, 1.4)
		self:Run(CIRCLE_SPEED * i)
	else
		self:Pry(i)
	end
	self.beatEnd = math.min(self.beatEnd, self.start + (self.done - self.start) * FADE)
end

function ENT:Walk(step)
	local v = self.victim
	local mins, maxs = v:OBBMins(), v:OBBMaxs()
	local up = Vector(0, 0, STEP)
	local filter = { v, self }
	local tr = util.TraceHull({ start = self.pos + up, endpos = self.pos + up + step, mins = mins, maxs = maxs, filter = filter, mask = MASK_NPCSOLID })
	if tr.StartSolid then return end
	if tr.Hit then return nil, tr.HitNormal end
	local down = util.TraceHull({ start = tr.HitPos, endpos = tr.HitPos - Vector(0, 0, STEP + DROP), mins = mins, maxs = maxs, filter = filter, mask = MASK_NPCSOLID })
	if down.StartSolid or not down.Hit then return end
	return down.HitPos
end

function ENT:Bump(i, wall)
	if (self.mode ~= "run" or math.random() > i) and self.mode ~= "pry" then
		self:Pry(i, math.Rand(0.4, 0.9))
	end
	local dir = Angle(0, self.yaw, 0):Forward()
	local n = wall and Vector(wall.x, wall.y, 0)
	if n and n:LengthSqr() > 0.01 then
		n:Normalize()
		self.heading = (dir - n * (2 * dir:Dot(n))):Angle().y + math.Rand(-35, 35)
		self.yaw = self.yaw + math.Rand(-JOLT, JOLT) * i
	else
		self.heading = self.yaw + 180 + math.Rand(-40, 40)
	end
	self.recoil = CurTime() + math.Rand(0.15, 0.35)
end

function ENT:Struggle(now, dt)
	local p = (now - self.start) / (self.done - self.start)
	local i = EvilHeadcrab.Intensity(p)
	if now >= self.beatEnd then self:Beat(p, i) end
	if self.mode == "circle" then self.heading = self.heading + self.spin * dt end
	self.swerve = self.swerve + dt * Lerp(i, SWERVE_HZ_SLOW, SWERVE_HZ_FAST) * math.pi * 2
	local swerve = (math.sin(self.swerve) + 0.4 * math.sin(self.swerve * 2.3 + self.seed)) * Lerp(i, SWERVE_SLOW, SWERVE_FAST)
	self.yaw = math.ApproachAngle(self.yaw, self.heading + swerve, Lerp(i, TURN_SLOW, TURN_FAST) * dt)
	if self.speed > 0 and now >= self.recoil then
		local to, wall = self:Walk(Angle(0, self.yaw, 0):Forward() * self.speed * dt)
		if to then
			self.pos = to
		else
			self:Bump(i, wall)
		end
	end
end

function ENT:Enthrall()
	self.thrall = true
	self.speed = 0
	self:Play(self.idleSeq, 0.5, true)
	self.victim:SetNotSolid(false)
	self:Cling("headcrabbedpost", SUCKLE)
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
