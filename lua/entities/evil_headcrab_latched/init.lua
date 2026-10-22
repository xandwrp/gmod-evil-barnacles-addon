AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MODEL = "models/headcrabclassic.mdl"
local HEALTH = 10
local SEAT = Angle(-90, 180, 90)
local MINS, MAXS = Vector(-12, -12, -6), Vector(12, 12, 16)
local CLING = 176 / 30
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
local CORPSE_PUSH = 150
local RUNS = { ACT_RUN_PROTECTED, ACT_RUN_PANICKED, ACT_RUN, ACT_HL2MP_RUN_PANICKED, ACT_HL2MP_RUN_PROTECTED, ACT_HL2MP_RUN }
local IDLES = { "idle_unarmed", "idle_subtle", "idle_all_scared" }
local UNARMED_IDLES = {
	["models/monk.mdl"] = "LineIdle01",
}
local LURE_EVERY = 1
local SKIP_FOR = 20
local REPATH = 2
local WAYPOINT = 24
local GUIDE = 0.35
local GUIDE_TURN = 120
local NEAR = 120
local NEAR_SPEED = 0.6
local NEAR_SWERVE = 0.2
local UNDER = 20
local OFFER_WAIT = 8
local DROP_FIND = 4096
local THROW, THROW_UP, THROW_CLEAR = 220, 200, 16
local SHUN = 15
local FLEE = 600
local MASH_DECAY = 0.1

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
	return Valid(v:SelectWeightedSequence(ACT_IDLE)) or Valid(v:SelectWeightedSequence(ACT_HL2MP_IDLE))
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
	v.EvilCrab = self
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
	v:SetNotSolid(false)
	self.seed = math.Rand(0, 100)
	self.start = CurTime()
	self.done = self.start + EvilHeadcrab.Settings:Get("hold_time")
	self.beatEnd = 0
	self.last = self.start
	v:SetNW2Float("EvilCrabbed", self.start)
	v:SetNW2Float("EvilCrabDone", self.done)
	self:Seat(v)
	self:Cling("headcrabbed", CLING / (self.done - self.start))
	self:EmitSound("NPC_HeadCrab.Bite")
	if v:IsPlayer() then self:Resist(v) end
	return true
end

function ENT:Resist(ply)
	Evil.Mash(ply, self, {
		gain = 1 / EvilHeadcrab.Settings:Get("escape_presses"), decay = MASH_DECAY,
		done = function() if self.victim == ply then self:PryOff() end end,
	})
end

function ENT:Unresist(ply)
	local m = ply:IsPlayer() and Evil.Mashing(ply)
	if m and m.source == self then Evil.StopMash(ply) end
end

function ENT:EvilPose()
	if self.pos and not self.lifted then return self.pos, Angle(0, self.yaw, 0) end
end

function ENT:Play(seq, rate, loop, cycle)
	local v = self.victim
	if not seq then return end
	if not cycle and seq == v:GetSequence() then cycle = v:GetCycle() end
	Evil.Pose(v, self, { sequence = seq, rate = rate, loop = loop })
	if cycle then v:SetCycle(cycle) end
	if v:IsPlayer() then
		v:SetNW2Bool("EvilCrabRunning", seq == self.runSeq)
		v:SetNW2Float("EvilCrabRate", rate or 1)
	end
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

function ENT:Beat(i, g, near)
	local now = CurTime()
	local roll, run = math.random(), Lerp(g, Lerp(i, 0.3, 0.8), 1)
	if self.runSeq and (near or roll < run) then
		self.mode = "run"
		self.heading = self.yaw + math.Rand(-1, 1) * Lerp(i, 50, 160) * (1 - g)
		self.beatEnd = now + math.Rand(0.5, 1.4) * Lerp(i, 1.5, 0.8)
		self:Run(Lerp(i, RUN_SLOW, RUN_FAST) * (near and NEAR_SPEED or 1))
	elseif self.runSeq and roll < run + 0.2 * i * (1 - g) then
		self.mode = "circle"
		self.spin = (math.random(2) == 1 and 1 or -1) * CIRCLE_TURN * i
		self.beatEnd = now + math.Rand(0.7, 1.4)
		self:Run(CIRCLE_SPEED * i)
	else
		self:Pry(i)
	end
end

function ENT:Walk(step)
	local v = self.victim
	local mins, maxs = v:OBBMins(), v:OBBMaxs()
	local up = Vector(0, 0, STEP)
	local filter = function(ent) return ent ~= v and ent ~= self and ent:GetClass() ~= "npc_barnacle_tongue_tip" end
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

