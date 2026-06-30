# Doc Gaps

A rolling list of documentation gaps, doc-vs-code drifts, and undocumented surfaces discovered during the wave-1 init investigations and later development. Group by category. Every row cites the documentation side and the code side with `file:line`.

## Real user-visible bugs

Documentation and code disagree on the same name.

| Issue | Doc claim | Code reality | Citations |
|---|---|---|---|
| `<box>` inner padding option | README says **`sep:N`** ("override locally with `sep:N`"); README and the manual both also say **`boxsep:N`** elsewhere | Code reads `opts.sep` only. `opts.boxsep` is parsed but ignored, silently falling back to the class `padding` default. **PARTIAL FIX (fork only, commit `43dda10`)**: this fork now also honours `opts.boxsep` as an alias; upstream README/code still drift | `README.md:129` (`sep:`) vs `README.md:515` and `scholatex.tex:449` (`boxsep:`); code at `scholatex-box.lua:41`. Pinned MWE: `testfiles/regress-A1.lvt` |
| Auto-escape list missing `^` | README:597 lists "`_ & % ~`" (4 chars) | Code escapes 5 chars (`_ & % ^ ~`); the standalone manual is correct. **PARTIAL FIX (fork README only)**: doc-only fix landed in the fork README; upstream README still missing | `README.md:597` vs `scholatex.lua:299-303` and `scholatex.tex:361`. Pinned MWE: `testfiles/regress-A2.lvt` |
| Examples count says "six" | README copy says "six self-contained" but the table lists seven; the standalone manual says "seven" | `examples/` actually contains **12** `.tex` files. **FIXED (fork only, commit `3306d09`)**: count harmonised across README, `scholatex.tex`, and the on-disk inventory | `README.md:647` (six/seven mismatch) and `scholatex.tex:1123` (seven) vs `ls examples/*.tex` |

## Undocumented surfaces

Features that exist in code but appear in no user-facing document outside example files.

### Inline math geometry vocabulary

The entire inline geometry vocabulary is exercised only in `examples/geometry.tex` and documented in neither `README.md` nor `scholatex.tex`. ~20 named operators:

| Operator | Code | Example use |
|---|---|---|
| `angle(A)` / `angle(ABC)` | `scholatex-math.lua:363-370` | `examples/geometry.tex:29-37, 100` |
| `triangle(ABC)` | `scholatex-math.lua:373-376` | `examples/geometry.tex:95` |
| `arc(AB)` | `scholatex-math.lua:379-382` | `examples/geometry.tex:96` |
| `frame(O, i, j, ...)` | `scholatex-math.lua:386-398` | `examples/geometry.tex:90-92` |
| `orthoframe(O, i, j, ...)` | `scholatex-math.lua:446-458` | `examples/geometry.tex:99` |
| `circle(O, r)` and `circle(A, B, C)` (math) | `scholatex-math.lua:403-413` | `examples/geometry.tex:96-97` |
| `vector(x, y, ...)` | `scholatex-math.lua:417-427` | `examples/geometry.tex:106-111` |
| `colvec(x, y, ...)` | `scholatex-math.lua:430-441` | `examples/geometry.tex:107` |
| `triple(u, v, w)` | `scholatex-math.lua:591-601` | `examples/geometry.tex:79` |
| `vec(.) . vec(.)` and `vec(.) ^ vec(.)` (postfix infix) | `scholatex-math.lua:466-481` | `examples/geometry.tex:52, 58, 82` |
| `ortho(F)` | `scholatex-math.lua:162` (`WRAP1`) | `examples/geometry.tex:77` |
| `collinear(u, v)` | `scholatex-math.lua:179` (`TWOARG`) | `examples/geometry.tex:62, 83` |
| `inner(u, v)` | `scholatex-math.lua:180` (`TWOARG`) | `examples/geometry.tex:76` |
| `distance(A, B)` | `scholatex-math.lua:181` (`TWOARG`) | `examples/geometry.tex:69` |
| `midpoint(A, B)` | `scholatex-math.lua:182` (`TWOARG`) | `examples/geometry.tex:70` |
| `orthogonalprojection(F, x)` | `scholatex-math.lua:183` (`TWOARG`) | `examples/geometry.tex:78` |
| `perp` / `parallel` / `perpendicular` / `rightangle` / `parallelogram` / `nparallel` | `scholatex-math.lua:69-72` (`SYM`) | `examples/geometry.tex:43-45, 95-96` |
| `cong` / `sim` / `congruent` / `similar` | `scholatex-math.lua:62-63` (`SYM`) | `examples/geometry.tex:45` |
| `!parallel`, `!cong`, `!sim` | `scholatex-math.lua:86-87` (`NEG`) | `examples/geometry.tex:44` (`!parallel` only) |
| `°` (UTF-8 U+00B0) inside `$ ... $` → `^{\circ}` | `scholatex-math.lua:779-780` | `examples/geometry.tex:100` |

