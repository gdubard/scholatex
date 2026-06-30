# Architecture: Release Pipeline

## Purpose

The path from a `make tag v<X.Y>` invocation to a CTAN-accepted release marked "latest" on GitHub. Two workflows split the responsibility: `release.yml` runs automatically on tag push and produces a GitHub **prerelease** with a CTAN-shaped zip attached; `release-ctan-upload.yml` runs manually via `workflow_dispatch` and either dry-runs the CTAN form construction or POSTs it for real, then flips the GitHub release from prerelease to "latest" on success.

What this pipeline automates:

- Tag-format validation across three sites (`Makefile`, `release.yml`, `release-ctan-upload.yml`) with one shared regex.
- CI gating: the release job blocks until every non-Release workflow on the tagged commit has finished successfully.
- CTAN zip naming with tag + 8-char SHA traceability.
- Release-notes extraction from `CHANGELOG.md` with a three-tier fallback chain.
- Dry-run / live separation via a protected-environment gate.
- Promote-to-latest only after CTAN confirms acceptance — GitHub's `latest` pointer never points at a version CTAN doesn't have.

What it does **not** automate:

- The `git push origin <tag>` after `make tag` — intentionally manual so the operator can sanity-check before triggering CI.
- The CHANGELOG bump — the operator must add `## [<X.Y>]` and the section body before tagging.
- The `ctan-release` GitHub environment provisioning — see § "Outstanding setup".

Owned by `Makefile` (the `tag` target), `.github/workflows/release.yml`, `.github/workflows/release-ctan-upload.yml`, `scripts/extract-changelog.sh`, and the `uploadconfig` block in `build.lua:59-77`.

## End-to-end flow

```
make tag v2.4                                  (local)
    │
    │  validates regex, creates annotated tag, prints push hint
    ▼
git push origin v2.4                           (manual)
    │
    ▼
release.yml on push tag v*                     (GitHub Actions)
    │
    ├─► parse tag, compute SHA                    release.yml:28-40
    ├─► restore TL bypass cache                   release.yml:45-71
    ├─► make ctan  ────►  build/distrib/ctan/scholatex-ctan.zip
    ├─► rename ─────────► scholatex-v2.4-<sha8>.zip
    ├─► scripts/extract-changelog.sh v2.4 ──► release-notes.md
    │       fallback A: git log --pretty='- %s' prev..HEAD
    │       fallback B: echo "Release scholatex 2.4"
    ├─► CI wait loop (poll workflow_runs, 30 min budget)
    │       filter: select(.name != "Release")        ← self-deadlock guard
    │       gate: every run completed AND successful
    └─► gh release create v2.4 <asset> --prerelease --notes-file ...
                                          │
                                          ▼
                              [operator review on GitHub]
                                          │
                                          ▼
release-ctan-upload.yml (workflow_dispatch)    (manual, GitHub Actions)
    inputs: tag, uploader, email, note, dry_run
    │
    ├─► environment gate: dry_run ? '' : 'ctan-release'
    ├─► validate tag regex + note size ≤ 4096 bytes
    ├─► setup-texlive (scheme-minimal + l3build + luatex)
    ├─► gh release download v2.4 *.zip → build/distrib/ctan/
    ├─► rename to scholatex-ctan.zip (l3build's expected name)
    ├─► l3build upload
    │       dry_run: echo n | l3build upload --dry-run
    │       live:    echo y | l3build upload          ← POST to ctan.org/submit/
    └─► if !dry_run: gh release edit --prerelease=false --latest
```

## `make tag` validation

The `tag` recipe at `Makefile:80-102` uses two unusual make tricks:

1. **MAKECMDGOAL parsing** (`Makefile:80`): `TAG_NAME := $(firstword $(filter-out tag,$(MAKECMDGOALS)))` — reads make's command line, strips the `tag` keyword, takes the first remaining word. So `make tag v2.4` gives `TAG_NAME = v2.4`.
2. **Conditional phony noop** (`Makefile:106-112`):
   ```make
   ifneq ($(filter tag,$(MAKECMDGOALS)),)
   ifneq ($(TAG_NAME),)
   .PHONY: $(TAG_NAME)
   $(TAG_NAME):
       @:
   endif
   endif
   ```
   The `@:` is shell's "do nothing, exit 0". Conditionally installed so it only exists when `tag` is invoked, avoiding name pollution.

