#!/usr/bin/env bash
# Pull canonical LAR standards into a consuming repo.
#
#   scripts/sync-standards.sh [--ref v4] [--target .]
#
# Copies config/ruff.toml, config/mypy.ini and config/.editorconfig into the
# target repo root, refreshes the shared block inside its AGENTS.md in place
# (leaving repo-specific guidance below the block untouched), and ensures
# CLAUDE.md is a symlink to AGENTS.md.
#
# AGENTS.md is the cross-tool standard, read natively by Claude Code, Codex,
# Cursor, Copilot, Gemini CLI and others. CLAUDE.md is kept as a symlink because
# sources disagree on which file wins when both exist -- pointing them at the
# same bytes makes the question moot.
#
# Run this after lar-standards cuts a new tag. CI's drift job fails until you do.

set -euo pipefail

REF="v4"
TARGET="."
STANDARDS_REPO="https://github.com/iamthanh/lar-standards.git"

while [ $# -gt 0 ]; do
    case "$1" in
        --ref)    REF="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[ -d "$TARGET" ] || { echo "target is not a directory: $TARGET" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Fetching lar-standards@${REF} ..."
git clone --depth 1 --branch "$REF" "$STANDARDS_REPO" "$WORK/std" --quiet

for f in ruff.toml mypy.ini .editorconfig; do
    cp "$WORK/std/config/$f" "$TARGET/$f"
    echo "  wrote $f"
done

AGENTS="$TARGET/AGENTS.md"
CLAUDE="$TARGET/CLAUDE.md"
BLOCK="$WORK/std/agent/AGENTS.shared.md"

# A pre-AGENTS.md repo has a real CLAUDE.md. Move it rather than lose the
# repo-specific guidance below the block.
if [ ! -e "$AGENTS" ] && [ -f "$CLAUDE" ] && [ ! -L "$CLAUDE" ]; then
    mv "$CLAUDE" "$AGENTS"
    echo "  migrated CLAUDE.md -> AGENTS.md"
fi

if [ ! -e "$AGENTS" ]; then
    {
        cat "$BLOCK"
        printf '\n## Repo-specific guidance\n\n_Add anything true of this repo alone below. Do not edit the block above._\n'
    } > "$AGENTS"
    echo "  created AGENTS.md"
elif ! grep -q "BEGIN lar-standards shared block" "$AGENTS"; then
    { cat "$BLOCK"; printf '\n'; cat "$AGENTS"; } > "$WORK/AGENTS.md.new"
    mv "$WORK/AGENTS.md.new" "$AGENTS"
    echo "  !! AGENTS.md had no shared block; prepended one." >&2
else
    # Replace only the delimited region; everything outside it survives.
    awk -v blockfile="$BLOCK" '
        /BEGIN lar-standards shared block/ {
            while ((getline line < blockfile) > 0) print line
            close(blockfile)
            skipping = 1
            next
        }
        /END lar-standards shared block/ { skipping = 0; next }
        !skipping { print }
    ' "$AGENTS" > "$WORK/AGENTS.md.new"
    mv "$WORK/AGENTS.md.new" "$AGENTS"
    echo "  refreshed the shared block in AGENTS.md"
fi

# CLAUDE.md must be a symlink to AGENTS.md, never a copy -- two real files drift.
if [ -L "$CLAUDE" ] && [ "$(readlink "$CLAUDE")" = "AGENTS.md" ]; then
    echo "  CLAUDE.md symlink already correct"
else
    rm -f "$CLAUDE"
    ln -s AGENTS.md "$CLAUDE"
    echo "  linked CLAUDE.md -> AGENTS.md"
fi

echo
echo "Done. Review the diff, then commit:"
echo "    git -C $TARGET diff --stat"
