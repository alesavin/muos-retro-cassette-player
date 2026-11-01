-- Whether a song can be loaded without running out of memory. LÖVE 11 plays a
-- song from a copy of the whole file, and lib/loader.lua briefly needs a second
-- copy while loading, so a song may take at most SHARE of the free memory.
-- Bigger ones are skipped like unreadable files instead of the system killing
-- the app.
local Memory = {}

Memory.SHARE = 0.4

-- Songs at least this small are read ahead while the one before plays.
Memory.READ_AHEAD_MAX = 64 * 1024 * 1024

-- Free memory in bytes, or nil when the system doesn't say.
function Memory.available()
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

-- The file's size in bytes, or nil if it can't be opened.
function Memory.size(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local size = f:seek("end")
	f:close()
	return size
end

function Memory.fits(path)
	local size = Memory.size(path)
	if not size then
		return false
	end
	local free = Memory.available()
	return not free or size <= free * Memory.SHARE
end

return Memory
