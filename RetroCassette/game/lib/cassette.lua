-- Draws the cassette and the deck panel below it on a 640x480 canvas.
local ui = require("lib.ui")
local lg = love.graphics

local Cassette = {}
Cassette.__index = Cassette

Cassette.THEMES = {
	{
		name = "Classic",
		shell = { 0.17, 0.17, 0.19 },
		bottom = { 0.22, 0.22, 0.24 },
		label = { 0.96, 0.92, 0.82 },
		stripe1 = { 0.95, 0.55, 0.15 },
		stripe2 = { 0.85, 0.24, 0.20 },
		ink = { 0.13, 0.16, 0.38 },
		screw = { 0.62, 0.62, 0.66 },
		bg = { 0.24, 0.17, 0.13 },
	},
	{
		name = "Chrome",
		shell = { 0.72, 0.74, 0.78 },
		bottom = { 0.64, 0.66, 0.70 },
		label = { 0.12, 0.12, 0.14 },
		stripe1 = { 0.20, 0.75, 0.85 },
		stripe2 = { 0.85, 0.30, 0.65 },
		ink = { 0.92, 0.92, 0.95 },
		screw = { 0.35, 0.35, 0.38 },
		bg = { 0.10, 0.12, 0.20 },
	},
	{
		name = "Beach",
		shell = { 0.93, 0.89, 0.80 },
		bottom = { 0.87, 0.83, 0.73 },
		label = { 0.99, 0.98, 0.95 },
		stripe1 = { 0.98, 0.70, 0.20 },
		stripe2 = { 0.20, 0.55, 0.60 },
		ink = { 0.30, 0.18, 0.12 },
		screw = { 0.55, 0.52, 0.48 },
		bg = { 0.16, 0.33, 0.38 },
	},
	{
		name = "Neon",
		shell = { 0.08, 0.06, 0.12 },
		bottom = { 0.12, 0.09, 0.18 },
		label = { 0.98, 0.30, 0.62 },
		stripe1 = { 0.20, 0.95, 0.90 },
		stripe2 = { 0.98, 0.90, 0.25 },
		ink = { 0.10, 0.04, 0.16 },
		screw = { 0.45, 0.40, 0.55 },
		bg = { 0.05, 0.03, 0.09 },
	},
}

-- Geometry, in canvas pixels.
local SHELL = { x = 70, y = 30, w = 500, h = 316 }
local LABEL = { x = 96, y = 50, w = 448, h = 196 }
local WINDOW = { x = 186, y = 116, w = 268, h = 76 }
local HUB_L, HUB_R, HUB_Y = 230, 410, 154
local R_MIN, R_MAX = 23, 76
-- Tape speed at the pack surface while playing, in px/s. Reels turn at speed / radius,
-- so the nearly empty reel spins faster, like a real cassette.
local PLAY_SPEED = 95

local TAPE = { 0.28, 0.18, 0.12 }

local function packRadius(fraction)
	return math.sqrt(R_MIN ^ 2 + fraction * (R_MAX ^ 2 - R_MIN ^ 2))
end

function Cassette.new(fonts)
	local self = setmetatable({}, Cassette)
	self.fonts = fonts
	self.themeIndex = 1
	self.angleL, self.angleR = 0, 0
	self.shown = 0
	self.clock = 0
	self.titleClock = 0
	self.lastTitle = nil
	return self
end

function Cassette:setTheme(i)
	local n = #Cassette.THEMES
	self.themeIndex = (i - 1) % n + 1
	return self.themeIndex
end

function Cassette:theme()
	return Cassette.THEMES[self.themeIndex]
end

function Cassette:radii()
	return packRadius(1 - self.shown), packRadius(self.shown)
end

function Cassette:update(dt, speed, progress)
	self.clock = self.clock + dt
	self.titleClock = self.titleClock + dt
	-- Ease toward the real position so track changes visibly wind the tape back.
	self.shown = self.shown + (progress - self.shown) * math.min(1, dt * 6)
	local rl, rr = self:radii()
	local v = speed * PLAY_SPEED
	-- Tape runs left to right, so both reels turn counter-clockwise.
	self.angleL = (self.angleL - v / rl * dt) % (2 * math.pi)
	self.angleR = (self.angleR - v / rr * dt) % (2 * math.pi)
end

local function setColor(c, a)
	lg.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

local function drawScrew(x, y, t)
	setColor(t.screw)
	lg.circle("fill", x, y, 6)
	lg.setColor(0, 0, 0, 0.45)
	lg.setLineWidth(1.5)
	lg.line(x - 4, y - 1, x + 4, y + 1)
	lg.line(x - 1, y - 4, x + 1, y + 4)
end

