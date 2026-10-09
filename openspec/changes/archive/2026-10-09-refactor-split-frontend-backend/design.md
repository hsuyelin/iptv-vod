# Design

## Context

See proposal.md for motivation. Current state (`src/`, one crate `iptv-rust`, ~6.3k LOC):

| Module | LOC | Weight it drags in |
|---|---|---|
| `cmg` | 1525 | wasmtime, embedded worker script |
| `ts_remux`, `ts_decrypt` | 880 + 545 | takes concrete `CmgRuntime` |
| `media` | 684 | reqwest, axum `Body`/`HeaderMap`, tokio |
| `live`, `flow`, `sdk`, `ticket`, `sign` | 593+205+418+307+313 | reqwest, wasmtime |
| `main`, `prefix`, `playlist`, `config` | 402+131+68+97 | axum, serde_yaml |
| `assets` | 136 | `include_bytes!` of ~2.5 MB + JS-text scraping |

There is **no UI**. "Frontend" work is therefore a new application, not a refactor, and the
asset files in `src/assets` are backend runtime inputs (signing/decrypt engines), not
presentation. They are not moved to the frontend.

`.agents/AGENTS.md` is written for the EMS backend. Its generic Rust rules apply here; its
"Backend Contracts" (redb, accounts, Emby, Swagger) do not, and nothing here adds them.

## Decisions

Confidence values come from the `typesafe-ai` System One judgments run on a structural
summary of the code (no constants or secrets were sent). Raw answers are listed under
"Judgment log".

### D1. Workspace with four crates (judgment: yes 0.75; granularity 3-4 crates, 0.95)

Structure pattern: **layered** (per `axiom-rust-workspaces`), tier **S** (3-5 crates, none
published). Rationale: the pure TS/playlist code needs isolated benchmarks and a
compile-time ban on network/WASM dependencies, which module visibility cannot give
(judgments 0.86 and 0.87). Fine-grained (8+) crates were rejected at 0.00.

```
backend/                      workspace root (resolver = "2", edition 2021)
  Cargo.toml                  [workspace.package|dependencies|lints]
  clippy.toml  rustfmt.toml  deny.toml  justfile  rust-toolchain.toml
  assets/                     *.wasm, worker script, manifest.json   (runtime input)
  crates/
    ysp-media/                pure: TS demux/decrypt/remux, playlist rewrite, M3U build
    ysp-wasm/                 wasmtime hosts: CMG decryptor, ticket, keygen; AssetBundle
    ysp-upstream/             signing, sdk token, API flow limiter, live source cache,
                              per-channel segment pipeline
    ysp-server/               axum routes, config file, stats, CLI; binary `iptv-rust`
frontend/                     React app; its own src/
```

Interpretation of "their respective src directories": each Rust crate keeps its own
`src/` under `backend/crates/<name>/src`, and the web app lives in `frontend/src`.
A workspace root has no `src/` of its own.

Edges: `wasm -> media`, `upstream -> {wasm, media}`, `server -> {upstream, media}`.
All crates `publish = false`. No `*-types` crate: `Channel` lives in `ysp-upstream`
because `live` needs its ids; `ysp-media` gets its own `PlaylistEntry` input type, so the
media crate needs no channel type and no cycle arises.

Anti-pattern sweep (workspace-anti-patterns): no god-crate (largest is `ysp-wasm` ~2.3k
LOC, one concern); no shared version drift (all deps in `[workspace.dependencies]`); no
`pub use` of internal types across a published boundary (nothing is published); single
root `clippy.toml`/`deny.toml`; no single-crate workspace.

### D2. Decryptor injected into the media layer

`ysp-media` defines a trait for "decrypt one video sample in place and report stats"
(`PayloadCipher`). `ysp-wasm::CmgDecryptor` implements it. `decrypt_ts_segment` and
`decrypt_and_remux_ts` take `&mut impl PayloadCipher`. Benchmarks and tests use a
pass-through implementation from a `testkit` module (behind a `testkit` feature) that
also generates synthetic TS fixtures. Static dispatch, so no cost in production.

### D3. Assets loaded at startup from a directory (judgment: runtime directory 0.83)

