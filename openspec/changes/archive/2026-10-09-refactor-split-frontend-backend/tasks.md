## 1. Workspace skeleton

- [x] 1.1 Move `src/` to `backend/` with plain `mv` (the repo has no commits yet); verify `cd backend && cargo build --frozen` still succeeds with unchanged code.
- [x] 1.2 Add root `Cargo.toml` (`resolver = "2"`, `[workspace.package]`, `[workspace.dependencies]`, `[workspace.lints]`), `rustfmt.toml` (`max_width = 90`), `clippy.toml`, `deny.toml`, `rust-toolchain.toml`, `justfile`; verify `cargo metadata` lists the workspace and `just --list` shows fmt, lint, test, doc, bench, names, web.
- [x] 1.3 Create the four crates with `lints.workspace = true`, `publish = false`, and move modules mechanically (no logic edits): media <- `ts_decrypt ts_remux playlist` + pure parts of `media`; wasm <- `cmg ticket` + keygen part of `sdk` + `assets`; upstream <- `sign sdk live flow constants` + pipeline part of `media`; server <- `main config prefix`. Verify `cargo test --workspace --frozen` passes with the pre-existing tests.
- [x] 1.4 Add the `names` recipe (case-insensitive search of `*.rs`, `*.ts`, `*.tsx` for `resolv\w*|provider|locator|registry|container`) and fix every hit (`resolve_ch`, `resolve_func_index*`, "resolve m3u8 line"). Verify `just names` exits 0.
- [x] 1.5 Add `cargo tree -p ysp-media -e normal` check to the justfile (`deps` recipe) failing on `axum|reqwest|wasmtime|tokio|hyper`; verify it passes now and fails when a banned dependency is temporarily added.

## 2. Media crate (pure)

- [x] 2.1 Define `MediaError` (thiserror) and replace `anyhow` in the media crate; every public fn gets rustdoc with `# Errors`. Verify `cargo doc -p ysp-media --no-deps` has no warnings.
- [x] 2.2 Define `PayloadCipher` trait; change `decrypt_ts_segment` and `decrypt_and_remux_ts` to take `&mut impl PayloadCipher`. Verify crate compiles with no `wasmtime` in `cargo tree`.
- [x] 2.3 Add `testkit` feature: synthetic H.264/AAC TS generator (PAT, PMT, PES with PTS/DTS, continuity counters) and pass-through cipher. Verify generator output parses back with the crate's own demuxer in a unit test.
- [x] 2.4 Characterization tests on the unmodified algorithms: round trip, counts, continuity across two segments, ordering. Verify they pass before any optimization.
- [x] 2.5 Malformed-input tests (empty, misaligned, no sync, no PMT, no video, no audio, cipher failure) plus a bounded pseudo-random garbage test (seeded `rand`, 64 KiB, 200 cases). Verify none panic and error variants match.
- [x] 2.6 Playlist tests: M3U escaping, `PlaylistEntry` input, window and holdback bounds, relative URL join. Verify with `cargo test -p ysp-media`.
- [x] 2.7 Criterion benches `ts_demux`, `ts_remux`, `playlist_rewrite`, `m3u_build` on a 2 MiB synthetic segment. Verify `cargo bench -p ysp-media`, then record numbers in design.md "Baseline".
- [x] 2.8 Optimize per design D6.2 (range-based PES assembly, reused buffers, capacity hints, `get`/`chunks_exact` instead of indexing). After each change re-run characterization tests (byte-identical output) and the bench; keep only changes that do not regress. Verify final bench is at least as fast as Baseline and the allocation budget holds (counting-allocator test).

## 3. WASM and assets

