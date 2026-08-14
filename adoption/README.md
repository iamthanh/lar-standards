# Adoption kits

Per-repo material for the three repos that have not adopted yet. Each directory
holds the repo-specific tail for its `CLAUDE.md` and the CI file that replaces
its hand-rolled workflow.

`lunar-alpha-research` and `lar-probability-scoring` have already adopted, on
branch `claude/ai-code-structure-guidelines-ela4u1`. Both now call the reusable
workflow, and their `standards drift` and `style` jobs pass — so the pattern the
three repos below are about to follow is proven, not theoretical.

## The current tag is `v2`

Everything below pins `@v2`. **Do not use `v1`** — its drift job hard-required
a credential, and predates the fixes that followed. `v2` is the first usable
tag.

Consuming repos pin to a tag rather than `main` for the same reason the LAR
repos already pin each other by tag or SHA: a moving reference turns an
unrelated upstream edit into a surprise CI change.

## Order

Do `lar-ingestion` first. It is nearly empty, so it is the cheapest way to
confirm the reusable workflow and the drift job actually work before pointing
the big repos at them.

## Steps, per repo

```bash
cd /path/to/<repo>

# 1. Vendor the canonical config and seed CLAUDE.md with the shared block.
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v2/scripts/sync-standards.sh \
  | bash -s -- --ref v2 --target .

# 2. Append the repo-specific tail.
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v2/adoption/<repo>/CLAUDE.tail.md \
  >> CLAUDE.md

# 3. Replace CI.
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v2/adoption/<repo>/ci.yml \
  > .github/workflows/ci.yml

# 4. Confirm nothing drifted.
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v2/scripts/check-drift.sh \
  | bash -s -- --ref v2 --target .
```

`sync-standards.sh` seeds `CLAUDE.md` with a "Repo-specific guidance" stub when
the file does not exist. Step 2 appends the real tail; delete the stub heading
so the file has only one.

## This repo is public, deliberately

It holds lint config, markdown standards, CI definitions and adoption notes —
no secrets, no strategy, no market data. Being public removes two failure modes
that cost real time to diagnose:

- **Reusable workflows resolve.** A private repo does not share its workflows
  with other repositories by default, and when it does not, the caller's run
  fails instantly with zero jobs — no failing step, empty log. It reads as a
  broken caller rather than a missing permission.
- **The drift job needs no credentials**, so adopting a repo no longer depends
  on a PAT's scope being widened in a second place.

Keep it public. If something genuinely secret ever needs to live here, it
belongs in the consuming repo's private tail instead.

## Prerequisite: LAR_CI_TOKEN

Needed only for the **test** job, which installs the private `lar-*` packages
pinned over `git+ssh`. `lunar-alpha-research`, `lar-probability-scoring` and
`lar-conditions` already have it; `lar-ingestion` will need it before its first
run installs anything private.

The drift job does **not** need it — `lar-standards` is public. The token is
used there only when present, for the higher rate limit on busy runners.

## Per-repo notes

**`lar-conditions`** — the largest change of the three. It has ruff configured
in `pyproject.toml` but nothing has ever run it, so the style gate is new in
practice. Remove the `[tool.ruff]` and `[tool.ruff.lint]` sections from
`pyproject.toml` when the vendored `ruff.toml` lands; two configs for one tool
is the failure this repo set exists to end. Its CI also gains a 3.13 leg.

**`lar-probability-engine`** — already gated correctly. This is a lateral move
that buys a shared definition and the drift check, nothing more. Lowest risk,
lowest urgency.

**`lar-ingestion`** — greenfield. Its tail specifies whole-repo enforcement from
the first commit rather than the changed-files scoping the older repos need,
and a `src/` layout from the start.

## Verified end to end

On `lar-probability-scoring` and `lunar-alpha-research`, `ci / standards drift`
and `ci / style (changed files)` both pass against `lar-standards@v2`.

The drift comparison was also tested against deliberate tampering — a changed
`line-length`, an edited line inside the `CLAUDE.md` shared block, and a deleted
`mypy.ini` — and fails on each. It is a guard that actually guards, not one that
passes because it never looked.
