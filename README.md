# iptv-vod

An IPTV relay with a web console, split into two repositories that this one pulls in as
Git submodules:

| Path | Repository | Role |
|---|---|---|
| `iptv-rs/` | iptv-rs | Rust workspace; builds the `iptv-rs` binary. Parses and streams only. |
| `iptv-web/` | iptv-web | React + TypeScript console. Presents only. |
| `channels.yaml` | | Channel list, hot-reloaded by the relay. |
| `Dockerfile`, `docker-compose.yml`, `docker/` | | Container images and compose profiles. |
| `deploy/pm2/`, `deploy/nginx/` | | pm2 process file, host nginx reverse proxy. |
| `scripts/` | | Build, local run and one-click scripts. |
| `openspec/` | | Boundary constraints and change history. |

The two sides meet only at the relay's HTTP routes: `/list.m3u`, `/live/{ch}.m3u8`,
`/segment/{ch}/{id}.ts`, `/channels`, `/health`. The WASM assets in `iptv-rs/assets/` are
loaded from disk and checked against `manifest.json` at start; nothing from the console is
compiled into the binary.

## Get the code

```sh
git clone --recurse-submodules https://github.com/hsuyelin/iptv-vod.git
cd iptv-vod
# already cloned without submodules:
git submodule update --init --recursive
```

## Run it

The quickest way, which picks Docker, then pm2, then a plain foreground run:

```sh
scripts/one-click.sh            # or: auto | docker | docker-nginx | pm2 | local
```

Then open `http://127.0.0.1:8787/` (`:8080` for `docker-nginx`). Playlist for players:
`http://<host>:8787/list.m3u`.

### Docker

```sh
docker compose --profile single up -d --build   # relay + console on :8787
docker compose --profile split  up -d --build   # nginx on :8080 in front of the relay
```

`Dockerfile` has three targets: `all` (default, relay + console), `relay` (API only) and
`web` (nginx with the console and the reverse proxy from `docker/nginx.conf`). Edit
`channels.yaml` on the host; it is mounted read-only and reloaded without a restart. Set
`PORT` / `WEB_PORT` to change the published ports.

### Local (no container)

Needs Rust 1.96+ and Node 20+ (Node 24 is used in the image).

```sh
scripts/build.sh        # -> dist/bin/iptv-rs, dist/assets, dist/web
scripts/run-local.sh    # HOST=0.0.0.0 PORT=8787 CHANNELS=/path/channels.yaml to override
```

### pm2

```sh
scripts/build.sh
pm2 start deploy/pm2/ecosystem.config.cjs
pm2 save && pm2 startup          # restart on reboot
```

`HOST`, `PORT` and `CHANNELS` are read from the environment when pm2 starts. Remove the
`--web-dir` argument in the file if nginx serves the console.

### Nginx in front of a host-run relay

Run the relay bound to `127.0.0.1:8787` (pm2 or `run-local.sh`), copy `dist/web` to
`/srv/iptv-vod/web`, install `deploy/nginx/iptv-vod.conf` as
`/etc/nginx/conf.d/iptv-vod.conf`, then `nginx -t && nginx -s reload`. The config forwards
`Host` and `X-Forwarded-*`, which the relay uses to write absolute segment URLs. Add TLS
to the `server` block as usual (`X-Forwarded-Proto` follows `$scheme`).

## Relay options

| Flag | Env | Default | Meaning |
|---|---|---|---|
| `--host`, `--port` | | `127.0.0.1`, `8787` | listen address |
| `--channels` | | `/app/channels.yaml` | channel list, reloaded when it changes |
| `--assets-dir` | `IPTV_ASSETS_DIR` | `./assets` | WASM assets, SHA-256 verified at start |
| `--web-dir` | `IPTV_WEB_DIR` | off | serve a built console from this directory |
| `--verbose` | | off | log at info level |

The relay refuses to start if the channel file has no valid channel or an asset does not
match `manifest.json`. A full work queue for a channel answers `429` with `Retry-After`.

## Develop

```sh
cd iptv-rs  && just all    # fmt, clippy, test, doc, deps, names, cargo-deny
cd iptv-web && just all    # lint, typecheck, test, build, names
```

Install the tools with `brew install just cargo-deny` (or `cargo install just cargo-deny`).
Benchmarks: `cd iptv-rs && just bench`. Commits follow Conventional Commits.

## Acknowledgements

Thanks to the community around the original relay project and its authors, whose work on
the upstream protocol this code builds on. Questions and discussion happen in their
Telegram group: <http://t.me/iptvorganization>.

Thanks also to the maintainers of axum, tokio, wasmtime, React, Vite, TanStack Query,
hls.js and the other open-source projects used here.
