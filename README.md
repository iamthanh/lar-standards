# lar-standards

Canonical code standards for the LAR repos: `lunar-alpha-research`,
`lar-conditions`, `lar-probability-scoring`, `lar-probability-engine`,
`lar-ingestion`.

One source of truth for lint config, CI, and the instructions agents read
before they write code. Consuming repos vendor a copy and CI fails if the copy
drifts.

## Why this exists

The five repos had drifted along every axis at once — four package layouts,
three lint stacks (one of them running two formatters), two line widths, two
Python floors, conflicting `asyncio_mode` settings, and four hand-rolled CI
workflows. `lunar-alpha-research` alone configured mypy in three files with
different settings, pytest in two, and pylint in three.

None of that is the real problem. The real problem was that **no repo contained
a single instruction for an agent writing code in it** — no `CLAUDE.md`, no
`CONTRIBUTING.md`, no `.editorconfig`. Every session started cold and inferred
conventions from whichever file it opened first. The tell is in the numbers:
`from __future__ import annotations` sits at 250/530, 99/244 and 31/60 files
across the three Python repos — a coin flip in all three, which is exactly what
"nobody was ever told" looks like.

## The model

Three layers, in descending order of how much they actually hold:

1. **Enforced floor** — `ruff format`, `ruff check`, `pytest`, `cargo
   fmt/clippy`. Identical config everywhere, gated in CI, zero human attention.
2. **Agent instructions** — [`agent/CLAUDE.shared.md`](agent/CLAUDE.shared.md),
   vendored into every repo's `CLAUDE.md`. This covers what a linter cannot:
   which repo owns what, seam rules, contract rules, and the specific mistakes
   that have already happened here.
3. **Human review** — [`standards/review-checklist.md`](standards/review-checklist.md),
   six items, none of them style.

A style guide only humans read will not survive AI-written code, because code
arrives faster than review does. Layers 1 and 2 are the ones that scale; layer 3
is the small residue that genuinely needs judgment.

## Layout

```
config/          canonical ruff.toml, mypy.ini, .editorconfig  (vendored downstream)
agent/           CLAUDE.shared.md — the block every repo's CLAUDE.md contains
standards/       the written standards: python, rust, review checklist
.github/workflows/
  python-ci.yml  reusable (workflow_call) — called by the Python repos
  rust-ci.yml    reusable (workflow_call) — called by lar-probability-engine
scripts/
  sync-standards.sh   pull canonical config into a consuming repo
  check-drift.sh      the same comparison CI runs, locally
```

## Adopting this in a repo

```bash
# from the consuming repo's root
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v2/scripts/sync-standards.sh \
  | bash -s -- --ref v2 --target .
```

Then replace the repo's CI with a call to the reusable workflow:

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ci:
    uses: iamthanh/lar-standards/.github/workflows/python-ci.yml@v2
    with:
      python-versions: '["3.12", "3.13"]'
      install: 'pip install -e ".[dev]"'
      # Match this to the tag pinned above. Passing it explicitly keeps the
      # workflow you run and the standards you are compared against in step.
      standards-ref: 'v2'
    secrets:
      ci-token: ${{ secrets.LAR_CI_TOKEN }}
```

Finally, delete whatever the repo was using before — `black`, `isort`,
`pylint`, and any duplicate `mypy.ini` / `setup.cfg` / `[tool.*]` sections.
Two configs for one tool is the failure mode this repo exists to end.

## Changing a standard

1. Edit here. Never edit a vendored copy — the drift job will fail it.
2. Cut a tag (`v2`, `v3`, ...). Consuming repos pin to the tag.
3. Run `scripts/sync-standards.sh --ref <tag>` in each consumer and commit.

Moving the current tag is allowed for additive, non-breaking changes. Anything
that turns previously-passing code red gets a new major tag so repos can adopt
on their own schedule.

**The current tag is `v2`. `v1` is broken and must not be used** — its drift job
cloned this private repo without credentials, so it 404s on any runner. That is
also the worked example for the rule above: a fix that turns red into green in
one direction can turn green into red in the other, so it got a new tag rather
than moving the old one.

## Enforcement posture

Format and lint **block the merge**, scoped to files the PR changed. Types are
**advisory**. The reasoning, the measured backlog, and the ratchet plan for
tightening both are in [`standards/python.md`](standards/python.md).
