# Body Syntax Rules Reference

## Scope

The canonical user-facing rules for writing the body of a scholatex `.tex` file (everything between `\begin{document}` and `\end{document}`). Covers block syntax, tag syntax, escape rules, inline math delimiters, paragraphing, the six `let` forms, control flow, and document-edge effects.

For the runtime compile model (how the body is read from disk, transpiled to Lua, executed trusted or sandboxed, and replayed via `tex.print`), forward to `architecture/compile-pipeline.md`. For the math sub-language inside `$...$`, forward to `architecture/math-pipeline.md`. For the closed style word vocabulary that powers `<a Navy b>`-style attributes, see `reference/text-style-vocabulary.md`.

For an inventory of known doc-vs-code drifts and footguns that touch body syntax (notably the README missing `^` in the auto-escape list, the `for ... in [a,b,c]`-as-strings footgun, and the `tex.jobname` mismatch), see `memory/doc-gaps.md`.

## Stable Facts

### 1. Block syntax

A **block opener** is a line that creates a multi-line structured container (`<box>`, `<grid>`, `<list>`, `<table>`, `<matrix>`, `<area>`, `<section>` with body, etc.). It is recognised by a single regex at `scholatex.lua:402`:

```
^%s*<(%a[%w_]*)%s*(.-)>%s*{%s*$
```

In plain English:

- `^%s*` — optional leading whitespace.
- `<(%a[%w_]*)` — `<` then a block name (a letter followed by letters / digits / underscores), captured.
- `%s*(.-)>` — optional whitespace, then attribute words (captured), then `>`.
- `%s*{%s*$` — optional whitespace, the literal `{`, optional trailing whitespace, **end of line**.

The load-bearing rule: **the `{` must be the last non-whitespace character on the line.** Anything after it (including another tag, content, or `}`) makes this **not** a block opener — the line flips silently to the inline-tag path described in § 2 below.

| Line | Block? | Why |
|---|---|---|
| `<box Navy>{` | yes | `{` is the last non-whitespace char. |
| `   <box Navy>{   ` | yes | Leading and trailing whitespace are allowed (`^%s*` and `%s*$`). |
| `<box>{ body }` | **no** | Line ends with `}`, not `{`. Falls through to the inline-tag path. |
| `<box Navy>{<text>{world}}` | **no** | Line ends with `}}`. Falls through. |
| `<box>{` then `body` on the same line | **no** | Character after `{` is not whitespace. Falls through. |
| `<<box>` | **no** | Doubled `<<` is the literal-`<` escape; the `<` branch in `forward_text` consumes it (`scholatex.lua:237-240`). |

**The closer** is a bare `}` on its own line, matched at `scholatex.lua:427` by `^%s*}%s*$`. The same regex serves both block bodies and lifted Lua control flow; disambiguation is by context (`U.collect_block` at `scholatex-util.lua:94-95` handles the block case; `process_lines` at `scholatex.lua:427-429` handles the top-level case).

**Nesting works**. `U.collect_block` (`scholatex-util.lua:85-106`) is depth-aware: when it sees another block-opener line inside the body, it increments `depth`; only a `}` at `depth == 1` closes the outer block. So `<box>` inside `<area>` inside `<grid>` compiles correctly.

**Multi-line tag heads work**. If the `>` is not on the same line as `<`, `process_lines` (`scholatex.lua:389-401`) joins subsequent lines using `opener_unclosed` (lines 358-378), then re-tests the block-opener regex against the joined line. This is how multi-line `<fn ...>` accumulators and multi-line `<box title:{long ...}>` work.

### 2. Tag syntax

A **tag** is the inline form `<name attrs>` followed by either a `{...}` group or content to end of line. Parsed in `forward_text` at `scholatex.lua:236-264` (the `<` branch of the character scanner).

| Form | Example | Citation |
|---|---|---|
| Brace form (single line) | `<b>{bold text}` | `scholatex.lua:254-256` — `U.read_group` extracts the balanced `{...}` group. |
| Brace form (block-shaped) | `<box Navy>{` ... `}` | The block path (see § 1). |
| No-brace form (content to EOL) | `<h1>First topic` | `scholatex.lua:258-263` — the `content` is everything from the closing `>` up to the next `\n` or end of input. |
| Multi-line head | `<fn name:{f}\n    expr:{x^2}>` | `scholatex.lua:389-401, 469-487`. |

