# Tags and Blocks Reference

## Scope

This document is the exhaustive inventory of every registered tag and block in
scholatex. It is the single source of truth for the user-visible contract
surface: "is `<X>` a real tag?" is answered against this file.

A tag or block counts here **only** when a module calls `sl.register_tag` or
`sl.register_block`. Three classes of name look like tags but are not:

- **Style words** (e.g. `b`, `i`, `Navy`, `c`, `nextline`, `tab`, `Npt`) are
  resolved by `STYLE.resolve` (`scholatex-style.lua`), not by tag registration.
  See `reference/text-style-vocabulary.md`.
- **Math operators** (e.g. `sin`, `vec`, `int`, `angle`, `triangle`,
  `circle`) live in the `mathlite` tables (`scholatex-math.lua`) and fire only
  inside `$ ... $`. See `reference/math-vocabulary.md` and
  `reference/math-geometry-vocabulary.md`.
- **Transpiler-recognised constructs** that are parsed in `scholatex.lua`
  itself, not registered as tags — currently `<fn>` (recognised only on a
  `let X = <fn ...>` line; see `reference/fn-object-schema.md`).

`<draw>` shapes are catalogued in `reference/draw-shape-catalogue.md`; this
document lists `<draw>` itself once, as a single registration.

## Inventory

Every `sl.register_tag` / `sl.register_block` call in scholatex 2.3 (HEAD
`ebec138`):

