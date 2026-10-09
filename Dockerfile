# Multi-target image definition. Build context: the repository root with submodules
# checked out (`git submodule update --init --recursive`).
#   docker build --target all   -t iptv-vod       .   # relay + console in one image (default)
#   docker build --target relay -t iptv-vod-relay .   # relay only
#   docker build --target web   -t iptv-vod-web   .   # nginx: console + reverse proxy
#
# The `relay` and `all` images carry a static ffmpeg and offer the lighter stream for old Apple
# devices (?profile=compat) by default; run them with IPTV_COMPAT=off to switch it off. The
# ffmpeg build includes libx264, which is GPL licensed.

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

# The runtime image is `scratch` with a single layer: the binary, ffmpeg, the shared libraries and
# loader it needs, CA certificates, a minimal name-service configuration, the WASM assets
# and the channel list. Assets stay outside the binary and are verified at start.
# A static ffmpeg: no libraries to copy, nothing to install, and it runs from `scratch`.
FROM mwader/static-ffmpeg:7.1.1 AS ffmpeg

FROM relay-build AS rootfs
COPY channels.yaml /root-fs/app/channels.yaml
COPY --from=ffmpeg /ffmpeg /root-fs/app/ffmpeg
RUN set -eux; \
  mkdir -p /root-fs/tmp /root-fs/etc/ssl/certs; \
  cp /src/target/release/iptv-rs /root-fs/app/iptv-rs; \
  cp -r /src/assets /root-fs/app/assets; \
  copy_lib() { \
    lib="$(find /lib /usr/lib \( -type f -o -type l \) -name "$1" 2>/dev/null | head -n 1)"; \
    if [ -n "$lib" ]; then mkdir -p "/root-fs$(dirname "$lib")"; cp -L "$lib" "/root-fs$lib"; fi; \
  }; \
  for needed in $(readelf -d /src/target/release/iptv-rs | awk -F'[][]' '/NEEDED/ { print $2 }'); do \
    copy_lib "$needed"; \
  done; \
  for extra in libnss_dns.so.2 libnss_files.so.2 libresolv.so.2; do copy_lib "$extra"; done; \
  interp="$(readelf -l /src/target/release/iptv-rs | awk -F': ' '/interpreter/ { gsub(/]/, "", $2); print $2 }')"; \
  mkdir -p "/root-fs$(dirname "$interp")"; \
  cp -L "$interp" "/root-fs$interp"; \
  cp /etc/ssl/certs/ca-certificates.crt /root-fs/etc/ssl/certs/; \
  printf 'hosts: files dns\n' > /root-fs/etc/nsswitch.conf; \
  chmod 1777 /root-fs/tmp

# The same root file system with the console added.
FROM rootfs AS rootfs-all
COPY --from=web-build /web/dist /root-fs/app/web

# Relay only.
FROM scratch AS relay
COPY --from=rootfs /root-fs /
ENV IPTV_COMPAT_FFMPEG=/app/ffmpeg
EXPOSE 8787
ENTRYPOINT ["/app/iptv-rs"]
CMD ["--host", "0.0.0.0", "--port", "8787", "--channels", "/app/channels.yaml", "--assets-dir", "/app/assets"]

# Console behind nginx, which also proxies the relay routes to the `relay` host.
FROM nginx:1.29-alpine AS web
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/nginx-routes.conf /etc/nginx/iptv-routes.conf
COPY --from=web-build /web/dist /usr/share/nginx/html
EXPOSE 80

# Relay serving the console itself (default target).
FROM scratch AS all
COPY --from=rootfs-all /root-fs /
ENV IPTV_COMPAT_FFMPEG=/app/ffmpeg
EXPOSE 8787
ENTRYPOINT ["/app/iptv-rs"]
CMD ["--host", "0.0.0.0", "--port", "8787", "--channels", "/app/channels.yaml", "--assets-dir", "/app/assets", "--web-dir", "/app/web"]
