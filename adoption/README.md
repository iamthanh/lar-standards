# Adoption kits

Per-repo material for the three repos that have not adopted yet. Each directory
holds the repo-specific tail for its `CLAUDE.md` and the CI file that replaces
its hand-rolled workflow.

`lunar-alpha-research` and `lar-probability-scoring` have already adopted, on
branch `claude/ai-code-structure-guidelines-ela4u1`. Their CI is currently
**inlined** rather than calling the reusable workflow, because this repo did not
exist yet — see "Switching the two adopted repos over" below.

## Step 0: cut the `v1` tag

Everything below pins `@v1`, and nothing resolves until that tag exists. `main`
is pushed; the tag is not, because this session's egress proxy denies tag
pushes (HTTP 403 — an organization policy, not a transient failure). Cut it
locally:

```bash
git clone https://github.com/iamthanh/lar-standards && cd lar-standards
git tag -a v1 -m "v1: initial LAR standards"
git push origin v1
```

Consuming repos pin to the tag rather than `main` for the same reason the LAR
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
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v1/scripts/sync-standards.sh \
  | bash -s -- --ref v1 --target .

# 2. Append the repo-specific tail.
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v1/adoption/<repo>/CLAUDE.tail.md \
  >> CLAUDE.md

# 3. Replace CI.
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v1/adoption/<repo>/ci.yml \
  > .github/workflows/ci.yml

# 4. Confirm nothing drifted.
curl -fsSL https://raw.githubusercontent.com/iamthanh/lar-standards/v1/scripts/check-drift.sh \
  | bash -s -- --ref v1 --target .
```

`sync-standards.sh` seeds `CLAUDE.md` with a "Repo-specific guidance" stub when
the file does not exist. Step 2 appends the real tail; delete the stub heading
so the file has only one.

## Prerequisite: LAR_CI_TOKEN must also cover lar-standards

Every repo's CI needs the `LAR_CI_TOKEN` secret — a PAT with read access to the
private LAR repos. `lunar-alpha-research`, `lar-probability-scoring` and
`lar-conditions` already have it configured; `lar-ingestion` will need it before
its first run.

**`lar-standards` is private too, and the drift job clones it.** The existing
PAT was created for `{lar-conditions, lar-probability-scoring,
strategy-trader}`, so its scope has to be widened to include `lar-standards` or
every drift job fails with a 404 on the clone. That is one edit to the PAT, not
a new secret — the same token is reused.

The drift job fails loudly with a named error when the token is missing, rather
than skipping. A drift check that silently does not run is the failure mode this
whole repo exists to prevent.

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

## Switching the two adopted repos over

Once `v1` is tagged here, replace the inlined `.github/workflows/style.yml` in
each adopted repo with a call to the reusable workflow. The exact replacement
is written at the top of each of those files. For `lunar-alpha-research` the
`test-command` is `''` — its tests are gated by its existing `ci.yml`, which
runs the seam tests rather than the full suite.
