-- Small key=value settings file in the LÖVE save folder.
local Settings = {
	values = {
		volume = 0.8,
		hiss = true,
		theme = 1,
		lastDir = "",
	},
}

local FILE = "settings.txt"

function Settings.load()
	local contents = love.filesystem.getInfo(FILE) and love.filesystem.read(FILE)
	if not contents then
		return
	end
	local v = Settings.values
	for key, value in contents:gmatch("([%w_]+)=([^\n]*)") do
		if key == "volume" or key == "theme" then
			v[key] = tonumber(value) or v[key]
		elseif key == "hiss" then
			v.hiss = value == "true"
		elseif key == "lastDir" then
			v.lastDir = value
		end
	end
end

function Settings.save()
	local v = Settings.values
	local out = string.format(
		"volume=%.2f\nhiss=%s\ntheme=%d\nlastDir=%s\n",
		v.volume,
		tostring(v.hiss),
		v.theme,
		v.lastDir
	)
	love.filesystem.write(FILE, out)
end

return Settings
