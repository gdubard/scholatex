#!/usr/bin/env bash
# scripts/extract-changelog.sh -- extract one version's section from
# CHANGELOG.md for use as a release-notes body.
#
# Usage:   scripts/extract-changelog.sh <version>
# Example: scripts/extract-changelog.sh v2.3       (prefix accepted)
#          scripts/extract-changelog.sh 2.3        (also accepted)
#
# Output:  the markdown body between `## [<X.Y>] ...` and the next
#          `## [` (or end of file), with the heading line itself stripped
#          so it can be embedded under whatever heading the consumer
#          (gh release create / CTAN announcement) prefers.
#
# Exit:    1 if the version section is not found.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 <version>" >&2
    exit 2
fi

ver="$1"
# strip a leading v if present
ver="${ver#v}"
# strip release-candidate / prerelease suffixes (-rcN, -preN, etc.) so
# v2.4-rc1 finds the 2.4 section
ver="${ver%%-*}"

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

if [ ! -f "$CHANGELOG" ]; then
    echo "extract-changelog: $CHANGELOG not found" >&2
    exit 2
fi

# awk extracts the block starting at `## [<ver>]` until the next `## [`.
# The heading line itself is dropped (NR == start+1 onward) so the body
# can be embedded under a fresh title.
out=$(awk -v ver="$ver" '
    BEGIN { emit = 0 }
    /^## \[/ {
        if (emit) exit
        if ($0 ~ "^## \\[" ver "\\]") { emit = 1; next }
    }
    emit { print }
' "$CHANGELOG")

if [ -z "$out" ]; then
    echo "extract-changelog: no section for version '$ver' found in CHANGELOG.md" >&2
    exit 1
fi

# Trim leading and trailing blank lines for a tidy embed.
printf '%s\n' "$out" | sed -e '/./,$!d' | tac | sed -e '/./,$!d' | tac
