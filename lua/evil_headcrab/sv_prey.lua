local PANIC = 10
local CREEP_MIN, CREEP_MAX = 1.6, 2.4
local STAGGER_MIN, STAGGER_MAX = 0.4, 1
local SWALLOW_WAIT = 0.8
local SWALLOW_TIME = 3.5
local SWALLOW = 22
local GULPS = 3
local KICK = 10
local FADE = 8
local CLAW_UP, CLAW_SPREAD = 6, 9
local CLAW_K, CLAW_DAMP = 70, 9
local CLAW_MIN, CLAW_MAX = 0.2, 0.55
local REEL_K, REEL_DAMP, REEL_IN = 120, 12, 0.8
local REEL_OUT, REEL_UP = 4, 3
local LEG, LEG_OUT = 34, 4
local STRIDE_HZ, STRIDE_REACH, STRIDE_LIFT = 1.3, 14, 10
local LEG_K, LEG_DAMP = 40, 6
local KICK_JITTER, KICK_MIN, KICK_MAX = 8, 0.3, 0.7
local HEAVE, HEAVE_MIN, HEAVE_MAX = 160, 0.8, 1.8
local PLEAD_MIN, PLEAD_MAX = 1.4, 2.8
local MOAN_MIN, MOAN_MAX = 2.5, 5
local LIMP_LIN, LIMP_ANG = 0.4, 1.2
local TWITCH, TWITCH_MIN, TWITCH_MAX = 70, 5, 12
local TWITCH_MOAN = 0.3
local PANIC_FACE = {
	jaw_drop = 0.8,
	right_lid_raiser = 1,
	left_lid_raiser = 1,
	right_inner_raiser = 1,
	left_inner_raiser = 1,
	right_outer_raiser = 0.6,
	left_outer_raiser = 0.6,
	right_stretcher = 0.5,
	left_stretcher = 0.5,
}
local PLEAD = { "help01", "no01", "no02", "ohno", "startle01", "startle02", "pain07", "pain08", "pain09", "gethellout" }
local SHRIEK = { "pain07", "pain08", "pain09", "no02" }
local MOAN = { "moan01", "moan02", "moan03", "moan04", "moan05" }
local SIDES = {
	{ hand = "ValveBiped.Bip01_R_Hand", foot = "ValveBiped.Bip01_R_Foot", thigh = "ValveBiped.Bip01_R_Thigh", net = "EvilLatchR", phase = 0, out = -1 },
	{ hand = "ValveBiped.Bip01_L_Hand", foot = "ValveBiped.Bip01_L_Foot", thigh = "ValveBiped.Bip01_L_Thigh", net = "EvilLatchL", phase = math.pi, out = 1 },
}

local held = {}

local function Phys(body, name)
	local bone = body:LookupBone(name)
	local i = bone and body:TranslateBoneToPhysBone(bone)
	local phys = i and i >= 0 and body:GetPhysicsObjectNum(i)
	if IsValid(phys) then return phys end
end

local function Voice(model)
	model = string.lower(model or "")
	if string.find(model, "female", 1, true) or string.find(model, "alyx", 1, true) or string.find(model, "mossman", 1, true) then
		return "vo/npc/female01/"
	end
	if string.find(model, "male", 1, true) then return "vo/npc/male01/" end
end

local function Face(body, weights)
	for i = 0, body:GetFlexNum() - 1 do
		local w = weights[body:GetFlexName(i)]
		if w then body:SetFlexWeight(i, w) end
	end
end

