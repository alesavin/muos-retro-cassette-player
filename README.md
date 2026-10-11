# Retro Cassette

A music player for [muOS](https://muos.dev) handhelds that shows a cassette
inside a closed portable player. There are no on-screen icons or readouts. You
can tell what the player is doing the way you would with a real one: from the
keys that are pressed down, the turning reels, how much tape is on each reel
and the play head against the tape.

![Deck](docs/deck.png)

Built with [LÖVE](https://love2d.org) 11.x (Lua).

## How it works

- **A folder is one side of a tape.** Its songs are recorded one after another
  with a few seconds of blank tape between them. The reels show how far you are
  through the whole album, and the minute marks on the cassette window show the
  time: read it where the edge of the right-hand tape pack sits.
- **The label** shows the song under the head and the folder (album or artist) name.
- **The volume wheel** on the right side rolls to the current level, 0–10.
- **The keys stay down** like real ones. PLAY stays down while playing, and FF or
  REW stays down while winding. They pop up with a clunk at the end of the tape.

MP3, OGG, FLAC and WAV are supported.

## Controls

The four keys on top of the player are the shoulder buttons, in the same order:

| Button | Key | Stopped | Playing |
| --- | --- | --- | --- |
| L1 | REW | Rewinds until STOP or the start of the tape | Tap: back to the start of this song (or the previous one in its first 3 s). Hold: review, the tape runs back muted |
| L2 | STOP | Opens the lid and goes back to the library | Stops; the tape stays where it is, so this is also pause |
| R2 | PLAY | Plays | |
| R1 | FF | Fast-forwards until STOP or the end of the tape | Tap: wind to the next song (music sensor). Hold: cue, the tape plays fast and high-pitched |

A works as PLAY and B as STOP. D-pad up and down turn the volume wheel.

In the library: D-pad to move (left and right page), A to open a folder or to
put the tape in at the chosen song, B to go up a folder.

Select + Start or the Menu button quits.

On a desktop: arrows, Z = A, X = B, A/S/D/F = L1/L2/R2/R1, Tab = Select,
Space = Start, Esc = quit.

## Where to put music

The app looks for these folders and shows the ones that exist:

- `/mnt/sdcard/MUSIC`
- `/mnt/mmc/MUSIC`
- `/mnt/union/MUSIC`

Set `RC_MUSIC_DIR` to use a different folder.

## Install on a device

1. Build the package: `scripts/package.sh 0.1.0`. It writes `dist/RetroCassette-0.1.0.muxapp`.
2. Copy the `.muxapp` to the device's archive folder and install it from muOS's
   Archive Manager. Or copy the `RetroCassette` folder to
   `/mnt/mmc/MUOS/application/` yourself.
3. Start **Retro Cassette** from the Applications menu.

The app needs a LÖVE runtime. If your muOS build doesn't put `love` on `PATH`,
copy `love` and `libs.aarch64/` from a LÖVE app that ships with muOS into
`RetroCassette/bin/` before packaging (see [RetroCassette/bin/README.md](RetroCassette/bin/README.md)).
Output from the app goes to `RetroCassette/data/log.txt`, and settings are kept
in `RetroCassette/data/`.

> **Not yet tested on hardware.** The launcher, archive layout and button
> mapping follow what other muOS LÖVE apps do, but they still need to be checked on
> a real device. L2/R2 are read as analog triggers, and A/B can come out swapped
> depending on the device's controller mapping.

## Develop on a desktop

```sh
RC_MUSIC_DIR=~/Music love RetroCassette/game
```

Checks:

```sh
luajit tests/run.lua       # file listing, browser, tape timeline and transport logic, LÖVE stubbed out
scripts/screenshots.sh     # runs the real app headless and saves screenshots (needs love, xvfb-run, python3)
```

## Layout

```
RetroCassette/            what gets installed on the device
  mux_launch.sh           muOS launcher (HELP / ICON / GRID headers)
  game/                   LÖVE project
    main.lua              screens and button handling
    lib/walkman.lua       draws the player: lid, cassette, keys, volume wheel
    lib/deck.lua          transport: latching keys, cue/review, music sensor, audio
    lib/tape.lua          tape timeline: songs and gaps on one side
    lib/durations.lua     reads song lengths on a background thread
    lib/browser.lua       folder navigation
    lib/browser_view.lua  library screen drawing
    lib/fs.lua            SD card access (find / io.open)
    lib/input.lua         gamepad + keyboard to actions, key repeat
    lib/sfx.lua           generated hiss, winding whir and key clunk
    lib/settings.lua      settings file (volume, last folder)
    lib/scaler.lua        640x480 canvas scaled to the screen
scripts/                  package.sh, screenshots.sh
tests/run.lua             headless tests
tools/                    screenshot harness and test music generator
```

## Ideas for later

- Read ID3/Vorbis tags for the label
- Remember where each tape was stopped, like a real cassette does
- A screen-off mode to save battery while listening
- Side B: flip the tape to play the folder in reverse
