-- Reads track lengths on a background thread so the reels and the window scale
-- can show the whole tape without stalling the screen. Lengths come from file
-- headers (lib/probe.lua); only small files are ever decoded to find them.
local Media = require("lib.media")

local Durations = {}

local THREAD = [[
require("love.filesystem")
require("love.sound")
local probeSource, maxDecode = ...
local Probe = loadstring(probeSource)()
local jobs = love.thread.getChannel("rc_duration_jobs")
local results = love.thread.getChannel("rc_duration_results")
while true do
	local job = jobs:demand()
	-- Headers first: a few kilobytes, whatever the file's size.
	local d = Probe.duration(job.path)
	if not d then
		-- Otherwise decode, which loads the file whole: small files only.
		local f = io.open(job.path, "rb")
		local size = f and f:seek("end") or math.huge
		if f then
			f:close()
		end
		if size <= maxDecode then
			local ok, res = pcall(function()
				return love.sound.newDecoder(job.link or job.path):getDuration()
			end)
			d = ok and res or nil
		end
	end
	results:push({ tape = job.tape, index = job.index, duration = d or -1 })
	collectgarbage()
end
]]

-- Files the thread may decode whole when their header doesn't give a length.
local MAX_DECODE = 32 * 1024 * 1024

-- lib/probe.lua's source, handed to the thread (threads don't share modules).
local function probeSource()
	local src = love.filesystem.read("lib/probe.lua")
	if not src then
		local path = package.searchpath("lib.probe", package.path)
		local f = path and io.open(path, "rb")
		src = f and f:read("*a")
		if f then
			f:close()
		end
	end
	return src
end

local thread, jobs, results
local generation = 0

function Durations.init()
	jobs = love.thread.getChannel("rc_duration_jobs")
	results = love.thread.getChannel("rc_duration_results")
	thread = love.thread.newThread(THREAD)
	thread:start(probeSource(), MAX_DECODE)
end

-- Queues every track on the tape; results for older tapes are ignored.
function Durations.probe(tape)
	generation = generation + 1
	jobs:clear()
	results:clear()
	for i, tr in ipairs(tape.tracks) do
		jobs:push({
			tape = generation,
			index = i,
			path = tr.path,
			link = Media.link(tr.path),
			name = tr.path:match("([^/]+)$"),
		})
	end
end

-- Applies finished results to the tape; returns true if any arrived.
function Durations.update(tape)
	local err = thread:getError()
	if err and not Durations.failed then
		Durations.failed = true
		print("durations thread: " .. err)
	end
	local changed = false
	local r = results:pop()
	while r do
		if tape and r.tape == generation and r.duration > 0 then
			tape:setDuration(r.index, r.duration)
			changed = true
		end
		r = results:pop()
	end
	return changed
end

return Durations