Validation in the `tag:` recipe (`Makefile:82-101`):

- Reject empty `TAG_NAME` with usage message.
- Validate `TAG_NAME` against `^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$` — identical regex in `release.yml:32` and `release-ctan-upload.yml:61`.
- Reject existing tag with a "to delete: git tag -d <T>" hint.
- `git tag -a "$(TAG_NAME)" -m "$(TAG_NAME)"` to create the annotated tag locally.
- Print `next: git push origin <tag>` — the push is intentionally manual. The operator must `git push origin v2.4` separately to trigger `release.yml`.

## `release.yml` triggers and jobs

150 lines, single job `release`. Triggered on tag push matching `v*` (`release.yml:9-12`):

```yaml
on:
  push:
    tags:
      - 'v*'
```

Permissions: `contents: write` (to create the GitHub release).

### Tag parsing

`release.yml:28-40`:

```bash
tag="${GITHUB_REF#refs/tags/}"
if ! printf '%s' "$tag" | grep -qE '^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$'; then
    echo "::error::tag '$tag' does not match v<X.Y>[.<Z>][-rcN]"
    exit 1
fi
ver="${tag#v}"
sha8=$(git rev-parse --short=8 HEAD)
```

Outputs: `tag`, `ver`, `sha8`. The regex is one of three identical sites — Makefile, `release.yml`, `release-ctan-upload.yml`.

### TL bypass cache

`release.yml:45-71` is byte-identical to the `ci.yml:60-89` cache block. Same key shape: `tl-bypass-<os>-<TL_VERSION>-<iso-week>-<hashFiles('.github/tl_packages')>`. So a release tag pushed in the same ISO week as a recent CI run gets a free cache hit and skips the ~3-5 minute TL install. See `architecture/test-pipeline.md` § "CI run shape" for the cache mechanism rationale.

### Build CTAN zip

`release.yml:73-86`:

```bash
make ctan                                              # -> l3build ctan
src=$(ls build/distrib/ctan/*.zip 2>/dev/null | head -1)
dst="scholatex-${tag}-${sha8}.zip"
cp "$src" "$dst"
```

