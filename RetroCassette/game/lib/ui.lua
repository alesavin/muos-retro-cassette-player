-- Drawing and text helpers shared by the screens.
local utf8 = require("utf8")
local lg = love.graphics

local ui = {}

function ui.fmtTime(s)
	s = math.max(0, math.floor(s or 0))
	return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

-- File names aren't guaranteed to be UTF-8, and LÖVE errors when printing invalid text.
function ui.safe(s)
	if utf8.len(s) then
		return s
	end
	return (s:gsub("[\128-\255]", "?"))
end

function ui.ellipsize(font, text, maxw)
	if font:getWidth(text) <= maxw then
		return text
	end
	while #text > 0 and font:getWidth(text .. "...") > maxw do
		local off = utf8.offset(text, -1)
		text = off and text:sub(1, off - 1) or ""
	end
	return text .. "..."
end

function ui.setScissor(x, y, w, h)
	if x then
		lg.setScissor(x, y, w, h)
	else
		lg.setScissor()
	end
end

-- Clips to a rectangle given in the current transform's coordinates
-- (love.graphics.setScissor ignores transforms).
local function transformedRect(x, y, w, h)
	local x1, y1 = lg.transformPoint(x, y)
	local x2, y2 = lg.transformPoint(x + w, y + h)
	return math.floor(x1), math.floor(y1), math.ceil(x2 - x1), math.ceil(y2 - y1)
end

function ui.clip(x, y, w, h)
	lg.setScissor(transformedRect(x, y, w, h))
end

function ui.icon(kind, x, y, s)
	if kind == "play" then
		lg.polygon("fill", x, y, x, y + s, x + s * 0.85, y + s / 2)
	elseif kind == "pause" then
		lg.rectangle("fill", x, y, s * 0.32, s)
		lg.rectangle("fill", x + s * 0.55, y, s * 0.32, s)
	elseif kind == "stop" then
		lg.rectangle("fill", x, y, s, s)
	elseif kind == "ff" then
		lg.polygon("fill", x, y, x, y + s, x + s / 2, y + s / 2)
		lg.polygon("fill", x + s / 2, y, x + s / 2, y + s, x + s, y + s / 2)
	elseif kind == "eject" then
		lg.polygon("fill", x, y + s * 0.6, x + s, y + s * 0.6, x + s / 2, y)
		lg.rectangle("fill", x, y + s * 0.75, s, s * 0.25)
	elseif kind == "rew" then
		lg.polygon("fill", x + s, y, x + s, y + s, x + s / 2, y + s / 2)
		lg.polygon("fill", x + s / 2, y, x + s / 2, y + s, x, y + s / 2)
	end
end

return ui
