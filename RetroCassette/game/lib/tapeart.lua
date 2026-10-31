-- Drawing shared by the library spines and the cassette in the player.
local lg = love.graphics

local TapeArt = {}

local TWO = { { 0.95, 0.55, 0.15 }, { 0.85, 0.24, 0.20 } }
local RAINBOW = {
	{ 0.90, 0.20, 0.20 }, { 0.95, 0.60, 0.10 }, { 0.95, 0.85, 0.20 }, { 0.30, 0.70, 0.30 }, { 0.20, 0.45, 0.80 },
}

function TapeArt.setColor(c, a)
	lg.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

-- Fills x, y, w, h with the style's stripes: horizontal bands stacked top to bottom.
-- Returns false when the style has none.
function TapeArt.stripes(st, x, y, w, h)
	local bands
	if st.stripe == "two" then
		bands = TWO
	elseif st.stripe == "rainbow" then
		bands = RAINBOW
	elseif st.stripe == "band" then
		bands = { st.ink }
	else
		return false
	end
	local bh = h / #bands
	for i, c in ipairs(bands) do
		TapeArt.setColor(c, 0.95)
		lg.rectangle("fill", x, y + (i - 1) * bh, w, bh + 0.5)
	end
	return true
end

-- Shell colour, slightly see-through for clear shells.
function TapeArt.shell(st)
	TapeArt.setColor(st.shell.color, st.shell.clear and 0.88 or 1)
end

-- A colour that reads on the shell: dark on light shells, light on dark ones.
function TapeArt.onShell(st, a)
	if st.shell.light then
		lg.setColor(0, 0, 0, a)
	else
		lg.setColor(1, 1, 1, a)
	end
end

-- Ribs on clear shells, as seen through the plastic.
function TapeArt.ribs(st, x, y, w, h, step)
	if not st.shell.clear then
		return
	end
	lg.setColor(1, 1, 1, 0.10)
	lg.setLineWidth(1)
	for i = step, w - 1, step do
		lg.line(x + i, y + 2, x + i, y + h - 2)
	end
end

return TapeArt
