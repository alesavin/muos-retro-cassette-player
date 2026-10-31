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

local Frame = require("lib.frame")
local Fonts = require("lib.fonts")

-- The app's assets aren't in this game's folder, so read the fonts directly.
function Fonts.source(name)
	local f = assert(io.open(GAME .. "/assets/fonts/" .. name .. ".ttf", "rb"))
	local data = f:read("*a")
	f:close()
	return love.filesystem.newFileData(data, name .. ".ttf")
end

local function shot(name)
	return function()
		Frame.invalidate() -- static screens are only drawn on change
		love.graphics.captureScreenshot(name .. ".png")
	end
end

-- Frame number -> step (the loop runs at 30 per second). scripts/screenshots.sh
-- makes nine albums, in this order: After Hours Jazz Club, Backseat Summer,
-- Coastal Drive, Garage Band Demos, Kitchen Radio, Midnight Synth, ...
-- Keys: z = A, x = B, a/s/d/f = L1 (REW) / L2 (STOP) / R2 (PLAY) / R1 (FF).
local steps = {
	[10] = function() tap("down") tap("down") end, -- select Coastal Drive
	[30] = shot("01-library"),
	[32] = function() tap("z") end, -- open it: its songs as tapes
	[34] = function() tap("down") end,
	[50] = shot("02-album"),
	[60] = function() tap("d") end, -- PLAY: tape in, from song 2
	[200] = shot("03-playing"),
	[202] = function() tap("d") end, -- PLAY again: pause
	[230] = shot("04-paused"),
	[232] = function() tap("d") Input.keypressed("f") end, -- resume, hold FF: cue
	[290] = shot("05-cue"),
	[292] = function() Input.keyreleased("f") tap("s") end, -- STOP
	[330] = shot("06-stopped"),
	[332] = function() tap("s") end, -- STOP again: eject to the library
	[360] = shot("07-ejected"),
	[362] = function() tap("s") end, -- L2 in the library: up a folder
	[380] = shot("08-up"),
	[382] = function() tap("down") tap("down") tap("down") end, -- Midnight Synth
	[400] = function() tap("d") end, -- PLAY the whole album
	[540] = shot("09-another-tape"),
	[542] = function() tap("s") tap("s") end, -- stop and eject
	[560] = function() Frame.POCKET_AFTER = 0.5 end,
	[600] = shot("10-pocket"),
	[602] = function() Frame.POCKET_AFTER = 30 tap("z") end, -- wakes the screen only
	[620] = shot("11-woken"),
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
