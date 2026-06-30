# Text Style Vocabulary Reference

## Scope

The complete closed vocabulary of style descriptor words that the `let` system, the inline-tag fallback in `emit_tag`, and the section/box/list family all consume. These words appear after `<...` in tag and block attributes (e.g. `<b Navy>`, `<box line:Crimson title:{...} radius:2>`) and as the RHS of `let NAME = <words>` (Form E in `reference/body-syntax-rules.md` § 6).

This document only covers the closed style language defined in `scholatex-style.lua`. For the body-level syntax rules that invoke it (block opener, tag form, escapes), see `reference/body-syntax-rules.md`. For the dispatch pipeline that calls into `STYLE.classify_split`, see `architecture/compile-pipeline.md` § "emit_tag".

For known doc-vs-code drifts touching this surface (no strikethrough word, the dead `EMIT_ORDER` constant, the counter-not-classified gap), see `memory/doc-gaps.md`.

## Stable Facts

### 1. The 13-matcher resolver pipeline

`S.resolve(word)` (`scholatex-style.lua:136-142`) iterates a list of 13 small matcher functions in **priority order**. The first matcher that returns a non-nil descriptor wins; if all return nil, the resolver returns nil and the caller decides whether to consult the alias table or raise.

| # | Matcher kind | Lines | Pattern | Returned `kind` |
|---|---|---|---|---|
| 1 | counter | `scholatex-style.lua:45-49` | exact match in `{num, roman, ROMAN, alpha, ALPHA}` | `counter` |
| 2 | font | `scholatex-style.lua:52-56` | all-caps with no lowercase, first character is uppercase: `w:match("^%u") and w == w:upper() and not w:match("%l")` | `font` |
| 3 | color | `scholatex-style.lua:59-63` | exact key in the 151-entry CamelCase `S.CSS` table | `color` |
| 4 | style | `scholatex-style.lua:66-70` | exact key in `S.STYLE` (`b i u emph sf sc`) | `style` |
| 5 | align | `scholatex-style.lua:73-75` | exact key in `S.ALIGN` (`l c r j`) | `align` |
| 6 | section | `scholatex-style.lua:78-80` | exact key in `S.SECTION` (`section subsection subsubsection`) | `section` |
| 7 | size | `scholatex-style.lua:83-86` | regex `^(%d+%.?%d*)p[tx]$` (e.g. `12pt`, `14.5px`) | `size` |
| 8 | page | `scholatex-style.lua:89-91` | exact match `nextpage` | `page` |
| 9 | break | `scholatex-style.lua:94-96` | exact match `nextline` | `break` |
| 10 | lines | `scholatex-style.lua:102-115` | `line`, `1line`, or `Nlines` (N ≥ 2); raises a hint on `1lines` or `Nline` for N ≥ 2 | `lines` |
| 11 | tab | `scholatex-style.lua:118-121` | `tab` (= 1) or `Ntab` via `count_prefix` | `tab` |
| 12 | up | `scholatex-style.lua:124-127` | regex `^up(%d+%.?%d*)$` | `up` |
| 13 | down | `scholatex-style.lua:130-133` | regex `^down(%d+%.?%d*)$` | `down` |

**Why counter is first**: the comment at `scholatex-style.lua:42-44` explains that `ROMAN` and `ALPHA` are all-caps and would otherwise be swallowed by matcher #2 (font). Counter first → these five literal words route correctly.

**Why font is second, colour third**: `DEJAVU` is all-caps (matcher 2 catches); `Navy` is mixed-case (matcher 2 rejects because of the `not w:match("%l")` clause, matcher 3 catches). This single rule cleanly separates the three case classes the "one rule" pitch describes.

### 2. Vocabulary tables (one per matcher)

#### 2.1 Counter (`kind = "counter"`)

