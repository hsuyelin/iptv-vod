## ADDED Requirements

### Requirement: TS processing is independent of the decryptor
The media layer SHALL accept the payload decryptor as an injected dependency, so demux,
remux and packetization run and are testable with a stand-in decryptor and no network
or WASM engine.

#### Scenario: Round trip with a pass-through decryptor
- **WHEN** a synthetic H.264/AAC transport stream is processed with a pass-through
  decryptor
- **THEN** the output is a valid transport stream whose packets are 188 bytes, begin with
  sync byte 0x47, and carry the same video and audio sample counts as the input

#### Scenario: Decryptor failure surfaces as a typed error
- **WHEN** the injected decryptor returns an error for a video sample
- **THEN** processing stops and the error identifies the failing stage and PES index

### Requirement: Malformed input is rejected, never a panic
Parsing SHALL return a typed error for input that is empty, not a multiple of 188 bytes,
missing sync bytes, lacking a PMT, or lacking an H.264 or AAC stream, and SHALL NOT panic
or index out of bounds.

#### Scenario: Truncated segment
- **WHEN** input length is 188 * n + 17 bytes
- **THEN** the call returns an error describing the misalignment

#### Scenario: Garbage input
- **WHEN** pseudo-random bytes of any length up to 64 KiB are processed
- **THEN** the call returns an error or a result and never panics

### Requirement: Output ordering and continuity
Remuxed output SHALL be ordered by decode time and SHALL keep continuity counters
contiguous per PID, including across consecutive segments of one channel.

#### Scenario: Consecutive segments
- **WHEN** two segments of one channel are processed in sequence with the same mux state
- **THEN** the first packet of the second output continues each PID's continuity counter
  from the last packet of the first output

### Requirement: Playlist generation
The media layer SHALL build the channel list in M3U format with escaped attributes, and
SHALL rewrite upstream media playlists to local segment URLs with a bounded window and
bounded history.

#### Scenario: Attribute escaping
- **WHEN** a channel name contains a double quote, backslash or newline
- **THEN** the attribute value is escaped and the entry stays on one line

#### Scenario: Window bound
- **WHEN** the upstream playlist lists more segments than the window size
- **THEN** the local playlist lists only the newest window, minus the live-edge holdback

### Requirement: Performance budget
Hot paths SHALL be covered by `criterion` benchmarks. The refactored remux of a synthetic
2 MiB segment with a stand-in decryptor SHALL be at least as fast as the pre-refactor
implementation measured on the same input, and the comparison SHALL be recorded in
`design.md`.

#### Scenario: Regression guard
- **WHEN** `cargo bench -p ysp-media --features testkit` is run
- **THEN** it reports remux, in-place decrypt, upstream playlist parse, window render and
  M3U build timings that can be compared with the recorded figures
