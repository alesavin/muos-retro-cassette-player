-- Drives the app with scripted input and saves screenshots to the LÖVE save
-- folder (~/.local/share/love/rc-harness). Run it with scripts/screenshots.sh.
local GAME = os.getenv("GAME")
package.path = GAME .. "/?.lua;" .. package.path
dofile(GAME .. "/main.lua")
local Input = require("lib.input")

local function tap(key)
	Input.keypressed(key)
	Input.keyreleased(key)
end

local function shot(name)
	return function()
		love.graphics.captureScreenshot(name .. ".png")
	end
end

-- Frame number -> step. The music folder is expected to hold one album folder.
-- Keys: z = A, a/s/d/f = L1 (REW) / L2 (STOP) / R2 (PLAY) / R1 (FF).
local steps = {
	[10] = shot("1-library"),
	[12] = function() tap("z") end, -- open the album
	[20] = shot("2-album"),
	[22] = function() tap("z") end, -- insert the tape at the first song; PLAY latches
	[200] = shot("3-playing"),
	[202] = function() Input.keypressed("f") end, -- hold FF: cue
	[260] = shot("4-cue"),
	[262] = function() Input.keyreleased("f") tap("f") end, -- tap FF: music sensor to song 2
	[264] = shot("5-ams"),
	[400] = shot("6-song2"),
	[402] = function() tap("s") end, -- STOP
	[404] = function() tap("down") tap("down") tap("down") end, -- volume down
	[440] = shot("7-stopped"),
	[442] = function() tap("f") end, -- FF while stopped latches
	[460] = shot("8-wind"),
	[600] = shot("9-end"),
	[602] = function() tap("s") end, -- STOP releases FF
	[606] = function() tap("s") end, -- STOP while stopped opens the lid
	[620] = shot("10-ejected"),
	[640] = function() love.event.quit() end,
}

local frame = 0
local update = love.update
love.update = function()
	frame = frame + 1
	if steps[frame] then
		steps[frame]()
	end
	update(1 / 60)
end
