# iptv-vod

An IPTV relay with a web console, split into two repositories that this one pulls in as
Git submodules:

| Path | Repository | Role |
|---|---|---|
| `submodules/iptv-rs/` | iptv-rs | Rust workspace; builds the `iptv-rs` binary. Parses and streams only. |
| `submodules/iptv-web/` | iptv-web | React + TypeScript console (简体/繁體/English, senior mode). Presents only. |
| `channels.yaml` | | Channel list, hot-reloaded by the relay. |
| `Dockerfile`, `docker-compose.yml`, `docker/` | | Container images and compose profiles. |
| `deploy/pm2/`, `deploy/nginx/` | | pm2 process file, host nginx reverse proxy. |
| `scripts/` | | Build, local run and one-click scripts. |
| `openspec/` | | Boundary constraints and change history. |

The two sides meet only at the relay's HTTP routes: `/list.m3u`, `/live/{ch}.m3u8`,
`/segment/{ch}/{id}.ts`, `/channels`, `/health`. The WASM assets in `submodules/iptv-rs/assets/` are
loaded from disk and checked against `manifest.json` at start; nothing from the console is
compiled into the binary.

## Get the code

```sh
git clone --recurse-submodules https://github.com/hsuyelin/iptv-vod.git
cd iptv-vod
# already cloned without submodules:
git submodule update --init --recursive
```

### Work without a remote

Keep `iptv-rs` and `iptv-web` checked out next to this repository and point the
submodules at them:

```sh
scripts/submodule-source.sh local --pull    # use ../iptv-rs and ../iptv-web
scripts/submodule-source.sh remote --pull   # back to the URLs in .gitmodules
scripts/submodule-source.sh status
```

Only `.git/config` changes; `.gitmodules` stays as committed. `--pull` also moves the
submodules to the newest commit of the chosen source (commit in the sibling repository
first; uncommitted changes are not picked up).

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
scripts/run-local.sh    # cleans dist/, rebuilds, runs; HOST/PORT/CHANNELS override, SKIP_BUILD=1 reuses dist
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
| `-v`, `-vv` | `RUST_LOG` | info | log detail: `-v` adds debug, `-vv` adds trace; `RUST_LOG` overrides |
| | `IPTV_ADMIN_KEY` | generated | administrator key, see below |

The relay refuses to start if the channel file has no valid channel or an asset does not
match `manifest.json`. A full work queue for a channel answers `429` with `Retry-After`.

## Administrator mode

A standard visit shows the channel list and nothing else: no page tabs. Add the
administrator key to the address (`http://host:8787/<key>`) and the **Channels** and
**Dashboard** tabs appear; opening the plain address again returns to a standard visit.

- **Choose the key** with the environment variable `IPTV_ADMIN_KEY` (12 or more letters,
  digits, `-` or `_`). If it is not set, the relay generates a 32-character key on every
  start and prints it once to the terminal (standard error), together with the address to
  open. The generated key is not written through the log, but anything that collects the
  terminal output (`docker compose logs`, `pm2 logs`) will hold it, so set the variable for
  managed deployments.
- **Guessing is limited.** The console posts the key to `POST /admin/verify` once per
  visit. After 5 wrong keys a client is locked out for 15 minutes, twice as long each time
  up to a day; 60 wrong keys from anyone within 10 minutes lock everything for 10 minutes.
  While a lock is active every attempt is refused, even with the right key. Wrong keys are
  answered after a short pause, the check is constant-time, and the nginx configs add a
  rate limit of one check per second per client. Behind a proxy on the same machine or
  network the client address is the one the proxy appended to `X-Forwarded-For`.
- **The key is in the address**, so it lands in the browser history. The relay and the
  bundled nginx configs keep such addresses out of their logs; other proxies you add may
  not. `/health`, `/channels` and the playlists stay public, as before.

## Logs

The relay logs with `tracing` to standard error. Every line has the time (UTC, to the
microsecond), the level, the thread, the module, the source file and line, the message and
its fields, for example:

```
2026-10-09T08:05:36.103794Z  WARN tokio-rt-worker iptv_server::app: crates/iptv-server/src/app.rs:205: request rejected id=2 method=POST path=/admin/verify route="/admin/verify" status=403 elapsed_ms=302 client=127.0.0.1
```

By default the relay's own crates log at `info` and everything else at `warn`. For
troubleshooting run with `-v` (debug: upstream fetches and timings, playlist windows,
cache decisions, queue waits, asset checks) or `-vv` (trace), or set `RUST_LOG`, for
example `RUST_LOG=iptv_upstream=trace,warn`. One line is logged per request; a console
address (which may hold the key) is shown as `<static>`. A panic is logged with its
location and a backtrace. Keys, tokens and guesses are never logged.

## Develop

```sh
cd submodules/iptv-rs  && just all    # fmt, clippy, test, doc, deps, names, cargo-deny
cd submodules/iptv-web && just all    # lint, typecheck, test, build, names
```

Install the tools with `brew install just cargo-deny` (or `cargo install just cargo-deny`).
Benchmarks: `cd submodules/iptv-rs && just bench`. Commits follow Conventional Commits.

## Acknowledgements

Thanks to the community around the original relay project and its authors, whose work on
the upstream protocol this code builds on. Questions and discussion happen in their
Telegram group: <http://t.me/iptvorganization>.

Thanks also to the maintainers of axum, tokio, wasmtime, React, Vite, TanStack Query,
hls.js and the other open-source projects used here.
