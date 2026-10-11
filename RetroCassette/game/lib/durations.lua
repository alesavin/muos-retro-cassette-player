-- Reads track lengths on a background thread so the reels and the window scale
-- can show the whole tape without stalling the screen while files load.
local Durations = {}

local THREAD = [[
require("love.filesystem")
require("love.sound")
local jobs = love.thread.getChannel("rc_duration_jobs")
local results = love.thread.getChannel("rc_duration_results")
while true do
	local job = jobs:demand()
	local d = -1
	local f = io.open(job.path, "rb")
	if f then
		local data = f:read("*a")
		f:close()
		local ok, res = pcall(function()
			local fd = love.filesystem.newFileData(data, job.name)
			return love.sound.newDecoder(fd):getDuration()
		end)
		if ok and res then
			d = res
		end
	end
	results:push({ tape = job.tape, index = job.index, duration = d })
end
]]

local thread, jobs, results
local generation = 0

function Durations.init()
	jobs = love.thread.getChannel("rc_duration_jobs")
	results = love.thread.getChannel("rc_duration_results")
	thread = love.thread.newThread(THREAD)
	thread:start()
end

-- Queues every track on the tape; results for older tapes are ignored.
function Durations.probe(tape)
	generation = generation + 1
	jobs:clear()
	results:clear()
	for i, tr in ipairs(tape.tracks) do
		jobs:push({ tape = generation, index = i, path = tr.path, name = tr.path:match("([^/]+)$") })
	end
end

function Durations.update(tape)
	local err = thread:getError()
	if err and not Durations.failed then
		Durations.failed = true
		print("durations thread: " .. err)
	end
	local r = results:pop()
	while r do
		if tape and r.tape == generation and r.duration > 0 then
			tape:setDuration(r.index, r.duration)
		end
		r = results:pop()
	end
end

return Durations
