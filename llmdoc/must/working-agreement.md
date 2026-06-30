# Working Agreement

## Align before non-trivial changes

Before editing `scholatex.cls`, `scholatex.lua`, or any `scholatex-*.lua` module:

1. State the intent to the user in one or two sentences.
2. Read the relevant `architecture/*.md` document and the matching `reference/*.md` (or, when no stable doc exists yet, the closest evidence: the source itself, the relevant `memory/reflections/` entry, or any scratch investigation report the recorder has not yet synthesised).
3. Confirm the plan touches only the boundary the architecture doc describes. Cross-module patches are higher risk and need explicit user agreement.

For trivial changes (typos, comment fixes, single-line corrections in `examples/`) just do them.

## Citation style in documentation

- Default form: `path/to/file.lua` (`SymbolName`): one-clause description of why it matters.
- Add `:LINE` or `:LINE-LINE` only when the cited behaviour is non-obvious without the line number, e.g. when one branch of a multi-branch dispatcher needs to be pinned. Examples that need lines: the doubling rules in `forward_text` (`scholatex.lua:236-264`); the brace-balance pass (`scholatex.lua:575-595`); the `/`-arm derivative rejoin (`scholatex-math.lua:802-829`).
- Do not paste large source blocks. If a contract is load-bearing, cite the file and a short literal (one to three lines) and let the reader follow the path.
- For docs that mention multiple tags or vocabulary entries, prefer a compact two-column table (name → file:line) over prose.

## Extending the language

- New tag → call `sl.register_tag(name, handler)` from inside a new or existing `scholatex-*.lua` module, then add the module to the eager-load list in `scholatex.lua:779-789`.
- New block → call `sl.register_block(name, handler)` the same way. Block handlers receive `(api, words_str, inner_lines)` and emit Lua via `api.lit`, `api.raw`, `api.forward_text`, `api.process_block`, `api.is_control_open`, `api.lua_control` (`scholatex.lua:95-111`).
- New math keyword → add an entry to the matching table in `scholatex-math.lua` (`BBSET`, `SYM`, `WRAP1`, `TWOARG`, `INTOP`, `BIGOP`, `UNDEROP`, `ACCENT`, `FENCE`, `NAMED`, `SYMOP`) or, for a bespoke shape, a new `if word == "..."` arm inside `read_atom`. See `architecture/math-pipeline.md` for dispatch order.
- **Do not** patch the transpiler core (`build_lua`, `process_lines`, `emit_tag`, `forward_text`) for one-off behaviour. If a one-off change requires touching these, it almost certainly affects every tag — surface the trade-off to the user.

Naming discipline: `register_tag` and `register_block` refuse to overwrite an existing name (`scholatex.lua:18, 25`). Grep the registry before naming.

## Honour user contracts

When the user's request contradicts a documented rule, state the conflict explicitly and ask before changing the contract. Concrete examples:

- The user asks to teach a `<text>{...}` tag. Conflict: no module registers `text` and no built-in style word matches it (`scholatex-style.lua` matchers reject it). Surfacing the conflict means stating: "scholatex has no `<text>` tag; the equivalent is either plain prose or one of `<b>`, `<i>`, `<emph>`."
- The user asks for `<box sep:3>{...}`. The code reads `opts.sep` (`scholatex-box.lua:41`). README:515 documents `boxsep:N` instead. The README is drifting (see `memory/doc-gaps.md`). Surface this when asked.
- The user asks for a colour like `red`. The code errors with a CamelCase suggestion (`scholatex-style.lua:198-201`). Recommend `Red`.
- The user asks how to start a line with a literal `%`. Code accepts a `\%` prefix (`scholatex.lua:508-515`); only `scholatex.tex:375-376` documents the comment half. Surface the documented escape and the gap.

## Documents are scholatex-compilable

Every documentation example that claims to be scholatex source must:

- Match a tag that `sl.register_tag` has actually created, or a block that `sl.register_block` has created, or a style word from `scholatex-style.lua`'s matchers, or an alias the example itself defines via `let`.
- Use only `<<` `>>` `{{` `}}` `##` for special-character escapes; never `\<` `\>` `\{` `\}` `\#`.
- Place the `{` of a block opener as the last non-whitespace character on the line (`scholatex.lua:402`).
- Compile under `lualatex` against the actual class.

Verify against the example corpus under `examples/` before claiming a new pattern works.

## Bugs found during init become decisions

