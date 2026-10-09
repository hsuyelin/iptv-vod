#!/usr/bin/env bash
# One command to get running: scripts/one-click.sh [auto|docker|docker-nginx|pm2|local]
# `local` takes the options of run-local.sh, such as: scripts/one-click.sh local --compat
# auto prefers Docker, then pm2, then a foreground local run.
set -euo pipefail
. "$(dirname "$0")/_common.sh"
mode="${1:-auto}"
init_submodules
cd "$ROOT"

if [ "$mode" = auto ]; then
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then mode=docker
  elif command -v pm2 >/dev/null 2>&1; then mode=pm2
  else mode=local; fi
fi

case "$mode" in
  docker)
    docker compose -f docker-compose.build.yml --profile single up -d --build
    echo "console: http://127.0.0.1:${PORT}/" ;;
  docker-nginx)
    # nginx also listens on HTTPS and needs a certificate; make a self-signed one to start with.
    if [ ! -f certs/fullchain.pem ] || [ ! -f certs/privkey.pem ]; then
      scripts/self-signed-cert.sh
    fi
    docker compose -f docker-compose.build.yml --profile split up -d --build
    echo "console: http://127.0.0.1:${WEB_PORT:-8080}/  https://127.0.0.1:${WEB_HTTPS_PORT:-8443}/" ;;
  pm2)
    need pm2
    "$ROOT/scripts/build.sh"
    pm2 start "$ROOT/deploy/pm2/ecosystem.config.cjs"
    echo "console: http://$HOST:$PORT/   (pm2 save && pm2 startup to survive reboots)" ;;
  local)
    exec "$ROOT/scripts/run-local.sh" "${@:2}" ;;
  *)
    echo "usage: $0 [auto|docker|docker-nginx|pm2|local]" >&2; exit 2 ;;
esac
