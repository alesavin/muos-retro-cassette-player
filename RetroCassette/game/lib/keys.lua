-- The four transport keys along the bottom edge, above the real shoulder
-- buttons (L1 L2 ... R2 R1 on the RG34XXSP hinge). Used by the player and the
-- library, so the same button always looks the same.
local Fonts = require("lib.fonts")
local ui = require("lib.ui")
local lg = love.graphics

local Keys = {}

-- Left to right, with the action each one maps to.
Keys.LAYOUT = {
	{ name = "rew", action = "l1", x = 14 },
	{ name = "stop", action = "l2", x = 112 },
	{ name = "play", action = "r2", x = 518 },
	{ name = "ff", action = "r1", x = 616 },
}

local W, TOP, TRAVEL = 90, 444, 16

local function symbol(name, cx, y)
	if name == "stop" then
		-- STOP/EJECT
		ui.icon("stop", cx - 17, y, 12)
		ui.icon("eject", cx + 5, y, 12)
	elseif name == "play" then
		-- PLAY/PAUSE
		ui.icon("play", cx - 17, y, 12)
		ui.icon("pause", cx + 4, y, 12)
	else
		ui.icon(name, cx - 7, y, 13)
	end
end

-- depth[name]: 0 up .. 1 fully down. twins[name]: the other button that does
-- the same thing, printed under the symbol (optional).
function Keys.draw(depth, twins)
	for _, k in ipairs(Keys.LAYOUT) do
		local top = TOP + (depth[k.name] or 0) * TRAVEL
		lg.setColor(0.55, 0.56, 0.58)
		lg.rectangle("fill", k.x, top, W, 60, 6, 6)
		lg.setColor(0.80, 0.81, 0.83)
		lg.rectangle("fill", k.x + 2, top, W - 4, 54, 6, 6)
		lg.setColor(0.35, 0.36, 0.38)
		local cx = k.x + W / 2
		symbol(k.name, cx, top + 8)
		local twin = twins and twins[k.name]
		if twin then
			lg.setFont(Fonts.get("print", 12))
			lg.printf(twin, k.x, top + 21, W, "center")
		end
	end
end

return Keys