function ENT:Sense(now)
	local l = self.lure
	if l then
		local b = l.barnacle
		if not IsValid(b) or b:Health() <= 0 or b.EvilThrall ~= self then return self:Abandon() end
		if now < l.repath then return end
		l.repath = now + REPATH
		local path = EvilHeadcrab.Path(self.pos, l.spot)
		if not path then return self:Abandon(true) end
		l.path, l.i = path, 1
		return
	end
	if now < (self.nextLure or 0) then return end
	self.nextLure = now + LURE_EVERY
	local range = EvilHeadcrab.Settings:Get("barnacle_range")
	if range <= 0 then return end
	self.skip = self.skip or {}
	local b, spot = EvilHeadcrab.FreeBarnacle(self.pos, range, self.skip)
	if not b then return end
	local path = EvilHeadcrab.Path(self.pos, spot)
	if not path then
		self.skip[b] = now + SKIP_FOR
		return
	end
	b.EvilThrall = self
	self.lure = { barnacle = b, spot = spot, path = path, i = 1, repath = now + REPATH }
end

function ENT:Guide()
	local l = self.lure
	if not l then return end
	local flat = l.spot - self.pos
	flat.z = 0
	local dist = flat:Length()
	if dist < NEAR then return flat:Angle().y, 1, dist end
	local to = l.path[l.i] - self.pos
	to.z = 0
	if to:Length() < WAYPOINT and l.i < #l.path then
		l.i = l.i + 1
		to = l.path[l.i] - self.pos
		to.z = 0
	end
	return to:Angle().y, GUIDE, dist
end

function ENT:Struggle(now, dt, pinned)
	local p = (now - self.start) / math.max(self.done - self.start, 0.1)
	local i = EvilHeadcrab.Intensity(p)
	local aim, g, dist
	if not pinned then aim, g, dist = self:Guide() end
	if dist and dist < UNDER then return self:Present() end
	g = g or 0
	local near = dist ~= nil and dist < NEAR
	if now >= self.beatEnd or (near and self.mode ~= "run") then self:Beat(i, g, near) end
	if aim and self.mode == "run" then
		self.heading = near and aim or math.ApproachAngle(self.heading, aim, GUIDE_TURN * g * dt)
	end
	if self.mode == "circle" then self.heading = self.heading + self.spin * dt end
	self.swerve = self.swerve + dt * Lerp(i, SWERVE_HZ_SLOW, SWERVE_HZ_FAST) * math.pi * 2
	local swerve = (math.sin(self.swerve) + 0.4 * math.sin(self.swerve * 2.3 + self.seed)) * Lerp(i, SWERVE_SLOW, SWERVE_FAST) * (near and NEAR_SWERVE or 1)
	self.yaw = math.ApproachAngle(self.yaw, self.heading + swerve, Lerp(i, TURN_SLOW, TURN_FAST) * dt)
	if pinned or self.speed <= 0 or now < self.recoil then return end
	local to, wall = self:Walk(Angle(0, self.yaw, 0):Forward() * self.speed * dt)
	if to then
		self.pos = to
	else
		self:Bump(i, wall)
	end
end

function ENT:Pause()
	self.left = math.max(self.done - CurTime(), 0)
end

function ENT:Resume()
	local now = CurTime()
	self.done = now + (self.left or 0)
	self.left = nil
	self.beatEnd = 0
	self.victim:SetNW2Float("EvilCrabDone", self.done)
	if self.done > now then self:SetPlaybackRate((1 - self:GetCycle()) * CLING / (self.done - now)) end
end

function ENT:Abandon(skip)
	local l = self.lure
	self.lure = nil
	if not l then return end
	if IsValid(l.barnacle) and l.barnacle.EvilThrall == self then l.barnacle.EvilThrall = nil end
	if skip then self.skip[l.barnacle] = CurTime() + SKIP_FOR end
end

function ENT:Present()
	local b, v = self.lure.barnacle, self.victim
	self.lure = nil
	self.offer = { barnacle = b, ends = CurTime() + OFFER_WAIT }
	self:Pause()
	b:AddEntityRelationship(v, D_HT, 99)
	v:RemoveFlags(FL_NOTARGET)
end

function ENT:Withdraw(skip)
	local o = self.offer
	self.offer = nil
	if IsValid(o.barnacle) then
		if o.barnacle.EvilThrall == self then o.barnacle.EvilThrall = nil end
		if skip then self.skip[o.barnacle] = CurTime() + SKIP_FOR end
	end
	self.victim:AddFlags(FL_NOTARGET)
	self:Resume()
end

