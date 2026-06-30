# Project Basics

## What scholatex is

scholatex is a LuaLaTeX class (`scholatex.cls`) that provides a tag-based language for print-ready teaching worksheets — `<box>{...}`, `<table>{...}`, `<draw>{...}`, `<list:check>{...}`, inline `$...$` math with a closed mini-language, `let`-based aliases and macros, and `for` / `if` / `while` control flow lifted into Lua. Licensed under GPL v3 (`LICENSE:1-2`, `scholatex.cls:3-10`). Current version `v2.3` released `2026-06-28` (`scholatex.cls:2`, `CHANGELOG.md:10`).

## Hard engine requirement: LuaLaTeX only

LuaLaTeX is non-negotiable. `pdflatex` and `xelatex` cannot compile a scholatex document.

- The class loads `fontspec` and `unicode-math` at `scholatex.cls:74-75`, which require Lua/Xe-flavoured engines.
- The body is read and transpiled via `\directlua{...}` (`scholatex.cls:86, 87, 89, 91, 96, 107, 136-145`), which is only available under LuaTeX.
- `README.md:111` is the canonical user-facing statement: *"A LuaLaTeX engine is required (`lualatex`); the package does not compile with `pdflatex` or `xelatex`."*

Every example file ships the marker `% !TeX program = lualatex` at line 1.

## Repo layout (top-level)

- `scholatex.cls` — the LaTeX class file (boot, options, Lua bootstrap, body extraction).
- `scholatex.lua` — the Lua transpiler core. Defines `sl.transpile`, `sl.inject`, `sl.register_tag`, `sl.register_block`, the sandbox, and the build/process/emit pipeline.
- `scholatex-util.lua`, `scholatex-style.lua`, `scholatex-math.lua` — hard dependencies of the core, required at the top of `scholatex.lua` (`scholatex.lua:2-4`).
- `scholatex-{box,table,img,section,grid,list,matrix,vartab,plot,figure,toc}.lua` — eleven feature modules, eager-loaded by `sl.use` at `scholatex.lua:779-789`. Each registers one or more tags or blocks.
- `README.md` — the marketing + user-facing reference page (767 lines).
- `scholatex.tex` — the standalone PDF manual. Written in plain `article` so it survives without scholatex installed (`scholatex.tex:1-10`). It is **not** a scholatex document.
- `CHANGELOG.md` — Keep-a-Changelog format; 2.0 and 2.1 are marked BREAKING.
- `examples/*.tex` — 12 example files. The smallest is `math-algebra.tex` (93 lines); there is no minimal hello-world example file.
- `text-style.tex` and `math-language.tex` at the repo root — byte-identical duplicates of the same-name files under `examples/` (see `memory/doc-gaps.md`).
- `LICENSE` — GPL v3 full text.
- `.gitignore` — ignores LaTeX intermediates plus `CLAUDE.md`, `AGENTS.md`.
- `build.lua` — l3build configuration for the regression harness, CTAN packaging, and version derivation from `\ProvidesClass`. See `reference/build-and-ci-files.md`.
- `Makefile` — verb wrappers (`check`, `doc`, `ctan`, `install`, `clean`), the `hooks` installer for `.githooks/`, and the `tag v<X.Y>[-rcN]` annotated-tag creator. See `architecture/test-pipeline.md` and `architecture/release-pipeline.md`.
- `testfiles/` — the 20 `.lvt` regression / smoke tests, their `.tlg` baselines, and `testfiles/support/regression-test.cfg` (auto-staged by l3build as `testsuppdir`). See `architecture/test-pipeline.md`.
- `scripts/check-parallel.sh` — bucketed parallel `l3build check` driver (`make check J=N`).
- `scripts/extract-changelog.sh` — release-note extraction by version section from `CHANGELOG.md`.
- `.github/workflows/{ci,release,release-ctan-upload}.yml` — PR-gate CI, tag-push prerelease, manual CTAN upload. See `architecture/release-pipeline.md`.
- `.github/tl_packages` — single source of truth for the minimal TeX Live package set installed in CI. Regen recipe lives in the file header. See `reference/build-and-ci-files.md`.
- `.githooks/commit-msg` — Conventional Commits enforcement; install via `make hooks`.

Note: `scholatex.pdf` is **no longer tracked**; regenerate locally via `make doc` (`l3build doc`).

## Compile model in one paragraph

