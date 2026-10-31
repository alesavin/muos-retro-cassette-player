-- Label fonts by name and size, loaded on first use. Characters a font lacks
-- (Cyrillic in the handwriting fonts, for example) fall back to Oswald.
local Fonts = {}

local cache = {}

-- What newFont loads for a font name; tools/harness replaces this because it
-- runs the app from outside the game folder.
function Fonts.source(name)
	return "assets/fonts/" .. name .. ".ttf"
end

local function load(name, size, dpi)
	return love.graphics.newFont(Fonts.source(name), size, "normal", dpi)
end

-- dpi: rasterise for drawing scaled up by this much (the cassette in the player).
function Fonts.get(name, size, dpi)
	size = math.max(6, math.floor(size + 0.5))
	dpi = dpi or 1
	local key = name .. ":" .. size .. ":" .. dpi
	local f = cache[key]
	if not f then
		f = load(name, size, dpi)
		if name ~= "print" then
			f:setFallbacks(Fonts.get("print", size, dpi))
		end
		cache[key] = f
	end
	return f
end

local fitCache = {}

-- The largest font no bigger than size that fits text in maxw (down to 60%).
function Fonts.fit(name, text, maxw, size, dpi)
	local key = name .. "\0" .. text .. "\0" .. maxw .. "\0" .. size .. "\0" .. (dpi or 1)
	local f = fitCache[key]
	if f then
		return f
	end
	local s = size
	f = Fonts.get(name, s, dpi)
	while f:getWidth(text) > maxw and s > size * 0.6 do
		s = s - 1
		f = Fonts.get(name, s, dpi)
	end
	fitCache[key] = f
	return f
end

return Fonts
