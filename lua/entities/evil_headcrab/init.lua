AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local MODEL = "models/headcrabclassic.mdl"
local HEALTH = 10
local MINS, MAXS = Vector(-12, -12, 0), Vector(12, 12, 24)
local ROAM_RATE = 0.6
local ROAM_MIN, ROAM_MAX = 150, 500
local IDLE_MIN, IDLE_MAX = 2, 8
local CHATTER_MIN, CHATTER_MAX = 4, 12
local GIVE_UP = 10
local STALL = 1.5
local ARRIVED = 16
local LOOK_AHEAD = 24
local DROP = 64
local LOOK_EVERY = 0.5
local SIGHT = 800
local LOSE = 1200
local HUNT_FOR = 20
local LEAP_RANGE = 220
local LEAP_SPEED = 450
local LEAP_TIME_MIN, LEAP_TIME_MAX = 0.3, 0.7
local LEAP_AIM = Vector(0, 0, 4)
local LEAP_REST = 1.2
local LATCH = 26
local EYES = Vector(0, 0, 12)

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local crab = ents.Create(class)
	crab:SetPos(tr.HitPos + tr.HitNormal * 2)
	crab:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
	crab:Spawn()
	crab:Activate()
	return crab
end

function ENT:Initialize()
	self:SetModel(MODEL)
	self:SetHealth(self.carried or HEALTH)
	self:SetMaxHealth(HEALTH)
	self:SetCollisionBounds(MINS, MAXS)
	self:SetBloodColor(BLOOD_COLOR_GREEN)
	self.loco:SetDeathDropHeight(DROP)
	self.chatter = CurTime() + math.Rand(CHATTER_MIN, CHATTER_MAX)
	self.look = 0
end

function ENT:Think()
	if CurTime() < self.chatter then return end
	self.chatter = CurTime() + math.Rand(CHATTER_MIN, CHATTER_MAX)
	self:EmitSound("NPC_HeadCrab.Idle")
end

local function HeadPos(ent)
	local bone = ent:LookupBone(EvilHeadcrab.HEAD)
	return bone and ent:GetBonePosition(bone)
end

function ENT:Host(ent)
	if not IsValid(ent) or not ent:IsNPC() or ent:Health() <= 0 then return false end
	local class = ent:GetClass()
	if class:find("headcrab", 1, true) or class:find("zombie", 1, true) then return false end
	if Evil.Frozen(ent) or Evil.Downed(ent) or not Evil.Claimable(ent, self) then return false end
	return ent:LookupBone(EvilHeadcrab.HEAD) ~= nil
end

function ENT:Sees(ent)
	local head = HeadPos(ent)
	if not head then return false end
	return not util.TraceLine({ start = self:GetPos() + EYES, endpos = head, filter = { self, ent }, mask = MASK_BLOCKLOS }).Hit
end

function ENT:FindPrey()
	if EvilHeadcrab.Settings:Get("targets_npcs") == 0 then return end
	local pos, best, bestDist = self:GetPos()
	for _, ent in ipairs(ents.FindInSphere(pos, SIGHT)) do
		if self:Host(ent) then
			local dist = pos:DistToSqr(ent:GetPos())
			if (not best or dist < bestDist) and self:Sees(ent) then best, bestDist = ent, dist end
		end
	end
	return best
end

function ENT:Spot()
	if CurTime() < self.look then return self.prey end
	self.look = CurTime() + LOOK_EVERY
	self.prey = self:FindPrey()
	return self.prey
end