`scholatex.cls` loads `extarticle` with the user's `size` and `a4paper` (`scholatex.cls:27-28`), then sets fonts, geometry, paragraphing, and several preamble macros. In `\AtBeginDocument` it runs `\directlua{ scholatex = require("scholatex") }` (`scholatex.cls:86`), which eagerly registers all eleven feature modules. A second `\AtBeginDocument` block then reads the on-disk file `tex.jobname .. ".tex"` (`scholatex.cls:135-145`), regex-matches `\begin{document}(.-)\end{document}` against the whole file, and hands the captured body to `scholatex.inject`. `sl.inject` calls `sl.transpile` (`scholatex.lua:689-747`) which builds a Lua chunk via `build_lua`, executes it under either the sandbox or trusted globals, and concatenates the result into a single LaTeX string. The hook then emits a literal `\end{document}` (`scholatex.cls:146`) so LaTeX never scans the body itself. See `architecture/compile-pipeline.md` for the full detail.

The body-source resolver has two paths (`scholatex.cls:138-141`). Production: `tex.jobname .. ".tex"` (unchanged for end users). Test: when `regression-test.tex` is `\input`'ed (probed via `token.is_defined("START")`), fall back to `status.filename` with a leading `./` stripped — this is how the l3build harness can drive the class with an `.lvt` filename that does not match `tex.jobname`. See `architecture/test-pipeline.md`.

## Tooling

- `make check J=4` — run the l3build regression suite across four parallel buckets. Single bucket on `J=1`. See `architecture/test-pipeline.md`.
- `make doc` — `l3build doc`, regenerates `scholatex.pdf` from `scholatex.tex`.
- `make ctan` — `l3build ctan`, builds `build/distrib/ctan/scholatex-ctan.zip` for upload.
- `make tag v<X.Y>[-rcN]` — validate and create the annotated git tag locally; the push is intentionally manual so the operator can sanity-check before triggering `release.yml`.
- `make install` — `l3build install --full --dry-run`. Defaults to dry-run so it never writes into `~/texmf` without an explicit flag flip.
- `make hooks` — point `core.hooksPath` at `.githooks/` for the Conventional Commits enforcer.

## Naming taboo

`sl.register_tag(name, fn)` and `sl.register_block(name, fn)` both `error()` if `name` is already registered (`scholatex.lua:15-20, 22-27`). Modules cannot silently overwrite each other's tags. When picking a name for a new tag or block, grep the existing modules first; the existing names are `box`, `table`, `img`, `section`/`subsection`/`subsubsection`/`tableofcontents`, `grid`/`area`, `list`, `matrix`/`det`/`bmatrix`/`vmatrix`/`system`, `vartab`, `plot`, `draw`/`figure`, `row`. The math vocabulary (`scholatex-math.lua`) registers **zero** tags — it is invoked from `forward_text` on `$...$` content, not via the tag dispatch.

## Closed-language stance

scholatex is a **closed language**. The CHANGELOG 2.0 BREAKING entry (`CHANGELOG.md:194-201`) defines it:

- Backslash is inert in the body. `\` in user prose is emitted as `\textbackslash{}` (`scholatex.lua:233-234`). The user cannot write `\command` to invoke a LaTeX macro from prose; raw LaTeX text typed in the body is typeset literally as characters.
- Special-character escapes are by character doubling: `<<` `>>` `{{` `}}` `##` → literal `<` `>` `{` `}` `#`. The old `\<` `\>` `\{` `\}` `\#` no longer apply.
- `<nextline>` replaces the old `\\` line-break.
- Inside `$...$`, the `mathlite` mini-language interprets the content; `\command` survives as-is inside math (`scholatex-math.lua:334-343`).
- Colours are CamelCase only (`Red`, not `red`) since 2.1. Lowercase colour names error with a helpful CamelCase suggestion at `scholatex-style.lua:198-201`.

The `untrusted=true` class option (`scholatex.cls:25, 88-92`) runs the document's interpolated Lua under a sandbox: only `math`, `string`, `table`, and a curated set of primitives are available (`scholatex.lua:612-617`), strings are capped at 100 000 characters (`SANDBOX_STR_CAP`), and the chunk gets an instruction budget of about 2·10⁷ Lua VM steps (`SANDBOX_MAX_STEPS = 2e7`, hook every 10⁵ instructions, hard ceiling 200 hook events). See `architecture/compile-pipeline.md` § "Sandbox" for the full enforcement model.
