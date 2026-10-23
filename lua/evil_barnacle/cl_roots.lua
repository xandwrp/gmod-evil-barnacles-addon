local SCAN = 0.5
local RANGE = 3000
local LIGHT_EVERY = 0.5
local SIDES = 4
local MAX_QUADS = 7000

local HOLD_GROW = 2.5
local HOLD_SAMPLES = 8
local HOLD_R = { 1.4, 0.6 }
local HOLD_SAG = 0.08
local WRAP_TURNS, WRAP_POINTS, WRAP_R, WRAP_ALONG = 1.6, 8, 2, 0.4

local ESCALATE = 90
local CARESS_GROW = 4
local CARESS_SAMPLES = 8
local CARESS_R = { 0.8, 0.25 }
local CARESS_RING = { 8, 26 }
local STROKE = { 0.25, 1.6 }
local REACH = 0.45
local TRAIL, TRAIL_STEP = 4, 0.08
local SKIN = 1.2
local SWAY = 4
local LIMBS = {
	{ "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand", 2.2 },
	{ "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", 2.6 },
	{ "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Neck1", 3.5 },
	{ "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot", 2.8 },
	{ "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand", 2.2 },
	{ "ValveBiped.Bip01_Spine1", "ValveBiped.Bip01_Spine2", 7 },
	{ "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", 2.6 },
	{ "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", 3.6 },
	{ "ValveBiped.Bip01_L_Clavicle", "ValveBiped.Bip01_L_UpperArm", 3 },
	{ "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot", 2.8 },
}
local HANDS = {
	{ "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Forearm", EvilBarnacle.ROOT_R_VAR },
	{ "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Forearm", EvilBarnacle.ROOT_L_VAR },
}

local bodies, nextScan = {}, 0
local states = {}

local function Rand(seed, i, k)
	local x = math.sin(seed * 1.618 + i * 12.731 + k * 3.317) * 43758.5453
	return x - math.floor(x)
end

local function Bezier(a, b, c, t)
	local o = 1 - t
	return a * (o * o) + b * (2 * t * o) + c * (t * t)
end

local function Mix(a, b, k)
	return Lerp(k, a[1], b[1]), Lerp(k, a[2], b[2]), Lerp(k, a[3], b[3])
end

local function Bone(rag, name)
	local b = rag:LookupBone(name)
	return b and rag:GetBonePosition(b)
end

local function Basis(axis)
	local u = axis:Cross(vector_up)
	if u:LengthSqr() < 1e-4 then u = axis:Cross(Vector(1, 0, 0)) end
	u:Normalize()
	return u, axis:Cross(u)
end

