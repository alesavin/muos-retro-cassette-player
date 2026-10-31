-- Headless tests for the parts that don't need a screen.
-- Run from the repo root: luajit tests/run.lua
package.path = "RetroCassette/game/?.lua;" .. package.path

-- Minimal stand-in for a LÖVE audio source.
local function fakeSource(duration)
	local s = { pos = 0, playing = false, duration = duration, pitch = 1 }
	function s:play() self.playing = true end
	function s:pause() self.playing = false end
	function s:stop() self.playing = false end
	function s:release() end
	function s:isPlaying() return self.playing end
	function s:tell() return self.pos end
	function s:seek(t) self.pos = t end
	function s:getDuration() return self.duration end
	function s:setVolume() end
	function s:setPitch(p) self.pitch = p end
	return s
end

local fs = require("lib.fs")
local Browser = require("lib.browser")
local Deck = require("lib.deck")
local Tape = require("lib.tape")
local Style = require("lib.style")

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
check("music roots from muOS mounts", table.concat(fs.candidateRoots("/mnt/sdcard:/mnt/mmc"), ",") == "/mnt/sdcard/MUSIC,/mnt/mmc/MUSIC")
check("music roots: other mounts first, defaults kept", table.concat(fs.candidateRoots("/mnt/usb:"), ",") == "/mnt/usb/MUSIC,/mnt/mmc/MUSIC,/mnt/sdcard/MUSIC")
check("card labels", fs.rootLabel("/mnt/mmc/MUSIC") == "SD1 · MUSIC" and fs.rootLabel("/mnt/sdcard/MUSIC") == "SD2 · MUSIC" and fs.rootLabel("/mnt/mmcx/MUSIC") == "/mnt/mmcx/MUSIC")
check("music roots without muOS: SD1 first", table.concat(fs.candidateRoots(nil), ",") == "/mnt/mmc/MUSIC,/mnt/sdcard/MUSIC")

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

