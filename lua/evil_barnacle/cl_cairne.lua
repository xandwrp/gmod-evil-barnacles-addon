local SCAN = 0.5
local RANGE = 3000
local LIGHT_EVERY = 0.5
local SIDES = 4
local MAX_QUADS = 9000
local BATCH = 2500

local ROPE_GROW = 0.6
local ROPE_SAMPLES = 10
local ROPE_R = { 1.8, 0.9 }
local ROPE_SAG = 0.12
local ROPE_SWAY = 3
local ROPE_TINT = 0.15
local COIL_TURNS, COIL_POINTS, COIL_R = 2, 10, 2.6
local CROTCH_R, CROTCH_POINTS = 5.5, 9
local HIPS_R, HIPS_TURNS, HIPS_POINTS, HIPS_DROP = 8, 1.2, 12, 3

local WRAP_PITCH, WRAP_STEPS = 4, 5
local WRAP_R = { 0.8, 0.5 }
local SKIN = 1.2
local STAPLE_SAMPLES = 8
local STAPLE_R = { 1.1, 0.7 }
local STAPLE_OUT = 5
local HEAD_LEN = 8
local PELVIS, SPINE, NECK = "ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Neck1"
local R_THIGH, L_THIGH = "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_L_Thigh"
local COILS = {
	{ "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Forearm", 0.35 },
	{ "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Forearm", 0.35 },
	{ "ValveBiped.Bip01_R_Foot", "ValveBiped.Bip01_R_Calf", 0.2 },
	{ "ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_L_Calf", 0.2 },
}
local SEGMENTS = {
	{ PELVIS, SPINE, 7, 2, 2 },
	{ SPINE, NECK, 6.5, 2, 2 },
	{ EvilBarnacle.HEAD, nil, 4.5, 1, 1 },
	{ "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", 2.6, 1, 1 },
	{ "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", 2.6, 1, 1 },
	{ "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand", 2.2, 1, 1 },
	{ "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand", 2.2, 1, 1 },
	{ R_THIGH, "ValveBiped.Bip01_R_Calf", 3.8, 1, 2 },
	{ L_THIGH, "ValveBiped.Bip01_L_Calf", 3.8, 1, 2 },
	{ "ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot", 2.8, 1, 1 },
	{ "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot", 2.8, 1, 1 },
}

local bodies, nextScan = {}, 0
local lights = {}

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

local function Axes(rag)
	local pelvis, spine = Bone(rag, PELVIS), Bone(rag, SPINE)
	local rt, lt = Bone(rag, R_THIGH), Bone(rag, L_THIGH)
	if not (pelvis and spine and rt and lt) then return end
	local up = (spine - pelvis):GetNormalized()
	local right = rt - lt
	right = (right - up * right:Dot(up)):GetNormalized()
	return pelvis, up, right, up:Cross(right)
end

local function Coil(a, b, along)
	local axis = b - a
	local u, v = Basis(axis:GetNormalized())
	local path = {}
	for j = 0, COIL_POINTS do
		local k = j / COIL_POINTS
		local ang = k * COIL_TURNS * math.pi * 2
		path[j + 1] = a + axis * (along * (1 - k)) + (u * math.cos(ang) + v * math.sin(ang)) * COIL_R
	end
	return path
end

local function Crotch(pelvis, up, front)
	local c = pelvis - up
	local path = {}
	for j = 0, CROTCH_POINTS do
		local a = math.pi + j / CROTCH_POINTS * math.pi * 1.1
		path[j + 1] = c + front * (math.cos(a) * CROTCH_R) + up * (math.sin(a) * CROTCH_R * 1.2)
	end
	return path
end

local function Hips(pelvis, up, right, front)
	local c = pelvis - up * HIPS_DROP
	local path = {}
	for j = 0, HIPS_POINTS do
		local k = j / HIPS_POINTS
		local a = k * HIPS_TURNS * math.pi * 2
		path[j + 1] = c - front * (math.cos(a) * HIPS_R) + right * (math.sin(a) * HIPS_R) - up * (k * 2)
	end
	return path
end