local function NavSpot(from)
	if not navmesh.IsLoaded() then return end
	local areas = navmesh.Find(from, ROAM_MAX, DROP, DROP)
	if #areas == 0 then return end
	local spot
	for _ = 1, 8 do
		spot = areas[math.random(#areas)]:GetRandomPoint()
		if spot:DistToSqr(from) > ROAM_MIN * ROAM_MIN then break end
	end
	return spot
end

function ENT:TraceSpot()
	local from = self:GetPos() + vector_up * 8
	local dir = Angle(0, math.Rand(0, 360), 0):Forward()
	local reach = math.Rand(ROAM_MIN, ROAM_MAX)
	local tr = util.TraceHull({ start = from, endpos = from + dir * reach, mins = MINS, maxs = MAXS, filter = self, mask = MASK_NPCSOLID })
	if tr.Fraction * reach < ROAM_MIN * 0.5 then return end
	local down = util.TraceLine({ start = tr.HitPos, endpos = tr.HitPos - vector_up * (DROP + 8), filter = self, mask = MASK_NPCSOLID })
	if down.Hit then return down.HitPos end
end

function ENT:Ledge(goal)
	local pos = self:GetPos()
	local dir = goal - pos
	dir.z = 0
	dir:Normalize()
	local start = pos + dir * LOOK_AHEAD + vector_up * 8
	return not util.TraceLine({ start = start, endpos = start - vector_up * (DROP + 8), filter = self, mask = MASK_NPCSOLID }).Hit
end

function ENT:Scuttle(rate)
	self:StartActivity(ACT_RUN)
	self.loco:SetDesiredSpeed(self:GetSequenceGroundSpeed(self:GetSequence()) * rate)
end

function ENT:FollowPath(goal)
	local path = Path("Follow")
	path:SetGoalTolerance(ARRIVED)
	if not path:Compute(self, goal) then return end
	self:Scuttle(ROAM_RATE)
	local stop = CurTime() + GIVE_UP
	while path:IsValid() and CurTime() < stop do
		if self:Spot() then return end
		path:Update(self)
		if self.loco:IsStuck() then
			self.loco:ClearStuck()
			return
		end
		coroutine.yield()
	end
end

function ENT:Step(goal)
	self.loco:FaceTowards(goal)
	self.loco:Approach(goal, 1)
end

function ENT:Approach(goal)
	self:Scuttle(ROAM_RATE)
	local stop = CurTime() + GIVE_UP
	local last, stalled = self:GetPos(), CurTime() + STALL
	while CurTime() < stop do
		if self:Spot() then return end
		local pos = self:GetPos()
		if (goal - pos):Length2DSqr() < ARRIVED * ARRIVED or self:Ledge(goal) then return end
		if pos:DistToSqr(last) > 16 then
			last, stalled = pos, CurTime() + STALL
		elseif CurTime() > stalled then
			return
		end
		self:Step(goal)
		coroutine.yield()
	end
end

function ENT:Idle(seconds)
	self:StartActivity(ACT_IDLE)
	local stop = CurTime() + seconds
	while CurTime() < stop do
		if self:Spot() then return end
		coroutine.yield()
	end
end

function ENT:Wander()
	self:Idle(math.Rand(IDLE_MIN, IDLE_MAX))
	if self.prey then return end
	local goal = NavSpot(self:GetPos())
	if goal then
		self:FollowPath(goal)
	else
		goal = self:TraceSpot()
		if goal then self:Approach(goal) end
	end
end

function ENT:Leap(prey)
	local head = HeadPos(prey)
	if not head then return end
	head = head + LEAP_AIM
	local from = self:GetPos()
	local t = math.Clamp((head - from):Length2D() / LEAP_SPEED, LEAP_TIME_MIN, LEAP_TIME_MAX)
	local vel = (head - from) / t
	vel.z = vel.z + 0.5 * self.loco:GetGravity() * t
	self:SetAngles(Angle(0, (head - from):Angle().y, 0))
	self:StartActivity(ACT_RANGE_ATTACK1)
	self:EmitSound("NPC_Headcrab.Attack")
	self.loco:Jump()
	self.loco:SetVelocity(vel)
	local launched = CurTime()
	while CurTime() < launched + t + 1 do
		if not self:Host(prey) then break end
		head = HeadPos(prey)
		if head and self:WorldSpaceCenter():DistToSqr(head + LEAP_AIM) < LATCH * LATCH then
			self:Latch(prey)
			return true
		end
		if CurTime() > launched + 0.2 and self.loco:IsOnGround() then break end
		coroutine.yield()
	end
	self:StartActivity(ACT_IDLE)
	coroutine.wait(LEAP_REST)
end

function ENT:Chase(prey)
	if navmesh.IsLoaded() then
		self.path = self.path or Path("Chase")
		self.path:Chase(self, prey)
	else
		self:Step(prey:GetPos())
	end
end

function ENT:Hunt(prey)
	self:EmitSound("NPC_HeadCrab.Alert")
	self:Scuttle(1)
	local stop = CurTime() + HUNT_FOR
	while CurTime() < stop and self:Host(prey) and EvilHeadcrab.Settings:Get("targets_npcs") ~= 0 do
		local dist = self:GetPos():Distance(prey:GetPos())
		if dist > LOSE then break end
		if dist < LEAP_RANGE and self:Sees(prey) then
			if self:Leap(prey) then return end
			self:Scuttle(1)
		else
			self:Chase(prey)
		end
		coroutine.yield()
	end
	self.path = nil
	self.prey = nil
end

function ENT:RunBehaviour()
	while true do
		if self.gone then
			coroutine.yield()
		else
			local prey = self:Spot()
			if prey then self:Hunt(prey) else self:Wander() end
		end
	end
end

function ENT:Latch(prey)
	local crab = ents.Create("evil_headcrab_latched")
	crab:SetPos(self:GetPos())
	crab:SetAngles(self:GetAngles())
	crab.carried = self:Health()
	crab:Spawn()
	if not crab:Grab(prey) then
		crab:Remove()
		return
	end
	local ply = self:GetCreator()
	if IsValid(ply) then
		crab:SetCreator(ply)
		cleanup.Add(ply, "sents", crab)
	end
	self.gone = true
	self:Remove()
end

function ENT:OnInjured(dmg)
	if dmg:GetDamage() < self:Health() then self:EmitSound("NPC_HeadCrab.Pain") end
end

function ENT:OnKilled(dmg)
	self:EmitSound("NPC_HeadCrab.Die")
	hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
	self:BecomeRagdoll(dmg)
end
