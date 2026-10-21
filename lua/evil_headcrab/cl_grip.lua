local FADE = 0.8
local BLEND = 3
local GRIP_UP, GRIP_OUT, GRIP_FWD = 5, 9, 1
local TUG_UP, TUG_OUT = 2, 3
local TUG_FAST, TUG_SLOW = 4, 1.2
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
		local pry = ent:LookupSequence("headcrabbed")
		rig = { head = head, pry = pry > 0 and pry or nil, arms = {} }
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
	local function Rotate(v)
		return v * c + axis:Cross(v) * s + axis * (axis:Dot(v) * (1 - c))
	end
	for _, b in ipairs(bones) do
		local m = ent:GetBoneMatrix(b)
		if m then
			m:SetTranslation(pivot + Rotate(m:GetTranslation() - pivot))
			m:SetForward(Rotate(m:GetForward()))
			m:SetRight(Rotate(m:GetRight()))
			m:SetUp(Rotate(m:GetUp()))
			ent:SetBoneMatrix(b, m)
		end
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
	local want = (rig.pry and ent:GetSequence() == rig.pry) and 0 or 1
	want = want * math.Clamp((1 - p) / (1 - FADE), 0, 1)
	local t = RealTime()
	ent.EvilCrabGrip = math.Approach(ent.EvilCrabGrip or 0, want, (t - (ent.EvilCrabGripAt or t)) * BLEND)
	ent.EvilCrabGripAt = t
	local k = ent.EvilCrabGrip
	if k <= 0.01 then return end
	local hm = ent:GetBoneMatrix(rig.head)
	if not hm then return end
	local hp, up, face, right = hm:GetTranslation(), hm:GetForward(), hm:GetRight(), hm:GetUp()
	local vigor = 1 - p
	local freq = Lerp(p, TUG_FAST, TUG_SLOW) * math.pi * 2
	for _, arm in ipairs(rig.arms) do
		local mh = ent:GetBoneMatrix(arm.hand)
		if mh then
			local wave = now * freq + arm.phase
			local grip = hp + up * (GRIP_UP + math.sin(wave) * TUG_UP * vigor)
				+ right * (arm.side * (GRIP_OUT + math.cos(wave * 0.7) * TUG_OUT * vigor))
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
