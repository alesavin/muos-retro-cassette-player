-- Frame pacing, to keep the handheld cool: the scene is redrawn at FPS only
-- while something moves and once after any change. Otherwise the last finished
-- frame is shown again KEEPALIVE_FPS times a second: muOS draws its overlays
-- (the volume bar) when an app presents a frame, and some displays need
-- frames coming to show anything at all. The first WARMUP seconds are drawn
-- in full. The screen never goes dark on its own.
local Frame = {
	FPS = 30,
	KEEPALIVE_FPS = 10,
	WARMUP = 1,
	started = nil,
	lastPresent = 0,
	dirty = true,
	animating = false,
}

-- Something changed: draw the next frame.
function Frame.invalidate()
	Frame.dirty = true
end

function Frame.update(animating)
	Frame.animating = animating
end

-- What to put on screen this loop: "draw" the scene, "show" the last drawn
-- frame again, or nil for nothing.
function Frame.next(now)
	Frame.started = Frame.started or now
	local warm = now - Frame.started < Frame.WARMUP
	local draw = Frame.dirty or warm or Frame.animating
	Frame.dirty = false
	if draw then
		Frame.lastPresent = now
		return "draw"
	end
	if now - Frame.lastPresent >= 1 / Frame.KEEPALIVE_FPS - 0.005 then
		Frame.lastPresent = now
		return "show"
	end
	return nil
end

-- Seconds per loop iteration.
function Frame.period()
	return 1 / Frame.FPS
end

return Frame
