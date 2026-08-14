#!/usr/bin/env bash
# Pull canonical LAR standards into a consuming repo.
#
#   scripts/sync-standards.sh [--ref v2] [--target .]
#
# Copies config/ruff.toml, config/mypy.ini and config/.editorconfig into the
# target repo root, and refreshes the shared block inside its CLAUDE.md
# in place, leaving repo-specific guidance below the block untouched.
#
# Run this after lar-standards cuts a new tag. CI's drift job fails until you do.

set -euo pipefail

REF="v2"
TARGET="."
STANDARDS_REPO="https://github.com/iamthanh/lar-standards.git"

while [ $# -gt 0 ]; do
    case "$1" in
        --ref)    REF="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
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

CLAUDE="$TARGET/CLAUDE.md"
BLOCK="$WORK/std/agent/CLAUDE.shared.md"

if [ ! -f "$CLAUDE" ]; then
    # No CLAUDE.md yet: seed one with the shared block plus a stub for
    # repo-specific guidance.
    {
        cat "$BLOCK"
        printf '\n## Repo-specific guidance\n\n_Add anything true of this repo alone below. Do not edit the block above._\n'
    } > "$CLAUDE"
    echo "  created CLAUDE.md"
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
    ' "$CLAUDE" > "$WORK/CLAUDE.md.new"

    if ! grep -q "BEGIN lar-standards shared block" "$CLAUDE"; then
        echo "  !! CLAUDE.md has no shared block; prepending one." >&2
        { cat "$BLOCK"; printf '\n'; cat "$CLAUDE"; } > "$WORK/CLAUDE.md.new"
    fi

    mv "$WORK/CLAUDE.md.new" "$CLAUDE"
    echo "  refreshed the shared block in CLAUDE.md"
fi

echo
echo "Done. Review the diff, then commit:"
echo "    git -C $TARGET diff --stat"
