-- Folder browser over the music roots.
local fs = require("lib.fs")

local Browser = {}
Browser.__index = Browser

-- Tapes visible in the stack at once.
Browser.ROWS = 9

function Browser.new(roots)
	local self = setmetatable({}, Browser)
	self.roots = roots
	self.path = nil -- nil while showing the list of roots
	self.entries = {}
	self.sel = 1
	self.top = 1
	return self
end

function Browser:isRoot(path)
	for _, r in ipairs(self.roots) do
		if r == path then
			return true
		end
	end
	return false
end

function Browser:select(name)
	self.sel = 1
	for i, e in ipairs(self.entries) do
		if e.name == name then
			self.sel = i
			break
		end
	end
	self:scrollToSelection()
end

function Browser:openRoots(selectPath)
	if #self.roots == 1 then
		return self:open(self.roots[1])
	end
	self.path = nil
	self.entries = {}
	for _, r in ipairs(self.roots) do
		self.entries[#self.entries + 1] = { kind = "dir", name = r, path = r }
	end
	self:select(selectPath)
end

function Browser:open(path, selectName)
	local dirs, files = fs.list(path)
	self.path = path
	self.entries = {}
	for _, d in ipairs(dirs) do
		self.entries[#self.entries + 1] = { kind = "dir", name = d, path = fs.join(path, d) }
	end
	for _, f in ipairs(files) do
		self.entries[#self.entries + 1] = { kind = "file", name = f, path = fs.join(path, f) }
	end
	self:select(selectName)
end

function Browser:back()
	if not self.path then
		return
	end
	if self:isRoot(self.path) then
		if #self.roots > 1 then
			self:openRoots(self.path)
		end
		return
	end
	self:open(fs.parent(self.path), fs.basename(self.path))
end

function Browser:scrollToSelection()
	if self.sel < self.top then
		self.top = self.sel
	elseif self.sel >= self.top + Browser.ROWS then
		self.top = self.sel - Browser.ROWS + 1
	end
	self.top = math.max(1, math.min(self.top, #self.entries - Browser.ROWS + 1))
end

-- Single steps wrap around the list; page jumps stop at the ends.
function Browser:move(delta, wrap)
	local n = #self.entries
	if n == 0 then
		return
	end
	local s = self.sel + delta
	if wrap then
		s = (s - 1) % n + 1
	else
		s = math.max(1, math.min(n, s))
	end
	self.sel = s
	self:scrollToSelection()
end

-- Opens the selected folder, or returns the folder's tracks and the selected
-- track's position in them when a file is chosen.
function Browser:activate()
	local e = self.entries[self.sel]
	if not e then
		return nil
	end
	if e.kind == "dir" then
		self:open(e.path)
		return nil
	end
	local queue, index = {}, 1
	for _, it in ipairs(self.entries) do
		if it.kind == "file" then
			queue[#queue + 1] = it.path
			if it == e then
				index = #queue
			end
		end
	end
	return queue, index
end

-- The letter a name files under: A-Z upper-cased, "#" for digits and other
-- ASCII, and the first character itself for other scripts.
function Browser.initial(name)
	local c = name:match("^[%z\1-\127\194-\244][\128-\191]*") or ""
	if c:match("^%a$") then
		return c:upper()
	elseif #c <= 1 then
		return "#"
	end
	return c
end

local function letterAt(self, i)
	return Browser.initial(self.entries[i].name)
end

-- Jumps to the first tape of the next letter (dir 1), or to the first of this
-- letter / the previous letter (dir -1), and shows it at the top of the stack.
function Browser:jumpLetter(dir)
	local n = #self.entries
	if n == 0 then
		return
	end
	local i = self.sel
	local cur = letterAt(self, i)
	if dir > 0 then
		while i < n and letterAt(self, i) == cur do
			i = i + 1
		end
		if letterAt(self, i) == cur then
			i = self.sel -- no later letter
		end
	else
		local j = i
		while j > 1 and letterAt(self, j - 1) == cur do
			j = j - 1
		end
		if j == i and i > 1 then
			local prev = letterAt(self, i - 1)
			j = i - 1
			while j > 1 and letterAt(self, j - 1) == prev do
				j = j - 1
			end
		end
		i = j
	end
	self.sel = i
	self.top = math.max(1, math.min(i, n - Browser.ROWS + 1))
	self:scrollToSelection()
end

-- L1/R1: among albums, jump by letter; among songs, flip a pile of tapes.
function Browser:flip(dir)
	local e = self.entries[self.sel]
	if e and e.kind == "dir" then
		self:jumpLetter(dir)
	else
		self:move(dir * Browser.ROWS, false)
	end
end

-- True when the stack is longer than the screen, so it's worth showing where you are.
function Browser:isLong()
	return #self.entries > Browser.ROWS
end

-- Opens the selected folder; does nothing on a song. Returns true if opened.
function Browser:openSelection()
	local e = self.entries[self.sel]
	if e and e.kind == "dir" then
		self:open(e.path)
		return true
	end
	return false
end

-- PLAY on the selection: a song plays its folder from that song; a folder plays
-- its own songs from the first. A folder without songs is opened instead.
function Browser:playSelection()
	local e = self.entries[self.sel]
	if not e then
		return nil
	end
	if e.kind == "file" then
		return self:activate()
	end
	local _, files = fs.list(e.path)
	if #files == 0 then
		self:open(e.path)
		return nil
	end
	local queue = {}
	for i, f in ipairs(files) do
		queue[i] = fs.join(e.path, f)
	end
	return queue, 1
end

return Browser
