#!/bin/sh
# HELP: Retro Cassette Player - a music player drawn as a cassette. Put music in a MUSIC folder on your SD card.
# ICON: retrocassette
# GRID: Cassette

# Follows the launcher of muOS's own LÖVE app (2048 Plus) in muOS 2606.
# The app's name and help text for the menu come from mux_lang.ini.

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$APP_DIR/game"
DATA_DIR="$APP_DIR/data"

mkdir -p "$DATA_DIR"
LOG="$DATA_DIR/log.txt"

# muOS helpers: config access, app setup (governor, SDL, foreground process) and CAFFEINE.
if [ -f /opt/muos/script/var/retro.sh ]; then
	. /opt/muos/script/var/stage.sh
	. /opt/muos/script/var/retro.sh
	. /opt/muos/script/var/service.sh
elif [ -f /opt/muos/script/var/func.sh ]; then
	. /opt/muos/script/var/func.sh
fi

# LÖVE runtime: one bundled in bin/, else the one muOS ships with 2048 Plus, else PATH.
MUOS_LOVE_DIR="${MUOS_SHARE_DIR:-/opt/muos/share}/application/2048 Plus/.game/bin"
LOVE=""
for DIR in "$APP_DIR/bin" "$MUOS_LOVE_DIR"; do
	if [ -x "$DIR/love" ]; then
		LOVE="$DIR/love"
		export LD_LIBRARY_PATH="$DIR/libs.aarch64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
		break
	fi
done
if [ -z "$LOVE" ] && command -v love >/dev/null 2>&1; then
	LOVE="$(command -v love)"
fi
if [ -z "$LOVE" ]; then
	echo "LOVE runtime not found. Copy love and libs.aarch64/ into $APP_DIR/bin" >"$LOG"
	exit 1
fi

if command -v SETUP_APP >/dev/null 2>&1; then
	command -v SETUP_STAGE_OVERLAY >/dev/null 2>&1 && SETUP_STAGE_OVERLAY
	SETUP_APP "love" ""
fi

# Where to look for music: the MUSIC folder on each SD card.
if command -v GET_VAR >/dev/null 2>&1; then
	RC_SD1_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
	RC_SD2_MOUNT="$(GET_VAR "device" "storage/sdcard/mount")"
	RC_MUSIC_MOUNTS="$RC_SD1_MOUNT:$RC_SD2_MOUNT"
	export RC_SD1_MOUNT RC_SD2_MOUNT RC_MUSIC_MOUNTS
fi

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
# Point SDL at the Mali EGL driver, as muOS does for its own LÖVE app.
for MALI in /usr/lib/libmali.so /usr/lib/aarch64-linux-gnu/libmali.so; do
	if [ -e "$MALI" ]; then
		export SDL_VIDEO_EGL_DRIVER="$MALI"
		export SDL_OPENGL_ES_DRIVER=1
		break
	fi
done

# Settings are kept next to the app. LÖVE's own save folder goes to /tmp (RAM),
# because SD cards (FAT/exFAT) can't hold the symlinks the app streams songs
# through; if /tmp isn't writable it falls back to the data folder.
export RC_DATA_DIR="$DATA_DIR"
LOVE_SAVE="/tmp/retrocassette"
mkdir -p "$LOVE_SAVE" 2>/dev/null || LOVE_SAVE="$DATA_DIR"
export XDG_DATA_HOME="$LOVE_SAVE"
export RC_FULLSCREEN=1

# Keep the device awake while the tape plays.
command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE on

cd "$GAME_DIR" || exit 1
"$LOVE" "$GAME_DIR" >"$LOG" 2>&1
STATUS=$?

command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE off
exit "$STATUS"