local function Grown(pts, radii, g)
	local n = math.max(2, math.ceil(#pts * g))
	for i = #pts, n + 1, -1 do
		pts[i], radii[i] = nil, nil
	end
	return pts, radii
end

local function Hold(shapes, rag, hand, t, S)
	local anchor = rag:GetNW2Vector(hand[3])
	local h, f = Bone(rag, hand[1]), Bone(rag, hand[2])
	if anchor:IsZero() or not h or not f then return end
	local axis = f - h
	local u, v = Basis(axis:GetNormalized())
	local wrap = {}
	for j = 0, WRAP_POINTS do
		local k = j / WRAP_POINTS
		local a = k * WRAP_TURNS * math.pi * 2
		wrap[j + 1] = h + axis * (WRAP_ALONG * (1 - k)) + (u * math.cos(a) + v * math.sin(a)) * WRAP_R
	end
	local first = wrap[1]
	local mid = (anchor + first) * 0.5 - vector_up * (anchor:Distance(first) * HOLD_SAG)
	local pts, radii = {}, {}
	for i = 0, HOLD_SAMPLES do
		pts[#pts + 1] = Bezier(anchor, mid, first, i / HOLD_SAMPLES)
	end
	for j = 2, #wrap do pts[#pts + 1] = wrap[j] end
	for i = 1, #pts do radii[i] = Lerp((i - 1) / (#pts - 1), HOLD_R[1], HOLD_R[2]) end
	Grown(pts, radii, math.Clamp(t / HOLD_GROW, 0, 1))
	local r, g, b = Mix(S.ROOT, S.BODY_THICK, 0.35)
	shapes[#shapes + 1] = { pts, radii, r, g, b }
end

local function Caress(shapes, rag, st, center, i, t, dt, S)
	local start = ESCALATE * math.sqrt((i - 1) / (#LIMBS - 1))
	if t < start then return end
	local limb = LIMBS[i]
	local a, b = Bone(rag, limb[1]), Bone(rag, limb[2])
	if not a or not b then return end
	local seed = rag:EntIndex()
	local esc = math.Clamp(t / ESCALATE, 0, 1)
	st.phase[i] = (st.phase[i] or Rand(seed, i, 1) * math.pi * 2) + dt * Lerp(esc * esc, STROKE[1], STROKE[2])
	local p = st.phase[i]
	local axis = b - a
	local u, v = Basis(axis:GetNormalized())
	local r = limb[3] + SKIN
	local dir = math.cos(p) >= 0 and 1 or -1
	local s = 0.5 + REACH * math.sin(p)
	local turn = p * 0.4 + Rand(seed, i, 2) * math.pi * 2
	local trail = {}
	for k = TRAIL, 0, -1 do
		local along = math.Clamp(s - dir * TRAIL_STEP * k, 0, 1)
		local ang = turn - dir * k * 0.25
		trail[#trail + 1] = a + axis * along + (u * math.cos(ang) + v * math.sin(ang)) * r
	end
	local ring = Rand(seed, i, 3) * math.pi * 2
	local root = center + Vector(math.cos(ring), math.sin(ring), 0) * Lerp(Rand(seed, i, 4), CARESS_RING[1], CARESS_RING[2])
	local touch = trail[1]
	local now = CurTime()
	local bend = (root + touch) * 0.5 + Vector(math.sin(now * 0.7 + i), math.cos(now * 0.6 + i * 2), 0) * SWAY
	local pts, radii = {}, {}
	for k = 0, CARESS_SAMPLES do
		pts[#pts + 1] = Bezier(root, bend, touch, k / CARESS_SAMPLES)
	end
	for k = 2, #trail do pts[#pts + 1] = trail[k] end
	for k = 1, #pts do radii[k] = Lerp((k - 1) / (#pts - 1), CARESS_R[1], CARESS_R[2]) end
	Grown(pts, radii, math.Clamp((t - start) / CARESS_GROW, 0, 1))
	local cr, cg, cb = Mix(S.ROOT, S.VEIN, Rand(seed, i, 5) * 0.6)
	shapes[#shapes + 1] = { pts, radii, cr, cg, cb }
end

local function Draw()
	local S = EvilFungus and EvilFungus.Strands
	if not S then return end
	local clock = CurTime()
	if clock >= nextScan then
		nextScan = clock + SCAN
		bodies = {}
		for _, rag in ipairs(ents.FindByClass("prop_ragdoll*")) do
			if rag:GetNW2Float(EvilBarnacle.ROOTED_VAR, 0) > 0 then bodies[#bodies + 1] = rag end
		end
		for rag in pairs(states) do
			if not IsValid(rag) or rag:GetNW2Float(EvilBarnacle.ROOTED_VAR, 0) <= 0 then states[rag] = nil end
		end
	end
	if #bodies == 0 then return end
	local eye, dt = EyePos(), FrameTime()
	local shapes, quads = {}, 0
	for _, rag in ipairs(bodies) do
		local since = IsValid(rag) and rag:GetNW2Float(EvilBarnacle.ROOTED_VAR, 0) or 0
		local ra = since > 0 and rag:GetNW2Vector(HANDS[1][3])
		local rb = since > 0 and rag:GetNW2Vector(HANDS[2][3])
		if quads < MAX_QUADS and ra and not ra:IsZero() and not rb:IsZero() and rag:GetPos():DistToSqr(eye) < RANGE * RANGE then
			rag:SetupBones()
			local t = clock - since
			local st = states[rag]
			if not st then
				st = { phase = {}, at = -1 }
				states[rag] = st
			end
			local center = (ra + rb) * 0.5
			if clock - st.at > LIGHT_EVERY then
				st.at, st.light = clock, S.Light({ pos = rag:WorldSpaceCenter(), normal = vector_up })
			end
			local first = #shapes + 1
			for _, hand in ipairs(HANDS) do Hold(shapes, rag, hand, t, S) end
			for i = 1, #LIMBS do Caress(shapes, rag, st, center, i, t, dt, S) end
			for k = first, #shapes do
				shapes[k][6] = st.light
				quads = quads + (#shapes[k][1] - 1) * SIDES
			end
		end
	end
	if quads == 0 then return end
	render.SetMaterial(S.MAT)
	mesh.Begin(MATERIAL_QUADS, quads)
	for _, sh in ipairs(shapes) do S.Polyline(sh[1], sh[2], vector_up, SIDES, sh[3], sh[4], sh[5], sh[6]) end
	mesh.End()
end

hook.Add("Initialize", "EvilBarnacleRoots", function()
	if EvilFungus and EvilFungus.DrawPass then EvilFungus.DrawPass("EvilBarnacleRoots", Draw) end
end)
