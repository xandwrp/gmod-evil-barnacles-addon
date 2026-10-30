local SCAN = 2
local FRESH = SCAN * 3
local CHANCE = 0.01
local CEILING = -0.7
local SPACING = 256
local DROP = 96
local COOLDOWN = 8
local PROBE = 8

local cursors = setmetatable({}, { __mode = "k" })
local grown = {}
local nextAt = 0

local function Grown()
	local n = 0
	for b in pairs(grown) do
		if IsValid(b) then n = n + 1 else grown[b] = nil end
	end
	return n
end

local function Crowded(pos)
	for _, ent in ipairs(ents.FindInSphere(pos, SPACING)) do
		if ent:GetClass() == "npc_barnacle" then return true end
	end
	return false
end

local function Ceiling(node)
	local start = node.pos - Vector(0, 0, PROBE)
	local up = util.TraceLine({ start = start, endpos = node.pos + Vector(0, 0, PROBE), mask = MASK_SOLID_BRUSHONLY })
	if not up.Hit or up.StartSolid or up.HitSky or up.HitNoDraw or up.HitNormal.z >= CEILING then return end
	local down = util.TraceLine({ start = start, endpos = start - Vector(0, 0, DROP), mask = MASK_SOLID })
	if down.Hit then return end
	return up.HitPos
end

local function Try(colony, node)
	if Crowded(node.pos) then return false end
	local pos = Ceiling(node)
	if not pos then return false end
	local barnacle = EvilBarnacle.Spawn(pos, math.Rand(0, 360))
	if not barnacle then return false end
	grown[barnacle] = true
	local owner = colony:GetCreator()
	if IsValid(owner) and owner:IsPlayer() and cleanup then cleanup.Add(owner, "sents", barnacle) end
	return true
end

local function Scan(colony, mat, fresh)
	local id = cursors[mat] or 1
	local last = mat.nextId - 1
	cursors[mat] = last + 1
	for i = id, last do
		local node = mat.nodes[i]
		if node and not node.air and node.up < CEILING and node.born >= fresh and math.random() < CHANCE
			and Try(colony, node) then
			return true
		end
	end
	return false
end

timer.Create("EvilBarnacleGrow", SCAN, 0, function()
	local max = EvilBarnacle.Settings:Get("grown")
	local colonies = EvilFungus and EvilFungus.Colonies
	if not colonies then return end
	local now = CurTime()
	local fresh = now - FRESH
	local open = max > 0 and now >= nextAt and Grown() < max
	for colony in pairs(colonies) do
		local mat = IsValid(colony) and colony.Mat
		if mat then
			if open then
				if Scan(colony, mat, fresh) then
					nextAt = now + COOLDOWN
					open = false
				end
			else
				cursors[mat] = mat.nextId
			end
		end
	end
end)

hook.Add("EvilFungusCleared", "EvilBarnacleGrow", function()
	for barnacle in pairs(grown) do
		if IsValid(barnacle) then barnacle:Remove() end
		grown[barnacle] = nil
	end
end)