Real user-visible bugs surfaced during init or any update workflow are recorded in `memory/decisions/` and `memory/doc-gaps.md`. They are never silently reconciled by editing docs to match code or vice versa. The user decides which side moves. The current example: the `<box>` `sep:` vs `boxsep:` mismatch (see `memory/doc-gaps.md`).

## Push gate on CI-surface commits

Never push a commit that touches the CI surface without first verifying `make check J=4` passes locally. The CI surface is:

- any `.github/workflows/*.yml`
- `build.lua` (especially the `rewrite_log` filter and `_keep_patterns`)
- `testfiles/support/regression-test.cfg`
- any `testfiles/*.tlg` baseline
- `scholatex.cls`
- the warning channels in `scholatex.lua` and `scholatex-*.lua` (any `io.stderr` / `texio.write_nl` site)

If pushing red-knowingly to let CI iterate on something only the runner reproduces, state that explicitly to the user **before** the push. The silent failure mode otherwise is "wastes ~8 minutes of CI time per cycle." See `memory/reflections/l3build-ci-bootstrap.md` lesson 11.

## Baseline regeneration

Any change to `scholatex.cls`, `scholatex.lua`, `scholatex-*.lua`, or `testfiles/support/regression-test.cfg` MAY drift the 20 `.tlg` baselines under `testfiles/`. Procedure:

1. Run `make check` (serial; the parallel driver hides per-test diff context behind bucket prefixes).
2. On failure, inspect `build/test/<name>.luatex.diff` for the rewritten-log delta.
3. If the drift is intentional, run `l3build save -e luatex <name>` to refresh `testfiles/<name>.tlg`.
4. Commit the `.tlg` change in the **same** commit as the source change so reviewers see them together.

There is no `make save` wrapper; invoke `l3build save` directly. See `architecture/test-pipeline.md` for the full cycle.

## TL packages sync

Adding a `\RequirePackage{X}` to `scholatex.cls` — or a `\usepackage{X}` to `scholatex.tex` (the user manual) — REQUIRES re-deriving `.github/tl_packages` via the `lualatex --recorder` recipe documented in the file's header comment. The recipe iterates over BOTH `scholatex.tex` AND `examples/*.tex` because each is an independent compile entrypoint with its own dep surface. Do not push the cls or manual change without the corresponding `tl_packages` change — CI will fail mid-install with a `File 'X.sty' not found` error.

Before adding any candidate from the raw recipe output, cross-check against `collection-latex`'s transitive deps (intersection recipe at `reference/build-and-ci-files.md` § `tl_packages` "How to choose what to list"). Most hyperref / tools / array / longtable deps are already pulled in by `scheme-basic` and need not be enumerated — listing them only churns the cache hash without adding coverage.

The hash of `.github/tl_packages` is part of the cache key for **both** `.github/workflows/ci.yml` AND `.github/workflows/doc.yml` (and `release.yml`), so a stale file silently reuses a cache that lacks the package on every gated workflow at once.

## `%` in `\directlua`

When adding Lua to `scholatex.cls`'s `\AtBeginDocument` hook (or any `\directlua{...}` block), no `%` is allowed in the Lua source. TeX tokenizes `%` as a comment-to-end-of-line **before** the Lua chunk is parsed, silently truncating the chunk. Prefer `s:sub(1,2) == "./"` over `gsub("^%./", "")`; move complex patterns into a `scholatex-*.lua` module. See `memory/reflections/l3build-ci-bootstrap.md` lesson 1.

## `scholatex:` prefix contract for errors and warnings

Every new error or warning that should appear in a regression baseline MUST start with one of:

- `scholatex:` — every `error("scholatex: ...")` site in Lua modules.
- `scholatex.cls:` — class-level boot errors raised from `\directlua`.
- `Class scholatex Warning` — `\ClassWarning{scholatex}{...}` emissions.

The `_keep_patterns` whitelist in `build.lua:125-137` post-filters the rewritten log line-by-line; lines not matching any of the ten patterns are dropped before the `.tlg` diff. Tweaking the whitelist to accept a new prefix is allowed but should be a deliberate commit, not a "make my error visible" hack.

## Dual-channel warnings

When adding a new `io.stderr:write(msg, "\n")` warning in `scholatex.lua` or any `scholatex-*.lua` module, also call `if texio and texio.write_nl then texio.write_nl(msg) end` immediately after. The stderr write is for interactive feedback; the `texio.write_nl` lands the same text in the lualatex `.log` so a regression test can pin it. The canonical pattern is at `scholatex.lua:50-58, 200-203, 261-266`. The `if texio` guard makes the module still runnable outside LuaTeX. See `memory/reflections/l3build-ci-bootstrap.md` lesson 3.
