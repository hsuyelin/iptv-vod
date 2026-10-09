# runtime-assets Specification

## Purpose
How the WASM and worker assets are located, verified, compiled once and shared, so they are never embedded in the binary.

## Requirements

### Requirement: Assets are loaded from a directory, not compiled in
The binary SHALL NOT contain the WASM modules or worker scripts. It SHALL read them from
the directory given by `--assets-dir` (env `IPTV_ASSETS_DIR`, default `./assets`).

#### Scenario: Binary contents
- **WHEN** the release binary is built
- **THEN** it is at least 2 MiB smaller than the pre-refactor binary and contains none of
  the asset files' bytes

### Requirement: Integrity manifest
The assets directory SHALL contain `manifest.json` listing every required file with its
SHA-256. Startup SHALL verify each file and fail fast on a missing file, an unlisted
required file or a digest mismatch, naming the file.

#### Scenario: Tampered file
- **WHEN** one byte of `ticket.wasm` is changed
- **THEN** startup exits non-zero with an error naming `ticket.wasm` and both digests

#### Scenario: Missing directory
- **WHEN** `--assets-dir` points to a directory that does not exist
- **THEN** startup exits non-zero with an error naming the directory

### Requirement: Compile once, instantiate per use
Each WASM module SHALL be compiled once per process and shared by all channels and
requests. The worker script SHALL be parsed once per process. Per-channel state SHALL live
in a per-channel instance only.

#### Scenario: Two channels
- **WHEN** two channels are first used
- **THEN** module compilation and worker-script parsing are each counted once, and each
  channel has its own instance state

### Requirement: Secrets are not logged
Asset paths MAY be logged; request signatures, tokens and key material SHALL NOT appear
in logs at any level.

#### Scenario: Verbose logging
- **WHEN** the server runs with `--verbose` and serves a channel
- **THEN** no log line contains a token, signature or ckey value
