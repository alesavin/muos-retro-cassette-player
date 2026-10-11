-- Draws the library: the folder being browsed and its subfolders and songs.
local Browser = require("lib.browser")
local fs = require("lib.fs")
local ui = require("lib.ui")
local lg = love.graphics

local View = {}

local ROW_H = 26
local LIST_Y = 58

local BG = { 0.24, 0.17, 0.13 }
local BAR = { 0.09, 0.09, 0.10 }
local STRIPE1 = { 0.95, 0.55, 0.15 }
local STRIPE2 = { 0.85, 0.24, 0.20 }
local HIGHLIGHT = { 0.96, 0.92, 0.82 }
local INK = { 0.13, 0.16, 0.38 }
local TEXT = { 0.92, 0.92, 0.90 }
local DIM = { 0.6, 0.6, 0.62 }

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

function View.draw(browser, fonts)
	setColor(BG)
	lg.rectangle("fill", 0, 0, 640, 480)

	setColor(BAR)
	lg.rectangle("fill", 0, 0, 640, 44)
	setColor(STRIPE1)
	lg.rectangle("fill", 0, 44, 640, 5)
	setColor(STRIPE2)
	lg.rectangle("fill", 0, 49, 640, 4)
	lg.setFont(fonts.medium)
	setColor(TEXT)
	lg.print("LIBRARY", 16, 10)
	lg.setFont(fonts.small)
	setColor(DIM)
	local where = ui.safe(browser.path or "Music folders")
	lg.printf(ui.ellipsize(fonts.small, where, 470), 150, 15, 474, "right")

	local entries = browser.entries
	if #entries == 0 then
		setColor(TEXT)
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
		if i == browser.sel then
			setColor(HIGHLIGHT)
			lg.rectangle("fill", 8, y, 624, ROW_H - 2, 4, 4)
			setColor(INK)
		else
			setColor(TEXT)
		end
		if e.kind == "dir" then
			folderIcon(20, y + 4)
		else
			noteIcon(22, y + 4)
		end
		local name = ui.safe(e.kind == "file" and fs.stem(e.name) or e.name)
		lg.print(ui.ellipsize(fonts.small, name, 570), 46, y + 4)
	end

	if #entries > Browser.ROWS then
		local trackH = Browser.ROWS * ROW_H
		local barH = math.max(20, trackH * Browser.ROWS / #entries)
		local barY = LIST_Y + (trackH - barH) * (browser.top - 1) / (#entries - Browser.ROWS)
		lg.setColor(1, 1, 1, 0.15)
		lg.rectangle("fill", 634, barY, 3, barH)
	end
end

return View
