-- One side of a tape: the folder's tracks laid end to end with short blank gaps,
-- on a single timeline measured in seconds.
local Tape = {}
Tape.__index = Tape

-- Blank tape between songs. The music sensor finds songs by these gaps.
Tape.GAP = 4
-- Length assumed for a track until its real duration is known.
Tape.DEFAULT_DURATION = 210

function Tape.new(paths)
	local self = setmetatable({ tracks = {} }, Tape)
	for i, p in ipairs(paths) do
		self.tracks[i] = { path = p }
	end
	self:layout()
	return self
end

function Tape:estimate()
	local sum, n = 0, 0
	for _, tr in ipairs(self.tracks) do
		if tr.duration and not tr.bad then
			sum, n = sum + tr.duration, n + 1
		end
	end
	return n > 0 and sum / n or Tape.DEFAULT_DURATION
end

function Tape:layout()
	local est = self:estimate()
	local t = 0
	for i, tr in ipairs(self.tracks) do
		tr.start = t
		tr.length = tr.bad and 0 or tr.duration or est
		t = t + tr.length
		if i < #self.tracks then
			t = t + Tape.GAP
		end
	end
	self.length = t
end

function Tape:setDuration(i, d)
	local tr = self.tracks[i]
	if tr and d and d > 0 and tr.duration ~= d then
		tr.duration = d
		self:layout()
	end
end

-- An unreadable file takes up no tape.
function Tape:markBad(i)
	self.tracks[i].bad = true
	self:layout()
end

-- Returns the track at tape position t, the offset into it, and whether t is
-- on blank tape. In a gap it returns the upcoming track; past the end, the last one.
function Tape:locate(t)
	for i, tr in ipairs(self.tracks) do
		if t < tr.start + tr.length then
			if t < tr.start then
				return i, 0, true
			end
			return i, t - tr.start, false
		end
	end
	local n = #self.tracks
	return n, self.tracks[n].length, true
end

-- Start of the next song after t, or nil on the last one.
function Tape:nextStart(t)
	for _, tr in ipairs(self.tracks) do
		if tr.start > t + 0.01 then
			return tr.start
		end
	end
	return nil
end

-- Start of the current song, or of the previous one when t is in its first 3 seconds.
function Tape:prevStart(t)
	local target = 0
	for _, tr in ipairs(self.tracks) do
		if tr.start <= t - 3 then
			target = tr.start
		end
	end
	return target
end

return Tape
