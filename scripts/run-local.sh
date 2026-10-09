#!/usr/bin/env bash
# Runs the relay and console in the foreground. HOST, PORT and CHANNELS override defaults.
set -euo pipefail
. "$(dirname "$0")/_common.sh"
[ -x "$DIST/bin/iptv-rs" ] || "$ROOT/scripts/build.sh"
echo "console: http://$HOST:$PORT/"
exec "$DIST/bin/iptv-rs" --host "$HOST" --port "$PORT" --channels "$CHANNELS" \
  --assets-dir "$DIST/assets" --web-dir "$DIST/web" "$@"
