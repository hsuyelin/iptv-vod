# Multi-target image definition. Build context: the repository root with submodules
# checked out (`git submodule update --init --recursive`).
#   docker build --target all   -t iptv-vod       .   # relay + console in one image (default)
#   docker build --target relay -t iptv-vod-relay .   # relay only
#   docker build --target web   -t iptv-vod-web   .   # nginx: console + reverse proxy

FROM node:24-bookworm-slim AS web-build
WORKDIR /web
COPY submodules/iptv-web/package.json submodules/iptv-web/package-lock.json ./
RUN npm ci
COPY submodules/iptv-web/ ./
RUN npm run build

FROM rust:1.96-bookworm AS relay-build
# Use the image's own toolchain instead of the `stable` channel in rust-toolchain.toml.
ENV RUSTUP_TOOLCHAIN=1.96.0
WORKDIR /src
COPY submodules/iptv-rs/ ./
RUN cargo build --release --locked -p iptv-server

# The relay image is `scratch`: copy the binary with the shared libraries and loader it
# needs, CA certificates and a minimal name-service configuration.
FROM relay-build AS relay-root
RUN set -eux; \
  mkdir -p /root-fs/app /root-fs/tmp /root-fs/etc/ssl/certs; \
  cp /src/target/release/iptv-rs /root-fs/app/iptv-rs; \
  readelf -d /src/target/release/iptv-rs \
    | awk -F'[][]' '/NEEDED/ { print $2 }' \
    | while read -r needed; do \
        lib="$(find /lib /usr/lib \( -type f -o -type l \) -name "$needed" 2>/dev/null | head -n 1)"; \
        test -n "$lib"; \
        mkdir -p "/root-fs$(dirname "$lib")"; \
        cp -L "$lib" "/root-fs$lib"; \
      done; \
  for extra in libnss_dns.so.2 libnss_files.so.2 libresolv.so.2; do \
        lib="$(find /lib /usr/lib \( -type f -o -type l \) -name "$extra" 2>/dev/null | head -n 1)"; \
        if [ -n "$lib" ]; then \
          mkdir -p "/root-fs$(dirname "$lib")"; \
          cp -L "$lib" "/root-fs$lib"; \
        fi; \
      done; \
  interp="$(readelf -l /src/target/release/iptv-rs | awk -F': ' '/interpreter/ { gsub(/]/, "", $2); print $2 }')"; \
  mkdir -p "/root-fs$(dirname "$interp")"; \
  cp -L "$interp" "/root-fs$interp"; \
  cp /etc/ssl/certs/ca-certificates.crt /root-fs/etc/ssl/certs/ca-certificates.crt; \
  printf 'hosts: files dns\n' > /root-fs/etc/nsswitch.conf; \
  chmod 0755 /root-fs/app/iptv-rs; \
  chmod 1777 /root-fs/tmp

# Relay only. WASM assets stay outside the binary and are verified at start.
FROM scratch AS relay
COPY --from=relay-root /root-fs /
COPY channels.yaml /app/channels.yaml
COPY submodules/iptv-rs/assets /app/assets
WORKDIR /app
EXPOSE 8787
ENTRYPOINT ["/app/iptv-rs"]
CMD ["--host", "0.0.0.0", "--port", "8787", "--channels", "/app/channels.yaml", "--assets-dir", "/app/assets"]

# Console behind nginx, which also proxies the relay routes to the `relay` host.
FROM nginx:1.29-alpine AS web
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=web-build /web/dist /usr/share/nginx/html
EXPOSE 80

# Relay serving the console itself (default target).
FROM relay AS all
COPY --from=web-build /web/dist /app/web
CMD ["--host", "0.0.0.0", "--port", "8787", "--channels", "/app/channels.yaml", "--assets-dir", "/app/assets", "--web-dir", "/app/web"]
