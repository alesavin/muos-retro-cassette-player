-- The library as a box of tapes: every folder (album) and song is a cassette
-- lying in a stack with its spine facing you. The selected tape slides out.
-- Songs wear their folder's style, the same as the cassette in the player.
local Browser = require("lib.browser")
local Fonts = require("lib.fonts")
local Keys = require("lib.keys")
local Style = require("lib.style")
local TapeArt = require("lib.tapeart")
local fs = require("lib.fs")
local ui = require("lib.ui")
local lg = love.graphics

local View = {}
View.__index = View

local W = 720
local SPINE_X, SPINE_W, SPINE_H = 40, 600, 38
local STACK_Y, PITCH = 44, 43
local SLIDE = 40

-- The player's keys at the bottom, with the button that does the same printed
-- under each: L1/R1 flip a pile, L2 goes back up, R2 plays.
local TWINS = { stop = "B  or  ‹", play = "A" }

-- "03 - Song Name.mp3" -> "Song Name"
function View.songTitle(path)
	local stem = fs.stem(fs.basename(path))
	return ui.safe(stem:match("^%d+[%s%.%-_]+(.+)$") or stem)
end

-- The style of the tape a song belongs to: its folder's.
function View.tapeStyle(songPath)
	return Style.of(fs.basename(fs.parent(songPath)))
end

function View.new()
	local self = setmetatable({}, View)
	self.offset = 1
	self.slide = {}
	self.path = false
	self.moving = false
	self.keyDepth = {}
	return self
end

local function approach(current, target, rate, dt)
	local v = current + (target - current) * math.min(1, dt * rate)
	if math.abs(target - v) < 0.01 then
		return target, false
	end
	return v, true
end

-- keys: how far each key is pressed (0..1), by key name.
function View:update(dt, browser, keys)
	if browser.path ~= self.path then
		-- New folder: show it in place, no scrolling in from elsewhere.
		self.path = browser.path
		self.offset = browser.top
		self.slide = {}
	end
	local moving
	self.offset, moving = approach(self.offset, browser.top, 14, dt)
	for i = browser.top - 1, browser.top + Browser.ROWS do
		local target = i == browser.sel and SLIDE or 0
		local m
		self.slide[i], m = approach(self.slide[i] or 0, target, 16, dt)
		moving = moving or m
	end
	for _, k in ipairs(Keys.LAYOUT) do
		local m
		self.keyDepth[k.name], m = approach(self.keyDepth[k.name] or 0, keys[k.name] or 0, 30, dt)
		moving = moving or m
	end
	self.moving = moving
end

function View:isMoving()
	return self.moving
end

local function drawSpine(st, title, sub, x, y, lifted)
	local w, h = SPINE_W, SPINE_H
	lg.setColor(0, 0, 0, lifted and 0.5 or 0.3)
	lg.rectangle("fill", x + 3, y + 4, w, h, 6, 6)
	TapeArt.shell(st)
	lg.rectangle("fill", x, y, w, h, 6, 6)
	TapeArt.ribs(st, x, y, w, h, 9)
	lg.setColor(1, 1, 1, 0.12)
	lg.rectangle("fill", x + 4, y + 2, w - 8, 2, 1, 1)

	-- Paper label with the stripes at both ends.
	local lx, ly, lw, lh = x + 34, y + 5, w - 68, h - 10
	TapeArt.setColor(st.paper)
	lg.rectangle("fill", lx, ly, lw, lh, 2, 2)
	TapeArt.stripes(st, lx, ly, 14, lh)
	TapeArt.stripes(st, lx + lw - 14, ly, 14, lh)

	local tw = lw - 90
	local f = Fonts.fit(st.font, title, tw, lh * 0.85)
	lg.setFont(f)
	TapeArt.setColor(st.ink)
	lg.push()
	lg.translate(lx + 24, ly + (lh - f:getHeight()) / 2)
	lg.rotate(st.tilt)
	lg.print(ui.ellipsize(f, title, tw), 0, 0)
	lg.pop()
	if sub then
		lg.setFont(Fonts.get("print", 12))
		TapeArt.setColor(st.ink, 0.7)
		lg.printf(sub, lx, ly + lh / 2 - 8, lw - 22, "right")
	end

	-- Side letters moulded into the shell ends.
	lg.setFont(Fonts.get("print", 13))
	TapeArt.onShell(st, 0.45)
	lg.print("A", x + 13, y + h / 2 - 9)
	lg.print("A", x + w - 22, y + h / 2 - 9)
end

