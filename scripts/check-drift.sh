#!/usr/bin/env bash
# Check that a consuming repo's vendored standards match the canonical ones.
# Same comparison CI performs, runnable locally before you push.
#
#   scripts/check-drift.sh [--ref v3] [--target .]
#
# Exits non-zero on any drift, and prints the diff.

set -uo pipefail

REF="v3"
TARGET="."
STANDARDS_REPO="https://github.com/iamthanh/lar-standards.git"

while [ $# -gt 0 ]; do
    case "$1" in
        --ref)    REF="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --depth 1 --branch "$REF" "$STANDARDS_REPO" "$WORK/std" --quiet

status=0

for f in ruff.toml mypy.ini .editorconfig; do
    if [ ! -f "$TARGET/$f" ]; then
        echo "MISSING  $f"
        status=1
    elif diff -u "$WORK/std/config/$f" "$TARGET/$f" > "$WORK/d" 2>&1; then
        echo "ok       $f"
    else
        echo "DRIFTED  $f"
        cat "$WORK/d"
        status=1
    fi
done

if [ ! -f "$TARGET/AGENTS.md" ]; then
    echo "MISSING  AGENTS.md"
    status=1
else
    awk '/BEGIN lar-standards shared block/,/END lar-standards shared block/' \
        "$TARGET/AGENTS.md" > "$WORK/block"
    if diff -u "$WORK/std/agent/AGENTS.shared.md" "$WORK/block" > "$WORK/d" 2>&1; then
        echo "ok       AGENTS.md shared block"
    else
        echo "DRIFTED  AGENTS.md shared block"
        cat "$WORK/d"
        status=1
    fi
fi

# CLAUDE.md must be a symlink, not a copy. A copy is the failure mode this
# whole repo exists to prevent, and it would pass a content comparison on the
# day it was made.
if [ ! -L "$TARGET/CLAUDE.md" ]; then
    if [ -e "$TARGET/CLAUDE.md" ]; then
        echo "DRIFTED  CLAUDE.md is a real file; it must be a symlink to AGENTS.md"
    else
        echo "MISSING  CLAUDE.md symlink -> AGENTS.md"
    fi
    status=1
elif [ "$(readlink "$TARGET/CLAUDE.md")" != "AGENTS.md" ]; then
    echo "DRIFTED  CLAUDE.md points at $(readlink "$TARGET/CLAUDE.md"), expected AGENTS.md"
    status=1
else
    echo "ok       CLAUDE.md -> AGENTS.md"
fi

if [ "$status" -ne 0 ]; then
    echo
    echo "Drift detected against lar-standards@${REF}."
    echo "Fix upstream, then: scripts/sync-standards.sh --ref ${REF} --target ${TARGET}"
fi

exit "$status"
