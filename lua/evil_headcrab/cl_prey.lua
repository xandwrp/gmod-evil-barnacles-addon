local MOUTH = -25
local RIM, RIM_R = -27, 5
local SEGS = 16
local WIDE, THIN = 2.4, 0.9
local SAG = 0.3
local CREEP, CREEP_REACH = 0.7, 0.35
local WIGGLE, TAUT = 5, 0.6
local WIGGLE_HZ = 1.4
local COIL_SEGS, COIL_LEN, COIL_R, COIL_TURNS, COIL_IN = 14, 5, 1.8, 2.5, 0.35
local TEX_SPAN = 12
local TINT = Vector(1, 0.72, 0.72)
local GAIN = 1.5
local SIDES = {
	{ hand = "ValveBiped.Bip01_R_Hand", fore = "ValveBiped.Bip01_R_Forearm", net = "EvilLatchR", phase = 0, out = -1 },
	{ hand = "ValveBiped.Bip01_L_Hand", fore = "ValveBiped.Bip01_L_Forearm", net = "EvilLatchL", phase = 2.1, out = 1 },
}

local mat = CreateMaterial("evil_tendril", "UnlitGeneric", {
	["$basetexture"] = "models/flesh",
	["$vertexcolor"] = 1,
	["$nocull"] = 1,
})
local flesh = Material("models/flesh"):GetTexture("$basetexture")
if flesh then mat:SetTexture("$basetexture", flesh) end

local prey = {}

local function Plane(maw)
	local n = -maw:GetUp()
	return n, n:Dot(maw:LocalToWorld(Vector(0, 0, MOUTH)))
end

local function Clip(ent, flags)
	local maw = ent:GetNW2Entity("EvilMaw")
	if not IsValid(maw) then return ent:DrawModel(flags) end
	local old = render.EnableClipping(true)
	render.PushCustomClipPlane(Plane(maw))
	ent:DrawModel(flags)
	render.PopCustomClipPlane()
	render.EnableClipping(old)
end

local function Track(ent)
	prey[ent] = true
	ent.RenderOverride = Clip
end

local function Shade(pos)
	local l = render.GetLightColor(pos) * GAIN
	return Color(math.min(l.x * TINT.x, 1) * 255, math.min(l.y * TINT.y, 1) * 255, math.min(l.z * TINT.z, 1) * 255)
end

local function Bezier(a, b, c, s)
	local u = 1 - s
	return a * (u * u) + b * (2 * u * s) + c * (s * s)
end

local function Tendril(body, maw, side, now, hunt, latch)
	local bone = body:LookupBone(side.hand)
	local hand = bone and body:GetBonePosition(bone)
	if not hand then return end
	local up = maw:GetUp()
	local mouth = maw:LocalToWorld(Vector(0, 0, RIM))
	local out = hand - mouth
	out = out - up * out:Dot(up)
	if out:LengthSqr() < 0.01 then out = maw:GetRight() * side.out end
	out:Normalize()
	local base = mouth + out * RIM_R
	local latched = now >= latch
	local tip, amp = hand, TAUT
	if not latched then
		local p = math.Clamp((now - hunt) / math.max(latch - hunt, 0.1), 0, 1)
		local strike = p > CREEP and math.ease.InCubic((p - CREEP) / (1 - CREEP)) or 0
		local reach = p < CREEP and CREEP_REACH * math.ease.OutSine(p / CREEP) or Lerp(strike, CREEP_REACH, 1)
		tip = LerpVector(reach, base, hand)
		amp = WIGGLE * (1 - strike)
	end
	local dir = tip - base
	local len = dir:Length()
	if len < 0.5 then return end
	dir:Div(len)
	local a = dir:Cross(up)
	if a:LengthSqr() < 1e-3 then a = maw:GetRight() end
	a:Normalize()
	local b = a:Cross(dir)
	local ctrl = (base + tip) * 0.5 - up * (len * SAG)
	local w = now * WIGGLE_HZ * math.pi * 2 + side.phase
	local pts = {}
	for i = 0, SEGS do
		local s = i / SEGS
		local env = latched and amp * math.sin(math.pi * s) or amp * math.sin(math.pi * s * 0.5)
		local pos = Bezier(base, ctrl, tip, s) + a * (math.sin(s * 7 - w) * env) + b * (math.cos(s * 5 - w * 1.3) * env * 0.6)
		pts[#pts + 1] = { pos, Lerp(s, WIDE, THIN), s * len / TEX_SPAN }
	end
	if latched then
		local c = math.Clamp((now - latch) / COIL_IN, 0, 1)
		local fb = body:LookupBone(side.fore)
		local elbow = fb and body:GetBonePosition(fb)
		if elbow and c > 0 then
			local axis = elbow - hand
			axis:Normalize()
			local u = axis:Cross(up)
			if u:LengthSqr() < 1e-3 then u = axis:Cross(maw:GetRight()) end
			u:Normalize()
			local v = axis:Cross(u)
			for j = 1, COIL_SEGS do
				local s = j / COIL_SEGS * c
				local th = s * COIL_TURNS * math.pi * 2
				local pos = hand + axis * (s * COIL_LEN) + (u * math.cos(th) + v * math.sin(th)) * COIL_R
				pts[#pts + 1] = { pos, THIN * 1.2, (len + s * COIL_LEN * 3) / TEX_SPAN }
			end
		end
	end
	render.StartBeam(#pts)
	for _, p in ipairs(pts) do render.AddBeam(p[1], p[2], p[3], Shade(p[1])) end
	render.EndBeam()
end

hook.Add("PostDrawOpaqueRenderables", "EvilHeadcrabPrey", function(_, sky, sky3d)
	if sky or sky3d then return end
	local now = CurTime()
	for body in pairs(prey) do
		if not IsValid(body) then
			prey[body] = nil
		elseif not body:IsDormant() then
			local hunt = body:GetNW2Float("EvilHunt", 0)
			local maw = body:GetNW2Entity("EvilMaw")
			if hunt > 0 and IsValid(maw) then
				render.SetMaterial(mat)
				local old = render.EnableClipping(true)
				render.PushCustomClipPlane(Plane(maw))
				for _, side in ipairs(SIDES) do
					local latch = body:GetNW2Float(side.net, 0)
					if latch > 0 then Tendril(body, maw, side, now, hunt, latch) end
				end
				render.PopCustomClipPlane()
				render.EnableClipping(old)
			end
		end
	end
end)

hook.Add("EntityNetworkedVarChanged", "EvilHeadcrabPrey", function(ent, name)
	if name == "EvilMaw" and IsValid(ent) then Track(ent) end
end)

hook.Add("NetworkEntityCreated", "EvilHeadcrabPrey", function(ent)
	if IsValid(ent:GetNW2Entity("EvilMaw")) then Track(ent) end
end)
