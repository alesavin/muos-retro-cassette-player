-- The tape transport: latching REW / STOP / PLAY / FF keys like a real
-- portable player, with cue/review and an automatic music sensor (AMS).
--
--   stopped      FF/REW tap latches and winds until STOP or the end of the tape
--   playing      FF held = cue (fast, high-pitched audio), REW held = review (muted)
--                FF/REW tapped = wind to the next song / back to this or the previous song
--   PLAY         while playing, pauses (the key stays half-way down); again resumes
--   STOP         releases every key; pressed again while stopped, opens the lid
--   skip         (D-pad) jumps straight to the previous / next song
local Loader = require("lib.loader")
local Media = require("lib.media")

local Deck = {}
Deck.__index = Deck

Deck.CUE_RATE = 3
Deck.REVIEW_RATE = 4
Deck.TAP_TIME = 0.3
-- How long the reels whir after a skip.
Deck.SKIP_TIME = 0.35

-- Returns a stream source and the FileData it reads from, if any (kept alive
-- with it), or nil and "pending" while lib/loader.lua is still reading the
-- file, or nil and "failed". Songs are opened through a link (lib/media.lua)
-- when possible, and refused when they wouldn't fit in memory.
local function openSource(path)
	if not Media.fits(path) then
		return nil, "failed"
	end
	local link = Media.link(path)
	if link then
		local ok, src = pcall(love.audio.newSource, link, "stream")
		if ok then
			return src
		end
		return nil, "failed"
	end
	local fd, err = Loader.fetch(path)
	if not fd then
		return nil, err
	end
	local ok, src = pcall(love.audio.newSource, fd, "stream")
	if not ok then
		fd:release()
		return nil, "failed"
	end
	return src, fd
end

function Deck.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Deck)
	self.open = opts.open or openSource
	self.prefetch = opts.prefetch or (opts.open and function() end) or Loader.prefetch
	self.onClunk = opts.onClunk or function() end
	self.tape = nil
	self.t = 0 -- position on the tape, in seconds
	self.mode = "stop" -- stop | play | pause | ff | rew | ams
	self.hold = nil -- while playing: 1 = cue, -1 = review
	self.volume = 0.8
	self.clock = 0
	self.source, self.fileData, self.srcIndex, self.started = nil, nil, nil, false
	return self
end

function Deck:unloadSource()
	if self.source then
		self.source:stop()
		self.source:release()
	end
	if self.fileData then
		self.fileData:release()
	end
	self.source, self.fileData, self.srcIndex, self.started = nil, nil, nil, false
end

-- Stops the sound but keeps the tape where it is.
function Deck:silence()
	if self.source then
		self.source:pause()
	end
	self.started = false
	self.loadingSince = nil
end

function Deck:insert(tape, t)
	self:eject()
	self.tape = tape
	self.t = t or 0
	self:remember()
end

-- Song lengths arrive after the tape is in, and each one moves the songs after
-- it. The position is therefore also held as (song, offset into it) and
-- re-applied whenever the tape's layout changes.
function Deck:remember()
	local i = self.tape:locate(self.t)
	self.anchorIndex = i
	self.anchorOffset = self.t - self.tape.tracks[i].start
	self.anchorVersion = self.tape.version
end

function Deck:resync()
	local tape = self.tape
	if tape.version == self.anchorVersion then
		return
	end
	local t = tape.tracks[self.anchorIndex].start + self.anchorOffset
	self.t = math.max(0, math.min(tape.length, t))
	if self.mode == "ams" then
		self.amsTarget = tape.tracks[self.amsIndex].start
	end
	self.anchorVersion = tape.version
end

function Deck:eject()
	self:unloadSource()
	self.tape = nil
	self.t = 0
	self.mode = "stop"
	self.hold = nil
end

-- Tape seconds per second while winding: a whole side takes at most about 30 seconds.
function Deck:windRate()
	return math.max(30, self.tape.length / 30)
end

function Deck:autoStop()
	self:silence()
	self.mode = "stop"
	self.hold = nil
	self.onClunk()
end