local function Rope(shapes, anchor, path, grow, i, n, now, color, light)
	local first = path[1]
	local sway = Vector(math.sin(now * 1.7 + i * 2.1), math.cos(now * 1.3 + i * 1.3), 0) * ROPE_SWAY
	local mid = (anchor + first) * 0.5 + n * (anchor:Distance(first) * ROPE_SAG) + sway
	local pts, radii = {}, {}
	for k = 0, ROPE_SAMPLES do pts[#pts + 1] = Bezier(anchor, mid, first, k / ROPE_SAMPLES) end
	for k = 2, #path do pts[#pts + 1] = path[k] end
	for k = 1, #pts do radii[k] = Lerp((k - 1) / (#pts - 1), ROPE_R[1], ROPE_R[2]) end
	Grown(pts, radii, grow)
	shapes[#shapes + 1] = { pts, radii, color[1], color[2], color[3], light }
end

local function Ropes(shapes, rag, t, n, now, light, S)
	local grow = math.Clamp(t / ROPE_GROW, 0, 1)
	local color = { Mix(S.BODY_THICK, S.ROOT, ROPE_TINT) }
	local pelvis, up, right, front = Axes(rag)
	for i = 1, #EvilBarnacle.CAIRNE_ROPES do
		local anchor = rag:GetNW2Vector(EvilBarnacle.CAIRNE_ROPE_VAR .. i)
		local path
		if COILS[i] then
			local a, b = Bone(rag, COILS[i][1]), Bone(rag, COILS[i][2])
			if a and b then path = Coil(a, b, COILS[i][3]) end
		elseif pelvis then
			path = i == 5 and Crotch(pelvis, up, front) or Hips(pelvis, up, right, front)
		end
		if path and not anchor:IsZero() then Rope(shapes, anchor, path, grow, i, n, now, color, light) end
	end
end

local function Spiral(shapes, a, b, r, grow, seed, flip, light, S)
	local axis = b - a
	local len = axis:Length()
	if len < 1 then return end
	local u, v = Basis(axis / len)
	local turns = math.max(1, len / WRAP_PITCH)
	local n = math.ceil(turns * WRAP_STEPS)
	local phase = Rand(seed, n, 1) * math.pi * 2
	local dir = flip and -1 or 1
	local pts, radii = {}, {}
	for j = 0, n do
		local k = j / n
		local ang = phase + dir * k * turns * math.pi * 2
		local rr = r + SKIN + (Rand(seed, j, 2) - 0.5) * 0.8
		pts[j + 1] = a + axis * k + (u * math.cos(ang) + v * math.sin(ang)) * rr
		radii[j + 1] = Lerp(k, WRAP_R[1], WRAP_R[2])
	end
	Grown(pts, radii, grow)
	local cr, cg, cb = Mix(S.ROOT, S.VEIN, Rand(seed, n, 3) * 0.6)
	shapes[#shapes + 1] = { pts, radii, cr, cg, cb, light }
end

local function Staple(shapes, p, along, r, grow, at, n, seed, light, S)
	local w = n:Cross(along)
	if w:LengthSqr() < 1e-4 then return end
	w:Normalize()
	local base = p - n * (p - at):Dot(n)
	local reach = r + STAPLE_OUT
	local e1, e2 = base + w * reach, base - w * reach
	local ctrl = (p + n * (r + 1)) * 2 - (e1 + e2) * 0.5
	local pts, radii = {}, {}
	for k = 0, STAPLE_SAMPLES do
		local t = k / STAPLE_SAMPLES
		pts[k + 1] = Bezier(e1, ctrl, e2, t)
		radii[k + 1] = Lerp(math.abs(t - 0.5) * 2, STAPLE_R[2], STAPLE_R[1])
	end
	Grown(pts, radii, grow)
	local cr, cg, cb = Mix(S.ROOT, S.BODY_THICK, 0.2 + Rand(seed, 1, 4) * 0.2)
	shapes[#shapes + 1] = { pts, radii, cr, cg, cb, light }
end

local function Cocoon(shapes, rag, t, at, n, light, S)
	local seed = rag:EntIndex()
	for i, seg in ipairs(SEGMENTS) do
		local grow = EvilBarnacle.Wrapped(t, seg[1])
		local a = grow > 0 and Bone(rag, seg[1])
		local b = a and seg[2] and Bone(rag, seg[2])
		if a and not seg[2] then
			local neck = Bone(rag, NECK)
			if neck then b = a + (a - neck):GetNormalized() * HEAD_LEN end
		end
		if b then
			for s = 1, seg[4] do Spiral(shapes, a, b, seg[3], grow, seed * 31 + i * 7 + s, s % 2 == 0, light, S) end
			local pin = math.Clamp(grow * 2 - 1, 0, 1)
			if pin > 0 then
				for s = 1, seg[5] do
					Staple(shapes, LerpVector((s - 0.5) / seg[5], a, b), b - a, seg[3], pin, at, n, seed * 17 + i * 5 + s, light, S)
				end
			end
		end
	end
end

local function Quads(shapes, first)
	local q = 0
	for k = first, #shapes do q = q + (#shapes[k][1] - 1) * SIDES end
	return q
end

local function Batch(shapes, first, last, S)
	for k = first, last do
		local sh = shapes[k]
		S.Polyline(sh[1], sh[2], vector_up, SIDES, sh[3], sh[4], sh[5], sh[6])
	end
end

local function Emit(mat, shapes, S)
	local i, n = 1, #shapes
	if n == 0 then return end
	render.SetMaterial(mat)
	while i <= n do
		local quads, last = 0, i
		while last <= n do
			local q = (#shapes[last][1] - 1) * SIDES
			if quads > 0 and quads + q > BATCH then break end
			quads = quads + q
			last = last + 1
		end
		if quads > 0 then
			mesh.Begin(MATERIAL_QUADS, quads)
			local ok, err = pcall(Batch, shapes, i, last - 1, S)
			mesh.End()
			if not ok then
				ErrorNoHalt("Evil barnacles couldn't draw a cocoon: ", err, "\n")
				return
			end
		end
		i = last
	end
end

local function Draw()
	local S = EvilFungus and EvilFungus.Strands
	if not S then return end
	local clock = CurTime()
	if clock >= nextScan then
		nextScan = clock + SCAN
		bodies = {}
		for _, rag in ipairs(ents.FindByClass("prop_ragdoll*")) do
			if rag:GetNW2Float(EvilBarnacle.CAIRNE_VAR, 0) > 0 then bodies[#bodies + 1] = rag end
		end
		for rag in pairs(lights) do
			if not IsValid(rag) or rag:GetNW2Float(EvilBarnacle.CAIRNE_VAR, 0) <= 0 then lights[rag] = nil end
		end
	end
	if #bodies == 0 then return end
	local eye = EyePos()
	local ropes, fibers, quads = {}, {}, 0
	for _, rag in ipairs(bodies) do
		local since = IsValid(rag) and rag:GetNW2Float(EvilBarnacle.CAIRNE_VAR, 0) or 0
		local n = since > 0 and rag:GetNW2Vector(EvilBarnacle.CAIRNE_UP_VAR)
		if quads < MAX_QUADS and n and not n:IsZero() and rag:GetPos():DistToSqr(eye) < RANGE * RANGE then
			rag:SetupBones()
			local t = clock - since
			local l = lights[rag]
			if not l or clock - l.at > LIGHT_EVERY then
				l = { at = clock, light = S.Light({ pos = rag:WorldSpaceCenter(), normal = n }) }
				lights[rag] = l
			end
			local r0, f0 = #ropes + 1, #fibers + 1
			Ropes(ropes, rag, t, n, clock, l.light, S)
			if t > EvilBarnacle.CAIRNE_HOIST then Cocoon(fibers, rag, t, rag:GetNW2Vector(EvilBarnacle.CAIRNE_AT_VAR), n, l.light, S) end
			quads = quads + Quads(ropes, r0) + Quads(fibers, f0)
		end
	end
	Emit(S.FLESH, ropes, S)
	Emit(S.MAT, fibers, S)
end

hook.Add("Initialize", "EvilBarnacleCairne", function()
	if EvilFungus and EvilFungus.DrawPass then EvilFungus.DrawPass("EvilBarnacleCairne", Draw) end
end)
