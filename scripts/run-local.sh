#!/usr/bin/env bash
# Cleans dist/, rebuilds the relay and the console, then runs them in the foreground.
# HOST, PORT and CHANNELS override the defaults. SKIP_BUILD=1 restarts the existing build.
set -euo pipefail
. "$(dirname "$0")/_common.sh"
if [ "${SKIP_BUILD:-0}" = 1 ] && [ -x "$DIST/bin/iptv-rs" ]; then
  echo "SKIP_BUILD=1: reusing $DIST"
else
  "$ROOT/scripts/build.sh"
fi
echo "console: http://$HOST:$PORT/"
exec "$DIST/bin/iptv-rs" --host "$HOST" --port "$PORT" --channels "$CHANNELS" \
  --assets-dir "$DIST/assets" --web-dir "$DIST/web" "$@"
