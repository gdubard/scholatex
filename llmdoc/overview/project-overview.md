# Project Overview

## Identity

scholatex is a tag-based authoring layer on top of LuaLaTeX, distributed as a single LaTeX class (`scholatex.cls`) plus a Lua transpiler (`scholatex.lua` and twelve `scholatex-*.lua` modules). It targets the production of print-ready teaching worksheets — exercises, lecture notes, exam sheets, function-study reports — by replacing brittle LaTeX prose-writing with a small, closed, tag-and-attribute language:

- `<h>{Title}`, `<box title:{...} line:Navy>{...}`, `<grid template:[...]>{...}`, `<table [tl, mc, br] borders header>{...}`
- inline `$ ... $` math compiled by a bespoke mini-language (`mathlite`)
- `<draw>{ triangle ABC equilateral side:5 marks:on }` for geometric figures
- `<fn ...>` / `<vartab f>` / `<plot f ...>` for full function-study workflows
- `let` aliases, parametric macros, block aliases, `for` / `if` / `while` control flow

The project is GPL v3 (`LICENSE`, `scholatex.cls:3-10`), authored by Gérard DUBARD, current release `v2.3` dated `2026-06-28` (`scholatex.cls:2`, `CHANGELOG.md:10`).

## Boundaries

scholatex belongs in the document body. Specifically:

- **In scope.** Tag and block syntax that the transpiler parses, the inline `mathlite` mini-language, `let` aliases and macros, control-flow `for`/`if`/`while`, the auto-escape rules for `_ & % ^ ~`, the doubling escapes for `< > { } #`, and every behaviour produced by the `scholatex-*.lua` modules.
- **Out of scope.** The LaTeX preamble (the user only writes `\documentclass{scholatex}`; everything else is the class's job). Raw LaTeX command invocation in prose is also out of scope: backslash is inert in the body and `\command` typed in prose is typeset as text (`CHANGELOG.md:194-197`, `scholatex.lua:233-234`).
- **Closed language by design.** The user cannot extend the syntax from the document itself; extensions happen by adding a new `scholatex-*.lua` module that registers tags and blocks through `sl.register_tag` / `sl.register_block` (`scholatex.lua:15-27`). `untrusted=true` confines all interpolated Lua to a curated sandbox (`scholatex.lua:612-617, 670-687`).

## Major areas

- **cls + core transpiler** (`scholatex.cls`, `scholatex.lua`, `scholatex-util.lua`, `scholatex-style.lua`, `scholatex-math.lua`). Boots LuaLaTeX, loads font/geometry/preamble, runs `\directlua` to read the body from disk, hands it to `sl.transpile` for parse-and-emit, then closes the document. See `architecture/compile-pipeline.md`.
- **Style system** (`scholatex-style.lua`, dispatched by `emit_tag` in `scholatex.lua:113-172`). Resolves attribute words to nested wrappers — colours, fonts, sizes, alignment, vertical skips, scripts, sections. See `architecture/style-and-tags.md` (wave 2).
- **Math mini-language** (`scholatex-math.lua`, called from `forward_text` on `$ ... $`). A recursive-descent compiler that turns a small, expression-oriented surface into the LaTeX it emits. See `architecture/math-pipeline.md`.
- **Figures (`<draw>`)** (`scholatex-figure.lua`). Closed-form solvers for triangles, quadrilaterals, circles, and regular polygons; composite-figure graft over shared points or edges; per-shape mark and measure emission. See `architecture/figure-draw.md`.
- **Function studies (`<fn>`, `<vartab>`, `<plot>`)** (`scholatex-vartab.lua`, `scholatex-plot.lua`). `<fn>` is a parser-level object form (not a tag) parsed by `sl.fn_parse` in `scholatex-vartab.lua`; `<vartab>` and `<plot>` are tags that consume the object. See `architecture/function-studies.md` (wave 2).
- **Containers (`<box>`, `<grid>`, `<list>`)** (`scholatex-box.lua`, `scholatex-grid.lua`, `scholatex-list.lua`). Framed-and-titled boxes, named-area grid layout, multi-style ordered/unordered lists.
- **Sections + images + TOC** (`scholatex-section.lua`, `scholatex-img.lua`, `scholatex-toc.lua`). Heading levels with both attribute and block forms; image embedding with `imgdir` search; `<tableofcontents>` shortcut.
- **Tables and matrices** (`scholatex-table.lua`, `scholatex-matrix.lua`). Compact table syntax with two-letter placement codes, span syntax, augmented-bar matrices, `<system>` for linear systems.

## Version anchors

Two BREAKING migrations are recorded in CHANGELOG. Full migration text lives in `CHANGELOG.md`; the short form:

- **v2.0** (`CHANGELOG.md:190-207`) introduced the closed-language design: backslash inert in body, new doubling escapes (`<<` `>>` `{{` `}}` `##`), `<nextline>` replaces `\\`. The old `\<` `\>` `\{` `\}` `\#` escapes were removed.
- **v2.1** (`CHANGELOG.md:125-188`) made colours CamelCase only. Lowercase colour names (`red`, `navy`, ...) now error with a CamelCase suggestion; the migration sed is at `CHANGELOG.md:181-183`.

Versions 2.2 and 2.3 are "purely additive" (`CHANGELOG.md:58-60, 119-123`). 2.2 added higher-order `d^n y / d x^n` derivatives and extensible parentheses over fractions. 2.3 added the `<draw>` block, the `vector(...)` helper, the math `<triple>` operator, and the in-block `for` / `if` / `while` control flow inside `<draw>`.
