# Architecture: Style and Tag Dispatch

## Purpose

This is the middle layer between the transpiler (`scholatex.lua`) and the user-facing tag vocabulary. It defines how three coexisting namespaces — the built-in tag/block registries owned by modules, the user-side `let` aliases / macros / block aliases reset on every transpile, and the closed style-word vocabulary in `scholatex-style.lua` — are dispatched without ambiguity.

The transpile timeline that owns these tables is described in `architecture/compile-pipeline.md` (§§ 2-7); this document only concerns the dispatch contract between them.

## Tables and ownership

| Table | File:line | Owner | Lifetime |
|---|---|---|---|
| `sl._tags` | `scholatex.lua:14, 17-21` | Modules via `sl.register_tag(name, fn)` | Module load (eager via `sl.use` chain at `scholatex.lua:779-789`); refuse-on-collision |
| `sl._blocks` | `scholatex.lua:15, 22-28` | Modules via `sl.register_block(name, fn)` | Same; refuse-on-collision |
| `ALIAS` | `scholatex.lua:13` | User `let NAME = <WORDS>` lines (forms D, E in `architecture/compile-pipeline.md` § 4) | Reset to `{}` at top of every `sl.transpile` (`scholatex.lua:690`) |
| `MACRO` | `scholatex.lua:13` | User `let NAME{params} = RHS` lines (form C) | Same |
| `BLOCKALIAS` | `scholatex.lua:13` | User `let NAME = <... BLOCK ...>` and `let NAME{params} = <... BLOCK ...>` (forms B, D) | Same |
| `STYLE.resolve` matcher chain | `scholatex-style.lua:40-134` | Closed; defined at module load | Process lifetime |
| `sl._objects` | Created lazily in `scholatex.lua:483, 498` | User `let X = <fn ...>` (form A) via `sl.fn_parse` | Per-transpile (created fresh; no explicit reset) |

`sl.register_tag` and `sl.register_block` refuse to overwrite an existing entry: `scholatex.lua:17-21` raises `scholatex: tag 'X' is already registered (name clash)` and `:22-28` raises the same for blocks. Modules cannot accidentally shadow each other.

## Dispatch order

### Tags (`<head WORDS>{CONTENT}` inline form)

`emit_tag(code, words_str, content)` at `scholatex.lua:113-172`. Strict three-way priority — every miss is an error, no silent fall-through:

1. `sl._tags[head]` (`scholatex.lua:118-122`). If set, the built-in handler runs and returns. User `MACRO[head]` of the same name is unreachable.
2. `MACRO[head]` (`scholatex.lua:124-152`). Comma-split `content` honouring brace depth and backslash escape pairs; substitute every `#param` with `body:gsub("#" .. pname .. "%f[%W]", repl)` (the `%f[%W]` frontier prevents `#x` from matching `#xy`); recurse `forward_text(code, body)`.
3. `STYLE.classify_split(words, ALIAS)` (`scholatex.lua:154`, dispatched through `scholatex-style.lua:213-221`). Returns `(outer, inner)` for the 13 style matchers (see § "Style word kinds"). A word that resolves to nothing raises `scholatex: unknown tag attribute: 'X'` (`scholatex-style.lua:201`) or the CamelCase hint `'red' is not a colour; colours are written in CamelCase now -- use 'Red'` (`scholatex-style.lua:198-200`).

### Blocks (`<name OPTS>{` ... `}` multi-line form)

Two-way priority, in `process_lines` at `scholatex.lua:402-426`. The block-opener regex `^%s*<(%a[%w_]*)%s*(.-)>%s*{%s*$` (`scholatex.lua:402`) is the single most common gotcha — it requires `{` to be the last non-whitespace character on the line. A line ending in `{{` is rejected explicitly by `ends_struct_open` (`scholatex.lua:57-62`).

1. `BLOCKALIAS[name]` (`scholatex.lua:404-415`). If set, `#param` substitution runs over the recorded `opts` and `name := def.block`. The underlying built-in block then executes; the alias only rewrites the lookup name and prepends options.
2. `sl._blocks[name]` (`scholatex.lua:417-426`). The block handler runs with `mkapi(code), words, inner_str`. After the block, append `emit(" \\par ")`.

A name that is in neither table falls through to the prose path and reaches `forward_text`, which usually raises `unknown tag attribute` via the STYLE fallback above.

### Style words (the STYLE fallback)

`STYLE.classify_split(words, alias)` at `scholatex-style.lua:213-221` drives `classify_into` at `scholatex-style.lua:155-205`. For each whitespace-separated word it tries, in order:

1. `S.resolve(w)` (`scholatex-style.lua:136-142`). Walks the 13-entry `MATCHERS` list (see below); first hit wins.
2. `alias[w]` (`scholatex-style.lua:191-192`). If the word fails resolve and the user `let`-declared an alias by that name, recurse into the alias body. Because `STYLE.resolve_styles` flattens nested aliases at registration time (`scholatex-style.lua:232-240, 236`), the body is already a flat list of resolvable keywords — recursion is effectively one level deep.
3. CamelCase hint (`scholatex-style.lua:196-200`). If `cap = w:gsub("^%l", string.upper)` is in `S.CSS`, raise the CamelCase colour error. Only catches single-word colours (`red → Red`); multi-word lowercase variants (`darkgray`) fall through to the generic message.
4. Generic error: `scholatex: unknown tag attribute: 'X'` (`scholatex-style.lua:201`).

The ALIAS interleaving in step 2 is what makes `let h1 = <Navy b section>` reachable as `<h1>{...}`: `h1` fails resolve, hits `alias["h1"]`, recurses with the flat list, and each of `Navy / b / section` resolves cleanly.

## `warn_if_shadows` — the silent failure mode

