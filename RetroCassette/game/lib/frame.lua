-- Frame pacing, to keep the handheld cool: the scene is redrawn at FPS only
-- while something moves and once after any change. Otherwise the last finished
-- frame is shown again KEEPALIVE_FPS times a second: muOS draws its overlays
-- (the volume bar) when an app presents a frame, and some displays need
-- frames coming to show anything at all. The first WARMUP seconds are drawn
-- in full. After POCKET_AFTER seconds without a button press the screen goes
-- dark ("pocket mode") until the next press.
local Frame = {
	FPS = 30,
	DARK_FPS = 10,
	KEEPALIVE_FPS = 10,
	WARMUP = 1,
	POCKET_AFTER = 30,
	started = nil,
	lastPresent = 0,
	dirty = true,
	animating = false,
	dark = false,
	lastInput = 0,
}

-- Something changed: draw the next frame.
function Frame.invalidate()
	Frame.dirty = true
end

-- A button was pressed. Returns true when it only woke the screen.
function Frame.input(now)
	Frame.lastInput = now
	Frame.dirty = true
	if Frame.dark then
		Frame.dark = false
		return true
	end
	return false
end

function Frame.update(now, animating)
	Frame.animating = animating
	if not Frame.dark and now - Frame.lastInput >= Frame.POCKET_AFTER then
		Frame.dark = true
		Frame.dirty = true
	end
end

-- What to put on screen this loop: "draw" the scene, "show" the last drawn
-- frame again, or nil for nothing.
function Frame.next(now)
	Frame.started = Frame.started or now
	local warm = now - Frame.started < Frame.WARMUP
	local draw = Frame.dirty or warm or (Frame.animating and not Frame.dark)
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
	return 1 / (Frame.dark and Frame.DARK_FPS or Frame.FPS)
end

return Frame
