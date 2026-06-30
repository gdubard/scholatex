# `<draw>` Shape Catalogue

## Scope

This document is the user-facing reference for every shape the `<draw>` block
accepts. Each entry lists the required arguments, the optional arguments and
their defaults, and the solver that produces the canonical coordinates.

For the runtime hand-off (how `<draw>` is dispatched into Lua at transpile
time, how `__drawbuild` is published, how `__dfig` is accumulated), see
`architecture/figure-draw.md`. For the global block options (`marks:`,
`measures:`, `labels:`, `rotate:`) and their interaction with the per-figure
attributes, see § "Marks and measures" below — and `architecture/figure-draw.md`
§ "Marks and measures" for the emission detail.

This catalogue covers `<draw>` only. The math operators `triangle(ABC)`,
`circle(O, r)`, `parallelogram` (the bare word) live in `mathlite` and fire
only inside `$ ... $`; see `reference/math-geometry-vocabulary.md`.

## Catalogue

Every shape, sourced from `compute` (`scholatex-figure.lua:143-403`) and the
solvers `Tri.*`, `Quad.*`, `Circle.*`, `regular_polygon`.

| Shape                                          | Required                                                         | Optional / defaults                                                                  | Solver / source line                                  |
|------------------------------------------------|------------------------------------------------------------------|--------------------------------------------------------------------------------------|-------------------------------------------------------|
| `triangle ABC equilateral`                     | `side:s`                                                         | `side:` is inferred from a shared edge if present (`scholatex-figure.lua:208-227`)   | `Tri.equilateral` (`:38`); dispatched at `:291`        |
| `triangle ABC isosceles`                       | `side:e base:b`                                                  | —                                                                                    | `Tri.isosceles` (`:39-44`); dispatched at `:292`       |
| `triangle ABC right`                           | one of `sides:(p,q)`, named-side per leg (`AB:n`), or a shared edge | `right:LETTER` (the right-angle vertex; defaults to the first point `at=1`)         | `Tri.right` (`:45-51`); dispatched at `:293-321`       |
| `triangle ABC sides:(a,b,c)`                   | `sides:(a,b,c)`                                                  | —                                                                                    | `Tri.sss` (`:52-57`); dispatched at `:326-329`         |
| `triangle ABC sides:(a,b) angle:t`             | `sides:(a,b) angle:t`                                            | —                                                                                    | `Tri.sas` (`:58`); dispatched at `:322-325`            |
| `triangle ABC angles:(A,B) side:c`             | `angles:(A,B) side:c`                                            | —                                                                                    | `Tri.asa` (`:59-64`); dispatched at `:330-333`         |
| `triangle ABC AB:n BC:n CA:n` (named SSS)      | all three named sides                                            | —                                                                                    | `Tri.sss` (`:52-57`); dispatched at `:334-340`         |
| `square ABCD`                                  | `side:s` (or a shared edge)                                      | —                                                                                    | `Quad.square` (`:67`); dispatched at `:342-345`        |
| `rectangle ABCD`                               | `sides:(w,h)`                                                    | —                                                                                    | `Quad.rectangle` (`:68-69`); dispatched at `:346-350`  |
| `rhombus ABCD`                                 | `side:s angle:t` (side inferred from shared edge if missing)     | `angle:` has no default — missing raises through `num(attrs.angle, "angle")`         | `Quad.rhombus` (`:70`); dispatched at `:351-354`       |
| `parallelogram ABCD`                           | `sides:(a,b) angle:t`                                            | —                                                                                    | `Quad.parallelogram` (`:71-72`); dispatched at `:355-359` |
| `trapezoid ABCD`                               | `bases:(b1,b2) height:h`                                         | `offset:o` (default `(b1 - b2) / 2`, i.e. an isosceles trapezoid) — see footnote¹     | `Quad.trapezoid` (`:73-76`); dispatched at `:360-365`  |
| `kite ABCD`                                    | `sides:(a,b) angle:t`                                            | —                                                                                    | `Quad.kite` (`:81-101`); dispatched at `:366-372`      |
| `pentagon`, `hexagon`, `octagon`               | exactly 5 / 6 / 8 points                                         | `side:s` (default `1` cm) — see footnote¹                                            | `regular_polygon` (`:131-141`); dispatched at `:373-379` |
| `polygon`                                      | ≥ 3 points                                                       | `side:s` (default `1` cm) — see footnote¹                                            | `regular_polygon` (`:131-141`); dispatched at `:373-379` |
| `circle X radius:r`                            | `radius:r`                                                       | one point `X` for the centre; missing centre falls back to `(0, 0)` silently²        | autonomous circle path (`:235-261`)                    |
| `circle X diameter:d`                          | `diameter:d`                                                     | same as above                                                                        | autonomous circle path (`:256-257`)                    |
| `circle X radius:AB`                           | two already-placed points naming the radius segment              | one point `X` for the centre                                                         | `length_value` reads the named segment (`:244-255`)    |
| `circle ABC`                                   | three already-placed points                                      | — (circumscribed circle by default)                                                   | `Circle.circumscribed` (`:107-115`); dispatched at `:262-285` |
| `circle ABC inscribed`                         | three already-placed points                                      | `inscribed` keyword switches to the inscribed circle                                  | `Circle.inscribed` (`:118-129`); dispatched at `:276-280` |
| `point(P)` primitive                           | one expression indexable as `[1]`, `[2]`                          | identifier name (becomes `dict[name]`) — unnamed dots get no entry in `dict`         | `primitive_to_lua` (`:796-805`); emitted at `:489`     |
| `line(A, B)` primitive                         | two arguments                                                    | `measures:cm` / `measures:mm`                                                         | `primitive_to_lua` (`:807-823`); emitted at `:496`     |

