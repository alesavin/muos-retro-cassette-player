-- Playback of a queue of files, including cassette-style fast-forward and rewind.
local fs = require("lib.fs")

local Player = {}
Player.__index = Player

-- Seconds of audio skipped per second of holding FF/REW.
Player.WIND_SPEED = 12

function Player.new()
	local self = setmetatable({}, Player)
	self.queue = {}
	self.index = 0
	self.source = nil
	self.fileData = nil
	self.state = "stopped" -- stopped | playing | paused
	self.wind = 0 -- -1 rewinding, 1 fast-forwarding, 0 not winding
	self.windPos = 0
	self.windResume = false
	self.volume = 0.8
	self.error = nil
	return self
end

function Player:currentPath()
	return self.queue[self.index]
end

function Player:unload()
	if self.source then
		self.source:stop()
		self.source:release()
	end
	if self.fileData then
		self.fileData:release()
	end
	self.source, self.fileData = nil, nil
end

function Player:load(index, autoplay)
	self:unload()
	self.index = index
	self.state = "stopped"
	self.wind = 0
	self.error = nil
	local path = self.queue[index]
	if not path then
		return false
	end
	local data, err = fs.readAll(path)
	if not data then
		self.error = "Can't read file: " .. tostring(err)
		return false
	end
	local ok, res = pcall(function()
		-- The source streams from this FileData, so it is kept alive on the player.
		local fd = love.filesystem.newFileData(data, fs.basename(path))
		return { fd = fd, src = love.audio.newSource(fd, "stream") }
	end)
	if not ok then
		self.error = "Unsupported file: " .. fs.basename(path)
		return false
	end
	self.fileData, self.source = res.fd, res.src
	self.source:setVolume(self.volume)
	if autoplay then
		self:play()
	end
	return true
end

function Player:setQueue(paths, index)
	self.queue = paths
	if not self:load(index, true) then
		-- Skip unplayable files the way a running tape would.
		self.state = "playing"
		self:step(1)
	end
end

function Player:play()
	if not self.source then
		if self.queue[self.index] then
			self:load(self.index, true)
		end
		return
	end
	self.source:play()
	self.state = "playing"
end

function Player:pause()
	if self.source and self.state == "playing" then
		self.source:pause()
		self.state = "paused"
	end
end

function Player:toggle()
	if self.wind ~= 0 then
		return
	end
	if self.state == "playing" then
		self:pause()
	else
		self:play()
	end
end

-- Move to the next (dir = 1) or previous (dir = -1) playable track. Running off
-- either end of the queue rewinds to the first track and stops, like the end of a side.
function Player:step(dir)
	local n = #self.queue
	if n == 0 then
		return
	end
	local autoplay = self.state == "playing"
	local i = self.index
	for _ = 1, n do
		i = i + dir
		if i < 1 or i > n then
			self:load(1, false)
			return
		end
		if self:load(i, autoplay) then
			return
		end
	end
end

function Player:prev()
	if self.index <= 1 or self:position() > 3 then
		self:seek(0)
	else
		self:step(-1)
	end
end

function Player:duration()
	if not self.source then
		return 0
	end
	local d = self.source:getDuration("seconds")
	if not d or d < 0 then
		return 0
	end
	return d
end

function Player:position()
	if self.wind ~= 0 then
		return self.windPos
	end
	if not self.source then
		return 0
	end
	return self.source:tell("seconds")
end

function Player:progress()
	local d = self:duration()
	if d <= 0 then
		return 0
	end
	return math.min(1, math.max(0, self:position() / d))
end

function Player:seek(t)
	if not self.source then
		return
	end
	local d = self:duration()
	if d > 0 then
		t = math.min(t, d - 0.05)
	end
	self.source:seek(math.max(0, t), "seconds")
end

function Player:startWind(dir)
	if not self.source or self.wind == dir then
		return
	end
	if self.wind == 0 then
		self.windResume = self.state == "playing"
		self.windPos = self.source:tell("seconds")
		if self.state == "playing" then
			self.source:pause()
		end
	end
	self.wind = dir
end

function Player:stopWind(dir)
	if self.wind == 0 or (dir and dir ~= self.wind) then
		return
	end
	self.wind = 0
	self:seek(self.windPos)
	if self.windResume then
		self.source:play()
		self.state = "playing"
	end
end

-- Relative tape speed for the reels: 1 while playing, larger while winding.
function Player:tapeSpeed()
	if self.wind ~= 0 then
		return self.wind * 8
	end
	if self.state == "playing" then
		return 1
	end
	return 0
end

function Player:setVolume(v)
	self.volume = math.min(1, math.max(0, v))
	if self.source then
		self.source:setVolume(self.volume)
	end
end

function Player:update(dt)
	if self.wind ~= 0 then
		local d = self:duration()
		self.windPos = math.max(0, self.windPos + self.wind * Player.WIND_SPEED * dt)
		if d > 0 then
			self.windPos = math.min(self.windPos, d)
		end
		return
	end
	if self.state == "playing" and self.source and not self.source:isPlaying() then
		self:step(1)
	end
end

return Player
