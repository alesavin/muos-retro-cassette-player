-- Draws a closed portable cassette player: the cassette seen through the lid
-- window, the transport keys along the top edge and the volume thumbwheel on
-- the side. Everything the player shows comes from these parts.
local ui = require("lib.ui")
local lg = love.graphics

local Walkman = {}
Walkman.__index = Walkman

local C = {
	body = { 0.19, 0.20, 0.22 },
	lid = { 0.23, 0.24, 0.26 },
	print = { 0.62, 0.63, 0.66 },
	key = { 0.80, 0.81, 0.83 },
	keySide = { 0.55, 0.56, 0.58 },
	shell = { 0.17, 0.17, 0.19 },
	bottom = { 0.22, 0.22, 0.24 },
	label = { 0.96, 0.92, 0.82 },
	stripe1 = { 0.95, 0.55, 0.15 },
	stripe2 = { 0.85, 0.24, 0.20 },
	ink = { 0.13, 0.16, 0.38 },
	screw = { 0.62, 0.62, 0.66 },
	tape = { 0.28, 0.18, 0.12 },
}

-- Geometry on the 640x480 canvas.
local BODY = { x = 16, y = 36, w = 608, h = 436 }
local LID = { x = 36, y = 60, w = 568, h = 400 }
local GLASS = { x = 58, y = 84, w = 524, h = 356 }
local SHELL = { x = 70, y = 96, w = 500, h = 316 }
local LABEL = { x = 96, y = 116, w = 448, h = 196 }
local WINDOW = { x = 186, y = 182, w = 268, h = 76 }
local HUB_L, HUB_R, HUB_Y = 230, 410, 220
local R_MIN, R_MAX = 23, 76
local KEYS = { "rew", "stop", "play", "ff" }
local KEY_W, KEY_GAP, KEY_X = 66, 12, 170
local WHEEL = { x = 616, y = 200, w = 18, h = 110 }
local WHEEL_STEP = 0.32 -- radians of wheel per volume notch

-- Tape speed at the pack surface during play, in px/s. Reels turn at speed / radius,
-- so the nearly empty reel spins faster, as on a real cassette.
local PLAY_SPEED = 95

local function setColor(c, a)
	lg.setColor(c[1], c[2], c[3], a or 1)
end

local function packRadius(fraction)
	return math.sqrt(R_MIN ^ 2 + fraction * (R_MAX ^ 2 - R_MIN ^ 2))
end

function Walkman.new(fonts)
	local self = setmetatable({}, Walkman)
	self.fonts = fonts
	self.angleL, self.angleR = 0, 0
	self.shown = 0
	self.volumeShown = 0.8
	self.head = 0 -- 0 = retracted, 1 = against the tape
	self.keyDepth = { rew = 0, stop = 0, play = 0, ff = 0 }
	self.titleClock = 0
	self.lastTitle = nil
	return self
end

local function approach(current, target, rate, dt)
	return current + (target - current) * math.min(1, dt * rate)
end

-- state: { speed, progress, volume, keys = {rew, stop, play, ff}, headEngaged }
function Walkman:update(dt, state)
	self.titleClock = self.titleClock + dt
	-- Ease toward the real position so a new tape or a jump winds visibly.
	self.shown = approach(self.shown, state.progress, 8, dt)
	self.volumeShown = approach(self.volumeShown, state.volume, 14, dt)
	self.head = approach(self.head, state.headEngaged and 1 or 0, 20, dt)
	for _, k in ipairs(KEYS) do
		self.keyDepth[k] = approach(self.keyDepth[k], state.keys[k] and 1 or 0, 30, dt)
	end
	local rl, rr = packRadius(1 - self.shown), packRadius(self.shown)
	-- Tape runs left to right during play, so both reels turn counter-clockwise.
	local v = state.speed * PLAY_SPEED
	self.angleL = (self.angleL - v / rl * dt) % (2 * math.pi)
	self.angleR = (self.angleR - v / rr * dt) % (2 * math.pi)
