local FADE_IN = 3

hook.Add("HUDPaint", "EvilBarnacleHeld", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or ply:Alive() then return end
	local at = ply:GetNW2Float(EvilBarnacle.HELD_VAR, 0)
	if at <= 0 then return end
	local k = math.Clamp((CurTime() - at - EvilBarnacle.GIVE_UP) / FADE_IN, 0, 1)
	if k <= 0 then return end
	local key = string.upper(input.LookupBinding("+jump") or "space")
	draw.SimpleText("Press " .. key .. " to give up", "Trebuchet24", ScrW() / 2, ScrH() * 0.85, Color(255, 255, 255, 160 * k), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