`l3build ctan` produces `build/distrib/ctan/scholatex-ctan.zip` (the name is l3build's default per `module = "scholatex"` in `build.lua:16`). The rename to `scholatex-<tag>-<sha8>.zip` (e.g. `scholatex-v2.4-1277346e.zip`) encodes both the tag and the short commit for traceability.

## CI gating in `release.yml`

`release.yml:106-139`. The most subtle piece of the release flow.

```bash
sha="${{ github.sha }}"
deadline=$(( $(date +%s) + 1800 ))   # 30 min budget
while :; do
    now=$(date +%s)
    if [ "$now" -ge "$deadline" ]; then
        echo "::error::timed out waiting for CI"
        exit 1
    fi
    json=$(gh api "repos/${{ github.repository }}/actions/runs?head_sha=$sha&per_page=50")
    statuses=$(echo "$json" | jq -r '.workflow_runs[] | select(.name != "Release") | "\(.name)\t\(.status)\t\(.conclusion)"')
    if [ -z "$statuses" ]; then
        sleep 30; continue
    fi
    if echo "$statuses" | awk -F'\t' '{ if ($2!="completed") exit 1 }'; then
        if echo "$statuses" | awk -F'\t' '{ if ($3!="success") exit 1 }'; then
            break
        else
            echo "::error::CI failed on $sha"
            exit 1
        fi
    else
        sleep 30
    fi
done
```

Key behaviours:

- **30-minute budget** keyed off Unix epoch. A larger test corpus or a slow runner could hit this — no graceful extension, the operator would have to manually retry the release workflow.
- **Self-deadlock guard**: `select(.name != "Release")` filters out the Release workflow's own run from the watch list. Without it the Release job would wait for itself indefinitely.
- **Empty-run-list patience**: if `gh api` returns no non-Release runs yet (CI hasn't enqueued or isn't visible), sleep 30s and retry. Common for tags pushed seconds after a commit when GitHub hasn't enqueued CI yet.
- **Three-phase awk gate**:
  1. First awk asserts every run's `status` column is `completed`. Any `in_progress` or `queued` → sleep and retry.
  2. Once all completed, second awk asserts every run's `conclusion` column is `success`. Any non-success → fail the release job with `::error::CI failed on $sha`.
- **Per-line tab-separated format** `<name>\t<status>\t<conclusion>` so awk's `-F'\t'` field split is unambiguous (workflow names can contain spaces).

The gate is: **every non-Release workflow on this commit must complete successfully within 30 minutes**.

## Release notes generation

`release.yml:88-104`. Three-tier fallback chain:

1. **Primary**: `scripts/extract-changelog.sh "$ver"` → `release-notes.md`. If exit 0, log `::notice::release notes from CHANGELOG.md section <ver>`.
2. **Fallback A** (CHANGELOG missing the section): `git log --pretty='- %s' "$prev_tag"..HEAD > release-notes.md` where `prev_tag` is found via `git describe --tags --abbrev=0 --exclude="$current_tag"`.
3. **Fallback B** (no previous tag): `echo "Release scholatex $ver" > release-notes.md`.

A `head -40 release-notes.md` preview runs unconditionally at `release.yml:104` so the operator can sanity-check the notes in the workflow log.

### `scripts/extract-changelog.sh`

57 lines, `set -euo pipefail`. Algorithm:

1. **Argument parsing** (`scripts/extract-changelog.sh:18-21`): exactly one arg or exit 2.
2. **Prefix stripping** (`scripts/extract-changelog.sh:25-28`):
   ```bash
   ver="${1#v}"       # v2.3      -> 2.3
   ver="${ver%%-*}"   # 2.3-rc1   -> 2.3
   ```
   So `v2.3`, `2.3`, `v2.3-rc1`, `2.3-rc1` all resolve to section `2.3`.
3. **awk extraction** (`scripts/extract-changelog.sh:41-48`):
   ```awk
   BEGIN { emit = 0 }
   /^## \[/ {
       if (emit) exit
       if ($0 ~ "^## \\[" ver "\\]") { emit = 1; next }
   }
   emit { print }
   ```
   Walks `CHANGELOG.md`; when `## [<ver>]` matches, sets `emit=1`, skips the heading itself; subsequent lines are printed until the next `## [` heading or EOF.
4. **Empty-result guard** (`scripts/extract-changelog.sh:50-53`): exit 1 with `no section for version '<ver>' found` on stderr.
5. **Trim** leading/trailing blank lines via two `sed '/./,$!d'` invocations sandwiching `tac` (`scripts/extract-changelog.sh:56`).

Exit codes: `0` (section found), `1` (heading not found), `2` (arg count wrong or `CHANGELOG.md` missing).

## `release-ctan-upload.yml` triggers and inputs

122 lines, single job `upload`. `workflow_dispatch` only (`release-ctan-upload.yml:13`).

| Input | Required | Type | Default | Purpose |
|---|---|---|---|---|
| `tag` | yes | string | — | Release tag to upload (e.g. `v2.4`) |
| `uploader` | yes | string | — | CTAN form: uploader real name |
| `email` | yes | string | — | CTAN form: contact email |
| `note` | no | string | `''` | CTAN form: internal note (≤ 4096 bytes) |
| `dry_run` | yes | boolean | `true` | `true` = no actual CTAN submission |

Default `dry_run=true` so an absent-minded operator's first run cannot submit accidentally.

### Input validation

`release-ctan-upload.yml:58-69`:

- Tag against `^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$` — identical to Makefile and release.yml.
- `note` byte-length capped at 4096 (CTAN's limit) via `printf '%s' "$note" | wc -c`.

## The dry-run gate

`release-ctan-upload.yml:52`:

```yaml
environment: ${{ inputs.dry_run && '' || 'ctan-release' }}
```

- **Dry-run path**: empty environment string → no protected environment → anyone with `workflow_dispatch` permission can run.
- **Live path**: `ctan-release` environment → if configured in the GitHub repo UI with required reviewers, blocks until approval.

**Outstanding setup**: the `ctan-release` environment is **not yet provisioned in the GitHub UI**. The dry-run path works today; the live path would either run unprotected (if the environment exists but has no reviewers) or fail to find the environment. Operator action required in Settings → Environments before the first live CTAN upload — see § "Outstanding setup".

## `l3build upload` mechanics

`release-ctan-upload.yml:98-110`:

```yaml
env:
  CTAN_UPLOADER: ${{ inputs.uploader }}
  CTAN_EMAIL:    ${{ inputs.email }}
  CTAN_NOTE:     ${{ inputs.note }}
run: |
  if [ "${{ inputs.dry_run }}" = "true" ]; then
      echo "::notice::dry-run upload (no actual CTAN submission)"
      echo n | l3build upload --dry-run
  else
      echo "::notice::LIVE upload to CTAN"
      echo y | l3build upload
  fi
```

The env vars are read by `build.lua:62-63, 75`:

```lua
uploader = os.getenv("CTAN_UPLOADER") or "",
email    = os.getenv("CTAN_EMAIL")    or "",
note     = os.getenv("CTAN_NOTE")     or "",
```

Two l3build invariants worked around by the `echo n` / `echo y` pipes:

- **`l3build upload --dry-run` still prompts on stdin** `Continue? [y/n]`. `echo n | ...` answers no — the form is constructed but not submitted; the resulting JSON is printed for review. This is a TL 2026 l3build bug — `--dry-run` ought to skip the prompt, but doesn't.
- **`l3build upload` (live)** prompts the same way. `echo y | ...` answers yes — the form is POSTed to `https://ctan.org/submit/`.

Piping the answer via stdin is the only way to make `l3build upload` non-interactive in either mode.

### TL footprint for upload only

`release-ctan-upload.yml:71-79`. This workflow does NOT use the bypass cache. Instead it directly invokes `setup-texlive-action` with a hand-picked subset:

```yaml
packages: |
    scheme-minimal
    l3build
    luatex
cache: true
```

Rationale: the upload step only needs `l3build upload`, which doesn't compile anything. `scheme-minimal` + `l3build` + `luatex` is enough — ~10× smaller than the full corpus and avoids invalidating the release-cache key.

## Promote-to-latest flip

`release-ctan-upload.yml:112-121`:

```yaml
- name: promote release to latest
  if: ${{ inputs.dry_run == false }}
  run: |
      gh release edit "${{ inputs.tag }}" \
        --repo "${{ github.repository }}" \
        --prerelease=false \
        --latest
```

Only fires on live success. `--prerelease=false --latest` flips the GitHub release in two ways:

1. Removes the prerelease badge.
2. Points GitHub's `latest` pointer at this release.

The invariant: **every release is a prerelease until CTAN confirms acceptance**. So GitHub's `latest` pointer never points at a version CTAN doesn't have. If CTAN rejects the form, the GitHub release stays in prerelease state; the operator can fix and rerun `release-ctan-upload.yml` without needing to bump the tag.

## Shared TL bypass cache

Both `ci.yml:48-89` and `release.yml:45-71` re-implement the same `actions/cache@v4` block:

- Key: `tl-bypass-<runner.os>-<TL_VERSION>-<iso-week>-<hashFiles('.github/tl_packages')>`.
- Path: `${{ runner.temp }}/setup-texlive-action/${{ env.TL_VERSION }}`.
- `setup-texlive-action` invoked with `cache: false` to disable its built-in cache.

Why this beats `setup-texlive-action`'s built-in cache: the built-in cache is immutable per primary key. A weekly TLnet refresh would never invalidate it; a package addition would never refresh it. The manual cache rolls weekly via `%G-W%V` (ISO-8601 year + week — Mondays trigger a roll) AND invalidates on `.github/tl_packages` change via the `hashFiles` token.

`release-ctan-upload.yml` does NOT use the bypass cache — see § "TL footprint for upload only" for why.

## Failure modes

| Symptom | Root cause | Where to look |
|---|---|---|
| `release.yml` job red with "tag does not match" | Bad tag format pushed; the regex caught it | `release.yml:28-40` |
| `release.yml` stuck > 30 min | Some non-Release workflow is hanging or queued behind a runner shortage | `release.yml:106-139` — operator must cancel and retry |
| `release.yml` red with "CI failed on <sha>" | `ci.yml` itself failed; check the test-pipeline diffs | `architecture/test-pipeline.md` § "Failure modes" |
| `gh release create` race / 422 | Tag was deleted or release already exists | Operator must `gh release delete <tag>` and re-push or rerun |
| `release-ctan-upload.yml` hangs waiting for env approval | `ctan-release` environment has required reviewers but none approved | GitHub UI: Settings → Environments → ctan-release |
| `l3build upload` live mode fails with HTTP 4xx | CTAN form validation rejected the metadata (invalid uploader, mistyped email, note too long) | Re-run `release-ctan-upload.yml` with `dry_run=true` to inspect the JSON form before retrying live |
| Live upload succeeded but `gh release edit --latest` fails | Release was deleted between upload and promote, or `gh` token lacks `contents: write` | Re-run only the final step manually via `gh release edit` |
| Dry-run prints CTAN form but the live run never prompts | `echo y` answered before l3build read it — this is actually correct behaviour; the worry is unfounded | `release-ctan-upload.yml:104-109` |

## Operator workflow cheat-sheet

1. **Prepare**:
   - Bump `## [<X.Y>]` section in `CHANGELOG.md` with the release notes body.
   - `git commit -m "release: scholatex <X.Y>"`.
   - `make tag v<X.Y>` → validates regex, creates annotated tag locally.
   - `git push origin v<X.Y>` → triggers `release.yml`.

2. **Verify automated prerelease**:
   - Watch `release.yml` complete (or fail) on GitHub Actions.
   - Open the resulting GH release; confirm the zip filename is `scholatex-v<X.Y>-<sha8>.zip` and the notes match the CHANGELOG section.

3. **Dry-run CTAN**:
   - Actions → `Release: CTAN upload` → Run workflow.
   - Inputs: `tag=v<X.Y>`, `uploader=<your name>`, `email=<contact>`, `note=<optional>`, `dry_run=true`.
   - Workflow constructs the CTAN form, prints the JSON, exits without submitting.

4. **Live CTAN**:
   - Same workflow, `dry_run=false`.
   - If `ctan-release` environment has reviewers, wait for approval.
   - On success: form POSTed to CTAN, GitHub release flipped to `latest`.

5. **Post-CTAN**:
   - CTAN review is asynchronous (hours to days). If CTAN rejects, the GH release stays at `latest` — manual rollback via `gh release edit --prerelease`.

## Outstanding setup

- **`ctan-release` GitHub environment is not yet provisioned**. `release-ctan-upload.yml:52` references it but the GitHub UI has no entry yet. Operator action: Settings → Environments → New environment → name `ctan-release`, add required reviewers, optionally store CTAN credentials as environment secrets. Until this is done, live uploads either run unprotected or fail to find the environment depending on default-environment behaviour.

## Related Docs

- `architecture/test-pipeline.md` — the `ci.yml` gate that `release.yml` waits on; covers `_keep_patterns`, the parallel-check harness, and the `.tlg` baseline contract.
- `reference/build-and-ci-files.md` — file-by-file reference for `Makefile`, `.github/workflows/*`, `scripts/*`, `build.lua`'s `uploadconfig`.
- `memory/reflections/l3build-ci-bootstrap.md` — the war stories on `setup-texlive-action`'s broken cache, the `set -e` subshell trap, and the push-discipline failure.
- `memory/doc-gaps.md` — open items including the `ctan-release` environment provisioning.
