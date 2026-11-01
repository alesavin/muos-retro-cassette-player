-- The four transport keys along the bottom edge, above the real shoulder
-- buttons (L1 L2 ... R2 R1 on the RG34XXSP hinge). Used by the player and the
-- library, so the same button always looks the same.
local Fonts = require("lib.fonts")
local ui = require("lib.ui")
local lg = love.graphics

local Keys = {}

-- Left to right, with the action each one maps to.
Keys.LAYOUT = {
	{ name = "rew", action = "l1", x = 8 },
	{ name = "stop", action = "l2", x = 124 },
	{ name = "play", action = "r2", x = 486 },
	{ name = "ff", action = "r1", x = 602 },
}

local W, TOP, TRAVEL = 110, 444, 16
local ICON = 18 -- symbol size
local TWIN_SIZE = 13 -- the optional twin buttons are printed small and grey

-- Width of a key's symbol(s).
local function symbolWidth(name)
	if name == "stop" or name == "play" then
		return 2 * ICON + 4
	end
	return ICON
end

local function symbol(name, x, y)
	if name == "stop" then
		-- STOP/EJECT
		ui.icon("stop", x, y, ICON)
		ui.icon("eject", x + ICON + 4, y, ICON)
	elseif name == "play" then
		-- PLAY/PAUSE
		ui.icon("play", x, y, ICON)
		ui.icon("pause", x + ICON + 6, y, ICON)
	else
		ui.icon(name, x, y, ICON)
	end
end

-- depth[name]: 0 up .. 1 fully down. twins[name]: a list of other buttons that
-- do the same thing, printed small and grey beside the symbol (optional).
function Keys.draw(depth, twins)
	for _, k in ipairs(Keys.LAYOUT) do
		local top = TOP + (depth[k.name] or 0) * TRAVEL
		lg.setColor(0.55, 0.56, 0.58)
		lg.rectangle("fill", k.x, top, W, 60, 6, 6)
		lg.setColor(0.80, 0.81, 0.83)
		lg.rectangle("fill", k.x + 2, top, W - 4, 54, 6, 6)
		local twin = twins and twins[k.name] and table.concat(twins[k.name], " ")
		local f = Fonts.get("print", TWIN_SIZE)
		local width = symbolWidth(k.name) + (twin and f:getWidth(twin) + 7 or 0)
		local x = k.x + (W - width) / 2
		local cy = top + 18
		lg.setColor(0.30, 0.31, 0.33)
		symbol(k.name, x, cy - ICON / 2)
		if twin then
			lg.setFont(f)
			lg.setColor(0.45, 0.46, 0.48)
			lg.print(twin, x + symbolWidth(k.name) + 7, cy - f:getHeight() / 2)
		end
	end
end

return Keys
