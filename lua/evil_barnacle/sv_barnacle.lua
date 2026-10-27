local FLOOR = 4096
local EAT_LENGTH = 145 / 30
local BITE_CYCLE = 0.16
local SOCKET = -27.8
local YANK = 900
local SHOT_RADIUS = 8
local TOSS = 160
local STRIKE = {
	-33.2, -33.2, -34.9, -38.3, -39.7, -40.6, -71.1, -63.7, -61.6, -60.6, -60.0, -59.2, -57.2,
	-53.5, -48.2, -42.5, -38.7, -37.4, -36.7, -36.1, -35.5, -34.9, -34.2, -33.4, -32.4, -30.4,
	-27.9, -24.9, -21.5, -18.0, -14.3, -10.7, -9.5, -9.2, -9.1, -9.1, -9.1,
}

local pulls = {}
local bonded = {}

EvilBarnacle.HANG = 2
EvilBarnacle.REST = 16

function EvilBarnacle.Rest(barnacle)
	if IsValid(barnacle) and barnacle:Health() > 0 then barnacle:SetKeyValue("RestDist", tostring(EvilBarnacle.REST)) end
end

function EvilBarnacle.Spawn(pos, yaw)
	local barnacle = ents.Create("npc_barnacle")
	if not IsValid(barnacle) then return end
	barnacle:SetPos(pos - Vector(0, 0, EvilBarnacle.HANG))
	barnacle:SetAngles(Angle(0, yaw, 0))
	barnacle:Spawn()
	barnacle:Activate()
	EvilBarnacle.Add(barnacle)
	return barnacle
end

function EvilBarnacle.Below(barnacle)
	local start = barnacle:GetPos()
	local tr = util.TraceLine({ start = start, endpos = start - Vector(0, 0, FLOOR), mask = MASK_NPCSOLID_BRUSHONLY })
	if tr.Hit and not tr.StartSolid then return tr.HitPos end
end

local function Kill(ent, attacker)
	local dmg = DamageInfo()
	dmg:SetDamage(ent:Health() + 100)
	dmg:SetDamageType(DMG_GENERIC)
	dmg:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
	dmg:SetInflictor(game.GetWorld())
	ent:TakeDamageInfo(dmg)
end

local function Unpin(body, keep)
	EvilBarnacle.Free(body, keep)
	body.EvilBond = nil
	body:RemoveSolidFlags(FSOLID_NOT_SOLID)
	Evil.Unclaim(body)
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			phys:EnableMotion(true)
			phys:Wake()
		end
	end
end