- [x] 3.1 Move asset files to `backend/assets/`, drop unused `hls.cmg.js`, and generate `manifest.json` (SHA-256 per file) with a documented `just assets-manifest` recipe. Verify manifest matches `shasum -a 256`.
- [x] 3.2 Implement `AssetBundle::load(dir)` with `AssetError` (missing dir, missing file, digest mismatch naming file and both digests). Verify unit tests for each error using `tempfile`.
- [x] 3.3 Parse the worker script once into an owned `CmgImage` (wasm bytes, static data, relocations) and compile each module once under a shared `Engine`; remove `include_bytes!`/`include_str!`. Verify `rg 'include_(bytes|str)' backend` is empty and a counter test shows one compile and one parse for two channels.
- [x] 3.4 Implement `PayloadCipher` for `CmgDecryptor`; give `TicketSigner` and `KeygenSigner` constructors that take the bundle. Verify existing ticket and keygen unit tests pass, and add golden-vector tests captured from the old code for ticket and keygen output given fixed inputs.
- [x] 3.5 Read `CMG_*` debug env switches once into a config struct. Verify behavior is covered by a test that sets the config directly (no process env mutation).
- [x] 3.6 Release-size check: build release and verify the binary is at least 2 MiB smaller than the pre-refactor release binary (record both sizes in the PR description).

## 4. Upstream crate

- [x] 4.1 `UpstreamError` (thiserror); remove `anyhow`; keep secrets out of `Display`/`Debug` (redacting wrapper type for tokens and signatures). Verify a unit test asserts `format!("{err:?}")` has no token text.
- [x] 4.2 Inject the HTTP client behind a small trait so token fetch and playlist fetch are testable with a stand-in. Verify tests for success, 4xx, timeout, and malformed body.
- [x] 4.3 Unit tests with golden vectors for `sign` (md5 variants, js_int32_hash, ckey build), `canonical_*` sorting, `flow` limiter (concurrency 1, min interval, retries, queue timeout using `tokio::time::pause`).
- [x] 4.4 Replace the shared `Mutex<MediaState>` + per-channel tokio mutex with per-channel task + bounded `mpsc`/`oneshot` (design D6.6); run decrypt+remux in `spawn_blocking`. Verify tests: in-order processing, predecessor priming, reset on older sequence, queue-full returns the overload error, and `rg 'lock\(\)\.await' ` shows no guard held over an await (clippy `await_holding_lock` on).
- [x] 4.5 Criterion bench `upstream`: ckey/sign throughput and limiter overhead with paused time. Verify `cargo bench -p ysp-upstream --no-run` and run it once.

## 5. Server crate

- [x] 5.1 `ChannelIndex` + `ChannelStore` with mtime-checked reload (at most 1 stat/s), last-good fallback and reload error exposed to `/health`; `find_channel_by_slug` returns `Option<Arc<Channel>>`. Verify tests for edit, broken edit, missing file at startup, case-insensitive lookup, duplicates (first wins, logged).
- [x] 5.2 `Stats` as atomics; notice cache with std mutex and no await inside; remove `unwrap`/`expect` from header construction and signal handlers. Verify `rg '\.unwrap\(\)|\.expect\(' backend/crates/*/src` shows only test code.
- [x] 5.3 Move HTTP-specific helpers (`prefix`) here, taking plain `&str` inputs for the media crate; keep route behavior frozen. Verify with axum `tower::ServiceExt::oneshot` tests for every spec scenario in `stream-relay`.
- [x] 5.4 Map overload to `429 + Retry-After: 1`; map other errors as today. Verify a test saturating one channel's queue while another channel still answers.
- [x] 5.5 Add `--assets-dir` (env `YSP_ASSETS_DIR`) and optional `--web-dir`; API routes precede the `ServeDir` fallback. Verify tests: no `--web-dir` -> `GET /` is 404; with it -> index served, `/health` still JSON.
- [x] 5.6 Criterion bench `server`: `build_list_m3u` with 200 channels, `find_channel_by_slug`, request path through the router with a stand-in pipeline. Verify `cargo bench -p ysp-server --no-run`.
- [x] 5.7 Full backend gate: run the four AGENTS.md verification commands from `backend/`. Verify all exit 0; otherwise record the exact failing gate.

## 6. Frontend

