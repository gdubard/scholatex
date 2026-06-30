# Math Geometry Vocabulary Reference

## Scope

This document catalogues the inline-math geometry operators that live in `scholatex-math.lua` and are reached **only** by writing them inside a `$ ... $` span. They are part of the `mathlite` mini-language; see `architecture/math-pipeline.md` for the dispatcher and tokeniser. The general (non-geometry) vocabulary is in `reference/math-vocabulary.md`.

This vocabulary exists as its own reference document because **none of it is documented in `README.md` or `scholatex.tex`** outside the example file `examples/geometry.tex`. A user who has not opened that example cannot discover any of `angle()`, `triangle()`, `frame()`, `circle()` (math form), `vector()`, `colvec()`, `triple()`, `collinear()`, `inner()`, `distance()`, `midpoint()`, `orthogonalprojection()`, `ortho()`, `rightangle`, `parallelogram` (math relation), `nparallel`, `cong`, `sim`, `perp`, `parallel`, `perpendicular`, `congruent`, `similar`, `vec(u).vec(v)`, `vec(u)^vec(v)`, or the degree-sign literal `°`. See `memory/doc-gaps.md` § "Inline math geometry vocabulary" for the consolidated gap.

These names are **distinct from the `<draw>` block** (`reference/draw-shape-catalogue.md`, wave 2). Three names exist in both worlds — disambiguate by surrounding context (see § "Disambiguation" below).

## Catalogue

Each row gives the source word as the user types it inside `$ ... $`, the arity, the table or arm the dispatcher consults, the LaTeX it emits, an example use, and whether the name appears anywhere outside this file. Source: `examples/geometry.tex` and the bespoke arms / table entries in `scholatex-math.lua`.