## Per-shape solver one-liners

The geometry is closed-form per shape — there is no generic constraint solver.
Every angle argument is in degrees, every coordinate in centimetres.

| Shape                                   | Source                                  | Formula                                                                                                |
|-----------------------------------------|-----------------------------------------|--------------------------------------------------------------------------------------------------------|
| `triangle equilateral`                  | `Tri.equilateral` (`scholatex-figure.lua:38`) | Place `A = (0, 0)`, `B = (s, 0)`, `C = (s/2, s √3 / 2)`.                                          |
| `triangle isosceles`                    | `Tri.isosceles` (`scholatex-figure.lua:39-44`) | `A = (0, 0)`, `B = (b/2, h)`, `C = (b, 0)` with `h = √(e² − b²/4)`.                                |
| `triangle right`                        | `Tri.right` (`scholatex-figure.lua:45-51`) | Right-angle vertex at the origin, legs `p` and `q` on the positive axes.                              |
| `triangle sides:(a,b,c)` (SSS)          | `Tri.sss` (`scholatex-figure.lua:52-57`) | Law of cosines: `cos A = (a² + c² − b²) / (2ac)`. Place `P[1] = (0, 0)`, `P[2] = (a, 0)`, `P[3] = (c · cos A, c · sin A)`. Sides are cyclic: `a = P₁P₂`, `b = P₂P₃`, `c = P₃P₁`. |
| `triangle sides:(a,b) angle:t` (SAS)    | `Tri.sas` (`scholatex-figure.lua:58`)   | Place `P[1] = (0, 0)`, `P[2] = (a, 0)`, `P[3] = (b · cos t, b · sin t)`.                              |
| `triangle angles:(A,B) side:c` (ASA)    | `Tri.asa` (`scholatex-figure.lua:59-64`) | Place by law of sines from the shared side `c`; raises if `A + B ≥ 180°`.                            |
| `square`                                | `Quad.square` (`scholatex-figure.lua:67`) | Unit square scaled by `s`: corners at `(0, 0)`, `(s, 0)`, `(s, s)`, `(0, s)`.                       |
| `rectangle`                             | `Quad.rectangle` (`scholatex-figure.lua:68-69`) | Corners at `(0, 0)`, `(w, 0)`, `(w, h)`, `(0, h)`.                                              |
| `rhombus`                               | `Quad.rhombus` (`scholatex-figure.lua:70`) | Two corners on the x-axis, two off it by angle `t`.                                                 |
| `parallelogram`                         | `Quad.parallelogram` (`scholatex-figure.lua:71-72`) | Base on the x-axis, opposite side translated by `(b · cos t, b · sin t)`.                       |
| `trapezoid`                             | `Quad.trapezoid` (`scholatex-figure.lua:73-76`) | Bottom base `b1` on the x-axis; top base `b2` at height `h`, horizontally offset by `o` (default `(b1 − b2) / 2`, i.e. isosceles). |
| `kite`                                  | `Quad.kite` (`scholatex-figure.lua:81-101`) | Symmetric kite around the y-axis: upper sides `a`, lower sides `b`, apex angle `t`. Raises if `b ≤ a · sin(t/2°)` (the kite would flatten to a triangle). |
| `pentagon` / `hexagon` / `octagon` / `polygon` | `regular_polygon` (`scholatex-figure.lua:131-141`) | Regular n-gon inscribed in circumradius `s / (2 · sin(π/n))`, first vertex at angle 0 from centre. |
| `circle X radius:r`                     | autonomous (`scholatex-figure.lua:235-261`) | Centre at `dict[X]` if `X` is placed, else `(0, 0)`. `diameter:d` is the same path with `r = d / 2`. |
| `circle X radius:AB`                    | autonomous (`scholatex-figure.lua:244-255`) | Centre at `dict[X]`; radius is the Euclidean distance `|AB|` from `dict[A]` and `dict[B]`.         |
| `circle ABC`                            | `Circle.circumscribed` (`scholatex-figure.lua:107-115`) | Circumscribed circle through three placed points. Raises if `|d| < 1e-9` (collinear). |
| `circle ABC inscribed`                  | `Circle.inscribed` (`scholatex-figure.lua:118-129`) | Inscribed circle of triangle `ABC` (incentre at weighted average of vertices by opposite-side lengths). |

