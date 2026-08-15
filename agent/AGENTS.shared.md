<!-- BEGIN lar-standards shared block -->
<!--
  SOURCE OF TRUTH: iamthanh/lar-standards :: agent/AGENTS.shared.md
  This block is VENDORED. Do not edit it here -- CI drift-check compares it
  byte-for-byte against the pinned lar-standards tag and fails on divergence.
  To change it: edit it in lar-standards, cut a tag, run scripts/sync-standards.sh.
  Repo-specific guidance goes OUTSIDE this block, below it.
-->

## The LAR repo map

Seven repos. Put code where it belongs; the seams are deliberate and were paid
for with extraction work.

| Repo | Owns | Language |
|---|---|---|
| `lunar-alpha-research` | The application: ingestion orchestration, backtesting, trade engine, jobs/workers, HTTP API. Depends on the libraries below. | Python 3.13 |
| `lar-conditions` | Condition definitions, evaluation, classification, encoding. The BLAKE2b -> 0..255 encoding contract is **frozen**. | Python 3.12 |
| `lar-probability-scoring` | Probability scoring engine, scoring constants, weight profiles, scoring CLI, scores worker, scoring HTTP API. | Python 3.12 |
| `lar-probability-engine` | Performance-critical probability computation. | Rust |
| `lar-ingestion` | Market data ingestion. | Python 3.12 |
| `lar-utils` | Shared Python helpers used across the repos above. | Python |
| `lar-ui` | The React frontend. Consumes the HTTP APIs the app and libraries expose. | TypeScript / React |

Two of these are mid-migration, and assuming they are finished is a way to put
code in the wrong place:

- **`lar-ui` is not yet the only frontend.** `lunar-alpha-research` still ships
  ~148 files under `ui/`. New frontend work goes to `lar-ui`; do not extend the
  copy still sitting in the application.
- **`lar-utils` is consumed by one repo so far.** `lar-probability-scoring`
  pins it at `v0.2.0`; nothing else declares it. Do not assume a helper is
  available from it -- check the consuming repo's `pyproject.toml` first, and if
  you add the dependency, that is its own commit with its own reason.

**Dependency direction is one-way**: `lunar-alpha-research` depends on the
libraries; the libraries may depend on `lar-utils`. Nothing may import from
`lunar-alpha-research`. If you find yourself wanting to, the code you are
writing belongs on the other side of the seam -- stop and say so rather than
adding the import.

`lar-ui` talks to the other repos over HTTP only. A route or response-model
change in any `api/` package is a two-repo change with `lar-ui`.

**Before adding a module, check whether another repo already owns that concern.**
Scoring logic goes in `lar-probability-scoring`, not in a new `common/scoring/`.
This is the single most common way an AI-written change goes wrong here.

## Layout

- **Libraries** use a `src/` layout: `src/<package_name>/`. New library repos
  must; existing ones migrate when convenient.
- **Applications** (`lunar-alpha-research`) keep top-level packages.
- Code copied from `lunar-alpha-research` goes in a `compat/` subpackage, so the
  copies stay in one place and their drift is visible rather than scattered.
  `lar-conditions` and `lar-probability-scoring` both use it.
- A repo's *own* internal-only helpers go in `_infra/`. The leading underscore
  means *no other repo may import this*.
- Both are internal and neither is public surface; they differ in origin, not
  visibility. A repo will often have only one of them -- if everything under it
  came from `lunar-alpha-research`, it is all `compat/` and there is no
  `_infra/`.
- Each package declares its public surface in `__all__` in its **top-level**
  `__init__.py` -- the list of names other repos may import. Submodules do not
  need one. Changing that list is a cross-repo change.
- Tests live in a flat top-level `tests/`, named `test_<module>.py`. Do not
  mirror the package tree, and do not nest a second `tests/` inside the package.
  Subdirectories under `tests/` are for fixtures and golden data only.
- One concern per module. If a module exceeds ~500 lines, it is doing more than
  one thing -- split it along the seam that is already visible in its sections.

## Python conventions

These are the rules a linter cannot check. The linter handles the rest; do not
hand-format code, run `ruff format`.

**Typing**
- `from __future__ import annotations` at the top of **every** module.
- Annotate every public function signature. Internal helpers may omit
  annotations only when the types are obvious from a two-line body.
- Prefer `X | None` over `Optional[X]`, `list[str]` over `List[str]`.

**Docstrings**
- Required on every public function, class and module, in **Google style**
  (`Args:` / `Returns:` / `Raises:`).
- Say what the caller needs that the signature does not already tell them. A
  docstring restating the parameter names is worse than none.

**Imports**
- Absolute imports within a package (`from lar_conditions.encode import ...`),
  not relative. This is already near-universal; keep it that way.

**Data shapes**
- `@dataclass` is the default, frozen where the value is not meant to change.
- `pydantic.BaseModel` only where data crosses an **external** boundary and
  needs validation -- HTTP request/response bodies, parsed config, third-party
  JSON. Not for internal plumbing, and not in hot scoring paths.
- `TypedDict` only to describe a dict shape you do not control.

