# Sourced by the other scripts.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8787}"
CHANNELS="${CHANNELS:-$ROOT/channels.yaml}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }

init_submodules() {
  if [ ! -f "$ROOT/iptv-rs/Cargo.toml" ] || [ ! -f "$ROOT/iptv-web/package.json" ]; then
    need git
    git -C "$ROOT" submodule update --init --recursive
  fi
}