## Marks and measures

Both default to `off` and apply to the **whole block** — setting either on
any figure propagates to the block-level options
(`build_block:731-733`).

| Option       | Values                  | Default | Effect                                                              |
|--------------|-------------------------|---------|---------------------------------------------------------------------|
| `marks:`     | `on` / `off`            | `off`   | Toggle equal-side ticks and right-angle squares.                    |
| `measures:`  | `off` / `cm` / `mm`     | `off`   | Label each side with its length, parallel to the side.              |
| `labels:`    | (`off` is the only recognised non-default) | unset | `off` suppresses vertex name labels. Other values silently ignored³. |

Validation:

- `marks` outside `{on, off}` → `<draw> marks: takes 'on' or 'off' (got 'V')`
  (`scholatex-figure.lua:742`).
- `measures` outside `{off, cm, mm}` → equivalent error
  (`scholatex-figure.lua:745`).

What `marks:on` activates per shape (mark hints come from each solver):

| Shape                                  | Mark hint                                  | Visible effect                                                      |
|----------------------------------------|--------------------------------------------|---------------------------------------------------------------------|
| `triangle equilateral`, `square`, `rhombus` | `sides = "all"`                       | One perpendicular tick per side.                                    |
| `triangle isosceles`                   | `{{1, 2}, {1, 3}}`                         | One tick on the two equal sides.                                    |
| `triangle right`                       | `right = at`                               | Inner-square right-angle coding at vertex `at`.                     |
| `square`                               | `right = "all"` plus `sides = "all"`       | Both ticks and right-angle codings (the "all" right path tests each corner with `|u1·u2| < 1e-6`). |
| `rectangle`, `parallelogram`           | `{{1,2,1}, {3,4,1}, {2,3,2}, {4,1,2}}`     | Single tick on one opposite-side pair, double on the other (so opposite sides share a tick count). |
| `kite`                                 | `{{1,2,1}, {1,4,1}, {2,3,2}, {3,4,2}}`     | Single tick on the two upper sides, double on the two lower.        |
| SSS / SAS / ASA, `trapezoid`, regular polygons (other than via shape-class default), circles | empty | No automatic marks.                                                  |

What `measures:cm` / `measures:mm` activates: per-edge `\node[rotate=θ] at
(mx,my) {\footnotesize VALUE UNIT};` rotated parallel to the edge, placed 0.28
cm outside the edge midpoint
(`scholatex-figure.lua:604-635`).

### Shared-edge deduplication

When two figures share an edge (e.g. `square` then `triangle` next to it), the
ticks and the measure label fire **once**. Both use the same sorted-name-pair
key `(na < nb) and na.."\1"..nb or nb.."\1"..na` to track already-marked /
already-measured edges (`scholatex-figure.lua:573` for ticks,
`scholatex-figure.lua:615-617` for measures).

