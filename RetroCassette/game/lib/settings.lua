-- Small key=value settings file in the LÖVE save folder.
local Settings = {
	values = {
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
		if key == "lastDir" then
			v.lastDir = value
		end
	end
end

function Settings.save()
	local v = Settings.values
	love.filesystem.write(FILE, string.format("lastDir=%s\n", v.lastDir))
end

return Settings