`warn_if_shadows(name, lineno)` at `scholatex.lua:43-55` checks whether the user `let`-name collides with a built-in. It calls `pcall(STYLE.resolve, name)` plus `sl._blocks[name]` plus `sl._tags[name]`. On any collision it writes to **stderr only**:

```
scholatex: warning: 'let X' (line N) shadows a built-in name and will be ignored;
the built-in 'X' always takes precedence. Use a different alias name.
```

Critical: `warn_if_shadows` **does not prevent the assignment**. Every routing branch (`scholatex.lua:533, 537, 552, 554, 557, 561`) writes to `ALIAS` / `MACRO` / `BLOCKALIAS` unconditionally after the warning returns. The "ignored" promise holds because the dispatch order in § "Dispatch order" always queries built-ins first:

- `emit_tag:118` checks `sl._tags` before `MACRO`.
- `process_lines:417` checks `sl._blocks[bname]` after the BLOCKALIAS rewrite — but the rewrite sets `bname = def.block`, which points back at the built-in.

So the user table contains a dead entry that is never read. The warning goes nowhere except stderr (not the LaTeX log), so a build wrapper that only forwards LaTeX output may swallow it entirely.

## Style word kinds — the 13 matchers

`MATCHERS` in `scholatex-style.lua:40-134` is an ordered list. First non-nil descriptor wins (`scholatex-style.lua:137-140`). Order matters because `ROMAN`/`ALPHA` would otherwise be swallowed by the all-caps font matcher.

| # | Lines | Matches | Kind |
|---|---|---|---|
| 1 | 45-49 | `num roman ROMAN alpha ALPHA` | `counter` |
| 2 | 52-56 | All-uppercase word starting uppercase (no lowercase) | `font` |
| 3 | 59-63 | Exact key in `S.CSS` (151 CamelCase colour names) | `color` |
| 4 | 66-70 | Exact key in `S.STYLE` (`b i u emph sf sc`) | `style` |
| 5 | 73-75 | `l c r j` | `align` |
| 6 | 78-80 | `section subsection subsubsection` | `section` |
| 7 | 83-86 | Regex `^(%d+%.?%d*)p[tx]$` (`12pt`, `14.5px`) | `size` |
| 8 | 89-91 | Literal `nextpage` | `page` |
| 9 | 94-96 | Literal `nextline` | `break` |
| 10 | 102-115 | `line` / `1line` / `Nlines` (N≥2) — strict singular/plural | `lines` |
| 11 | 118-121 | `tab` or `Ntab` via `count_prefix` | `tab` |
| 12 | 124-127 | Regex `^up(%d+%.?%d*)$` | `up` |
| 13 | 130-133 | Regex `^down(%d+%.?%d*)$` | `down` |

The full vocabulary catalogue with LaTeX outputs is in `reference/text-style-vocabulary.md` — this document only enumerates the dispatch order.

## Cross-module patterns

Three places where modules sidestep the standard STYLE fallback to reuse style-word semantics for their own purposes:

### `<section>` family routes counter words before classify

`scholatex-section.lua:64-97` walks the bare-word options of `<section title:{...}>{ body }` and explicitly intercepts `kind == "counter"` words from `sl.style.resolve(w)`. The captured counter cmd (e.g. `\Roman`) feeds `\renewcommand{\thesection}{<cmd>{section}}` (`scholatex-section.lua:93-97`). This means counter words are **only meaningful inside the section block-form** — `classify_into` has no `counter` branch (`scholatex-style.lua:155-205` enumerates the kinds it routes; counter is absent), so a free-standing `<num>` raises the generic unknown-attribute error.

The matcher being first in `MATCHERS` exists to keep the section module's own `sl.style.resolve` call distinguishing `ROMAN` from a font name.

### `<grid>` reuses the `<box>` option vocabulary

`scholatex-grid.lua:200-203` calls `sl.box_parse_opts` and `sl.box_build_options` (exposed at `scholatex-box.lua:90-92`) to compute styled-box options for each `<area>`. Two consequences:

- `<area NAME line:Navy fill:AliceBlue radius:2 title:{Lemma}>{...}` accepts the same option set as `<box ...>{...}`. No vocabulary split.
- The bare two-letter placement code (`tl`, `mc`, `br`) and the bare alignment words (`l c r j`) on `<area>` are translated by the grid module itself, using `sl.style.ALIGN` (`scholatex-grid.lua:215-217`), not by `classify_split`.

`<row>` also delegates to the same box parser (`scholatex-box.lua:127`) and silently accepts every box option, but reads only `gap:`.

### `<vartab>` and `<plot>` read `sl._objects`

`scholatex-vartab.lua:419-431` and `scholatex-plot.lua:115-123` look up function objects by bare name in `sl._objects`. The object is stored at `scholatex.lua:483-484` (multi-line `<fn>`) and `:498-499` (single-line). The schema lives in `reference/fn-object-schema.md`. Neither the style table nor the tag dispatcher is involved; `<vartab>` and `<plot>` are normal registered tags that perform a private name lookup before falling back to attribute parsing.

This is the third bypass pattern: a module-registered tag (rather than a block) reads transpiler-owned state by name.

## Related

- `architecture/compile-pipeline.md` — the transpile timeline that resets these tables and owns the routing inside `process_lines`, `emit_tag`, `forward_text`.
- `architecture/function-studies.md` — the `<fn>` / `<vartab>` / `<plot>` triangle that uses `sl._objects` as its shared store.
- `reference/text-style-vocabulary.md` — the user-facing catalogue of every style word recognised by the 13 matchers.
- `reference/tags-and-blocks.md` — the user-facing index of every registered tag and block.
- `memory/doc-gaps.md` — `warn_if_shadows` writing dead entries, undocumented `BLOCKALIAS` dual-write, and other quirks of this layer.
