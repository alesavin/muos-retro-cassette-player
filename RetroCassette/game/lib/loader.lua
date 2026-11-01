-- Fallback for when songs can't be streamed through lib/media.lua: reads song
-- files into memory on a background thread, so the screen keeps moving while
-- a file loads. Files over MAX bytes are refused, since holding them would
-- risk running out of memory. Holds at most KEEP songs that nobody has taken
-- yet (the next song, read ahead).
local Loader = {}

local THREAD = [[
require("love.filesystem")
local max = ...
local requests = love.thread.getChannel("rc_load_requests")
local results = love.thread.getChannel("rc_load_results")
while true do
	local path = requests:demand()
	local f = io.open(path, "rb")
	local data
	if f then
		if f:seek("end") <= max then
			f:seek("set")
			data = f:read("*a")
		end
		f:close()
	end
	if data then
		local ok, fd = pcall(love.filesystem.newFileData, data, path:match("([^/]+)$"))
		data = nil
		collectgarbage()
		results:push({ path = path, fileData = ok and fd or nil })
	else
		results:push({ path = path })
	end
end
]]

local KEEP = 2

local requests, results
local entries = {} -- path -> { state = "pending" | "ready" | "failed", fileData, used }
local clock = 0

Loader.MAX = 96 * 1024 * 1024

function Loader.init()
	requests = love.thread.getChannel("rc_load_requests")
	results = love.thread.getChannel("rc_load_results")
	love.thread.newThread(THREAD):start(Loader.MAX)
end

local function collect()
	local r = results:pop()
	while r do
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
		requests:push(path)
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

-- Starts reading a song that will be needed soon.
function Loader.prefetch(path)
	if path then
		collect()
		request(path)
	end
end

return Loader