| Name              | Kind  | Module + line                         | Required args             | Optional args / attributes                                                                                                                                | LaTeX target                                                          |
|-------------------|-------|---------------------------------------|---------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| `box`             | block | `scholatex-box.lua:94`                | — (body)                  | placement code (`tl`...`br`); `line:`, `fill:`, `text:`, `boxrule:`, `sep:`, `radius:`, `width:`, `height:`, `break:`, `title:`, `titlefill:`, `titletext:` | `\begin{tcolorbox}[enhanced, ...] ... \end{tcolorbox}` (with optional `\tcblower` if body contains `---`) |
| `row`             | block | `scholatex-box.lua:126`               | — (body of `<box>` etc.)  | `gap:N`                                                                                                                                                   | `\begin{tcbraster}[raster columns=N, raster equal height, ...] ... \end{tcbraster}` |
| `grid`            | block | `scholatex-grid.lua:128`              | `template:[...]`          | placement code (default cell alignment); `gap:`, `width:`, `height:`                                                                                       | `\Needspace*` + `\begin{minipage}` + `\begin{tcbposter}[...]` + `\posterbox`-per-area + `\end{tcbposter}` + `\end{minipage}\par` |
| `list`            | block | `scholatex-list.lua:43`               | `:<style>` (in tag head)  | bare style words wrap the whole list                                                                                                                       | `\begin{itemize}[label=..., leftmargin=*, nosep]` or `\begin{enumerate}[label=..., leftmargin=*, nosep]` |
| `section`         | block | `scholatex-section.lua:48` (loop)     | `title:{...}`             | counter style (`num`/`roman`/`ROMAN`/`alpha`/`ALPHA`); colour, style, `Npt`, `line`/`Nlines`                                                                | optional `\renewcommand{\thesection}{...}` + optional `\vspace*` + `\section{...}` + nested body |
| `subsection`      | block | `scholatex-section.lua:48` (loop)     | `title:{...}`             | same as `section`                                                                                                                                          | `\subsection{...}`                                                    |
| `subsubsection`   | block | `scholatex-section.lua:48` (loop)     | `title:{...}`             | same as `section`                                                                                                                                          | `\subsubsection{...}`                                                 |
| `table`           | block | `scholatex-table.lua:141`             | `[col1, col2, ...]`       | `borders`, `header`/`headers`, `gap:N`, `fill:`, `line:`, `text:`, `headerfill:`, `headertext:`                                                             | `\begin{tblr}{...} ... \end{tblr}` (from `tabularray`)                 |
| `matrix`          | block | `scholatex-matrix.lua:68` (loop)      | — (body)                  | none (rejects all options)                                                                                                                                 | `\[\begin{pmatrix}...\end{pmatrix}\]` (or `\left( ... \begin{array} ... \right)` when an augmentation `|` is present) |
| `det`             | block | `scholatex-matrix.lua:68` (loop)      | — (body)                  | none (rejects all options and `|` augmentation)                                                                                                            | `\[\begin{vmatrix}...\end{vmatrix}\]`                                  |
| `bmatrix`         | block | `scholatex-matrix.lua:68` (loop)      | — (body)                  | none (rejects all options)                                                                                                                                 | `\[\begin{bmatrix}...\end{bmatrix}\]` (or augmented `array` form)      |
| `system`          | block | `scholatex-matrix.lua:127`            | — (body)                  | none                                                                                                                                                       | `\[\left\{\begin{array}{r@{\;}c@{\;}l}...\end{array}\right.\]`         |
| `draw`            | tag + block | `scholatex-figure.lua:837, 853`  | shape definition          | `marks:on/off`, `measures:off/cm/mm`, `labels:off`, `rotate:`                                                                                               | `\begin{center}\begin{tikzpicture}[line width=0.5pt] ... \end{tikzpicture}\end{center}` |
| `figure`          | tag + block | `scholatex-figure.lua:837, 853`  | same as `draw`            | same as `draw`                                                                                                                                              | same as `draw` — **alias** (see § "Aliases and surprises")            |
| `vartab`          | tag   | `scholatex-vartab.lua:409`            | object name, or `x:{...}` + `var:{...}` inline | `name:{...}`, `deriv:{...}`, `second:{...}`                                                                                                              | `\begin{center}\begin{tikzpicture}\tkzTabInit[...] \tkzTabLine{...} \tkzTabVar{...}\end{tikzpicture}\end{center}` (from `tkz-tab`) |
| `plot`            | tag   | `scholatex-plot.lua:105`              | object name (`_ref`)      | `x:{a,b}`, `y:{c,d}`, `samples:N` (default 100)                                                                                                            | `\begin{center}\begin{tikzpicture}\begin{axis}[...] \addplot[...]{body};\end{axis}\end{tikzpicture}\end{center}` (from `pgfplots`) |
| `img`             | tag   | `scholatex-img.lua:4`                 | filename (content)        | `N` (mm width) or `NxM` (mm width × mm height + `keepaspectratio`)                                                                                          | `\includegraphics[<opt>]{<filename>}`                                  |
| `tableofcontents` | tag   | `scholatex-toc.lua:4`                 | — (optional title content)| —                                                                                                                                                          | `\renewcommand{\contentsname}{}` + optional centred title + `\tableofcontents\newpage` |

`<area>` is **not** a top-level registration — it is parsed inline inside the
`<grid>` body (`scholatex-grid.lua:90-125`) and rejected outside. See § "`<grid>` and `<area>`".

## Per-block reference

### `<box>` (`scholatex-box.lua:94`)

Frame builder over `tcolorbox`. Options resolved in `parse_opts`
(`scholatex-box.lua:18-29`) and `build_tcb_options` (`scholatex-box.lua:31-87`).

Minimal input:

```
<box line:Crimson fill:MistyRose radius:4 title:{Key identity}>{
  body
}
```

Emits (approximately):

```latex
\begin{tcolorbox}[enhanced, colframe=Crimson, colback=MistyRose,
                  boxrule=0.4mm, boxsep=2mm, left=0mm, right=0mm,
                  top=0mm, bottom=0mm, rounded corners, arc=4mm,
                  unbreakable, colbacktitle=Crimson,
                  title={Key identity}]
body
\end{tcolorbox}
```

Defaults (`scholatex-box.lua:4-7`):