**Attribute splitting**. Inside the head, words are split by `%S+` (`scholatex.lua:115`):

```lua
local words = {}
for w in words_str:gmatch("%S+") do words[#words + 1] = w end
```

So attributes are **whitespace-delimited**. Commas are not separators: `<box Navy, Red>` parses as two words `{"Navy,", "Red"}` — the trailing comma sticks to the first word and the resolver raises `unknown tag attribute: 'Navy,'`. Write `<box Navy Red>` instead.

**Key:value attribute values**. For block-style attributes like `<box title:{Hello} radius:4>`, `U.parse_attrs` (`scholatex-util.lua:142-187`) walks the option string character by character, recognising `key:{group}` (balanced braces, default), `key:[group]` (when the block opts in with `opts.brackets = true`, e.g. `<grid template:[...]>`), and bare `key:VALUE` where VALUE is a single non-whitespace token (`scholatex-util.lua:180-182`).

**Tag-body re-entry**. The body of any tag is **always re-parsed by `forward_text`**, so inner `<...>` tags and `$...$` math nest cleanly inside any tag body. See `architecture/compile-pipeline.md` § "emit_tag" for the three-way dispatch (built-in tag → `MACRO[head]` → STYLE fallback).

### 3. Escape rules

The body language is **closed**: backslashes are inert, the only escape mechanism is character-doubling, and a small set of TeX-special characters auto-escape themselves.

#### 3.1 The five doubling escapes (CHANGELOG 2.0)

Folded at emit time in `forward_text`:

| Source | Output | Citation |
|---|---|---|
| `<<` | `\textless{}` | `scholatex.lua:237-240` |
| `>>` | `\textgreater{}` | `scholatex.lua:290-292` |
| `{{` | `\{` | `scholatex.lua:293-295` |
| `}}` | `\}` | `scholatex.lua:296-298` |
| `##` | `\#` | `scholatex.lua:268-269` |

