local PEAK = 0.5
local START = 0.4

function EvilHeadcrab.Intensity(p)
	if p >= PEAK then return 1 end
	return Lerp(math.ease.InOutSine(math.max(p, 0) / PEAK), START, 1)
end