local function Say(prey, list, level, pitch, volume)
	if not prey.voice then return end
	prey.body:EmitSound(prey.voice .. list[math.random(#list)] .. ".wav", level, pitch, volume)
end

local function Flat(v, up)
	return v - up * v:Dot(up)
end

local function Spring(phys, target, k, damp, dt)
	phys:AddVelocity(((target - phys:GetPos()) * k - phys:GetVelocity() * damp) * dt)
end

function EvilHeadcrab.Prey(body, maw, fighter)
	local prey = {
		body = body, maw = maw, start = CurTime(), voice = Voice(body:GetModel()),
		head = Phys(body, EvilHeadcrab.HEAD), pelvis = Phys(body, "ValveBiped.Bip01_Pelvis"),
		sides = {}, stride = 0, plead = 0, heave = 0, burst = 0, burstEnd = 0,
	}
	for _, def in ipairs(SIDES) do
		local side = { def = def, hand = Phys(body, def.hand), foot = Phys(body, def.foot), thigh = Phys(body, def.thigh), aim = Vector(), kick = Vector(), claw = 0, jolt = 0 }
		if side.hand and side.foot and side.thigh then prey.sides[#prey.sides + 1] = side end
	end
	prey.fighter = fighter and prey.head ~= nil and prey.pelvis ~= nil and #prey.sides == #SIDES
	if prey.fighter then Face(body, PANIC_FACE) end
	return prey
end

local function Claw(prey, now, dt, up)
	local top = prey.head:GetPos() + up * CLAW_UP
	for _, side in ipairs(prey.sides) do
		if not side.latched then
			if now >= side.claw then
				side.claw = now + math.Rand(CLAW_MIN, CLAW_MAX)
				side.aim = Flat(VectorRand(), up) * CLAW_SPREAD
			end
			Spring(side.hand, top + side.aim, CLAW_K, CLAW_DAMP, dt)
		end
	end
end

local function Reel(prey, now, dt, up)
	local head = prey.head:GetPos()
	for _, side in ipairs(prey.sides) do
		if side.latched then
			local k = Lerp(math.min((now - side.latch) / REEL_IN, 1), 0.3, 1)
			Spring(side.hand, head + side.out + up * REEL_UP, REEL_K * k, REEL_DAMP, dt)
		end
	end
end

local function Kick(prey, now, dt, up, k)
	if k <= 0 then return end
	local left = Flat(prey.sides[2].thigh:GetPos() - prey.sides[1].thigh:GetPos(), up)
	if left:LengthSqr() < 0.01 then return end
	left:Normalize()
	local fwd = left:Cross(up)
	local hip = prey.pelvis:GetPos()
	prey.stride = prey.stride + dt * STRIDE_HZ * math.pi * 2
	for _, side in ipairs(prey.sides) do
		if now >= side.jolt then
			side.jolt = now + math.Rand(KICK_MIN, KICK_MAX)
			side.kick = VectorRand() * KICK_JITTER
		end
		local w = prey.stride + side.def.phase
		local target = hip - up * LEG + left * (side.def.out * LEG_OUT)
			+ fwd * (math.sin(w) * STRIDE_REACH)
			+ up * (math.max(math.cos(w), 0) * STRIDE_LIFT)
			+ side.kick
		Spring(side.foot, target, LEG_K * k, LEG_DAMP, dt)
	end
end

local function Heave(prey, now, up)
	if now < prey.heave then return end
	prey.heave = now + math.Rand(HEAVE_MIN, HEAVE_MAX)
	prey.pelvis:AddVelocity(-up * HEAVE + Flat(VectorRand(), up) * (HEAVE * 0.4))
end

local function Plead(prey, now)
	if now < prey.plead then return end
	prey.plead = now + math.Rand(PLEAD_MIN, PLEAD_MAX)
	Say(prey, PLEAD, 80, math.random(98, 110), 1)
end

local function Moan(prey, now)
	if now < prey.plead then return end
	prey.plead = now + math.Rand(MOAN_MIN, MOAN_MAX)
	Say(prey, MOAN, 60, math.random(78, 90), 0.5)
end

local function Limp(prey, now)
	prey.limp = true
	prey.twitch = now + math.Rand(TWITCH_MIN, TWITCH_MAX)
	prey.damping = {}
	local body = prey.body
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local lin, ang = phys:GetDamping()
			prey.damping[i] = { lin, ang }
			phys:SetDamping(math.max(lin, LIMP_LIN), math.max(ang, LIMP_ANG))
		end
	end
end

local function Twitch(prey, now)
	if now < prey.twitch then return end
	prey.twitch = now + math.Rand(TWITCH_MIN, TWITCH_MAX)
	local body = prey.body
	local phys = body:GetPhysicsObjectNum(math.random(0, body:GetPhysicsObjectCount() - 1))
	if IsValid(phys) then
		phys:Wake()
		phys:AddVelocity(VectorRand() * TWITCH)
	end
	if prey.fighter and math.random() < TWITCH_MOAN then Say(prey, MOAN, 55, math.random(72, 84), 0.35) end
end

local function Latch(prey, side, up)
	side.latched = true
	local out = Flat(side.hand:GetPos() - prey.head:GetPos(), up)
	if out:LengthSqr() < 0.01 then out = prey.maw:GetRight() * side.def.out end
	out:Normalize()
	side.out = out * REEL_OUT
	prey.body:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(4) .. ".wav")
	Say(prey, SHRIEK, 85, math.random(100, 112), 1)
	prey.plead = CurTime() + PLEAD_MIN
end

local function Hunt(prey, now)
	local body = prey.body
	prey.hunt = now
	body:SetNW2Float("EvilHunt", now)
	local at = now + math.Rand(CREEP_MIN, CREEP_MAX)
	local first = math.random(#prey.sides)
	for n, side in ipairs(prey.sides) do
		side.latch = n == first and at or at + math.Rand(STAGGER_MIN, STAGGER_MAX)
		body:SetNW2Float(side.def.net, side.latch)
	end
	prey.maw:EmitSound("NPC_Barnacle.TongueStretch")
end

local function Swallow(prey, now)
	if not prey.gulping then
		prey.gulping = true
		prey.maw:EmitSound("NPC_Barnacle.PullPant")
	end
	local s = math.min((now - prey.swallow) / SWALLOW_TIME, 1)
	local f = s - math.sin(s * GULPS * math.pi * 2) / (GULPS * math.pi * 2)
	prey.head:SetPos(prey.maw:LocalToWorld(prey.socket + Vector(0, 0, SWALLOW * f)))
end

local function Legs(prey, now)
	if not prey.swallowed or now < prey.swallowed + KICK then return 1 end
	local f = 1 - math.min((now - prey.swallowed - KICK) / FADE, 1)
	if now >= prey.burst then
		prey.burstEnd = now + math.Rand(0.4, 1.2) * (0.5 + f)
		prey.burst = prey.burstEnd + math.Rand(0.6, 1.4) * Lerp(f, 3, 0.2)
	end
	return now < prey.burstEnd and f or 0
end

local function Fight(prey, now, dt, up)
	if not prey.hunt and prey.seated and now - prey.start >= PANIC then Hunt(prey, now) end
	local all = prey.hunt ~= nil
	for _, side in ipairs(prey.sides) do
		if side.latch and not side.latched and now >= side.latch then Latch(prey, side, up) end
		all = all and side.latched
	end
	if all and not prey.swallow then
		prey.swallow = now + SWALLOW_WAIT
		prey.swallowed = prey.swallow + SWALLOW_TIME
	end
	if prey.swallow and now >= prey.swallow then Swallow(prey, now) end
	Claw(prey, now, dt, up)
	Reel(prey, now, dt, up)
	local k = Legs(prey, now)
	Kick(prey, now, dt, up, k)
	if not prey.swallow then
		Heave(prey, now, up)
		Plead(prey, now)
	elseif k > 0 then
		Moan(prey, now)
	end
	if prey.swallowed and now >= prey.swallowed + KICK + FADE then Limp(prey, now) end
end

function EvilHeadcrab.Thrash(prey, now, dt)
	if not prey or not prey.fighter or not IsValid(prey.maw) then return end
	local up = prey.maw:GetUp()
	Claw(prey, now, dt, up)
	Kick(prey, now, dt, up, 1)
	Plead(prey, now)
end

function EvilHeadcrab.Hold(maw, body, prey)
	prey = prey or EvilHeadcrab.Prey(body, maw, false)
	prey.maw = maw
	held[body] = prey
	body:SetNW2Entity("EvilMaw", maw)
end

function EvilHeadcrab.Seated(body)
	local prey = held[body]
	if not prey or not IsValid(prey.maw) or not IsValid(prey.head) then return end
	local now = CurTime()
	prey.seated = now
	prey.socket = prey.maw:WorldToLocal(prey.head:GetPos())
	if not prey.fighter then Limp(prey, now) end
end

function EvilHeadcrab.Free(body)
	local prey = held[body]
	held[body] = nil
	if not prey or not IsValid(body) then return end
	for i, d in pairs(prey.damping or {}) do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:SetDamping(d[1], d[2]) end
	end
	body:SetNW2Entity("EvilMaw", NULL)
	body:SetNW2Float("EvilHunt", 0)
	for _, def in ipairs(SIDES) do body:SetNW2Float(def.net, 0) end
end

hook.Add("Think", "EvilHeadcrabPrey", function()
	local now, dt = CurTime(), FrameTime()
	for body, prey in pairs(held) do
		if not IsValid(body) or not IsValid(prey.maw) or body.EvilBond ~= prey.maw then
			held[body] = nil
		elseif prey.limp then
			Twitch(prey, now)
		elseif prey.fighter then
			Fight(prey, now, dt, prey.maw:GetUp())
		end
	end
end)
