# Retro Cassette Player

A cassette-style music player for muOS handhelds, written in Lua for LÖVE 11.x.
See README.md for features, controls and layout.

Design rule: the deck screen shows only a physical player. State is shown by
parts of the player (latched keys, reels, tape packs, head, the
cassette label), never by icons, text readouts or overlays. A tape's look comes
from `lib/style.lua` (hash of its folder name) and must match between its
library spine and the cassette in the player.

## Commands

- `luajit tests/run.lua`: headless tests (LÖVE APIs are stubbed). Run after any change to `fs`, `browser`, `style`, `tape` or `deck`.
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
- The screen is only redrawn when something moves or changed (`lib/frame.lua`), to keep the device cool. A state change that doesn't come from a button press must call `Frame.invalidate()`, and anything animated must report itself through the screen's `isMoving()`.
- Load fonts through `lib/fonts.lua`, never `love.graphics.newFont` directly.
- Don't commit LÖVE binaries (`RetroCassette/bin/`) or `RetroCassette/data/`.
- Never rename the `RetroCassette` folder or package: muOS identifies the app by its folder, so a new name installs a second copy beside the old one. The displayed name lives in `mux_lang.ini`.
