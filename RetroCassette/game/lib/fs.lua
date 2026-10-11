-- Access to the real filesystem. love.filesystem is sandboxed to the game and
-- save folders, so music on the SD cards is listed with find and read with io.open.
local fs = {}

fs.AUDIO_EXT = { mp3 = true, ogg = true, oga = true, flac = true, wav = true }

-- Folders checked for music, in order. RC_MUSIC_DIR overrides them (handy on a desktop).
fs.CANDIDATE_ROOTS = {
	"/mnt/sdcard/MUSIC",
	"/mnt/mmc/MUSIC",
	"/mnt/union/MUSIC",
}

local function quote(s)
	return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

function fs.join(a, b)
	if a:sub(-1) == "/" then
		return a .. b
	end
	return a .. "/" .. b
end

function fs.basename(p)
	local trimmed = p:gsub("/+$", "")
	return trimmed:match("([^/]+)$") or p
end

function fs.parent(p)
	local trimmed = p:gsub("/+$", "")
	local parent = trimmed:match("^(.*)/[^/]*$")
	if parent == nil or parent == "" then
		return "/"
	end
	return parent
end

function fs.stem(name)
	return name:match("^(.*)%.[^%.]+$") or name
end

function fs.isAudio(name)
	local ext = name:match("%.([^%.]+)$")
	return ext ~= nil and fs.AUDIO_EXT[ext:lower()] == true
end

function fs.isDir(p)
	local r = os.execute("[ -d " .. quote(p) .. " ]")
	-- Lua 5.1/LuaJIT returns an exit code, Lua 5.2+ returns true/nil.
	return r == 0 or r == true
end

local function sortNames(t)
	table.sort(t, function(a, b)
		return a:lower() < b:lower()
	end)
end

local function findNames(dir, ftype)
	local names = {}
	local p = io.popen("find " .. quote(dir) .. " -mindepth 1 -maxdepth 1 -type " .. ftype .. " 2>/dev/null")
	if not p then
		return names
	end
	for line in p:lines() do
		local name = line:match("([^/]+)$")
		if name and name:sub(1, 1) ~= "." then
			names[#names + 1] = name
		end
	end
	p:close()
	sortNames(names)
	return names
end

-- Returns two sorted lists of names: subfolders and playable audio files.
function fs.list(dir)
	local dirs = findNames(dir, "d")
	local files = {}
	for _, name in ipairs(findNames(dir, "f")) do
		if fs.isAudio(name) then
			files[#files + 1] = name
		end
	end
	return dirs, files
end

function fs.readAll(p)
	local f, err = io.open(p, "rb")
	if not f then
		return nil, err
	end
	local data = f:read("*a")
	f:close()
	return data
end

function fs.musicRoots()
	local override = os.getenv("RC_MUSIC_DIR")
	local candidates = override and { override } or fs.CANDIDATE_ROOTS
	local roots = {}
	for _, dir in ipairs(candidates) do
		if fs.isDir(dir) then
			roots[#roots + 1] = dir
		end
	end
	return roots
end

return fs
