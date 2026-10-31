#!/bin/sh
# Runs the app headless with scripted input and saves screenshots.
# Needs: love (11.x), xvfb-run, python3.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A small library of made-up albums. The audio is three test tones reused.
mkdir -p "$WORK/tones"
python3 "$ROOT/tools/make_test_music.py" "$WORK/tones"
set -- "$WORK"/tones/*.wav
TONE1=$1 TONE2=$2 TONE3=$3

album() {
	DIR="$WORK/MUSIC/$1"
	shift
	mkdir -p "$DIR"
	N=0
	for SONG in "$@"; do
		N=$((N + 1))
		case $((N % 3)) in 1) T=$TONE1 ;; 2) T=$TONE2 ;; *) T=$TONE3 ;; esac
		cp "$T" "$DIR/$(printf '%02d' "$N") - $SONG.wav"
	done
}

album "After Hours Jazz Club" "Smoke Rings" "Blue Note Boulevard" "Last Call"
album "Backseat Summer" "Sunburn" "Ice Cream Truck" "Fireflies"
album "Coastal Drive" "Morning Tide" "Salt and Sun" "Lighthouse" "Harbour Lights" "Last Ferry Home"
album "Garage Band Demos" "Three Chords" "Feedback Loop" "Basement Tapes"
album "Kitchen Radio" "Toast and Jam" "Sunday Paper" "Kettle Song"
album "Midnight Synth" "Neon Rain" "Chrome Hearts" "Night Drive on the Neon Highway (Extended Version)" "Laser Grid"
album "Road Trip Mixtape" "Open Road" "Gas Station Coffee" "Motel Sign"
album "Sunday Morning" "Slow Light" "Pancakes" "Window Seat"
album "Zero Gravity" "Liftoff" "Orbit" "Splashdown"

OUT="${XDG_DATA_HOME:-$HOME/.local/share}/love/rc-harness"
rm -rf "$OUT"

GAME="$ROOT/RetroCassette/game" RC_MUSIC_DIR="$WORK/MUSIC" ALSOFT_DRIVERS=null \
	xvfb-run -a -s "-screen 0 720x480x24" love "$ROOT/tools/harness" 2>&1 | grep -v '^ALSA' || true

ls "$OUT"/*.png