function ENT:Offer(now, dt)
	local b, v = self.offer.barnacle, self.victim
	if not IsValid(b) or b:Health() <= 0 then return self:Withdraw() end
	if v:IsPlayer() and b:GetEnemy() == v then return self:Haul(b) end
	local body = b:GetInternalVariable("m_hRagdoll")
	if b:GetEnemy() == v and IsValid(body) then return self:Grabbed(b, body) end
	if now > self.offer.ends then return self:Withdraw(true) end
	if now >= self.beatEnd then
		self:Pry(1)
		self.speed = 0
	end
	self.yaw = math.ApproachAngle(self.yaw, self.heading, TURN_SLOW * dt)
end

function ENT:Seat(ent)
	self:FollowBone(ent, ent:LookupBone(EvilHeadcrab.HEAD))
	self:SetLocalPos(vector_origin)
	self:SetLocalAngles(SEAT)
end

function ENT:Grabbed(b, body)
	self.offer = nil
	self.lifted = { barnacle = b, body = body }
	self.prey = EvilHeadcrab.Prey(body, b, true)
	self:Seat(body)
end

function ENT:Haul(b)
	local v = self.victim
	self.offer = nil
	self.hauled = { barnacle = b }
	self:Unresist(v)
	Evil.Unpose(v, self)
end

function ENT:Hang()
	local h = self.hauled
	local b = h.barnacle
	if not IsValid(b) or b:Health() <= 0 or b:GetEnemy() ~= self.victim then return self:FallOff() end
	if b:GetInternalVariable("m_bLiftingPrey") then
		h.rising = true
	elseif h.rising then
		self:EmitSound("NPC_HeadCrab.Die")
		self:Release()
		self:Remove()
	end
end

function ENT:Ride(now, dt)
	local l = self.lifted
	local b = l.barnacle
	if not IsValid(b) or b:Health() <= 0 or not IsValid(l.body) or b:GetInternalVariable("m_hRagdoll") ~= l.body then
		return self:Dropped()
	end
	if not b:GetInternalVariable("m_bLiftingPrey") then return self:Transfer() end
	EvilHeadcrab.Thrash(self.prey, now, dt)
end

function ENT:Dropped()
	local b, v = self.lifted.barnacle, self.victim
	self.lifted = nil
	EvilHeadcrab.Calm(self.prey)
	self.prey = nil
	if IsValid(b) then
		if b.EvilThrall == self then b.EvilThrall = nil end
		self.skip[b] = CurTime() + SKIP_FOR
	end
	v:AddFlags(FL_NOTARGET)
	self:Seat(v)
	local start = v:GetPos()
	local tr = util.TraceLine({ start = start, endpos = start - Vector(0, 0, DROP_FIND), mask = MASK_NPCSOLID_BRUSHONLY })
	self.pos = tr.HitPos
	self.yaw = v:GetAngles().y
	self:Resume()
end

function ENT:Transfer()
	local l = self.lifted
	local b, body, v = l.barnacle, l.body, self.victim
	local head = body:TranslateBoneToPhysBone(body:LookupBone(EvilHeadcrab.HEAD))
	local health = math.max(v:GetMaxHealth(), 1)
	b:Input("LetGo")
	local freed = not IsValid(b:GetInternalVariable("m_hRagdoll"))
	if not freed then
		self:EmitSound("NPC_HeadCrab.Die")
		self:Release()
		self:Remove()
		return
	end
	self.lifted = nil
	self.dead = true
	self:Release()
	self:SetNotSolid(true)
	v:Remove()
	EvilHeadcrab.Bond(b, body, head, health, self)
end

function ENT:Think()
	local now = CurTime()
	local dt = now - (self.last or now)
	self.last = now
	local v = self.victim
	if v then
		if not IsValid(v) or v:Health() <= 0 or (not self.hauled and Evil.Owner(v) ~= self) then
			self:FallOff()
			return
		end
		if self.hauled then
			self:Hang()
		elseif self.lifted then
			self:Ride(now, dt)
		elseif self.offer then
			self:Offer(now, dt)
		elseif now >= self.done and not v:IsPlayer() then
			self:PryOff()
			return
		else
			if self.held then
				self:Carry()
			else
				self:Sense(now)
			end
			if self.victim then self:Struggle(now, dt, self.held ~= nil) end
		end
		if IsValid(self.victim) and self.victim:IsPlayer() then self.victim:SetNW2Float("EvilCrabYaw", self.yaw) end
	end
	self:NextThink(now)
	return true
end

function ENT:Hold(ply)
	if not self.victim or self.lifted then return end
	if self.lure then self:Abandon() end
	if self.offer then self:Withdraw() end
	local from = ply:GetShootPos()
	local grab = ply:GetEyeTrace().HitPos
	self.held = { ply = ply, dist = grab:Distance(from), offset = grab - self.pos }
	ply.EvilCarrying = self
