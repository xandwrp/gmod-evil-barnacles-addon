local FLOOR = 4096
local CLIMB = 18
local SEARCH_LIMIT = 4000

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

function EvilHeadcrab.Bond(barnacle, body, head, health)
	barnacle.EvilThrall = nil
	barnacle.EvilBond, body.EvilBond = body, barnacle
	body.EvilHealth = health
	local floor = EvilHeadcrab.Below(barnacle)
	if floor then barnacle:SetKeyValue("RestDist", tostring(barnacle:GetPos().z - floor.z)) end
	local phys = body:GetPhysicsObjectNum(head)
	if IsValid(phys) then phys:EnableMotion(false) end
	barnacle:EmitSound("NPC_Barnacle.FinalBite")
end

function EvilHeadcrab.Unbond(barnacle, attacker)
	local body = barnacle.EvilBond
	barnacle.EvilBond = nil
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