| name | arity | source dispatch | LaTeX template | example | doc'd outside this file? |
|---|---|---|---|---|---|
| `angle(A)` / `angle(ABC)` | 1 (parenthesised) | bespoke arm `scholatex-math.lua:363-366` | `\widehat{A}` / `\widehat{ABC}` | `examples/geometry.tex:29, 30, 100` | No |
| `angle` (bare, no `(`) | error path | `scholatex-math.lua:368-370` | raises `scholatex: angle s'utilise avec des points : angle(A) ou angle(ABC)` (French) | n/a — error path | No |
| `triangle(ABC)` | 1 (parenthesised) | bespoke arm `scholatex-math.lua:373-376` | `\bigtriangleup ABC` | `examples/geometry.tex:94` | No (`<draw>` shape collision — see § Disambiguation) |
| `arc(AB)` | 1 (parenthesised) | bespoke arm `scholatex-math.lua:379-382` | `\overparen{AB}` | `examples/geometry.tex:95` | No |
| `frame(O, i, j, ...)` | >= 3 | bespoke arm `scholatex-math.lua:386-398` | `\left(O, \overrightarrow{i}, \overrightarrow{j}[, ...]\right)` — origin first, every subsequent argument arrowed | `examples/geometry.tex:90, 92` | No |
| `orthoframe(O, i, j, ...)` | >= 3 | bespoke arm `scholatex-math.lua:446-458` | identical to `frame` (separate name for orthogonal-frame intent) | `examples/geometry.tex:99` | No |
| `circle(O, r)` | exactly 2 | bespoke arm `scholatex-math.lua:403-413` | `\mathcal{C}\left(O, r\right)` (centre + radius) | `examples/geometry.tex:96` | No (`<draw>` shape collision) |
| `circle(A, B, C)` | exactly 3 | bespoke arm `scholatex-math.lua:403-413` | `\mathcal{C}\left(A, B, C\right)` (three-point circle) | `examples/geometry.tex:97` | No |
| `vector(x, y, ...)` | >= 2 | bespoke arm `scholatex-math.lua:417-427` | `\left(x, y[, z, ...]\right)` | `examples/geometry.tex:106, 107` | No |
| `colvec(x, y, ...)` | >= 2 | bespoke arm `scholatex-math.lua:430-441` | `\begin{pmatrix}x \\ y[ \\ z]\end{pmatrix}` | `examples/geometry.tex:107` | No |
| `triple(u, v, w)` | exactly 3 | bespoke arm `scholatex-math.lua:591-601` | `\left[\overrightarrow{u}, \overrightarrow{v}, \overrightarrow{w}\right]` (scalar triple product) | `examples/geometry.tex:79` | No |
| `vec(arg)` | 1 (parenthesised) | `ACCENT` table `scholatex-math.lua:110`, dispatcher `scholatex-math.lua:462` | `\overrightarrow{arg}` | `examples/geometry.tex:51, 52, ...` | Partial — `vec(AB)` is in the README master math table (`README.md:240`) and `scholatex.tex:661`. The dot/cross-product postfix extension below is **not** documented |
| `vec(u) . vec(v)` | 2 vecs joined by `.` | postfix infix detection inside the `ACCENT` arm `scholatex-math.lua:466-477` | `\overrightarrow{u} \cdot \overrightarrow{v}` | `examples/geometry.tex:52, 58, 59, 82` | No |
| `vec(u) ^ vec(v)` | 2 vecs joined by `^` | postfix infix detection inside the `ACCENT` arm `scholatex-math.lua:466-477` | `\overrightarrow{u} \wedge \overrightarrow{v}` | `examples/geometry.tex:52` | No |
| `ortho(F)` | 1 | `WRAP1` table `scholatex-math.lua:162`, dispatcher `scholatex-math.lua:528` | `F^{\perp}` (orthogonal complement) | `examples/geometry.tex:77` | No |
| `collinear(u, v)` | exactly 2 | `TWOARG` table `scholatex-math.lua:179`, dispatcher `scholatex-math.lua:608` | `\overrightarrow{u} \mathbin{/\!/} \overrightarrow{v}` | `examples/geometry.tex:62, 83` | No |
| `inner(u, v)` | exactly 2 | `TWOARG` table `scholatex-math.lua:180`, dispatcher `scholatex-math.lua:608` | `\left\langle u, v\right\rangle` | `examples/geometry.tex:76` | No (the same glyph is reached via `abr(u, v)` in `FENCE`, documented in `README.md:279`) |
| `distance(A, B)` | exactly 2 | `TWOARG` table `scholatex-math.lua:181`, dispatcher `scholatex-math.lua:608` | `d\left(A, B\right)` | `examples/geometry.tex:69` | No |
| `midpoint(A, B)` | exactly 2 | `TWOARG` table `scholatex-math.lua:182`, dispatcher `scholatex-math.lua:608` | `I_{AB}` — the two arguments are concatenated into the subscript | `examples/geometry.tex:70` | No |
| `orthogonalprojection(F, x)` | exactly 2 | `TWOARG` table `scholatex-math.lua:183`, dispatcher `scholatex-math.lua:608` | `p_{F}\left(x\right)` | `examples/geometry.tex:78` | No |
| `perp` | 0 | `SYM` table `scholatex-math.lua:69`, dispatcher `scholatex-math.lua:729` | `\perp ` | `examples/geometry.tex:44, 63` | No |
| `perpendicular` | 0 | `SYM` table `scholatex-math.lua:70`, dispatcher `scholatex-math.lua:729` | `\perp ` (alias of `perp`) | untested in examples | No |
| `parallel` | 0 | `SYM` table `scholatex-math.lua:69`, dispatcher `scholatex-math.lua:729` | `\mathbin{/\!/}` | `examples/geometry.tex:43` | No |
| `nparallel` | 0 | `SYM` table `scholatex-math.lua:72`, dispatcher `scholatex-math.lua:729` | `\mathbin{/\!/\mkern-12.5mu\backslash}` | untested in examples (the example uses `!parallel` instead, same glyph) | No |
| `rightangle` | 0 | `SYM` table `scholatex-math.lua:71`, dispatcher `scholatex-math.lua:729` | `\rightangle ` — macro provided by `scholatex.cls` | `examples/geometry.tex:95` | No |
| `parallelogram` | 0 | `SYM` table `scholatex-math.lua:71`, dispatcher `scholatex-math.lua:729` | `\scholatexparallelogram ` — macro provided by `scholatex.cls` | `examples/geometry.tex:95` | No (`<draw>` shape collision) |
| `cong` | 0 | `SYM` table `scholatex-math.lua:62`, dispatcher `scholatex-math.lua:729` | `\cong ` | `examples/geometry.tex:45` | No |
| `congruent` | 0 | `SYM` table `scholatex-math.lua:63`, dispatcher `scholatex-math.lua:729` | `\cong ` (alias of `cong`) | untested in examples | No |
| `sim` | 0 | `SYM` table `scholatex-math.lua:62`, dispatcher `scholatex-math.lua:729` | `\sim ` | `examples/geometry.tex:45` | No |
| `similar` | 0 | `SYM` table `scholatex-math.lua:63`, dispatcher `scholatex-math.lua:729` | `\sim ` (alias of `sim`) | untested in examples | No |
| `!parallel` | 0 (prefix) | `NEG` table `scholatex-math.lua:87`, dispatcher `scholatex-math.lua:781-786` | `\mathbin{/\!/\mkern-12.5mu\backslash}` | `examples/geometry.tex:44` | Partial — the general `!`-prefix rule is in `README.md:264` and `scholatex.tex:702-706`, but `!parallel` is not in the curated examples |
| `!cong` | 0 (prefix) | `NEG` table `scholatex-math.lua:86`, same dispatcher | `\ncong ` | untested in examples | Partial (as `!parallel`) |
| `!sim` | 0 (prefix) | `NEG` table `scholatex-math.lua:86`, same dispatcher | `\nsim ` | untested in examples | Partial (as `!parallel`) |
| `°` (UTF-8 U+00B0) | 0 (literal) | top-level loop `scholatex-math.lua:779-780` | `^{\circ}` | `examples/geometry.tex:100` (`$angle(ABC) = 90°$`) | No |