local function drawPack(x, y, r)
	setColor(TAPE)
	lg.circle("fill", x, y, r)
	lg.setLineWidth(1)
	lg.setColor(1, 1, 1, 0.05)
	for ring = R_MIN + 4, r - 2, 5 do
		lg.circle("line", x, y, ring)
	end
	lg.setColor(1, 1, 1, 0.12)
	lg.circle("line", x, y, r)
end

local function drawHub(x, y, angle)
	lg.push()
	lg.translate(x, y)
	lg.rotate(angle)
	lg.setColor(0.93, 0.92, 0.88)
	lg.circle("fill", 0, 0, 20)
	lg.setColor(0.25, 0.25, 0.27)
	for i = 0, 2 do
		local a = i * 2 * math.pi / 3
		lg.circle("fill", math.cos(a) * 15, math.sin(a) * 15, 2.5)
	end
	lg.setColor(0.05, 0.05, 0.06)
	lg.circle("fill", 0, 0, 11)
	lg.setColor(0.93, 0.92, 0.88)
	for i = 0, 5 do
		lg.push()
		lg.rotate(i * math.pi / 3)
		lg.rectangle("fill", 7, -2, 5, 4)
		lg.pop()
	end
	lg.pop()
end

function Cassette:drawShell(info)
	local t = self:theme()
	local f = self.fonts

	-- Shadow and body.
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", SHELL.x + 6, SHELL.y + 8, SHELL.w, SHELL.h, 18, 18)
	setColor(t.shell)
	lg.rectangle("fill", SHELL.x, SHELL.y, SHELL.w, SHELL.h, 18, 18)
	lg.setColor(1, 1, 1, 0.08)
	lg.setLineWidth(2)
	lg.rectangle("line", SHELL.x + 3, SHELL.y + 3, SHELL.w - 6, SHELL.h - 6, 16, 16)

	-- Label with stripes and ruled lines.
	setColor(t.label)
	lg.rectangle("fill", LABEL.x, LABEL.y, LABEL.w, LABEL.h, 8, 8)
	setColor(t.stripe1)
	lg.rectangle("fill", LABEL.x, LABEL.y + LABEL.h - 46, LABEL.w, 14)
	setColor(t.stripe2)
	lg.rectangle("fill", LABEL.x, LABEL.y + LABEL.h - 32, LABEL.w, 14)
	setColor(t.ink, 0.25)
	lg.setLineWidth(1)
	lg.line(LABEL.x + 60, LABEL.y + 36, LABEL.x + LABEL.w - 14, LABEL.y + 36)
	lg.line(LABEL.x + 60, LABEL.y + 60, LABEL.x + LABEL.w - 14, LABEL.y + 60)

	setColor(t.ink)
	lg.setFont(f.side)
	lg.print(info.side or "A", LABEL.x + 16, LABEL.y + 6)
	if info.title ~= self.lastTitle then
		self.lastTitle = info.title
		self.titleClock = 0
	end
	ui.marquee(f.title, info.title or "", LABEL.x + 62, LABEL.y + 12, LABEL.w - 78, self.titleClock)
	lg.setFont(f.small)
	lg.print(ui.ellipsize(f.small, info.subtitle or "", LABEL.w - 78), LABEL.x + 62, LABEL.y + 42)
	setColor(t.ink, 0.7)
	lg.setFont(f.tiny)
	lg.print("C-90   TYPE I  NORMAL BIAS", LABEL.x + 16, LABEL.y + LABEL.h - 15)
	lg.printf(self:theme().name:upper(), LABEL.x, LABEL.y + LABEL.h - 15, LABEL.w - 16, "right")

	-- Window: tape packs clipped to the opening, hubs on top, then glass.
	local rl, rr = self:radii()
	lg.setScissor(WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h)
	lg.setColor(0.06, 0.05, 0.05)
	lg.rectangle("fill", WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h)
	drawPack(HUB_L, HUB_Y, rl)
	drawPack(HUB_R, HUB_Y, rr)
	lg.setScissor()
	drawHub(HUB_L, HUB_Y, self.angleL)
	drawHub(HUB_R, HUB_Y, self.angleR)
	lg.setColor(1, 1, 1, 0.07)
	lg.polygon(
		"fill",
		WINDOW.x + 40, WINDOW.y,
		WINDOW.x + 90, WINDOW.y,
		WINDOW.x + 50, WINDOW.y + WINDOW.h,
		WINDOW.x, WINDOW.y + WINDOW.h
	)
	setColor(t.shell)
	lg.setLineWidth(3)
	lg.rectangle("line", WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h, 4, 4)

	-- Lower part with head openings and the tape running along the bottom edge.
	setColor(t.bottom)
	lg.polygon("fill", 176, 346, 196, 266, 444, 266, 464, 346)
	lg.setColor(0.04, 0.04, 0.05)
	lg.circle("fill", 214, 318, 8)
	lg.circle("fill", 426, 318, 8)
	lg.rectangle("fill", 300, 316, 40, 30)
	lg.rectangle("fill", 250, 326, 26, 20)
	lg.rectangle("fill", 364, 326, 26, 20)
	setColor(TAPE)
	lg.rectangle("fill", 190, 339, 260, 4)

	drawScrew(SHELL.x + 16, SHELL.y + 16, t)
	drawScrew(SHELL.x + SHELL.w - 16, SHELL.y + 16, t)
	drawScrew(SHELL.x + 16, SHELL.y + SHELL.h - 16, t)
	drawScrew(SHELL.x + SHELL.w - 16, SHELL.y + SHELL.h - 16, t)
	drawScrew(320, 290, t)