local function Strike(cycle)
	local f = math.Clamp(cycle, 0, 1) * (#STRIKE - 1)
	local i = math.floor(f)
	return Lerp(f - i, STRIKE[i + 1], STRIKE[math.min(i + 2, #STRIKE)])
end

local function Pull(barnacle, pull, dt)
	local phys = pull.phys
	if not IsValid(phys) then return true end
	local cycle = (CurTime() - pull.start) * pull.rate / EAT_LENGTH
	if cycle < BITE_CYCLE then return end
	local pos = phys:GetPos()
	if not pull.bitten then
		pull.bitten = true
		barnacle:EmitSound("NPC_Barnacle.FinalBite")
		EvilBarnacle.Bitten(pull.body)
		pull.low = math.min(barnacle:WorldToLocal(pos).z, SOCKET)
	end
	local target = barnacle:LocalToWorld(Vector(0, 0, math.Clamp(Strike(cycle), pull.low, SOCKET)))
	local gap = target - pos
	local step = YANK * dt
	local dist = gap:Length()
	phys:SetPos(dist > step and pos + gap * (step / dist) or target)
	return cycle >= 1 and dist <= step
end

hook.Add("Think", "EvilBarnaclePull", function()
	local dt = FrameTime()
	for barnacle, pull in pairs(pulls) do
		if not IsValid(barnacle) or barnacle.EvilBond ~= pull.body then
			pulls[barnacle] = nil
		elseif Pull(barnacle, pull, dt) then
			pulls[barnacle] = nil
			EvilBarnacle.Rest(barnacle)
			EvilBarnacle.Seated(pull.body)
		end
	end
end)

function EvilBarnacle.Shed(barnacle, keep)
	local body = barnacle.EvilBond
	barnacle.EvilBond = nil
	pulls[barnacle] = nil
	bonded[barnacle] = nil
	EvilBarnacle.Rest(barnacle)
	if IsValid(body) then Unpin(body, keep) end
end

local function Toss(body)
	local push = Angle(0, math.Rand(0, 360), 0):Forward() * TOSS
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:AddVelocity(push) end
	end
end

function EvilBarnacle.Bond(barnacle, body, head, health, prey)
	local old = barnacle.EvilBond
	EvilBarnacle.Shed(barnacle)
	if IsValid(old) and old ~= body then Toss(old) end
	barnacle.EvilBond, body.EvilBond = body, barnacle
	bonded[barnacle] = true
	body.EvilHealth = health
	body:AddSolidFlags(FSOLID_NOT_SOLID)
	Evil.Claim(body, barnacle)
	local floor = EvilBarnacle.Below(barnacle)
	if floor then barnacle:SetKeyValue("RestDist", tostring(barnacle:GetPos().z - floor.z)) end
	local phys = body:GetPhysicsObjectNum(head)
	if IsValid(phys) then phys:EnableMotion(false) end
	local eat = barnacle:LookupSequence("eat_humanoid")
	local rate = barnacle:GetPlaybackRate()
	if rate <= 0 then rate = 1 end
	local start = CurTime()
	if barnacle:GetSequence() == eat then start = start - barnacle:GetCycle() * EAT_LENGTH / rate end
	pulls[barnacle] = { body = body, phys = phys, start = start, rate = rate }
	EvilBarnacle.Hold(barnacle, body, prey)
end

function EvilBarnacle.Unbond(barnacle, attacker)
	EvilBarnacle.Shed(barnacle)
	if barnacle:Health() > 0 then Kill(barnacle, attacker) end
end

hook.Add("EntityTakeDamage", "EvilBarnacleBond", function(ent, dmg)
	local other = ent.EvilBond
	if not IsValid(other) then return end
	if dmg:IsDamageType(DMG_CRUSH) then return true end
	if ent:IsNPC() then
		if pulls[ent] or ent:GetInternalVariable("m_bLiftingPrey") then return end
		return true
	end
	ent.EvilHealth = ent.EvilHealth - dmg:GetDamage()
	if ent.EvilHealth <= 0 then EvilBarnacle.Unbond(other, dmg:GetAttacker()) end
end)

hook.Add("PostEntityTakeDamage", "EvilBarnacleBond", function(ent)
	if ent:IsNPC() and IsValid(ent.EvilBond) and ent:Health() <= 0 then EvilBarnacle.Shed(ent) end
end)

local function Graze(body, from, to)
	local ray = to - from
	local len = ray:Length()
	if len < 1 then return end
	local dir = ray / len
	local best, at
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local p = phys:GetPos()
			local t = math.Clamp((p - from):Dot(dir), 0, len)
			local near = from + dir * t
			local d = near:DistToSqr(p)
			if d < SHOT_RADIUS * SHOT_RADIUS and (not best or t < best) then best, at = t, near end
		end
	end
	return at
end

hook.Add("PostEntityFireBullets", "EvilBarnacleBond", function(shooter, data)
	local tr = data.Trace
	if not tr then return end
	for barnacle in pairs(bonded) do
		if not IsValid(barnacle) then bonded[barnacle] = nil end
		local body = IsValid(barnacle) and barnacle.EvilBond
		local at = IsValid(body) and Graze(body, tr.StartPos, tr.HitPos)
		if at then
			local dmg = DamageInfo()
			dmg:SetDamage(data.Damage or 0)
			dmg:SetDamageType(DMG_BULLET)
			dmg:SetAttacker(IsValid(data.Attacker) and data.Attacker or shooter)
			dmg:SetInflictor(shooter)
			dmg:SetDamagePosition(at)
			dmg:SetDamageForce(tr.Normal * (data.Force or 1) * 100)
			body:TakeDamageInfo(dmg)
		end
	end
end)

hook.Add("EntityRemoved", "EvilBarnacleBond", function(ent)
	local other = ent.EvilBond
	if not IsValid(other) then return end
	if ent:IsNPC() then
		Unpin(other)
	else
		EvilBarnacle.Unbond(other)
	end
end)