-- A strip of masking tape on the box with the folder's name.
-- A strip of masking tape on the box with the folder's name, and in a long
-- box a pencilled note of where you are ("40 of 87").
local function drawBoxLabel(text, note)
	local f = Fonts.get("marker", 18)
	text = ui.ellipsize(f, text, 520)
	local w = f:getWidth(text) + 28
	lg.setColor(0, 0, 0, 0.25)
	lg.rectangle("fill", 23, 11, w, 30)
	lg.setColor(0.93, 0.88, 0.70, 0.97)
	lg.rectangle("fill", 20, 8, w, 30)
	lg.setFont(f)
	lg.setColor(0.10, 0.10, 0.10)
	lg.print(text, 34, 10)
	if note then
		lg.setFont(Fonts.get("pen", 20))
		lg.setColor(0.80, 0.76, 0.68, 0.85)
		lg.print(note, 20 + w + 14, 9)
	end
end

-- An index card standing between the tapes where a new letter starts.
local function drawDivider(letter, y)
	lg.setColor(0, 0, 0, 0.3)
	lg.rectangle("fill", 688, y + 3, 30, 28, 4, 4)
	lg.setColor(0.97, 0.95, 0.88)
	lg.rectangle("fill", 685, y, 30, 28, 4, 4)
	lg.setFont(Fonts.get("marker", 18))
	lg.setColor(0.70, 0.10, 0.10)
	lg.printf(letter, 685, y + 1, 30, "center")
end

local function drawNote(text)
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", 126, 156, 480, 170, 3, 3)
	lg.setColor(0.97, 0.95, 0.88)
	lg.rectangle("fill", 120, 150, 480, 170, 3, 3)
	lg.setFont(Fonts.get("pen", 20))
	lg.setColor(0.12, 0.18, 0.55)
	lg.printf(text, 140, 168, 440, "center")
end

function View:draw(browser)
	-- Inside of a cardboard box.
	lg.setColor(0.30, 0.22, 0.15)
	lg.rectangle("fill", 0, 0, W, 480)
	lg.setColor(0, 0, 0, 0.06)
	lg.setLineWidth(1)
	for y = 0, 480, 6 do
		lg.line(0, y, W, y + 3)
	end

	local entries = browser.entries
	if #entries == 0 then
		drawNote(browser.path and "No tapes in this folder."
			or "No music found.\n\nMake a MUSIC folder on your SD card with one folder per album.")
	end

	-- Songs in a folder are numbered in folder order.
	local songNo, n = {}, 0
	for i, e in ipairs(entries) do
		if e.kind == "file" then
			n = n + 1
			songNo[i] = n
		end
	end

	local first = math.max(1, math.floor(self.offset) - 1)
	for i = first, math.min(#entries, first + Browser.ROWS + 2) do
		local e = entries[i]
		local y = STACK_Y + (i - self.offset) * PITCH
		local x = SPINE_X + (self.slide[i] or 0)
		if e.kind == "file" then
			drawSpine(View.tapeStyle(e.path), View.songTitle(e.path), string.format("%02d", songNo[i]), x, y, i == browser.sel)
		else
			-- At the top level the folders are the cards' MUSIC folders: name them by card.
			local name = browser.path and e.name or fs.rootLabel(e.path)
			drawSpine(Style.of(browser.path and fs.basename(e.path) or name), ui.safe(name), nil, x, y, i == browser.sel)
		end
	end

	-- In a long box of albums, divider cards mark where each letter starts.
	local long = browser:isLong()
	if long and browser.path then
		for i = first, math.min(#entries, first + Browser.ROWS + 2) do
			local e = entries[i]
			if e.kind == "dir" then
				local letter = Browser.initial(e.name)
				if i == 1 or entries[i - 1].kind ~= "dir" or Browser.initial(entries[i - 1].name) ~= letter then
					drawDivider(ui.safe(letter), STACK_Y + (i - self.offset) * PITCH - 6)
				end
			end
		end
	end

	-- Top edge of the box, behind the label, so a tape scrolled off the top
	-- doesn't show through it.
	lg.setColor(0.30, 0.22, 0.15)
	lg.rectangle("fill", 0, 0, W, 40)
	lg.setColor(0, 0, 0, 0.18)
	lg.rectangle("fill", 0, 40, W, 3)

	local box = "MUSIC"
	if browser.path then
		box = browser:isRoot(browser.path) and fs.rootLabel(browser.path) or fs.basename(browser.path)
	end
	local note
	local e = entries[browser.sel]
	if long then
		if e and e.kind == "dir" and browser.path then
			box = box .. "  ·  " .. Browser.initial(e.name)
		end
		note = string.format("%d of %d", browser.sel, #entries)
	end
	drawBoxLabel(ui.safe(box), note)

	-- Bottom edge: the keys, and the D-pad's part between them.
	lg.setColor(0.30, 0.22, 0.15)
	lg.rectangle("fill", 0, 438, W, 42)
	Keys.draw(self.keyDepth, TWINS)
	lg.setFont(Fonts.get("print", 14))
	lg.setColor(0.93, 0.88, 0.70, 0.75)
	local open = e and e.kind == "dir" and "     ›  open" or ""
	lg.printf("up · down  choose" .. open, 210, 452, 300, "center")
end

return View
