#!/bin/sh
# Builds dist/RetroCassette-<version>.muxapp, a zip with the RetroCassette folder at its root.
# Usage: scripts/package.sh [version]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP=RetroCassette
VERSION="${1:-$(git -C "$ROOT" describe --tags --always 2>/dev/null || echo dev)}"
OUT="$ROOT/dist/$APP-$VERSION.muxapp"

if [ ! -x "$ROOT/$APP/bin/love" ]; then
	echo "warning: $APP/bin/love is missing; the package will rely on a LÖVE runtime already on the device" >&2
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$ROOT/$APP" "$STAGE/"
rm -rf "$STAGE/$APP/data"
rm -f "$STAGE/$APP/bin/README.md"
chmod +x "$STAGE/$APP/mux_launch.sh"

mkdir -p "$ROOT/dist"
rm -f "$OUT"
(cd "$STAGE" && zip -qr "$OUT" "$APP")
echo "$OUT"