end

local function drawScrew(x, y)
	setColor(C.screw)
	lg.circle("fill", x, y, 6)
	lg.setColor(0, 0, 0, 0.45)
	lg.setLineWidth(1.5)
	lg.line(x - 4, y - 1, x + 4, y + 1)
	lg.line(x - 1, y - 4, x + 1, y + 4)
end

local function drawPack(x, y, r)
	setColor(C.tape)
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

-- Minute marks printed on the cassette window. The edge of the take-up pack
-- passes each mark at that many minutes into the side.
function Walkman:drawScale(tapeLength)
	if not tapeLength or tapeLength <= 0 then
		return
	end
	local minutes = tapeLength / 60
	local step = 1
	for _, s in ipairs({ 1, 2, 5, 10, 15, 20, 30 }) do
		step = s
		if minutes / s <= 4 then
			break
		end
	end
	lg.setFont(self.fonts.mini)
	lg.setLineWidth(1)
	local m = 0
	while m <= minutes do
		local x = HUB_R - packRadius(m / minutes)
		lg.setColor(1, 1, 1, 0.55)
		lg.line(x, WINDOW.y + 2, x, WINDOW.y + 8)
		lg.printf(tostring(m), x - 10, WINDOW.y + 9, 20, "center")
		m = m + step
	end
end

function Walkman:drawCassette(info)
	local f = self.fonts

	setColor(C.shell)
	lg.rectangle("fill", SHELL.x, SHELL.y, SHELL.w, SHELL.h, 18, 18)
	lg.setColor(1, 1, 1, 0.08)
	lg.setLineWidth(2)
	lg.rectangle("line", SHELL.x + 3, SHELL.y + 3, SHELL.w - 6, SHELL.h - 6, 16, 16)

	-- Label: side letter, song title, artist/album, stripes.
	setColor(C.label)
	lg.rectangle("fill", LABEL.x, LABEL.y, LABEL.w, LABEL.h, 8, 8)
	setColor(C.stripe1)
	lg.rectangle("fill", LABEL.x, LABEL.y + LABEL.h - 46, LABEL.w, 14)
	setColor(C.stripe2)
	lg.rectangle("fill", LABEL.x, LABEL.y + LABEL.h - 32, LABEL.w, 14)
	setColor(C.ink, 0.25)
	lg.setLineWidth(1)
	lg.line(LABEL.x + 60, LABEL.y + 36, LABEL.x + LABEL.w - 14, LABEL.y + 36)
	lg.line(LABEL.x + 60, LABEL.y + 60, LABEL.x + LABEL.w - 14, LABEL.y + 60)
	setColor(C.ink)
	lg.setFont(f.side)
	lg.print("A", LABEL.x + 16, LABEL.y + 6)
	if info.title ~= self.lastTitle then
		self.lastTitle = info.title
		self.titleClock = 0
	end
	ui.marquee(f.title, info.title, LABEL.x + 62, LABEL.y + 12, LABEL.w - 78, self.titleClock)
	lg.setFont(f.small)
	lg.print(ui.ellipsize(f.small, info.subtitle, LABEL.w - 78), LABEL.x + 62, LABEL.y + 42)
	setColor(C.ink, 0.7)
	lg.setFont(f.tiny)
	lg.print("TYPE I  NORMAL BIAS", LABEL.x + 16, LABEL.y + LABEL.h - 15)

	-- Window: packs clipped to the opening, hubs, the printed scale, then glass.
	local rl, rr = packRadius(1 - self.shown), packRadius(self.shown)
	lg.setScissor(WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h)
	lg.setColor(0.06, 0.05, 0.05)
	lg.rectangle("fill", WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h)
	drawPack(HUB_L, HUB_Y, rl)
	drawPack(HUB_R, HUB_Y, rr)
	lg.setScissor()
	drawHub(HUB_L, HUB_Y, self.angleL)
	drawHub(HUB_R, HUB_Y, self.angleR)
	self:drawScale(info.tapeLength)
	lg.setColor(1, 1, 1, 0.07)
	lg.polygon(
		"fill",
		WINDOW.x + 40, WINDOW.y,
		WINDOW.x + 90, WINDOW.y,
		WINDOW.x + 50, WINDOW.y + WINDOW.h,
		WINDOW.x, WINDOW.y + WINDOW.h
	)
	setColor(C.shell)
	lg.setLineWidth(3)
	lg.rectangle("line", WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h, 4, 4)

	-- Lower edge: openings for the head and capstans, tape along the bottom.
	setColor(C.bottom)
	lg.polygon("fill", 176, 412, 196, 332, 444, 332, 464, 412)
	lg.setColor(0.04, 0.04, 0.05)
	lg.circle("fill", 214, 384, 8)
	lg.circle("fill", 426, 384, 8)
	lg.rectangle("fill", 300, 382, 40, 30)
	lg.rectangle("fill", 250, 392, 26, 20)
	lg.rectangle("fill", 364, 392, 26, 20)
	setColor(C.tape)
	lg.rectangle("fill", 190, 405, 260, 4)

	-- Play head: rises into the cassette while the tape is engaged.
	local headTop = 420 - self.head * 22
	lg.setScissor(300, 382, 40, 58)
	lg.setColor(0.72, 0.73, 0.76)
	lg.rectangle("fill", 306, headTop, 28, 30, 3, 3)
	lg.setColor(0.45, 0.46, 0.48)
	lg.rectangle("fill", 316, headTop, 8, 4)
	lg.setScissor()

	drawScrew(SHELL.x + 16, SHELL.y + 16)
	drawScrew(SHELL.x + SHELL.w - 16, SHELL.y + 16)
	drawScrew(SHELL.x + 16, SHELL.y + SHELL.h - 16)
	drawScrew(SHELL.x + SHELL.w - 16, SHELL.y + SHELL.h - 16)
	drawScrew(320, 356)
