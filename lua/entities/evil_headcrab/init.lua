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
	self:SetHealth(HEALTH)
	self:SetMaxHealth(HEALTH)
	self:SetCollisionBounds(MINS, MAXS)
	self:SetBloodColor(BLOOD_COLOR_GREEN)
	self.loco:SetDeathDropHeight(DROP)
	self.chatter = CurTime() + math.Rand(CHATTER_MIN, CHATTER_MAX)
end

function ENT:Think()
	if CurTime() < self.chatter then return end
	self.chatter = CurTime() + math.Rand(CHATTER_MIN, CHATTER_MAX)
	self:EmitSound("NPC_HeadCrab.Idle")
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

function ENT:Scuttle()
	self:StartActivity(ACT_RUN)
	self.loco:SetDesiredSpeed(self:GetSequenceGroundSpeed(self:GetSequence()) * ROAM_RATE)
end

function ENT:FollowPath(goal)
	local path = Path("Follow")
	path:SetGoalTolerance(ARRIVED)
	if not path:Compute(self, goal) then return end
	self:Scuttle()
	local stop = CurTime() + GIVE_UP
	while path:IsValid() and CurTime() < stop do
		path:Update(self)
		if self.loco:IsStuck() then
			self.loco:ClearStuck()
			return
		end
		coroutine.yield()
	end
end

function ENT:Approach(goal)
	self:Scuttle()
	local stop = CurTime() + GIVE_UP
	local last, stalled = self:GetPos(), CurTime() + STALL
	while CurTime() < stop do
		local pos = self:GetPos()
		if (goal - pos):Length2DSqr() < ARRIVED * ARRIVED or self:Ledge(goal) then return end
		if pos:DistToSqr(last) > 16 then
			last, stalled = pos, CurTime() + STALL
		elseif CurTime() > stalled then
			return
		end
		self.loco:FaceTowards(goal)
		self.loco:Approach(goal, 1)
		coroutine.yield()
	end
end

function ENT:RunBehaviour()
	while true do
		self:StartActivity(ACT_IDLE)
		coroutine.wait(math.Rand(IDLE_MIN, IDLE_MAX))
		local goal = NavSpot(self:GetPos())
		if goal then
			self:FollowPath(goal)
		else
			goal = self:TraceSpot()
			if goal then self:Approach(goal) end
		end
	end
end

function ENT:OnInjured(dmg)
	if dmg:GetDamage() < self:Health() then self:EmitSound("NPC_HeadCrab.Pain") end
end

function ENT:OnKilled(dmg)
	self:EmitSound("NPC_HeadCrab.Die")
	hook.Run("OnNPCKilled", self, dmg:GetAttacker(), dmg:GetInflictor())
	self:BecomeRagdoll(dmg)
end
