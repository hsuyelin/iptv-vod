#!/usr/bin/env bash
# Chooses where the iptv-rs and iptv-web submodules come from on this machine.
#   scripts/submodule-source.sh status
#   scripts/submodule-source.sh local  [--pull]   sibling checkouts (../iptv-rs, ../iptv-web)
#   scripts/submodule-source.sh remote [--pull]   URLs recorded in .gitmodules
# Only .git/config changes; the committed .gitmodules is never touched.
# --pull also moves each submodule to the newest commit of the chosen source.
set -euo pipefail
. "$(dirname "$0")/_common.sh"
need git
cd "$ROOT"
modules=(iptv-rs iptv-web)

show() {
  for m in "${modules[@]}"; do
    local effective declared
    effective="$(git config --get "submodule.$m.url" || true)"
    declared="$(git config -f .gitmodules --get "submodule.$m.url")"
    if [ "$effective" = "$declared" ]; then
      echo "$m: remote ($declared)"
    else
      echo "$m: local ($effective)"
    fi
  done
}

mode="${1:-status}"
pull="${2:-}"
case "$mode" in
  status) show; exit 0 ;;
  local)
    for m in "${modules[@]}"; do
      [ -d "$ROOT/../$m/.git" ] || { echo "missing sibling checkout: $ROOT/../$m" >&2; exit 1; }
    done
    # `sync` copies the URLs from .gitmodules, so the override comes after it.
    git submodule sync --quiet
    for m in "${modules[@]}"; do git config "submodule.$m.url" "../$m"; done
    ;;
  remote)
    git submodule sync --quiet ;;
  *) echo "usage: $0 status|local|remote [--pull]" >&2; exit 2 ;;
esac

# Point each submodule's own `origin` at the new source so later pulls follow it.
for m in "${modules[@]}"; do
  if [ -e "$ROOT/$m/.git" ]; then
    git -C "$ROOT/$m" remote set-url origin "$(git config --get "submodule.$m.url")"
  fi
done
if [ "$pull" = "--pull" ]; then
  # Git refuses local paths as submodule sources unless the file transport is allowed.
  git -c protocol.file.allow=always submodule update --init --remote --merge
fi
show