end

function ENT:Carry()
	local h = self.held
	local ply = h.ply
	if not IsValid(ply) or not ply:Alive() then return self:Drop() end
	self.pos = ply:GetShootPos() + ply:GetAimVector() * h.dist - h.offset
end

function ENT:Drop()
	local h = self.held
	self.held = nil
	if IsValid(h.ply) and h.ply.EvilCarrying == self then h.ply.EvilCarrying = nil end
	self.nextLure = CurTime() + LURE_EVERY
	local v = self.victim
	if not IsValid(v) then return end
	local filter = function(ent) return ent ~= v and ent ~= self end
	local up = self.pos + Vector(0, 0, STEP)
	local tr = util.TraceHull({ start = up, endpos = up - Vector(0, 0, DROP_FIND), mins = v:OBBMins(), maxs = v:OBBMaxs(), filter = filter, mask = MASK_NPCSOLID })
	if tr.Hit and not tr.StartSolid then self.pos = tr.HitPos end
end

function ENT:Release()
	if self.held then self:Drop() end
	local hold = self.lifted or self.offer or self.lure or self.hauled
	local lifted = self.lifted ~= nil
	self.lifted, self.offer, self.lure, self.hauled = nil, nil, nil, nil
	if hold and IsValid(hold.barnacle) and hold.barnacle.EvilThrall == self then hold.barnacle.EvilThrall = nil end
	local v = self.victim
	self.victim = nil
	if not IsValid(v) then return end
	self:Unresist(v)
	v.EvilCrab = nil
	v:SetNW2Float("EvilCrabbed", 0)
	v:SetNW2Float("EvilCrabDone", 0)
	v:SetNW2Bool("EvilCrabRunning", false)
	if Evil.Owner(v) == self then Evil.Unpose(v, self) end
	if lifted then
		v:SetNoDraw(true)
		v:SetNotSolid(true)
	end
end

function ENT:Handover(ent)
	local ply = self:GetCreator()
	if not IsValid(ply) then return end
	ent:SetCreator(ply)
	cleanup.Add(ply, "sents", ent)
end

function ENT:Shed(pos, yaw, vel, shun)
	local crab = ents.Create("evil_headcrab")
	crab:SetPos(vel and pos + vel:GetNormalized() * THROW_CLEAR or pos)
	crab:SetAngles(Angle(0, yaw, 0))
	crab.carried = self:Health()
	crab.shun = shun
	crab:Spawn()
	crab:Activate()
	if vel then
		crab.loco:Jump()
		crab.loco:SetVelocity(vel)
	end
	self:Handover(crab)
	return crab
end

local function Flee(v, away)
	local goal = v:GetPos() + away * FLEE
	if navmesh.IsLoaded() then
		local area = navmesh.GetNearestNavArea(goal)
		if area then goal = area:GetClosestPointOnArea(goal) or goal end
	end
	v:SetLastPosition(goal)
	v:SetSchedule(SCHED_FORCED_GO_RUN)
end

function ENT:PryOff()
	local v, pos = self.victim, self:GetPos()
	local yaw = self.yaw + 180 + math.Rand(-60, 60)
	local throw = Angle(0, yaw, 0):Forward()
	self:Release()
	local crab = self:Shed(pos, yaw, throw * THROW + Vector(0, 0, THROW_UP), { [v] = CurTime() + SHUN })
	crab:EmitSound("NPC_HeadCrab.Pain")
	if IsValid(v) and v:IsNPC() then Flee(v, -throw) end
	self:Remove()
end

function ENT:FallOff()
	local pos, yaw = self:GetPos(), self:GetAngles().y
	self:Release()
	self:Shed(pos, yaw)
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

local wheelSpeed = GetConVar("physgun_wheelspeed")

hook.Add("OnPhysgunPickup", "EvilHeadcrabCarry", function(ply, ent)
	local crab = ent.EvilCrab
	if IsValid(crab) then crab:Hold(ply) end
end)

hook.Add("PhysgunDrop", "EvilHeadcrabCarry", function(ply, ent)
	local crab = ent.EvilCrab
	if IsValid(crab) and crab.held and crab.held.ply == ply then crab:Drop() end
end)

hook.Add("StartCommand", "EvilHeadcrabCarry", function(ply, cmd)
	local crab = ply.EvilCarrying
	if not IsValid(crab) or not crab.held then return end
	local wheel = cmd:GetMouseWheel()
	if wheel ~= 0 then
		crab.held.dist = math.max(crab.held.dist + wheel * (wheelSpeed and wheelSpeed:GetFloat() or 10), 0)
	end
end)
