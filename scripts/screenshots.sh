#!/bin/sh
# Runs the app headless with scripted input and saves screenshots.
# Needs: love (11.x), xvfb-run, python3.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/MUSIC/Synthwave Mixtape"
python3 "$ROOT/tools/make_test_music.py" "$WORK/MUSIC/Synthwave Mixtape"

OUT="${XDG_DATA_HOME:-$HOME/.local/share}/love/rc-harness"
rm -rf "$OUT"

GAME="$ROOT/RetroCassette/game" RC_MUSIC_DIR="$WORK/MUSIC" ALSOFT_DRIVERS=null \
	xvfb-run -a -s "-screen 0 640x480x24" love "$ROOT/tools/harness" 2>&1 | grep -v '^ALSA' || true

ls "$OUT"/*.png