- [x] 6.1 Scaffold `frontend/` (Vite, React 19, TS strict, ESLint with the DOM-ban rule, Vitest, Testing Library, msw). Verify `npm run build`, `npm run lint`, `npm test` all pass on the empty app.
- [x] 6.2 Design tokens (light and dark per design D4), global focus ring, reduced-motion rule. Verify a Vitest contrast test computes AA for every text/background token pair in both schemes.
- [x] 6.3 API layer: typed `fetchChannels`, `fetchHealth` with runtime validation of the response shape; TanStack Query hooks (health 5 s, paused when hidden). Verify msw tests for success, malformed JSON, and 500.
- [x] 6.4 Channel browser: grouped tiles, filter, empty state. Verify component tests for the filter and empty-state scenarios.
- [x] 6.5 Player: `useHlsPlayback` hook, state banner (loading, playing, stalled, failed + retry, notice fallback), cleanup on switch and unmount. Verify tests with a fake HLS engine asserting detach-before-attach and destroy on unmount.
- [x] 6.6 Health strip with offline state and last-success time. Verify test with msw failing after a success.
- [x] 6.7 Responsive and keyboard pass at 360 px and 1280 px; verify by a keyboard-navigation test and by viewing screenshots (browser run: `npm run dev` against the backend).
- [x] 6.8 Check the declarative rule: `npm run lint` fails when a probe file uses `document.querySelector` outside the hook (probe removed after the check).

## 7. Packaging and docs

- [x] 7.1 Rewrite `Dockerfile`: node stage builds `frontend/dist`; rust stage builds the workspace (fix the stale `rust-src/` paths); scratch runtime gets the binary, `/app/assets`, optional `/app/web`, `channels.yaml`; `CMD` passes `--assets-dir`. Verify `docker build` and a container smoke run of `/health` (if Docker is unavailable, report that this was not run).
- [x] 7.2 README with layout, run, test, bench, and asset-manifest instructions; add `.gitignore` (target, node_modules, dist, `.codegraph`). Verify commands in the README run as written.
- [x] 7.3 Manual network smoke checklist for the user (needs live upstream): `/list.m3u` loads in a player, one channel plays for 2 minutes, `/health` counters move. Record in the PR description whether it was run.
- [x] 7.4 Final gates: four backend verification commands, `just names`, `just deps`, frontend lint/test/build. Verify all exit 0 and `openspec validate refactor-split-frontend-backend` passes.

## Deviations from the task list as written

- 2.7: there is no separate demux benchmark, because demux is not a public entry point;
  `remux_*`, `decrypt_in_place_*`, `hls/*` and `playlist/*` are benchmarked.
- 2.8: the allocation-count check was not automated (a counting allocator needs `unsafe`,
  which the workspace forbids). Speed against the original is recorded in design.md.
- 3.1: `cmg.wasm` and `hls.cmg.js` are unused by the code but were kept in `backend/assets`
  (ablation gate judged removal 0.55, not warranted); they are not in the manifest.
- 7.1: built and run with Docker (Colima, a temporary 4 CPU / 8 GiB profile, since the
  default 2 GiB profile ran out of memory; the profile was deleted afterwards). The image
  is 25.9 MB. It serves the console, `/health`, a live playlist and a 1080p H.264 + AAC
  segment from the real upstream. The builder sets `RUSTUP_TOOLCHAIN=1.90.0` so rustup does
  not download `stable` over the image's pinned compiler; this also proves the declared
  MSRV of 1.90.
- 7.3: the network smoke ran against the live upstream from this machine: `/live` and
  `/segment` through the relay gave a 1080p H.264 + AAC segment that ffprobe/ffmpeg decode,
  and the console played CCTV-1 and CCTV-2 in headless Chrome in both themes.
- Nothing was committed; commits must go through the `conventional-commit` skill.

## Workflow follow-up

- Commit each numbered group through the `conventional-commit` skill (scopes: `workspace`, `media`, `wasm`, `upstream`, `server`, `web`, `docker`).
- Archive with `openspec archive refactor-split-frontend-backend` after the manual smoke in 7.3.
