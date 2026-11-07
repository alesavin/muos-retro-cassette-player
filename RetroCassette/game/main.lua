local Battery = require("lib.battery")
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

-- Buttons for the player's keys. L2 (EJECT) and B don't reach the deck: they
-- switch between the player and the library, and the tape keeps playing.
local KEY_FOR_ACTION = { l1 = "rew", r2 = "play", r1 = "ff", a = "play" }

local screen = "library" -- library | deck
local deck, browser, library, walkman
local nowPlaying -- path of the song at the tape's current position, or nil

local function clunk()
	Sfx.clunk(0.5)
end

local function insertTape(paths, index)
	if not paths then
		return
	end
	Loader.clear() -- the old tape's read-ahead isn't needed any more
	local tape = Tape.new(paths)
	deck:insert(tape, tape.tracks[index].start)
	Durations.probe(tape)
	deck:press("play")
	screen = "deck"
	Settings.values.lastDir = browser.path or ""
	Settings.save()
end

-- Back to the player, the tape as it was.
local function toPlayer()
	clunk()
	screen = "deck"
end

-- R2 / A in the library: puts the chosen tape in and plays it. Choosing the
-- tape that's already in (its album, or the song playing now) only goes back
-- to the player, unless that tape has run to its end.
local function playChosen()
	local e = browser.entries[browser.sel]
	local paths, index = browser:playSelection()
	if not paths then
		return
	end
	local tape = deck.tape
	local over = tape and deck.mode == "stop" and deck.t >= tape.length
	if tape and not over and tape:hasPaths(paths) and (e.kind == "dir" or deck:currentTrack() == tape.tracks[index]) then
		toPlayer()
	else
		insertTape(paths, index)
	end
end

-- The library uses the player's keys: L1/R1 jump a letter among albums (a pile
-- of tapes among songs), R2 (PLAY) or A puts the tape in, D-pad right opens an
-- album to show its songs and D-pad left goes back up. L2 (EJECT) or B goes
-- back to the player while a tape is in it, otherwise back up too.
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
		playChosen()
	elseif (action == "l2" or action == "b") and deck.tape then
		toPlayer()
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
	local stop = deck.tape and down("l2", "b") or down("l2", "b", "left")
	return { rew = down("l1"), stop = stop, play = down("r2", "a"), ff = down("r1") }
end

local function deckAction(action)
	if action == "left" or action == "right" then
		deck:skip(action == "right" and 1 or -1)
		return
	end
	if action == "l2" or action == "b" then
		-- EJECT: to the library; the tape plays on.
		deck:letGo()
		clunk()
		screen = "library"
		return
	end
	local key = KEY_FOR_ACTION[action]
	if key then
		deck:press(key)
	end
end

local function onAction(action, isRepeat)
	Frame.invalidate()
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
	Battery.find()

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
end

function love.update(dt)
	Input.update(dt)
	if Durations.update(deck.tape) then
		Frame.invalidate() -- the tape's length changed: redraw the window scale
	end
	Loader.update()
	if Battery.update(love.timer.getTime()) then
		Frame.invalidate() -- the charge changed: redraw the battery line
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
	-- The library marks the song playing, so it changes when the tape moves on.
	local track = deck:currentTrack()
	local playing = track and track.path or nil
	if playing ~= nowPlaying then
		nowPlaying = playing
		Frame.invalidate()
	end
	Frame.update(moving)
end

function love.draw()
	Scaler.begin()
	if screen == "deck" then
		local track = deck:currentTrack()
		walkman:draw({
			title = track and LibraryView.songTitle(track.path) or "",
			subtitle = track and ui.safe(fs.basename(fs.parent(track.path))) or "",
			tapeLength = deck.tape and deck.tape.length,
			position = deck.t,
			style = LibraryView.tapeStyle(track and track.path or ""),
		})
	else
		library:draw(browser, nowPlaying)
	end
	Scaler.finish()
end

-- LÖVE's standard loop, paced by lib/frame.lua: sleeps out each period, redraws
-- when something changed or moves, and otherwise re-shows the last frame.
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
		local frame = love.graphics.isActive() and Frame.next(love.timer.getTime())
		if frame then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
			if frame == "draw" then
				love.draw()
			else
				Scaler.finish() -- the last frame again, without redrawing the scene
			end
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
