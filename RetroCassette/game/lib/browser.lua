-- Folder browser over the music roots.
local fs = require("lib.fs")

local Browser = {}
Browser.__index = Browser

-- Tapes visible in the stack at once.
Browser.ROWS = 10

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
