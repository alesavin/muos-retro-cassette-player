-- Small key=value settings file. On the device it lives in the app's data
-- folder (RC_DATA_DIR, set by the launcher): the LÖVE save folder is in /tmp
-- there so it can hold symlinks (lib/media.lua). Elsewhere it's in the save folder.
local Settings = {
	values = {
		lastDir = "",
	},
}

local FILE = "settings.txt"

local function dataPath(name)
	local dir = os.getenv("RC_DATA_DIR")
	return dir and dir ~= "" and (dir .. "/" .. name) or nil
end

local function readFile(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local contents = f:read("*a")
	f:close()
	return contents
end

local function read()
	local path = dataPath(FILE)
	if path then
		-- Versions up to 0.3.3 kept it under the LÖVE save folder inside the data folder.
		return readFile(path) or readFile(dataPath("love/retrocassette/" .. FILE))
	end
	return love.filesystem.getInfo(FILE) and love.filesystem.read(FILE)
end

function Settings.load()
	local contents = read()
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
	local contents = string.format("lastDir=%s\n", v.lastDir)
	local path = dataPath(FILE)
	if path then
		local f = io.open(path, "wb")
		if f then
			f:write(contents)
			f:close()
		end
		return
	end
	love.filesystem.write(FILE, contents)
end

return Settings