-- key: "rew" | "stop" | "play" | "ff". Returns "eject" when STOP is pressed while stopped.
function Deck:press(key)
	if not self.tape then
		return nil
	end
	if key == "play" then
		if self.mode == "ams" or self.hold or self.t >= self.tape.length then
			return nil
		end
		self:silence()
		self.mode = self.mode == "play" and "pause" or "play"
	elseif key == "stop" then
		if self.mode == "stop" then
			return "eject"
		end
		self:silence()
		self.mode = "stop"
		self.hold = nil
	elseif key == "ff" or key == "rew" then
		local dir = key == "ff" and 1 or -1
		if self.mode == "play" then
			if self.hold then
				return nil
			end
			self.hold, self.holdStart, self.holdT = dir, self.clock, self.t
			if dir < 0 then
				self:silence()
			end
		elseif self.mode ~= "ams" then
			self:silence()
			self.mode = key
		end
	end
	self.onClunk()
	return nil
end

-- Jumps straight to the start of the next song (dir 1), or of this one / the
-- previous one (dir -1), keeping play, pause or stop as they were. Returns
-- false when there is nowhere to go or the tape is winding.
function Deck:skip(dir)
	if not self.tape or self.hold or not (self.mode == "play" or self.mode == "pause" or self.mode == "stop") then
		return false
	end
	local target
	if dir > 0 then
		target = self.tape:nextStart(self.t)
	else
		target = self.tape:prevStart(self.t)
	end
	if not target then
		return false
	end
	self:silence()
	self.t = target
	self:remember()
	self.skipTime, self.skipDir = Deck.SKIP_TIME, dir
	return true
end

function Deck:release(key)
	local dir = (key == "ff" and 1) or (key == "rew" and -1) or nil
	if not self.tape or self.mode ~= "play" or self.hold ~= dir or dir == nil then
		return
	end
	self.hold = nil
	if self.clock - self.holdStart >= Deck.TAP_TIME then
		-- End of cue/review: play carries on from here (review already silenced the
		-- source, so the next update seeks to the new position).
		return
	end
	local target, index
	if dir > 0 then
		target, index = self.tape:nextStart(self.holdT)
	else
		target, index = self.tape:prevStart(self.holdT)
	end
	self:silence()
	if target then
		self.mode = "ams"
		self.amsTarget, self.amsIndex = target, index
		self.amsDir = target >= self.t and 1 or -1
	else
		-- No song after this one: wind on to the end of the tape.
		self.mode = "ff"
	end
end

