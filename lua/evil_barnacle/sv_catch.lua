local MASH_DECAY = 0.1
local SHUN = 3

local barnacles = {}
local caught = {}

function EvilBarnacle.Add(b)
	b.EvilBarnacle = true
	barnacles[b] = true
end

local function Head(body)
	local bone = body:LookupBone(EvilBarnacle.HEAD)
	local head = bone and body:TranslateBoneToPhysBone(bone)
	if head and head >= 0 then return head end
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
	local head = Head(body)
	if not head then
		body:Remove()
		return
	end
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		local m = IsValid(phys) and v:GetBoneMatrix(body:TranslatePhysBoneToBone(i))
		if m then
			phys:SetPos(m:GetTranslation(), true)
			phys:SetAngles(m:GetAngles())
			phys:Wake()
		end
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
	EvilBarnacle.Bond(b, body, head, health, c.prey)
end

local function Catch(b, v)
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
		if not IsValid(c.body) or b:GetInternalVariable("m_hRagdoll") ~= c.body then return Drop(b, c) end
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
		elseif not caught[b] and b:Health() > 0 and b:GetInternalVariable("m_bLiftingPrey") then
			local v = b:GetEnemy()
			if IsValid(v) then Catch(b, v) end
		end
	end
	for b, c in pairs(caught) do Hang(b, c, now, dt) end
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

hook.Add("PlayerSpawn", "EvilBarnacleSocket", function(ply)
	ply.EvilSocket = nil
end)
