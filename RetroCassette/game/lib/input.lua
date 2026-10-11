-- Maps the handheld's gamepad and a desktop keyboard to the same actions,
-- with key repeat for the d-pad.
local Input = {}

local KEYMAP = {
	up = "up",
	down = "down",
	left = "left",
	right = "right",
	z = "a",
	["return"] = "a",
	x = "b",
	backspace = "b",
	a = "l1",
	s = "l2",
	d = "r2",
	f = "r1",
	tab = "select",
	space = "start",
	escape = "quit",
}

local PADMAP = {
	dpup = "up",
	dpdown = "down",
	dpleft = "left",
	dpright = "right",
	a = "a",
	b = "b",
	leftshoulder = "l1",
	rightshoulder = "r1",
	back = "select",
	start = "start",
	guide = "quit",
}

local REPEATABLE = { up = true, down = true, left = true, right = true }
local REPEAT_DELAY = 0.35
local REPEAT_RATE = 0.07

local held = {}
local timers = {}

-- Set by the app: onAction(action, isRepeat) and onRelease(action).
Input.onAction = function() end
Input.onRelease = function() end

local function press(action)
	if not action or held[action] then
		return
	end
	held[action] = true
	timers[action] = REPEAT_DELAY
	if (action == "start" and held.select) or (action == "select" and held.start) then
		action = "quit"
	end
	Input.onAction(action, false)
end

local function release(action)
	if not action or not held[action] then
		return
	end
	held[action] = nil
	timers[action] = nil
	Input.onRelease(action)
end

function Input.isDown(action)
	return held[action] == true
end

function Input.keypressed(key)
	press(KEYMAP[key])
end

function Input.keyreleased(key)
	release(KEYMAP[key])
end

function Input.gamepadpressed(button)
	press(PADMAP[button])
end

function Input.gamepadreleased(button)
	release(PADMAP[button])
end

-- L2/R2 are analog triggers on most controllers.
local TRIGGERS = { triggerleft = "l2", triggerright = "r2" }

function Input.gamepadaxis(axis, value)
	local action = TRIGGERS[axis]
	if not action then
		return
	end
	if value > 0.5 then
		press(action)
	elseif value < 0.3 then
		release(action)
	end
end

function Input.update(dt)
	for action in pairs(REPEATABLE) do
		if held[action] then
			timers[action] = timers[action] - dt
			if timers[action] <= 0 then
				timers[action] = REPEAT_RATE
				Input.onAction(action, true)
			end
		end
	end
end

return Input
