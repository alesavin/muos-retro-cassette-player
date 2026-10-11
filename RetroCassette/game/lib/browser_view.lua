-- Draws the folder browser screen.
local Browser = require("lib.browser")
local fs = require("lib.fs")
local ui = require("lib.ui")
local lg = love.graphics

local View = {}

local ROW_H = 26
local LIST_Y = 58

local function setColor(c, a)
	lg.setColor(c[1], c[2], c[3], a or 1)
end

local function folderIcon(x, y)
	lg.rectangle("fill", x, y + 2, 7, 3)
	lg.rectangle("fill", x, y + 4, 16, 11, 2, 2)
end

local function noteIcon(x, y)
	lg.circle("fill", x + 5, y + 12, 4)
	lg.rectangle("fill", x + 7, y, 2, 12)
	lg.rectangle("fill", x + 7, y, 7, 3)
end

-- theme: a Cassette theme; nowPlaying: path of the loaded track or nil.
function View.draw(browser, fonts, theme, nowPlaying, playing)
	setColor(theme.bg)
	lg.rectangle("fill", 0, 0, 640, 480)

	-- Header.
	lg.setColor(0.09, 0.09, 0.10)
	lg.rectangle("fill", 0, 0, 640, 44)
	setColor(theme.stripe1)
	lg.rectangle("fill", 0, 44, 640, 5)
	setColor(theme.stripe2)
	lg.rectangle("fill", 0, 49, 640, 4)
	lg.setFont(fonts.medium)
	lg.setColor(0.95, 0.95, 0.92)
	lg.print("LIBRARY", 16, 10)
	lg.setFont(fonts.small)
	lg.setColor(0.6, 0.6, 0.62)
	local where = ui.safe(browser.path or "Music folders")
	lg.printf(ui.ellipsize(fonts.small, where, 470), 150, 15, 474, "right")

	-- Rows.
	local entries = browser.entries
	if #entries == 0 then
		lg.setFont(fonts.small)
		lg.setColor(0.95, 0.95, 0.92)
		local msg = browser.path and "No folders or audio files here."
			or "No music folder found.\nCreate MUSIC on your SD card (for example /mnt/sdcard/MUSIC)\nand copy MP3, OGG, FLAC or WAV files into it."
		lg.printf(msg, 40, 180, 560, "center")
	end
	for row = 0, Browser.ROWS - 1 do
		local i = browser.top + row
		local e = entries[i]
		if not e then
			break
		end
		local y = LIST_Y + row * ROW_H
		local selected = i == browser.sel
		if selected then
			setColor(theme.label)
			lg.rectangle("fill", 8, y, 624, ROW_H - 2, 4, 4)
			setColor(theme.ink)
		else
			lg.setColor(0.92, 0.92, 0.9)
		end
		if e.kind == "dir" then
			folderIcon(20, y + 4)
		else
			noteIcon(22, y + 4)
		end
		local name = ui.safe(e.kind == "file" and fs.stem(e.name) or e.name)
		lg.setFont(fonts.small)
		lg.print(ui.ellipsize(fonts.small, name, 560), 46, y + 4)
		if e.path == nowPlaying then
			setColor(theme.stripe1)
			ui.icon(playing and "play" or "pause", 610, y + 6, 12)
		end
	end

	-- Scrollbar.
	if #entries > Browser.ROWS then
		local trackH = Browser.ROWS * ROW_H
		local barH = math.max(20, trackH * Browser.ROWS / #entries)
		local barY = LIST_Y + (trackH - barH) * (browser.top - 1) / (#entries - Browser.ROWS)
		lg.setColor(1, 1, 1, 0.15)
		lg.rectangle("fill", 634, barY, 3, barH)
	end

	-- Footer.
	lg.setColor(0.09, 0.09, 0.10)
	lg.rectangle("fill", 0, 428, 640, 52)
	lg.setFont(fonts.tiny)
	if nowPlaying then
		setColor(theme.stripe1)
		ui.icon(playing and "play" or "pause", 16, 436, 10)
		lg.setColor(0.95, 0.95, 0.92)
		lg.print(ui.ellipsize(fonts.tiny, ui.safe(fs.stem(fs.basename(nowPlaying))), 590), 34, 434)
	end
	lg.setColor(0.55, 0.55, 0.58)
	local hint = "A open/play   B back   < > page   Y cassette   SELECT+START quit"
	lg.printf(hint, 0, 456, 640, "center")
end

return View
