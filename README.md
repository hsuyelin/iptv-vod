<h1 align="center">iptv-vod</h1>
<h3 align="center">The IPTV relay and web console, ready to deploy</h3>

---

<p align="center">
<img alt="iptv-vod" src="branding/banner.svg" width="560"/>
<br/>
<br/>
<a href="https://github.com/hsuyelin/iptv-vod/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/hsuyelin/iptv-vod.svg"/></a>
<a href="https://github.com/hsuyelin/iptv-vod/commits/main"><img alt="Last Commit" src="https://img.shields.io/github/last-commit/hsuyelin/iptv-vod.svg"/></a>
<a href="http://t.me/iptvorganization"><img alt="Chat on Telegram" src="https://img.shields.io/badge/chat-telegram-26A5E4?logo=telegram&logoColor=white"/></a>
<br/>
<img alt="Rust" src="https://img.shields.io/badge/Rust-backend-DEA584?logo=rust&logoColor=white"/>
<img alt="TypeScript" src="https://img.shields.io/badge/TypeScript-frontend-3178C6?logo=typescript&logoColor=white"/>
<img alt="React" src="https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black"/>
<img alt="Docker" src="https://img.shields.io/badge/Docker-compose-2496ED?logo=docker&logoColor=white"/>
<img alt="Nginx" src="https://img.shields.io/badge/Nginx-proxy-009639?logo=nginx&logoColor=white"/>
<img alt="PM2" src="https://img.shields.io/badge/PM2-process-2B037A?logo=pm2&logoColor=white"/>
<img alt="English" src="https://img.shields.io/badge/lang-English-555"/>
<img alt="简体中文" src="https://img.shields.io/badge/lang-简体中文-555"/>
<img alt="繁體中文" src="https://img.shields.io/badge/lang-繁體中文-555"/>
</p>

---

iptv-vod is an IPTV relay with a web console. It packages two projects as Git submodules and ships everything needed to run them: [iptv-rs](https://github.com/hsuyelin/iptv-rs), a Rust relay that parses and streams, and [iptv-web](https://github.com/hsuyelin/iptv-web), a React console that only presents. The two meet only at the relay's HTTP routes.

Run it with Docker, pm2, nginx or plain scripts. Add `/<key>` to the address to unlock the administrator tabs.

<strong>Want to get started?</strong><br/>
Jump to <a href="#quick-start">Quick Start</a>.<br/>

<strong>Something not working right?</strong><br/>
Open an <a href="https://github.com/hsuyelin/iptv-vod/issues">Issue</a> on GitHub.<br/>

<strong>Want to contribute?</strong><br/>
Read <a href="#development">Development</a>, then open a pull request. Commits follow <a href="https://www.conventionalcommits.org">Conventional Commits</a>.<br/>

<strong>Questions or ideas?</strong><br/>
Join the community on <a href="http://t.me/iptvorganization">Telegram</a>.<br/>

---

## Quick Start

```bash
git clone --recurse-submodules https://github.com/hsuyelin/iptv-vod.git
cd iptv-vod
scripts/one-click.sh      # or: auto | docker | docker-nginx | pm2 | local
```

Open `http://127.0.0.1:8787/` (`:8080` for `docker-nginx`). The playlist for players is `http://<host>:8787/list.m3u`.

If you cloned without submodules, run `git submodule update --init --recursive`.

## Deployment

### Docker

```bash
docker compose --profile single up -d --build   # relay and console on :8787
docker compose --profile split  up -d --build   # nginx on :8080 in front of the relay
```

Edit `channels.yaml` on the host. It is mounted read-only and reloaded without a restart. Set `PORT` and `WEB_PORT` to change the published ports.

### Local

Requires Rust 1.96+ and Node.js 20+.

```bash
scripts/build.sh        # builds dist/
scripts/run-local.sh    # cleans, rebuilds and runs; SKIP_BUILD=1 reuses dist/
```

### pm2

```bash
scripts/build.sh
pm2 start deploy/pm2/ecosystem.config.cjs
pm2 save && pm2 startup
```

### Nginx

Run the relay on `127.0.0.1:8787`, copy `dist/web` to `/srv/iptv-vod/web`, install `deploy/nginx/iptv-vod.conf` as `/etc/nginx/conf.d/iptv-vod.conf`, then reload nginx. The config forwards `Host` and `X-Forwarded-*`, which the relay uses to write absolute segment URLs. Add TLS to the `server` block as usual.

## Configuration

| Flag | Environment | Default | Meaning |
|---|---|---|---|
| `--host`, `--port` | | `127.0.0.1`, `8787` | Listen address (the scripts read `HOST`, `PORT`) |
| `--channels` | | `/app/channels.yaml` | Channel list, reloaded on change (the scripts read `CHANNELS`) |
| `--assets-dir` | `IPTV_ASSETS_DIR` | `./assets` | WASM assets, SHA-256 verified at start |
| `--web-dir` | `IPTV_WEB_DIR` | off | Serve a built console from this directory |
| `-v`, `-vv` | `RUST_LOG` | `info` | Log detail |
| | `IPTV_ADMIN_KEY` | generated | Administrator key |

### Administrator Mode

A standard visit shows the channel list only. Open `http://host:8787/<key>` to reveal the **Channels** and **Dashboard** tabs.

- Set the key with `IPTV_ADMIN_KEY` (12 or more letters, digits, `-` or `_`). If it is unset, a 32-character key is generated at every start and printed once to standard error. Set the variable for managed deployments, since `docker compose logs` and `pm2 logs` keep the terminal output.
- After 5 wrong keys a client is locked out for 15 minutes, doubling up to a day. 60 wrong keys from anyone within 10 minutes lock all attempts for 10 minutes.
- The key is part of the address and lands in browser history. The relay and the bundled nginx configs keep such addresses out of their logs.

### Logs

The relay logs with `tracing` to standard error: time (UTC), level, thread, module, source file and line, message and fields.

```
2026-10-09T08:05:36.103794Z  WARN tokio-rt-worker iptv_server::app: crates/iptv-server/src/app.rs:205: request rejected id=2 method=POST path=/admin/verify status=403 elapsed_ms=302
```

Run with `-v` for debug, `-vv` for trace, or set `RUST_LOG`, for example `RUST_LOG=iptv_upstream=trace,warn`. Keys, tokens and guesses are never logged.

## Development

```bash
git submodule update --init --remote --merge   # newest main of each submodule

cd submodules/iptv-rs  && just all    # fmt, clippy, test, doc, deps, names, cargo-deny
cd submodules/iptv-web && just all    # lint, typecheck, test, build, names
```

Install the tools with `brew install just cargo-deny`. After changing a submodule, push it first, then commit the bumped pointers here.

## Acknowledgements

Thanks to the community and the authors of the original relay project, whose work on the upstream protocol this code builds on. Join the discussion in the Telegram group: <http://t.me/iptvorganization>.

Thanks also to the maintainers of axum, tokio, wasmtime, React, Vite, TanStack Query, hls.js and the other open-source projects used here.
