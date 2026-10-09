#!/usr/bin/env bash
# Cleans dist/, rebuilds the relay and the console, then runs them in the foreground.
# HOST, PORT and CHANNELS override the defaults. SKIP_BUILD=1 restarts the existing build.
#
#   scripts/run-local.sh --compat    also serves the lighter stream (?profile=compat) for old
#                                    iPhones and iPads; needs an ffmpeg with libx264 (set FFMPEG
#                                    to use one that is not on the PATH)
#
# Any other argument goes to the relay as it is.
set -euo pipefail
. "$(dirname "$0")/_common.sh"

compat=0
relay_args=()
for arg in "$@"; do
  case "$arg" in
    --compat) compat=1 ;;
    *) relay_args+=("$arg") ;;
  esac
done

compat_args=()
if [ "$compat" = 1 ]; then
  # Look for it before the build, so a missing ffmpeg does not cost a build first.
  ffmpeg="${FFMPEG:-$(command -v ffmpeg || true)}"
  if [ -z "$ffmpeg" ] || [ ! -x "$ffmpeg" ]; then
    echo "--compat needs an ffmpeg with libx264: install one (brew install ffmpeg, apt install ffmpeg)" >&2
    echo "or point FFMPEG at it, for example FFMPEG=/opt/ffmpeg/bin/ffmpeg ${0##*/} --compat" >&2
    exit 1
  fi
  compat_args=(--compat-ffmpeg "$ffmpeg")
fi

if [ "${SKIP_BUILD:-0}" = 1 ] && [ -x "$DIST/bin/iptv-rs" ]; then
  echo "SKIP_BUILD=1: reusing $DIST"
else
  "$ROOT/scripts/build.sh"
fi

if [ "$compat" = 1 ]; then
  # A build from before the lighter stream existed would only fail with "unexpected argument".
  if ! "$DIST/bin/iptv-rs" --help 2>&1 | grep -q -- '--compat-ffmpeg'; then
    echo "$DIST/bin/iptv-rs is too old for --compat: run again without SKIP_BUILD=1 to rebuild it" >&2
    exit 1
  fi
  echo "compat stream: on (ffmpeg: $ffmpeg); open the console with ?compat=1 to try it on a device"
fi
echo "console: http://$HOST:$PORT/"
exec "$DIST/bin/iptv-rs" --host "$HOST" --port "$PORT" --channels "$CHANNELS" \
  --assets-dir "$DIST/assets" --web-dir "$DIST/web" \
  ${compat_args[@]+"${compat_args[@]}"} ${relay_args[@]+"${relay_args[@]}"}
