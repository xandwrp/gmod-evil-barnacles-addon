local MASH_DECAY = 0.1
local SHUN = 3
local STRAY = 64
local CARRY = { "start", "stride", "plead", "heave", "burst", "burstEnd", "muffled" }

local barnacles = {}
local caught = {}

function EvilBarnacle.Add(b)
	b.EvilBarnacle, b.EvilFungusAlly = true, true
	barnacles[b] = true
end

local function Head(body)
	local bone = body:LookupBone(EvilBarnacle.HEAD)
	local head = bone and body:TranslateBoneToPhysBone(bone)
	if head and head >= 0 then return head end
end

local function Posed(v, bone)
	if not bone or bone < 0 or not (v:BoneHasFlag(bone, BONE_USED_BY_HITBOX) or v:BoneHasFlag(bone, BONE_USED_BY_ATTACHMENT)) then return end
	local m = v:GetBoneMatrix(bone)
	if not m then return end
	local p = m:GetTranslation()
	if p.x ~= p.x or p.y ~= p.y or p.z ~= p.z then return end
	local reach = STRAY + v:BoundingRadius()
	if p:DistToSqr(v:WorldSpaceCenter()) < reach * reach then return m end
end

local function Above(body, i)
	local bone = body:GetBoneParent(body:TranslatePhysBoneToBone(i))
	while bone and bone >= 0 do
		local p = body:TranslateBoneToPhysBone(bone)
		if p and p >= 0 and p ~= i then return p end
		bone = body:GetBoneParent(bone)
	end
end

local function Pose(v, body)
	local n = body:GetPhysicsObjectCount()
	local rest, pose = {}, {}
	for i = 0, n - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local m = Matrix()
			m:SetTranslation(phys:GetPos())
			m:SetAngles(phys:GetAngles())
			rest[i] = m
			pose[i] = Posed(v, body:TranslatePhysBoneToBone(i))
		end
	end
	local function Place(i, depth)
		if pose[i] or not rest[i] or depth > n then return pose[i] end
		local p = Above(body, i)
		local pm = p and rest[p] and Place(p, depth + 1)
		if pm then pose[i] = pm * rest[p]:GetInverseTR() * rest[i] end
		return pose[i]
	end
	for i = 0, n - 1 do
		local m = Place(i, 0)
		if m then
			local phys = body:GetPhysicsObjectNum(i)
			phys:SetPos(m:GetTranslation(), true)
			phys:SetAngles(m:GetAngles())
			phys:SetVelocity(vector_origin)
			phys:Wake()
		end
	end
end

local function Nearest(body, at)
	local best, near
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local d = phys:GetPos():DistToSqr(at)
			if not near or d < near then best, near = i, d end
		end
	end
	return best
end

local function Corpse(v)
	local model = v:GetModel()
	if not model or not util.IsValidRagdoll(model) then return end
	local body = ents.Create("prop_ragdoll")
	if not IsValid(body) then return end
	body:SetModel(model)
	body:SetPos(v:GetPos())
	body:SetAngles(Angle(0, v:GetAngles().y, 0))
	body:SetSkin(v:GetSkin())
	for i = 0, v:GetNumBodyGroups() - 1 do body:SetBodygroup(i, v:GetBodygroup(i)) end
	body:SetMaterial(v:GetMaterial())
	body:SetColor(v:GetColor())
	body:SetNW2Vector("EvilColor", v:GetPlayerColor())
	body:Spawn()
	body:Activate()
	Pose(v, body)
	local head = Head(body) or Nearest(body, v:EyePos())
	if not head then
		body:Remove()
		return
	end
	return body, head
end

local function Shun(ply)
	if ply:IsFlagSet(FL_NOTARGET) then return end
	ply:AddFlags(FL_NOTARGET)
	timer.Simple(SHUN, function()
		if IsValid(ply) then ply:RemoveFlags(FL_NOTARGET) end
	end)
end

local function Release(b, c)
	caught[b] = nil
	local v = c.victim
	if not IsValid(v) or not v:IsPlayer() then return end
	v.EvilCaught = nil
	local m = Evil.Mashing(v)
	if m and m.source == b then Evil.StopMash(v) end
	Evil.Unclaim(v, b)
end

local function Drop(b, c)
	Release(b, c)
	if c.prey then EvilBarnacle.Calm(c.prey) end
end

local function Escape(b, ply)
	local c = caught[b]
	if not c or c.victim ~= ply then return end
	Release(b, c)
	if IsValid(b) then
		b:Input("LetGo")
		b:EmitSound("NPC_Barnacle.Pain")
	end
	Shun(ply)
end

local function Socket(b, c)
	local v = c.victim
	local body, head = Corpse(v)
	Release(b, c)
	if not body then return end
	b:Input("LetGo")
	v.EvilSocket = body
	v:KillSilent()
	v:SetNW2Float(EvilBarnacle.HELD_VAR, CurTime())
	EvilBarnacle.Bond(b, body, head, math.max(v:GetMaxHealth(), 1))
end

