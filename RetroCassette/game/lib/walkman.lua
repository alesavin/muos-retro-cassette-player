-- Draws the cassette as seen through the tinted lid of a closed player. The
-- handheld's own screen bezel is the player body, so only the parts that matter
-- are drawn: the cassette filling the screen and the transport keys (lib/keys.lua)
-- along the bottom edge above the real shoulder buttons. The cassette is drawn
-- in its tape's style, matching its library spine.
local Fonts = require("lib.fonts")
local Keys = require("lib.keys")
local TapeArt = require("lib.tapeart")
local ui = require("lib.ui")
local lg = love.graphics

local Walkman = {}
Walkman.__index = Walkman

local C = {
	interior = { 0.05, 0.05, 0.06 },
	key = { 0.80, 0.81, 0.83 },
	keySide = { 0.55, 0.56, 0.58 },
	keyMark = { 0.35, 0.36, 0.38 },
	tape = { 0.28, 0.18, 0.12 },
}

Walkman.WIDTH, Walkman.HEIGHT = 720, 480

-- Other buttons that do what each key does, shown as badges on the key. The
-- D-pad skips straight to the previous / next song, as a tap on REW / FF does
-- by winding there.
Walkman.TWINS = { rew = { "‹" }, stop = { "B" }, play = { "A" }, ff = { "›" } }

-- The cassette is drawn in its own 500x316 coordinates (origin at SHELL) and
-- scaled up to fill the screen: centred, and as large as its height allows
-- above the keys (a cassette is narrower for its height than the screen).
Walkman.CASSETTE_SCALE = 1.37
local DPI = Walkman.CASSETTE_SCALE
local CASSETTE_X, CASSETTE_Y = 17, 5
local SHELL = { x = 70, y = 96, w = 500, h = 316 }
local LABEL = { x = 96, y = 116, w = 448, h = 196 }
local WINDOW = { x = 186, y = 182, w = 268, h = 76 }
local HUB_L, HUB_R, HUB_Y = 230, 410, 220
local R_MIN, R_MAX = 23, 76

-- Tape speed at the pack surface during play, in px/s. Reels turn at speed / radius,
-- so the nearly empty reel spins faster, as on a real cassette.
local PLAY_SPEED = 95

local setColor = TapeArt.setColor

local function packRadius(fraction)
	return math.sqrt(R_MIN ^ 2 + fraction * (R_MAX ^ 2 - R_MIN ^ 2))
end

function Walkman.new()
	local self = setmetatable({}, Walkman)
	self.angleL, self.angleR = 0, 0
	self.shown = 0
	self.head = 0 -- 0 = retracted, 1 = against the tape
	self.keyDepth = {}
	for _, k in ipairs(Keys.LAYOUT) do
		self.keyDepth[k.name] = 0
	end
	self.moving = false
	return self
end

-- Eases current toward target; also reports whether it is still moving.
local function approach(current, target, rate, dt)
	local v = current + (target - current) * math.min(1, dt * rate)
	if math.abs(target - v) < 0.002 then
		return target, false
	end
	return v, true
end

-- state: { speed, progress, keys = {rew, stop, play, ff} (0..1), head (0..1) }
function Walkman:update(dt, state)
	local m1, m2, m
	-- Ease toward the real position so a new tape or a jump winds visibly.
	self.shown, m1 = approach(self.shown, state.progress, 8, dt)
	self.head, m2 = approach(self.head, state.head, 20, dt)
	local moving = m1 or m2 or state.speed ~= 0
	for _, k in ipairs(Keys.LAYOUT) do
		self.keyDepth[k.name], m = approach(self.keyDepth[k.name], state.keys[k.name] or 0, 30, dt)
		moving = moving or m
	end
	self.moving = moving
	local rl, rr = packRadius(1 - self.shown), packRadius(self.shown)
	-- Tape runs left to right during play, so both reels turn counter-clockwise.
	local v = state.speed * PLAY_SPEED
	self.angleL = (self.angleL - v / rl * dt) % (2 * math.pi)
	self.angleR = (self.angleR - v / rr * dt) % (2 * math.pi)
end