### Other undocumented math vocabulary

| Names | Code | Status |
|---|---|---|
| `approx equiv propto sim cong mapsto ldots cdots vdots ddots dots times cdot pm mp ast circop star bullet aleph wp Real Imag Top Bot models vdash thus because` | `scholatex-math.lua:43-77` (`SYM`) | Recognised but absent from README and `scholatex.tex` |
| `ni` (reversed `\in`) | `scholatex-math.lua:52` (`SYM`) | Recognised; not documented |
| `union` / `inter` (synonyms for `cup` / `cap`) | `scholatex-math.lua:57` (`SYM`) | Not documented |
| `dotacc` / `ddotacc` / `underbar` | `scholatex-math.lua:113-115` (`ACCENT`) | Not documented |
| `hom` (extra `FUNC`) | `scholatex-math.lua:20` | Not documented |
| `xorsym` (`\oplus`) | `scholatex-math.lua:49` (`SYM`) | Not documented |
| `round(x)` in `FENCE` | `scholatex-math.lua:98` | Mentioned in CHANGELOG 2.1 (`CHANGELOG.md:722`) but absent from the basics math table at `README.md:222-247` and `scholatex.tex:639-671` |

### Undocumented tags and blocks

| Surface | Code | Doc status |
|---|---|---|
| `<figure>` registered as a back-compat alias for `<draw>` | `scholatex-figure.lua:888` ("kept as an alias during the transition") | Nowhere — not in README, not in `scholatex.tex`, not in CHANGELOG |
| Block-form `<section title:{...}>{ body }`, `<subsection>`, `<subsubsection>` | `scholatex-section.lua:48-50, 84-87` (requires `title:` on block form) | Only `scholatex.tex:282-286`. README only shows the attribute form |
| `<table>` accepts `header` or `headers` | `scholatex-table.lua:99` | Only `header` documented |
| `<row>` silently accepts all `<box>` options but uses only `gap:` | `scholatex-box.lua:127` | Undocumented |
| `<matrix>` / `<det>` / `<bmatrix>` / `<system>` explicitly reject options | `scholatex-matrix.lua:69-71, 128-129` ("takes no options") | Undocumented |
| `<table>` rejects `radius:`, `title:`, `width:` with a hint to wrap in `<box>` | `scholatex-table.lua:108-111` | Undocumented |
| `<draw> marks:off` (the explicit `off` value, in addition to default) | `scholatex-figure.lua:741-746` | README only documents `marks:on`, `measures:cm`/`mm` |
| `<draw> labels:` unvalidated | `scholatex-figure.lua:733, 751` (any non-`off` value silently keeps labels on) | Not documented |
| `<plot> y:{c, d}` triples bounds for the internal `restrict y to domain=c*3:d*3` | `scholatex-plot.lua:152-156` | Surface only — docs say "framed" without mentioning the 3× expansion |

### Undocumented body-syntax rules

