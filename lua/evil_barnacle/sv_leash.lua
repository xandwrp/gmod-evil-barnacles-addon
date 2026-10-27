local HOLE = 40
local LAND = 64
local LOOK_UP = 32
local TOSS = 120
local SETTLE_MIN = 1
local SETTLE_MAX = 4
local SETTLE_SPEED = 30
local REEL = 220
local REEL_TIME = 12
local REEL_NEAR = 24
local DRAG_UP = 10
local STAND_UP = 4
local MASH_DECAY = 0.1
local FOOT = "ValveBiped.Bip01_R_Foot"
local LOWER_SOUND = "npc/barnacle/barnacle_tongue_pull%d.wav"
local WHIP = "weapons/iceaxe/iceaxe_swing1.wav"
local SLAP = "physics/flesh/flesh_impact_hard%d.wav"

local DROPPING, WALKING, REELING = 1, 2, 3

local leashes = {}

function EvilBarnacle.Leashed(b)
	return leashes[b] ~= nil
end

local function Lifting(b)
	return b:GetInternalVariable("m_bLiftingPrey") == true
end

local function Point(b, ent, bone)
	b:SetNW2Entity(EvilBarnacle.LEASH_VAR, ent or NULL)
	b:SetNW2String(EvilBarnacle.LEASH_BONE_VAR, bone or "")
end

local function Finish(b)
	local l = leashes[b]
	leashes[b] = nil
	if l and IsValid(l.body) and l.body.EvilLeash == b then l.body.EvilLeash = nil end
	if not IsValid(b) then return end
	Point(b)
	EvilBarnacle.Rest(b)
end

local function Pose(b, ent)
	local l = leashes[b]
	if l and l.victim == ent then return l.at + Vector(0, 0, DRAG_UP) end
end

local function Foot(rag)
	local bone = rag:LookupBone(FOOT)
	local i = bone and rag:TranslateBoneToPhysBone(bone)
	local phys = i and i >= 0 and rag:GetPhysicsObjectNum(i)
	return IsValid(phys) and phys:GetPos() or rag:GetPos()
end

local function Under(v, at)
	local pos = at + Vector(0, 0, STAND_UP)
	local tr = util.TraceHull({
		start = pos, endpos = pos, mins = v:OBBMins(), maxs = v:OBBMaxs(),
		mask = v:IsPlayer() and MASK_PLAYERSOLID or MASK_NPCSOLID, filter = v,
	})
	if not tr.StartSolid then v:SetPos(pos) end
end

local function Slip(b, v)
	local m = Evil.Mashing(v)
	if m and m.source == b then Evil.StopMash(v) end
	if not IsValid(b) or Evil.Owner(v) == b then Evil.LetGo(v, 1) end
	Finish(b)
end

local function Throw(b, l, v)
	if leashes[b] ~= l or l.phase ~= WALKING or not IsValid(b) or b:Health() <= 0 then return false end
	local rag = Evil.Grip(v, b, { bone = FOOT, speed = REEL })
	if not IsValid(rag) then return false end
	if IsValid(l.body) then l.body.EvilLeash = nil end
	l.phase, l.victim, l.since = REELING, v, CurTime()
	b.EvilPose = Pose
	EvilBarnacle.Rest(b)
	Point(b, rag, FOOT)
	b:EmitSound(WHIP, 75, math.random(70, 85))
	rag:EmitSound(string.format(SLAP, math.random(1, 3)), 75)
	if v:IsPlayer() then
		Evil.Mash(v, b, {
			gain = 1 / EvilBarnacle.Settings:Get("escape_presses"), decay = MASH_DECAY,
			done = function() Slip(b, v) end,
		})
	end
	return true
end

local function Away(at)
	local from = at + Vector(0, 0, LOOK_UP)
	local spin = math.Rand(0, 360)
	local best, far = nil, -1
	for i = 0, 7 do
		local dir = Angle(0, spin + i * 45, 0):Forward()
		local frac = util.TraceLine({ start = from, endpos = from + dir * LAND, mask = MASK_SOLID_BRUSHONLY }).Fraction
		if frac > far then best, far = dir, frac end
		if far >= 1 then break end
	end
	return best
end