-- True while anything on screen still moves (reels, keys, head, tape packs).
function Walkman:isMoving()
	return self.moving
end

local function drawScrew(st, x, y)
	if st.shell.light then
		lg.setColor(0.45, 0.45, 0.48)
	else
		lg.setColor(0.62, 0.62, 0.66)
	end
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
local function drawScale(tapeLength)
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
	lg.setFont(Fonts.get("print", 9, DPI))
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

-- Prints text in the style's font and ink, shrunk to fit w and cut short if
-- still too long; handwriting sits at the style's tilt.
local function writeOnLabel(st, text, x, y, w, size)
	local f = Fonts.fit(st.font, text, w, size, DPI)
	lg.setFont(f)
	setColor(st.ink)
	lg.push()
	lg.translate(x, y + (size - f:getHeight()) / 2)
	lg.rotate(st.tilt)
	lg.print(ui.ellipsize(f, text, w), 0, 0)
	lg.pop()
end

function Walkman:drawCassette(info)
	local st = info.style

	TapeArt.shell(st)
	lg.rectangle("fill", SHELL.x, SHELL.y, SHELL.w, SHELL.h, 18, 18)
	TapeArt.ribs(st, SHELL.x, SHELL.y, SHELL.w, SHELL.h, 14)
	TapeArt.onShell(st, 0.10)
	lg.setLineWidth(2)
	lg.rectangle("line", SHELL.x + 3, SHELL.y + 3, SHELL.w - 6, SHELL.h - 6, 16, 16)

	-- Label: side letter, song title, album, stripes.
	setColor(st.paper)
	lg.rectangle("fill", LABEL.x, LABEL.y, LABEL.w, LABEL.h, 8, 8)
	TapeArt.stripes(st, LABEL.x, LABEL.y + LABEL.h - 46, LABEL.w, 28)
	setColor(st.ink, 0.25)
	lg.setLineWidth(1)
	lg.line(LABEL.x + 60, LABEL.y + 38, LABEL.x + LABEL.w - 14, LABEL.y + 38)
	lg.line(LABEL.x + 60, LABEL.y + 62, LABEL.x + LABEL.w - 14, LABEL.y + 62)
	setColor(st.ink)
	lg.setFont(Fonts.get("print", 40, DPI))
	lg.print("A", LABEL.x + 18, LABEL.y + 2)
	writeOnLabel(st, info.title, LABEL.x + 62, LABEL.y + 8, LABEL.w - 78, 26)
	writeOnLabel(st, info.subtitle, LABEL.x + 62, LABEL.y + 41, LABEL.w - 78, 17)
	setColor(st.ink, 0.7)
	lg.setFont(Fonts.get("print", 11, DPI))
	lg.print("TYPE I  NORMAL BIAS", LABEL.x + 16, LABEL.y + LABEL.h - 16)

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
	drawScale(info.tapeLength)
	lg.setColor(1, 1, 1, 0.07)
	lg.polygon(
		"fill",
		WINDOW.x + 40, WINDOW.y,
		WINDOW.x + 90, WINDOW.y,
		WINDOW.x + 50, WINDOW.y + WINDOW.h,
		WINDOW.x, WINDOW.y + WINDOW.h
	)
	TapeArt.shell(st)
	lg.setLineWidth(3)
	lg.rectangle("line", WINDOW.x, WINDOW.y, WINDOW.w, WINDOW.h, 4, 4)

	-- Lower edge: openings for the head and capstans, tape along the bottom.
	TapeArt.shell(st)
	lg.polygon("fill", 176, 412, 196, 332, 444, 332, 464, 412)
	TapeArt.onShell(st, 0.08)
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

	drawScrew(st, SHELL.x + 16, SHELL.y + 16)
	drawScrew(st, SHELL.x + SHELL.w - 16, SHELL.y + 16)
	drawScrew(st, SHELL.x + 16, SHELL.y + SHELL.h - 16)
	drawScrew(st, SHELL.x + SHELL.w - 16, SHELL.y + SHELL.h - 16)
	drawScrew(st, 320, 356)
end

-- info: { title, subtitle, tapeLength, style }
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

	Keys.draw(self.keyDepth, Walkman.TWINS)
end

return Walkman