-- Letter jumps
check("initials", Browser.initial("kind of blue") == "K" and Browser.initial("'86 Mix") == "#" and Browser.initial("Ёлка") == "Ё")
do
	local lb = Browser.new({})
	lb.entries = {}
	for _, n in ipairs({ "Amber", "Apple", "Blue", "Bright", "Bronze", "Cold", "Zero" }) do
		lb.entries[#lb.entries + 1] = { kind = "dir", name = n }
	end
	lb.sel = 2
	lb:jumpLetter(1)
	check("jump to next letter", lb.sel == 3)
	lb:jumpLetter(1)
	check("jump again", lb.sel == 6)
	lb.sel = 5
	lb:jumpLetter(-1)
	check("back to start of this letter", lb.sel == 3)
	lb:jumpLetter(-1)
	check("then to the previous letter", lb.sel == 1)
	lb.sel = 7
	lb:jumpLetter(1)
	check("no letter after the last", lb.sel == 7)
end

-- Tape styles
check("hash is stable", Style.hash("Kind of Blue") == Style.hash("Kind of Blue") and Style.hash("a") ~= Style.hash("b"))
check("same name, same style", Style.of("Road Trip '86") == Style.of("Road Trip '86"))
do
	local shells, fonts, valid = {}, {}, true
	for i = 1, 200 do
		local st = Style.of("Album " .. i)
		shells[st.shell.name], fonts[st.font] = true, true
		valid = valid and st.paper and st.ink and st.stripe and math.abs(st.tilt) < 0.02
	end
	local ns, nf = 0, 0
	for _ in pairs(shells) do ns = ns + 1 end
	for _ in pairs(fonts) do nf = nf + 1 end
	check("styles are complete", valid)
	check("names spread over every shell and font", ns == #Style.SHELLS and nf == #Style.FONTS)
end

-- Tape timeline
local tape = Tape.new({ "a", "b", "c" })
check("estimated layout", tape.length == 3 * Tape.DEFAULT_DURATION + 2 * Tape.GAP)
tape:setDuration(1, 100)
tape:setDuration(2, 50)
check("unknown track uses average", tape.tracks[3].length == 75)
check("starts include gaps", tape.tracks[2].start == 104 and tape.tracks[3].start == 158)
local i, off, blank = tape:locate(120)
check("locate in song", i == 2 and off == 16 and not blank)
i, off, blank = tape:locate(102)
check("locate in gap", i == 2 and blank)
check("next start", tape:nextStart(10) == 104 and tape:nextStart(160) == nil)
check("prev start: restart song", tape:prevStart(120) == 104)
check("prev start: previous song", tape:prevStart(105) == 0)

-- Deck transport. Sources are fakes keyed by path; "bad" can't be opened.
local sources = {}
local function newDeck()
	sources = {}
	return Deck.new({
		open = function(path)
			if path == "bad" then return nil end
			sources[path] = fakeSource(path == "a" and 100 or 50)
			return sources[path], { release = function() end }
		end,
	})
end
local d = newDeck()
d:insert(Tape.new({ "a", "b" }), 0)
d:press("play")
d:update(0.01)
check("play starts the first song", d.mode == "play" and sources.a.playing)
sources.a.pos = 40
d:update(0.01)
check("tape follows the song", d.t == 40)

d:press("play")
check("play again pauses", d.mode == "pause" and not sources.a.playing and d:keysDown().play == 0.5 and d:headEngaged())
d:update(1)
check("pause keeps position", d.t == 40)
d:press("play")
d:update(0.01)
check("play resumes from pause", d.mode == "play" and sources.a.playing and sources.a.pos == 40)
d:press("play")
d:press("stop")
check("stop from pause", d.mode == "stop" and not d:headEngaged())
d:press("play")
d:update(0.01)
d:press("stop")
check("stop silences, keeps position", d.mode == "stop" and not sources.a.playing and d.t == 40)
check("stop again ejects", d:press("stop") == "eject")
d:press("ff")
check("ff latches while stopped", d.mode == "ff")
d:update(1)
check("ff winds", d.t > 40 and not sources.a.playing)
d:press("play")
d:update(0.01)
check("play from wound position", sources.a.playing and math.abs(sources.a.pos - d.t) < 1e-6)

-- AMS: tap FF while playing winds to the next song, then plays it.
d:press("ff")
d:update(0.1)
check("held ff cues at higher pitch", sources.a.pitch == Deck.CUE_RATE and d:keysDown().ff == 1)
d:release("ff")
check("tap ff starts music sensor", d.mode == "ams" and d.amsTarget == d.tape.tracks[2].start)
for _ = 1, 100 do d:update(0.1) end
check("ams lands on next song and plays", d.mode == "play" and d.srcIndex == 2 and sources.b.playing)

-- Tap REW early in a song goes back to the previous song.
sources.b.pos = 1
d:update(0.01)
d:press("rew")
check("held rew reviews muted", not sources.b.playing and d:keysDown().rew == 1)
d:release("rew")
check("tap rew goes to previous song", d.mode == "ams" and d.amsTarget == 0)

-- End of a song runs into the gap, then the next song; end of tape stops.
d = newDeck()
d:insert(Tape.new({ "a", "b" }), 0)
d:press("play")
d:update(0.01)
sources.a.playing = false
d:update(0.01)
check("song end enters gap", d.mode == "play" and select(3, d.tape:locate(d.t)))
for _ = 1, 50 do d:update(0.1) end
check("gap leads to next song", sources.b and sources.b.playing)
sources.b.playing = false
for _ = 1, 3 do d:update(0.1) end
check("end of tape stops and pops PLAY", d.mode == "stop" and d.t == d.tape.length and d:keysDown().play == 0)

-- Putting the tape in at a later song survives the real lengths arriving.
d = newDeck()
local t3 = Tape.new({ "a", "b", "c" })
d:insert(t3, t3.tracks[2].start)
d:press("play")
d:update(0.01)
check("starts the chosen song", d.srcIndex == 2 and sources.b.playing and sources.b.pos == 0)
t3:setDuration(1, 30)
t3:setDuration(3, 70)
d:update(0.01)
check("position follows the layout", d.t == t3.tracks[2].start and d:currentTrack() == t3.tracks[2])
d:press("stop")
t3:setDuration(1, 20)
d:update(0.01)
check("stopped position follows too", d.t == t3.tracks[2].start)

-- D-pad skip: straight to the next / previous song, keeping play or pause.
d = newDeck()
local t4 = Tape.new({ "a", "b", "c" })
d:insert(t4, 0)
d:press("play")
d:update(0.01)
sources.a.pos = 20
d:update(0.01)
check("skip forward", d:skip(1) and d.t == t4.tracks[2].start and d:tapeSpeed() > 0 and d:winding())
d:update(0.01)
check("skip keeps playing the new song", d.mode == "play" and d.srcIndex == 2 and sources.b.playing and sources.b.pos == 0)
sources.b.pos = 10
d:update(0.01)
check("skip back restarts the song", d:skip(-1) and d.t == t4.tracks[2].start)
d:update(0.01)
check("skip back again goes to the previous song", d:skip(-1) and d.t == 0)
d:press("play")
check("skip while paused stays paused", d:skip(1) and d.mode == "pause" and d.t == t4.tracks[2].start)
d:update(1)
check("whir ends", d:tapeSpeed() == 0 and not d:winding())
d:skip(1)
check("no skip past the last song", not d:skip(1) and d.t == t4.tracks[3].start)
d:press("ff")
check("no skip while winding", not d:skip(-1))

-- While a song's file is still being read, PLAY is down and the deck waits.
do
	sources = {}
	local waits = 3
	local dl = Deck.new({
		open = function(path)
			if waits > 0 then
				waits = waits - 1
				return nil, "pending"
			end
			sources[path] = fakeSource(50)
			return sources[path], { release = function() end }
		end,
	})
	dl:insert(Tape.new({ "a", "b" }), 0)
	dl:press("play")
	dl:update(0.2)
	check("loading: waits for the file", dl:loading() and dl.t == 0 and not sources.a)
	local early = dl:keysDown().play
	dl:update(0.4)
	check("loading: PLAY sinks and the head rises", dl:keysDown().play > early and dl:headPosition() > 0.1 and dl:headPosition() < 1)
	dl:update(0.1)
	dl:update(0.1)
	check("loading: plays once ready", not dl:loading() and sources.a.playing and dl:keysDown().play == 1 and dl:headPosition() == 1)
	waits = 2
	dl:press("stop")
	check("loading state ends on stop", not dl:loading())
end
do
	local fetched = {}
	local dp = Deck.new({
		open = function(path)
			sources[path] = fakeSource(50)
			return sources[path], { release = function() end }
		end,
		prefetch = function(path) fetched[#fetched + 1] = path end,
	})
	dp:insert(Tape.new({ "a", "b", "c" }), 0)
	dp:press("play")
	dp:update(0.01)
	check("reads the next song ahead", fetched[1] == "b")
end

-- Unreadable files are skipped as blank tape.
d = newDeck()
d:insert(Tape.new({ "bad", "b" }), 0)
d:press("play")
for _ = 1, 200 do d:update(0.1) end
check("unreadable file skipped", sources.b and sources.b.playing)

d:setVolume(2)
check("volume clamps", d.volume == 1)

sh("rm -rf '" .. tmp .. "'")
print(string.format("%d/%d checks passed", count - failures, count))
os.exit(failures == 0 and 0 or 1)
