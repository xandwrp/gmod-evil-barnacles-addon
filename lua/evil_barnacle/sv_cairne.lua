local CEILING = -0.7
local GAP = 28
local BACK, LIMB_BACK = 7, 3
local ARM_SPREAD, LEG_SPREAD = math.rad(55), math.rad(16)
local STRETCH = 0.95
local ROPE_OUT, CROTCH_ROPE, HIPS_ROPE = 8, 8, 10
local FOOTPRINT, WIDTH = 120, 32
local PROBE_DEPTH, PROBE_UP = 8, 16
local SPACING = 70
local TRIES = 8
local GRAB = 0.6
local WEIGHT = 0.3
local PULL_K, PULL_DAMP = 60, 12
local PIN_K, PIN_DAMP = 150, 20
local FADE = 24
local HOLD_BACK = 0.7
local JERK_MIN, JERK_MAX = 0.25, 0.7
local AWAY = 0.6
local SETTLE = 3
local WIRE_EVERY = 2
local MASH_DECAY = 0.1
local PELVIS = "ValveBiped.Bip01_Pelvis"
local R_THIGH, L_THIGH = "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_L_Thigh"
local LIMBS = {
	{ "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand", side = 1, spread = ARM_SPREAD },
	{ "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand", side = -1, spread = ARM_SPREAD },
	{ R_THIGH, "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot", side = 1, spread = math.pi - LEG_SPREAD },
	{ L_THIGH, "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot", side = -1, spread = math.pi - LEG_SPREAD },
}
local JERK = {
	["ValveBiped.Bip01_R_Hand"] = 240, ["ValveBiped.Bip01_L_Hand"] = 240,
	["ValveBiped.Bip01_R_Foot"] = 280, ["ValveBiped.Bip01_L_Foot"] = 280,
	[PELVIS] = 170, ["ValveBiped.Bip01_Spine2"] = 150, [EvilBarnacle.HEAD] = 130,
}

local HOIST = EvilBarnacle.CAIRNE_HOIST
local FIGHT = HOIST + EvilBarnacle.CAIRNE_WRAP

local hung = {}
local cairns = {}

local function Phys(body, name)
	local bone = body:LookupBone(name)
	local i = bone and body:TranslateBoneToPhysBone(bone)
	local phys = i and i >= 0 and body:GetPhysicsObjectNum(i)
	if IsValid(phys) then return i, phys end
end

local function Humanoid(ent)
	return ent:LookupBone(EvilBarnacle.HEAD) and ent:LookupBone(PELVIS) and ent:LookupBone(R_THIGH) and ent:LookupBone(L_THIGH) and true or false
end

local function Point(f, u, r, depth)
	return f.at + f.f * u + f.r * r + f.n * depth
end

local function Above(f, p)
	return p - f.n * (p - f.at):Dot(f.n)
end

local function Open(a, b)
	return not util.TraceLine({ start = a, endpos = b, mask = MASK_SOLID_BRUSHONLY }).Hit
end

local function Covered(f, p)
	local tr = util.TraceLine({ start = p, endpos = p - f.n * PROBE_UP, mask = MASK_SOLID_BRUSHONLY })
	return tr.Hit and not tr.HitSky
end

local function Clear(f)
	local mid = Point(f, -GAP - 30, 0, PROBE_DEPTH)
	for body, spot in pairs(cairns) do
		if not IsValid(body) then
			cairns[body] = nil
		elseif spot:DistToSqr(mid) < SPACING * SPACING then
			return false
		end
	end
	for _, p in ipairs({ mid, Point(f, -GAP - 8, 0, PROBE_DEPTH) }) do
		if not Open(p, p + f.r * WIDTH) or not Open(p, p - f.r * WIDTH) then return false end
	end
	local near, far = Point(f, -GAP * 0.5, 0, PROBE_DEPTH), Point(f, -FOOTPRINT, 0, PROBE_DEPTH)
	return Open(near, far) and Covered(f, near) and Covered(f, mid) and Covered(f, far)
end

