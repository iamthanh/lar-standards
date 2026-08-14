# Rust standard

Applies to `lar-probability-engine`, and any future Rust crate.

This repo is already the healthiest of the five — `cargo fmt --check`, `cargo
clippy -D warnings` and `cargo test` all gate on every PR. The standard is
mostly *keep doing this*, written down so the next Rust repo starts here.

## Toolchain

- The channel is pinned in `rust-toolchain.toml` with `rustfmt` and `clippy`
  components. Never rely on the runner's default toolchain.
- `RUSTFLAGS: -D warnings` in CI. A warning is a build failure.

| Job | Command | Gate |
|---|---|---|
| Format | `cargo fmt --all -- --check` | blocking |
| Lint | `cargo clippy --workspace --all-targets --all-features -- -D warnings` | blocking |
| Tests | `cargo test --workspace --all-features` | blocking |

Unlike the Python side, the Rust gate is **whole-repo**, because it is already
green. Keep it that way.

## Conventions

- **Workspace layout.** Crates under `crates/<crate-name>/`. Shared dependency
  versions in `[workspace.dependencies]` — a crate must never pin its own
  version of a dependency the workspace already declares.
- **Async at the edge only.** I/O may be async; the compute core stays sync.
  This is already the rule in `lar-prob-core` vs `lar-prob-io` and it is what
  keeps the core testable without a runtime.
- **Errors.** `thiserror` for library crates (typed, matchable errors),
  `anyhow` for the CLI binary only. Never `unwrap()` or `expect()` outside
  tests, benches, and `main`.
- **Panics.** The release profile sets `panic = "abort"`. Library code must not
  panic on data-dependent input — return an error.
- **Tracing, not println.** `tracing` is already a workspace dependency.

## Parity with Python

`lar-probability-engine` reimplements computation that exists in Python, so
byte-level agreement is a contract, not an aspiration:

- The canonical parity checksum is sha256 over polars-formatted CSV. Float
  formatting must match byte-for-byte — this is why `ryu` is pinned.
- Any change to a computation path needs its parity fixture re-verified in the
  same PR. Do not update a golden fixture to make a test pass without
  explaining, in the commit message, why the new bytes are the correct ones.
