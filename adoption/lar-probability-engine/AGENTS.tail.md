
## Repo-specific guidance: lar-probability-engine

Rust. See [`standards/rust.md`](https://github.com/iamthanh/lar-standards/blob/v4/standards/rust.md);
the Python sections of the shared block above do not apply, but the repo map,
the cross-repo contracts and the commit conventions do.

**This repo is the reference for how a LAR repo should be gated.** `cargo fmt
--check`, `cargo clippy -D warnings` and `cargo test` all block, whole-repo,
with `RUSTFLAGS: -D warnings`. It is the only one of the five that was already
in that state. Do not weaken it.

**Parity with the Python implementation is a contract.** The canonical checksum
is sha256 over polars-formatted CSV, so float formatting must match byte for
byte — that is why `ryu` is pinned and why `lar_prob_io::checksum` exists. Any
change to a computation path re-verifies its parity fixture in the same PR.
Never update a golden fixture to make a test pass without explaining in the
commit message why the new bytes are the correct ones.

**Async at the edge only.** `lar-prob-core` stays sync; `lar-prob-io` owns I/O.
This is what keeps the core testable without a runtime.

**`panic = "abort"` in release.** Library code must not panic on data-dependent
input — return an error. `unwrap()`/`expect()` belong in tests, benches and
`main` only.