end

function Walkman:drawKeys()
	for i, k in ipairs(KEYS) do
		local x = KEY_X + (i - 1) * (KEY_W + KEY_GAP)
		local top = 10 + self.keyDepth[k] * 16
		setColor(C.keySide)
		lg.rectangle("fill", x, top, KEY_W, 40, 5, 5)
		setColor(C.key)
		lg.rectangle("fill", x + 2, top, KEY_W - 4, 34, 5, 5)
		lg.setColor(0, 0, 0, 0.12)
		for r = 0, 2 do
			lg.rectangle("fill", x + 10, top + 7 + r * 5, KEY_W - 20, 2)
		end
	end
end

-- Symbols printed on the body under each key.
function Walkman:drawKeyMarks()
	setColor(C.print, 0.8)
	for i, k in ipairs(KEYS) do
		local cx = KEY_X + (i - 1) * (KEY_W + KEY_GAP) + KEY_W / 2
		ui.icon(k, cx - 6, 43, 11)
	end
end

function Walkman:drawWheel()
	local cy = WHEEL.y + WHEEL.h / 2
	local r = WHEEL.h / 2
	-- Slot in the body, then the wheel rim with shading for its curve.
	lg.setColor(0.05, 0.05, 0.06)
	lg.rectangle("fill", WHEEL.x - 4, WHEEL.y - 4, WHEEL.w + 8, WHEEL.h + 8, 4, 4)
	for y = WHEEL.y, WHEEL.y + WHEEL.h - 1, 2 do
		local shade = math.cos(math.asin(math.max(-1, math.min(1, (y + 1 - cy) / r))))
		lg.setColor(0.18 + 0.32 * shade, 0.18 + 0.32 * shade, 0.20 + 0.32 * shade)
		lg.rectangle("fill", WHEEL.x, y, WHEEL.w, 2)
	end
	local phase = self.volumeShown * 10 * WHEEL_STEP
	-- Knurling.
	lg.setLineWidth(1)
	for k = -40, 40 do
		local a = k * 0.12 - phase % 0.12
		if math.abs(a) < 1.45 then
			lg.setColor(0, 0, 0, 0.35 * math.cos(a))
			local y = cy + r * math.sin(a)
			lg.line(WHEEL.x, y, WHEEL.x + 3, y)
			lg.line(WHEEL.x + WHEEL.w - 3, y, WHEEL.x + WHEEL.w, y)
		end
	end
	-- Numbers on the rim; the one level with the index mark is the volume.
	lg.setFont(self.fonts.mini)
	for n = 0, 10 do
		local a = (n - self.volumeShown * 10) * WHEEL_STEP
		if math.abs(a) < 1.35 then
			local s = math.cos(a)
			lg.setColor(0.95, 0.95, 0.92, s)
			local h = self.fonts.mini:getHeight()
			lg.printf(tostring(n), WHEEL.x - 2, cy + r * math.sin(a), WHEEL.w + 4, "center", 0, 1, s, 0, h / 2)
		end
	end
	setColor(C.print, 0.8)
	lg.polygon("fill", WHEEL.x - 12, cy - 4, WHEEL.x - 12, cy + 4, WHEEL.x - 6, cy)
	lg.setFont(self.fonts.mini)
	lg.print("VOL", WHEEL.x - 8, WHEEL.y + WHEEL.h + 10, -math.pi / 2)
