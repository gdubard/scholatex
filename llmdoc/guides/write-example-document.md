# How to Write an Example Document

This guide is for writing or updating an `examples/*.tex` file. Examples are the canonical demonstration corpus; they are the only place readers see the surface vocabulary exercised end-to-end. Existing examples set the tone: terse, labelled, no narrative.

## 1. Preconditions

### Pick a theme

One example per concrete demonstration. Match an existing `examples/*.tex` family rather than inventing new categories:

| Theme | File | What it shows |
|---|---|---|
| Text styling and structure | `examples/text-style.tex` | Styles, colours, fonts, sizes, alignment, tabs/skips, scripts, aliases, TOC |
| Containers and layout | `examples/containers.tex` | Tables, boxes, grid, image dimensions, row of boxes |
| Inline math sampler | `examples/math-language.tex`, `examples/basics.tex` | Number sets, quantifiers, fences, accents, named operators |
| Math analysis | `examples/math-analysis.tex`, `examples/analysis.tex` | Sums, products, limits, derivatives, integrals |
| Math algebra | `examples/math-algebra.tex`, `examples/algebra.tex` | Matrix blocks, named operators (`ker`, `im`, `rank`, ...) |
| Function studies | `examples/functions.tex` | `<fn>` + `<vartab>` + `<plot>`, three-step method |
| Geometry vocabulary | `examples/geometry.tex` | Inline geometry (`angle`, `triangle`, `vec`), `<draw>` block |
| Probability | `examples/probability.tex` | `C`, `A`, `PP`, `EE`, `var`, `cov`, distributions |

Mirror the existing tone: no narrative, just labelled blocks demonstrating the feature. One feature per `<box>` is the typical granularity.

If your feature does not fit any existing theme, create a new file with a one-word name matching the dominant tag (e.g. `examples/<your-feature>.tex`). Then add it to the `README.md` examples table (currently undercounting at "six"/"seven" — see `memory/doc-gaps.md`) and the standalone manual `scholatex.tex`.

## 2. File header

Every example starts with:

```
% !TeX program = lualatex
\documentclass[margins=20, size=12, lang=en]{scholatex}
\begin{document}
...
\end{document}
```

Conventions:

- `% !TeX program = lualatex` — the engine directive. LuaLaTeX is hard-required (`scholatex.cls:86` calls `\directlua`, the entire body is in Lua). `pdflatex` / `xelatex` silently fail with a `fontspec` error.
- `lang=en` for examples that ship internationally. Eleven of twelve current examples use `lang=en`; only `examples/functions.tex` uses the short form. Pick `en` unless your example specifically demonstrates French decimal separators (`MATH.decsep = "{,}"` in default `lang=fr`).
- `margins=20` is the default and may be omitted; explicit is the existing convention.
- `size=12` matches the existing examples; `11` is the class default if omitted.
- For thematically related options: `linespread=1.4` for documents with lots of math (`examples/analysis.tex`, `examples/functions.tex`); `padding=2` is the class default.

## 3. Common idioms

These twelve patterns appear in two or more existing files. Follow them verbatim when you can — readers learn the vocabulary by recognising patterns.

### Heading-style alias trio

The factor-once pattern. Most examples define these near the top:

```
let title = <Red b 18pt c>
let h1    = <Navy b section>
let h2    = <Teal i subsection>
let h3    = <Gray sc subsubsection>
let p     = <tab>
```

Then `<h1>First topic` reaches `<Navy b section>` via the ALIAS table. The `section` keyword carries the level; the rest style the title text.

### Coloured-heading single-tag form (the official `<section>` workaround)

```
let h = <line Navy b section>
```

The `line` prefix injects a vertical skip before the heading. This is the documented workaround for the bare attribute form. See `README.md:133` for the canonical statement.

### Highlighted block

```
<box Navy>{
  some content
}
```

Or with options:

```
<box line:Crimson fill:MistyRose radius:4 title:{Key identity}>{
  body
}
```

Remember the block opener `{` **must end the line** (the regex at `scholatex.lua:402` requires `{` as the last non-whitespace character). A line like `<box Navy>{body}` fails — that goes through the inline tag path and raises `unknown tag attribute: 'box'`.

### `<nextline>` for in-paragraph line breaks

`<nextline>` is a STYLE word (not a tag — `scholatex-style.lua:94-96`) that emits `\newline `. Use it inside table cells, grid areas, and prose where a paragraph break would be too much:

```
Surname: <nextline> First name:
```