| Word | LaTeX command | Reg line | Effect | Emit fragment |
|---|---|---|---|---|
| `num` | `\arabic` | `scholatex-style.lua:46` | Arabic counter (1, 2, 3) | (consumed by section block, see § 2.6) |
| `roman` | `\roman` | `scholatex-style.lua:46` | lowercase roman (i, ii, iii) | same |
| `ROMAN` | `\Roman` | `scholatex-style.lua:46` | uppercase roman (I, II, III) | same |
| `alpha` | `\alph` | `scholatex-style.lua:47` | lowercase alphabetic (a, b, c) | same |
| `ALPHA` | `\Alph` | `scholatex-style.lua:47` | uppercase alphabetic (A, B, C) | same |

**Routing caveat**: `classify_into` (`scholatex-style.lua:155-205`) has **no branch** for `kind = "counter"`. So if a counter word is the only word in a free-standing `<num>...` tag, the resolver hits the alias fallback at line 191, fails there, and raises `unknown tag attribute: 'num'`. The counter words are **only meaningful** inside `<section ...>{...}`, `<subsection ...>{...}`, `<subsubsection ...>{...}` block bodies, where the section block intercepts them — see § 2.6 for the cross-module routing.

This dead-branch is recorded in `memory/doc-gaps.md` as a code smell; not a user-facing bug because the section block path covers all real use cases.

#### 2.2 Font weight / style (`kind = "style"`)

Defined as a literal table in `scholatex-style.lua:7-11`:

| Word | Reg line | Effect | Emit fragment |
|---|---|---|---|
| `b` | `scholatex-style.lua:8` | bold | `\textbf{ ... }` |
| `i` | `scholatex-style.lua:8` | italic | `\textit{ ... }` |
| `u` | `scholatex-style.lua:8` | underline | `\underline{ ... }` |
| `emph` | `scholatex-style.lua:9` | semantic emphasis | `\emph{ ... }` |
| `sf` | `scholatex-style.lua:9` | sans-serif | `\textsf{ ... }` |
| `sc` | `scholatex-style.lua:10` | small caps | `\textsc{ ... }` |

**Doc-gap pointer**: there is **no strikethrough word** (`s` is not in `S.STYLE`); no overline, no double-underline, no wave-underline. The descriptor language carries only these six. See `memory/doc-gaps.md` for the rolling list of vocabulary that exists in code but not in docs.

#### 2.3 Colour (`kind = "color"`)

The vocabulary is the **151 CamelCase CSS `svgnames` colours** stored as a literal table in `scholatex-style.lua:14`. This is a single ~1.6 KB line of source that maps each name to `true`; the resolver checks `S.CSS[w]` for exact-key membership (`scholatex-style.lua:60`).

| Aspect | Detail | Citation |
|---|---|---|
| Vocabulary location | The literal table at `scholatex-style.lua:14` (151 entries on one line) | `scholatex-style.lua:14` |
| Resolver | Exact lookup `S.CSS[w]` (no regex, no case folding) | `scholatex-style.lua:60-62` |
| Emit fragment | `\textcolor{NAME}{ ... }` (verbatim NAME) | `scholatex-style.lua:61` |
| Case rule | CamelCase only. CHANGELOG 2.1 BREAKING removed the 22 lowercase keywords. | `CHANGELOG.md:161-167` |
| Lowercase-error hint | `classify_into` final `else` capitalises only the first letter (`^%l`) and re-checks `S.CSS[cap]`; if found, raises **`scholatex: '<w>' is not a colour; colours are written in CamelCase now -- use '<Cap>'`**. The hint only fires for one-word colours (`red → Red`); multi-word like `darkgray` give the generic `unknown tag attribute` error because `Darkgray` is not in `S.CSS` (the CamelCase form is `DarkGray`). | `scholatex-style.lua:196-200` |

Do not enumerate the 151 names here — they live verbatim in `scholatex-style.lua:14` and are documented in the README's Colour reference (`README.md:602-628`) for end users.

#### 2.4 Align (`kind = "align"`)

