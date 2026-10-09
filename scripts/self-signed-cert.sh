#!/usr/bin/env bash
# Writes a self-signed certificate and key to ./certs for trying out the HTTPS setup of
# docker-compose.build.yml. Browsers will warn about it; use a real certificate for anything
# beyond a test. Usage: scripts/self-signed-cert.sh [host-name]   (default: localhost)
set -euo pipefail

host="${1:-localhost}"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/certs"
mkdir -p "$dir"

openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -subj "/CN=${host}" \
  -addext "subjectAltName=DNS:${host},DNS:localhost,IP:127.0.0.1" \
  -keyout "$dir/privkey.pem" -out "$dir/fullchain.pem" 2>/dev/null \
  || openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=${host}" \
       -keyout "$dir/privkey.pem" -out "$dir/fullchain.pem" 2>/dev/null

chmod 600 "$dir/privkey.pem"
echo "Wrote $dir/fullchain.pem and $dir/privkey.pem for ${host}"