`AssetBundle::load(dir)` reads `manifest.json`, checks SHA-256 of every file, parses the
worker script once (base64 WASM, static data, relocations), and compiles each wasmtime
`Module` once under one shared `Engine`. The bundle is an `Arc` passed to constructors of
`CmgDecryptor`, `TicketSigner` and `KeygenSigner`. Per channel, only a `Store` and
instance are created. This removes the per-call `Engine::default()` + recompile + 1.3 MB
re-parse seen in `cmg.rs:158`, `ticket.rs:27`, `sdk.rs:250`.
The Docker image copies `assets/` next to the binary.

### D4. Frontend: React 19 + TypeScript + Vite (user choice; judgment was a 0.50/0.49 tie)

- Server state: TanStack Query (`/channels` once with long stale time, `/health` polled 5 s,
  paused when hidden via `refetchIntervalInBackground: false`).
- Player: `hls.js` behind one `useHlsPlayback(videoRef, url)` hook, the only imperative
  surface; everything else is declarative JSX. ESLint `no-restricted-syntax` bans DOM
  queries and mutation elsewhere.
- Styling: CSS Modules over CSS custom-property tokens, `light-dark()`/`color-scheme`
  for theming; no UI kit, no Tailwind (fewer dependencies for ~6 screens).
- Tests: Vitest + Testing Library; `msw` for `/channels` and `/health`.
- Dev: Vite proxies `/channels /health /live /segment /list.m3u` to the backend.
- Fonts bundled via `@fontsource` (no third-party CDN requests from an app that shows
  private stream state).

Design plan (frontend-design skill). Subject: an operator console for a TV relay.
Memorable element: a **multiviewer wall**, the grid of channel tiles a broadcast engineer
sees, with a tally-red marker on the channel that is on air.

- Colors (light): wall `#E8ECF1`, panel `#FFFFFF`, ink `#17212E`, tally `#D42B3E`
  (on-air marker and primary action), signal `#0B7A83` (healthy, links),
  caution `#A86A12`.
- Colors (dark): wall `#0F1620`, panel `#18222F`, ink `#E7ECF3`, tally `#FF5A6E`,
  signal `#3CC2CB`, caution `#E0A34A`. Every text/background pair is checked to AA.
- Type: one family, IBM Plex Sans (variable) with its condensed width for tile labels;
  CJK falls back to the system CJK sans. Numerals use `tabular-nums` rather than a
  monospace face.
- Layout: left column groups and filter; main column player over the tile wall; slim
  health strip pinned to the top. Left-aligned text; tiles 16:9.
- Plan review against the generic defaults: not cream/terracotta, not black with an acid
  accent, not newspaper rules, not identical rounded cards (tiles are square-cornered
  monitors, panels are not carded), no eyebrow labels. Motion: one orchestrated moment
  only, the tally marker transitions when a channel goes on air; reduced motion disables it.

### D5. Routes frozen, optional static serving (judgment: 0.95 and 0.98)

No route or payload changes. `--web-dir` enables a `tower-http` `ServeDir` fallback;
API routes match first. Nothing is embedded.

### D6. Performance changes (each measured against a baseline)

1. **Baseline first.** After the mechanical extraction (D1, D2) and before optimizing,
   record `cargo bench` numbers in "Baseline" below. Optimizations must beat them.
2. TS: parse packets into a `Vec<PacketView>` of offsets (already offsets) but stop
   copying payloads: `PesChunk.bytes` becomes ranges into the input; PES assembly into one
   reused `Vec` per call; `output = input.to_vec()` stays the single full copy; replace
   `Vec<MediaEvent>` growth with `with_capacity`; replace linear PID scans with a small
   fixed table.
3. WASM: compile once (D3).
4. Channel directory: `ChannelIndex` = `Vec<Arc<Channel>>` plus `HashMap<Box<str>, usize>`
   keyed by lowercased slug; held as `RwLock<Arc<ChannelIndex>>` (std lock, never held
   across await). A `ChannelStore` checks the file mtime at most once per second.
   `find_channel_by_slug` replaces `resolve_ch` and no longer clones a `Channel`.
5. Stats: `AtomicU64` counters; notice cache is a `std::sync::Mutex<HashMap>` with
   critical sections that contain no `.await`.
