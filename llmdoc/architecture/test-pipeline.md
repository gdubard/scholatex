# Architecture: Test Pipeline

## Purpose

The local-and-CI regression harness that watches `scholatex.cls` + the lua modules + the test corpus under `testfiles/`. The pipeline is built on `l3build` (CTAN's standard package test driver) plus a `rewrite_log` override in `build.lua` that turns the full normalised transcript into a tiny whitelisted slice the team can pin in `.tlg` baselines.

What this pipeline catches:

- New error sites in `scholatex.lua` / `scholatex.cls` whose strings drift from the pinned baseline.
- Class-level dimension drift (`\textwidth`, `\paperwidth`, `\textheight`, `\scholatextab`, `\scholatexline`) via the PIN protocol.
- Class-boot crashes that change the exit code (`recordstatus = true`).
- Regression of the eight doc-gap MWEs (A1, A2, B1, B2, B5, E1-E4).
- Smoke health of the ten image-free example documents.

What it does **not** catch:

- Typesetting glyph layout drift (no PDF diff; `.tlg` is text only).
- Cross-platform reproducibility (TeX Live and font versions only roll on the GitHub runner; local runs use whatever TL the operator has).
- The image-using `containers.tex` example — deferred for image-dep handling, see § "Deferred".
- B3 (literal `\end{document}` in body) and B4 (`--jobname=foo` mismatch) — see § "Deferred".

Owned by `build.lua` (the `rewrite_log` override is the single most material design choice in the toolchain), `testfiles/*.lvt`, `testfiles/support/regression-test.cfg`, `scripts/check-parallel.sh`, `Makefile`. The CI runner is `.github/workflows/ci.yml`.

## The end-to-end loop

```
testfiles/*.lvt  ──►  l3build save -e luatex <name>  ──►  testfiles/*.tlg
                              (intentional regen)         (committed baseline)

testfiles/*.lvt  ──►  l3build check                  ──►  build/test/*.luatex.log
                                                              │
                                              normalize ────► (l3build's pipeline)
                                                              │
                                              rewrite_log ──► (build.lua override)
                                                              │
                                              filter line-by-line ◄── _keep_patterns
                                                              │
                                              diff against ──► testfiles/*.tlg
                                                              │
                                              on drift ──────► build/test/*.luatex.diff
```

Two pipelines run on the same source: `l3build save` (operator-initiated, refreshes the `.tlg`) and `l3build check` (CI-initiated, compares against the `.tlg`). Both go through the same `rewrite_log` override at `build.lua:155-159` so the saved baseline and the checked log share an identical filter pass.

## `build.lua` fields by section

160 lines, declarative. Groups in source order — each row cites the canonical line:

### 1. Package metadata

- `module = "scholatex"` (`build.lua:16`).
- `packtdszip = true`, `tdsroot = "luatex"` (`build.lua:19-20`) — `l3build ctan` emits a TDS-shaped zip rooted under `luatex/`.

### 2. Source layout

- `unpackfiles = { }` (`build.lua:23`) — scholatex has no `.dtx`; the class and lua modules are the canonical sources.
- `sourcefiles = { "scholatex.cls", "scholatex.lua", "scholatex-*.lua" }` (`build.lua:24`).
- `installfiles = sourcefiles` (`build.lua:25`) — `l3build install` copies the same set into TDS.

### 3. Docs

- `typesetfiles = { "scholatex.tex" }`, `typesetexe = "lualatex"` (`build.lua:28-29`).
- `docfiles = { "README.md", "CHANGELOG.md", "LICENSE" }` (`build.lua:31-35`).

### 4. Testing

- `testfiledir = "./testfiles"`, `stdengine = "luatex"`, `checkengines = { "luatex" }`, `checkformat = "latex"`, `checkruns = 1` (`build.lua:38-46`).
- `recordstatus = true` (`build.lua:51`) — pins lualatex's exit code in every `.tlg`. The recorded line is verbatim `Compilation 1 of test file completed with exit status N` (`testfiles/example-basics.tlg:4`, `testfiles/regress-B5.tlg:5`). Status `1` for E1-E4 and B1; status `0` for A1, A2, B2, B5, `pin-class-defaults`, and the 10 smoke tests.

### 5. Upload (`uploadconfig`)

`build.lua:59-77`. Fields populated by `release-ctan-upload.yml` workflow inputs. See `architecture/release-pipeline.md` § "`l3build upload` mechanics".

### 6. Version derivation

`build.lua:83-89`. `read_version()` greps `scholatex.cls` for the `\ProvidesClass{scholatex}[<date> v<X.Y> ...]` line via the Lua pattern `ProvidesClass{scholatex}%[[%d-]+%s+v([%w.+-]+)`. Returns `"dev"` on miss. Assigns `uploadconfig.version = "v" .. read_version()`.

### 7. Baseline whitelist (the centrepiece)

`build.lua:92-159`. See § "Baseline whitelist contract" below — this is the single most material design choice in the toolchain.

## Baseline whitelist contract

### Mechanism

The override at `build.lua:122-159` captures l3build's `rewrite_log` global at file-load time into `_orig_rewrite_log`, then replaces it with a wrapper that:

1. Calls `_orig_rewrite_log(source, result, engine, errlevels)` — l3build's stock normalisation (date stripping, register-number stripping, path canonicalisation).
2. Post-filters the rewritten file line-by-line via `_scholatex_filter(path)` (`build.lua:139-153`), keeping only lines that match one of the ten `_keep_patterns`.

### The ten patterns

`_keep_patterns` (`build.lua:125-137`) — enumerated:

| # | Pattern | Matches |
|---|---|---|
| 1 | `^scholatex:` | Every `error("scholatex: ...")` / `error("scholatex.cls: ...")` / `io.stderr:write("scholatex: warning: ...")` site in the source |
| 2 | `^scholatex%.cls:` | The cls-level boot errors at `scholatex.cls:144-145, 151` |
| 3 | `^Class scholatex Warning` | The `\ClassWarning{scholatex}{...}` emission at `scholatex.cls:154-155` (the B3 multi-`\end{document}` warning) |
| 4 | `^[^:]-scholatex%.lua:` | Stack-trace frames after a Lua error: `./scholatex.lua:NNN: in function 'X'` |
| 5 | `^[^:]-scholatex%-[%w_-]+%.lua:` | Stack-trace frames from `scholatex-figure.lua`, `scholatex-math.lua`, etc. |
| 6 | `^PIN:` | The `\typeout{PIN: ...}` lines that `pin-class-defaults.lvt` emits |
| 7 | `^This is a generated file` | l3build's `.tlg` header line 1 |
| 8 | `^Don't change this file` | l3build's `.tlg` header line 2 |
| 9 | `^%*+$` | The `***************` separator that `recordstatus` writes before the exit-status line |
| 10 | `^Compilation %d+ of test file` | The recordstatus body line: `Compilation N of test file completed with exit status N` |

### Behavioural contract

- **Every new error or warning site MUST start with `scholatex:`, `scholatex.cls:`, or `Class scholatex Warning`**, or it is silently filtered out of every baseline. This is the most consequential rule in the test-pipeline contract.
- Every new `\typeout` in a `pin-*.lvt` must use the `PIN:` prefix.
- l3build's headers, the `*` separator, and the `Compilation N ...` line are preserved verbatim regardless of how `_keep_patterns` evolves (rows 7-10 lock them).
- What gets dropped: every line of font-defaults output, geometry-package verbose, pgfplots compat notices, tcolorbox poster info, the `\InputIfFileExists` chain — 100+ noise lines per test. The whitelist drops them by design.

### Upgrade risk

The override wraps `_orig_rewrite_log` by capturing the global at file-load time. If a future l3build release refactors `rewrite_log` into a method on a config object, the override silently no-ops and every `.tlg` suddenly carries the full normalised log, breaking every baseline at once. There is no automated check for this — a guard rail belongs in `memory/decisions/`.

## `Makefile` target inventory

113 lines. `.PHONY` targets at `Makefile:14`: `help hooks check doc ctan install clean tag`.

| Target | Recipe | Citation |
|---|---|---|
| `help` (default) | `@echo` list of targets with short descriptions | `Makefile:17-32` |
| `hooks` | `git config core.hooksPath .githooks` | `Makefile:35-37` |
| `check` | If `$(J)` > 1, `LUATEX_BUCKETS=$(J) ./scripts/check-parallel.sh`; else `l3build check -q` | `Makefile:47-53` |
| `doc` | `l3build doc` | `Makefile:55-56` |
| `ctan` | `l3build ctan` | `Makefile:58-59` |
| `install` | `l3build install --full --dry-run` (dry-run by default — never installs into `~/texmf` without an explicit live invocation) | `Makefile:61-62` |
| `clean` | `l3build clean` | `Makefile:64-65` |
| `tag` | Validate first non-`tag` MAKECMDGOAL as `v<X.Y>[.<Z>][-rcN]`; create annotated git tag; emit "next: git push origin <tag>" hint | `Makefile:80-102` |

### `J ?= 1` parallel mechanism

`Makefile:45`: `J ?= 1`.

Why `J=N` instead of GNU make's `-j N`: `make -j N` is jobserver-controlled (file-descriptor protocol). The recipe sees a populated jobserver but cannot directly read `N` as an integer; l3build itself is single-process per invocation, so the parallelism must be at the make-target level — and that needs `N` as an explicit number, not a jobserver token. Wiring: `make check J=4` → `LUATEX_BUCKETS=4 ./scripts/check-parallel.sh` (`Makefile:50`). The env-var name `LUATEX_BUCKETS` is for parity with ctex-kit's convention; `BUCKETS=N` is accepted as a synonym (`scripts/check-parallel.sh:6-8, 24`).

### `make tag` validation

The recipe at `Makefile:80-102` reads the first non-`tag` word from `MAKECMDGOALS` as `TAG_NAME` (`Makefile:80`), then validates it against the regex `^v[0-9]+\.[0-9]+(\.[0-9]+)?(-rc[0-9]+)?$` — identical to the regex in `release.yml:32` and `release-ctan-upload.yml:61`, so all three sites share a single validation contract.

A conditional phony noop sub-target (`Makefile:106-112`) absorbs the tag-name argument so make does not complain "no rule to make target 'v2.4'". The recipe finishes with `git tag -a "$(TAG_NAME)" -m "$(TAG_NAME)"`, then prints `next: git push origin <tag>` — the push is intentionally manual so the operator can sanity-check before triggering `release.yml`. See `architecture/release-pipeline.md` § "tag creation flow".

## `scripts/check-parallel.sh`

Algorithm (`scripts/check-parallel.sh:46-121`):

1. **Bucket count** from env (`scripts/check-parallel.sh:24`): `BUCKETS="${LUATEX_BUCKETS:-${BUCKETS:-1}}"`. `LUATEX_BUCKETS` wins; `BUCKETS` is a synonym; default 1.
2. **Sanity**: must run from repo root with `build.lua` present (`scripts/check-parallel.sh:35-38`).
3. **Short-circuit** at BUCKETS ≤ 1: `exec l3build check -q "$@"` and exit (`scripts/check-parallel.sh:42`).
4. **Enumerate** with `find testfiles -maxdepth 1 -name '*.lvt' -printf '%f\n' | sort` (`scripts/check-parallel.sh:46`). Alphabetical bucket assignment — buckets are deterministic across runs.
5. **Cap** buckets to test count if requested > total (`scripts/check-parallel.sh:55-58`).
6. **Slice**: ceiling division `per=$(( (total + BUCKETS - 1) / BUCKETS ))` (`scripts/check-parallel.sh:61`). Last bucket may be smaller.
7. **Workdir setup**: `WORK_ROOT="$REPO_ROOT/tmp/parallel-check"` wiped and re-created (`scripts/check-parallel.sh:63-65`).
8. **Trap on EXIT** (`scripts/check-parallel.sh:68`): on success, wipe the workdir; on failure, preserve it for post-mortem and print the path to stderr.
9. **Per-bucket worker** (`scripts/check-parallel.sh:75-121`):
   - Compute `--first` / `--last` from the slice bounds (`.lvt` basenames without extension).
   - **Isolated tree copy** via `git ls-files -z | tar --null -T- -cf - | tar -xf - -C "$workdir"` (`scripts/check-parallel.sh:91-93`) — delivers exactly the tracked files; any untracked worktree state (build outputs, local scratch directories) is filtered out by `git ls-files`. Fallback to `cp -a` plus an explicit clean-up if git is unavailable.
   - **Spawn** in a subshell with `set +e` (`scripts/check-parallel.sh:101-117`) — this is critical. Without `set +e`, the parent shell's `set -e + pipefail` causes the subshell to exit on l3build's non-zero exit before the diff-dump block can run.
   - `l3build check --first "$first" --last "$last" -q 2>&1 | awk -v p="[$label] " '{print p $0; fflush()}'` prefixes every line with `[bN]` for legibility.
   - Capture l3build's exit via `${PIPESTATUS[0]}` because the awk pipe would otherwise eat it.
   - **Dump-on-fail** (`scripts/check-parallel.sh:109-115`): for each `build/test/*.diff`, print `[bN] ===== <name>.diff =====` then the diff body line-prefixed. Reviewers see the baseline drift in CI logs without downloading an artifact.

Env vars: `LUATEX_BUCKETS` (preferred) or `BUCKETS` (alias).

## `testfiles/` corpus

Total: 20 `.lvt` files = **10 smoke + 9 regression + 1 PIN**.

### Smoke tests (10)

One per image-free example. Each is `\input{regression-test}` on line 1 followed by a byte-identical copy of the corresponding `examples/<name>.tex`:

- `example-algebra.lvt`, `example-analysis.lvt`, `example-basics.lvt`, `example-functions.lvt`, `example-geometry.lvt`, `example-math-algebra.lvt`, `example-math-analysis.lvt`, `example-math-language.lvt`, `example-probability.lvt`, `example-text-style.lvt`.

`examples/containers.tex` is excluded — uses image deps, see § "Deferred".

### Regression tests (9)

Named after the doc-gap rows that triggered them (`memory/doc-gaps.md`). Each pins either an error string + exit code, or just confirms the documented behaviour stays stable:

| Test | Doc-gap | Pinned outcome |
|---|---|---|
| `regress-A1.lvt` | `<box>` `boxsep:` ignored, falls back silently | exit 0 (bug renders without error; pins "no crash") |
| `regress-A2.lvt` | README missing `^` in escape list | exit 0 (doc-only bug; pins "compiles clean") |
| `regress-B1.lvt` | Block opener `{` not at line end → cryptic `unknown tag attribute: 'box'` | exit 1, pins `scholatex: line 3: block opener for 'box' requires ...` (`testfiles/regress-B1.tlg:3`) |
| `regress-B2.lvt` | Bracketed-list `for` items always strings | exit 0 (compiles silently — only a PDF visual diff would expose it) |
| `regress-B5.lvt` | `warn_if_shadows` text now lands in `.log` | exit 0; pins the warning string (`testfiles/regress-B5.tlg:3`) |
| `regress-E1.lvt` | French `angle s'utilise avec des points` translated | exit 1, pins `scholatex: line 3: angle expects point names: angle(A) or angle(ABC)` |
| `regress-E2.lvt` | French `côté égal trop court` translated | exit 1, pins `scholatex: triangle — equal side too short for the given base` |
| `regress-E3.lvt` | French `côtés incompatibles` translated | exit 1, pins `scholatex: triangle — sides violate the triangle inequality` |
| `regress-E4.lvt` | French `la somme des deux angles ...` translated | exit 1, pins `scholatex: triangle — the two given angles sum to 180 degrees or more` |

### PIN test (1)

`testfiles/pin-class-defaults.lvt` — the only test in the corpus that pins class-level dimensions. See § "The `PIN:` typesetting invariant pattern".

### The `\input{regression-test}` wrapper convention

Every `.lvt` opens with literal `\input{regression-test}` on line 1. This pulls in l3build's stock `regression-test.tex` plus this repo's `testfiles/support/regression-test.cfg`.

### `testfiles/support/regression-test.cfg`

Minimal — the entire active payload is two lines (`testfiles/support/regression-test.cfg:24-25`):

```latex
\START
\def\AUTHOR#1{}
```

Three design notes encoded in the file's own comments:

- **No `\OMIT` / `\TIMO` bracketing.** The original cfg had an OMIT pair to silence preamble noise. The build.lua-side whitelist filter already drops everything outside the `scholatex:` / `scholatex.cls:` / `Class scholatex Warning` / `PIN:` namespaces, so per-test OMIT is redundant. Worse — when both were active, `PIN:` `\typeout` lines fired inside the OMIT window were silently dropped, producing empty baselines. The OMIT pair was removed (`testfiles/support/regression-test.cfg:18-22`).
- **`\START` is synchronous at cfg load time, NOT in `\AtBeginDocument`.** `scholatex.cls`'s own `\AtBeginDocument` hook can `tex.error()` (e.g. on missing begin/end document). That error aborts every subsequent `\AtBeginDocument` hook, including the harness's. If `\START` were deferred to that point, failing tests would never emit the marker and l3build would drop the entire transcript as preamble noise (everything before `START-TEST-LOG` is filtered out by l3build itself).
- **`\AUTHOR{...}` swallow.** Some `examples/*.tex` use an `\AUTHOR{...}` macro. Defining it as a no-op avoids "undefined control sequence" errors when an `.lvt` body is a byte-identical copy of `examples/<name>.tex`.

`testfiles/support/` is the only directory whose contents l3build auto-stages into every test work-dir (it is l3build's default `testsuppdir`). A `regression-test.cfg` at `testfiles/` root would be inert.

## The `PIN:` typesetting invariant pattern

Class-level dimensions (`\textwidth`, `\paperwidth`, etc.) are pinned by `\typeout{PIN: ...}` lines that land in the transcript before scholatex's body-rewriting hook fires. The canonical example is `testfiles/pin-class-defaults.lvt`:

```latex
\AddToHook{begindocument/before}{%
  \typeout{PIN: \string\textwidth=\the\textwidth}%
  \typeout{PIN: \string\paperwidth=\the\paperwidth}%
  \typeout{PIN: \string\textheight=\the\textheight}%
  \typeout{PIN: \string\scholatextab=\the\scholatextab}%
  \typeout{PIN: \string\scholatexline=\the\scholatexline}%
}
\documentclass[lang=en, margins=20, size=11, tabwidth=8, lineheight=8]{scholatex}
```

Mechanism:

- `\AddToHook{begindocument/before}` runs **before** `\AtBeginDocument`. By then class-loading + the lengths block have completed, so the dimensions are final, but scholatex's `\AtBeginDocument` body-extraction hook has not yet fired and therefore cannot raise an error before the typeouts.
- Each `\typeout{PIN: ...}` writes a line `PIN: <name>=<dimension>` to the `.log`.
- Whitelist row 6 (`^PIN:`) keeps every such line.
- The baseline at `testfiles/pin-class-defaults.tlg:3-7` pins the five dimensions:
  ```
  PIN: \textwidth=483.69687pt
  PIN: \paperwidth=597.50787pt
  PIN: \textheight=731.23584pt
  PIN: \scholatextab=22.76219pt
  PIN: \scholatexline=22.76219pt
  ```

Coverage contract: any change to `margins=`, `tabwidth=`, `lineheight=`, `size=`, or the `\graphicspath` / `\linespread` chain that perturbs final dimensions flips these pins and forces a deliberate `l3build save`.

Why `begindocument/before` and not `\AtBeginDocument`: scholatex's own `\AtBeginDocument` re-reads the body and emits its own `\end{document}` literal. A `\TEST{label}{body}` placed inside `\begin{document}` would either get transpiled (untranslatable) or skipped entirely. The preamble-side `\AddToHook{begindocument/before}` sidesteps this collision.

## Class-side affordances making this work

Two `scholatex.cls` features exist solely to support the test pipeline:

- **`status.filename` fallback** (`scholatex.cls:138-141`). When `token.is_defined("START")` (regression-test harness loaded) AND `status.filename` is set, `src = status.filename` (with `./` prefix strip) instead of the default `tex.jobname .. ".tex"`. l3build invokes lualatex with `-jobname=<lvtbase>`, so `tex.jobname` resolves to a non-existent `.tex` file; the fallback reads the actual `.lvt` source from `status.filename` instead.
- **B3 truncation warning + `e_pos` capture** (`scholatex.cls:152-156`). The body-extraction regex `\begin{document}(.-)()\end{document}` records the position right after the body via the empty `()` capture; a subsequent `whole:find("\\end{document}", e_pos + 14, true)` triggers `\ClassWarning{scholatex}{source contains more than one \end{document}; body truncated at first occurrence}` — whitelist row 3 pins this warning.

These two affordances are covered in detail in `architecture/compile-pipeline.md` § 1.6 "Body extraction"; this doc references them but does not duplicate the explanation.

## Cycle commands cheat-sheet

| Goal | Command |
|---|---|
| Regenerate one baseline | `l3build save -e luatex <name>` |
| Regenerate all baselines | `rm -rf build && l3build save -e luatex example-algebra example-analysis example-basics example-functions example-geometry example-math-algebra example-math-analysis example-math-language example-probability example-text-style regress-A1 regress-A2 regress-B1 regress-B2 regress-B5 regress-E1 regress-E2 regress-E3 regress-E4 pin-class-defaults` |
| Parallel check (4 buckets) | `make check J=4` |
| Serial check | `make check` |
| One test | `l3build check -q <name>` |
| Local clean | `make clean` |

There is no `make save` target. The recorder may add `make save NAME=<test>` as a future affordance (tracked in `memory/doc-gaps.md`).

## Failure modes

| Symptom | Root cause | Where to look |
|---|---|---|
| `.diff` artifact missing on failed CI | `set -e + pipefail` in `scripts/check-parallel.sh` subshell would have exited before the dump block; mitigated by explicit `set +e` | `scripts/check-parallel.sh:101-117` |
| Empty `.tlg` after `l3build save` | OMIT/TIMO pair active in `regression-test.cfg` swallowed `PIN:` lines; the cfg now omits OMIT entirely | `testfiles/support/regression-test.cfg:18-22` |
| `io.open: cannot read 'X.tex'` on a `.lvt` run | `tex.jobname` resolves to the `.lvt` basename without extension; class needs the `status.filename` fallback to find the actual `.lvt` source | `scholatex.cls:138-141` |
| New error message silently absent from baseline | Message prefix is not `scholatex:` / `scholatex.cls:` / `Class scholatex Warning`; filter dropped it | `build.lua:125-137` |
| Baseline carries hundreds of unrelated lines after l3build upgrade | `_orig_rewrite_log` capture broke (l3build refactored the global to a method) | `build.lua:122` |
| Stuck on `unknown tag attribute: 'box'` instead of the expected explicit error | `regress-B1.lvt` wraps a literal `<box>{...}` on one line; the error path is `scholatex.lua` STYLE classifier raising the cryptic message — the explicit one only fires at `<box>{` on a line by itself | `scholatex.lua:113-172` |

## Deferred

The following items are knowingly absent from the corpus:

- **B3** (`memory/doc-gaps.md` row "literal `\end{document}` in body truncates silently"): no `.lvt` coverage. A `.lvt` whose body literally contains `\end{document}` would itself be terminated by it at the LaTeX parser level — there is no convenient quoting form. The cls-side warning (whitelist row 3) is reachable from a real scholatex document but not from a self-contained `.lvt`.
- **B4** (`--jobname=foo` mismatch): no `.lvt` coverage. l3build accepts `checkopts` as a global string, not as a per-test override; per-test `--jobname` wiring would need a separate harness or a `build.lua` function override.
- **`containers.tex` smoke test**: deferred for image-dep handling. `testfiles/support/` would need to mirror or symlink `examples/IMG/` for `\graphicspath` to resolve, but l3build doesn't follow symlinks to image directories; PNG/JPG assets would need to be either committed under `testfiles/support/IMG/` (size cost) or pulled at test time via a separate script.
- **No `make save` target**: operators must invoke `l3build save -e luatex <name>` directly.

These items live in `memory/doc-gaps.md` with status `partial` (B3, B4) or `deferred` (containers, `make save`).

## Related Docs

- `architecture/compile-pipeline.md` — the cls / lua compile model; covers `scholatex.cls:135-161` body extraction and `scholatex.lua` warning channels in depth.
- `architecture/release-pipeline.md` — the CTAN / GitHub release flow; consumes the `make check` gate via `release.yml`'s CI wait loop.
- `reference/build-and-ci-files.md` — file-by-file reference for `build.lua`, `Makefile`, `.github/`, `scripts/`, `testfiles/`.
- `memory/reflections/l3build-ci-bootstrap.md` — the war stories that produced this design (whitelist-vs-OMIT collision, `set -e` subshell trap, closed-language vs jobname).
- `memory/doc-gaps.md` — rolling list of doc-vs-code drifts; the regression `.lvt` files are MWEs for these rows.
