# Doc CI Workflow Reflection

## Task

- Two commits on `feat/l3build-ci-release`, both pushed and CI-green:
  1. `bd98852` `ci: add booktabs / chngcntr / fancyvrb for the user manual` — extend `.github/tl_packages` so `scholatex.tex` (the standalone manual) compiles under CI's minimal TL bypass.
  2. `c9ad92a` `ci: add doc workflow that compiles scholatex.tex on every push` — new `.github/workflows/doc.yml` that runs `make doc`, reuses ci.yml's TL bypass cache shape, uploads `scholatex.pdf` (14-day) + `scholatex.log` on failure.
- PR #3 both checks green (CI 1m53s cold, Doc 1m53s cold).

## Expected vs Actual

- Expected: trace `scholatex.tex` with `lualatex --recorder`, diff the resulting dir list against the existing `tl_packages`, add every "new" dir. Maybe 20+ entries. Then wire a separate doc workflow because budgets diverge.
- Actual: the naive --recorder diff produced **23 raw "missing" packages**, but cross-checking against `tlmgr info --json collection-latex | jq -r '.[0].depends[]' | sort -u` (62 transitive deps) revealed that `scheme-basic` already covers the hyperref family (`bigintcalc bitset hycolor intcalc kvdefinekeys ltxcmds pdfescape refcount rerunfilecheck stringenc uniquecounter url`) plus tools/array/longtable/latexconfig/graphics-cfg/etc. The true delta was **3 packages**: `booktabs / chngcntr / fancyvrb`. Also discovered the existing `tl_packages:35 array` line is a phantom name (TLPDB has no package literally named `array`; `array.sty` ships in `tools`); `setup-texlive-action` silently ignored it, which is why CI was green despite the misname.

## What Went Wrong

- Nothing red-CI-visible. All learning was inflationary-risk-avoidance: had the naive 23-entry diff landed, every subsequent tl_packages regen would have churned the cache hash by 20× more than necessary, and the file would have grown a long list of redundant entries that look meaningful but only restate what `collection-latex` already pulls in.
- The original `tl_packages` header comment said "22 entries" for the cls `\RequirePackage` block but the block actually had 27 lines (now fixed). The original regen recipe traced only `examples/*.tex`, not `scholatex.tex` — so the toolchain literally could not have generated the manual's dep set from the documented recipe (now fixed to cover both).
- One discovery cost real time: figuring out that the existing `array` line was a phantom. The first reaction was "I should add `tools` to capture array.sty", until `tlmgr info tools` and `tlmgr info array` together showed `tools` IS the parent and `array` is a not-found name silently tolerated by the action. Decided NOT to remove `array` (out of scope, risk of unknown downstream).

## Root Cause

- The `tl_packages` design assumption was "every directory `lualatex --recorder` reports under `texmf-dist/tex/latex/<dir>/` must be listed". This is *necessary but not sufficient* — `scheme-basic` already includes `collection-latex` whose transitive set covers many of those dirs. Without the cross-check the result is correct-but-bloated.
- `setup-texlive-action` does not warn on not-found package names. Phantom entries silently accumulate; the only way to catch them is `tlmgr info <name>` per entry.
- The standalone manual (`scholatex.tex`) has independent deps from `scholatex.cls`. The cls is exercised by `testfiles/*.lvt` under `lualatex` + l3build; the manual is exercised by `make doc` under `lualatex` directly. They share the project but not the dep set, and the original `tl_packages` regen recipe traced only the examples corpus — so the manual's deps had no provenance.
- ci.yml has a 30-min budget tuned for the check matrix; doc.yml has its own 20-min budget tuned for a single typeset. Combining them in one workflow would force every doc edit through the check matrix and every code edit through an extra typeset run — billing them independently with a shared cache key prime is strictly better.

## Lessons (Hard, Specific, Cited)