6. Segment pipeline: one tokio task per channel owns `ChannelRuntime` (WASM store,
   mux state, processed cache). Requests send a message over a bounded `mpsc` (capacity 8)
   and await a `oneshot` reply. Decrypt+remux runs inside `spawn_blocking` from that task.
   No lock spans an await; a full queue returns 429 + `Retry-After: 1`.
7. `Bytes` is returned for cached segments without copying (already true; kept and tested).

### D7. Naming (spec: workspace-boundaries)

Renames: `resolve_ch` -> `find_channel_by_slug`; `resolve_func_index*` ->
`map_func_index*`; error context text "resolve m3u8 line" -> "join m3u8 line"; media's
`runtime_for_channel` stays (it names the thing, not a lookup service). `ChannelDirectory`
is replaced by `ChannelIndex` + `ChannelStore`. A CI grep gate enforces the list.

### D8. Workspace policy

- `resolver = "2"` stated explicitly; every dependency used by two or more crates is in
  `[workspace.dependencies]` and inherited with `workspace = true`.
- `[workspace.lints]` denies `clippy::unwrap_used`, `expect_used`, `panic`,
  `unreachable`, `indexing_slicing`, `cast_possible_truncation`, `unsafe_code`
  (`forbid`), and warns `missing_docs` on public items; tests may allow via
  `#![cfg_attr(test, allow(...))]` in each crate root. Crates use `lints.workspace = true`.
- `rustfmt.toml`: `max_width = 90`. `rust-toolchain.toml` pins a stable toolchain;
  MSRV documented in `[workspace.package] rust-version`.
- One `deny.toml` at the root (advisories, licenses, sources) run by the justfile.
- `justfile` recipes mirror the four AGENTS.md verification commands plus `bench`, `web`,
  `names` (grep gate).
- `panic = "abort"` in release is kept; the `unwrap`/`expect` removals mean a request
  error never aborts the process.

### D9. Error handling

Libraries use `thiserror` enums (`MediaError`, `AssetError`, `UpstreamError`); `anyhow`
appears only in the server's `main`. HTTP mapping lives only in the server. Error text
never includes tokens or signatures.

## Risks / Trade-offs

- [Behavior drift while restructuring TS code] -> Characterization tests are written
  against the pre-change `ts_*` functions with synthetic fixtures before they are touched;
  pass-through output must be byte-identical before and after each optimization step.
- [Upstream protocol cannot be exercised offline] -> Signing helpers (`sign`, `sdk`
  pure parts, `ticket`) are covered by golden-vector tests captured from the current code;
  live network paths are covered by a trait-injected HTTP client stand-in, with a manual
  smoke checklist in tasks (needs network and is run by the user).
- [Per-channel task adds latency vs a mutex] -> One message hop (microseconds) against
  segment processing that takes milliseconds; verified by the server bench.
- [429 on queue overflow is new behavior] -> Only reachable under overload that previously
  queued unboundedly on a mutex; capacity chosen at 8 (> HLS window prefetch); documented in
  the stream-relay spec.
- [Assets directory missing in deployment] -> Startup fails fast with the directory name;
  Docker image and README updated; `manifest.json` catches partial copies.
- [`indexing_slicing` deny makes TS code verbose] -> Use `get(..)` returning a typed
  error, or iterate with `chunks_exact(188)`; this is also what makes the malformed-input
  guarantee true.
- [Debug env switches (`CMG_FROZEN_NOW_MS`, `CMG_SKIP_MAIN`, `CMG_LIVE8_ONLY`)] ->
  Kept with the same names inside `ysp-wasm`, read once at load into a config struct
  instead of on each call.

## Migration Plan

1. Move `src/` to `backend/` with no code change; `cargo build` must still pass.
2. Split into crates mechanically (no logic edits); tests green.
3. Inject the cipher, add `testkit`, write characterization tests, record Baseline.
4. Externalize assets, add manifest and loader.
5. Apply D6 optimizations one by one, re-running bench and characterization tests.
6. Add frontend; add `--web-dir`.
7. Rewrite Dockerfile (node build stage, rust build stage, scratch runtime with
   `/app/assets` and optional `/app/web`).