Not `\\` — backslash is inert in scholatex prose (`scholatex.lua:233-234` emits `\textbackslash{}` for any `\`).

### Literal-character doubling

The five doublings, all collapsed at emit time inside `forward_text` (`scholatex.lua:236-298`):

- `<<` → literal `<`
- `>>` → literal `>`
- `{{` → literal `{`
- `}}` → literal `}`
- `##` → literal `#`

Use to typeset code-like text or set-builder notation `{{x : x > 0}}` (the outer `{{` and `}}` are the brace escapes; the inner becomes `\{x : x > 0\}`).

### The five auto-escaped characters

Type `_`, `&`, `%`, `~`, `^` raw — they emerge as `\_`, `\&`, `\%`, `\textasciitilde{}`, `\textasciicircum{}` (`scholatex.lua:299-303`). The README:597 lists only four (`_ & % ~`), missing `^`; the standalone manual `scholatex.tex:361` lists all five.

A leading `%` on a line starts a comment (the whole line is dropped at `scholatex.lua:508-515`). To write a literal `%` at line start, escape it as `\%`.

## 4. Adding a new operator demonstration

For a new math operator (a `WRAP1` / `TWOARG` / `NAMED` entry added via `guides/extend-math-vocabulary.md`):

1. Open the corresponding `examples/math-*.tex` family (analysis, algebra, geometry, ...).
2. Add one `<box>` per operator in the existing labelled style:

```
<box>{
  <b>Variance and covariance.<nextline>
  $var(X) = EE(X^2) - EE(X)^2$<nextline>
  $cov(X, Y) = EE(X Y) - EE(X) EE(Y)$
}
```

3. Match the surrounding tone: the box label is `<b>...</b>` plus a brief description, then one or more `$...$` lines. No prose paragraphs — that is `scholatex.tex` (the manual) territory.

For a new layout / structural feature, place the demonstration in `examples/containers.tex` or `examples/text-style.tex` depending on which is closer in domain.

For a new `<draw>` shape, add to `examples/geometry.tex` near the existing shape demonstrations (`examples/geometry.tex:113-264` is the `<draw>` half).

## 5. Verification

1. `lualatex examples/<name>.tex` once for the body to compile.
2. `lualatex examples/<name>.tex` a second time if you used TOC or cross-references.
3. Visually inspect the PDF: tight margins, no overfull boxes, the new feature renders as expected.
4. Cross-check with `README.md` and `scholatex.tex` — the new feature should appear in at least one user-facing manual surface. If it does not, file a doc-gap entry in `memory/doc-gaps.md` (see the existing § "Inline math geometry vocabulary" for the precedent).
5. If your example exercises an `untrusted=true`-incompatible feature, add `untrusted=true` to the class options and confirm it still compiles. The sandbox bug catalogue is in `architecture/compile-pipeline.md` § 8.

## 6. Common failure points

| Symptom | Cause | Fix |
|---|---|---|
| `unknown tag attribute: 'text'` | Wrote `<text>{...}`. `text` is not a registered tag and not a style word | Plain text needs no wrapper; or use `<b>{...}` for bold, `<p>{...}` if you `let p = <tab>` |
| `unknown tag attribute: 'box'` | Wrote `<box ...>{...}` on a single line. Block opener regex requires `{` at end of line | Split: `<box ...>{` on its own line, body, `}` on its own line |
| `'red' is not a colour; colours are written in CamelCase now -- use 'Red'` | Lowercase colour name from pre-2.1 syntax | Rename to CamelCase. Only single-word colours get the hint — multi-word lowercase (`darkgray`) falls through to `unknown tag attribute` |
| Image not found | `imgdir` does not include the directory holding the file | Add to class option: `imgdir={img, IMAGES/PNG}` (comma-separated). `./` is always searched first |
| `% !TeX program = lualatex` ignored | The editor's TeX directive comment is parsed by the editor, not by LuaLaTeX. If the user invokes `pdflatex examples/...`, the directive does not save them | Document the engine requirement in the example's comments or rely on the user reading `README.md:111` |
| Body silently truncates after the seventh character `\end{document}` | Class extracts the body with non-greedy regex `\begin{document}(.-)\end{document}` (`scholatex.cls:139`). A literal `\end{document}` in prose triggers early termination | Avoid the seven literal characters. No documented escape |

## 7. Related docs

- `reference/body-syntax-rules.md` — escape rules, auto-escaped characters, doubling, block-opener requirements.
- `reference/tags-and-blocks.md` — the catalogue of every registered tag and block with options.
- `reference/text-style-vocabulary.md` — the full style word catalogue.
- `memory/doc-gaps.md` — known undocumented surfaces to know what to exercise (and what is risky to demonstrate without a doc backing it up).
