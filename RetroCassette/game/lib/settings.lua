-- Small key=value settings file in the LÖVE save folder.
local Settings = {
	values = {
		volume = 0.8,
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
		if key == "volume" then
			v.volume = tonumber(value) or v.volume
		elseif key == "lastDir" then
			v.lastDir = value
		end
	end
end

function Settings.save()
	local v = Settings.values
	love.filesystem.write(FILE, string.format("volume=%.2f\nlastDir=%s\n", v.volume, v.lastDir))
end

return Settings