local function Frame(b)
	local pos = b:GetPos()
	local tr = util.TraceLine({ start = pos, endpos = pos + Vector(0, 0, PROBE_UP), mask = MASK_SOLID_BRUSHONLY })
	if not tr.Hit or tr.HitSky or tr.HitNormal.z >= CEILING then return end
	local n = tr.HitNormal
	local spin = math.Rand(0, 360)
	for i = 0, TRIES - 1 do
		local out = Angle(0, spin + i * 360 / TRIES, 0):Forward()
		out = out - n * out:Dot(n)
		out:Normalize()
		local f = { at = tr.HitPos, n = n, f = -out, r = n:Cross(-out) }
		if Clear(f) then return f end
	end
end

local function Layout(body, f)
	local pi, pelvis = Phys(body, PELVIS)
	local _, head = Phys(body, EvilBarnacle.HEAD)
	local _, rt = Phys(body, R_THIGH)
	local _, lt = Phys(body, L_THIGH)
	if not (pelvis and head and rt and lt) then return end
	local o = pelvis:GetPos()
	local up = head:GetPos() - o
	up:Normalize()
	local right = rt:GetPos() - lt:GetPos()
	right = right - up * right:Dot(up)
	if right:LengthSqr() < 0.01 then return end
	right:Normalize()
	local front = up:Cross(right)
	local function Body(p)
		local d = p - o
		return d:Dot(up), d:Dot(right), d:Dot(front)
	end
	local hu = Body(head:GetPos())
	local u0 = -GAP - hu
	local targets = {}
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local u, r, d = Body(phys:GetPos())
			targets[i] = Point(f, u0 + u, r, math.max(LIMB_BACK, BACK + d))
		end
	end
	local ropes = {}
	for k, limb in ipairs(LIMBS) do
		local a, pa = Phys(body, limb[1])
		local b, pb = Phys(body, limb[2])
		local c, pc = Phys(body, limb[3])
		if a and b and c and a ~= b and b ~= c and a ~= c then
			local u, r = Body(pa:GetPos())
			u = u0 + u
			local du, dr = math.cos(limb.spread), math.sin(limb.spread) * limb.side
			local l1 = pa:GetPos():Distance(pb:GetPos()) * STRETCH
			local l2 = l1 + pb:GetPos():Distance(pc:GetPos()) * STRETCH
			targets[b] = Point(f, u + du * l1, r + dr * l1, LIMB_BACK + 1)
			targets[c] = Point(f, u + du * l2, r + dr * l2, LIMB_BACK)
			ropes[k] = Above(f, targets[c]) + (f.f * du + f.r * dr) * ROPE_OUT
		elseif c then
			ropes[k] = Above(f, targets[c])
		end
	end
	local seat = Above(f, targets[pi])
	ropes[5] = seat - f.f * CROTCH_ROPE
	ropes[6] = seat + f.r * HIPS_ROPE
	return targets, targets[pi], ropes
end

