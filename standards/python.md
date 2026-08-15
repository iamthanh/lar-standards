# Python standard

Conventions live in [`agent/AGENTS.shared.md`](../agent/AGENTS.shared.md) —
that file is vendored into every repo's `AGENTS.md` so agents read it before
writing code.
This document covers the **package layout, the toolchain, and how both are
enforced**.

## Package layout

```
lar-<name>/
├── pyproject.toml          [tool.setuptools.packages.find] where = ["src"]
├── README.md               links here; does not restate this
├── AGENTS.md               shared block + repo tail
├── CLAUDE.md -> AGENTS.md  symlink, never a copy
├── ruff.toml  mypy.ini  .editorconfig      vendored from lar-standards
├── docs/                   design notes, contracts, migration plan
├── scripts/                dev/ops scripts, not packaged
├── src/lar_<name>/
│   ├── __init__.py
│   ├── cli.py              Click group, exposed via [project.scripts]
│   ├── api/                only if the repo serves one
│   ├── compat/             modules vendored from lunar-alpha-research
│   └── <domain packages>/
└── tests/                  flat, test_<module>.py; subdirs for fixtures only
```

The repo directory is hyphenated (the distribution name) and the package under
`src/` is underscored (the import name). `lar-probability-scoring` installs as
`lar_probability_scoring`.

`tests/` is **flat** — `test_<module>.py`, with subdirectories only for fixtures
and golden data. Mirroring the package tree was the earlier rule and no repo
ever followed it: `lar-probability-scoring` has `_infra/` and `api/` in the
package and only `golden/` under `tests/`. The standard now matches what the
repos do rather than what they were told to do.

### Why `src/`

Flat layout is not wrong — requests, django, numpy and pandas all use it. `src/`
is what the Python Packaging Authority recommends, and pip, setuptools, attrs,
black, flask and pytest follow it. Either is defensible, so the reason to pick
one is that four layouts across five repos is what this repo exists to stop.

The tie-breaker is specific to how these repos consume each other. With flat
layout, `import lar_probability_scoring` from the repo root resolves to the
**source tree**, not the installed package. A module accidentally left out of the
wheel keeps working locally and fails wherever it is actually installed —
and `lunar-alpha-research` installs that package **by tag**, so source and
installed genuinely diverge. Under `src/` the import can only resolve to
something that was installed, which makes local runs and CI agree.

`lar-conditions` already used `src/`, but as a diagram rather than a decision:
its migration plan records reasons for ten choices — language, bridge style,
config format, distribution, DB access, sequencing — and layout is not among
them. This section is that missing rationale.

### `api/` lives inside the package

At `src/lar_<name>/api/`, holding the app factory, routes and service layer,
started through a `serve` subcommand on the repo's CLI.

This one is not a preference. At the repo root, `api/` is not importable as
`lar_<name>.api` and `packages.find` does not ship it. `lar-probability-scoring`
is the reference shape.

Since the frontend moved to `lar-ui`, **an `api/` package is a cross-repo
contract**: a route or response-model change is a two-repo change, and the
OpenAPI export is how the other side sees it.

### `compat/` holds code copied from `lunar-alpha-research`

One name, everywhere, so the copies are visible rather than scattered.
`lar-conditions` uses `src/lar_conditions/compat/`, and `lar-ingestion`'s plan
adopts it for the same reason.

`_infra/` is the sibling for a repo's **own** internal-only helpers. The two are
both internal and neither is public surface — they differ in origin, not
visibility. Most repos have only one: everything under
`lar-probability-scoring`'s was traced back to `lunar-alpha-research`, including
two modules that had been renamed on the way (`dates.py` from `common/utils/`,
`live_profiles_db.py` a two-function subset of
`common/db_queries/live_trading_pipeline_profiles.py`), so that repo has no
`_infra/` at all.

Vendored code drifts. `lunar-alpha-research` runs a drift guard that hashes each
original and fails when one changes without the copy following — two bugs got
through before it existed, a SQL cast copied onto a column of a different type
and a calculation duplicated in two places that then diverged for 85.8% of rows.
Quarantining copies under one directory is what makes that check possible.

### Where each repo stands

| repo | layout | vendored dir |
|---|---|---|
| `lar-conditions` | `src/` | `compat/` |
| `lar-ingestion` | `src/` (planned) | `compat/` (planned) |
| `lar-probability-scoring` | flat — **migrating** | `_infra/` — **migrating** |
| `lar-utils` | `src/` (new repo — start there) | n/a |
| `lunar-alpha-research` | application, not a package | n/a |
| `lar-probability-engine` | Rust; see [rust.md](rust.md) | n/a |
| `lar-ui` | TypeScript/React; this standard does not apply | n/a |

