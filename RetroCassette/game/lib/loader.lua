-- Reads song files on a background thread, so the screen keeps moving while a
-- big file loads. LÖVE 11 plays a song from a copy of the whole file in memory,
-- so the file is read in 1 MB pieces straight into one LÖVE buffer (no
-- whole-file Lua string), which then becomes the song's FileData. That step
-- copies the buffer, so loading briefly needs twice the file's size; check
-- with lib/memory.lua first. Holds at most KEEP songs that nobody has taken
-- yet (the next song, read ahead).
local Loader = {}

local THREAD = [[
require("love.data")
require("love.filesystem")
local CHUNK = 1048576
local requests = love.thread.getChannel("rc_load_requests")
local results = love.thread.getChannel("rc_load_results")

-- Piece-by-piece reading needs LuaJIT's ffi and ByteData:getFFIPointer (LÖVE
-- 11.3+). Without them, read the file in one go (a whole-file Lua string).
local hasFFI, ffi = pcall(require, "ffi")
local probe = love.data.newByteData(1)
local piecewise = hasFFI and probe.getFFIPointer ~= nil and not os.getenv("RC_NO_FFI")
probe:release()
print("loader: " .. (piecewise and "reading songs in 1 MB pieces" or "reading songs whole (no ffi or LÖVE < 11.3)"))

local function loadWhole(path, f)
	local data = f:read("*a")
	f:close()
	local ok, fileData = pcall(love.filesystem.newFileData, data, path:match("([^/]+)$"))
	data = nil
	collectgarbage()
	return ok and fileData or nil
end

local function load(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	if not piecewise then
		return loadWhole(path, f)
	end
	local size = f:seek("end")
	f:seek("set")
	local ok, buffer = pcall(love.data.newByteData, math.max(size, 1))
	if not ok then
		f:close()
		return nil
	end
	local ptr = ffi.cast("uint8_t*", buffer:getFFIPointer())
	local done = 0
	while done < size do
		local chunk = f:read(math.min(CHUNK, size - done))
		if not chunk or #chunk == 0 then
			break
		end
		ffi.copy(ptr + done, chunk, #chunk)
		done = done + #chunk
	end
	f:close()
	local fileData
	if done == size then
		ok, fileData = pcall(love.filesystem.newFileData, buffer, path:match("([^/]+)$"))
		fileData = ok and fileData or nil
	end
	buffer:release()
	collectgarbage()
	return fileData
end

while true do
	local path = requests:demand()
	local fileData = load(path)
	results:push({ path = path, fileData = fileData })
	-- The receiver holds its own reference now; drop this thread's, or the
	-- song would stay in memory after the player releases it.
	if fileData then
		fileData:release()
	end
end
]]

local KEEP = 2

local requests, results
local entries = {} -- path -> { state = "pending" | "ready" | "failed", fileData, used }
local inflight = {} -- path -> true while the thread is reading it
local clock = 0

function Loader.init()
	requests = love.thread.getChannel("rc_load_requests")
	results = love.thread.getChannel("rc_load_results")
	love.thread.newThread(THREAD):start()
end

local function collect()
	local r = results:pop()
	while r do
		inflight[r.path] = nil
		local e = entries[r.path]
		if e then
			e.state = r.fileData and "ready" or "failed"
			e.fileData = r.fileData
		elseif r.fileData then
			r.fileData:release()
		end
		r = results:pop()
	end
end

-- Forgets the least recently used songs beyond KEEP.
local function trim()
	local list = {}
	for path, e in pairs(entries) do
		list[#list + 1] = { path = path, used = e.used }
	end
	table.sort(list, function(a, b)
		return a.used > b.used
	end)
	for i = KEEP + 1, #list do
		local e = entries[list[i].path]
		if e.fileData then
			e.fileData:release()
		end
		entries[list[i].path] = nil
	end
end

local function request(path)
	clock = clock + 1
	local e = entries[path]
	if not e then
		e = { state = "pending" }
		entries[path] = e
		-- A read already under way (from before an eject) will serve this one.
		if not inflight[path] then
			inflight[path] = true
			requests:push(path)
		end
	end
	e.used = clock
	trim()
	return e
end

-- Returns the song's FileData when it's ready, handing it over: the caller
-- owns it from then on and releases it. Otherwise returns nil and "pending"
-- or "failed". The first call starts reading the file.
function Loader.fetch(path)
	collect()
	local e = request(path)
	if e.state == "pending" then
		return nil, "pending"
	end
	entries[path] = nil
	if e.state == "ready" then
		return e.fileData
	end
	return nil, "failed"
end

-- Picks up finished reads; ones nobody waits for any more are freed at once.
function Loader.update()
	collect()
end

-- Forgets every song read but not taken (the tape was ejected). Reads still
-- under way are freed when they finish.
function Loader.clear()
	collect()
	for _, e in pairs(entries) do
		if e.fileData then
			e.fileData:release()
		end
	end
	entries = {}
end

-- Starts reading a song that will be needed soon.
function Loader.prefetch(path)
	if path then
		collect()
		request(path)
	end
end

return Loader
