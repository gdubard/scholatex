# Architecture: Compile Pipeline

## Purpose

The complete path from `lualatex myfile.tex` to typeset PDF, end-to-end. This document is the single source of truth for the compile model: how the class boots, how the body is reached, how it is transpiled to Lua, how the chunk is executed (trusted or sandboxed), and how the resulting LaTeX is handed back to TeX.

Owned by `scholatex.cls`, `scholatex.lua`, `scholatex-util.lua`, `scholatex-style.lua`. The math mini-language is a separate ownership boundary — see `architecture/math-pipeline.md`. The `<draw>` block is also separate — see `architecture/figure-draw.md`.

## End-to-end overview

```
lualatex myfile.tex
    │
    ▼
scholatex.cls               (LaTeX class)
    ├── kvoptions parse                          scholatex.cls:14-25
    ├── \LoadClass[size pt, a4paper]{extarticle} scholatex.cls:28
    ├── \RequirePackage{...}                     scholatex.cls:29-76
    ├── fonts (text + math, 3-step fallback)     scholatex.cls:93-114
    ├── geometry, paragraphing, preamble macros  scholatex.cls:115-134
    ├── \directlua{ scholatex = require("scholatex") }
    │       │                                    scholatex.cls:86
    │       ▼
    │   scholatex.lua loaded
    │   ├── require util, style, math            scholatex.lua:2-4
    │   └── sl.use(...) × 11                     scholatex.lua:779-789
    │       (eager-registers every built-in tag and block)
    │
    ├── \directlua write scholatex.config        scholatex.cls:87-92
    │       (padding, lang, untrusted)
    │
    └── \AtBeginDocument hook                    scholatex.cls:135-147
            ├── io.open(tex.jobname .. ".tex")
            ├── whole:match("\\begin{document}(.-)\\end{document}")
            ├── scholatex.inject(body)
            │       └── sl.transpile(body)       scholatex.lua:689-747
            │           ├── reset ALIAS/MACRO/BLOCKALIAS
            │           ├── set decimal separators from lang
            │           ├── build_lua(src)       scholatex.lua:449-600
            │           │   ├── pre-pass: lift `let`, comments, body_lines
            │           │   ├── brace-balance validation
            │           │   └── process_lines    scholatex.lua:380-447
            │           │       └── emit_tag → forward_text (recursive)
            │           ├── load(lua_code, ..., env?)
            │           ├── pcall(chunk) or pcall(run_limited, chunk)
            │           └── return collapse_par(result)
            │       └── print_par_lines(out)      scholatex.lua:749-757
            │           └── tex.print(lines)      (TeX resumes)
            └── \end{document}                    scholatex.cls:146
                (literal — stops LaTeX's own scan of the body)
```

The pipeline is three sequential layers inside `sl.transpile`:

1. **Pre-pass** (`build_lua` lines 465-573 of `scholatex.lua`): line-by-line scanner that peels off `let`-directives into `ALIAS`/`MACRO`/`BLOCKALIAS`, strips comments, accumulates multi-line `<fn ...>` objects. Everything surviving becomes a `body_lines` record.
2. **Generation pass** (`process_lines` 380-447, `emit_tag` 113-172, `forward_text` 174-312): emits the **Lua chunk** that, when executed, builds the LaTeX string.
3. **Execution pass** (`transpile` 703-746): `load`s the chunk under either the sandbox env or `_G`, then `pcall`s it. On success, the chunk returns a single concatenated LaTeX string.

## 1. `scholatex.cls` boot sequence

### 1.1 Option parsing and `extarticle` loading

`scholatex.cls:12-13` calls `\RequirePackage{kvoptions}` with `family=scholatex, prefix=scholatex@`. The 11 string options and 1 boolean are declared at `scholatex.cls:14-25`:

| Option | Default | Consumed at |
|---|---|---|
| `margins` | `20` | `scholatex.cls:77-85` (comma-counted; 0 → `margin=Nmm`, ≥1 → four-tuple `top,right,bottom,left`) |
| `font` | `Latin Modern Roman` | `scholatex.cls:93-103` |
| `size` | `11` | `scholatex.cls:28` (passed straight to `extarticle`) |
| `mathfont` | `Latin Modern Math` | `scholatex.cls:104-114` |
| `imgdir` | `img` | `scholatex.cls:34-48` (expands to `\graphicspath{{./}{IMG/}...}`) |
| `tabwidth` | `8` | `scholatex.cls:64-65` (`\newlength{\scholatextab}`) |
| `lineheight` | `8` | `scholatex.cls:66-67` (`\newlength{\scholatexline}`) |
| `linespread` | `1.0` | `scholatex.cls:132` |
| `scriptscale` | `100` | `scholatex.cls:72-73` (divided by 100 into `\scholatex@scriptfactor`) |
| `padding` | `2` | `scholatex.cls:87` writes `scholatex.config.padding` |
| `lang` | `fr` | `scholatex.cls:87` writes `scholatex.config.lang`; consumed in `scholatex.lua:450-452, 692-693` |
| `untrusted` | `false` | `scholatex.cls:88-92` writes `scholatex.config.untrusted`; switches `transpile` between trusted and sandboxed execution |