Argument-count validation — wrong-arity calls raise clear errors:

- `frame(O, ...)` / `orthoframe(O, ...)` with fewer than 3 args: error at `scholatex-math.lua:390-393, 450-453` (English).
- `circle(...)` not exactly 2 or 3 args: `scholatex: circle takes circle(O, r) (centre, radius) or circle(A, B, C) (three points); got N argument(s)` (`scholatex-math.lua:407-410`, English).
- `vector(...)` / `colvec(...)` with fewer than 2 components: `scholatex-math.lua:421-423, 434-436` (English).
- `triple(u, v, w)` not exactly 3 args: `scholatex-math.lua:595-598` (English).
- `angle` with no parenthesis: French error at `scholatex-math.lua:369`.
- `TWOARG` keys (`collinear`, `inner`, `distance`, `midpoint`, `orthogonalprojection`) called with the wrong arity **silently** fall back to a verbatim function-call form `word .. "(" .. M.mathlite(raw) .. ")"` (`scholatex-math.lua:610-612`). So `collinear(u, v, w)` renders as `collinear(u, v, w)` with no error — a footgun.

## Disambiguation

Three names exist in both the inline-math vocabulary and the `<draw>` shape catalogue. The dispatcher is the surrounding context — a name inside `$ ... $` is a math operator; the same name as the first non-whitespace word of a `<draw>{ ... }` body line is a draw shape.

