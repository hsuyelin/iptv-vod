<h1 align="center">iptv-vod</h1>
<h3 align="center">The IPTV relay and web console, ready to deploy</h3>

---

<p align="center">
<img alt="iptv-vod" src="branding/banner.svg" width="560"/>
<br/>
<br/>
<a href="https://github.com/hsuyelin/iptv-vod/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/hsuyelin/iptv-vod.svg"/></a>
<a href="https://github.com/hsuyelin/iptv-vod/commits/main"><img alt="Last Commit" src="https://img.shields.io/github/last-commit/hsuyelin/iptv-vod.svg"/></a>
<br/>
<img alt="Rust" src="https://img.shields.io/badge/Rust-backend-DEA584?logo=rust&logoColor=white"/>
<img alt="TypeScript" src="https://img.shields.io/badge/TypeScript-frontend-3178C6?logo=typescript&logoColor=white"/>
<img alt="React" src="https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black"/>
<img alt="Docker" src="https://img.shields.io/badge/Docker-compose-2496ED?logo=docker&logoColor=white"/>
</p>

---

iptv-vod is an IPTV relay with a web console, published as the Docker image [`hsuyelin/iptv-vod`](https://hub.docker.com/r/hsuyelin/iptv-vod) (`linux/amd64`, `linux/arm64`) and as binaries for Linux and macOS. It combines [iptv-rs](https://github.com/hsuyelin/iptv-rs), the relay, with [iptv-web](https://github.com/hsuyelin/iptv-web), the console.

<strong>Want to get started?</strong><br/>
Jump to <a href="#quick-start">Quick Start</a>.<br/>

<strong>Something not working right?</strong><br/>
Open an <a href="https://github.com/hsuyelin/iptv-vod/issues">Issue</a> on GitHub.<br/>

<strong>Questions or ideas?</strong><br/>
Join the community on <a href="http://t.me/iptvorganization">Telegram</a>.<br/>

---

## Quick Start

### Docker Compose

```bash
curl -fLO https://raw.githubusercontent.com/hsuyelin/iptv-vod/main/docker-compose.yml
curl -fL https://raw.githubusercontent.com/hsuyelin/iptv-vod/main/.env.example -o .env
curl -fLO https://raw.githubusercontent.com/hsuyelin/iptv-vod/main/channels.yaml
docker compose up -d
```

Edit `.env` first if you want to change the port or set an administrator key.

| File | Purpose |
|---|---|
| `docker-compose.yml` | Service definition: read-only root file system, health check, log rotation. Every value comes from `.env` |
| `.env` (from `.env.example`) | Settings, listed below |
| `channels.yaml` | Channel list, mounted read-only and reloaded without a restart |

### Docker

```bash
docker run -d --name iptv-vod -p 8787:8787 \
  -e IPTV_ADMIN_KEY=change-me-please \
  hsuyelin/iptv-vod:latest
```

Add `-v "$PWD/channels.yaml:/app/channels.yaml:ro"` to use your own channel list.

### Binary

Download the package for your system from the [releases](https://github.com/hsuyelin/iptv-vod/releases) (`linux-amd64`, `linux-arm64`, `macos-amd64` or `macos-arm64`), check it against `SHA256SUMS`, then run:

```bash
tar -xzf iptv-vod-*-linux-amd64.tar.gz && cd iptv-vod-*-linux-amd64
./iptv-rs --host 0.0.0.0 --port 8787 --channels channels.yaml --assets-dir assets --web-dir web
```

Open `http://127.0.0.1:8787/`. The playlist for players is `http://<host>:8787/list.m3u`.

## Configuration

### Environment (`.env`)

| Variable | Default | Meaning |
|---|---|---|
| `IPTV_IMAGE` | `hsuyelin/iptv-vod:latest` | Image to run |
| `IPTV_CONTAINER_NAME`, `IPTV_HOSTNAME` | `iptv-vod` | Container name and host name |
| `RESTART_POLICY` | `unless-stopped` | Docker restart policy |
| `NOFILE_LIMIT` | `65536` | Open file limit |
| `TZ` | `Asia/Shanghai` | Time zone |
| `SERVICE_NETWORK_NAME` | `iptv_net` | Docker network name |
| `BIND_HOST` | `127.0.0.1` | Address to publish on; use `0.0.0.0` to reach it from other machines |
| `IPTV_HOST_PORT` | `8787` | Published port |
| `IPTV_CHANNELS_FILE` | `./channels.yaml` | Channel list on the host |
| `IPTV_ADMIN_KEY` | empty | Administrator key; if empty, one is generated at every start and printed in `docker compose logs` |
| `RUST_LOG` | `info` | Log filter, such as `debug` or `iptv_upstream=trace,warn` |
| `IPTV_HEALTH_INTERVAL`, `IPTV_HEALTH_TIMEOUT`, `IPTV_HEALTH_RETRIES`, `IPTV_HEALTH_START_PERIOD` | `30s`, `5s`, `3`, `15s` | Health check timing |
| `LOG_MAX_SIZE`, `LOG_MAX_FILE` | `10m`, `3` | Log rotation |

### Binary options

| Flag | Environment | Default | Meaning |
|---|---|---|---|
| `--host`, `--port` | | `127.0.0.1`, `8787` | Listen address |
| `--channels` | | `/app/channels.yaml` | Channel list, reloaded on change |
| `--assets-dir` | `IPTV_ASSETS_DIR` | `./assets` | WASM assets, SHA-256 verified at start |
| `--web-dir` | `IPTV_WEB_DIR` | off | Serve the console from this directory |
| `-v`, `-vv` | `RUST_LOG` | `info` | Log detail |
| | `IPTV_ADMIN_KEY` | generated | Administrator key |

### Administrator mode

A standard visit shows the channel list only. Open `http://host:8787/<key>` to reveal the **Channels** and **Dashboard** tabs. The key needs 12 or more letters, digits, `-` or `_`. After 5 wrong keys a client is locked out for 15 minutes, and the lockout grows up to a day.

## Acknowledgements

Thanks to the community and the authors of the original relay project, whose work on the upstream protocol this code builds on. Join the discussion in the Telegram group: <http://t.me/iptvorganization>.

Thanks also to the maintainers of axum, tokio, wasmtime, React, Vite, TanStack Query, hls.js and the other open-source projects used here.
