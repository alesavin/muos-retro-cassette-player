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
local BADGE = 11 -- radius of a twin button badge

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

-- A round badge with a button's name, like the printing on a real key.
local function badge(label, cx, cy)
	lg.setColor(0.35, 0.36, 0.38)
	lg.circle("fill", cx, cy, BADGE)
	lg.setColor(0.86, 0.87, 0.89)
	local f = Fonts.get("print", 17)
	lg.setFont(f)
	lg.printf(label, cx - BADGE, cy - f:getHeight() / 2 - 1, BADGE * 2, "center")
end

-- depth[name]: 0 up .. 1 fully down. twins[name]: a list of other buttons that
-- do the same thing, each drawn as a badge beside the symbol (optional).
function Keys.draw(depth, twins)
	for _, k in ipairs(Keys.LAYOUT) do
		local top = TOP + (depth[k.name] or 0) * TRAVEL
		lg.setColor(0.55, 0.56, 0.58)
		lg.rectangle("fill", k.x, top, W, 60, 6, 6)
		lg.setColor(0.80, 0.81, 0.83)
		lg.rectangle("fill", k.x + 2, top, W - 4, 54, 6, 6)
		local list = twins and twins[k.name] or {}
		local width = symbolWidth(k.name) + #list * (BADGE * 2 + 5)
		local x = k.x + (W - width) / 2
		local cy = top + 18
		lg.setColor(0.30, 0.31, 0.33)
		symbol(k.name, x, cy - ICON / 2)
		x = x + symbolWidth(k.name) + 6
		for _, label in ipairs(list) do
			badge(label, x + BADGE, cy)
			x = x + BADGE * 2 + 5
		end
	end
end

return Keys