Defined as a literal table in `scholatex-style.lua:16`:

| Word | LaTeX command | Reg line | Emit fragment |
|---|---|---|---|
| `l` | `\raggedright` | `scholatex-style.lua:16` | `{\raggedright ... \par}` |
| `c` | `\centering` | `scholatex-style.lua:16` | `{\centering ... \par}` |
| `r` | `\raggedleft` | `scholatex-style.lua:16` | `{\raggedleft ... \par}` |
| `j` | `\justifying` | `scholatex-style.lua:16` | `{\justifying ... \par}` |

The `\par` in the close fragment is intentional — `classify_into:169` writes `{r.cmd .. " ", "\\par}"}`. Routed into the `align` bucket (outer wrappers, see § 4).

#### 2.5 Size (`kind = "size"`)

Regex `^(%d+%.?%d*)p[tx]$` (`scholatex-style.lua:84`). Accepts both `pt` and `px` suffixes; the number can carry a decimal point.

| Word | Reg line | Emit fragment |
|---|---|---|
| `Npt` / `N.Npt` / `Npx` / `N.Npx` | `scholatex-style.lua:83-86` | `{\fontsize{N}{1.2N}\selectfont ... }` — leading is `pt * 1.2` formatted with `%.1f` |

The literal `1.2` leading factor is hardcoded at `classify_into:177` and documented inline as `-- 1.2 = leading factor`.

#### 2.6 Section (`kind = "section"`)

Defined as a literal table in `scholatex-style.lua:17`:

| Word | LaTeX command | Reg line |
|---|---|---|
| `section` | `\section` | `scholatex-style.lua:17` |
| `subsection` | `\subsection` | `scholatex-style.lua:17` |
| `subsubsection` | `\subsubsection` | `scholatex-style.lua:17` |

**Two code paths consume section words** (cross-module):

1. **Lightweight attribute form** `<section>Title` or `<line Navy b section>Title`. Routed through `classify_into:161` → outer `{r.cmd .. "{", "}"}` wrappers. Emits e.g. `\section{ ... }` around the entire tag content.
2. **Block form** `<section title:{Title}>{ body }`. The `scholatex-section.lua` module registers `section` / `subsection` / `subsubsection` as blocks. The block's own loop at `scholatex-section.lua:68-88` walks the attribute words, intercepting:
   - `kind = "counter"` → captured into `counter_cmd`, used to redefine `\thesection` / `\thesubsection` / etc. via `\renewcommand` (`scholatex-section.lua:92-97`).
   - `kind = "style"` / `kind = "color"` → captured into `style_open` / `style_close`, wrapped around the title text only.
   - `kind = "size"` → same treatment with `\fontsize{...}{...}\selectfont`.
   - `kind = "lines"` → captured into `before`, emitted as `\vspace*` ahead of the heading.
   - Anything else → raises `<NAME> only accepts colour/style words, a line skip, or a counter style ...`.

So the counter words `num roman ROMAN alpha ALPHA` reach the user **only** through the section block — they are not classifiable in the generic `classify_into` chain. The cross-module routing is at `scholatex-section.lua:69-71`.

#### 2.7 Page (`kind = "page"`)

| Word | Reg line | Effect | Emit fragment |
|---|---|---|---|
| `nextpage` | `scholatex-style.lua:89-91` | new page before this tag's content | `\newpage ` (with trailing space) |

Routed into `buckets.page` at `classify_into:162-163`. **Single slot**: `buckets.page[1] = {"\\newpage ", ""}` — repeated `nextpage` words overwrite each other.

#### 2.8 Break (`kind = "break"`)

| Word | Reg line | Effect | Emit fragment |
|---|---|---|---|
| `nextline` | `scholatex-style.lua:94-96` | in-paragraph line break (does not end paragraph) | `\newline ` |

