#!/bin/sh
# HELP: Retro Cassette - a music player drawn as a spinning cassette tape. Put music in /mnt/sdcard/MUSIC or /mnt/mmc/MUSIC.
# ICON: music
# GRID: Cassette

# muOS helper: sets up SDL, the CPU governor, HOME and the SD card mounts.
# Keep this line when muOS provides it.
if [ -f /opt/muos/script/var/func.sh ]; then
	. /opt/muos/script/var/func.sh
fi

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$APP_DIR/game"
DATA_DIR="$APP_DIR/data"

mkdir -p "$DATA_DIR"
LOG="$DATA_DIR/log.txt"

# Prefer a LÖVE runtime bundled with the app, then one on PATH.
if [ -x "$APP_DIR/bin/love" ]; then
	LOVE="$APP_DIR/bin/love"
	export LD_LIBRARY_PATH="$APP_DIR/bin/libs.aarch64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
elif command -v love >/dev/null 2>&1; then
	LOVE="$(command -v love)"
else
	echo "LOVE runtime not found. Copy love and libs.aarch64/ into $APP_DIR/bin" >"$LOG"
	exit 1
fi

# Keep settings next to the app instead of in the shared home folder.
export XDG_DATA_HOME="$DATA_DIR"
export RC_FULLSCREEN=1

cd "$GAME_DIR" || exit 1
"$LOVE" "$GAME_DIR" >"$LOG" 2>&1