local function Transfer(b, c)
	local v, body = c.victim, c.body
	local head = Head(body)
	if not head then return Drop(b, c) end
	local health = IsValid(v) and math.max(v:GetMaxHealth(), 1) or 100
	b:Input("LetGo")
	if IsValid(b:GetInternalVariable("m_hRagdoll")) then return Drop(b, c) end
	Release(b, c)
	if IsValid(v) then v:Remove() end
	local prey = c.prey
	local fresh = not c.fed and EvilBarnacle.Clone(body)
	if fresh then
		local was = prey
		EvilBarnacle.Calm(was)
		body:Remove()
		body = fresh
		prey = EvilBarnacle.Prey(body, b, true)
		if was then
			for _, k in ipairs(CARRY) do prey[k] = was[k] end
		end
	end
	EvilBarnacle.Bond(b, body, head, health, prey)
end

local function Host(v)
	local hosts = EvilFungus and EvilFungus.Hosts
	return hosts and hosts.list and hosts.list[v] ~= nil
end

local function Fed(v)
	return v:GetClass() == "prop_ragdoll" and v.EvilHealth == nil and not v.EvilFungusSleeper and not Evil.Owner(v) and Head(v) ~= nil
end

local function Catch(b, v)
	if not v:IsPlayer() and not v:IsNPC() then
		if Evil.Owner(v) == b or Host(v) then
			b:Input("LetGo")
		elseif Fed(v) then
			caught[b] = { body = v, fed = true }
		end
		return
	end
	if EvilBarnacle.Cairne(b, v) then return end
	if v:IsPlayer() then
		if not v:Alive() or not Evil.Claim(v, b) then return end
		caught[b] = { victim = v }
		v.EvilCaught = b
		Evil.Mash(v, b, {
			gain = 1 / EvilBarnacle.Settings:Get("escape_presses"), decay = MASH_DECAY,
			done = function() Escape(b, v) end,
		})
	elseif v:IsNPC() then
		local body = b:GetInternalVariable("m_hRagdoll")
		if not IsValid(body) then return end
		caught[b] = { victim = v, body = body, prey = EvilBarnacle.Prey(body, b, true) }
	end
end

local function Hang(b, c, now, dt)
	if not IsValid(b) or b:Health() <= 0 then return Drop(b, c) end
	local lifting = b:GetInternalVariable("m_bLiftingPrey")
	if c.body then
		local on = c.fed and b:GetEnemy() or b:GetInternalVariable("m_hRagdoll")
		if not IsValid(c.body) or on ~= c.body then return Drop(b, c) end
		if not lifting then return Transfer(b, c) end
		EvilBarnacle.Thrash(c.prey, now, dt)
		return
	end
	local v = c.victim
	if not IsValid(v) or not v:Alive() or b:GetEnemy() ~= v then return Drop(b, c) end
	if not lifting then Socket(b, c) end
end

hook.Add("Think", "EvilBarnacleCatch", function()
	local now, dt = CurTime(), FrameTime()
	for b in pairs(barnacles) do
		if not IsValid(b) then
			barnacles[b] = nil
		elseif not caught[b] and b:Health() > 0 and b:GetInternalVariable("m_bLiftingPrey") and not EvilBarnacle.Leashed(b) then
			local v = b:GetEnemy()
			if IsValid(v) then Catch(b, v) end
		end
	end
	for b, c in pairs(caught) do Hang(b, c, now, dt) end
end)

hook.Add("EntityTakeDamage", "EvilBarnacleKnocks", function(ent, dmg)
	if not ent.EvilBarnacle or not dmg:IsDamageType(DMG_CRUSH) then return end
	local by = dmg:GetAttacker()
	if IsValid(by) and string.StartWith(by:GetClass(), "prop_ragdoll") then return true end
end)

hook.Add("EntityTakeDamage", "EvilBarnacleCatch", function(ent, dmg)
	local b = ent.EvilCaught
	if not IsValid(b) or not caught[b] or caught[b].victim ~= ent then return end
	if dmg:GetAttacker() == b or dmg:GetInflictor() == b or dmg:IsDamageType(DMG_CRUSH) then return true end
end)

hook.Add("PostPlayerDeath", "EvilBarnacleSocket", function(ply)
	local body = ply.EvilSocket
	if not IsValid(body) then return end
	ply:Spectate(OBS_MODE_CHASE)
	ply:SpectateEntity(body)
end)

hook.Add("PlayerDeathThink", "EvilBarnacleSocket", function(ply)
	local body = ply.EvilSocket
	if not IsValid(body) or not (IsValid(body.EvilBond) or IsValid(body.EvilLeash) or body.EvilCairne) then return end
	if CurTime() - ply:GetNW2Float(EvilBarnacle.HELD_VAR, 0) < EvilBarnacle.GIVE_UP or not ply:KeyPressed(IN_JUMP) then return false end
	ply.EvilSocket = nil
	ply:SetNW2Float(EvilBarnacle.HELD_VAR, 0)
end)

hook.Add("PlayerSpawn", "EvilBarnacleSocket", function(ply)
	ply.EvilSocket = nil
	ply:SetNW2Float(EvilBarnacle.HELD_VAR, 0)
end)