Routed into the **same bucket** as `page` (note: `buckets.page[#buckets.page + 1]` at `classify_into:165`) — but appended rather than overwriting slot 1. So `nextpage nextline` first sets slot 1 to `\newpage`, then appends `\newline` at slot 2.

`<nextline>` is the CHANGELOG 2.0 BREAKING replacement for the removed `\\` syntax. It is **not** a registered tag — it is a style word. So you can stack it with other style words: `<nextline c Navy>` works (line break, then centered, then Navy applied to whatever follows).

#### 2.9 Lines (`kind = "lines"`)

Strict singular/plural agreement, with explicit error messages.

| Word | Reg line | Effect | Emit fragment |
|---|---|---|---|
| `line` or `1line` | `scholatex-style.lua:103` | 1 line skip | `\vspace*{1\scholatexline}` |
| `Nlines` (N ≥ 2) | `scholatex-style.lua:104-110` | N line skip | `\vspace*{N\scholatexline}` |
| `1lines` | `scholatex-style.lua:106-108` | (error) raises `scholatex: write '1line' (singular), not '1lines'` | — |
| `Nline` (N ≥ 2) | `scholatex-style.lua:111-114` | (error) raises `scholatex: write 'Nlines' (plural), not 'Nline'` | — |

The `\scholatexline` length register is defined at `scholatex.cls:66-67` from the `lineheight` class option (default 8mm).

#### 2.10 Tab (`kind = "tab"`)

| Word | Reg line | Effect | Emit fragment |
|---|---|---|---|
| `tab` or `Ntab` | `scholatex-style.lua:118-121` | N tab indents (N defaults to 1 for bare `tab`) | `\hspace*{N\scholatextab}` |

Helper `count_prefix` (`scholatex-style.lua:34-38`) accepts `tab` → "1" or `Ntab` → "N".

Routed into `buckets.wrap` (inline-level) at `classify_into:170-171`. The `\scholatextab` length register is defined at `scholatex.cls:64-65` from the `tabwidth` class option (default 8mm).

#### 2.11 Up (`kind = "up"`)

| Word | Reg line | Effect | Emit fragment |
|---|---|---|---|
| `upN` or `upN.N` | `scholatex-style.lua:124-127` | raise content by N mm and scale by `\scholatex@scriptfactor` | `\scholatexscript{Nmm}{ ... }` |

`\scholatexscript{#1}{#2}` is defined at `scholatex.cls:72-73` as `\raisebox{#1}{\scalebox{\scholatex@scriptfactor}{#2}}` (script factor derived from `scriptscale` class option, default 100%).

#### 2.12 Down (`kind = "down"`)

| Word | Reg line | Effect | Emit fragment |
|---|---|---|---|
| `downN` or `downN.N` | `scholatex-style.lua:130-133` | lower content by N mm and scale | `\scholatexscript{-Nmm}{ ... }` |

Same `\scholatexscript` macro as `up`, with negated displacement.

#### 2.13 Font (`kind = "font"`)

| Pattern | Reg line | Effect | Emit fragment |
|---|---|---|---|
| All-caps starting with uppercase, no lowercase: `w:match("^%u") and w == w:upper() and not w:match("%l")` | `scholatex-style.lua:52-56` | switch to a fontspec font | `{\fontspec{NAME [SUB SUB ...]} ... }` |

The matcher returns just `{kind = "font"}` — no name field. **Composition rule**: `classify_into:182-190` greedily consumes subsequent all-uppercase words from the current attribute list and joins them with single spaces. So `<DEJAVU SANS 13pt>` matches `DEJAVU` (font kind), then continues eating `SANS` (still all-caps, still no lowercase), emerges as `{\fontspec{DEJAVU SANS} ... }`, then breaks out at `13pt` (mixed case, contains digit + lowercase).

The trailing `i = i - 1` (`scholatex-style.lua:190`) compensates for the outer loop's `i = i + 1` at line 203 so the next iteration sees the right word.

