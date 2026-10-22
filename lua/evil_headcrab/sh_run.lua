local STILL = { "aim_yaw", "aim_pitch", "head_yaw", "head_pitch", "move_y" }

hook.Add("UpdateAnimation", "EvilHeadcrabRun", function(ply)
	if ply:GetNW2Float("EvilCrabbed", 0) == 0 or not Evil.Posed(ply) then return end
	local running = ply:GetNW2Bool("EvilCrabRunning")
	ply:SetPoseParameter("move_x", running and 1 or 0)
	for _, name in ipairs(STILL) do ply:SetPoseParameter(name, 0) end
	ply:SetPlaybackRate(ply:GetNW2Float("EvilCrabRate", 1))
	return true
end)
