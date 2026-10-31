-- How a tape looks: picked from a hash of its name, so a tape's spine in the
-- library and the cassette in the player always match.
local Style = {}

Style.SHELLS = {
	{ name = "black", color = { 0.13, 0.13, 0.14 } },
	{ name = "smoke", color = { 0.32, 0.30, 0.30 }, clear = true },
	{ name = "white", color = { 0.90, 0.89, 0.86 }, light = true },
	{ name = "red", color = { 0.72, 0.13, 0.12 } },
	{ name = "blue", color = { 0.22, 0.42, 0.72 }, clear = true },
	{ name = "yellow", color = { 0.95, 0.78, 0.16 }, light = true },
	{ name = "chrome", color = { 0.70, 0.72, 0.76 }, light = true },
	{ name = "mint", color = { 0.52, 0.78, 0.68 }, light = true },
}

Style.PAPERS = {
	{ 0.96, 0.92, 0.82 }, -- cream
	{ 0.98, 0.98, 0.96 }, -- white
	{ 0.80, 0.66, 0.47 }, -- kraft
	{ 0.98, 0.80, 0.84 }, -- pink
	{ 0.75, 0.88, 0.97 }, -- sky
}

Style.STRIPES = { "none", "two", "rainbow", "band" }

-- Files in assets/fonts; marker and pen are handwriting.
Style.FONTS = { "marker", "pen", "typewriter", "print", "dotmatrix" }

Style.INKS = {
	{ 0.12, 0.18, 0.55 }, -- blue ballpoint
	{ 0.08, 0.08, 0.08 }, -- black
	{ 0.70, 0.10, 0.10 }, -- red
}

-- djb2-style hash of s, kept within 32 bits. seed and mult default to djb2's.
function Style.hash(s, seed, mult)
	local h = seed or 5381
	mult = mult or 33
	for i = 1, #s do
		h = (h * mult + s:byte(i)) % 4294967296
	end
	return h
end

local cache = {}

function Style.of(name)
	local st = cache[name]
	if st then
		return st
	end
	-- Each element gets its own hash, so names that differ by one character
	-- ("Disc 1", "Disc 2") still differ in every element.
	local function pick(list, seed, mult)
		return list[Style.hash(name, seed, mult) % #list + 1]
	end
	st = {
		shell = pick(Style.SHELLS, 5381, 33),
		paper = pick(Style.PAPERS, 7, 31),
		stripe = pick(Style.STRIPES, 11, 37),
		font = pick(Style.FONTS, 13, 41),
		ink = pick(Style.INKS, 17, 43),
	}
	-- Handwritten titles sit slightly askew.
	local handwritten = st.font == "marker" or st.font == "pen"
	st.tilt = handwritten and ((Style.hash(name, 19, 47) % 7) - 3) * 0.004 or 0
	cache[name] = st
	return st
end

return Style
