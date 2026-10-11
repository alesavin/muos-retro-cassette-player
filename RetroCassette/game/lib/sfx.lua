-- Generated tape sounds: background hiss, the whir while winding, and the
-- clunk of a transport button.
local Sfx = {}

local RATE = 22050

local function hissData(seconds)
	local n = math.floor(seconds * RATE)
	local sd = love.sound.newSoundData(n, RATE, 16, 1)
	local b0, b1, b2 = 0, 0, 0
	for i = 0, n - 1 do
		local white = love.math.random() * 2 - 1
		-- Cheap pink-noise filter: tape hiss is softer in the highs than white noise.
		b0 = 0.99765 * b0 + white * 0.0990460
		b1 = 0.96300 * b1 + white * 0.2965164
		b2 = 0.57000 * b2 + white * 1.0526913
		local s = (b0 + b1 + b2 + white * 0.1848) * 0.15
		sd:setSample(i, math.max(-1, math.min(1, s)))
	end
	return sd
end

local function clunkData()
	local n = math.floor(0.09 * RATE)
	local sd = love.sound.newSoundData(n, RATE, 16, 1)
	for i = 0, n - 1 do
		local t = i / RATE
		local s = (math.sin(2 * math.pi * 95 * t) * 0.8 + (love.math.random() * 2 - 1) * 0.35) * math.exp(-t * 45)
		sd:setSample(i, s * 0.6)
	end
	return sd
end

function Sfx.init()
	Sfx.hiss = love.audio.newSource(hissData(2), "static")
	Sfx.hiss:setLooping(true)
	Sfx.clunkSource = love.audio.newSource(clunkData(), "static")
end

function Sfx.clunk(volume)
	Sfx.clunkSource:stop()
	Sfx.clunkSource:setVolume(volume)
	Sfx.clunkSource:play()
end

function Sfx.update(player, hissEnabled)
	local vol, pitch = 0, 1
	if player.wind ~= 0 then
		vol, pitch = 0.18, 1.8
	elseif hissEnabled and player.state == "playing" then
		vol = 0.035
	end
	vol = vol * player.volume
	if vol > 0 then
		Sfx.hiss:setVolume(vol)
		Sfx.hiss:setPitch(pitch)
		if not Sfx.hiss:isPlaying() then
			Sfx.hiss:play()
		end
	elseif Sfx.hiss:isPlaying() then
		Sfx.hiss:pause()
	end
end

return Sfx