| Option   | Default                          | Notes                                                            |
|----------|----------------------------------|------------------------------------------------------------------|
| `line:`  | `Gray`                           | Frame colour (CamelCase CSS name).                               |
| `fill:`  | `White`                          |                                                                  |
| `text:`  | unset                            | When set, emits `coltext=<colour>`.                              |
| `boxrule:` | `0.4` (mm)                     | Frame thickness.                                                 |
| `sep:`   | `sl.config.padding` or `3` (mm)  | Inner padding. `boxsep:` is **silently ignored** — see footnote¹. |
| `radius:`| sharp corners                    | When set, emits `rounded corners, arc=<N>mm`.                    |
| `width:` | full width                       | `N%` → `<coef>\linewidth`; plain `N` → `Nmm`.                    |
| `height:`| natural                          | When set, emits `height=<N>mm`.                                  |
| `break:` | `no` → `unbreakable`             | `yes` → `breakable`.                                              |
| `title:` | no title                         | Forwarded through `forward_text` so it may carry inline tags / math. |
| `titlefill:` / `titletext:` | inherits from `line:` | Title background / title text colour.                       |

Body splitter `---` (`scholatex-box.lua:108-110`): a standalone `---` line
splits the body into upper and lower halves separated by `\tcblower`.

Failure modes:

- Unknown bare word on `<box>`: `scholatex-box.lua:18-29` rejects anything that
  is not a two-letter placement code with a hint about layout attributes
  belonging on the body.
- Unknown colour name: `color_name` → `STYLE.resolve` raises
  `scholatex: unknown frame colour: '<word>'` (`scholatex-box.lua:10-16` →
  `scholatex-style.lua:196-200`).

### `<row>` (`scholatex-box.lua:126`)

Wraps N child blocks in a `tcbraster` with equal heights. Only consumes
`gap:` (default `4` mm — `scholatex-box.lua:128`); other `<box>`-style options
parse but are silently ignored².

Body must contain only nested blocks (collected via `U.collect_block`); a
non-tag non-blank line raises `<row> only accepts child blocks`
(`scholatex-box.lua:144-146`).

### `<grid>` and `<area>` (`scholatex-grid.lua:128`)

Named-area layout over `tcbposter`. Requires `template:[ "row" "row" ... ]`
(`scholatex-grid.lua:140-141`).

Areas are recorded in the order they appear inside the `<grid>` body. Each
`<area NAME ...>{...}` records `{lines, opts}` keyed by name
(`scholatex-grid.lua:90-125`). The bounding box of every distinct name is then
verified for rectangularity (`scholatex-grid.lua:69-76`); non-rectangular spans
raise `area '<nm>' is not rectangular`.

`<area>` accepts the **same option vocabulary as `<box>`** through
`sl.box_parse_opts` / `sl.box_build_options` (`scholatex-grid.lua:200-203`),
plus a two-letter placement code (becomes `valign`/`halign` on the
`\posterbox`) and an alignment letter `l`/`c`/`r`/`j` (becomes
`{\raggedright ...\par}` / `{\centering ...\par}` / etc.).

`<area>` outside a `<grid>` body is not registered and falls through to the
unknown-tag path.

### `<list>` (`scholatex-list.lua:43`)

The bullet/number style is required and written `<list:STYLE>` —
`split_style` (`scholatex-list.lua:26-35`) enforces the leading colon. The
ten recognised styles map to `enumitem`'s `label=` option:

| Style     | LaTeX label             | Family    |
|-----------|-------------------------|-----------|
| `none`    | `label={}`              | itemize   |
| `disc`    | `label=$\bullet$`       | itemize   |
| `circle`  | `label=$\circ$`         | itemize   |
| `square`  | `label=$\blacksquare$`  | itemize   |
| `check`   | `label=$\square$`       | itemize (checkbox glyph) |
| `decimal` | `label=\arabic*.`       | enumerate |
| `alpha`   | `label=\alph*)`         | enumerate |
| `ALPHA`   | `label=\Alph*.`         | enumerate |
| `roman`   | `label=\roman*.`        | enumerate |
| `ROMAN`   | `label=\Roman*.`        | enumerate |