| name | math meaning (inside `$ ... $`) | draw meaning (inside `<draw>{ ... }`) |
|---|---|---|
| `triangle` | math operator: `triangle(ABC)` → `\bigtriangleup ABC` (`scholatex-math.lua:373-376`) | draw shape: `triangle ABC equilateral side:5 ...`, dispatched at `scholatex-figure.lua:289-341`. Accepts `equilateral`, `isosceles`, `right`, `sides:(a,b,c)`, `sides:(a,b) angle:t`, `angles:(A,B) side:c`, named-side `AB:3 BC:4 CA:5` |
| `circle` | math operator: `circle(O, r)` or `circle(A, B, C)` → `\mathcal{C}\left(...\right)` (`scholatex-math.lua:403-413`) | draw shape: `circle O radius:3`, `circle O diameter:6`, `circle ABC` (circumscribed), `circle ABC inscribed` (incircle), dispatched at `scholatex-figure.lua:235-286` |
| `parallelogram` | math relation: bare keyword → `\scholatexparallelogram ` (no arguments) (`scholatex-math.lua:71`) | draw shape: `parallelogram ABCD sides:(a,b) angle:t`, dispatched at `scholatex-figure.lua:355-359` |

Other draw shapes (`square`, `rectangle`, `rhombus`, `trapezoid`, `kite`, `polygon`, `pentagon`, `hexagon`, `octagon`) have **no** math counterpart. Conversely, the rest of this catalogue (`frame`, `orthoframe`, `arc`, `angle`, `vector`, `colvec`, `triple`, `collinear`, `inner`, `distance`, `midpoint`, `ortho`, `orthogonalprojection`, `rightangle`, `perp`, `nparallel`, `cong`, `sim`, ...) exists **only** as math operators.

## Vector and frame helpers

The `vec` accent (`ACCENT` table at `scholatex-math.lua:110`) is the over-arrow primitive: `vec(u)` → `\overrightarrow{u}`. It is also the entry point for the only infix shortcut in the language.

### The `vec(u) . vec(v)` and `vec(u) ^ vec(v)` postfix infix

When the `ACCENT` arm dispatches on `vec`, it inspects what follows the closing `)` (`scholatex-math.lua:466-481`). If the next non-whitespace character is `.` or `^` and that is itself followed by another `vec(...)` call, the arm emits the binary form directly:

- `vec(u) . vec(v)` → `\overrightarrow{u} \cdot \overrightarrow{v}` — dot product.
- `vec(u) ^ vec(v)` → `\overrightarrow{u} \wedge \overrightarrow{v}` — cross / wedge product.

A bare `^` after `vec(u)` (no `vec(...)` on the right) reverts to ordinary script raising — so `vec(u)^2` stays a power. A bare `.` after `vec(u)` (no `vec(...)` on the right) is treated as ordinary punctuation and emitted as a literal `.` — **no error**, even though the user almost certainly meant `\cdot`.

### Frame builders

| name | arity | LaTeX template | source line |
|---|---|---|---|
| `vector(x, y[, z, ...])` | >= 2 | `\left(x, y[, z, ...]\right)` | `scholatex-math.lua:417-427` |
| `colvec(x, y[, z])` | >= 2 | `\begin{pmatrix}x \\ y[ \\ z]\end{pmatrix}` | `scholatex-math.lua:430-441` |
| `triple(u, v, w)` | exactly 3 | `\left[\overrightarrow{u}, \overrightarrow{v}, \overrightarrow{w}\right]` | `scholatex-math.lua:591-601` |
| `frame(O, i, j[, k, ...])` | >= 3 | `\left(O, \overrightarrow{i}, \overrightarrow{j}[, ...]\right)` — origin first, all subsequent args arrowed | `scholatex-math.lua:386-398` |
| `orthoframe(O, i, j[, k, ...])` | >= 3 | identical to `frame` — kept as a distinct word for orthogonal-basis intent | `scholatex-math.lua:446-458` |

## Relation symbols

The forward (non-negated) relation symbols all live in `SYM` (`scholatex-math.lua:62-72`) and dispatch through the `SYM` arm (`scholatex-math.lua:729`).

