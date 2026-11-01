-- Song lengths from file headers, reading a few kilobytes instead of decoding
-- the whole file (LÖVE 11's decoders load a file whole, which a long mix can't
-- afford). Plain Lua with no LÖVE calls, so it also runs on the background
-- thread in lib/durations.lua and in the tests.
local Probe = {}

local function u8(s, i)
	return s:byte(i) or 0
end

local function le32(s, i)
	return u8(s, i) + u8(s, i + 1) * 256 + u8(s, i + 2) * 65536 + u8(s, i + 3) * 16777216
end

local function be32(s, i)
	return u8(s, i) * 16777216 + u8(s, i + 1) * 65536 + u8(s, i + 2) * 256 + u8(s, i + 3)
end

local function le64(s, i)
	return le32(s, i) + le32(s, i + 4) * 4294967296
end

-- RIFF chunks: byte rate from "fmt ", length from "data".
local function wav(f, size)
	f:seek("set", 12)
	local byteRate
	while true do
		local head = f:read(8)
		if not head or #head < 8 then
			return nil
		end
		local id, len = head:sub(1, 4), le32(head, 5)
		if id == "fmt " then
			local fmt = f:read(len)
			byteRate = fmt and le32(fmt, 9)
		elseif id == "data" then
			-- Some writers leave the length at 0 or too big; trust the file size then.
			local start = f:seek()
			if len == 0 or start + len > size then
				len = size - start
			end
			return byteRate and byteRate > 0 and len / byteRate or nil
		else
			f:seek("cur", len + len % 2)
		end
	end
end

-- STREAMINFO: 20-bit sample rate and 36-bit sample count.
local function flac(f)
	f:seek("set", 4)
	local block = f:read(38)
	if not block or #block < 38 or u8(block, 1) % 128 ~= 0 then
		return nil
	end
	local b = function(i)
		return u8(block, 4 + i)
	end
	local rate = b(11) * 4096 + b(12) * 16 + math.floor(b(13) / 16)
	local samples = (b(14) % 16) * 4294967296 + b(15) * 16777216 + b(16) * 65536 + b(17) * 256 + b(18)
	if rate == 0 or samples == 0 then
		return nil
	end
	return samples / rate
end

-- Vorbis: sample rate from the identification header, sample count from the
-- granule position of the last page.
local function ogg(f, size)
	f:seek("set", 0)
	local head = f:read(4096) or ""
	local at = head:find("\1vorbis", 1, true)
	if not at then
		return nil
	end
	local rate = le32(head, at + 12)
	local tailSize = math.min(size, 65536)
	f:seek("set", size - tailSize)
	local tail = f:read(tailSize) or ""
	local last
	local from = 1
	while true do
		local i = tail:find("OggS", from, true)
		if not i then
			break
		end
		last, from = i, i + 1
	end
	if not last or rate == 0 then
		return nil
	end
	return le64(tail, last + 6) / rate
end

local MP3_BITRATES = {
	[1] = { 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 },
	[2] = { 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 },
}
local MP3_RATES = {
	[3] = { 44100, 48000, 32000 }, -- MPEG 1
	[2] = { 22050, 24000, 16000 }, -- MPEG 2
	[0] = { 11025, 12000, 8000 }, -- MPEG 2.5
}

-- Layer III: frame count from a Xing/Info or VBRI header, else constant bitrate.
local function mp3(f, size)
	f:seek("set", 0)
	local head = f:read(10) or ""
	local start = 0
	if head:sub(1, 3) == "ID3" and #head == 10 then
		start = 10 + u8(head, 7) * 2097152 + u8(head, 8) * 16384 + u8(head, 9) * 128 + u8(head, 10)
	end
	f:seek("set", start)
	local buf = f:read(16384) or ""
	for i = 1, #buf - 4 do
		local b1, b2, b3, b4 = u8(buf, i), u8(buf, i + 1), u8(buf, i + 2), u8(buf, i + 3)
		if b1 == 255 and b2 >= 224 then
			local version = math.floor(b2 / 8) % 4 -- 3 = MPEG1, 2 = MPEG2, 0 = MPEG2.5
			local layer = math.floor(b2 / 2) % 4 -- 1 = Layer III
			local bitrateIndex = math.floor(b3 / 16)
			local rateIndex = math.floor(b3 / 4) % 4
			if version ~= 1 and layer == 1 and bitrateIndex > 0 and bitrateIndex < 15 and rateIndex < 3 then
				local rate = MP3_RATES[version][rateIndex + 1]
				local kbps = MP3_BITRATES[version == 3 and 1 or 2][bitrateIndex]
				local perFrame = version == 3 and 1152 or 576
				local mono = math.floor(b4 / 64) == 3
				local side = version == 3 and (mono and 17 or 32) or (mono and 9 or 17)
				local x = i + 4 + side
				local tag = buf:sub(x, x + 3)
				if (tag == "Xing" or tag == "Info") and u8(buf, x + 7) % 2 == 1 then
					return be32(buf, x + 8) * perFrame / rate
				end
				if buf:sub(i + 36, i + 39) == "VBRI" then
					return be32(buf, i + 50) * perFrame / rate
				end
				return (size - (start + i - 1)) * 8 / (kbps * 1000)
			end
		end
	end
	return nil
end

-- Length in seconds of the song at path, or nil when the header doesn't say.
function Probe.duration(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local size = f:seek("end")
	f:seek("set", 0)
	local magic = f:read(12) or ""
	local ok, d = pcall(function()
		if magic:sub(1, 4) == "RIFF" and magic:sub(9, 12) == "WAVE" then
			return wav(f, size)
		elseif magic:sub(1, 4) == "fLaC" then
			return flac(f)
		elseif magic:sub(1, 4) == "OggS" then
			return ogg(f, size)
		end
		return mp3(f, size)
	end)
	f:close()
	if ok and d and d > 0 and d < 1e6 then
		return d
	end
	return nil
end

return Probe
