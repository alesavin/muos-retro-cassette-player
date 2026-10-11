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

-- Prints text, scrolling it sideways when it doesn't fit in w.
function ui.marquee(font, text, x, y, w, clock)
	lg.setFont(font)
	local tw = font:getWidth(text)
	if tw <= w then
		lg.print(text, x, y)
		return
	end
	local span = tw + 60
	local off = (math.max(0, clock - 1.5) * 35) % span
	local sx, sy, sw, sh = lg.getScissor()
	lg.intersectScissor(x, y - 2, w, font:getHeight() + 4)
	lg.print(text, math.floor(x - off), y)
	lg.print(text, math.floor(x - off + span), y)
	ui.setScissor(sx, sy, sw, sh)
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
	elseif kind == "rew" then
		lg.polygon("fill", x + s, y, x + s, y + s, x + s / 2, y + s / 2)
		lg.polygon("fill", x + s / 2, y, x + s / 2, y + s, x, y + s / 2)
	end
end

return ui
