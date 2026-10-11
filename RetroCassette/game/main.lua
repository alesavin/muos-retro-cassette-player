local Browser = require("lib.browser")
local BrowserView = require("lib.browser_view")
local Cassette = require("lib.cassette")
local Input = require("lib.input")
local Player = require("lib.player")
local Scaler = require("lib.scaler")
local Settings = require("lib.settings")
local Sfx = require("lib.sfx")
local fs = require("lib.fs")
local ui = require("lib.ui")

local WIDTH, HEIGHT = 640, 480

local screen = "browser" -- browser | deck
local fonts, player, browser, cassette

local function loadFonts()
	-- Drop a TTF at assets/label.ttf for a handwritten-style cassette label.
	local labelFont = love.filesystem.getInfo("assets/label.ttf") and "assets/label.ttf"
	local function labelSized(size)
		if labelFont then
			return love.graphics.newFont(labelFont, size)
		end
		return love.graphics.newFont(size)
	end
	return {
		title = labelSized(22),
		side = labelSized(40),
		small = love.graphics.newFont(15),
		tiny = love.graphics.newFont(12),
		medium = love.graphics.newFont(20),
		digits = love.graphics.newFont(22),
	}
end

local function transport()
	if player.wind > 0 then
		return "ff"
	elseif player.wind < 0 then
		return "rew"
	elseif player.state == "playing" then
		return "play"
	elseif player.state == "paused" then
		return "pause"
	end
	return "stop"
end

local function deckInfo()
	local path = player:currentPath()
	local title, subtitle = "No tape loaded", "Press B to pick some music"
	if path then
		title = ui.safe(fs.stem(fs.basename(path)))
		subtitle = ui.safe(fs.basename(fs.parent(path)))
	end
	return {
		side = "A",
		title = title,
		subtitle = subtitle,
		transport = transport(),
		position = player:position(),
		duration = player:duration(),
		track = math.max(player.index, 0),
		tracks = #player.queue,
		volume = player.volume,
		hiss = Settings.values.hiss,
		error = player.error,
	}
end

local function clunk()
	Sfx.clunk(0.5 * player.volume)
end

local function browserAction(action, isRepeat)
	if action == "up" then
		browser:move(-1, not isRepeat)
	elseif action == "down" then
		browser:move(1, not isRepeat)
	elseif action == "left" then
		browser:move(-Browser.ROWS, false)
	elseif action == "right" then
		browser:move(Browser.ROWS, false)
	elseif action == "a" and not isRepeat then
		local queue, index = browser:activate()
		if queue then
			player:setQueue(queue, index)
			clunk()
			screen = "deck"
			Settings.values.lastDir = browser.path or ""
			Settings.save()
		end
	elseif action == "b" then
		browser:back()
	elseif action == "y" and #player.queue > 0 then
		screen = "deck"
	end
end

local function deckAction(action, isRepeat)
	if action == "up" or action == "down" then
		player:setVolume(player.volume + (action == "up" and 0.05 or -0.05))
		Settings.values.volume = player.volume
		Settings.save()
	elseif isRepeat then
		return
	elseif action == "a" then
		player:toggle()
		clunk()
	elseif action == "b" then
		screen = "browser"
	elseif action == "left" then
		player:prev()
		clunk()
	elseif action == "right" then
		player:step(1)
		clunk()
	elseif action == "l1" then
		player:startWind(-1)
		clunk()
	elseif action == "r1" then
		player:startWind(1)
		clunk()
	elseif action == "x" then
		Settings.values.hiss = not Settings.values.hiss
		Settings.save()
	elseif action == "y" then
		Settings.values.theme = cassette:setTheme(cassette.themeIndex + 1)
		Settings.save()
	end
end

local function onAction(action, isRepeat)
	if action == "quit" then
		love.event.quit()
	elseif screen == "browser" then
		browserAction(action, isRepeat)
	else
		deckAction(action, isRepeat)
	end
end

local function onRelease(action)
	if action == "l1" then
		player:stopWind(-1)
	elseif action == "r1" then
		player:stopWind(1)
	end
end

function love.load()
	love.mouse.setVisible(false)
	Settings.load()
	Scaler.init(WIDTH, HEIGHT)
	fonts = loadFonts()
	Sfx.init()

	player = Player.new()
	player:setVolume(Settings.values.volume)

	cassette = Cassette.new(fonts)
	cassette:setTheme(Settings.values.theme)

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
	player:update(dt)
	cassette:update(dt, player:tapeSpeed(), player:progress())
	Sfx.update(player, Settings.values.hiss)
end

function love.draw()
	Scaler.begin()
	if screen == "deck" then
		cassette:draw(deckInfo())
	else
		BrowserView.draw(browser, fonts, cassette:theme(), player:currentPath(), player.state == "playing")
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