| name | LaTeX template | source line | notes |
|---|---|---|---|
| `perp` | `\perp ` | 69 | |
| `parallel` | `\mathbin{/\!/}` | 69 | |
| `perpendicular` | `\perp ` | 70 | alias of `perp` |
| `rightangle` | `\rightangle ` | 71 | macro provided by `scholatex.cls` |
| `parallelogram` | `\scholatexparallelogram ` | 71 | macro provided by `scholatex.cls`; bare keyword, no arguments |
| `nparallel` | `\mathbin{/\!/\mkern-12.5mu\backslash}` | 72 | struck-through `//` — same glyph as `!parallel` |
| `cong` | `\cong ` | 62 | congruent |
| `sim` | `\sim ` | 62 | similar |
| `congruent` | `\cong ` | 63 | alias of `cong` |
| `similar` | `\sim ` | 63 | alias of `sim` |

The LaTeX macros `\rightangle` and `\scholatexparallelogram` are not in the AMS or LaTeX kernel — they are provided by the scholatex runtime (`scholatex.cls`).

## Negated forms

Geometry-flavoured negations live in `NEG` (`scholatex-math.lua:86-87`); the dispatcher is the `!`-prefix arm at `scholatex-math.lua:781-795`.

| source | LaTeX template | source line | notes |
|---|---|---|---|
| `!parallel` | `\mathbin{/\!/\mkern-12.5mu\backslash}` | 87 | same glyph as bare `nparallel` (`scholatex-math.lua:72`); the example file uses `!parallel` |
| `!cong` | `\ncong ` | 86 | amssymb native glyph |
| `!sim` | `\nsim ` | 86 | amssymb native glyph |

A `!` in front of any other `SYM` word falls back to `\not<symbol>` (`scholatex-math.lua:787-790`), so `!perp` is technically legal and emits `\not\perp ` — but it is **not** in the curated `NEG` table and the resulting glyph is visually weaker than the native amssymb forms above.

## Degree literal

The UTF-8 degree sign `°` (U+00B0, bytes `\194\176`) is intercepted in the top-level loop at `scholatex-math.lua:779-780`, before the word lookup. It emits `^{\circ}` — a script-style superscript circle, not a standalone glyph. Used in geometry expressions like `45°` or `$angle(ABC) = 90°$` (`examples/geometry.tex:99-100`).

## Known issues

The entire geometry surface is currently undocumented in `README.md` and `scholatex.tex`; `examples/geometry.tex` is the sole user-visible source of truth. See `memory/doc-gaps.md` § "Inline math geometry vocabulary" for the consolidated gap list, including:

- `nparallel`, `perpendicular`, `congruent`, `similar`, `!cong`, `!sim` have no exercise in any example file.
- `midpoint(A, B)` concatenates its arguments into the subscript (`I_{AB}`), which is fine for two-letter point names but produces oddities like `I_{P_1P_2}` for multi-character arguments — no example tests this edge case.
- `vec(u) . v` (no `vec(...)` on the right) is silently emitted as `\overrightarrow{u} . v` with a literal dot — no error, no `\cdot`. Users expecting the dot-product shortcut have to remember the `vec(...)` requirement on both sides.
- The French error message for bare `angle` (`scholatex-math.lua:369-370`) is the only French-language validator left in `scholatex-math.lua`; all other geometry validators are in English.
- `TWOARG` geometry keys (`collinear`, `inner`, `distance`, `midpoint`, `orthogonalprojection`) called with the wrong arity silently fall back to a verbatim function-call form — no error (`scholatex-math.lua:610-612`).

## See also

- `reference/draw-shape-catalogue.md` (wave 2) — the `<draw>` block shape catalogue, including the three names that collide with this vocabulary (`triangle`, `circle`, `parallelogram`).
- `reference/math-vocabulary.md` — the general inline-math vocabulary (number sets, quantifiers, integrals, linear algebra, transforms, ...).
- `architecture/math-pipeline.md` — the `mathlite` compiler, the dispatcher tables, the script-vs-fraction precedence, the ISO 80000-2 upright-d rule, and the `vec` postfix infix.
- `architecture/figure-draw.md` — the `<draw>` block, where the colliding names route differently.
