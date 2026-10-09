# observability Specification

## Purpose
Logging of the relay with the tracing crate, detailed enough to troubleshoot from the log alone, and free of secrets.

## Requirements

### Requirement: Log line format
Every log line SHALL carry the time as RFC 3339 in UTC with microseconds, the level, the
thread name, the module, the source file and line, the message and its fields. Lines SHALL
go to standard error.

#### Scenario: A line
- **WHEN** the relay logs an event
- **THEN** the line shows time, level, module, `crates/<crate>/src/<file>.rs:<line>`, the
  message and the fields

### Requirement: Verbosity
By default the relay's own crates SHALL log at `info` and all other crates at `warn`; `-v`
SHALL raise the relay's crates to `debug` and `-vv` to `trace`. `RUST_LOG`, when set, SHALL
replace these defaults.

#### Scenario: Debug detail
- **WHEN** the relay runs with `-v`
- **THEN** upstream fetches with their timings, playlist windows, cache decisions, queue
  waits and asset checks are logged

### Requirement: Request lines
Each HTTP request SHALL produce one line with a request id, method, route, status, size,
time, client address and user agent, at `info` for 2xx and 3xx, `warn` for 4xx and `error`
for 5xx. The path SHALL be shown only for API routes; for any other path it SHALL read
`<static>`.

#### Scenario: Console address with a key
- **WHEN** `/<key>` is requested
- **THEN** the line shows `path=<static>` and the key appears nowhere in the log

### Requirement: Secrets stay out
Administrator keys, guesses, tokens and signatures SHALL NOT be written to the log, and the
`Debug` output of the key type SHALL be redacted.

#### Scenario: Wrong key
- **WHEN** a wrong key is posted
- **THEN** the log records the client and the failure count but not the key text

### Requirement: Panics
A panic SHALL be logged at `error` with its source location, message and a backtrace before
the process ends.

#### Scenario: Panic
- **WHEN** code panics
- **THEN** an `error` line with `location`, `message` and `backtrace` precedes the abort
