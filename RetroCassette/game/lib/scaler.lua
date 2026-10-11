-- Draws everything at a fixed virtual size and scales it to the screen with
-- letterboxing, so 640x480, 720x720 and 1024x768 screens all work.
local Scaler = {}

function Scaler.init(width, height)
	Scaler.width, Scaler.height = width, height
	Scaler.canvas = love.graphics.newCanvas(width, height)
	Scaler.canvas:setFilter("linear", "linear")
end

function Scaler.begin()
	love.graphics.setCanvas(Scaler.canvas)
	love.graphics.clear(0, 0, 0, 1)
end

function Scaler.finish()
	love.graphics.setCanvas()
	local sw, sh = love.graphics.getDimensions()
	local scale = math.min(sw / Scaler.width, sh / Scaler.height)
	local x = math.floor((sw - Scaler.width * scale) / 2)
	local y = math.floor((sh - Scaler.height * scale) / 2)
	love.graphics.clear(0, 0, 0, 1)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(Scaler.canvas, x, y, 0, scale, scale)
end

return Scaler