1. **Cross-check tl_packages additions against `collection-latex`'s transitive set before adding them.** `scheme-basic` implicitly pulls `collection-latex` (~62 transitive deps including the entire hyperref family, tools, latexconfig, graphics-cfg). A naive `lualatex --recorder` diff inflates the list with no extra coverage. Recipe: `tlmgr info --json collection-latex | jq -r '.[0].depends[]' | sort -u` and intersect against the candidate set; only keep candidates NOT in the intersection. Applied: pruned 23 raw to 3 actual (`booktabs / chngcntr / fancyvrb`) in `bd98852`.

2. **Not every texmf dir name is a valid TLPDB package.** `array.sty` ships inside the `tools` package; `tlmgr info array` returns "package not found". `setup-texlive-action` silently tolerates not-found names — proven by current `.github/tl_packages:35 array` being inert yet CI is green. Validation recipe: `for n in <candidates>; do tlmgr info "$n" 2>&1 | grep -q "^package: *$n" && echo OK $n || echo PHANTOM $n; done`. Apply: run this on every regen pass and audit phantoms before pruning (some may serve as documentation hints even if not load-bearing).

3. **Separate workflow files beat combined steps when budgets diverge AND the cache key shape is shared.** doc.yml runs ~1.9 min cold; ci.yml runs ~7 min cold. Same cache key shape (`tl-bypass-<os>-<TL_VERSION>-<ISO-week>-<hashFiles tl_packages>`) means a single primed cache serves both — no duplicate ~2-min cold install. Apply: when adding a new workflow that exercises the same TL surface, copy the cache step verbatim (path AND key), then differ in `paths-ignore` and the actual run command.

4. **`scholatex.tex` is article-class self-hosted, NOT a class-tests-itself document.** The 154-line `\documentclass[margins=20, size=12, imgdir=IMG]{scholatex}` block inside the manual is verbatim sample code wrapped in `slcode` Verbatim — not an actual `\documentclass`. So `make doc` exercises `article + hyperref + titlesec + booktabs + chngcntr + fancyvrb`, NOT scholatex itself. The cls is exercised only by `testfiles/*.lvt`. Apply: when reasoning about "what does X test", read the `\documentclass` line at the top of the file; do not assume a self-titled manual class-tests itself.

5. **The `--recorder` regen recipe must cover every top-level `.tex` whose compilation matters.** The original recipe traced `examples/*.tex` only; the manual was outside the trace set. Fixed in `bd98852` to cover both `scholatex.tex` AND `examples/*.tex`. Apply: when adding any new top-level `.tex` (manual, sample, integration scaffold) that the toolchain compiles, append it to the for-loop in the `tl_packages` header recipe.

6. **A "manual deps" sub-block in `tl_packages` should be visually distinct from the cls deps block.** The cls's `\RequirePackage` deps (27 entries) and the manual's `\usepackage` deps (3 new entries: `booktabs / chngcntr / fancyvrb`) serve different toolchain paths but live in one file. Applied as a separate suffix block in `bd98852`. Apply: when one TL package list serves multiple compile entrypoints, segregate by entrypoint with clear section headers — flat lists hide provenance.

## Missing Docs or Signals

- `reference/build-and-ci-files.md` § `.github/tl_packages` lists 55 packages in 4 blocks but does not yet name the "How to choose what to list" cross-check pattern (collection-latex intersection). After `bd98852` the file now has 58 packages and a new 5th "Manual deps" block — the row table at lines 80-86 must be updated and the regen recipe at lines 95-103 + 365-373 must mirror the fixed two-source recipe.
- `reference/build-and-ci-files.md` does not yet list `.github/workflows/doc.yml`. The "Files at `.github/`" section currently covers `ci.yml`, `release.yml`, `release-ctan-upload.yml` only. New row needed: trigger, paths-ignore, cache shape (shared with ci.yml), 20-min budget, artifact contract (`scholatex.pdf` 14-day, `scholatex.log` on failure).
- `must/working-agreement.md` § "TL packages sync" (lines 77-79) talks only about `\RequirePackage` in `scholatex.cls`. It does not yet say "adding `\usepackage` to `scholatex.tex` requires the same tl_packages sync." A maintainer adding a `\usepackage{X}` to the manual would not be guided to update `tl_packages`.
- `must/doc-routing.md` § "Build, test, CI, release" (lines 56-65) has six rows; none cover "manual won't compile" or "doc workflow failed". A reader hitting a `make doc` failure has no entry-point row.
- `architecture/release-pipeline.md` (referenced from index but not read in this task) likely needs a note that `make doc` is now a CI-gated invariant on every push, not just a manual-operator action.
- `memory/doc-gaps.md` § "Toolchain limitations" row at line 113 says `tl_packages:31` comment claims "22 entries". This is now FIXED in `bd98852` (correctly says 27 + the new 3-entry manual block). The row should be marked resolved or removed.