-- Returns "ok", "pending" while the file is still being read, or "bad".
function Deck:loadSource(i)
	self:unloadSource()
	local tr = self.tape.tracks[i]
	if tr.bad then
		return "bad"
	end
	local src, fd = self.open(tr.path)
	if not src then
		if fd == "pending" then
			self.loadingSince = self.loadingSince or self.clock
			return "pending"
		end
		self.loadingSince = nil
		self.tape:markBad(i)
		return "bad"
	end
	self.loadingSince = nil
	self.source, self.fileData, self.srcIndex, self.started = src, fd, i, false
	-- An MP3's length means scanning the whole file, which is left to the
	-- background thread in lib/durations.lua; other formats know it at once.
	if not tr.path:lower():match("%.mp3$") then
		local d = src:getDuration()
		if d and d > 0 then
			self.tape:setDuration(i, d)
		end
	end
	-- Read the next song ahead, unless songs stream (then there's nothing to read).
	local nextTrack = self.tape.tracks[i + 1]
	if nextTrack and fd then
		self.prefetch(nextTrack.path)
	end
	return "ok"
end

function Deck:updatePlay(dt)
	local tape = self.tape
	if self.hold == -1 then
		self.t = math.max(0, self.t - Deck.REVIEW_RATE * dt)
		return
	end
	local rate = self.hold == 1 and Deck.CUE_RATE or 1
	local i, offset, blank = tape:locate(self.t)
	if not blank and self.srcIndex ~= i then
		if self:loadSource(i) ~= "ok" then
			-- Still reading the file: wait. Unreadable: the track now has no
			-- length, and the next update moves past it.
			return
		end
		self:resync()
		i, offset, blank = tape:locate(self.t)
	end
	if blank then
		self.t = self.t + rate * dt
	elseif not self.started then
		self.source:seek(offset)
		self.source:play()
		self.started = true
	elseif self.source:isPlaying() then
		self.t = tape.tracks[i].start + self.source:tell()
	else
		-- The recording ended: run on into the gap.
		self.t = tape.tracks[i].start + tape.tracks[i].length + 0.001
		self.started = false
	end
	if self.source then
		self.source:setPitch(rate)
		self.source:setVolume(self.volume)
	end
	if self.t >= tape.length then
		self.t = tape.length
		self:autoStop()
	end
end

function Deck:update(dt)
	self.clock = self.clock + dt
	if self.skipTime then
		self.skipTime = self.skipTime - dt
		if self.skipTime <= 0 then
			self.skipTime = nil
		end
	end
	if not self.tape then
		return
	end
	self:resync()
	if self.mode == "ff" or self.mode == "rew" then
		local dir = self.mode == "ff" and 1 or -1
		self.t = self.t + dir * self:windRate() * dt
		if self.t >= self.tape.length or self.t <= 0 then
			self.t = math.max(0, math.min(self.tape.length, self.t))
			self:autoStop()
		end
	elseif self.mode == "ams" then
		self.t = self.t + self.amsDir * self:windRate() * dt
		if (self.t - self.amsTarget) * self.amsDir >= 0 then
			self.t = self.amsTarget
			self.mode = "play"
		end
	elseif self.mode == "play" then
		self:updatePlay(dt)
	end
	if self.tape then
		self:remember()
	end
end

function Deck:setVolume(v)
	self.volume = math.min(1, math.max(0, v))
	if self.source then
		self.source:setVolume(self.volume)
	end
end

function Deck:progress()
	if not self.tape or self.tape.length <= 0 then
		return 0
	end
	return math.min(1, math.max(0, self.t / self.tape.length))
end

function Deck:winding()
	return self.mode == "ff" or self.mode == "rew" or self.mode == "ams" or self.hold == -1 or self.skipTime ~= nil
end

-- Reel speed relative to normal play; negative runs the tape backwards.
function Deck:tapeSpeed()
	if self.skipTime then
		return 6 * self.skipDir
	elseif self.mode == "ff" then
		return 6
	elseif self.mode == "rew" then
		return -6
	elseif self.mode == "ams" then
		return 6 * self.amsDir
	elseif self.mode == "play" then
		if self.hold == 1 then
			return Deck.CUE_RATE
		elseif self.hold == -1 then
			return -Deck.REVIEW_RATE
		end
		return 1
	end
	return 0
end

-- How far each key is down: 1 latched, 0.5 for PLAY while paused (STOP is only
-- down while held, so the caller adds it).
function Deck:keysDown()
	local ams = self.mode == "ams"
	local play = 0
	if self:loading() then
		play = 0.3 + 0.6 * self:loadingTravel()
	elseif self.mode == "play" or ams then
		play = 1
	elseif self.mode == "pause" then
		play = 0.5
	end
	return {
		rew = (self.mode == "rew" or self.hold == -1 or (ams and self.amsDir < 0)) and 1 or 0,
		play = play,
		ff = (self.mode == "ff" or self.hold == 1 or (ams and self.amsDir > 0)) and 1 or 0,
	}
end

-- The head touches the tape while playing or paused.
function Deck:headEngaged()
	return self.mode == "play" or self.mode == "pause" or self.mode == "ams"
end

-- True while PLAY is down but the song's file is still being read.
function Deck:loading()
	return self.mode == "play" and self.loadingSince ~= nil
end

-- How far the motor has got while loading (0 -> 1): PLAY sinks and the head
-- rises as if the motor were starting, and both settle once the song plays.
function Deck:loadingTravel()
	return 1 - math.exp(-1.5 * (self.clock - self.loadingSince))
end

-- Head position, 0 (pulled back) .. 1 (against the tape).
function Deck:headPosition()
	if self:loading() then
		return 0.1 + 0.8 * self:loadingTravel()
	end
	return self:headEngaged() and 1 or 0
end

-- Title of the song under the head (or the next one while on blank tape).
function Deck:currentTrack()
	if not self.tape then
		return nil
	end
	local i = self.tape:locate(self.t)
	return self.tape.tracks[i]
end

return Deck