### 3. `S.classify_split(words, ALIAS)` — outer / inner buckets

`S.classify_split` (`scholatex-style.lua:213-221`) is the entry point called by `emit_tag` at `scholatex.lua:154`. It runs `classify_into` to fill five buckets, then flattens four of them into `outer` and returns `buckets.wrap` as `inner`:

```
outer order = page, lines, section, align        (block-level, may straddle \par)
inner       = wrap                               (inline, must reopen around each paragraph)
```

The hard-coded outer order at `scholatex-style.lua:217`:

```lua
for _, cat in ipairs({"page", "lines", "section", "align"}) do
  for _, e in ipairs(buckets[cat]) do outer[#outer + 1] = e end
end
```

The split exists because LaTeX inline commands like `\textcolor{...}` and `\textbf{...}` **cannot contain a `\par`**. So `emit_tag` (`scholatex.lua:156-171`):

1. Emits all `outer` openers once.
2. Splits the tag content into paragraphs via `U.split_top_newlines`.
3. For each paragraph: reopens all `inner` wrappers, recurses `forward_text` into the body, closes `inner` in reverse.
4. Closes `outer` in reverse.

This is the single most important emission contract in the style system.

### 4. Alias interleaving (`STYLE.classify_split(words, ALIAS)`)

Inside `classify_into` (`scholatex-style.lua:155-205`), when `S.resolve(w)` returns nil **and** `alias[w]` is non-nil, the function **recurses** with the alias body:

```lua
elseif alias[w] then
  classify_into(alias[w], alias, buckets)
```

Because aliases are flattened at **registration time** by `S.resolve_styles` (`scholatex-style.lua:232-240`) into a flat list of resolvable keywords, the recursion is effectively one level deep and always succeeds (modulo the counter-routing caveat in § 2.1).

**Order semantics**: alias contents are spliced **in place** at the position of the alias word. So `<title 14pt>` where `let title = <Red b>` resolves as if the user had written `<Red b 14pt>` — colour, weight, then size. This matters for the bucket assignment: `Red` and `b` land in `wrap`, `14pt` also lands in `wrap`, all preserving user-typed order.

**Registration vs use time**:

- At **registration** (`scholatex.lua:557` for `let X = <BLOCK ...>` dual-write, `scholatex.lua:561` for plain `let X = <...>`): `STYLE.resolve_styles(words, ALIAS)` validates each word against `S.resolve` or an existing `ALIAS[w]` and inlines nested aliases. Raises `scholatex: unknown style in alias: '<word>'` on the first miss.
- At **use** (every tag/block emission that consults the vocabulary): `STYLE.classify_split(words, ALIAS)` runs the bucket logic, recursing into alias bodies only when the resolver fails first.

### 5. `S.resolve(word)` return shape

`S.resolve(word)` returns one of these tables, or `nil` (`scholatex-style.lua:136-142`):

| `kind` | Other fields | Source line |
|---|---|---|
| `counter` | `cmd` (the LaTeX counter command, e.g. `\arabic`) | `scholatex-style.lua:46-48` |
| `font` | (no extra; caller composes the name from this and subsequent all-caps words) | `scholatex-style.lua:53-55` |
| `color` | `open` (`\textcolor{NAME}{`), `close` (`}`) | `scholatex-style.lua:60-62` |
| `style` | `open`, `close` (copied from `S.STYLE` entry) | `scholatex-style.lua:67-69` |
| `align` | `cmd` (e.g. `\centering`) | `scholatex-style.lua:74` |
| `section` | `cmd` (e.g. `\section`) | `scholatex-style.lua:79` |
| `size` | `pt` (numeric string) | `scholatex-style.lua:84-85` |
| `page` | (no extra) | `scholatex-style.lua:90` |
| `break` | (no extra) | `scholatex-style.lua:95` |
| `lines` | `n` (numeric string) | `scholatex-style.lua:103, 109` |
| `tab` | `n` (numeric string) | `scholatex-style.lua:119-120` |
| `up` | `mm` (numeric string) | `scholatex-style.lua:125-126` |
| `down` | `mm` (numeric string) | `scholatex-style.lua:131-132` |

