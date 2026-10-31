-- Frame pacing, to keep the handheld cool: the screen is redrawn at FPS only
-- while something moves, once after any change, and not at all otherwise.
-- After POCKET_AFTER seconds without a button press the screen goes dark
-- ("pocket mode") until the next press.
local Frame = {
	FPS = 30,
	DARK_FPS = 10,
	POCKET_AFTER = 30,
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

function Frame.shouldDraw()
	local draw = Frame.dirty or (Frame.animating and not Frame.dark)
	Frame.dirty = false
	return draw
end

-- Seconds per loop iteration.
function Frame.period()
	return 1 / (Frame.dark and Frame.DARK_FPS or Frame.FPS)
end

return Frame
