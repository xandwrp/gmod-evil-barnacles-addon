local LOCKED = bit.bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD, IN_USE)
local BACK = 110
local HULL = Vector(4, 4, 4)

hook.Add("UpdateAnimation", "EvilHeadcrabRun", function(ply)
	if ply:GetNW2Float("EvilCrabbed", 0) == 0 or not Evil.Posed(ply) then return end
	ply:SetPlaybackRate(ply:GetNW2Float("EvilCrabRate", 1))
	return true
end)

hook.Add("StartCommand", "EvilHeadcrabRoped", function(ply, cmd)
	if ply:GetNW2Bool("EvilCrabRoped") then cmd:RemoveKey(LOCKED) end
end)

hook.Add("PlayerSwitchWeapon", "EvilHeadcrabRoped", function(ply)
	if ply:GetNW2Bool("EvilCrabRoped") then return true end
end)

if SERVER then return end

hook.Add("CalcView", "EvilHeadcrabRoped", function(ply, _, angles, fov)
	if not ply:Alive() or not ply:GetNW2Bool("EvilCrabRoped") then return end
	local center = ply:GetPos() + ply:OBBCenter()
	local tr = util.TraceHull({
		start = center, endpos = center - angles:Forward() * BACK,
		mins = -HULL, maxs = HULL, mask = MASK_SOLID_BRUSHONLY,
	})
	return { origin = tr.HitPos, angles = angles, fov = fov, drawviewer = true }
end)