Pre-built `open` / `close` strings exist only for `color` and `style`; every other kind carries a `cmd` or numeric field, and the caller (`classify_into` for the general case, `scholatex-section.lua:68-88` for the section block) assembles the wrapper.

### 6. `EMIT_ORDER` is declared but unused

`scholatex-style.lua:153`:

```lua
local EMIT_ORDER = {"page", "lines", "section", "align", "wrap"}
```

This constant is **never read**. `S.classify_split` hard-codes the outer-bucket walk order at `scholatex-style.lua:217` as `{"page", "lines", "section", "align"}` — the same first four entries of `EMIT_ORDER`. The `EMIT_ORDER` name appears in the documentation comment above (`scholatex-style.lua:144-151`) but the value is never consulted at runtime.

This is documentation-only and would deserve either wiring up or deletion in a future refactor — recorded as a doc-gap pointer (see `memory/doc-gaps.md`).

## Sources of Truth

- `scholatex-style.lua:1` — `local S = {}`.
- `scholatex-style.lua:7-11` — the six `S.STYLE` entries (`b i u emph sf sc`).
- `scholatex-style.lua:14` — the 151-entry `S.CSS` table.
- `scholatex-style.lua:16` — `S.ALIGN` (`l c r j`).
- `scholatex-style.lua:17` — `S.SECTION` (`section subsection subsubsection`).
- `scholatex-style.lua:40-134` — the 13-matcher `MATCHERS` list.
- `scholatex-style.lua:136-142` — `S.resolve`.
- `scholatex-style.lua:153` — the unused `EMIT_ORDER` constant.
- `scholatex-style.lua:155-205` — `classify_into` (bucket assignment, alias recursion, lowercase-colour hint).
- `scholatex-style.lua:213-221` — `S.classify_split`.
- `scholatex-style.lua:223-229` — `S.classify_words` (variant used by `scholatex-list.lua:51`).
- `scholatex-style.lua:232-240` — `S.resolve_styles` (registration-time flattener).
- `scholatex.lua:154` — the single call from `emit_tag` into `STYLE.classify_split`.
- `scholatex-section.lua:69-71` — the cross-module routing that gives counter words their meaning.

## Known issues

These touch the style vocabulary but are catalogued centrally in `memory/doc-gaps.md`.

- **No strikethrough word.** `s` is not in `S.STYLE`. No overline, no double-underline, no wave-underline. Anything beyond `b i u emph sf sc` requires registering a new style or wrapping in raw LaTeX (which the closed body language does not allow). Recorded in `memory/doc-gaps.md` § "Undocumented surfaces".
- **`EMIT_ORDER` is dead.** Declared at `scholatex-style.lua:153`, never read. The hard-coded list at `scholatex-style.lua:217` is the actual contract.
- **Counter words are not classified by `classify_into`.** Matcher #1 returns `kind = "counter"` (`scholatex-style.lua:46-48`), but `classify_into` (`scholatex-style.lua:155-205`) has no branch for that kind. The counter vocabulary only works because `scholatex-section.lua:69-71` intercepts the words before they reach the generic classifier. A free-standing `<num>...` outside a section block raises `unknown tag attribute: 'num'`. Recorded in `memory/doc-gaps.md`.
- **Lowercase-colour hint only fires for one-word colours.** `classify_into:196` capitalises only the first letter (`^%l`); `darkgray` becomes `Darkgray`, which is not in `S.CSS` (the CamelCase form is `DarkGray`). Multi-word lowercase colour names give the generic `unknown tag attribute` error instead of the helpful CamelCase hint.

See `memory/doc-gaps.md` for the rolling list of doc-vs-code drifts that touch the style surface.
