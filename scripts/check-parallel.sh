#!/usr/bin/env bash
# scripts/check-parallel.sh -- run l3build check across N buckets of the
# luatex test corpus in parallel. For scholatex (single-package, luatex
# only), this is the entire -j support.
#
# Usage:  LUATEX_BUCKETS=4 scripts/check-parallel.sh
#         BUCKETS=4 scripts/check-parallel.sh
#         (both accepted; LUATEX_BUCKETS wins for parity with ctex-kit.)
#
# Behaviour:
#   - If buckets <= 1, falls through to a plain `l3build check` and exits.
#   - Otherwise, sorts testfiles/*.lvt alphabetically, slices into N
#     contiguous ranges, and starts N background l3build processes each
#     working in its own isolated worktree under tmp/parallel-check/<n>/.
#   - Each bucket invokes `l3build check --first <first> --last <last>` so
#     it only runs its slice.
#   - Per-bucket stdout/stderr is line-prefixed with [bN] for legibility.
#   - On success: removes tmp/parallel-check/ and exits 0.
#   - On any failure: keeps tmp/parallel-check/ for post-mortem and exits 1.

set -euo pipefail

# ── Inputs ────────────────────────────────────────────────────────────────
BUCKETS="${LUATEX_BUCKETS:-${BUCKETS:-1}}"

if ! [[ "$BUCKETS" =~ ^[0-9]+$ ]] || [ "$BUCKETS" -lt 1 ]; then
    echo "check-parallel: invalid bucket count: $BUCKETS" >&2
    exit 2
fi

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

# Sanity check: must run from a repo with build.lua + testfiles/*.lvt.
if [ ! -f build.lua ]; then
    echo "check-parallel: build.lua not found (run from repo root)" >&2
    exit 2
fi

# ── Single-bucket short-circuit ───────────────────────────────────────────
if [ "$BUCKETS" -le 1 ]; then
    exec l3build check -q "$@"
fi

# ── Multi-bucket: split testfiles alphabetically ──────────────────────────
mapfile -t LVTS < <(find testfiles -maxdepth 1 -name '*.lvt' -printf '%f\n' | sort)
total=${#LVTS[@]}

if [ "$total" -eq 0 ]; then
    echo "check-parallel: no .lvt files in testfiles/" >&2
    exit 2
fi

# Cap buckets to total tests; more buckets than tests is wasteful.
if [ "$BUCKETS" -gt "$total" ]; then
    echo "check-parallel: capping buckets ($BUCKETS) to test count ($total)"
    BUCKETS=$total
fi

# Compute per-bucket size (ceiling division so last bucket may be smaller).
per=$(( (total + BUCKETS - 1) / BUCKETS ))

WORK_ROOT="$REPO_ROOT/tmp/parallel-check"
rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

# Cleanup trap: on failure, leave WORK_ROOT alone; on success, remove it.
trap 'if [ "${FAIL:-1}" -eq 0 ]; then rm -rf "$WORK_ROOT"; else echo "check-parallel: WORK_ROOT preserved at $WORK_ROOT for post-mortem" >&2; fi' EXIT

# ── Spawn bucket workers ──────────────────────────────────────────────────
pids=()
labels=()

i=0
for ((n = 1; n <= BUCKETS; n++)); do
    start=$i
    end=$((i + per - 1))
    [ $end -ge $total ] && end=$((total - 1))
    if [ $start -gt $end ]; then break; fi

    first_lvt=${LVTS[$start]}
    last_lvt=${LVTS[$end]}
    first="${first_lvt%.lvt}"
    last="${last_lvt%.lvt}"

    workdir="$WORK_ROOT/$n"
    mkdir -p "$workdir"
    # Use `git archive` style copy so we get exactly the tracked tree
    # (no build/ leftovers, no untracked scratch); fall back to cp -a
    # if git is unavailable (unlikely but defensive).
    if command -v git >/dev/null && [ -d "$REPO_ROOT/.git" ]; then
        (cd "$REPO_ROOT" && git ls-files -z | tar --null -T- -cf -) \
            | tar -xf - -C "$workdir"
    else
        cp -a "$REPO_ROOT/." "$workdir/"
        # Drop common gitignored worktree state; the cp -a path is a
        # rare fallback so this enumeration is not the source of truth.
        rm -rf "$workdir/build" "$workdir/tmp"
    fi

    label="b$n"
    labels+=("$label:$first..$last")
    (
        set +e
        cd "$workdir"
        l3build check --first "$first" --last "$last" -q 2>&1 \
          | awk -v p="[$label] " '{print p $0; fflush()}'
        rc="${PIPESTATUS[0]}"
        # On failure, dump every .diff l3build produced so reviewers can
        # see the baseline drift without downloading an artifact.
        if [ "$rc" -ne 0 ]; then
            for d in build/test/*.diff; do
                [ -f "$d" ] || continue
                echo "[$label] ===== $(basename "$d") ====="
                awk -v p="[$label] " '{print p $0}' "$d"
            done
        fi
        exit "$rc"
    ) &
    pids+=($!)

    i=$((end + 1))
done

# ── Wait, collect, report ─────────────────────────────────────────────────
FAIL=0
for idx in "${!pids[@]}"; do
    pid=${pids[$idx]}
    label=${labels[$idx]}
    if wait "$pid"; then
        echo "check-parallel: $label OK"
    else
        echo "check-parallel: $label FAIL" >&2
        FAIL=1
    fi
done

if [ $FAIL -eq 0 ]; then
    echo "check-parallel: all $BUCKETS buckets passed"
else
    echo "check-parallel: at least one bucket failed" >&2
fi

exit $FAIL