## Promotion Candidates

- **Lesson 1 (collection-latex cross-check)** → new subsection "How to choose what to list" in `reference/build-and-ci-files.md` § `.github/tl_packages`, between the block-counts table and the regeneration recipe. Include the verbatim `tlmgr info --json` command and the intersection workflow.
- **Lesson 2 (phantom names)** → either a row in `reference/build-and-ci-files.md` known-limitations list, or a new entry under `memory/doc-gaps.md` § "Toolchain limitations" naming `array` as a phantom-but-tolerated entry.
- **Lesson 3 (separate workflows, shared cache key)** → new `.github/workflows/doc.yml` row in `reference/build-and-ci-files.md`, sibling to the ci.yml / release.yml entries. Body should emphasise the shared cache-key shape and the budget-divergence rationale.
- **Lesson 4 (scholatex.tex is article-class self-hosted)** → brief note in `reference/build-and-ci-files.md` § `doc.yml` entry, OR a short paragraph in `architecture/release-pipeline.md` once that doc covers `make doc` as a CI invariant.
- **Lesson 5 ("regen must cover every compile entrypoint")** → fold into the updated regen recipe in `reference/build-and-ci-files.md`. The recipe at lines 95-103 and the duplicate at lines 365-373 should both grow a `scholatex.tex` iteration step.
- **"Adding `\usepackage` to `scholatex.tex` requires tl_packages sync"** → extend `must/working-agreement.md` § "TL packages sync" (line 77-79) to name both `\RequirePackage` in cls AND `\usepackage` in `scholatex.tex` (and any future top-level `.tex` that CI compiles).
- **"Manual won't compile" row** → new row in `must/doc-routing.md` § "Build, test, CI, release", pointing to `reference/build-and-ci-files.md` § `doc.yml` and to the regen recipe.

## Follow-up

- Update `reference/build-and-ci-files.md` per the four bullets above (new doc.yml entry, 5th tl_packages block, regen recipe with `scholatex.tex`, "How to choose what to list" subsection).
- Mark the `tl_packages:31` "22 entries" row in `memory/doc-gaps.md` § "Toolchain limitations" as resolved (or delete it).
- Audit the phantom-name surface: the existing `tl_packages` lines `array`, possibly `graphics` (also lives in `graphics-cfg` / built-in), and any others should be passed through the `tlmgr info` validator in a separate commit if cache hygiene becomes a concern. Current value is zero (nothing breaks); cost is one-off hash churn on the next TL minor version regen pass.
- The `tl_packages` header comment now correctly says "27 entries" for the cls block. Consider whether the new "Manual deps" suffix block deserves its own header line + recipe-source note ("derived from `lualatex --recorder scholatex.tex`, intersected against `collection-latex`").
- Extend `must/working-agreement.md` § "TL packages sync" to cover `\usepackage` in `scholatex.tex` alongside `\RequirePackage` in cls.
- Add a "manual won't compile" row to `must/doc-routing.md` § "Build, test, CI, release".
- If `architecture/release-pipeline.md` is rewritten in a future task, include the `make doc` CI invariant and the doc.yml/ci.yml cache-sharing relationship.