Asymmetry: `<<` and `##` are peek-ahead-before-processing (the first character's branch detects the doubled form and skips both); `>>`, `{{`, `}}` always emit the literal once and then consume the second character if present. Net effect is the same single literal.

`<<` and `>>` only collapse when **consecutive**. A line like `print <html>` is interpreted as an unterminated tag head — the `<` branch in `forward_text` emits a stderr warning (`scholatex.lua:244-247`: "To print a literal `<`, double it as `<<`.") and emits the literal `<` then continues. Use `<<html>>` to write the literal characters in prose.

#### 3.2 The five auto-escaped characters

`scholatex.lua:299-303` — the canonical list:

```
elseif c == "_" then buf[#buf + 1] = "\\_"
elseif c == "&" then buf[#buf + 1] = "\\&"
elseif c == "%" then buf[#buf + 1] = "\\%"
elseif c == "^" then buf[#buf + 1] = "\\textasciicircum{}"
elseif c == "~" then buf[#buf + 1] = "\\textasciitilde{}"
```

**Five** characters auto-escape: `_`, `&`, `%`, `^`, `~`. The user types them as themselves; the transpiler emits the proper LaTeX form.

**Doc drift**: `README.md:597` lists only four (`_ & % ~`), omitting `^`. The standalone manual at `scholatex.tex:361` lists all five correctly. See `memory/doc-gaps.md` for the citation chain.

#### 3.3 The backslash rule

`scholatex.lua:233-234`:

```
elseif c == "\\" then
  buf[#buf + 1] = "\\textbackslash{}"; i = i + 1
```

A backslash is **always** emitted as `\textbackslash{}`. There is no backslash-as-escape syntax — the CHANGELOG 2.0 BREAKING change removed `\<`, `\>`, `\{`, `\}`, `\#`. A Windows path `C:\Users\Leo` and a regex `\d+\s*` print literally (see `examples/text-style.tex:115`).

#### 3.4 Line-start `\%` escape

`scholatex.lua:508-515`:

```lua
local lead, rest = line:match("^(%s*)\\(%%.*)$")
if lead then
  line = lead .. rest
elseif line:match("^%s*%%") then
  goto continue
end
```

- A line whose first non-whitespace character is `%` is **dropped** as a Lua-style line comment.
- A line starting with optional whitespace then `\%` has the leading `\` **stripped**, leaving a line whose first non-whitespace character is `%`. Because the strip happens before the comment-line check (the `elseif` skips the second test), the line survives. This is the documented (in `scholatex.tex:375-376` only) way to print a literal `%` at the start of a line.

#### 3.5 Inside `$...$` — rules differ

The doubling escapes (`<<`, `>>`, `{{`, `}}`, `##`) and the auto-escape set (`_`, `&`, `%`, `^`, `~`) do **not** apply inside `$...$`. The `$` branch of `forward_text` (`scholatex.lua:182-231`) hands the inner text to `MATH.mathlite` (`scholatex-math.lua:201`), which has its own rules. In particular `_` and `^` inside `$...$` are TeX math subscript / superscript.

The only escape-like behaviour inside math is `#NAME` / `#{EXPR}` (Lua interpolation, see § 7 below). For the math sub-language proper, forward to `architecture/math-pipeline.md`.

#### 3.6 Inside attribute words — rules do not apply

Attribute words (the part after `<` and before `>`) are split by `%S+` and matched against the closed style vocabulary (see `reference/text-style-vocabulary.md`). They are **not** processed by `forward_text`, so the doubling and auto-escape rules do not fire there. An attribute word like `<<` would not be processed by `forward_text` — it would be matched against the style vocabulary and either resolve or raise `unknown tag attribute: '<<'`.

Inside `key:{value}` groups that the receiving block hands to `api.forward_text` (e.g. `<box title:{...}>`), the value **is** re-processed and the escape rules **do** apply (auto-escapes and doublings both fire).

### 4. Inline math

#### 4.1 Delimiters

Only `$...$` — there is no `$$...$$` display form. The `$` branch in `forward_text` (`scholatex.lua:182-231`) scans for the *next single* `$` via `s:find("$", i + 1, true)` (`scholatex.lua:183`).

If a user types `$$x$$`, the first `$` opens math, the second `$` closes it with an empty body, the `x` is plain text, then the third `$` opens another empty span and the fourth closes it. So `$$` is **not** display math — it is two empty math spans separated by plain text.

For display-style equations, scholatex provides block forms like `<matrix>`, `<det>`, `<bmatrix>`, `<system>` (see `architecture/math-pipeline.md`) — not `$$...$$`.

#### 4.2 Unmatched `$` (graceful degradation)

`scholatex.lua:182-189`:

```lua
if c == "$" then
  local close = s:find("$", i + 1, true)
  if not close then
    local where = sl._line and (" (line " .. sl._line .. ")") or ""
    io.stderr:write("scholatex: warning: unterminated '$'" .. where
      .. "; treating it as a literal dollar sign.\n")
    buf[#buf + 1] = "\\$"; i = i + 1
    goto continue
  end
```

A stray `$` does **not** halt compilation. Behaviour:

1. Write a warning to **stderr** (not the LaTeX log) with `(line N)` if `sl._line` is set.
2. Emit `\$` (literal dollar sign).
3. Continue parsing past the `$`.

Compare this with brace imbalance, which **does** halt at `scholatex.lua:583-594` with `unbalanced '{'` or `unbalanced '}'`.

### 5. Paragraphing

#### 5.1 Blank line → new paragraph

The mechanism is the default behaviour of `process_lines`: every non-empty entry in `body_lines` emits a `\par` after its content. Block dispatch (`scholatex.lua:426`) and prose fall-through (`scholatex.lua:442`) both append `emit(" \\par ")`. So every source line contributes a `\par`, and consecutive blank source lines produce consecutive `\par`s.

The final `collapse_par` pass (`scholatex.lua:603-610`) walks until fixpoint, deleting any `\par` preceded by another `\par` (with optional whitespace and `}` in between):

```lua
local function collapse_par(s)
  local prev
  repeat
    prev = s
    s = s:gsub("(\\par[%s}]*)\\par", "%1")
  until s == prev
  return s
end
```

Net effect: any number of blank lines fold to a single paragraph break — what TeX needs.

#### 5.2 `<nextline>` is a **style word**, not a tag

`<nextline>` is **not** registered with `sl.register_tag`. It is one of the entries in `scholatex-style.lua:94-96`:

```lua
function(w)
  if w == "nextline" then return {kind = "break"} end
end
```

Consumed in `classify_into` at `scholatex-style.lua:164-165`:

```lua
elseif r and r.kind == "break" then
  buckets.page[#buckets.page + 1] = {"\\newline ", ""}
```

So `<nextline>` produces a `\newline ` token — an in-paragraph line break that does **not** start a new paragraph. It replaces the old `\\` (removed in CHANGELOG 2.0 BREAKING).

Because it is a style word and not a registered tag, you can also stack it with other style words inside an attribute list: `<nextline c Navy>` works (line break, then centred, then Navy — applied to whatever follows).

#### 5.3 Trailing newline normalisation

`print_par_lines` (`scholatex.lua:749-757`) replaces every `\n` in the assembled LaTeX with a space, then splits on `\par` (with frontier `%f[%A]` to avoid `\paragraph`), and feeds each segment plus `"\par"` to `tex.print`. The TeX side receives **pre-broken paragraphs**, one input line per paragraph.

### 6. `let` forms (six forms total)

`build_lua` (`scholatex.lua:491-571`) recognises six `let` syntactic forms, lifted in a pre-pass. All examples below render exactly as documented in the README and `examples/` files.

#### Form A — `let NAME = <fn ARGS>` (object accumulator)

`scholatex.lua:492` matches `^%s*let%s+([%a_][%w_]*)%s*=%s*<%s*fn%f[%s>](.*)$`. The RHS is parsed by `sl.fn_parse` (defined in `scholatex-vartab.lua:405-407`) and stored in `sl._objects[NAME]`. Supports multi-line accumulation: if the matched line does not end with `>%s*$`, an accumulator buffer collects subsequent lines until a `>` line is reached (`scholatex.lua:500-503, 474-487`).

```
let f = <fn name:{f(x)}
            expr:{-x^4 + 2x^2 + 1}
            x:{-inf | -1 | 0 | 1 | +inf}
            deriv:{+ | + | - | -}
            var:{-inf / 2 \ 1 / 2 \ -inf}>
```

#### Form B — `let NAME{params} = <BLOCK ...>` (parametric block alias)

`scholatex.lua:516-535` — parametric, RHS bracketed, at least one word inside resolves to a registered block name. Stores `BLOCKALIAS[NAME] = {block = W, opts = other_words, params = plist}`.

```
let exo{n} = <box title:{Exercise #n} line:Navy fill:AliceBlue radius:2>
```

Invoke as `<exo 1>{ body }`. The `1` arg is comma-split (via `U.split_commas`, `scholatex.lua:407`) and substituted into the opts via `gsub("#" .. pname .. "%f[%W]", repl)`.

#### Form C — `let NAME{params} = RHS` (parametric text macro)

`scholatex.lua:537` — parametric, RHS is **not** a block. Stores `MACRO[NAME] = {params = plist, body = RHS}`.

```
let greet{name} = Hello #name!
```

At use time `<greet World>`, args are comma-split, `#param` is substituted via `body:gsub("#" .. pname .. "%f[%W]", repl)` (`scholatex.lua:148`; the `%f[%W]` frontier prevents `#x` from matching `#xy`), and the result is fed to `forward_text`.

#### Form D — `let NAME = <BLOCK ...>` (non-parametric block alias)

`scholatex.lua:540-557` — non-parametric, words include a registered block name. **Dual-write**: both `BLOCKALIAS[NAME]` (with `params = {}`) and `ALIAS[NAME] = STYLE.resolve_styles(words, ALIAS)` are populated. The latter would error at registration time if the block word were not first resolvable as a style — in practice this means `let mybox = <box ...>` writes to `BLOCKALIAS` but errors on `STYLE.resolve_styles` because `box` is not a style word.

Most examples use Form E instead. This dual-write quirk is noted in `memory/doc-gaps.md`.

#### Form E — `let NAME = <STYLE WORDS>` (style alias)

`scholatex.lua:540-561`, inner else when no word resolves to a block. `ALIAS[NAME] = STYLE.resolve_styles(words, ALIAS)`. Each word is validated against the style vocabulary or an existing alias at **registration time**; nested aliases are flattened in place.

```
let title = <Red b 20pt c>
let h1    = <Navy b section>
let h2    = <Blue i subsection>
let p     = <tab>
let key   = <b Crimson>
```

#### Form F — `let NAME = EXPR` (value binding)

`scholatex.lua:564` matches `^%s*let%s+([%a_][%w_]*)%s*=%s*(.+)$` — the catch-all when the RHS is not bracketed. Appends `{var = NAME, expr = EXPR}` to `body_lines`. At generation time this becomes a Lua `local NAME = EXPR` in the chunk (`scholatex.lua:385-386`).

```
let n = 7
```

Then `#n`, `#{n*n}`, `#{n/2}` interpolate the bound value.

#### Match order and immediate effect

Forms A → B/C → D/E → F are checked sequentially. Forms A–E mutate module-local tables (`ALIAS`, `MACRO`, `BLOCKALIAS`, `sl._objects`) at pre-pass time; only Form F produces runtime Lua. All non-fn forms call `warn_if_shadows(NAME, lineno)` (`scholatex.lua:494, 518, 542`), which writes a stderr warning if the alias name collides with a built-in style, block, or tag — but the entry is **still written** to the dictionary (it is just dead, because the dispatcher always checks built-ins first).

### 7. Control flow

#### 7.1 Recognised opener shapes

`is_control_open` at `scholatex.lua:64-71`:

```lua
local function is_control_open(line)
  if line:match("^%s*for%s+[%a_][%w_]*%s+in%s+%b[]%s*{%s*$") then return true end
  if line:match("^%s*for%s+[%a_][%w_]*%s+in%s+%S+%.%.%S+%s*{%s*$") then return true end
  if line:match("^%s*}%s*else%s*{%s*$") then return true end
  if line:match("^%s*if%s+.+{%s*$") and ends_struct_open(line) then return true end
  if line:match("^%s*while%s+.+{%s*$") and ends_struct_open(line) then return true end
  return false
end
```

Five shapes — all requiring the `{` to be the last non-whitespace character on the line (via `ends_struct_open` at `scholatex.lua:57-62`, which also rejects `{{`).

#### 7.2 Translations to Lua

`lua_control` (`scholatex.lua:73-91`):

| Source | Generated Lua | Citation |
|---|---|---|
| `for VAR in [a, b, c] {` | `for _, VAR in ipairs({"a", "b", "c"}) do` — items are **`%q`-quoted strings** | `scholatex.lua:78-80` |
| `for VAR in FROM..TO {` | `for VAR = FROM, TO do` — bounds are **raw Lua expressions (numbers)** | `scholatex.lua:84` |
| `if COND {` | `if COND then` — COND raw | `scholatex.lua:85` |
| `} else {` | `else` | `scholatex.lua:86` |
| `while COND {` | `while COND do` | `scholatex.lua:87` |

The closer is the same bare `}` line that closes a block (§ 1). Context disambiguates: at the top level of `process_lines`, a bare `}` always emits `end` (`scholatex.lua:427-429`); inside a block body, `U.collect_block` consumes it first.

#### 7.3 Bracketed-list items are always strings (footgun)

`scholatex.lua:78-80`:

```lua
for _, it in ipairs(items) do
  quoted[#quoted + 1] = string.format("%q", it)
end
```

`%q` quotes every item as a Lua string literal. So `for n in [1, 2, 3] { ... }` makes `n` take the **string** values `"1"`, `"2"`, `"3"` — not numbers. Using `#n` interpolates the string fine; using `n` as a number in `#{n*2}` causes a Lua type error. Wrap with `tonumber(n)` for arithmetic.

The range form `for n in 1..3 { ... }` passes bounds verbatim as Lua expressions, so `n` IS a number there. No doc warns about this asymmetry. See `memory/doc-gaps.md`.

#### 7.4 No `elseif`

`scholatex.lua:64-91` recognises only `} else {` as a chained control shape — there is no `elseif` syntax. Cascaded conditionals must nest:

```
if a == 1 {
  ...
} else {
  if a == 2 {
    ...
  } else {
    ...
  }
}
```

### 8. Document-edge effects

#### 8.1 `tex.jobname` mismatch with on-disk source

`scholatex.cls:135-145` reads `tex.jobname .. ".tex"` from disk:

```latex
\AtBeginDocument{%
  \directlua{
    local f = io.open(tex.jobname .. ".tex", "r")
    local whole = f:read("*a"); f:close()
    local body = whole:match("\string\\begin{document}(.-)\string\\end{document}")
    ...
  }
  \end{document}%
}
```

If `tex.jobname` does not match the on-disk source filename:

- `lualatex --jobname=other main.tex` → `tex.jobname = "other"`, the class tries to read `other.tex`. If the file is missing, `f:read` raises a Lua error in `\directlua`. If `other.tex` exists (say, a different document), the body extracted is **the wrong file's body** — silently rendering wrong content.
- `\input{other.tex}` from a master file → `tex.jobname` is the master's name (set by the command line), not the included file's. The class reads the master's content.
- Build wrappers that pre-process to a temporary file (some latexmk configurations, arara recipes, CI scripts) — same risk.

User-visible symptom: either `scholatex.cls: begin/end document not found` (the readable error path at `scholatex.cls:141`) or wildly incorrect typeset output (the silent-truncation path).

The deeper explanation lives in `architecture/compile-pipeline.md` § "Body extraction (the `\AtBeginDocument` trick)" and § "Failure modes".

#### 8.2 Body literally containing `\end{document}`

The Lua pattern at `scholatex.cls:139` is `\begin{document}(.-)\end{document}` — `(.-)` is **non-greedy**. If the body literally contains the seven characters `\end{document}` (e.g. in prose about LaTeX itself), the regex stops at the **first** occurrence, and the rest of the file is **silently dropped**. No warning, no error.

There is no documented escape route. The auto-escape rules in `forward_text` (`scholatex.lua:233-234`) replace `\` with `\textbackslash{}` at emit time — but the body-extraction regex runs on the **raw source on disk**, before any escape rules fire. So writing `\\end{document}` does not help; the source still contains the literal seven-character sequence after the leading backslash.

User-visible symptom: the trailing portion of the document does not render. Easy to miss for a long document.

The deeper discussion lives in `architecture/compile-pipeline.md` § "Failure modes".

## Common errors and their meaning

| Message | When | What it actually means | Citation |
|---|---|---|---|
| `scholatex: unknown tag attribute: 'X'` | At `STYLE.classify_split` time | `X` is not a built-in style word, colour, font, alignment, size, page/break word, line, tab, or up/down script, AND is not a registered alias. Frequent cause: writing a block tag inline like `<box>{stuff}` on one line — the inline-tag path tries to treat `box` as a style word. Fix: move `{` to its own line (block form), or use the correct style word. | `scholatex-style.lua:201` |
| `scholatex: 'red' is not a colour; colours are written in CamelCase now -- use 'Red'` | Lowercase colour | The 22 simple colour keywords removed in CHANGELOG 2.1 BREAKING. The hint only fires for one-word colours whose first-letter-capitalised form is in `S.CSS` — multi-word lowercase (`darkblue`) gives the generic unknown-attribute error. | `scholatex-style.lua:196-200` |
| `scholatex.cls: begin/end document not found` | Class boot, `\AtBeginDocument` Lua step | The Lua read `tex.jobname .. ".tex"` from disk, and either the file did not contain `\begin{document}` / `\end{document}`, or `tex.jobname` does not match the source filename (custom `--jobname`, latexmk shadow copy, build wrapper). | `scholatex.cls:141` |
| `scholatex: untrusted document exceeded the instruction limit (possible runaway loop); aborted` | Sandbox runtime | The chunk (running under `untrusted=true`) ran past the `SANDBOX_MAX_STEPS = 2 × 10⁷` instruction budget. Usually a `for n in 1..1000000 { ... }`. | `scholatex.lua:676-679` |
| `scholatex: line N: unbalanced '{'` / `unbalanced '}'` | Brace-balance pre-pass | The line-by-line scanner counted unmatched `{` or `}`. The `{{` and `}}` doubling pairs balance correctly; this is about real source-level imbalance. | `scholatex.lua:583-594` |
| `scholatex: 'io' is not available in untrusted mode ...` | Sandbox runtime | A `#{...}` or `let X = EXPR` tried to call a global outside the whitelist (`math`, `string`, `table`, `type`, `tostring`, `tonumber`, `ipairs`, `pairs`, `next`, `select`, `error`, `assert`, `unpack`). Rewritten at `scholatex.lua:737-742`. | `scholatex.lua:737-742` |

For the full diagnostics table including class-level failure modes (font fallback warning, unknown class option falling through), see `architecture/compile-pipeline.md` § "Failure modes and their messages".
