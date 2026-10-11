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
local steps = {
	[10] = shot("1-browser"),
	[12] = function() tap("z") end, -- open the album
	[20] = shot("2-folder"),
	[22] = function() tap("z") end, -- play the first track
	[200] = shot("3-deck"),
	[202] = function() Input.keypressed("s") end, -- hold fast-forward
	[300] = shot("4-ff"),
	[302] = function() Input.keyreleased("s") tap("v") end, -- next shell
	[330] = shot("5-chrome"),
	[332] = function() tap("v") tap("v") end,
	[360] = shot("6-neon"),
	[362] = function() tap("v") end, -- back to the first shell
	[400] = function() love.event.quit() end,
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
