local FLOOR = 4096
local CLIMB = 18
local SEARCH_LIMIT = 4000
local EAT_LENGTH = 145 / 30
local BITE_CYCLE = 0.16
local SOCKET = -27.8
local YANK = 900
local STRIKE = {
	-33.2, -33.2, -34.9, -38.3, -39.7, -40.6, -71.1, -63.7, -61.6, -60.6, -60.0, -59.2, -57.2,
	-53.5, -48.2, -42.5, -38.7, -37.4, -36.7, -36.1, -35.5, -34.9, -34.2, -33.4, -32.4, -30.4,
	-27.9, -24.9, -21.5, -18.0, -14.3, -10.7, -9.5, -9.2, -9.1, -9.1, -9.1,
}

local pulls = {}

function EvilHeadcrab.Below(barnacle)
	local start = barnacle:GetPos()
	local tr = util.TraceLine({ start = start, endpos = start - Vector(0, 0, FLOOR), mask = MASK_NPCSOLID_BRUSHONLY })
	if tr.Hit and not tr.StartSolid then return tr.HitPos end
end

function EvilHeadcrab.FreeBarnacle(pos, range, skip)
	local now, best, bestDist, bestSpot = CurTime()
	for _, b in ipairs(ents.FindByClass("npc_barnacle")) do
		if b.EvilBarnacle and b:Health() > 0 and not IsValid(b.EvilThrall) and not IsValid(b.EvilBond) and (skip[b] or 0) < now then
			local spot = EvilHeadcrab.Below(b)
			local dist = spot and pos:DistToSqr(spot)
			if dist and dist < range * range and (not best or dist < bestDist) then
				best, bestDist, bestSpot = b, dist, spot
			end
		end
	end
	return best, bestSpot
end

local function Route(came, area)
	local areas = { area }
	while came[area:GetID()] do
		area = came[area:GetID()]
		table.insert(areas, 1, area)
	end
	return areas
end

local function Search(start, goal)
	local target = goal:GetCenter()
	start:ClearSearchLists()
	start:AddToOpenList()
	start:SetCostSoFar(0)
	start:SetTotalCost(start:GetCenter():Distance(target))
	start:UpdateOnOpenList()
	local came, steps = {}, 0
	while not start:IsOpenListEmpty() and steps < SEARCH_LIMIT do
		steps = steps + 1
		local cur = start:PopOpenList()
		if cur == goal then return Route(came, cur) end
		cur:AddToClosedList()
		for _, n in ipairs(cur:GetAdjacentAreas()) do
			local cost = cur:GetCostSoFar() + cur:GetCenter():Distance(n:GetCenter())
			local known = (n:IsOpen() or n:IsClosed()) and n:GetCostSoFar() <= cost
			if not known and not n:IsUnderwater() and cur:ComputeAdjacentConnectionHeightChange(n) <= CLIMB then
				n:SetCostSoFar(cost)
				n:SetTotalCost(cost + n:GetCenter():Distance(target))
				if n:IsClosed() then n:RemoveFromClosedList() end
				if n:IsOpen() then n:UpdateOnOpenList() else n:AddToOpenList() end
				came[n:GetID()] = cur
			end
		end
	end
end

function EvilHeadcrab.Path(from, to)
	if not navmesh.IsLoaded() then return { to } end
	local start, goal = navmesh.GetNearestNavArea(from), navmesh.GetNearestNavArea(to)
	if not start or not goal then return { to } end
	if start == goal then return { to } end
	local areas = Search(start, goal)
	if not areas then return end
	local points = {}
	for i = 2, #areas - 1 do points[#points + 1] = areas[i]:GetCenter() end
	points[#points + 1] = to
	return points
end

function EvilHeadcrab.Kill(ent, attacker)
	local dmg = DamageInfo()
	dmg:SetDamage(ent:Health() + 100)
	dmg:SetDamageType(DMG_GENERIC)
	dmg:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
	dmg:SetInflictor(game.GetWorld())
	ent:TakeDamageInfo(dmg)
end

local function Unpin(body)
	body.EvilBond = nil
	for i = 0, body:GetPhysicsObjectCount() - 1 do
		local phys = body:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			phys:EnableMotion(true)
			phys:Wake()
		end
	end
end

local function Eat(pull, barnacle)
	pull.bitten = true
	barnacle:EmitSound("NPC_Barnacle.FinalBite")
	if IsValid(pull.crab) then
		pull.crab:EmitSound("NPC_HeadCrab.Die")
		pull.crab:Remove()
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
		Eat(pull, barnacle)
		pull.low = math.min(barnacle:WorldToLocal(pos).z, SOCKET)
	end
	local target = barnacle:LocalToWorld(Vector(0, 0, math.Clamp(Strike(cycle), pull.low, SOCKET)))
	local gap = target - pos
	local step = YANK * dt
	local dist = gap:Length()
	phys:SetPos(dist > step and pos + gap * (step / dist) or target)
	return cycle >= 1 and dist <= step
end

hook.Add("Think", "EvilHeadcrabPull", function()
	local dt = FrameTime()
	for barnacle, pull in pairs(pulls) do
		if not IsValid(barnacle) or barnacle.EvilBond ~= pull.body or Pull(barnacle, pull, dt) then
			pulls[barnacle] = nil
		end
	end
end)

function EvilHeadcrab.Bond(barnacle, body, head, health, crab)
	barnacle.EvilThrall = nil
	barnacle.EvilBond, body.EvilBond = body, barnacle
	body.EvilHealth = health
	local floor = EvilHeadcrab.Below(barnacle)
	if floor then barnacle:SetKeyValue("RestDist", tostring(barnacle:GetPos().z - floor.z)) end
	local phys = body:GetPhysicsObjectNum(head)
	if IsValid(phys) then phys:EnableMotion(false) end
	local eat = barnacle:LookupSequence("eat_humanoid")
	local rate = barnacle:GetPlaybackRate()
	if rate <= 0 then rate = 1 end
	local start = CurTime()
	if barnacle:GetSequence() == eat then start = start - barnacle:GetCycle() * EAT_LENGTH / rate end
	pulls[barnacle] = { body = body, phys = phys, crab = crab, start = start, rate = rate }
end

function EvilHeadcrab.Unbond(barnacle, attacker)
	local body, pull = barnacle.EvilBond, pulls[barnacle]
	barnacle.EvilBond = nil
	pulls[barnacle] = nil
	if pull and not pull.bitten then Eat(pull, barnacle) end
	if IsValid(body) then Unpin(body) end
	if barnacle:Health() > 0 then EvilHeadcrab.Kill(barnacle, attacker) end
end

hook.Add("EntityTakeDamage", "EvilHeadcrabBond", function(ent, dmg)
	local other = ent.EvilBond
	if not IsValid(other) then return end
	if ent:IsNPC() then return true end
	ent.EvilHealth = ent.EvilHealth - dmg:GetDamage()
	if ent.EvilHealth <= 0 then EvilHeadcrab.Unbond(other, dmg:GetAttacker()) end
end)

hook.Add("EntityRemoved", "EvilHeadcrabBond", function(ent)
	local other = ent.EvilBond
	if not IsValid(other) then return end
	if ent:IsNPC() then
		Unpin(other)
	else
		EvilHeadcrab.Unbond(other)
	end
end)
