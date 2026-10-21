local PEAK = 0.5
local START = 0.4

function EvilHeadcrab.Intensity(p)
	if p < PEAK then return Lerp(math.ease.InOutSine(p / PEAK), START, 1) end
	return 1 - math.ease.InOutSine(math.min((p - PEAK) / (1 - PEAK), 1))
end