The emitted environment always carries `leftmargin=*, nosep`
(`scholatex-list.lua:59-60`). Nested `<list:STYLE>{...}` is detected by
`is_list_open` (`scholatex-list.lua:37-40`) and dispatched recursively. Any
other non-blank line becomes `\item ` followed by `api.forward_text` on the
trimmed line.

Failure mode: unknown style → `scholatex-list.lua:22-23` raises with the full
style list.

### `<section>`, `<subsection>`, `<subsubsection>` (`scholatex-section.lua:48` loop)

All three are registered by the loop over the `LEVEL` table
(`scholatex-section.lua:18-22`). The handler captures the level name and the
matching `\section` / `\subsection` / `\subsubsection` command.

`title:{...}` is **required**: `split_title` (`scholatex-section.lua:26-44`)
extracts it, and a missing title raises
`scholatex: <section> block needs a title:{...} option`
(`scholatex-section.lua:50-52`)³.

Bare words on the option string are classified:

- `kind == "counter"` (`num`/`roman`/`ROMAN`/`alpha`/`ALPHA`, matched at
  `scholatex-style.lua:45-49`) → stored, emits
  `\renewcommand{\the<level>}{<counter_cmd>{<level>}}` with **no inherited
  prefix** (this is the CHANGELOG 2.1 "counter style on its own" behaviour;
  `scholatex-section.lua:93-97`).
- `kind == "style"` / `"color"` → wrap the title text.
- `kind == "size"` (`Npt`) → wrap the title with `\fontsize{<pt>}{<pt*1.2>}\selectfont`.
- `kind == "lines"` (`Nlines`) → emit `\vspace*{N\scholatexline}` before the heading.
- Anything else → error directing the user to put layout words on the body
  (`scholatex-section.lua:82-87`).

After heading emission the inner block content is processed as nested body
(`scholatex-section.lua:104-116`).

### `<table>` (`scholatex-table.lua:141`)

User-facing `tabularray::tblr` wrapper.

Column spec: `[c1, c2, ...]` (`parse_table_opts`, `scholatex-table.lua:64-95`).
Each entry is `code` or `width:code` where `code` is a two-letter placement
code (vertical `t`/`m`/`b` + horizontal `l`/`c`/`r`) and `width` is an integer
in millimetres. A `code` without width becomes an `X`-column (flex); a
`width:code` becomes a `Q`-column of fixed width.

Other options:

- `borders` → emits `hlines, vlines` on the preamble.
- `header` or `headers`⁴ → tags row 1 as a header row.
- `gap:N`, `fill:`, `line:`, `text:`, `headerfill:`, `headertext:`.

Rejected with a hint:

- `radius:`, `title:`, `width:` → `scholatex-table.lua:108-111` directs the
  user to wrap the `<table>` in a `<box>`⁵.

Cell separation: top-level `|` (`split_cells`, `scholatex-table.lua:3-20`).
Inside a cell:

- `<colspan:N hpos>{text}` — N-column span (`SetCell[c=N]{h}` at
  `scholatex-table.lua:218-219`); absorbed columns marked with `.`.
- `<rowspan:N vpos>{text}` — N-row span (`SetCell[r=N]{v}`).
- `.` — absorbed-cell marker (`scholatex-table.lua:23, 216`).
- Literal `\\` in a cell is rewritten to `\newline ` (so `<nextline>` is a
  soft line break, not a row end — `scholatex-table.lua:220, 225, 228`).

### `<matrix>`, `<det>`, `<bmatrix>` (`scholatex-matrix.lua:68` loop)

Three blocks from one loop (`scholatex-matrix.lua:67-68`), driven by the
dispatch table at `scholatex-matrix.lua:4-8`:

| Block      | Math environment | Bar (`|`) allowed |
|------------|------------------|-------------------|
| `<matrix>` | `pmatrix`        | yes (augmented)   |
| `<det>`    | `vmatrix`        | **no**            |
| `<bmatrix>`| `bmatrix`        | yes (augmented)   |

