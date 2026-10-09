# Proposal

## Why

The relay is one 6.3k-line crate where HTTP handling, upstream signing, WASM hosting, TS
parsing and playlist building share one module namespace, and where 2.5 MB of WASM/JS is
compiled into the binary with `include_bytes!`. Consequences measured in the code:

- TS decrypt/remux cannot be unit-tested or benchmarked without linking wasmtime, axum and
  reqwest, because `ts_decrypt`/`ts_remux` take a concrete `CmgRuntime`.
- Every `CmgRuntime::load_for_page`, `build_ticket` and keygen call recreates a wasmtime
  `Engine`, recompiles the module, and (for CMG) base64-decodes and re-parses the 1.3 MB
  worker script. This runs per channel and per signed request.
- `ChannelDirectory::load` re-reads and re-parses the YAML on every HTTP request; the
  stats and notice cache sit behind async mutexes; a tokio mutex guard is held across
  `.await` while a segment is processed.
- There is no UI at all, so operators read raw JSON from `/health` and `/channels`.

## What Changes

- Convert `src/` into a Cargo workspace at `backend/` with four crates (see design.md):
  `ysp-media` (pure parsing/remux/playlist), `ysp-wasm` (WASM hosts), `ysp-upstream`
  (signing, API flow control, channel pipeline), `ysp-server` (axum binary `iptv-rust`).
- Stop embedding assets: WASM and worker files move to `backend/assets/` and are loaded
  from a configurable directory at startup, integrity-checked against a manifest, and
  compiled once and shared.
- Add a new `frontend/` (React 19 + TypeScript + Vite) web console: channel browser, live
  player, relay health. It talks to the existing JSON/HLS routes only.
- Make hot paths cheaper: borrowed TS packet views, one-time WASM compile, in-memory
  channel index with change-detected reload, atomic counters, per-channel work queue
  instead of a lock held over `.await`, CPU-bound work off the async executor.
- Add unit tests per crate and `criterion` benchmarks for the hot paths.
- Rename Service-Locator-flavoured names (`resolve_ch`, `resolve_func_index`, ...).
- **BREAKING (deployment only)**: the server needs `--assets-dir` (default `./assets`);
  the Docker image layout changes. HTTP routes and payloads are unchanged.

## Capabilities

### New Capabilities

- `stream-relay`: the frozen HTTP contract for playlists, segments, channel listing,
  health, fallback notice and overload behavior.
- `media-processing`: TS demux, decrypt, remux and playlist generation behavior and its
  performance budget.
- `runtime-assets`: how WASM/worker assets are located, verified and shared.
- `web-console`: the operator UI behavior and presentation constraints.
- `workspace-boundaries`: crate dependency direction, naming and quality gates.

### Modified Capabilities

None (`openspec/specs/` is empty).

## Impact

- Code: every file under `src/` moves; `Dockerfile` rewritten (also fixes its stale
  `rust-src/` paths); new `frontend/`; new `openspec/`.
- Dependencies added: `criterion`, `sha2` (backend); React, Vite, TanStack
  Query, hls.js, Vitest (frontend).
- Out of scope: new upstream features, auth, persistence, changing the media output format.
