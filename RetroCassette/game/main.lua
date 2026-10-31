local Browser = require("lib.browser")
local Deck = require("lib.deck")
local Durations = require("lib.durations")
local Frame = require("lib.frame")
local Input = require("lib.input")
local LibraryView = require("lib.library_view")
local Loader = require("lib.loader")
local Scaler = require("lib.scaler")
local Settings = require("lib.settings")
local Sfx = require("lib.sfx")
local Tape = require("lib.tape")
local Walkman = require("lib.walkman")
local fs = require("lib.fs")
local ui = require("lib.ui")

-- Shoulder buttons in the order the keys sit on the player.
local KEY_FOR_ACTION = { l1 = "rew", l2 = "stop", r2 = "play", r1 = "ff", a = "play", b = "stop" }

local screen = "library" -- library | deck
local deck, browser, library, walkman

local function clunk()
	Sfx.clunk(0.5)
end

local function insertTape(paths, index)
	if not paths then
		return
	end
	local tape = Tape.new(paths)
	deck:insert(tape, tape.tracks[index].start)
	Durations.probe(tape)
	deck:press("play")
	screen = "deck"
	Settings.values.lastDir = browser.path or ""
	Settings.save()
end

-- The library uses the player's keys: L1/R1 jump a letter among albums (a pile
-- of tapes among songs), R2 (PLAY)
-- or A puts the tape in, L2 (STOP), B or D-pad left goes back up, D-pad right
-- opens an album to show its songs.
local function libraryAction(action, isRepeat)
	if action == "up" then
		browser:move(-1, not isRepeat)
	elseif action == "down" then
		browser:move(1, not isRepeat)
	elseif isRepeat then
		return
	elseif action == "l1" then
		browser:flip(-1)
	elseif action == "r1" then
		browser:flip(1)
	elseif action == "right" then
		browser:openSelection()
	elseif action == "r2" or action == "a" then
		insertTape(browser:playSelection())
	elseif action == "l2" or action == "b" or action == "left" then
		browser:back()
	end
end

-- How far each library key is pressed: a key also goes down for its twin.
local function libraryKeys()
	local function down(...)
		for _, a in ipairs({ ... }) do
			if Input.isDown(a) then
				return 1
			end
		end
		return 0
	end
	return { rew = down("l1"), stop = down("l2", "b", "left"), play = down("r2", "a"), ff = down("r1") }
end

local function deckAction(action)
	if action == "left" or action == "right" then
		deck:skip(action == "right" and 1 or -1)
		return
	end
	local key = KEY_FOR_ACTION[action]
	if key and deck:press(key) == "eject" then
		deck:eject()
		clunk()
		screen = "library"
	end
end

local function onAction(action, isRepeat)
	if Frame.input(love.timer.getTime()) then
		return -- the press only woke the screen
	end
	if action == "quit" then
		love.event.quit()
	elseif screen == "library" then
		libraryAction(action, isRepeat)
	elseif not isRepeat then
		deckAction(action)
	end
end

local function onRelease(action)
	local key = KEY_FOR_ACTION[action]
	if screen == "deck" and key then
		deck:release(key)
	end
	Frame.invalidate()
end

function love.load()
	love.mouse.setVisible(false)
	Settings.load()
	Scaler.init(Walkman.WIDTH, Walkman.HEIGHT)
	Sfx.init()
	Durations.init()
	Loader.init()

	deck = Deck.new({ onClunk = clunk })
	deck:setVolume(1) -- the device's volume buttons set the level
	walkman = Walkman.new()
	library = LibraryView.new()

	browser = Browser.new(fs.musicRoots())
	local last = Settings.values.lastDir
	if last ~= "" and fs.isDir(last) then
		browser:open(last)
	else
		browser:openRoots()
	end

	Input.onAction = onAction
	Input.onRelease = onRelease
	Frame.lastInput = love.timer.getTime()
end

function love.update(dt)
	Input.update(dt)
	if Durations.update(deck.tape) then
		Frame.invalidate() -- the tape's length changed: redraw the window scale
	end
	deck:update(dt)
	local keys = deck:keysDown()
	keys.stop = (Input.isDown("l2") or Input.isDown("b")) and 1 or 0
	walkman:update(dt, {
		speed = deck:tapeSpeed(),
		progress = deck:progress(),
		keys = keys,
		head = deck:headPosition(),
	})
	library:update(dt, browser, libraryKeys())
	Sfx.update(deck)
	local moving = screen == "deck" and walkman:isMoving() or screen == "library" and library:isMoving()
	Frame.update(love.timer.getTime(), moving)
end

function love.draw()
	Scaler.begin()
	if Frame.dark then
		-- Pocket mode: nothing on screen until a button is pressed.
		love.graphics.clear(0, 0, 0, 1)
	elseif screen == "deck" then
		local track = deck:currentTrack()
		walkman:draw({
			title = track and LibraryView.songTitle(track.path) or "",
			subtitle = track and ui.safe(fs.basename(fs.parent(track.path))) or "",
			tapeLength = deck.tape and deck.tape.length,
			style = LibraryView.tapeStyle(track and track.path or ""),
		})
	else
		library:draw(browser)
	end
	Scaler.finish()
end

-- LÖVE's standard loop, paced by lib/frame.lua: sleeps out each period and
-- only redraws when something changed or moves.
function love.run()
	love.load(love.arg.parseGameArguments(arg), arg)
	love.timer.step()
	return function()
		local start = love.timer.getTime()
		love.event.pump()
		for name, a, b, c, d, e, f in love.event.poll() do
			if name == "quit" and not (love.quit and love.quit()) then
				return a or 0
			end
			love.handlers[name](a, b, c, d, e, f)
		end
		love.update(love.timer.step())
		if love.graphics.isActive() and Frame.shouldDraw() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.draw()
			love.graphics.present()
		end
		local rest = Frame.period() - (love.timer.getTime() - start)
		love.timer.sleep(rest > 0.001 and rest or 0.001)
	end
end

function love.keypressed(key, _, isRepeat)
	if not isRepeat then
		Input.keypressed(key)
	end
end

function love.keyreleased(key)
	Input.keyreleased(key)
end

function love.gamepadpressed(_, button)
	Input.gamepadpressed(button)
end

function love.gamepadreleased(_, button)
	Input.gamepadreleased(button)
end

function love.gamepadaxis(_, axis, value)
	Input.gamepadaxis(axis, value)
end

function love.resize()
	Frame.invalidate()
end
