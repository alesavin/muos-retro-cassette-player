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

-- Frame number -> step (the loop runs at 30 per second). The music folder holds
-- albums in this order: Kind of Blue, Road Trip '86, Synthwave Mixtape, then four more.
-- Keys: z = A, x = B, a/s/d/f = L1 (REW) / L2 (STOP) / R2 (PLAY) / R1 (FF).
local steps = {
	[10] = function() tap("down") tap("down") end, -- select Synthwave Mixtape
	[30] = shot("1-library"),
	[32] = function() tap("z") end, -- open it: its songs as tapes
	[50] = shot("2-album"),
	[52] = function() tap("down") end,
	[60] = function() tap("d") end, -- PLAY: tape in, from song 2
	[200] = shot("3-playing"),
	[202] = function() tap("d") end, -- PLAY again: pause
	[230] = shot("4-paused"),
	[232] = function() tap("d") Input.keypressed("f") end, -- resume, hold FF: cue
	[290] = shot("5-cue"),
	[292] = function() Input.keyreleased("f") tap("s") end, -- STOP
	[330] = shot("6-stopped"),
	[332] = function() tap("s") end, -- STOP again: eject to the library
	[360] = shot("7-ejected"),
	[362] = function() tap("s") end, -- L2 in the library: up a folder
	[380] = shot("8-up"),
	[382] = function() Frame.POCKET_AFTER = 0.5 end,
	[420] = shot("9-pocket"),
	[422] = function() Frame.POCKET_AFTER = 30 tap("z") end, -- wakes the screen only
	[440] = shot("10-woken"),
	[460] = function() love.event.quit() end,
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
