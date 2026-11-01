-- Opens songs from the SD card through LÖVE. love.filesystem only sees the
-- game and save folders, so each song gets a symlink in the save folder and
-- is opened through it: LÖVE reads it straight into its own buffer, with no
-- Lua copy. (LÖVE 11 still holds the whole file while playing, hence
-- Media.fits.) Folder symlinks aren't followed, so the links are per file.
local fs = require("lib.fs")
local Style = require("lib.style")

local Media = {}

local DIR = "links"

-- Without links (a save folder on a filesystem that can't hold them), songs
-- are read into memory by lib/loader.lua instead, up to Loader.MAX bytes.

function Media.init()
	love.filesystem.setSymlinksEnabled(true)
	love.filesystem.createDirectory(DIR)
	for _, name in ipairs(love.filesystem.getDirectoryItems(DIR)) do
		love.filesystem.remove(DIR .. "/" .. name)
	end
	Media.saveDir = love.filesystem.getSaveDirectory()
end

-- A path love.filesystem can open for the song at an absolute path, or nil
-- if no link can be made.
function Media.link(path)
	if not Media.saveDir then
		return nil
	end
	local ext = (path:match("%.([^%./]+)$") or "bin"):lower()
	local name = DIR .. "/" .. Style.hash(path) .. "-" .. Style.hash(path, 7, 31) .. "." .. ext
	if not love.filesystem.getInfo(name) then
		os.execute("ln -sfn " .. fs.quote(path) .. " " .. fs.quote(Media.saveDir .. "/" .. name) .. " 2>/dev/null")
		if not love.filesystem.getInfo(name) then
			return nil
		end
	end
	return name
end

-- Free memory in bytes, or nil when the system doesn't say.
local function available()
	local f = io.open("/proc/meminfo", "r")
	if not f then
		return nil
	end
	local kb
	for line in f:lines() do
		kb = line:match("^MemAvailable:%s+(%d+)")
		if kb then
			break
		end
	end
	f:close()
	return kb and tonumber(kb) * 1024
end

-- LÖVE 11 loads a song whole even when it streams it. False when the file
-- would take more than half the free memory: such a song is skipped like an
-- unreadable one rather than letting the system kill the app.
function Media.fits(path)
	local f = io.open(path, "rb")
	if not f then
		return false
	end
	local size = f:seek("end")
	f:close()
	local free = available()
	return not free or size <= free * 0.5
end

return Media
