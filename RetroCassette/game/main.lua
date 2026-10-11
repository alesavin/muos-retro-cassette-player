local Browser = require("lib.browser")
local BrowserView = require("lib.browser_view")
local Deck = require("lib.deck")
local Durations = require("lib.durations")
local Input = require("lib.input")
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
local fonts, deck, browser, walkman

local function loadFonts()
	-- The cassette is drawn scaled up, so its fonts are rasterised at that scale.
	local dpi = Walkman.CASSETTE_SCALE
	-- Drop a TTF at assets/label.ttf for a handwritten-style cassette label.
	local labelFont = love.filesystem.getInfo("assets/label.ttf") and "assets/label.ttf"
	local function labelSized(size)
		if labelFont then
			return love.graphics.newFont(labelFont, size, "normal", dpi)
		end
		return love.graphics.newFont(size, "normal", dpi)
	end
	return {
		cassette = {
			title = labelSized(22),
			side = labelSized(40),
			small = love.graphics.newFont(15, "normal", dpi),
			tiny = love.graphics.newFont(12, "normal", dpi),
			mini = love.graphics.newFont(9, "normal", dpi),
		},
		medium = love.graphics.newFont(20),
		small = love.graphics.newFont(15),
		wheel = love.graphics.newFont(11),
	}
end

-- "03 - Song Name.mp3" -> "Song Name"
local function songTitle(path)
	local stem = fs.stem(fs.basename(path))
	local stripped = stem:match("^%d+[%s%.%-_]+(.+)$")
	return ui.safe(stripped or stem)
end

local function clunk()
	Sfx.clunk(0.5 * deck.volume)
end

local function insertTape(paths, index)
	local tape = Tape.new(paths)
	deck:insert(tape, tape.tracks[index].start)
	Durations.probe(tape)
	deck:press("play")
	screen = "deck"
end

local function libraryAction(action, isRepeat)
	if action == "up" then
		browser:move(-1, not isRepeat)
	elseif action == "down" then
		browser:move(1, not isRepeat)
	elseif action == "left" then
		browser:move(-Browser.ROWS, false)
	elseif action == "right" then
		browser:move(Browser.ROWS, false)
	elseif action == "a" and not isRepeat then
		local paths, index = browser:activate()
		if paths then
			insertTape(paths, index)
			Settings.values.lastDir = browser.path or ""
			Settings.save()
		end
	elseif action == "b" then
		browser:back()
	end
end

local function deckAction(action)
	if action == "up" or action == "down" then
		deck:setVolume(deck.volume + (action == "up" and 0.1 or -0.1))
		Settings.values.volume = deck.volume
		Settings.save()
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
	if action == "quit" then
		love.event.quit()
	elseif screen == "library" then
		libraryAction(action, isRepeat)
	elseif not isRepeat or action == "up" or action == "down" then
		deckAction(action)
	end
end

local function onRelease(action)
	local key = KEY_FOR_ACTION[action]
	if screen == "deck" and key then
		deck:release(key)
	end
end

function love.load()
	love.mouse.setVisible(false)
	Settings.load()
	Scaler.init(Walkman.WIDTH, Walkman.HEIGHT)
	fonts = loadFonts()
	Sfx.init()
	Durations.init()

	deck = Deck.new({ onClunk = clunk })
	deck:setVolume(Settings.values.volume)
	walkman = Walkman.new(fonts)

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
	Durations.update(deck.tape)
	deck:update(dt)
	local keys = deck:keysDown()
	keys.stop = Input.isDown("l2") or Input.isDown("b")
	walkman:update(dt, {
		speed = deck:tapeSpeed(),
		progress = deck:progress(),
		volume = deck.volume,
		keys = keys,
		headEngaged = keys.play,
	})
	Sfx.update(deck)
end

function love.draw()
	Scaler.begin()
	if screen == "deck" then
		local track = deck:currentTrack()
		walkman:draw({
			title = track and songTitle(track.path) or "",
			subtitle = track and ui.safe(fs.basename(fs.parent(track.path))) or "",
			tapeLength = deck.tape and deck.tape.length,
		})
	else
		BrowserView.draw(browser, fonts)
	end
	Scaler.finish()
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
