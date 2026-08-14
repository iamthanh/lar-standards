
## Repo-specific guidance: lar-ingestion

A **library** for market data ingestion, consumed by `lunar-alpha-research`. It
must never import from `lunar-alpha-research`.

**This repo is nearly empty** — a README and a .gitignore. That makes it the one
place where the standard costs nothing to follow from the start:

- `src/lar_ingestion/` layout from the first commit. Do not start flat and
  migrate later; both other libraries are still carrying that decision.
- `requires-python = ">=3.12"`, CI matrix `["3.12", "3.13"]`.
- Internal helpers go in `_infra/` from the beginning.
- Ingestion writes to the shared parquet layout, which is a cross-repo
  contract. Paths come from a `paths.py` in this package, never string
  concatenation.

Because there is no legacy here, **the style gate should be whole-repo, not
changed-files**, from the first commit. Set `ruff check --config ruff.toml .`
as a blocking step rather than adopting the changed-files scoping the older
repos need.