Rows: one per body line. Cells separated by `;` (`split_row` at
`scholatex-matrix.lua:12-35`). Each cell goes through `Math.mathlite`
(`scholatex-matrix.lua:110`).

Augmentation bar (`|` between two cells) is recorded once per row
(`split_row:24-29`); a second bar raises (`scholatex-matrix.lua:82-85`). The
bar must be at the same column index in every row (`scholatex-matrix.lua:104-107`)
and is rejected on `<det>` (`scholatex-matrix.lua:7, 87-90`). When present,
the emission switches to `\left<delim>\begin{array}{c..c|c..c}...\end{array}\right<delim>`
because `pmatrix`/`bmatrix` do not support inline rules
(`scholatex-matrix.lua:114-118`).

No options accepted: `words_str ~= ""` raises
`<matrix> takes no options; put the rows in the body, one row per line, cells
separated by ';'` (`scholatex-matrix.lua:69-72`).

**`<Vmatrix>`, `<Bmatrix>`, `<smallmatrix>` are not registered.** Norms in
expressions are reachable through `norm(...)` in math (`scholatex-math.lua:485-491`).

### `<system>` (`scholatex-matrix.lua:127`)

Aligned equation system. One equation per line, no separator. Each line is
split at the first top-level relational operator (`=` / `<=` / `>=` / etc.;
`scholatex-matrix.lua:45-64`) and aligned by an `array{r@{\;}c@{\;}l}`.

No options accepted: `words_str ~= ""` raises (`scholatex-matrix.lua:128-130`).

### `<draw>` / `<figure>` (`scholatex-figure.lua:837, 853`)

The figure block. `<draw>` and `<figure>` are registered separately by the
`register(name)` helper called twice (`scholatex-figure.lua:887-888`).

Both a tag form (`<draw>triangle ABC equilateral side:5`) and a block form
(`<draw>{ ... }`) are accepted. The shape vocabulary, options, composite-figure
graft, and primitives (`point(...)`, `line(...)`) are catalogued in
`reference/draw-shape-catalogue.md`; the runtime hand-off through
`__drawbuild` is in `architecture/figure-draw.md`.

Global options validated at `build_block` (`scholatex-figure.lua:739-746`):

| Option      | Values                  | Default | Validation site                         |
|-------------|-------------------------|---------|-----------------------------------------|
| `marks:`    | `on` / `off`            | `off`   | `scholatex-figure.lua:742`              |
| `measures:` | `off` / `cm` / `mm`     | `off`   | `scholatex-figure.lua:745`              |
| `labels:`   | (`off` only meaningful) | unset   | unvalidated — see footnote⁶             |
| `rotate:`   | degrees (per figure)    | none    | `scholatex-figure.lua:390` (non-numeric raises) |

### `<vartab>` (`scholatex-vartab.lua:409`)

Variation table over `tkz-tab`. Two argument forms:

- **Object reference:** `<vartab f>` — `f` must be a name defined earlier via
  `let f = <fn ...>`. Dispatch at `scholatex-vartab.lua:419-421`. A name
  with no matching `_objects` entry raises
  `<vartab f> refers to an object that is not defined; write let f = <fn ...> first, or give x:{...} var:{...} inline`
  (`scholatex-vartab.lua:422-425`).
- **Inline attributes:** `<vartab x:{...} var:{...}>` — every attribute is
  re-parsed by `parse_attrs(require_group=true)` (`scholatex-vartab.lua:32-38`).
  Required: `x:`, `var:`. Optional: `name:`, `deriv:`, `second:`. `expr:` is
  accepted but unused (transported through, for `<plot>`).

Four shapes emerge from optional-line presence — see `reference/fn-object-schema.md`
for the schema, and the architecture investigation
`.llmdoc-tmp/investigations/05-functions-tables-data.md` § 2 for the row
construction (always `x`-row plus `f`-row, optionally `f''`-row above `f'`-row).

