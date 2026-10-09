#!/usr/bin/env bash
# Builds the relay and the console into dist/{bin,assets,web}.
set -euo pipefail
. "$(dirname "$0")/_common.sh"
init_submodules
need cargo
need npm

(cd "$ROOT/iptv-rs" && cargo build --release --locked -p iptv-server)
(cd "$ROOT/iptv-web" && npm ci && npm run build)

rm -rf "$DIST"
mkdir -p "$DIST/bin"
cp "$ROOT/iptv-rs/target/release/iptv-rs" "$DIST/bin/iptv-rs"
cp -R "$ROOT/iptv-rs/assets" "$DIST/assets"
cp -R "$ROOT/iptv-web/dist" "$DIST/web"
echo "built: $DIST"