`\DeclareDefaultOption{\PassOptionsToClass{\CurrentOption}{extarticle}}` at `scholatex.cls:26` forwards unknown options to `extarticle`, so `\documentclass[twocolumn, draft]{scholatex}` works.

### 1.2 Fonts and `respace` fallback

Both text font (`scholatex.cls:93-103`) and math font (`scholatex.cls:104-114`) use the same three-step chain:

1. `\IfFontExistsTF{\scholatex@font}` → use it directly.
2. Otherwise call `scholatex.respace("scholatex@font")` to insert spaces at case boundaries (`scholatex.lua:770-775`: `gsub("(%l)(%u)", "%1 %2")` then `gsub("(%u)(%u%l)", "%1 %2")`), then test again. This turns `LatinModernRoman` into `Latin Modern Roman` and `DEJAVUSans` into `DEJAVU Sans` automatically.
3. Otherwise emit `\ClassWarningNoLine` and fall back to `Latin Modern Roman` / `Latin Modern Math`.

### 1.3 `\graphicspath` flattening

`scholatex.cls:34-48` accepts a comma-separated `imgdir` (with whitespace inside the list deleted by `\StrDel`) and emits a single `\graphicspath{{./}{DIR1/}{DIR2/}...}` so the user can scatter assets across multiple folders. `./` is always first, so files in the source directory take priority.

### 1.4 Geometry and paragraphing

`scholatex.cls:115-134` finalises: `\parindent=0pt`, `\parskip=0.5em`, `\linespread{\scholatex@linespread}`, `\lineskiplimit=3pt`, `\lineskip=3pt`. The two latter give breathing room above tall fractions (CHANGELOG 1.2). The class also defines `\fint` (a manually-composed mean integral symbol for fonts without it, `scholatex.cls:115-121`) and `\scholatexparallelogram` (a TikZ-drawn ▱ for fonts where unicode-math binds `\parallelogram` to a missing math char, `scholatex.cls:122-128`).

### 1.5 Lua bootstrap

`scholatex.cls:86` runs `\directlua{scholatex = require("scholatex")}`. This loads `scholatex.lua`, which at the top requires `scholatex-util`, `scholatex-style`, `scholatex-math` (`scholatex.lua:2-4`), then at the bottom (`scholatex.lua:779-789`) eagerly `sl.use`s eleven feature modules — `box`, `table`, `img`, `section`, `grid`, `list`, `matrix`, `vartab`, `plot`, `figure`, `toc`. After this line returns, **every built-in tag and block is registered**; there is no lazy-load path.

`scholatex.cls:87-92` then writes `scholatex.config` (`padding`, `lang`, `untrusted`) via `\directlua`. These mutate the same `sl` table.

### 1.6 Body extraction (the `\AtBeginDocument` trick)

`scholatex.cls:135-161` contains the load-bearing hook. The hook accumulated through four commits and now performs four ordered sub-steps:

1. **Source-file resolution with test-mode fallback** (`scholatex.cls:137-141`). Default `src = tex.jobname .. ".tex"`. When `regression-test.tex` is loaded (probed via `token.is_defined("START")`) AND `status.filename` is set, prefer `status.filename` and strip a leading `./` using `src:sub(1,2) == "./"`. LuaTeX exposes the actual main source filename via the `status` table; without this branch the l3build harness — which drives the class with `-jobname=<basename>` against a `.lvt` whose `.tex` does not exist — would fail at `io.open`. See `architecture/test-pipeline.md` for how the harness invokes the class.
2. **`io.open` nil-safety** (`scholatex.cls:142-147`). If both resolution paths return nil, raise the explicit class-level error `scholatex.cls: cannot read '<src>'. If you used --jobname, ensure it matches the main source filename.` and `return`. Without this guard, a missing file crashes on the next `f:read("*a")` call with an opaque Lua "attempt to index a nil value" error.
3. **Body extraction with `e_pos` capture and truncation warning** (`scholatex.cls:149-156`). The regex `whole:match("\\begin{document}(.-)()\\end{document}")` uses the empty `()` capture between `(.-)` and `\end{document}` to record the offset *right after the body ends* (Lua's trick to get a position rather than a string). The hook then searches `whole` from `e_pos + 14` (skipping past the 14-char literal `\end{document}`); if another occurrence is found, the hook emits `\ClassWarning{scholatex}{source contains more than one \end{document}; body truncated at first occurrence}`. The truncation itself cannot be recovered without a different regex; the warning is the partial fix for the B3 doc-gap. See `memory/doc-gaps.md` row B3.
4. **`scholatex.inject(body)` then literal `\end{document}`** (`scholatex.cls:157-160`). `inject` runs the transpiler; the literal `\end{document}` after the `\directlua{}` block stops LaTeX from scanning the original source body a second time.

Two design choices to understand:

- **The body is re-read from disk.** TeX is *not* the parser; `scholatex.inject` runs over the raw source text. This is how the user can type `<box>{...}` instead of `\scholatexbox{...}` — TeX never sees the tags.
- **A literal `\end{document}` is emitted inside the hook.** This stops LaTeX from scanning the original source body a second time. The whole body is consumed by Lua and replayed via `tex.print`; LaTeX's own scanner sees the inserted `\end{document}` right after, and the rest of the source is silently skipped.

**Pitfalls:**

- The regex `\begin{document}(.-)\end{document}` is **non-greedy**. If the body literally contains the seven characters `\end{document}` (e.g. a tutorial about LaTeX), the regex truncates there and the tail is silently dropped — the user now gets a `\ClassWarning` (step 3) but the trailing material is still lost. See § "Failure modes".
- The Lua reads `tex.jobname .. ".tex"`. If the user compiles with `lualatex --jobname=other main.tex`, `tex.jobname` is `other`; the class tries to read `other.tex` and either errors with the explicit "cannot read" message (step 2) or extracts the wrong body (file exists but is different).

> The regression-test integration and the test-mode `status.filename` fallback (step 1) are documented in full in `architecture/test-pipeline.md`. The hook is the single integration point between the closed-language class and the l3build harness.

## 2. `sl.transpile(src)` flow

The single entry called by `scholatex.inject`. Defined at `scholatex.lua:689-747`.

1. **Reset state** (`scholatex.lua:690-691`): `ALIAS, MACRO, BLOCKALIAS = {}, {}, {}`, `sl._line = nil`. Per-call state — no caching across documents.
2. **Decimal separators** (`scholatex.lua:692-693`): read `sl.config.lang`, set `MATH.decsep` to `.` (English) or `{,}` (default French). The text-side separator is then set inside `build_lua` (see §4).
3. **`build_lua(src)`** (`scholatex.lua:694`) under `pcall`. The catch block at `695-701` strips Lua error prefixes and re-raises as `scholatex: line N: msg` using `sl._line`.
4. **Execution mode**: read `sl.config.untrusted` (`scholatex.lua:703`).
5. **Load the chunk**:
   - Untrusted (`scholatex.lua:705-708`): `make_sandbox_env()` returns `env, safestr`. `load(lua_code, "=sl-body", "t", env)`. Mode `"t"` forbids bytecode.
   - Trusted (`scholatex.lua:709-719`): set `_G.vector` (if absent) and `_G.__drawbuild = sl.build_figure_block`. `load(lua_code, "=sl-body")` with default env `_G`.
6. **Run** (`scholatex.lua:724-729`): `pcall(chunk)` (trusted) or `pcall(run_limited, chunk, safestr)` (untrusted).
7. **Failure rewriting** (`scholatex.lua:730-744`): untrusted mode looks for `instruction limit`, `result too large`, or `nil value (global 'X')` in the error message and rewrites for clarity (e.g. `'X' is not available in untrusted mode ...`).
8. **Return** (`scholatex.lua:746`): `collapse_par(result)`.

## 3. `build_lua` preamble

`build_lua` produces a complete Lua source string. Every chunk starts with the same hardcoded preamble (`scholatex.lua:454-463`):

```lua
local _parts = {}
local function emit(s) _parts[#_parts+1] = s end
local sqrt=math.sqrt; local floor=math.floor; local ceil=math.ceil
local abs=math.abs; local pi=math.pi; local max=math.max; local min=math.min
local function round(x,d) local m=10^(d or 0); return floor(x*m+0.5)/m end
local _SEPT=","; local _SEPM="{,}"  -- or "." / "." in English
local function _fmt(v)  ... end     -- text decimal-formatter
local function _fmtm(v) ... end     -- math decimal-formatter
```

The eight injected locals are:

- `_parts`, `emit` — the output array and its appender. Every emit-time string goes through `emit` and the final value is `table.concat(_parts)`.
- `sqrt`, `floor`, `ceil`, `abs`, `pi`, `max`, `min`, `round` — convenience binds for use inside `let` expressions, `for k in a..b { ... }` ranges, and `#{expr}` interpolations.
- `_SEPT` / `_SEPM` — text and math decimal separators. Set from `sl.config.lang` at `scholatex.lua:450-452`. The math one is `{,}` not `,` because a bare comma in math mode triggers TeX's punctuation spacing.
- `_fmt`, `_fmtm` — number formatters: replace the decimal dot via `gsub('%.', _SEP, 1)`, return `""` for `nil`, otherwise `tostring(v)`.

Lifted control-flow statements (`for`/`if`/`while`/`local NAME = EXPR`) are appended **as bare Lua** without going through `emit`. So the generated chunk freely interleaves `emit("...")` calls with `for ... do` / `if ... then` / `local NAME = EXPR` lines. Only the strings that flowed through `emit` survive the final concat.

### Three-way emission per source line type

`process_lines` (see §5) decides what to append for each line in `body_lines`:

- **Prose line.** A scan via `forward_text` writes one or more `emit("LITERAL")\n` lines, plus `emit(_fmt(EXPR))\n` for each `#NAME` or `#{EXPR}` placeholder, plus a trailing `emit(" \\par ")\n`.
- **Tag line `<tag>{body}`.** Through `forward_text` → `emit_tag` → either an inner tag handler emits its own Lua, or `STYLE.classify_split` emits opener/closer wrappers around the body.
- **Block opener `<tag ...>{`.** `process_lines` reads the block body via `U.collect_block`, then calls `sl._blocks[bname](api, ...)` which appends Lua to the chunk. A trailing `emit(" \\par ")\n` follows.
- **Control-flow opener** (`for x in ... {`, `if cond {`, `} else {`, `while cond {`) → bare Lua `for x ... do` / `if ... then` / `else` / `while ... do`.
- **Bare `}` line** → bare Lua `end`.
- **`let NAME = EXPR`** (non-bracketed RHS) → bare Lua `local NAME = EXPR`.

## 4. `build_lua` line-by-line pre-pass

`build_lua` walks every source line with `for srcline in (src .. "\n"):gmatch("(.-)\n") do` at `scholatex.lua:469`. Branches in order:

1. **Multi-line `<fn ...>` accumulator** (`scholatex.lua:472-488`). A `pending_obj.buf` collects lines until one ends with `>%s*$`, at which point the buffer is fed to `sl.fn_parse` (defined in `scholatex-vartab.lua:405-407`) and stored in `sl._objects[name]`.
2. **`let NAME = <fn ...>`** (`scholatex.lua:491-506`). Calls `warn_if_shadows`. If the same line closes with `>`, parse immediately; otherwise open the accumulator.
3. **Comment lines** (`scholatex.lua:508-515`). A line matching `^%s*%%` is dropped (treated as a Lua-style line-comment); a line matching `^(%s*)\(%%.*)$` has the leading `\` stripped — this is the documented-only-in-scholatex.tex line-escape `\%` for a literal `%` at start of line.
4. **`let NAME{params} = RHS`** (`scholatex.lua:516-538`). Parametric:
   - If RHS is `<...>` whose words include a registered block name (`sl._blocks[w]`), → `BLOCKALIAS[NAME] = {block=W, opts=other, params=plist}`.
   - Otherwise → `MACRO[NAME] = {params=plist, body=RHS}`.
5. **`let NAME = <WORDS>`** (`scholatex.lua:540-562`). Non-parametric:
   - If a block name is in WORDS, dual-write: both `BLOCKALIAS[NAME]` (with `params={}`) and `ALIAS[NAME] = STYLE.resolve_styles(WORDS, ALIAS)`.
   - Otherwise just `ALIAS[NAME] = STYLE.resolve_styles(WORDS, ALIAS)`.
6. **`let NAME = EXPR`** (no brackets) (`scholatex.lua:563-569`). Becomes a `body_lines` entry `{var=NAME, expr=EXPR, lineno=N}` → emits `local NAME = EXPR\n` at generation time.
7. **Anything else** (`scholatex.lua:568`). Plain text or tag line → `body_lines[#body_lines+1] = {text = line, lineno = N}`.

After the pre-pass, `scholatex.lua:575-595` runs a **brace-balance validator** over `body_lines`. It uses `U.raw_brace_delta` to count `{` − `}` and raises `scholatex: line N: unbalanced '{'` or `unbalanced '}'`. The pass counts every brace including the ones inside `{{` and `}}` escape pairs — they pair-balance so the count is still correct.

### Six `let` forms summary

| Form | RHS shape | Routes to | File:line |
|---|---|---|---|
| A | `<fn ARGS>` (single line) or `<fn ARGS\n...\n>` (multi-line) | `sl._objects[NAME]` via `sl.fn_parse` | 492-506 |
| B | `<WORDS>` containing a block name, parametric `let NAME{p1,p2} = ...` | `BLOCKALIAS[NAME] = {block=W, opts, params}` | 516-535 |
| C | parametric `let NAME{p1,p2} = RHS` (RHS not a block) | `MACRO[NAME] = {params, body=RHS}` | 537 |
| D | `<WORDS>` containing a block name, non-parametric | dual-write: `BLOCKALIAS[NAME]` + `ALIAS[NAME]` | 552-557 |
| E | `<WORDS>` no block, non-parametric | `ALIAS[NAME] = STYLE.resolve_styles(...)` | 561 |
| F | `let NAME = EXPR` (no brackets) | `body_lines{var=NAME, expr=EXPR}` → `local NAME = EXPR` at runtime | 563-569 |

## 5. `process_lines`

`scholatex.lua:380-447`. Walks `body_lines` with an explicit `idx` cursor.

Per entry:

1. **`entry.lineno`** → update `sl._line` (so any error in `forward_text` carries the right line number).
2. **`entry.var`** → emit `local NAME = EXPR\n`. Raw, unchecked Lua.
3. **Opener-unclosed line joining** (`scholatex.lua:389-401`). If a line starts with `<...` and the matching `>` is not on the same line, join subsequent lines until `opener_unclosed(joined)` is false. Lets a tag head span multiple physical lines (e.g. multi-line `<fn ...>`).
4. **Block-opener regex** (`scholatex.lua:402`):
   ```
   ^%s*<(%a[%w_]*)%s*(.-)>%s*{%s*$
   ```
   This requires the `{` to be the **last non-whitespace character on the line**. If a line ends in `}`, `}}`, `{{`, or contains content after `{`, it does **not** match. The single most common gotcha for users — see § "Failure modes".
5. **`BLOCKALIAS` rewrite** (`scholatex.lua:404-415`). If `BLOCKALIAS[bname]` is set, substitute `#param` in the recorded `opts` using `U.split_commas` and reassign `bname := def.block`. So the lookup ultimately hits `sl._blocks[bname]` with the underlying block.
6. **Block dispatch** (`scholatex.lua:417-426`). If `sl._blocks[bname]` exists, advance `idx`, `U.collect_block` scans inner lines until a `}` at depth 0, then `sl._blocks[bname](mkapi(code), bwords, inner_str)` runs. Append `emit(" \\par ")\n`.
7. **Bare `}` line** (`scholatex.lua:427-429`) → `code[#code+1] = "end\n"`.
8. **Control-flow opener** (`scholatex.lua:430-432`, `is_control_open` at 64-71, `lua_control` at 73-91) → append the lifted Lua statement.
9. **Prose fall-through** (`scholatex.lua:433-444`). Gather continuation lines if the line has unbalanced tag-internal braces (`tag_brace_delta` at 314-356 ignores literal braces in prose, only counts braces inside `<...>{...}` and `#{...}`). Then `forward_text(code, chunk)` and append `emit(" \\par ")\n`.

The `api` passed to block handlers (`mkapi` at `scholatex.lua:95-111`) provides:

- `api.lit(t)` — wrap `t` as a literal string.
- `api.raw(t)` — append raw Lua to `code`.
- `api.forward_text(t)` — recursively process inline content.
- `api.is_control_open` / `api.lua_control` — expose the control-flow detector so blocks can lift loops inside their own bodies (used by `<draw>`).
- `api.process_block(lines)` — wrap a list of strings as `{text=...}` records and recurse into `process_lines`.

### Control-flow shapes

`is_control_open` (`scholatex.lua:64-71`) accepts five shapes, all requiring the `{` to be the last non-whitespace character (rejected if the line ends in `{{`, see `ends_struct_open` at 57-62):

| Source | Lua translation | File:line |
|---|---|---|
| `for VAR in [a, b, c] {` | `for _, VAR in ipairs({"a","b","c"}) do` (items `%q`-quoted → **always strings**) | 78-80 |
| `for VAR in A..B {` | `for VAR = A, B do` (bounds raw Lua, **numbers**) | 84 |
| `if COND {` | `if COND then` (COND raw Lua) | 85 |
| `} else {` | `else` | 86 |
| `while COND {` | `while COND do` | 87 |

There is no `elseif`. Cascaded conditionals must nest.

The bracketed-list items are always strings — `for n in [1, 2, 3] { ... }` binds `n` to `"1"`, `"2"`, `"3"`. Use `tonumber(n)` if arithmetic is needed.

## 6. `emit_tag`

`scholatex.lua:113-172`. Called from `forward_text` after locating `<HEAD WORDS>{CONTENT}`.

Words are split from `words_str` by whitespace: `for w in words_str:gmatch("%S+")` (`scholatex.lua:115`). Commas are not separators.

Three-way dispatch (`scholatex.lua:118-152`), **strict**: no fall-through, every miss is an error.

1. **`sl._tags[head]`** — built-in tag. Invoke `handler(mkapi(code), words, content)`.
2. **`MACRO[head]`** — user macro. Comma-split `content` (brace-aware, backslash-escape-aware, `scholatex.lua:127-143`). Substitute each `#param` with `body:gsub("#" .. pname .. "%f[%W]", repl)` (the `%f[%W]` frontier prevents `#x` from matching `#xy`). Recurse `forward_text(code, body)`.
3. **`STYLE.classify_split(words, ALIAS)`** — falls through to the style classifier (`scholatex-style.lua:213-221`), which returns `(outer, inner)` arrays. The classifier raises `scholatex: unknown tag attribute: 'X'` (`scholatex-style.lua:201`) or the CamelCase colour hint (`scholatex-style.lua:198-200`) on a miss.

If `STYLE.classify_split` succeeds, the emission order (`scholatex.lua:156-171`):

1. Emit all `outer[*][1]` openers (block-level wrappers).
2. Split content into paragraphs with `U.split_top_newlines`.
3. For each paragraph: ` \par ` between paragraphs from the second on, all `inner[*][1]` openers, recursive `forward_text(code, para)`, `inner` closers in reverse.
4. Emit `outer` closers in reverse.

## 7. `forward_text`

`scholatex.lua:174-312`. Single-pass character scanner that emits LaTeX into a `buf` and flushes via `lit(code, table.concat(buf))`. The character dispatch (`scholatex.lua:179-309`):

| Char | Behaviour | File:line |
|---|---|---|
| `$` | Find matching `$`. Scan inner text for `#NAME` / `#{EXPR}` placeholders (rewrite as `\scholatexI{N}` sentinels). Pass to `MATH.mathlite`. Emit `$ ... $` with sentinels replaced by `emit(_fmtm(EXPR))` calls. If no closing `$`, warn to stderr and emit `\$` | 182-231 |
| `\` | Always emit `\textbackslash{}`. Backslash is **inert** (closed-language since 2.0) | 233-234 |
| `<` | If `<<`, emit `\textless{}` and skip both. Otherwise parse `<WORDS>` head, look for `{` or treat content as up to EOL, then `emit_tag` | 236-264 |
| `#` | If `##`, emit `\#` and skip both. If `#{EXPR}`, balanced-read with `U.read_group`, append `emit(_fmt(EXPR))\n` to code. If `#NAME`, append `emit(_fmt(NAME))\n`. Else emit `\#` | 266-284 |
| `\n` | Flush, `lit(" \\par ")`. Only fires when `forward_text` was called on multi-line text — `emit_tag`'s STYLE fallback splits paragraphs before calling, so this is rarer | 287-289 |
| `>` | Always emit `\textgreater{}`. If next char is `>`, advance past it (`>>` collapse) | 290-292 |
| `{` | Always emit `\{`. If next is `{`, advance past it (`{{` collapse) | 293-295 |
| `}` | Always emit `\}`. If next is `}`, advance past it (`}}` collapse) | 296-298 |
| `_` | Emit `\_` | 299 |
| `&` | Emit `\&` | 300 |
| `%` | Emit `\%` | 301 |
| `^` | Emit `\textasciicircum{}` (**not** documented in README:597) | 302 |
| `~` | Emit `\textasciitilde{}` | 303 |
| U+00B0 `°` | Emit `\ensuremath{^\circ}`. Detected by the two-byte UTF-8 sequence `\194\176` | 304-305 |
| else | Pass through verbatim | 306 |

### Escape rules summary (CHANGELOG 2.0)

- **Five doublings**: `<<` `>>` `{{` `}}` `##` → `<` `>` `{` `}` `#`. Emit-time, not pre-pass.
- **Five auto-escapes**: `_` `&` `%` `^` `~` → `\_` `\&` `\%` `\textasciicircum{}` `\textasciitilde{}`. The user types them raw.
- **Backslash inert**: `\` always becomes `\textbackslash{}`. No backslash-as-escape syntax.
- **Inside `$...$`**: doublings and auto-escapes do **not** apply. The body goes through `mathlite`, which has its own rules.
- **`<nextline>`**: not a tag but a STYLE word producing `\newline ` (`scholatex-style.lua:94-96, 164-165`). Replaces the old `\\`.

## 8. Sandbox (`untrusted=true`)

The `untrusted` option (`scholatex.cls:25`) gates which load path runs.

### Whitelist

`SANDBOX_ALLOW` (`scholatex.lua:612-617`):

```lua
math = true, string = true, table = true,
type = true, tostring = true, tonumber = true,
ipairs = true, pairs = true, next = true,
select = true, error = true, assert = true,
unpack = (table and table.unpack) and "table.unpack" or true,
```

Every other global (`io`, `os`, `package`, `require`, `_G`, `debug`, ...) is absent from the env. A user `#{io.open(...)}` fails as `nil value (global 'io')` and the catch block at `scholatex.lua:737-742` rewrites it to a friendly message.

### `safe_string`

`scholatex.lua:620-642` clones the `string` table for the sandbox:

- Removes `string.dump`.
- Caps `string.rep(str, n, sep?)`: enforces `n * (#str + (sep and #sep or 0)) <= SANDBOX_STR_CAP = 100000` before allocating.
- Caps `string.format`: checks the actual output length after computation.

Both raise `scholatex: string.X result too large in untrusted mode (limit 100000 characters)`.

### `make_sandbox_env`

`scholatex.lua:644-667`. Builds a fresh env table for each `sl.transpile` call. Inputs from `SANDBOX_ALLOW`, plus two injected helpers:

- `env.vector = function(...)` — at least 2 components, returns a sequence table. Used by user `let u = vector(3, 5)` plus `#{u[1]}` access (`examples/geometry.tex:109-111`).
- `env.__drawbuild = sl.build_figure_block` — the runtime entry the `<draw>` block calls. See `architecture/figure-draw.md`.

### `run_limited`

`scholatex.lua:670-687`. Runs the chunk inside a coroutine with a `debug.sethook` budget.

```
SANDBOX_MAX_STEPS = 2e7         (scholatex.lua:669)
hook step = 1e5 instructions
hard ceiling = SANDBOX_MAX_STEPS / 1e5 = 200 hook events
```

So the actual budget is **≤ 200 hook firings × 10⁵ instructions = ≤ 2·10⁷ Lua VM instructions**. Overflow raises `scholatex: untrusted document exceeded the instruction limit (possible runaway loop); aborted`, which propagates through `pcall` and the catch block at `scholatex.lua:730-736`.

`run_limited` also installs `debug.setmetatable("", {__index = safestr})` so `:method()` lookups on strings hit the sandboxed `string` clone, then restores the previous metatable on exit. Trusted runs are unaffected.

## Warning channels

Three Lua warning sites in `scholatex.lua` write to **both** `io.stderr` and the LuaTeX transcript via `texio.write_nl`:

| Site | Function | Trigger | File:line |
|---|---|---|---|
| 1 | `warn_if_shadows(name, lineno)` | `let NAME` where NAME shadows a tag, block, or style word | `scholatex.lua:50-58` |
| 2 | `forward_text` `$` branch | unterminated `$` in prose | `scholatex.lua:200-203` |
| 3 | `forward_text` `<` branch | unterminated `<` (no closing `>` on the rest of the buffer) | `scholatex.lua:261-266` |

The canonical pattern is:

```lua
io.stderr:write(msg, "\n")
if texio and texio.write_nl then texio.write_nl(msg) end
```

Two reasons for the dual write:

- **`io.stderr`** is the interactive feedback channel — the message appears on the operator's terminal during an `lualatex myfile.tex` run.
- **`texio.write_nl`** writes the same text into the LuaTeX `.log` file. l3build's regression harness diffs against that log, so a warning that fires only on stderr is invisible to baselines. After the dual write landed, `regress-B5.tlg` pins the shadow-warning text and the regression harness catches drift on that channel.

The `if texio and texio.write_nl` guard makes the module still runnable outside LuaTeX (e.g. plain `lua scholatex.lua` for unit testing) without crashing on the missing `texio` namespace.

See `must/working-agreement.md` § "Dual-channel warnings" for the rule when adding new warnings. The baseline-pinning side is covered in `architecture/test-pipeline.md`.

## 9. Failure modes and their messages

| Trigger | Message | Mitigation |
|---|---|---|
| `tex.jobname` is not the on-disk source name | `scholatex.cls: cannot read '<src>'. If you used --jobname, ensure it matches the main source filename.` (`scholatex.cls:144-145`) | Drop `--jobname=...`. With latexmk, ensure the jobname matches the source root. The test-mode fallback to `status.filename` only fires when `regression-test.tex` is loaded |
| Body literally contains `\end{document}` (e.g. in prose about LaTeX) | `Class scholatex Warning: source contains more than one \end{document}; body truncated at first occurrence` (`scholatex.cls:154-155`). Body still silently truncates at the first occurrence; trailing content vanishes | No documented escape. Avoid typing the literal seven characters in scholatex prose. The warning is the partial fix; truncation cannot be recovered without a different regex |
| Unknown tag attribute | `scholatex: unknown tag attribute: 'X'` (`scholatex-style.lua:201`) | Usually a typo or a block name typed inline (e.g. `<box>{...}` on one line — see § "Process lines" step 4). Fix: move `{` to end-of-line for the block path |
| Lowercase colour | `scholatex: 'red' is not a colour; colours are written in CamelCase now -- use 'Red'` (`scholatex-style.lua:198-200`) | Rename per CamelCase |
| Sandbox instruction limit | `scholatex: untrusted document exceeded the instruction limit (possible runaway loop); aborted` (`scholatex.lua:676-679`) | Reduce loop count, or compile without `untrusted=true` |
| Sandbox string cap | `scholatex: string.X result too large in untrusted mode (limit 100000 characters)` (`scholatex.lua:619, 627, 635`) | Reduce the `rep`/`format` size |
| Missing global in sandbox | `scholatex: 'io' is not available in untrusted mode (only pure maths and string/table helpers are permitted)` (rewritten at `scholatex.lua:737-742`) | Use only `math`, `string`, `table`, basic primitives; or trust the document |
| Brace imbalance | `scholatex: line N: unbalanced '{'` or `unbalanced '}'` (`scholatex.lua:583-594`) | Look at the line and check that every `{` has a matching `}` |
| Tag/block name clash | `scholatex: tag '<name>' is already registered (name clash)` (`scholatex.lua:18, 25`) | Pick a different module-level name |
| Transpiled Lua syntax error | `scholatex: transpilation error\n...` (`scholatex.lua:721-723`) | Almost always a malformed `let NAME = EXPR` RHS or a stray `#{...}` |

## Generated Lua output by example

The traces below assume the trusted path. The `emit` calls in the right column are exactly what `build_lua` appends to `code`; the final `table.concat(_parts)` produces the LaTeX shown.

### Example A: `<text>{hello}` — **fails**

`<text>` is not a registered tag (`scholatex.lua` has no `sl.register_tag("text", ...)`; none of `scholatex-img`, `scholatex-plot`, `scholatex-vartab`, `scholatex-toc`, `scholatex-figure` register that name) and `text` is not a style word in `scholatex-style.lua`'s matchers.

Trace:

- `process_lines` opens the block-opener regex (`scholatex.lua:402`). The line ends in `}`, not `{`. **No block match.**
- Falls through to `forward_text(code, "<text>{hello}")`.
- `<` branch (`scholatex.lua:236-264`) parses `words_str = "text"`, finds `{`, reads `content = "hello"`, calls `emit_tag(code, "text", "hello")`.
- `emit_tag` (`scholatex.lua:113-172`):
  - `sl._tags["text"]` — nil.
  - `MACRO["text"]` — nil.
  - `STYLE.classify_split({"text"}, ALIAS)` — `text` does not match any matcher. **Raises** `scholatex: unknown tag attribute: 'text'`.
- The catch block at `scholatex.lua:695-701` rewrites to `scholatex: line N: unknown tag attribute: 'text'`.

To make this work the user must either define `let text = <some style>` first or write `hello` plainly (prose is the default). A close-to-canonical valid form is `<b>{hello}` (using the built-in `b` style word).

### Example B: `let x = <line Navy b>`

Top-level `let` directive, consumed in the pre-pass.

Trace:

- `scholatex.lua:540` matches. `an = "x"`, `arhs = "line Navy b"`.
- `warn_if_shadows("x", N)`: no shadow.
- Iterate words `{"line", "Navy", "b"}`. None of them are registered blocks (`scholatex.lua:543-549`). So `blockname` stays nil, `opts = {"line", "Navy", "b"}`.
- Falls into the no-block branch at `scholatex.lua:561`: `ALIAS["x"] = STYLE.resolve_styles({"line", "Navy", "b"}, ALIAS)`.
- Each word resolves (`scholatex-style.lua` line matcher, CSS colour `Navy`, style `b`) → `ALIAS["x"] = {"line", "Navy", "b"}`.

**No Lua code emitted** by `process_lines` for this line. The `let` is purely state-mutating. A later `<x>{paragraph}` would reach `STYLE.classify_split({"x"}, ALIAS)` which sees `alias["x"]` and recurses (`scholatex-style.lua:191-192`), equivalent to `<line Navy b>{paragraph}` typed directly.

### Example C: multi-line `<box Navy>{ ... }` block

```
<box Navy>{
Hello
}
```

Trace:

- Line 1 `<box Navy>{` matches `scholatex.lua:402`. `bname = "box"`. `BLOCKALIAS["box"]` not set. `sl._blocks["box"]` exists (registered in `scholatex-box.lua:94`).
- `U.collect_block` collects `["Hello"]` and consumes the closing `}`.
- `sl._blocks["box"](api, "Navy", {"Hello"})` runs. From `scholatex-box.lua`:

```lua
api.raw('emit("\\\\begin{tcolorbox}[enhanced, colframe=Navy, colback=White, ...]")\n')
-- api.process_block({"Hello"}) recurses into process_lines:
emit("Hello")        -- via forward_text
emit(" \\par ")
-- close:
api.raw('emit("\\\\end{tcolorbox}")\n')
-- process_lines appends the block-trailing \par:
emit(" \\par ")
```

Output after `collapse_par`: `\begin{tcolorbox}[...]Hello \par\end{tcolorbox} \par` (the duplicate `\par` after `Hello` folds against the next `\par` only if the wrapping closes correctly; `\par\end{tcolorbox}` keeps both).

### Example D: `for i in 1..3 { <b>{#i} }` — **idiomatic multi-line form**

The single-line form fails because `is_control_open` requires the `{` to be the last non-whitespace character on the line (`ends_struct_open` at `scholatex.lua:57-62`). The idiomatic form is multi-line:

```
for i in 1..3 {
  <b>{#i}
}
```

Trace:

- Line 1 `for i in 1..3 {` matches `is_control_open` range form. `lua_control` emits `for i = 1, 3 do\n`.
- Line 2 `  <b>{#i}` → `forward_text`:
  - `<b>` → `emit_tag(code, "b", "#i")` → STYLE fallback `b` → inner wrapper `("\\textbf{", "}")`. Body `#i` recurses through `forward_text`:
    - `#` followed by name → `code[#code+1] = "emit(_fmt(i))\n"`.
  - Emitted:
    ```lua
    emit("\\textbf{")
    emit(_fmt(i))
    emit("}")
    ```
- After `forward_text`, `process_lines:442` appends `emit(" \\par ")`.
- Line 3 `}` matches `^%s*}%s*$` → `code[#code+1] = "end\n"`.

Generated Lua for the body:

```lua
for i = 1, 3 do
  emit("\\textbf{")
  emit(_fmt(i))
  emit("}")
  emit(" \\par ")
end
```

After execution, `_parts` contains `\textbf{1} \par \textbf{2} \par \textbf{3} \par`. `collapse_par` finds no duplicates here. `print_par_lines` splits on `\par` and `tex.print`s three lines, each followed by `\par`.

## `collapse_par` and `print_par_lines`

`collapse_par` (`scholatex.lua:603-610`) walks until fixpoint, deleting any `\par` preceded by another `\par` (with optional whitespace and `}` in between). This is necessary because both block dispatch (`scholatex.lua:426`) and prose fall-through (`scholatex.lua:442`) append ` \par ` after every emission, and many style wrappers end in `\par}`.

`print_par_lines` (`scholatex.lua:749-757`) replaces every `\n` in the LaTeX with a space, then splits on `\par` (with frontier `%f[%A]` to avoid matching `\paragraph`), and pushes each segment plus `"\par"` into a table for `tex.print`. The result is pre-broken paragraphs — TeX sees one input line per paragraph.

## Related

- `architecture/figure-draw.md` — the `<draw>` block, including the `__drawbuild` runtime hand-off.
- `architecture/math-pipeline.md` — the `$ ... $` math compiler, called from `forward_text`.
- `reference/body-syntax-rules.md` (wave 2) — the user-facing summary of body-syntax rules, escapes, and edge effects.
- `memory/doc-gaps.md` — the documented-vs-coded drifts.