### `<plot>` (`scholatex-plot.lua:105`)

Function plot over `pgfplots`. Always needs a function-object reference
(`scholatex-plot.lua:111-114`): the first bare word becomes `attrs._ref`
through `on_bare` (`scholatex-plot.lua:7-11`). The object must carry `expr:`
(`scholatex-plot.lua:120-123`).

Inline options:

| Option     | Default            | Effect                                                                 |
|------------|--------------------|------------------------------------------------------------------------|
| `x:{a,b}`  | inferred from `obj.x` (skipping `inf` cells, `scholatex-plot.lua:95`) | x-window. |
| `y:{c,d}`  | inferred           | y-window. **Internally tripled** to `restrict y to domain=3c:3d` (`scholatex-plot.lua:154-156`)⁷. |
| `samples:N`| `100` (`scholatex-plot.lua:135`) | Sample count.                                       |

Pole handling is implicit: `unbounded coords=jump` (`scholatex-plot.lua:159`)
breaks the curve where pgfplots reports an unbounded coordinate; the tripled
y-window combined with that key produces a clean visual gap at the asymptote.

### `<img>` (`scholatex-img.lua:4`)

Emits `\includegraphics[<opt>]{<filename>}`. The filename is the content
(everything between `>` and EOL or `{...}`), trimmed and forwarded literally
(`scholatex-img.lua:18, 35`).

Single optional positional word `words[2]` (the head word `img` is `words[1]`):

| Form          | Emits                                                       |
|---------------|-------------------------------------------------------------|
| `<img>{f}`    | `width=\linewidth`                                          |
| `<img N>{f}`  | `width=Nmm`                                                 |
| `<img NxM>{f}`| `width=Nmm,height=Mmm,keepaspectratio`                      |

Anything else raises `scholatex: invalid image dimension: '<w>' (expected N
or NxM in mm)` (`scholatex-img.lua:6-17`).

Filename interpolation (`#name`, `#{expr}`) is processed at
`scholatex-img.lua:20-34`, so a loop can feed the filename.

Path resolution is fully on the LaTeX side via `\graphicspath`, set from the
class option `imgdir` (`scholatex.cls:34-48`); the module never touches
the filesystem.

### `<tableofcontents>` (`scholatex-toc.lua:4`)

Six lines of business logic. Always:

1. `\renewcommand{\contentsname}{}` — clear the language-dependent default
   heading.
2. If content (between `>` and EOL/`{...}`) is non-empty, emit
   `{\centering\large\bfseries <title>\par}\vspace{\scholatexline}` —
   forwarded through `forward_text`.
3. `\tableofcontents\newpage` — TOC plus a forced page break.

The registered name is **`tableofcontents`**, not `toc`. See § "Aliases and surprises".

## Aliases and surprises

### `<figure>` is a back-compat alias for `<draw>`

`scholatex-figure.lua:888` calls `register("figure")` with the comment
"kept as an alias during the transition". The registrations are independent —
two tag entries and two block entries that happen to dispatch to identical
closures built by the same `register(name)` helper.

**`<figure>` is undocumented in CHANGELOG, in `README.md`, and in
`scholatex.tex`.** Both names work today; future versions may remove `figure`.
See `memory/doc-gaps.md`.

### `<text>` is not a registered tag

There is no `register_tag("text", ...)` call in any module. A literal
`<text>{hello}` falls through `emit_tag` (`scholatex.lua:113-122`):

1. `sl._tags["text"]` → nil.
2. `MACRO["text"]` → nil.
3. `STYLE.resolve("text")` → nil (`scholatex-style.lua:136-142`).
4. `STYLE.classify_into` falls to the else branch and raises
   `scholatex: unknown tag attribute: 'text'` (`scholatex-style.lua:201`).

Users wanting a neutral wrapper typically define an alias such as
`let p = <tab>` and write `<p>{body}`. The `forward_text` function (the
internal text-processing entry) is not exposed as a tag name by design.

