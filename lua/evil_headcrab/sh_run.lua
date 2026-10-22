hook.Add("UpdateAnimation", "EvilHeadcrabRun", function(ply)
	if ply:GetNW2Float("EvilCrabbed", 0) == 0 or not Evil.Posed(ply) then return end
	ply:SetPlaybackRate(ply:GetNW2Float("EvilCrabRate", 1))
	return true
end)