end

function Cassette:drawDeck(info)
	local f = self.fonts
	local px, py, pw, ph = 20, 358, 600, 112

	lg.setColor(0.09, 0.09, 0.10)
	lg.rectangle("fill", px, py, pw, ph, 10, 10)
	lg.setColor(1, 1, 1, 0.06)
	lg.setLineWidth(1)
	lg.rectangle("line", px + 1, py + 1, pw - 2, ph - 2, 10, 10)

	-- Transport state.
	local led = {
		play = { 0.35, 0.95, 0.45 },
		pause = { 1.0, 0.75, 0.2 },
		stop = { 0.95, 0.3, 0.25 },
		ff = { 0.35, 0.8, 1.0 },
		rew = { 0.35, 0.8, 1.0 },
	}
	local names = { play = "PLAY", pause = "PAUSE", stop = "STOP", ff = "F.FWD", rew = "REWIND" }
	setColor(led[info.transport])
	ui.icon(info.transport, 44, 374, 26)
	lg.setFont(f.tiny)
	lg.print(names[info.transport], 40, 406)

	-- Mechanical-style counter.
	lg.setColor(0.6, 0.6, 0.62)
	lg.print("COUNTER", 112, 368)
	local counter = string.format("%03d", math.floor(info.position * 0.9) % 1000)
	lg.setFont(f.digits)
	for i = 1, 3 do
		local bx = 112 + (i - 1) * 24
		lg.setColor(0.02, 0.02, 0.02)
		lg.rectangle("fill", bx, 384, 22, 30, 3, 3)
		lg.setColor(0.95, 0.95, 0.92)
		lg.printf(counter:sub(i, i), bx, 386, 22, "center")
	end

	-- Time, track and progress.
	lg.setFont(f.medium)
	lg.setColor(0.95, 0.95, 0.92)
	lg.print(ui.fmtTime(info.position) .. " / " .. ui.fmtTime(info.duration), 210, 372)
	lg.setFont(f.tiny)
	lg.setColor(0.6, 0.6, 0.62)
	lg.print(string.format("TRACK %02d / %02d", info.track, info.tracks), 210, 398)
	local frac = info.duration > 0 and math.min(1, info.position / info.duration) or 0
	lg.setColor(0.2, 0.2, 0.22)
	lg.rectangle("fill", 210, 418, 250, 6, 3, 3)
	setColor(self:theme().stripe1)
	lg.rectangle("fill", 210, 418, 250 * frac, 6, 3, 3)

	-- Volume meter and hiss switch.
	lg.setColor(0.6, 0.6, 0.62)
	lg.print("VOL", 490, 368)
	lg.print(info.hiss and "HISS ON" or "HISS OFF", 535, 368)
	local lit = math.floor(info.volume * 10 + 0.5)
	for i = 1, 10 do
		local h = 6 + i * 3
		if i <= lit then
			if i > 8 then
				lg.setColor(0.95, 0.3, 0.25)
			else
				lg.setColor(0.35, 0.95, 0.45)
			end
		else
			lg.setColor(0.2, 0.2, 0.22)
		end
		lg.rectangle("fill", 490 + (i - 1) * 11, 424 - h, 8, h)
	end

	lg.setFont(f.tiny)
	lg.setColor(0.55, 0.55, 0.58)
	lg.printf("A play/pause   < > track   L/R wind   B library   X hiss   Y shell", px, 446, pw, "center")
end

function Cassette:draw(info)
	setColor(self:theme().bg)
	lg.rectangle("fill", 0, 0, 640, 480)
	self:drawShell(info)
	self:drawDeck(info)
	if info.error then
		lg.setFont(self.fonts.small)
		lg.setColor(0.95, 0.3, 0.25)
		lg.printf(info.error, 0, 6, 640, "center")
	end
end

return Cassette