### `<toc>` is not registered — the name is `<tableofcontents>`

`scholatex-toc.lua` registers the tag under the LaTeX command name
`tableofcontents` (`scholatex-toc.lua:4`), not under the short module name.
Every example uses `<tableofcontents>` (e.g. `examples/text-style.tex:34`).
A literal `<toc>...` falls through to the unknown-tag path the same way as
`<text>`.

### `<nextline>` is a style word, not a tag

`<nextline>` is matched by `STYLE.resolve` at `scholatex-style.lua:94-96`
(`kind = "break"`) and emits `\newline ` from `classify_into`
(`scholatex-style.lua:164-165`). It is not registered by any module. See
`reference/text-style-vocabulary.md`.

### `<fn>` is parsed by the transpiler, not by a tag

`<fn>` is recognised only inside `let X = <fn ...>` lines, by
`scholatex.lua:467-487` (multi-line) and `scholatex.lua:492-505` (single-line).
The parser callable `sl.fn_parse` lives in `scholatex-vartab.lua:405-407`. A
bare `<fn ...>` outside a `let` falls through to the unknown-tag path. See
`reference/fn-object-schema.md`.

## Cross-references

- `architecture/figure-draw.md` — the runtime hand-off through `__drawbuild`,
  the shape-solver families, the graft algorithm.
- `architecture/math-pipeline.md` — the `mathlite` dispatcher; explains why
  `triangle`, `circle`, `parallelogram` exist in math too, and how the math
  module is invoked from inside `$ ... $` only.
- `reference/draw-shape-catalogue.md` — full `<draw>` shape catalogue with
  required / optional / defaulted attributes per shape.
- `reference/fn-object-schema.md` — the `<fn>` record consumed by `<vartab>`
  and `<plot>`.
- `reference/text-style-vocabulary.md` — `<nextline>`, colours, fonts,
  alignment, tabs, skips.
- `reference/math-vocabulary.md` and `reference/math-geometry-vocabulary.md` —
  the math operators that look like tags but live inside `$ ... $`.
- `memory/doc-gaps.md` — every doc-vs-code drift, including the seven
  user-visible discrepancies referenced as footnotes¹-⁷ below.

---

¹ `<box boxsep:N>` is documented in `README.md:515` and `scholatex.tex:449`
but the code reads only `opts.sep` (`scholatex-box.lua:41`). `boxsep:` parses
into `attrs.boxsep` but is silently ignored. See `memory/doc-gaps.md`
("`<box>` inner padding option").

² `<row>` accepts all `<box>` options through the shared `parse_opts`
(`scholatex-box.lua:127`) but only `gap:` is read. See `memory/doc-gaps.md`
("`<row>` silently accepts all `<box>` options").

³ The block-form `<section title:{...}>{ body }` is documented only in
`scholatex.tex:282-286`; the README shows only the attribute form
`<section>Title`. See `memory/doc-gaps.md` ("Block-form `<section title:{...}>`").

⁴ The `header` / `headers` synonym (`scholatex-table.lua:99`) is
undocumented. See `memory/doc-gaps.md` ("`<table>` accepts `header` or `headers`").

⁵ The `<table>` rejection of `radius:` / `title:` / `width:`
(`scholatex-table.lua:108-111`) is undocumented. See `memory/doc-gaps.md`
("`<table>` rejects `radius:`, `title:`, `width:`").

⁶ `<draw> labels:` accepts any value but only `off` does anything
(`scholatex-figure.lua:733, 751`). A typo like `labels:hide` silently keeps
labels on. See `memory/doc-gaps.md` ("`<draw> labels:` unvalidated").

⁷ `<plot> y:{c,d}` triples bounds internally
(`scholatex-plot.lua:152-156`). No doc mentions the 3× expansion. See
`memory/doc-gaps.md` ("`<plot> y:{c,d}` triples bounds").
