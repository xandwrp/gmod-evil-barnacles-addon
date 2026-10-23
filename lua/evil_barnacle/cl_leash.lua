local MAT = CreateMaterial("evil_barnacle_leash", "UnlitGeneric", { ["$basetexture"] = "color/white", ["$vertexcolor"] = 1, ["$nocull"] = 1 })
local MOUTH = Vector(0, 0, -26)
local POINTS = 16
local SIDES = 6
local THICK, THIN = 1.9, 1.1
local SAG = 0.1
local SWAY, SWAY_HZ = 3, 0.9
local SNAP = 0.25
local COLOR = Vector(160, 60, 70)
local ROOT_COLOR = Vector(90, 30, 40)
local SIDE = Vector(1, 0, 0)

local tongues = {}
local pts, rings = {}, {}

local function Tip(ent, name)
	local bone = name ~= "" and ent:LookupBone(name)
	local pos = bone and ent:GetBonePosition(bone)
	return pos or ent:WorldSpaceCenter()
end

local function Curve(root, tip, now, seed)
	local mid = (root + tip) * 0.5 - vector_up * (root:Distance(tip) * SAG)
	local side = (tip - root):Cross(vector_up)
	if side:LengthSqr() < 1e-4 then side = Vector(SIDE) end
	side:Normalize()
	for i = 0, POINTS do
		local u = i / POINTS
		local p = LerpVector(u, LerpVector(u, root, mid), LerpVector(u, mid, tip))
		pts[i + 1] = p + side * (math.sin(u * math.pi) * math.sin(now * SWAY_HZ * math.pi * 2 + u * 4 + seed) * SWAY)
	end
	return mid
end

local function Vert(v)
	local c = v[2]
	mesh.Position(v[1])
	mesh.Color(math.min(c.x, 255), math.min(c.y, 255), math.min(c.z, 255), 255)
	mesh.AdvanceVertex()
end

local function Tube(light)
	local n = POINTS + 1
	for j = 1, n do
		local t = pts[math.min(j + 1, n)] - pts[math.max(j - 1, 1)]
		t:Normalize()
		local s = t:Cross(vector_up)
		if s:LengthSqr() < 1e-4 then s = t:Cross(SIDE) end
		s:Normalize()
		local up = s:Cross(t)
		local f = (j - 1) / (n - 1)
		local r = Lerp(f, THICK, THIN)
		local col = LerpVector(math.min(f * 4, 1), ROOT_COLOR, COLOR) * light
		local ring = rings[j] or {}
		rings[j] = ring
		for q = 1, SIDES do
			local a = q / SIDES * math.pi * 2
			local d = s * math.cos(a) + up * math.sin(a)
			ring[q] = { pts[j] + d * r, col * (0.6 + 0.4 * math.max(d.z, 0)) }
		end
	end
	mesh.Begin(MATERIAL_QUADS, (n - 1) * SIDES)
	for j = 1, n - 1 do
		local r0, r1 = rings[j], rings[j + 1]
		for q = 1, SIDES do
			local q2 = q % SIDES + 1
			Vert(r0[q])
			Vert(r0[q2])
			Vert(r1[q2])
			Vert(r1[q])
		end
	end
	mesh.End()
end

local function Draw(b, now)
	local target = b:GetNW2Entity(EvilBarnacle.LEASH_VAR)
	if not IsValid(target) then
		tongues[b] = nil
		return
	end
	local root = b:LocalToWorld(MOUTH)
	local tip = Tip(target, b:GetNW2String(EvilBarnacle.LEASH_BONE_VAR))
	local t = tongues[b]
	if not t or t.target ~= target then
		t = { target = target, from = t and t.last or root, at = now, seed = math.Rand(0, 10) }
		tongues[b] = t
	end
	local k = math.min((now - t.at) / SNAP, 1)
	tip = LerpVector(k * k * (3 - 2 * k), t.from, tip)
	t.last = tip
	local lc = render.GetLightColor(Curve(root, tip, now, t.seed))
	Tube(math.Clamp((lc.x + lc.y + lc.z) * 0.8 + 0.15, 0.15, 1.2))
end

hook.Add("PostDrawOpaqueRenderables", "EvilBarnacleLeash", function(_, sky, sky3d)
	if sky or sky3d then return end
	local now = CurTime()
	render.SetMaterial(MAT)
	for _, b in ipairs(ents.FindByClass("npc_barnacle")) do Draw(b, now) end
	for b in pairs(tongues) do
		if not IsValid(b) then tongues[b] = nil end
	end
end)