## Toolchain

One tool, one job. Anything else is removed on adoption.

| Job | Tool | Config | Gate |
|---|---|---|---|
| Format | `ruff format` | `config/ruff.toml` | **blocking**, changed files |
| Lint / import order | `ruff check` | `config/ruff.toml` | **blocking**, changed files |
| Types | `mypy` | `config/mypy.ini` | advisory |
| Tests | `pytest` | repo's `pyproject.toml` | **blocking**, whole suite |

Explicitly **not** used: `black`, `isort`, `pylint`, `flake8`, `yapf`.
`ruff format` replaces black; ruff's `I` rules replace isort. `lunar-alpha-research`
was running ruff-format *and* black over the same files, neither configured — that
is the exact failure this table prevents.

## Settings and why

- **Line length 100.** `lar-conditions` had deliberately chosen 100; the 88 in
  `lunar-alpha-research` was an unconfigured default in two tools that happened
  to agree. 100 suits the long expressions in the analytics code.
- **`target-version = py312`.** The lowest floor any LAR library supports.
  `lunar-alpha-research` is an application and may *run* on 3.13, but every
  library it imports must stay importable on 3.12.
- **`E501` disabled.** `ruff format` enforces width structurally. What survives
  it — long string literals, URLs, comment tables — cannot be fixed by the
  author, only silenced with `noqa`. Enabling both a formatter and E501 is a
  noise generator.
- **`asyncio_mode = "strict"`.** `lar-probability-scoring` used `auto` and
  `lar-conditions` used `strict`; async tests moving between them broke
  silently. `strict` is pytest-asyncio's own default and makes the intent
  visible at each test.

## The gate is scoped to changed files

Whole-repo enforcement was measured before being scoped down. Running the
shipped config against the three Python repos as they stand:

| repo | violations | auto-fixable | left after `format` + `--fix` |
|---|---|---|---|
| `lunar-alpha-research` | 1,471 | 1,337 | **66** |
| `lar-conditions` | 176 | 130 | **17** |
| `lar-probability-scoring` | 164 | 151 | **4** |
| **total** | **1,811** | — | **87** |

87 residual violations across 834 Python files. The gate is still scoped to
changed files, but for a different reason than the raw count suggests:

- **Changed files must be clean.** New and touched code meets the standard.
- **A whole-repo advisory job** reports the remaining count on every run, so the
  backlog stays visible.
- **No mass reformat commit.** Not because the backlog is large, but because
  reformatting 530 files in `lunar-alpha-research` at once would conflict with
  everything in flight and bury a policy change in mechanical noise. Files come
  into compliance as they are touched.

The 98 `F403`/`F405` findings that dominated the earlier count all live in two
`lar-conditions` files (`intraday/bar_local_conditions.py`,
`intraday/conditions.py`), which build their condition namespace with star
imports. A scoped `per-file-ignores` entry handles them; those paths do not
exist in the other repos, so the config stays byte-identical everywhere.

**Note that per-file-ignore patterns resolve relative to the config file's
location.** They work with a vendored `ruff.toml` at the repo root, which is how
the config is deployed, but silently miss if you point ruff at the canonical
file by absolute path.

At 87, promoting the gate from changed-files to whole-repo is a near-term step,
not an aspiration — clear the residue per repo (`lar-probability-scoring` is 4)
and flip it.

## Ratchet

Each step is a deliberate PR, not a drive-by. Do the cleanup first, then flip
the switch, so the gate never lands red.

1. **`B` (flake8-bugbear)** — +110 findings, dominated by `B904`
   (`raise ... from`) and `B905` (`zip(..., strict=)`). Both are real
   correctness smells worth fixing.
2. **`SIM`, `RET`, `C4`** — +110 more, stylistic.
3. **mypy blocking, module by module.** Add a `[mypy-<module>.*]` section with
   `disallow_untyped_defs = True` as each area reaches full annotation. Do not
   flip it globally.
4. **`E501` never returns.** It is off permanently by design, not by backlog.

## Python version policy

- Libraries (`lar-conditions`, `lar-probability-scoring`, `lar-ingestion`):
  `requires-python = ">=3.12"`, CI matrix `["3.12", "3.13"]`.
- The application (`lunar-alpha-research`): `requires-python = ">=3.13"`, CI on
  `3.13` only.

A library tested on only one version will eventually break the other. Today
`lar-conditions` tests 3.12 alone while being consumed by a 3.13 application —
the matrix closes that gap.