## Composite figures: shared-point and shared-edge graft

A figure is "composite" when at least one of its named vertices already
exists in the running `dict` (the dictionary of placed points). The number
of shared vertices controls the graft mode (`graft`,
`scholatex-figure.lua:405-473`):

| Shared points | Behaviour                                                                                  |
|---------------|--------------------------------------------------------------------------------------------|
| 0             | Canonical layout — no translation, no rotation, no reflection.                             |
| 1             | Translate every vertex by `dict[name] − verts[i]` so the named vertex lands on its existing position. No rotation, no flip. |
| ≥ 2           | Graft over the shared edge — see below.                                                    |

### Shared-edge graft

1. Translate so the first shared vertex `la` lands on its existing position `ga`.
2. Rotate by `ang_g − ang_l` (the angle difference between the two edges).
3. Sanity-check side length: tolerance is `1e-3 * max(glen, 1)` — i.e. 0.1%
   of the longer side or 1 mm at most (`scholatex-figure.lua:423`). Mismatch
   raises `<draw> cannot graft 'AB': shared side length X differs from the
   existing Y — make the measurements match` (`scholatex-figure.lua:424-426`).
4. **Side-of-edge reflection** (`scholatex-figure.lua:437-471`):
   - Signed function `side_of(p) = (px − ga[1]) · ey − (py − ga[2]) · ex` using
     the existing edge as the reference vector.
   - Centroid of the **existing body** (all points already in `dict` minus
     the two shared ones).
   - Centroid of the **new body** (this figure's non-shared vertices).
   - If both signs are non-zero and equal — the new body would overlap the
     existing one — **reflect across the shared edge** with the orthogonal
     projection formula `p' = 2 · proj(p − ga onto edge) − (p − ga) + ga`.
   - If either centroid is zero (a single-vertex figure such as a `point()`
     primitive), the test is skipped.

Auto-deduction of `attrs.side` from a shared edge runs in `compute`
(`scholatex-figure.lua:208-227`) for single-length figures (`equilateral`,
`square`, `rhombus`) so the user does not have to repeat the length when
gluing a figure to an existing edge.

## Naming forms

`compute` (`scholatex-figure.lua:152-171`) dispatches on the first non-space
character after the tag word:

- `(` → parenthesised list: `triangle (O, A0, B0) ...`. Multi-character names
  are supported. Useful inside a loop where each iteration synthesises names
  like `A#k`.
- Otherwise → glued letter form: `triangle ABC`. The first word that matches
  `^%a+$` and contains no `:` becomes the point string; every Lua `%a` (single
  letter) is one point name.

**Named-side syntax (`AB:n`) only works in the glued form**
(`scholatex-figure.lua:184-202`). The check is
`#k == 2 and pointset[k:sub(1,1)] and pointset[k:sub(2,2)]`, which is
unambiguous only when every point is a single letter. The list form has no
named-side equivalent.

## Loops, interpolation, and rotation

### Block-level control flow

The block form `<draw>{ ... }` walks every line of `inner`
(`scholatex-figure.lua:869-881`):

- `}` alone → emit Lua `end\n` (closes the previous `for` / `if` / `while`).
- `api.is_control_open(l)` true → emit `api.lua_control(l)` translation. The
  recognised shapes are `for VAR in A..B {`, `for VAR in [list] {`,
  `if COND {`, `} else {`, `while COND {` — same as the core's control flow
  (`scholatex.lua:64-91`). The range form translates to Lua
  `for VAR = A, B do`.
- Any non-empty line → `primitive_to_lua` (for `point(...)` / `line(...)`) or
  `__dadd(line_to_luaexpr(line))`.

Example (`examples/geometry.tex:221`):

```
<draw>{
  for k in 0..11 {
    triangle (O, A#k, B#k) isosceles side:4 base:2 rotate:#{k*30} labels:off
  }
}
```

### `#k` and `#{expr}` interpolation

`line_to_luaexpr` (`scholatex-figure.lua:760-780`). If the line contains no
`#`, the whole line is `%q`-quoted as a single Lua string. Otherwise:

- `#NAME` (`[%a_][%w_]*`) → `tostring(NAME)` at runtime.
- `#{expr}` (balanced-read by `U.read_group`) → `tostring(expr)` at runtime.

The pieces concat with `..`. So the example above expands at each iteration to
roughly:

```lua
"triangle (O, A" .. tostring(k) .. ", B" .. tostring(k)
.. ") isosceles side:4 base:2 rotate:" .. tostring(k*30) .. " labels:off"
```

### `rotate:θ`

Pure post-canonical transform applied **before graft** (`compute`,
`scholatex-figure.lua:387-400`). After the shape solver returns its canonical
`verts`, every vertex is rotated by `θ` degrees about `verts[1]` (the first
vertex's coordinates). For the rosette/fan use case (one-shared-point
composite), the first vertex coincides with the shared apex, so the rotation
is around the apex.

Non-numeric raises `rotate: must be a number of degrees, got 'V'`
(`scholatex-figure.lua:390`).

### `labels:off`

Suppresses the vertex name labels only (`scholatex-figure.lua:751`). Side
labels and tick marks are not affected. Other `labels:` values are silently
ignored — see footnote³.

## Undocumented defaults

The following defaults are in code but absent from `CHANGELOG.md` and the
user-facing manuals. Recording them here so users do not get surprised:

- **`pentagon` / `hexagon` / `octagon` / `polygon` default `side:1`** — line
  `s = s or 1` in `regular_polygon` (`scholatex-figure.lua:132`) and the
  dispatcher fallback at `:379` (`attrs.side and num(attrs.side,"side") or 1`).
  A missing `side:` produces a 1 cm circumradius shape silently.
- **`trapezoid` default `offset:` is `(b1 - b2) / 2`** —
  `Quad.trapezoid:73-76` falls back to this value when `offset:` is omitted,
  producing an isosceles trapezoid. Documented in the example
  `examples/geometry.tex:168-172` but absent from `CHANGELOG.md`.

See footnote¹ and `memory/doc-gaps.md`.

## Known issues

- **Bilingual error messages.** `Tri.isosceles` (`:41`), `Tri.sss` (`:54`),
  `Tri.asa` (`:60`) still raise French strings; everything else uses English.
  Other v2.3 errors (e.g. `Quad.kite:91-94`) are English. The examples all
  use `lang=en`, so the bilingual leak is jarring. Tracked in
  `memory/doc-gaps.md`.
- **`<figure>` alias is undocumented.** `scholatex-figure.lua:888` registers
  `figure` as a back-compat alias for `draw`, but no user-facing doc mentions
  it. Tracked in `memory/doc-gaps.md`.
- **`labels:` is unvalidated** (footnote³ below). Tracked in `memory/doc-gaps.md`.
- **`circle O radius:N` falls back to centre `(0, 0)`** when `O` was never
  placed (`scholatex-figure.lua:259`). The user expects the centre at `O`;
  instead the circle ends up at the origin with no warning. Tracked in
  `memory/doc-gaps.md`.

See `memory/doc-gaps.md` for the full rolling list of doc-vs-code drifts.

## See also

- `architecture/figure-draw.md` — runtime hand-off, emission detail, complete
  failure-mode table, name collisions with `mathlite`.
- `reference/tags-and-blocks.md` — the full tag/block registry (where `<draw>`
  and `<figure>` are listed alongside everything else).
- `reference/math-geometry-vocabulary.md` — the math-mode operators with the
  same names (`triangle(ABC)`, `circle(O, r)`, `parallelogram` as a bare
  word). Context decides: inside `$ ... $` it is math, inside `<draw>` it is
  a shape.
- `memory/doc-gaps.md` — every doc-vs-code drift, including the four issues
  cross-referenced as footnotes¹-³ below.

---

¹ Undocumented `pentagon`/`hexagon`/`octagon`/`polygon` `side:` default of 1
cm, and `trapezoid` `offset:` default of `(b1-b2)/2`. See
`memory/doc-gaps.md`.

² `circle O radius:N` with `O` not previously placed silently uses centre
`(0, 0)` instead of `dict[O]` (`scholatex-figure.lua:259`). See
`memory/doc-gaps.md`.

³ `labels:` accepts any value but only `off` does anything. A typo such as
`labels:hide` silently keeps labels on (`scholatex-figure.lua:733, 751`). See
`memory/doc-gaps.md`.