local function Pins(body, targets)
	local pull = {}
	for _, name in ipairs(EvilBarnacle.CAIRNE_ROPES) do pull[name] = (pull[name] or 0) + 1 end
	local pins = {}
	for i, target in pairs(targets) do
		local phys = body:GetPhysicsObjectNum(i)
		local name = body:GetBoneName(body:TranslatePhysBoneToBone(i))
		pins[#pins + 1] = { i = i, phys = phys, name = name, target = target, from = phys:GetPos(), pull = pull[name], jerk = JERK[name], next = 0 }
	end
	return pins
end

local function Spring(phys, target, k, damp, dt)
	phys:AddVelocity(((target - phys:GetPos()) * k - phys:GetVelocity() * damp) * dt)
end

local function Float(c, on)
	if c.floating == on then return end
	c.floating = on
	for _, p in ipairs(c.pins) do
		if IsValid(p.phys) then p.phys:EnableGravity(not on) end
	end
end

local function Mark(c)
	local body = c.body
	body:SetNW2Vector(EvilBarnacle.CAIRNE_AT_VAR, c.frame.at)
	body:SetNW2Vector(EvilBarnacle.CAIRNE_UP_VAR, c.frame.n)
	for i, rope in pairs(c.ropes) do body:SetNW2Vector(EvilBarnacle.CAIRNE_ROPE_VAR .. i, rope) end
	body:SetNW2Float(EvilBarnacle.CAIRNE_VAR, c.start)
end

local function Adopt(c, body)
	local was = c.prey
	c.body = body
	body.EvilCairne = true
	body:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	body:AddSolidFlags(FSOLID_NOT_SOLID)
	if IsValid(c.maw) then Evil.Claim(body, c.maw) end
	c.prey = EvilBarnacle.Prey(body, c.maw, true)
	EvilBarnacle.Calm(c.prey)
	if was then c.prey.muffled, c.prey.plead = was.muffled, was.plead end
	for _, p in ipairs(c.pins) do p.phys = body:GetPhysicsObjectNum(p.i) end
	c.floating = nil
	Float(c, true)
	Mark(c)
	hung[body], cairns[body] = c, c.spot
end

local function Drop(c)
	local body = c.body
	hung[body], cairns[body] = nil, nil
	if not IsValid(body) then return end
	body.EvilCairne = nil
	body:RemoveSolidFlags(FSOLID_NOT_SOLID)
	body:SetNW2Float(EvilBarnacle.CAIRNE_VAR, 0)
	Float(c, false)
	Evil.Unclaim(body)
	for _, p in ipairs(c.pins) do
		if IsValid(p.phys) then
			p.phys:EnableMotion(true)
			p.phys:Wake()
		end
	end
end

local function Escape(c)
	local v = c.victim
	c.victim = nil
	Drop(c)
	if not IsValid(v) then return end
	local m = Evil.Mashing(v)
	if m and m.source == c.maw then Evil.StopMash(v) end
	Evil.LetGo(v, 1)
end

local function Lock(c)
	local v, old = c.victim, c.body
	local rag = EvilBarnacle.Clone(old)
	if not rag then
		Escape(c)
		return false
	end
	c.victim = nil
	local m = Evil.Mashing(v)
	if m and m.source == c.maw then Evil.StopMash(v) end
	hung[old], cairns[old] = nil, nil
	v.EvilSocket = rag
	v:SetNW2Float(EvilBarnacle.HELD_VAR, CurTime())
	if v:Alive() then
		v:KillSilent()
	else
		v:Spectate(OBS_MODE_CHASE)
		v:SpectateEntity(rag)
	end
	old:Remove()
	Adopt(c, rag)
	return true
end

local function Pull(c, t, dt)
	local h = math.Clamp(t / HOIST, 0, 1)
	h = h * h * (3 - 2 * h)
	local grab = math.min(t / GRAB, 1)
	local fall = physenv.GetGravity() * (WEIGHT * dt)
	for _, p in ipairs(c.pins) do
		local phys = p.phys
		if IsValid(phys) then
			phys:Wake()
			local w = EvilBarnacle.Wrapped(t, p.name)
			phys:AddVelocity(fall * (1 - w))
			local k, target = PIN_K * w, p.target
			if p.pull then
				k = math.max(k, PULL_K * p.pull * grab)
				target = LerpVector(h, p.from, p.target)
			end
			if k > 0 then Spring(phys, target, k, Lerp(w, PULL_DAMP, PIN_DAMP), dt) end
		end
	end
end

local function Burst(c, now, f)
	if now >= c.burst then
		c.burstEnd = now + math.Rand(0.4, 1.2) * (0.5 + f)
		c.burst = c.burstEnd + math.Rand(0.6, 1.4) * Lerp(f, 3, 0.2)
	end
	return now < c.burstEnd
end

local function Fight(c, now, t)
	local f = 1 - math.Clamp((t - FIGHT) / FADE, 0, 1)
	if f <= 0 then
		c.limp, c.still = true, now + SETTLE
		return
	end
	local prey = c.prey
	if not prey.muffled and EvilBarnacle.Wrapped(t, EvilBarnacle.HEAD) >= 0.5 then EvilBarnacle.Muffle(prey) end
	local active = f >= 1 or Burst(c, now, f)
	if f >= 1 then
		EvilBarnacle.Plead(prey, now)
	elseif active then
		EvilBarnacle.Moan(prey, now)
	end
	if not active then return end
	for _, p in ipairs(c.pins) do
		if p.jerk and now >= p.next and IsValid(p.phys) then
			p.next = now + math.Rand(JERK_MIN, JERK_MAX)
			local dir = VectorRand() + c.frame.n * AWAY
			dir:Normalize()
			p.phys:AddVelocity(dir * (p.jerk * f * (1 - HOLD_BACK * EvilBarnacle.Wrapped(t, p.name))))
		end
	end
end

local function Still(c, now)
	if now < c.still then return end
	c.frozen = true
	for _, p in ipairs(c.pins) do
		if IsValid(p.phys) then p.phys:EnableMotion(false) end
	end
end

local function Wire(c, now)
	if now < c.wireAt then return end
	c.wireAt = now + WIRE_EVERY
	local _, head = Phys(c.body, EvilBarnacle.HEAD)
	if head and EvilFungus.Wire(c.body, head:GetPos(), EvilBarnacle.Settings:Get("fungus_time")) then hung[c.body] = nil end
end

local function Hang(c, now, dt)
	local t = now - c.start
	local v = c.victim
	if v then
		if not IsValid(v) or v:Alive() and Evil.Downed(v) ~= c.body then return Drop(c) end
		if (t >= FIGHT or not v:Alive()) and not Lock(c) then return end
	end
	if t < HOIST and not (IsValid(c.maw) and c.maw:Health() > 0) then return Escape(c) end
	if c.frozen then return Wire(c, now) end
	Pull(c, t, dt)
	if c.limp then
		Still(c, now)
	else
		Fight(c, now, t)
	end
end

hook.Add("Think", "EvilBarnacleCairne", function()
	local now, dt = CurTime(), FrameTime()
	local list = {}
	for _, c in pairs(hung) do list[#list + 1] = c end
	for _, c in ipairs(list) do
		if not IsValid(c.body) then
			hung[c.body], cairns[c.body] = nil, nil
		elseif hung[c.body] == c then
			Hang(c, now, dt)
		end
	end
end)

function EvilBarnacle.Cairne(b, v)
	if EvilBarnacle.Settings:Get("cairne") <= 0 or not (EvilFungus and EvilFungus.Wire) then return false end
	local player = v:IsPlayer()
	local rag = not player and b:GetInternalVariable("m_hRagdoll")
	if player then
		if not v:Alive() or not Evil.Claimable(v) or not Humanoid(v) then return false end
	elseif not (v:IsNPC() and IsValid(rag) and Humanoid(rag)) then
		return false
	end
	local f = Frame(b)
	if not f then return false end
	b:Input("LetGo")
	local body
	if player then
		body = Evil.Grip(v, b)
	elseif not IsValid(b:GetInternalVariable("m_hRagdoll")) then
		body = EvilBarnacle.Clone(rag)
		if body then rag:Remove() else body = rag end
		v:Remove()
	end
	if not IsValid(body) then return true end
	local targets, spot, ropes = Layout(body, f)
	if not targets then
		if player then Evil.LetGo(v, 1) end
		return true
	end
	local c = {
		maw = b, frame = f, start = CurTime(), spot = spot, ropes = ropes, pins = Pins(body, targets),
		victim = player and v or nil, burst = 0, burstEnd = 0, wireAt = 0,
	}
	Adopt(c, body)
	if player then
		Evil.Mash(v, b, {
			gain = 1 / EvilBarnacle.Settings:Get("escape_presses"), decay = MASH_DECAY,
			done = function()
				if c.victim ~= v then return end
				Escape(c)
				if IsValid(b) then b:EmitSound("NPC_Barnacle.Pain") end
			end,
		})
	end
	return true
end
