# EMS Backend Repository Instructions

## Scope

- Reply in Chinese. Write Rust comments, public rustdoc, and commit messages in English.
- This repository owns the EMS Rust backend only. Frontend source belongs to `ems-frontend`;
  integration, Docker, CI, and release manifests belong to `ems`.
- Preserve unrelated changes. Never reset, stash, clean, checkout, or overwrite user work.
- Use only skills under `.agents/skills/`. Within that directory, exactly two skills are
  reserved for non-Rust duties: `conventional-commit` (MANDATORY for every commit) and
  `typesafe-ai` (typed AI judgments, including the MANDATORY ablation gate below). EVERY
  other skill present — and EVERY Rust skill added in the future — belongs to the
  mandatory Rust best-practices set defined in the next section. This set is defined by
  exclusion on purpose: new Rust skills are enforced automatically, with no edit to this
  file. For backend exploration, use the CodeGraph MCP with `projectPath` set to this
  repository before symbol or architecture edits.
- Keep product requirements and API contracts in OpenSpec/docs, not this file.

## Mandatory Rust Skills

- Every Rust implementation, refactor, review, and compile-error fix MUST load and
  apply EVERY applicable skill from the Rust best-practices set: all skills under
  `.agents/skills/` EXCEPT `conventional-commit` and `typesafe-ai`. Routing skills,
  domain skills, and the `m01`–`m15` module skills are NOT optional reading; when a
  skill's trigger conditions match the work, using it is REQUIRED, not advisory.
  This enumeration is deliberately closed by exclusion: any Rust skill added under
  `.agents/skills/` later joins this mandatory set automatically. Do NOT wait for
  this file to list a skill by name — its presence in the directory IS the mandate.
- `rust-best-practices` is a hard delivery gate: apply typed errors, explicit
  ownership and concurrency boundaries, no production `unwrap`/`expect`/panic,
  documented public APIs, and the required focused tests.
- Rust changes MUST pass the repository verification commands in this file, or the
  final report MUST identify the exact failing gate and affected scope.

## CodeGraph exploration

Before backend symbol or architecture edits, use the CodeGraph MCP with the backend
repository path explicitly set:

```json
{
  "projectPath": "/path/to/ems-backend",
  "query": "symbol or flow to explore"
}
```

Use `codegraph status` to verify the index is current. Generated `.codegraph/` data is
local-only, ignored by Git, and MUST NOT be committed.

## Workflow

For bugs: record symptom, reproduce, trace callers/history, state root cause, obtain TypeSafe
review, implement, run behavioral tests/smoke, then report evidence and limits.
For features: read the owning OpenSpec, define API/data/security contracts, implement in
one related batch, and verify all affected callers together.

## Backend Contracts

- The embedded redb database (rkyv records, one owning process) is the only storage:
  durable records are authoritative and ephemeral state expires by TTL in the same file.
- Internal account UUID is the only primary identity. Telegram and server-scoped Emby IDs
  are nullable external bindings with atomic audited rebinding.
- Use typed field-level PATCH/field-mask updates with optimistic versions; omitted fields
  remain unchanged and secrets require explicit set/clear operations.
- Swagger/OpenAPI is versioned, secret-free, and protected for admin/super-admin.
- Frontend, backend, and dual stream modes are supported with bounded listeners and relay
  loop/grant validation.
- Backend admission is authoritative for every protected route and API.
- Bound login, OAuth, identity binding, mutations, and expensive reads; return stable 429
  and Retry-After behavior where applicable.

## Rust Quality

- Follow the workspace edition/MSRV and four-space formatting; keep lines <=90 columns.
- Avoid unchecked indexing/casts, unwrap, recoverable expect, panic, unreachable, and
  silent error suppression in production.
- Inject dependencies, use typed errors, redact secrets, bound concurrency/timeouts/retries,
  and never hold locks across await points.
- Public APIs require rustdoc with Errors/Panics/Safety sections as applicable.

## Commit Discipline

- EVERY commit in this repository MUST be produced through the
  `.agents/skills/conventional-commit/` skill workflow: review `git status` and the
  diff, stage the intended files, then commit with a Conventional Commits message
  (`type(scope): imperative description`). Ad-hoc messages are FORBIDDEN.

## Ablation Experiment Gate

- Ablation (code simplification, over-design removal, structure reduction) is an
  auxiliary tool, NEVER a default action. Before starting ANY ablation experiment,
  the agent MUST submit the target code to the `typesafe-ai` skill for a typed
  judgment on whether ablation is warranted.
- If `typesafe-ai` judges that ablation is NOT needed, ablation is STRICTLY
  FORBIDDEN — the code stays as-is and the agent proceeds with the actual task.
  Skipping the gate to perform ablation, or overriding a negative judgment, is a
  process violation.

## Verification

```text
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --frozen -- -D warnings
cargo test --workspace --all-features --frozen
cargo doc --workspace --all-features --no-deps --frozen
```

Use focused tests for a related batch and adapter contract and service smoke tests where
contracts require them. Build success alone is not completion evidence.