function EvilBarnacle.Clone(old)
	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end
	rag:SetModel(old:GetModel())
	rag:SetPos(old:GetPos())
	rag:SetAngles(old:GetAngles())
	rag:SetSkin(old:GetSkin())
	for i = 0, old:GetNumBodyGroups() - 1 do rag:SetBodygroup(i, old:GetBodygroup(i)) end
	rag:SetMaterial(old:GetMaterial())
	for i = 0, #old:GetMaterials() - 1 do
		local m = old:GetSubMaterial(i)
		if m ~= "" then rag:SetSubMaterial(i, m) end
	end
	rag:SetColor(old:GetColor())
	rag:SetRenderMode(old:GetRenderMode())
	rag:Spawn()
	rag:Activate()
	if rag:GetPhysicsObjectCount() ~= old:GetPhysicsObjectCount() then
		rag:Remove()
		return
	end
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local from, to = old:GetPhysicsObjectNum(i), rag:GetPhysicsObjectNum(i)
		if IsValid(from) and IsValid(to) then
			to:SetPos(from:GetPos(), true)
			to:SetAngles(from:GetAngles())
			to:Wake()
		end
	end
	for i = 0, old:GetBoneCount() - 1 do
		local s = old:GetManipulateBoneScale(i)
		if s.x ~= 1 or s.y ~= 1 or s.z ~= 1 then rag:ManipulateBoneScale(i, s) end
	end
	for i = 0, old:GetFlexNum() - 1 do rag:SetFlexWeight(i, old:GetFlexWeight(i)) end
	rag:SetNW2Vector("EvilColor", old:GetNW2Vector("EvilColor"))
	if EvilFungus then
		rag:SetNW2Vector(EvilFungus.COLOR_VAR, old:GetNW2Vector(EvilFungus.COLOR_VAR))
		rag:SetNW2Float(EvilFungus.SINCE_VAR, old:GetNW2Float(EvilFungus.SINCE_VAR))
		rag:SetNW2Float(EvilFungus.CONSUMED_VAR, old:GetNW2Float(EvilFungus.CONSUMED_VAR))
		rag:SetNW2Float(EvilFungus.STAGE_AT_VAR, old:GetNW2Float(EvilFungus.STAGE_AT_VAR))
		rag:SetNW2Int(EvilFungus.STAGE_VAR, old:GetNW2Int(EvilFungus.STAGE_VAR))
		rag:SetNW2Bool(EvilFungus.WHOLE_VAR, old:GetNW2Bool(EvilFungus.WHOLE_VAR))
		rag.EvilFungusKept = old.EvilFungusKept
	end
	return rag
end

local function Watch(old, rag)
	for _, ply in ipairs(player.GetAll()) do
		if ply.EvilSocket == old then
			ply.EvilSocket = rag
			if not ply:Alive() then ply:SpectateEntity(rag) end
		end
	end
end

function EvilBarnacle.Lower(b, body)
	local radius = EvilBarnacle.Settings:Get("leash")
	local hosts = EvilFungus and EvilFungus.Hosts
	if radius <= 0 or leashes[b] or not (hosts and hosts.Unleash) or b.EvilBond ~= body then return end
	local floor = EvilBarnacle.Below(b)
	if not floor then return end
	local rag = EvilBarnacle.Clone(body)
	if not rag then return end
	local w = EvilFungus.Sleep.wired[body]
	EvilBarnacle.Shed(b, true)
	b:SetKeyValue("RestDist", tostring(b:GetPos().z - floor.z))
	EvilFungus.Unwire(body)
	Watch(body, rag)
	body:Remove()
	local push = Away(floor) * TOSS
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then phys:SetVelocity(push) end
	end
	rag.EvilLeash = b
	leashes[b] = { phase = DROPPING, body = rag, fungus = w and w.fungus, at = floor, radius = radius, since = CurTime() }
	Point(b, rag, EvilBarnacle.HEAD)
	b:EmitSound(string.format(LOWER_SOUND, math.random(1, 3)), 75, math.random(80, 95))
end

local function Dropping(b, l, now)
	local rag = l.body
	if not IsValid(rag) then return Finish(b) end
	local root = rag:GetPhysicsObject()
	local wait = now - l.since
	if wait < SETTLE_MIN or wait < SETTLE_MAX and IsValid(root) and root:GetVelocity():Length() > SETTLE_SPEED then return end
	l.tether = { at = l.at, radius = l.radius, hole = math.min(HOLE, l.radius * 0.5), catch = function(_, v) return Throw(b, l, v) end }
	if not EvilFungus.Hosts.Rise({ rag = rag, fungus = l.fungus }, l.tether) then return Finish(b) end
	l.phase = WALKING
end

local function Walking(b, l)
	local h = EvilFungus.Hosts.list[l.body]
	if not h or h.tether ~= l.tether then Finish(b) end
end

local function Reeling(b, l, now)
	local v = l.victim
	local rag = IsValid(v) and Evil.Downed(v)
	if not IsValid(rag) or Evil.Owner(v) ~= b then
		if IsValid(v) then return Slip(b, v) end
		return Finish(b)
	end
	if now - l.since > REEL_TIME then return Slip(b, v) end
	local p = Foot(rag)
	local lifting = Lifting(b)
	if not lifting and (p.x - l.at.x) ^ 2 + (p.y - l.at.y) ^ 2 > REEL_NEAR * REEL_NEAR then return end
	if lifting then b:Input("LetGo") end
	local m = Evil.Mashing(v)
	if m and m.source == b then Evil.StopMash(v) end
	Finish(b)
	Evil.Up(v)
	Under(v, l.at)
end

local function Cut(b, l)
	if l.phase == WALKING then
		EvilFungus.Hosts.Unleash(l.body)
	elseif l.phase == REELING and IsValid(l.victim) then
		return Slip(b, l.victim)
	end
	Finish(b)
end

hook.Add("Think", "EvilBarnacleLeash", function()
	local now = CurTime()
	for b, l in pairs(leashes) do
		if not IsValid(b) or b:Health() <= 0 then
			Cut(b, l)
		elseif l.phase == REELING then
			Reeling(b, l, now)
		else
			if Lifting(b) then b:Input("LetGo") end
			if l.phase == DROPPING then
				Dropping(b, l, now)
			else
				Walking(b, l)
			end
		end
	end
end)