**Errors**
- Anything raised out of a package's **public surface** must be a domain
  exception from that package's `exceptions.py`, so callers can catch by type.
- Plain `ValueError`/`TypeError` are fine for local argument validation that
  never escapes the module.
- Never raise bare `Exception` or `RuntimeError` across a seam.
- Always `raise ... from err` inside an `except` block. Losing the cause makes
  a failure in a worker unreadable.
- Never `except Exception: pass`. If a failure is genuinely ignorable, log it at
  `debug` and write the one-line reason why.

**Logging**
- Use the repo's domain logger (`from common.logger import get_domain_logger` in
  `lunar-alpha-research`; the package logger elsewhere). Never `print()` outside
  a CLI entry point, and never call `logging.getLogger` directly in new code.
- Lazy `%` formatting, never f-strings: `log.info("scored %s bars for %s", n,
  symbol)`. An f-string is formatted even when the level is disabled.
- Every message carries the identifiers needed to find the event again -- run
  id, symbol, bar timestamp. No secrets, DSNs, or full row payloads.

**Data access**
- Postgres access goes through the owning package's db module. Do not open a
  connection or write SQL inline in business logic.
- Parquet paths come from the owning package's `paths.py`. Never build a data
  path by string concatenation -- the layout is a cross-repo contract.

**Naming**
- `snake_case` modules and functions, `PascalCase` classes, `UPPER_SNAKE`
  constants. Module names are nouns; function names lead with a verb.
- No abbreviations that are not already in the codebase's vocabulary. `cfg`,
  `df`, `ts` are fine; inventing new ones is not.

**Comments**
- A comment earns its place by recording a decision, a constraint, or a
  non-obvious reason: why a pin is exact, why a fallback is forbidden, why bytes
  must match. Never restate what the code says.
- If a change makes a comment false, updating it is part of the change.

## Tests

- Write plain `def test_*` functions. Use a class only to group tests that
  genuinely share fixtures or parametrisation.
- **Hand-written fakes at seams** -- db clients, the job dispatcher, parquet IO.
  A fake breaks when the real interface changes; a `MagicMock` silently does
  not. Avoid `MagicMock` and `unittest.mock.patch`.
- `monkeypatch` is fine for values, clock and environment.
- A test must be able to fail for the reason it claims. Asserting that a mock
  was called, or recomputing the expected value with the code under test, proves
  nothing.

## Cross-repo contracts

Some state is shared and cannot drift. Changing any of it is a **two-repo
change** and must be called out explicitly in the PR body:

- **Postgres tables** shared between the app and the libraries: `jobs`,
  `workers`, `pipeline_configs`, `live_trading_pipeline_profiles`,
  `probabilities_runs`, `pipeline_settings`.
- **Parquet layout** for probability results and scores.
- **Job types and queue names** (e.g. `probabilities-scores-generation` on the
  `scores` queue).
- **The condition encoding contract** in `lar-conditions` -- frozen. Changing it
  silently invalidates every probability parquet already mined.
- **A package's `__all__`** -- the names other repos import.

**Changing a public surface** means: land the library change, cut a tag, bump
the consumer's pin, and say in both PR bodies that they move together. There is
no deprecation window -- an unmoved pin keeps old code working until you move it
deliberately.

**Dependency pinning.** Cross-repo dependencies are pinned exactly -- to a
release tag where the repo cuts releases, to a SHA where it does not. Never
loosen a pin to a range, and never bump one as a side effect of unrelated work.
Bumping a pin is its own commit with its own reason. For local development,
`pip install -e ../<repo>` instead of re-pinning.

## Commits and PRs

- Commit subjects are **imperative and specific about the behaviour change**,
  not the mechanism. Match the existing log: "Stop casting tradables_config_id
  to uuid in signal_candidates queries", not "fix bug" or "update queries.py".
- Branches: `feat/`, `fix/`, `docs/`, `chore/`, `prototype/`.
- One logical change per PR. A mechanical reformat is its own commit, never
  mixed with a behaviour change.
- If you change anything under "Cross-repo contracts", say so in the PR body
  and name the other repo that must move with it.

## What not to do

Each of these has actually happened in these repos:

- **Do not add a second config file for a tool that is already configured.**
  Tool config lives in exactly one place per repo. A `ruff.toml` beside a
  `[tool.ruff]` in `pyproject.toml` silently wins, and the other is dead.
- **Do not add a second formatter.** `ruff format` is the only formatter. Not
  black, not isort, not yapf.
- **Do not widen a test gate by deleting the failing test.** If a test is wrong,
  fix or delete it with a reason in the commit message.
- **Do not leave a config comment describing a state that no longer holds.**
  If you remove the thing a comment explains, remove the comment.
- **Do not reformat a file you are not otherwise changing.** The gate is scoped
  to changed files precisely so that cleanups stay reviewable.
- **Do not edit a vendored standards file** (`ruff.toml`, `mypy.ini`,
  `.editorconfig`, or this block). Change it in `lar-standards` and re-sync.

<!-- END lar-standards shared block -->
