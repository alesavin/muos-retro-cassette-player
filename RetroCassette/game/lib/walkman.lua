-- Draws the cassette as seen through the tinted lid of a closed player. The
-- handheld's own screen bezel is the player body, so only the parts that matter
-- are drawn: the cassette filling the screen, the transport keys along the
-- bottom edge above the real shoulder buttons (L1 L2 ... R2 R1 on the RG34XXSP
-- hinge) and the volume wheel on the left edge, next to the volume buttons.
local ui = require("lib.ui")
local lg = love.graphics

local Walkman = {}
Walkman.__index = Walkman

local C = {
	interior = { 0.05, 0.05, 0.06 },
	key = { 0.80, 0.81, 0.83 },
	keySide = { 0.55, 0.56, 0.58 },
	keyMark = { 0.35, 0.36, 0.38 },
	shell = { 0.17, 0.17, 0.19 },
	bottom = { 0.22, 0.22, 0.24 },
	label = { 0.96, 0.92, 0.82 },
	stripe1 = { 0.95, 0.55, 0.15 },
	stripe2 = { 0.85, 0.24, 0.20 },
	ink = { 0.13, 0.16, 0.38 },
	screw = { 0.62, 0.62, 0.66 },
	tape = { 0.28, 0.18, 0.12 },
}

Walkman.WIDTH, Walkman.HEIGHT = 720, 480

-- The cassette is drawn in its own 500x316 coordinates (origin at SHELL) and
-- scaled up to fill the screen.
Walkman.CASSETTE_SCALE = 1.3
local CASSETTE_X, CASSETTE_Y = 48, 8
local SHELL = { x = 70, y = 96, w = 500, h = 316 }
local LABEL = { x = 96, y = 116, w = 448, h = 196 }
local WINDOW = { x = 186, y = 182, w = 268, h = 76 }
local HUB_L, HUB_R, HUB_Y = 230, 410, 220
local R_MIN, R_MAX = 23, 76

-- Keys in screen coordinates, left to right as the shoulder buttons sit.
local KEYS = {
	{ name = "rew", x = 14 },
	{ name = "stop", x = 112 },
	{ name = "play", x = 518 },
	{ name = "ff", x = 616 },
}
local KEY_W, KEY_TOP, KEY_TRAVEL = 90, 444, 16
local WHEEL = { x = 0, y = 210, w = 22, h = 180 }
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
	self.keyDepth = {}
	for _, k in ipairs(KEYS) do
		self.keyDepth[k.name] = 0
	end
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
		self.keyDepth[k.name] = approach(self.keyDepth[k.name], state.keys[k.name] and 1 or 0, 30, dt)
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
	lg.setFont(self.fonts.cassette.mini)
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
	local f = self.fonts.cassette

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
	ui.clip(WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h)
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
	ui.clip(300, 382, 40, 40)
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

-- Keys stand up from the bottom edge and sink toward the hinge when pressed.
function Walkman:drawKeys()
	for _, k in ipairs(KEYS) do
		local top = KEY_TOP + self.keyDepth[k.name] * KEY_TRAVEL
		setColor(C.keySide)
		lg.rectangle("fill", k.x, top, KEY_W, 60, 6, 6)
		setColor(C.key)
		lg.rectangle("fill", k.x + 2, top, KEY_W - 4, 54, 6, 6)
		setColor(C.keyMark)
		local cx = k.x + KEY_W / 2
		if k.name == "stop" then
			-- STOP/EJECT: pressed again while stopped, it opens the lid.
			ui.icon("stop", cx - 17, top + 9, 12)
			ui.icon("eject", cx + 5, top + 9, 12)
		else
			ui.icon(k.name, cx - 7, top + 9, 13)
		end
	end
end

function Walkman:drawWheel()
	local cy = WHEEL.y + WHEEL.h / 2
	local r = WHEEL.h / 2
	-- Rim of the wheel, shaded for its curve.
	lg.setColor(0.02, 0.02, 0.03)
	lg.rectangle("fill", WHEEL.x, WHEEL.y - 4, WHEEL.w + 4, WHEEL.h + 8, 4, 4)
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
			lg.line(WHEEL.x + WHEEL.w - 4, y, WHEEL.x + WHEEL.w, y)
		end
	end
	-- Numbers on the rim; the one level with the index mark is the volume.
	local font = self.fonts.wheel
	lg.setFont(font)
	for n = 0, 10 do
		local a = (n - self.volumeShown * 10) * WHEEL_STEP
		if math.abs(a) < 1.35 then
			local s = math.cos(a)
			lg.setColor(0.95, 0.95, 0.92, s)
			lg.printf(tostring(n), WHEEL.x, cy + r * math.sin(a), WHEEL.w - 2, "center", 0, 1, s, 0, font:getHeight() / 2)
		end
	end
	lg.setColor(0.95, 0.95, 0.92, 0.8)
	lg.polygon("fill", WHEEL.x + WHEEL.w + 10, cy - 5, WHEEL.x + WHEEL.w + 10, cy + 5, WHEEL.x + WHEEL.w + 4, cy)
end

-- info: { title, subtitle, tapeLength }
function Walkman:draw(info)
	local W, H = Walkman.WIDTH, Walkman.HEIGHT
	setColor(C.interior)
	lg.rectangle("fill", 0, 0, W, H)

	lg.push()
	lg.translate(CASSETTE_X, CASSETTE_Y)
	lg.scale(Walkman.CASSETTE_SCALE)
	lg.translate(-SHELL.x, -SHELL.y)
	self:drawCassette(info)
	lg.pop()

	-- Tinted lid glass over the whole screen, with two reflections.
	lg.setColor(0.10, 0.13, 0.18, 0.22)
	lg.rectangle("fill", 0, 0, W, H)
	lg.setColor(1, 1, 1, 0.05)
	lg.polygon("fill", 430, 0, 530, 0, 300, H, 200, H)
	lg.setColor(1, 1, 1, 0.03)
	lg.polygon("fill", 560, 0, 585, 0, 355, H, 330, H)

	self:drawWheel()
	self:drawKeys()
end

return Walkman
