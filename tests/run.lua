-- Headless tests for the parts that don't need a screen.
-- Run from the repo root: luajit tests/run.lua
package.path = "RetroCassette/game/?.lua;" .. package.path

-- Minimal stand-ins for the LÖVE APIs the player touches.
local function fakeSource(duration)
	local s = { pos = 0, playing = false, duration = duration, volume = 1 }
	function s:play() self.playing = true end
	function s:pause() self.playing = false end
	function s:stop() self.playing = false; self.pos = 0 end
	function s:release() end
	function s:isPlaying() return self.playing end
	function s:tell() return self.pos end
	function s:seek(t) self.pos = t end
	function s:getDuration() return self.duration end
	function s:setVolume(v) self.volume = v end
	return s
end

love = {
	filesystem = {
		newFileData = function(data, name)
			if name:match("^bad") then error("decode failed") end
			return { release = function() end }
		end,
	},
	audio = { newSource = function() return fakeSource(100) end },
}

local fs = require("lib.fs")
local Browser = require("lib.browser")
local Player = require("lib.player")

local failures, count = 0, 0
local function check(name, cond)
	count = count + 1
	if not cond then
		failures = failures + 1
		print("FAIL " .. name)
	end
end

-- fs helpers
check("basename", fs.basename("/mnt/sdcard/MUSIC/Album/") == "Album")
check("parent", fs.parent("/mnt/sdcard/MUSIC/Album") == "/mnt/sdcard/MUSIC")
check("parent of top", fs.parent("/mnt") == "/")
check("stem", fs.stem("01 - Song.name.mp3") == "01 - Song.name")
check("isAudio", fs.isAudio("a.FLAC") and not fs.isAudio("cover.jpg"))

-- Build a temporary music tree.
local tmp = os.tmpname()
os.remove(tmp)
local function sh(cmd) assert(os.execute(cmd) == 0 or true) end
sh("mkdir -p '" .. tmp .. "/Albums/Side B' '" .. tmp .. "/.hidden'")
for _, f in ipairs({ "b.mp3", "A.ogg", "bad.mp3", "notes.txt", "it's.wav" }) do
	local h = io.open(tmp .. "/Albums/" .. f, "wb"); h:write("x"); h:close()
end

local dirs, files = fs.list(tmp .. "/Albums")
check("list dirs", #dirs == 1 and dirs[1] == "Side B")
check("list files sorted, audio only", table.concat(files, ",") == "A.ogg,b.mp3,bad.mp3,it's.wav")
check("isDir", fs.isDir(tmp) and not fs.isDir(tmp .. "/nope"))

-- Browser navigation
local b = Browser.new({ tmp })
b:openRoots()
check("single root opens directly", b.path == tmp and #b.entries == 1)
check("hidden folders skipped", b.entries[1].name == "Albums")
b:activate()
check("open folder", b.path == tmp .. "/Albums" and b.entries[1].kind == "dir")
b:move(-1, true)
check("wrap to last", b.entries[b.sel].name == "it's.wav")
b:move(-2, false)
local queue, index = b:activate()
check("queue of files", queue and #queue == 4 and index == 2)
b:back()
check("back selects folder", b.path == tmp and b.entries[b.sel].name == "Albums")
b:back()
check("back at root stays", b.path == tmp)

-- Player: skipping, end of side, winding
local p = Player.new()
p:setQueue(queue, 2)
check("plays selected", p.index == 2 and p.state == "playing")
p:step(1)
check("skips undecodable file", p.index == 4 and p.state == "playing")
p.source.playing = false
p:update(0.1)
check("end of side rewinds and stops", p.index == 1 and p.state == "stopped")
p:play()
p.source.pos = 10
p:startWind(1)
check("wind pauses audio", not p.source.playing and p.wind == 1)
p:update(1)
check("wind advances position", math.abs(p:position() - (10 + Player.WIND_SPEED)) < 1e-6)
p:stopWind(1)
check("wind resumes playback", p.source.playing and p.state == "playing" and p.source.pos == 10 + Player.WIND_SPEED)
p:startWind(-1)
p:update(60)
check("rewind clamps at 0", p:position() == 0)
p:stopWind(-1)
p.source.pos = 5
p:prev()
check("prev restarts track", p.index == 1 and p.source.pos == 0)
p:setVolume(2)
check("volume clamps", p.volume == 1)

sh("rm -rf '" .. tmp .. "'")
print(string.format("%d/%d checks passed", count - failures, count))
os.exit(failures == 0 and 0 or 1)
