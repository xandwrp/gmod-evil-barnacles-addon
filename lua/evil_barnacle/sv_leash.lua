local REST = 16
local LOWER = 40
local LOWER_TO = 60
local REEL = 220
local REEL_TIME = 12
local REEL_NEAR = 40
local DRAG_UP = 10
local DROP_TIME = 3
local DROP_REACH = 90
local MASH_DECAY = 0.1
local FOOT = "ValveBiped.Bip01_R_Foot"
local LOWER_SOUND = "npc/barnacle/barnacle_tongue_pull%d.wav"
local WHIP = "weapons/iceaxe/iceaxe_swing1.wav"
local SLAP = "physics/flesh/flesh_impact_hard%d.wav"

local LOWERING, WALKING, REELING, DROPPING = 1, 2, 3, 4

local leashes = {}

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
	if b:Health() > 0 and not IsValid(b.EvilBond) then b:SetKeyValue("RestDist", tostring(REST)) end
end

local function Pose(b, ent)
	local l = leashes[b]
	if l and l.victim == ent then return l.at + Vector(0, 0, DRAG_UP) end
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

local function HeadPhys(body)
	local bone = body:LookupBone(EvilBarnacle.HEAD)
	local i = bone and body:TranslateBoneToPhysBone(bone)
	local phys = i and i >= 0 and body:GetPhysicsObjectNum(i)
	if IsValid(phys) then return phys end
end

function EvilBarnacle.Lower(b, body)
	local radius = EvilBarnacle.Settings:Get("leash")
	local hosts = EvilFungus and EvilFungus.Hosts
	if radius <= 0 or leashes[b] or not (hosts and hosts.Unleash) or b.EvilBond ~= body then return end
	local floor, head = EvilBarnacle.Below(b), HeadPhys(body)
	if not floor or not head then return end
	EvilBarnacle.Shed(b, true)
	head:EnableMotion(false)
	body.EvilLeash = b
	leashes[b] = { phase = LOWERING, body = body, head = head, at = floor, radius = radius, height = b:GetPos().z - floor.z }
	Point(b, body, EvilBarnacle.HEAD)
	b:EmitSound(string.format(LOWER_SOUND, math.random(1, 3)), 75, math.random(80, 95))
end

local function Lowering(b, l, dt)
	local body, head = l.body, l.head
	if not IsValid(body) or not IsValid(head) then return Finish(b) end
	local pos = head:GetPos()
	local goal = l.at.z + LOWER_TO
	if pos.z > goal then
		head:SetPos(Vector(pos.x, pos.y, math.max(goal, pos.z - LOWER * dt)))
		return
	end
	head:EnableMotion(true)
	head:Wake()
	l.tether = { at = l.at, radius = l.radius, catch = function(_, v) return Throw(b, l, v) end }
	if not EvilFungus.Hosts.Rise(EvilFungus.Sleep.wired[body] or { rag = body }, l.tether) then
		EvilFungus.Unwire(body)
		return Finish(b)
	end
	l.phase = WALKING
end

local function Walking(b, l)
	local h = EvilFungus.Hosts.list[l.body]
	if not h or h.tether ~= l.tether then Finish(b) end
end

local function Reeling(b, l, now)
	local v = l.victim
	local rag = IsValid(v) and Evil.Downed(v)
	if not IsValid(rag) or Evil.Owner(v) ~= b then return Finish(b) end
	if now - l.since > REEL_TIME then return Slip(b, v) end
	if l.phase == REELING then
		local p = rag:GetPos()
		if (p.x - l.at.x) ^ 2 + (p.y - l.at.y) ^ 2 > REEL_NEAR * REEL_NEAR then return end
		l.phase, l.since = DROPPING, now
		b:SetKeyValue("RestDist", tostring(REST))
		return
	end
	local alt = tonumber(b:GetInternalVariable("m_flAltitude"))
	if now - l.since < DROP_TIME and not (alt and alt >= l.height - DROP_REACH) then return end
	local m = Evil.Mashing(v)
	if m and m.source == b then Evil.StopMash(v) end
	Finish(b)
	Evil.Up(v)
end

local function Cut(b, l)
	if l.phase == LOWERING then
		if IsValid(l.head) then
			l.head:EnableMotion(true)
			l.head:Wake()
		end
		if IsValid(l.body) then EvilFungus.Unwire(l.body) end
	elseif l.phase == WALKING then
		EvilFungus.Hosts.Unleash(l.body)
	elseif IsValid(l.victim) then
		return Slip(b, l.victim)
	end
	Finish(b)
end

hook.Add("Think", "EvilBarnacleLeash", function()
	local now, dt = CurTime(), FrameTime()
	for b, l in pairs(leashes) do
		if not IsValid(b) or b:Health() <= 0 then
			Cut(b, l)
		elseif l.phase == LOWERING then
			Lowering(b, l, dt)
		elseif l.phase == WALKING then
			Walking(b, l)
		else
			Reeling(b, l, now)
		end
	end
end)