| Behaviour | Code | Doc status |
|---|---|---|
| Line-start `\%` strips the `\` so a literal `%` survives | `scholatex.lua:508-515` | Only `scholatex.tex:375-376` mentions the comment half; README is silent |
| `for VAR in [a, b, c] { ... }` makes items always strings (`%q`-quoted) | `scholatex.lua:78-80` | Footgun; no doc mentions it. The README shows the bracketed form with file names (always strings) but never warns about numeric items. **B2 — FIXED (fork only, commit `9c9092e`)**: numeric literals now coerce. Pinned MWE: `testfiles/regress-B2.lvt` |
| No `elseif` syntax | `scholatex.lua:67` (only `} else {`) | Not mentioned in docs |
| `BLOCKALIAS` dual-write for `let NAME = <... BLOCK ...>` (non-parametric) | `scholatex.lua:552-557` writes both `BLOCKALIAS[NAME]` and `ALIAS[NAME]` | Undocumented quirk |

### Undocumented class-option surface

| Behaviour | Code | Doc status |
|---|---|---|
| Default-pass-through to `extarticle` for unknown class options (`twocolumn`, `draft`, ...) | `scholatex.cls:26` | Not in README |
| `\graphicspath` always includes `./` first, before any `imgdir` entry | `scholatex.cls:39` | Not in README |

## Stale or duplicate artefacts

| Item | Notes |
|---|---|
| Root-level `text-style.tex` and `math-language.tex` are byte-identical duplicates of files under `examples/` | `diff text-style.tex examples/text-style.tex` and `diff math-language.tex examples/math-language.tex` both return 0. Neither root file is referenced from README, `scholatex.tex`, CHANGELOG, or any module. CHANGELOG 2.1 reorganised examples (`CHANGELOG.md:168-169`) but did not delete the root copies. **FIXED (fork only, commit `b5bfa27`)**: root duplicates deleted |
| Example-count discrepancy | README:647 says "six" but its table lists 7; `scholatex.tex:1123` says 7; the actual count is **12** under `examples/`. The four missing from both docs are `geometry.tex`, `math-algebra.tex`, `math-analysis.tex`, `math-language.tex`. **FIXED (fork only, commit `3306d09`)**: see also the corresponding row in § "Real user-visible bugs" |
| Bilingual error messages | Several validators still raise French strings. Specifically: `scholatex-math.lua:369-370` (`angle s'utilise avec des points`), `scholatex-figure.lua:41` (`côté égal trop court`), `scholatex-figure.lua:54` (`côtés incompatibles`), `scholatex-figure.lua:60` (`la somme des deux angles atteint ou dépasse 180°`). All other v2.3 errors are English; the project's `lang=fr` default does not justify this since the examples all use `lang=en`. **FIXED (fork only)**: E1 `dbc31f6`, E2 `d668a36` (plus err-binding fix `55004d9`), E3 `d187693`, E4 `b428a09`. All four .lvt baselines (`testfiles/regress-E[1-4].lvt`/.tlg) now pin English |

## Compile-time fragility not documented

| Trigger | Failure | Citation |
|---|---|---|
| `tex.jobname` does not match the on-disk source filename (custom `--jobname`, latexmk shadow copies, build wrappers) | Class tries to read `tex.jobname .. ".tex"` from disk and either gets `nil` from `io.open` or reads a different file. **B4 — FIXED (fork only)**: `de3079a` adds nil-safe `io.open` with the explicit error `scholatex.cls: cannot read '<src>'. If you used --jobname, ensure it matches the main source filename.`; followup `e5475b5` adds the test-mode `status.filename` fallback so the l3build harness works. No `.lvt` regression coverage (per-test `checkopts` is not wired in `build.lua`) | `scholatex.cls:135-147` |
| Body literally contains the seven characters `\end{document}` | The non-greedy regex `\begin{document}(.-)\end{document}` truncates at the first occurrence. Body after that is silently dropped. **B3 — PARTIAL FIX (fork only, commit `0541fb3`)**: `\ClassWarning{scholatex}{source contains more than one \end{document}; body truncated at first occurrence}` is now emitted. Truncation still happens. No `.lvt` regression coverage — a `.lvt` containing the literal sequence would self-terminate at the LaTeX parser level | `scholatex.cls:149-156` |
| `<<` / `>>` only collapse when *consecutive*. `< x <` is interpreted as an unterminated tag head | The warning at `scholatex.lua:244-247` catches the unterminated case ("To print a literal `<`, double it as `<<`.") but not the case where `>` appears later in the text | `scholatex.lua:236-264` |
| The block-opener regex requires `{` to be the line's last non-whitespace character. Putting body on the same line as the opener silently flips to the inline-tag path, which errors as `unknown tag attribute: 'box'` | `scholatex.lua:402`; user-visible the rule is the single most common gotcha. **B1 — FIXED (fork only, commit `6250751`)**: explicit error `scholatex: line N: block opener for 'box' requires '{' as the last non-whitespace character on the line` now fires instead of the cryptic "unknown tag attribute". Pinned MWE: `testfiles/regress-B1.lvt`/.tlg | Most mistakes manifest at `scholatex-style.lua:201` |
| `let NAME = <STYLE>` where NAME shadows a built-in tag, block, or style word | The warning at `scholatex.lua:50-58` fires but the alias was previously still installed, silently overwriting the built-in. **B5 — FIXED (fork only) AND regression-covered**: `ee4c5a9` makes `warn_if_shadows` return early so the alias is not written; `0a578a5` adds the `texio.write_nl` dual-channel emit so the warning reaches the `.log`; `e1e0fe0` pins the warning text in `testfiles/regress-B5.tlg` | `scholatex.lua:50-58` |

## Toolchain limitations (added during l3build / CI bootstrap, 2026-06-30)

- **B3 and B4 lack `.lvt` regression coverage.** B3: a `.lvt` containing a literal `\end{document}` would be terminated by it at the LaTeX-parser level before reaching scholatex's hook. B4: per-test `--jobname=foo` is not wireable via the current `build.lua` — l3build accepts `checkopts` as a global string but not per-test. Both bugs are user-visible-fixed (warning emitted / explicit error) but cannot be pinned in baselines without harness changes.
- **`containers.tex` smoke test deferred.** The 10 image-free `examples/*.tex` files have smoke `.lvt` wrappers under `testfiles/`; `containers.tex` is excluded because it pulls images from `examples/IMG/`. `testfiles/support/` would need image staging or symlink resolution. Not attempted.
- **`ctan-release` GitHub environment not provisioned.** `.github/workflows/release-ctan-upload.yml:52` references the `ctan-release` protected environment, but the GitHub UI does not yet have it configured. Live CTAN uploads will block at the environment gate until an operator creates the environment under Settings → Environments and adds required reviewers + secrets. The dry-run path works today (the conditional `${{ inputs.dry_run && '' || 'ctan-release' }}` bypasses the gate).
- **No `make save` target.** The `.lvt` → `.tlg` refresh is operator-typed `l3build save -e luatex <name>` directly; no Makefile wrapper. Adding `make save NAME=<test>` would be a small improvement.
- **`_keep_patterns` whitelist depends on l3build keeping `rewrite_log` as a global.** `build.lua:122` captures `_orig_rewrite_log = rewrite_log` at file-load time. If a future l3build refactors `rewrite_log` into a method on a config object, the override silently no-ops and every `.tlg` grows noise at once. There is no automated upgrade check; this should be revisited on every l3build major version bump.
- **Stale count comment in `.github/tl_packages:31`.** The header comment said "22 entries" for the cls `\RequirePackage` block; the actual block had 27 lines. **FIXED (fork only, commit `bd98852`)**: the regen pass that added `booktabs / chngcntr / fancyvrb` also corrected the block-header comment to "27 entries" and added a new 5th "Manual deps" block for the three new entries. Not load-bearing (the whitelist filter doesn't see this file).

## Cross-references

- Wave-1 stable docs that address these gaps in part: `architecture/compile-pipeline.md` § "Failure modes", `architecture/figure-draw.md` § "Failure modes", `architecture/math-pipeline.md` § "Failure modes".
- Wave-2 docs that will close many of these gaps: `reference/body-syntax-rules.md`, `reference/math-geometry-vocabulary.md`, `reference/draw-shape-catalogue.md`, `reference/text-style-vocabulary.md`.
- The init reflection that triggered this rollup: `memory/reflections/init-process.md`.
