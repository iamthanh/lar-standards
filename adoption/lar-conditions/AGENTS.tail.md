
## Repo-specific guidance: lar-conditions

A **library**, consumed by `lunar-alpha-research` and `lar-probability-scoring`
as a pinned git dependency. It must never import from `lunar-alpha-research`.

**The encoding contract is frozen.** BLAKE2b -> 0..255. Both consuming repos
pin this package to the *same SHA* deliberately, because an unpinned bump could
silently change every cell already mined into probability parquet. Changing the
encoding is not a code change, it is a data migration.

**Layout.** `src/lar_conditions/` — this repo is the one that already follows
the `src/` layout the standard prefers. Keep it.

**Star imports in `intraday/`.** `bar_local_conditions.py` and `conditions.py`
build their condition namespace with `import *`, which produces all 98 of this
repo's `F403`/`F405` findings. They are scoped out in `ruff.toml`. If you
replace them with explicit imports, remove the ignore entry in the same PR.

**Tests.** Keep them in the top-level `tests/`. Do not add a second test tree
inside `src/lar_conditions/`.

**CI runs a 3.12/3.13 matrix.** It previously tested 3.12 alone while being
consumed by a 3.13 application. Do not narrow it back.
