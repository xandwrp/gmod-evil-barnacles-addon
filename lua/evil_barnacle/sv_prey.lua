local PANIC = 20
local FADE = 8
local CLAW_UP = 6
local CLAW_IN, CLAW_OUT = 5, 11
local LIP, YANK = -30, 8
local CLAW_K, CLAW_DAMP = 70, 9
local CLAW_MIN, CLAW_MAX = 0.2, 0.55
local LEG, LEG_OUT = 34, 4
local STRIDE_HZ, STRIDE_REACH, STRIDE_LIFT = 1.3, 14, 10
local LEG_K, LEG_DAMP = 40, 6
local KICK_JITTER, KICK_MIN, KICK_MAX = 8, 0.3, 0.7
local HEAVE, HEAVE_MIN, HEAVE_MAX = 160, 0.8, 1.8
local PLEAD_MIN, PLEAD_MAX = 1.4, 2.8
local MOAN_MIN, MOAN_MAX = 2.5, 5
local LIMP_LIN, LIMP_ANG = 0.4, 1.2
local SETTLE = 3
local WIRE_EVERY = 2
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
local MOAN = { "moan01", "moan02", "moan03", "moan04", "moan05" }
local SIDES = {
	{ hand = "ValveBiped.Bip01_R_Hand", fore = "ValveBiped.Bip01_R_Forearm", upper = "ValveBiped.Bip01_R_UpperArm", foot = "ValveBiped.Bip01_R_Foot", thigh = "ValveBiped.Bip01_R_Thigh", phase = 0, out = -1 },
	{ hand = "ValveBiped.Bip01_L_Hand", fore = "ValveBiped.Bip01_L_Forearm", upper = "ValveBiped.Bip01_L_UpperArm", foot = "ValveBiped.Bip01_L_Foot", thigh = "ValveBiped.Bip01_L_Thigh", phase = math.pi, out = 1 },
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
	phys:Wake()
	phys:AddVelocity(((target - phys:GetPos()) * k - phys:GetVelocity() * damp) * dt)
end

local function Float(prey, on)
	if prey.floating == on then return end
	prey.floating = on
	for _, side in ipairs(prey.sides) do
		for _, phys in ipairs(side.arm) do
			if IsValid(phys) then phys:EnableGravity(not on) end
		end
	end
end

function EvilBarnacle.Prey(body, maw, fighter)
	local prey = {
		body = body, maw = maw, start = CurTime(), voice = Voice(body:GetModel()),
		head = Phys(body, EvilBarnacle.HEAD), pelvis = Phys(body, "ValveBiped.Bip01_Pelvis"),
		sides = {}, stride = 0, plead = 0, heave = 0, burst = 0, burstEnd = 0,
	}
	for _, def in ipairs(SIDES) do
		local side = { def = def, hand = Phys(body, def.hand), foot = Phys(body, def.foot), thigh = Phys(body, def.thigh), aim = Vector(), kick = Vector(), claw = 0, jolt = 0 }
		side.arm = { side.hand, Phys(body, def.fore), Phys(body, def.upper) }
		if side.hand and side.foot and side.thigh then prey.sides[#prey.sides + 1] = side end
	end
	prey.fighter = fighter and prey.head ~= nil and prey.pelvis ~= nil and #prey.sides == #SIDES
	if prey.fighter then
		Face(body, PANIC_FACE)
		Float(prey, true)
	end
	return prey
end

function EvilBarnacle.Calm(prey)
	if prey then Float(prey, false) end
end

local function Claw(prey, now, dt)
	local maw = prey.maw
	local head = maw:WorldToLocal(prey.head:GetPos())
	for _, side in ipairs(prey.sides) do
		if now >= side.claw then
			side.claw = now + math.Rand(CLAW_MIN, CLAW_MAX)
			local a = math.Rand(0, math.pi * 2)
			local r = math.Rand(CLAW_IN, CLAW_OUT)
			side.aim = Vector(math.cos(a) * r, math.sin(a) * r, -math.Rand(0, YANK))
		end
		local top = math.min(head.z + CLAW_UP, LIP)
		local target = maw:LocalToWorld(Vector(head.x + side.aim.x, head.y + side.aim.y, top + side.aim.z))
		Spring(side.hand, target, CLAW_K, CLAW_DAMP, dt)
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
	prey.pelvis:Wake()
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
	Float(prey, false)
	prey.still = now + SETTLE
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

local function Still(prey, now)
	if not prey.frozen then
		if now < prey.still then return end
		prey.frozen = true
		local body = prey.body
		for i = 0, body:GetPhysicsObjectCount() - 1 do
			local phys = body:GetPhysicsObjectNum(i)
			if IsValid(phys) then phys:EnableMotion(false) end
		end
	end
	if now < (prey.wireAt or 0) or not (EvilFungus and EvilFungus.Wire) then return end
	prey.wireAt = now + WIRE_EVERY
	prey.wired = IsValid(prey.head) and EvilFungus.Wire(prey.body, prey.head:GetPos(), EvilBarnacle.Settings:Get("fungus_time"))
end

local function Legs(prey, now)
	local f = 1 - math.Clamp((now - prey.start - PANIC) / FADE, 0, 1)
	if f >= 1 then return 1 end
	if now >= prey.burst then
		prey.burstEnd = now + math.Rand(0.4, 1.2) * (0.5 + f)
		prey.burst = prey.burstEnd + math.Rand(0.6, 1.4) * Lerp(f, 3, 0.2)
	end
	return now < prey.burstEnd and f or 0
end

local function Fight(prey, now, dt, up)
	local k = Legs(prey, now)
	Kick(prey, now, dt, up, k)
	if now - prey.start < PANIC then
		Claw(prey, now, dt)
		Heave(prey, now, up)
		Plead(prey, now)
	else
		Float(prey, false)
		if k > 0 then Moan(prey, now) end
	end
	if now - prey.start >= PANIC + FADE then Limp(prey, now) end
end

function EvilBarnacle.Thrash(prey, now, dt)
	if not prey or not prey.fighter or not IsValid(prey.maw) then return end
	Claw(prey, now, dt)
	Kick(prey, now, dt, prey.maw:GetUp(), 1)
	Plead(prey, now)
end

function EvilBarnacle.Hold(maw, body, prey)
	prey = prey or EvilBarnacle.Prey(body, maw, false)
	prey.maw = maw
	held[body] = prey
end

function EvilBarnacle.Seated(body)
	local prey = held[body]
	if prey and not prey.fighter then Limp(prey, CurTime()) end
end

function EvilBarnacle.Free(body)
	local prey = held[body]
	held[body] = nil
	if not prey or not IsValid(body) then return end
	if prey.wired then EvilFungus.Unwire(body) end
	Float(prey, false)
	for i, d in pairs(prey.damping or {}) do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:SetDamping(d[1], d[2]) end
	end
end

hook.Add("Think", "EvilBarnaclePrey", function()
	local now, dt = CurTime(), FrameTime()
	for body, prey in pairs(held) do
		if not IsValid(body) or not IsValid(prey.maw) or body.EvilBond ~= prey.maw then
			held[body] = nil
		elseif prey.limp then
			Still(prey, now)
		elseif prey.fighter then
			Fight(prey, now, dt, prey.maw:GetUp())
		end
	end
end)
