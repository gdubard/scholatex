# Doc Routing

Use this decision tree to pick the next document or source file. Each row gives a typical situation, the document to read next, and the source file the work will likely touch.

## Extending the language

| Situation | Read next | Likely source file |
|---|---|---|
| Add a new shape inside `<draw>` | `architecture/figure-draw.md`, then `reference/draw-shape-catalogue.md` | `scholatex-figure.lua` |
| Add a new math operator or wrapper | `architecture/math-pipeline.md`, then `reference/math-vocabulary.md` to avoid a name collision | `scholatex-math.lua` |
| Add a new geometry math operator | `architecture/math-pipeline.md`, then `reference/math-geometry-vocabulary.md` | `scholatex-math.lua` |
| Register a new tag or block | `guides/add-tag-or-block.md`, then `architecture/compile-pipeline.md` § "dispatch priority" | New `scholatex-*.lua` plus the eager-load list in `scholatex.lua:779-789` |
| Add a new style word (font, alignment, skip, etc.) | `architecture/style-and-tags.md`, then `reference/text-style-vocabulary.md` | `scholatex-style.lua` |
| Add a new class option | `reference/class-options.md`, then check the consumption sites listed there | `scholatex.cls` and possibly `scholatex.lua` config wiring |

## Diagnosing a compile failure

| Error message | Read next |
|---|---|
| `scholatex.cls: begin/end document not found` | `architecture/compile-pipeline.md` § "Failure modes" and `reference/body-syntax-rules.md` § "Edge effects" — usually a `tex.jobname` mismatch (custom `--jobname`, latexmk shadow copy) or a literal `\end{document}` appearing inside the body |
| `scholatex: unknown tag attribute: 'X'` | `reference/body-syntax-rules.md` — the line is being parsed as an inline tag with `X` as an unknown style word. Either `X` is misspelled, or it is a block whose `{` was not the last non-whitespace character on the line |
| `'red' is not a colour; colours are written in CamelCase now -- use 'Red'` | Just rename to `Red`. See `reference/text-style-vocabulary.md` for the colour list |
| `scholatex: untrusted document exceeded the instruction limit ...` | `architecture/compile-pipeline.md` § "Sandbox" — the 2·10⁷ Lua-VM-instruction budget under `untrusted=true`. Either reduce the loop count or compile with `untrusted=false` |
| `scholatex: string.X result too large in untrusted mode (limit 100000 characters)` | Same — the 10⁵-character output cap on `string.rep` / `string.format` |
| `scholatex: line N: unbalanced '{' / '}'` | `reference/body-syntax-rules.md` § "Brace balance" — the pre-pass validator at `scholatex.lua:575-595` runs on raw braces and pairs `{{` with `}}` correctly. The diagnostic line number is the first unmatched character |
| `scholatex: transpilation error\n...` | The generated Lua chunk failed to load. Almost always a malformed `let`-bound EXPR or an interpolation `#{expr}`. Re-read the body for stray braces |
| `scholatex: 'X' is not available in untrusted mode ...` | A user `#{expr}` reached for a global outside `SANDBOX_ALLOW`. See `architecture/compile-pipeline.md` § "Sandbox" |
| `scholatex: tag '<name>' is already registered (name clash)` | Module collision. Grep the existing registry. See `must/project-basics.md` § "Naming taboo" |

## Known doc-vs-code drift

| Situation | Read next |
|---|---|
| User reports `<box>` `sep:N` doesn't work or vice-versa with `boxsep:N` | `memory/doc-gaps.md` § "Real user-visible bugs". The code reads `opts.sep` (`scholatex-box.lua:41`); `README.md:129` documents `sep:`, `README.md:515` and `scholatex.tex:449` document `boxsep:` |
| User asks why `^` is not in the auto-escape list | `memory/doc-gaps.md`. `README.md:597` lists `_ & % ~` and omits `^`; the code (`scholatex.lua:299-303`) and `scholatex.tex:361` include `^` |
| User asks about `<figure>` | `memory/doc-gaps.md`. `<figure>` is a back-compat alias for `<draw>` (`scholatex-figure.lua:888`) but is documented nowhere |
| Math operator name found in `examples/geometry.tex` but not in README | `memory/doc-gaps.md`. The whole inline geometry vocabulary is undocumented outside that example file |
| Two root-level files `text-style.tex` and `math-language.tex` | `memory/doc-gaps.md`. They are byte-identical duplicates of files under `examples/` |

## Writing or fixing examples

| Situation | Read next |
|---|---|
| Write a new example document | `guides/write-example-document.md` — the canonical idioms |
| Verify a tag/block does what the example claims | `architecture/compile-pipeline.md` § "Three-way dispatch" + the relevant `scholatex-*.lua` module |

## Process and meta

| Situation | Read next |
|---|---|
| Running an `/llmdoc:*` workflow that previously surprised | `memory/reflections/*.md` for the matching workflow |
| Recording a contract bug discovered mid-task | `memory/doc-gaps.md` to extend the list; if it warrants a structural decision, also add a new `memory/decisions/00N-*.md` |
| Picking a name for a new tag or block | `must/project-basics.md` § "Naming taboo" and grep `register_tag` / `register_block` |

## Build, test, CI, release

| Situation | Read next |
|---|---|
| User reports CI failed at `\RequirePackage{X}` (`File 'X.sty' not found`) | `reference/build-and-ci-files.md` § `.github/tl_packages` — re-derivation recipe in the file header comment |
| User reports `make check J=4` fails after a `scholatex.cls` / `scholatex*.lua` / `regression-test.cfg` source change | `architecture/test-pipeline.md` § baseline regen cycle (`l3build save -e luatex <name>`) |
| User reports `make doc` failed or `scholatex.pdf` won't compile | `reference/build-and-ci-files.md` § `workflows/doc.yml` for the workflow contract, and § `tl_packages` "Regeneration recipe" if a new `\usepackage` was added to `scholatex.tex` |
| User adds a `\usepackage{X}` to `scholatex.tex` (the user manual) | `must/working-agreement.md` § "TL packages sync" — same recipe applies to manual deps as to cls deps; both feed the same `tl_packages` hash |
| User wants to cut a release `v<X.Y>` | `architecture/release-pipeline.md` § operator workflow — `make tag`, push, await prerelease, dispatch CTAN upload |
| User wants to upload the cut release to CTAN | `architecture/release-pipeline.md` § CTAN upload + the `ctan-release` GitHub-environment provisioning note |
| User adds a new error or warning and wants it pinned in a regression baseline | `architecture/test-pipeline.md` § `_keep_patterns` whitelist and the dual-channel warning rule (must prefix with `scholatex:` / `scholatex.cls:` / `Class scholatex Warning`) |
| User asks why CI install takes so long, or how to shorten it | `reference/build-and-ci-files.md` § `.github/tl_packages` design rationale + the ISO-week TL-bypass cache key |
