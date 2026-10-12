# Retro Cassette

A cassette-style music player for muOS handhelds, written in Lua for LÖVE 11.x.
See README.md for features, controls and layout.

Design rule: the deck screen shows only a physical player. State is shown by
parts of the player (latched keys, reels, tape packs, head, volume wheel, the
cassette label), never by icons, text readouts or overlays.

## Commands

- `luajit tests/run.lua`: headless tests (LÖVE APIs are stubbed). Run after any change to `fs`, `browser`, `tape` or `deck`.
- `scripts/screenshots.sh`: runs the real app under xvfb with scripted input and writes PNGs to `~/.local/share/love/rc-harness/`. Look at them after any drawing change.
- `scripts/package.sh <version>`: builds `dist/RetroCassette-<version>.muxapp`.
- Syntax check: `for f in $(find RetroCassette tests tools -name '*.lua'); do luajit -bl "$f" >/dev/null; done`

## Conventions

- Code must run on LuaJIT (Lua 5.1): no `//`, bitwise operators or other Lua 5.3+ features.
- Tabs for indentation.
- All drawing happens on the 720x480 canvas from `lib/scaler.lua` (the RG34XXSP screen); use canvas coordinates, never the window size.
- `love.filesystem` can't see the SD cards. Use `lib/fs.lua` (shell `find`, `io.open`) for music; any new shell command there must quote paths with its `quote` helper.
- Pass file names through `ui.safe` before printing; they may not be valid UTF-8.
- Keyboard and gamepad buttons map to the same action names in `lib/input.lua`; screens only handle actions.
- Don't commit LÖVE binaries (`RetroCassette/bin/`) or `RetroCassette/data/`.
