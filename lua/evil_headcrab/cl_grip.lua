local BLEND = 2
local GRIP_UP, GRIP_OUT, GRIP_FWD = 5, 9, 1
local TUG_UP, TUG_OUT = 2.5, 3.5
local TUG_SLOW, TUG_FAST = 0.7, 2.2
local ELBOW_FWD = 0.3
local ARMS = {
	{ "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand", 1, 0 },
	{ "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand", -1, 2.3 },
}

local rigs = {}

local function Subtree(ent, bone, out)
	out[#out + 1] = bone
	for _, child in ipairs(ent:GetChildBones(bone)) do Subtree(ent, child, out) end
	return out
end

local function Rig(ent)
	local model = ent:GetModel()
	local rig = rigs[model]
	if rig ~= nil then return rig end
	rig = false
	local head = ent:LookupBone(EvilHeadcrab.HEAD)
	if head then
		rig = { head = head, arms = {} }
		for _, a in ipairs(ARMS) do
			local upper, fore, hand = ent:LookupBone(a[1]), ent:LookupBone(a[2]), ent:LookupBone(a[3])
			if upper and fore and hand then
				rig.arms[#rig.arms + 1] = {
					upper = upper, fore = fore, hand = hand, side = a[4], phase = a[5],
					upperTree = Subtree(ent, upper, {}), foreTree = Subtree(ent, fore, {}),
				}
			end
		end
	end
	rigs[model] = rig
	return rig
end

local function Turn(ent, bones, pivot, from, to)
	local axis = from:Cross(to)
	local s = axis:Length()
	if s < 1e-4 then return end
	axis:Div(s)
	local c = from:Dot(to)
	local t = 1 - c
	local x, y, z = axis.x, axis.y, axis.z
	local r11, r12, r13 = c + x * x * t, x * y * t - z * s, x * z * t + y * s
	local r21, r22, r23 = y * x * t + z * s, c + y * y * t, y * z * t - x * s
	local r31, r32, r33 = z * x * t - y * s, z * y * t + x * s, c + z * z * t
	local px, py, pz = pivot.x, pivot.y, pivot.z
	local move = Matrix({
		{ r11, r12, r13, px - (r11 * px + r12 * py + r13 * pz) },
		{ r21, r22, r23, py - (r21 * px + r22 * py + r23 * pz) },
		{ r31, r32, r33, pz - (r31 * px + r32 * py + r33 * pz) },
		{ 0, 0, 0, 1 },
	})
	for _, b in ipairs(bones) do
		local m = ent:GetBoneMatrix(b)
		if m then ent:SetBoneMatrix(b, move * m) end
	end
end

local function Reach(ent, arm, target, pole)
	local mu, mf, mh = ent:GetBoneMatrix(arm.upper), ent:GetBoneMatrix(arm.fore), ent:GetBoneMatrix(arm.hand)
	if not (mu and mf and mh) then return end
	local s, e, w = mu:GetTranslation(), mf:GetTranslation(), mh:GetTranslation()
	local a, b = s:Distance(e), e:Distance(w)
	if a < 1 or b < 1 then return end
	local d = target - s
	local dist = math.Clamp(d:Length(), math.abs(a - b) + 0.1, a + b - 0.1)
	d:Normalize()
	local cos = math.Clamp((a * a + dist * dist - b * b) / (2 * a * dist), -1, 1)
	local bend = pole - d * pole:Dot(d)
	if bend:LengthSqr() < 1e-4 then return end
	bend:Normalize()
	local elbow = s + d * (cos * a) + bend * (math.sqrt(1 - cos * cos) * a)
	Turn(ent, arm.upperTree, s, (e - s):GetNormalized(), (elbow - s):GetNormalized())
	w = ent:GetBoneMatrix(arm.hand):GetTranslation()
	Turn(ent, arm.foreTree, elbow, (w - elbow):GetNormalized(), (s + d * dist - elbow):GetNormalized())
end

local function Build(ent)
	local start = ent:GetNW2Float("EvilCrabbed", 0)
	if start == 0 then
		ent.EvilCrabGrip = nil
		return
	end
	local rig = Rig(ent)
	if not rig then return end
	local done = ent:GetNW2Float("EvilCrabDone", start + 1)
	local now = CurTime()
	local p = math.Clamp((now - start) / math.max(done - start, 0.1), 0, 1)
	local i = EvilHeadcrab.Intensity(p)
	local t = RealTime()
	local dt = math.min(t - (ent.EvilCrabGripAt or t), 0.1)
	ent.EvilCrabGripAt = t
	ent.EvilCrabGrip = math.Approach(ent.EvilCrabGrip or 0, 1, dt * BLEND)
	ent.EvilCrabTug = (ent.EvilCrabTug or 0) + dt * Lerp(i, TUG_SLOW, TUG_FAST) * math.pi * 2
	local k = ent.EvilCrabGrip
	if k <= 0.01 then return end
	local hm = ent:GetBoneMatrix(rig.head)
	if not hm then return end
	local hp, up, face, right = hm:GetTranslation(), hm:GetForward(), hm:GetRight(), hm:GetUp()
	for _, arm in ipairs(rig.arms) do
		local mh = ent:GetBoneMatrix(arm.hand)
		if mh then
			local wave = ent.EvilCrabTug + arm.phase
			local pull = (math.sin(wave) + 0.5 * math.sin(wave * 1.7 + 1.3)) / 1.5
			local twist = (math.cos(wave * 0.8) + 0.5 * math.sin(wave * 1.3 + 0.4)) / 1.5
			local grip = hp + up * (GRIP_UP + twist * TUG_UP * i)
				+ right * (arm.side * (GRIP_OUT + pull * TUG_OUT * i))
				+ face * GRIP_FWD
			Reach(ent, arm, LerpVector(k, mh:GetTranslation(), grip), right * arm.side + face * ELBOW_FWD)
		end
	end
end

local function Hook(ent)
	if ent.EvilCrabHooked then return end
	ent.EvilCrabHooked = true
	ent:AddCallback("BuildBonePositions", Build)
end

hook.Add("EntityNetworkedVarChanged", "EvilHeadcrabGrip", function(ent, name, _, new)
	if name == "EvilCrabbed" and IsValid(ent) and new and new ~= 0 then Hook(ent) end
end)

hook.Add("NetworkEntityCreated", "EvilHeadcrabGrip", function(ent)
	if ent:GetNW2Float("EvilCrabbed", 0) ~= 0 then Hook(ent) end
end)
