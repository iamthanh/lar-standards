# Python standard

Conventions live in [`agent/CLAUDE.shared.md`](../agent/CLAUDE.shared.md) —
that file is vendored into every repo so agents read it before writing code.
This document covers the **toolchain and how it is enforced**.

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

Whole-repo enforcement was measured before being rejected. Against the three
Python repos as they stand:

| | violations |
|---|---|
| Baseline (`E,F,I,W,UP`, width 100) | 2,744 |
| After `ruff format` + `ruff check --fix` | 435 |
| After also disabling `E501` | **224** |

224 across 834 Python files is a real backlog but not a blocker — *if* it does
not have to be cleared before anything else can merge. So:

- **Changed files must be clean.** New and touched code meets the standard.
- **A whole-repo advisory job** reports the remaining count on every run, so the
  backlog is visible and shrinking rather than forgotten.
- **No mass reformat commit.** Reformatting 530 files at once would conflict
  with everything in flight and bury the policy change in noise. Files come into
  compliance as they are touched.

98 of the 224 are `F405`/`F403` from star imports in one area of
`lar-conditions`, handled with a scoped `per-file-ignores` entry rather than a
rewrite.

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