Rollback: each step is its own commit (conventional-commit skill); revert to the last
green step. Deployment rollback = previous image.

## Baseline and results

Measured on the development machine (Apple silicon, release/bench profile). "Before" is the
original single-crate code run through the same input; "after" is this change.

| Path | Before | After |
|---|---|---|
| Remux 2 MiB synthetic segment (cipher = XOR stand-in) | 1.78 ms | 1.51 ms |
| In-place decrypt of the same segment | 1.67 ms | 1.43 ms |
| Ticket signature (WASM instance per call) | 438 ms (module recompiled every call) | 70 us |
| CMG instance for a channel | 40 ms (engine, compile, 1.3 MB script re-parse) | 75 us |
| Keygen signature | recompiled every call | 22 us |
| Channel lookup per HTTP request (200 channels) | 507 us (re-read and re-parse YAML) | 26 ns snapshot + 14 ns lookup |
| API flow limiter, zero interval | 1.28 ms (timer granularity) | 275 ns |
| Cached segment through the router | n/a | 8 us |
| Release binary | 11,032,272 B | 8,930,656 B (2.004 MiB smaller) |
| Startup (compile 3 WASM modules once) | n/a | about 0.5 s |

The remux output is byte-identical to the original: the characterization tests pin the
original implementation's FNV-1a digests for a 12-frame and a 2 MiB synthetic stream, for
both `decrypt_and_remux` and the in-place `decrypt_ts_segment`.

Not done as specified: the "at most three input-sized buffers" budget has no automated
check (it needs a counting global allocator, which needs `unsafe`, which the workspace
forbids). The structure keeps it true by construction: one PES copy, one arena, one output.

## Defects found and fixed during the move

- `decode_uri_compat` sliced a `&str` by byte offsets and panicked on `%` followed by a
  split multi-byte character; with `panic = "abort"` that would kill the process.
- The CMG `abort` import called `panic!`; it now traps the guest and returns an error.
- Published-segment eviction removed an arbitrary entry (`HashMap::keys().next()`), which
  could drop a segment that was just listed; it is now insertion-ordered.
- The M3U builder wrote the display name after the comma unescaped, so a newline in a
  channel name broke the entry; line breaks are now replaced.
- Debug tracing printed key and input hex dumps to stderr and could write 7 MB heap dumps.
  Removed after a TypeSafe ablation judgment (0.80); the functional switches
  (`CMG_FROZEN_NOW_MS`, `CMG_SKIP_MAIN`, `CMG_LIVE8_ONLY`) were kept (removal judged 0.37).
- `ts_decrypt` is unused by the relay. The ablation gate judged removal 0.54, so it was not
  removed: it is a public, tested API of `ysp-media`.

## Naming gate exception

`just names` finds one third-party identifier, `QueryClientProvider` (TanStack Query's own
API), and filters it out explicitly. No name introduced by this repository matches.

## Judgment log (typesafe-ai, model jev-1.13.0)

| Question | Answer |
|---|---|
| Convert to workspace appropriate | noul 0.75 |
| Separate pure crate improves bench isolation / compile time | noul 0.86 |
| Separate crates give compile-time boundary modules cannot | noul 0.87 |
| Granularity | three_to_four 0.95 (confidence 0.92) |
| Frontend stack | react_vite_ts 0.50, svelte_vite_ts 0.49 (confidence 0.33) -> asked user -> React |
| Asset location | runtime_directory 0.83 (confidence 0.74) |
| Keep HTTP routes stable | noul 0.95 |
| Static UI delivery | optional_runtime_dir 0.98 (confidence 0.97) |
| Remove dead `ts_decrypt` (ablation gate) | noul 0.54: not warranted, kept |
| Remove unused constants/fns (ablation gate) | noul 0.55: not warranted, kept |
| Remove CMG trace/dump facilities (ablation gate) | noul 0.80: warranted, removed; functional knobs 0.37: kept |

## Open Questions

- Pre-existing upstream credentials appear as constants in `constants.rs`. They stay
  where they are (moved to `ysp-upstream`); whether to externalize them is a separate
  change and does not affect this one.
