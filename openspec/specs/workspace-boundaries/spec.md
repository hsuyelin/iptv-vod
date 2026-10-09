# workspace-boundaries Specification

## Purpose
Crate dependency direction, naming rules, quality gates, and test and benchmark expectations for the backend workspace.

## Requirements

### Requirement: One-way crate dependencies
The backend SHALL be a Cargo workspace whose internal dependency edges are exactly
`iptv-wasm -> iptv-media`, `iptv-upstream -> iptv-wasm`, `iptv-upstream -> iptv-media`,
`iptv-server -> iptv-upstream` and `iptv-server -> iptv-media`. No other internal edge and no
cycle SHALL exist.

#### Scenario: Pure media crate
- **WHEN** the normal dependency tree of `iptv-media` is inspected
- **THEN** it contains none of `axum`, `reqwest`, `wasmtime`, `tokio`, `hyper`

#### Scenario: HTTP types stay in the server
- **WHEN** `iptv-media`, `iptv-wasm` or `iptv-upstream` are compiled
- **THEN** none depends on `axum` or `http`

### Requirement: No Service Locator vocabulary
No identifier, module, file name, crate name or documentation term SHALL use `resolver`,
`resolve`, `provider`, `locator`, `registry` or `container`. Collaborators SHALL be passed
explicitly to constructors.

#### Scenario: Grep gate
- **WHEN** CI searches Rust and TypeScript sources, case-insensitively, for those words
- **THEN** it finds no match outside `Cargo.lock`, `node_modules` and third-party code,
  where the only tolerated match is the third-party API name `QueryClientProvider`

### Requirement: Quality gates
Every crate SHALL inherit workspace lints, and the workspace SHALL pass `cargo fmt --check`,
`cargo clippy --workspace --all-targets --all-features --frozen -- -D warnings`,
`cargo test --workspace --all-features --frozen` and
`cargo doc --workspace --all-features --no-deps --frozen`. Production code SHALL contain no
`unwrap`, `expect`, `panic!`, `unreachable!`, unchecked indexing or `unsafe`, and public
items SHALL carry rustdoc with an Errors section where they return `Result`.

#### Scenario: Lint denies unwrap
- **WHEN** a non-test source file contains `.unwrap()`
- **THEN** clippy fails the build via `clippy::unwrap_used`

### Requirement: Tests and benchmarks accompany code
Each crate SHALL have unit tests for its public behavior, and `iptv-media`, `iptv-upstream`
and `iptv-server` SHALL each have a `criterion` benchmark target.

#### Scenario: Bench targets exist
- **WHEN** `cargo bench --workspace --no-run` is run
- **THEN** it builds the three benchmark targets