end

-- info: { title, subtitle, tapeLength }
function Walkman:draw(info)
	lg.setColor(0.04, 0.04, 0.05)
	lg.rectangle("fill", 0, 0, 640, 480)

	self:drawKeys()

	setColor(C.body)
	lg.rectangle("fill", BODY.x, BODY.y, BODY.w, BODY.h, 30, 30)
	lg.setColor(1, 1, 1, 0.025)
	for y = BODY.y + 4, BODY.y + BODY.h - 4, 3 do
		lg.line(BODY.x + 10, y, BODY.x + BODY.w - 10, y)
	end
	self:drawKeyMarks()
	self:drawWheel()

	-- Lid with its window.
	setColor(C.lid)
	lg.rectangle("fill", LID.x, LID.y, LID.w, LID.h, 20, 20)
	lg.setColor(0, 0, 0, 0.35)
	lg.setLineWidth(2)
	lg.rectangle("line", LID.x, LID.y, LID.w, LID.h, 20, 20)
	lg.setColor(0.03, 0.03, 0.04)
	lg.rectangle("fill", GLASS.x, GLASS.y, GLASS.w, GLASS.h, 14, 14)
	lg.setFont(self.fonts.tiny)
	setColor(C.print, 0.7)
	lg.print("STEREO CASSETTE PLAYER", LID.x + 24, LID.y + 6)

	self:drawCassette(info)

	-- Tinted lid glass and its reflections.
	lg.setColor(0.10, 0.13, 0.18, 0.22)
	lg.rectangle("fill", GLASS.x, GLASS.y, GLASS.w, GLASS.h, 14, 14)
	lg.setColor(1, 1, 1, 0.05)
	lg.polygon("fill", GLASS.x + 300, GLASS.y, GLASS.x + 380, GLASS.y, GLASS.x + 200, GLASS.y + GLASS.h, GLASS.x + 120, GLASS.y + GLASS.h)
	lg.setColor(1, 1, 1, 0.03)
	lg.polygon("fill", GLASS.x + 400, GLASS.y, GLASS.x + 420, GLASS.y, GLASS.x + 240, GLASS.y + GLASS.h, GLASS.x + 220, GLASS.y + GLASS.h)
	lg.setColor(0, 0, 0, 0.5)
	lg.setLineWidth(3)
	lg.rectangle("line", GLASS.x, GLASS.y, GLASS.w, GLASS.h, 14, 14)
end

return Walkman
