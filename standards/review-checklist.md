# PR review checklist

Formatting, import order, lint and tests are enforced by CI. **Do not spend
review attention on them.** This list is only the things a machine cannot check.

Six items. If a PR passes these, approve it.

### 1. Is the code in the right repo?

The most expensive mistake available here. Scoring logic in
`lunar-alpha-research`, condition logic outside `lar-conditions`, or any library
importing from the application — all mean the change is on the wrong side of a
seam that was paid for with extraction work.

### 2. Does it touch a cross-repo contract?

Shared Postgres tables, parquet layout, job types and queue names, the frozen
condition encoding. If yes, the PR body must say so and name the other repo that
moves with it. A contract change that lands in one repo alone is a production
incident with a delay fuse.

### 3. Is a dependency pin being moved?

Pin bumps are their own commit with their own stated reason. A pin that moved as
a side effect of unrelated work is a revert, not a comment.

### 4. Does the test prove the behaviour, or just execute it?

AI-written tests are reliably present and frequently vacuous — asserting that a
mock was called, or re-deriving the expected value with the same code path under
test. Ask what would have to break for this test to fail.

### 5. Is the error path real?

Bare `except Exception`, a swallowed error, a `raise` that drops its cause, or
an error message that does not name the identifier needed to find the failure
again.

### 6. Do the comments still describe the code?

Stale comments are the highest-density source of confusion in these repos —
`lunar-alpha-research` carried a `testpaths` comment explaining that condition
tests lived under `common/` for some time after they had moved to
`lar-conditions`. If a change makes a comment false, the comment is part of the
change.

---

**On volume.** AI produces more diff than review capacity. A PR too large to
review against these six items should be split, and saying so is a complete
review — it does not need line-level comments to be actionable.
