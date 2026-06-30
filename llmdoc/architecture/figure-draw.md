# Architecture: `<draw>` Figure Block

## Purpose

The `<draw>` block (introduced in v2.3) compiles a small declarative figure language — `triangle ABC equilateral side:5`, `rectangle ABCD sides:(8,5) marks:on`, `circle ABC inscribed`, `point(P)`, `line(A, B)` — into raw TikZ at transpile time. There are no symbolic coordinates, no `pgfmath` calls, and no scope transforms in the output. Every coordinate is resolved to four decimal places in centimetres and emitted as a hard literal inside a single `tikzpicture[line width=0.5pt]` wrapped in `\begin{center}...\end{center}`.

This is its own ownership boundary, separate from the math mini-language (which also has `triangle`, `circle`, `parallelogram` keywords — see § "Name collisions"). All `<draw>` logic lives in `scholatex-figure.lua` (~889 lines). The runtime hand-off goes through `__drawbuild`, set by the core transpiler.

## Runtime hand-off from `scholatex.lua`

`scholatex-figure.lua:831-889` is the module entry point — a closure called via `sl.use("scholatex-figure")` at `scholatex.lua:787`.

Three things happen on registration:

1. `sl.build_figure_block = build_block` (`scholatex-figure.lua:832`). The actual function the emitted Lua chunk calls through the global `__drawbuild`.
2. `sl.register_tag("draw", ...)` and `sl.register_tag("figure", ...)` (`scholatex-figure.lua:837-850`). The **tag** form: `<draw>triangle ABC equilateral side:5`. Inline use, one figure per tag.
3. `sl.register_block("draw", ...)` and `sl.register_block("figure", ...)` (`scholatex-figure.lua:853-884`). The **block** form: `<draw>{ ... }` with one figure per line and full control-flow support.

`figure` is a back-compat alias, commented "kept as an alias during the transition" at `scholatex-figure.lua:888`. The two name registrations share identical closures — `<draw>` and `<figure>` are interchangeable today. The alias is undocumented anywhere in user-facing docs (see `memory/doc-gaps.md`).

`__drawbuild` is published to both execution environments by the core:

- Untrusted (`scholatex.lua:644-667`): `env.__drawbuild = sl.build_figure_block` injected by `make_sandbox_env`.
- Trusted (`scholatex.lua:710-719`): `_G.__drawbuild = sl.build_figure_block` assigned before `load`.

The emitted block-form Lua opens with `local __dfig = {}; local function __dadd(f) __dfig[#__dfig+1] = f end` and closes with `emit(__drawbuild(__dfig))`. Every figure expression in the block goes through `__dadd`, and the final concatenation runs the whole list through `build_block` for output.

## Shape solver families

`compute` (`scholatex-figure.lua:143-403`) is the single dispatcher. The first whitespace-separated word selects the family. Each branch calls a closed-form solver in degrees and centimetres (no constraint solver). The solvers live near the top of the file:

- **Triangles** (`Tri.equilateral`, `Tri.isosceles`, `Tri.right`, `Tri.sss`, `Tri.sas`, `Tri.asa` at `scholatex-figure.lua:38-64`). Covered by `triangle ABC equilateral side:s`, `triangle ABC isosceles side:e base:b`, `triangle ABC right sides:(p,q)` or `triangle ABC right` with named sides, `triangle ABC sides:(a,b,c)` (SSS), `triangle ABC sides:(a,b) angle:t` (SAS), `triangle ABC angles:(A,B) side:c` (ASA), and the named-SSS shorthand `triangle ABC AB:3 BC:4 CA:5`.
- **Quadrilaterals** (`Quad.square`, `Quad.rectangle`, `Quad.rhombus`, `Quad.parallelogram`, `Quad.trapezoid`, `Quad.kite` at `scholatex-figure.lua:67-101`). Covered by `square ABCD side:s`, `rectangle ABCD sides:(w,h)`, `rhombus ABCD side:s angle:t`, `parallelogram ABCD sides:(a,b) angle:t`, `trapezoid ABCD bases:(b1,b2) height:h [offset:o]`, `kite ABCD sides:(a,b) angle:t`.
- **Circles** (`Circle.circumscribed`, `Circle.inscribed` at `scholatex-figure.lua:107-129`). Covered by `circle O radius:r`, `circle O diameter:d`, `circle O radius:AB` (segment length), `circle ABC` (circumscribed), `circle ABC inscribed`.
- **Regular polygons** (`regular_polygon` at `scholatex-figure.lua:131-141`). Covered by named `pentagon`, `hexagon`, `octagon` plus the generic `polygon` (any `n ≥ 3`).

Each solver returns `{verts, marks, ...}` where `verts` is an array of `{name, x, y}` triples in cm. Solvers raise descriptive errors when the geometry is impossible (collinear circumscribed points, triangle-inequality violation, kite flatness, etc.) — see § "Failure modes".

### Mark hints returned by solvers

- `Tri.equilateral` → `marks = {sides = "all"}` (single tick on every side).
- `Tri.right` → `marks = {right = at}` where `at` is the right-angle vertex index.
- `Tri.isosceles` → explicit pair list `{{1,2}, {1,3}}`.
- `Quad.square` → `{sides = "all", right = "all"}`.
- `Quad.rectangle`, `Quad.parallelogram` → `{{1,2,1}, {3,4,1}, {2,3,2}, {4,1,2}}` (opposite-side equality with multiplicity 1 and 2).
- `Quad.kite` → `{{1,2,1}, {1,4,1}, {2,3,2}, {3,4,2}}` (single tick on upper, double on lower).
- SSS / SAS / ASA, `trapezoid` → **empty** marks (no auto-marking).

Marks fire only when the block-level option `marks:on` is set (default `off`, see § "Block-level options").

## Coordinate model

- Unit: **centimetres**. Hardcoded at `scholatex-figure.lua:736-738` (comment) and exercised everywhere (`%.4f` formatting at output, `lcm*10` to convert to mm for labels at line 505).
- Precision: four decimals (`%.4f` per coordinate).
- Output wrapper: `\begin{center}\begin{tikzpicture}[line width=0.5pt]` ... `\end{tikzpicture}\end{center}` (`scholatex-figure.lua:747, 752`).
- Vertex emission: `\coordinate (NAME) at (X.XXXX,Y.YYYY);` (`scholatex-figure.lua:534`).
- Polygon outline: `\draw (NAME) -- (NAME) -- ... -- cycle;` (`scholatex-figure.lua:537`).
- Circles: `\draw (X,Y) circle [radius=R];` plus a `\fill (X,Y) circle [radius=0.04];` centre dot (`scholatex-figure.lua:518-519`).
- Point primitive: `\fill (X,Y) circle [radius=0.05];` (`scholatex-figure.lua:489`).
- Line primitive: `\draw (X1,Y1) -- (X2,Y2);` (`scholatex-figure.lua:496`).
- Vertex labels: `\node at (X,Y) {$NAME$};` pushed 0.35 cm radially out from the centroid (`scholatex-figure.lua:659, 697`).
- Side / radius labels: `\node[rotate=θ] at (mx,my) {\footnotesize VALUE UNIT};` with rotation folded into `]-90, 90]` (`scholatex-figure.lua:504, 507, 631`).

## Marks and measures

Both default to `off` and must be opted in. `build_block` (`scholatex-figure.lua:739-746`) normalises:

| Option | Values | Default | Effect |
|---|---|---|---|
| `marks:` | `on` / `off` | `off` | Toggle equal-side ticks and right-angle squares |
| `measures:` | `off` / `cm` / `mm` | `off` | Label each side with its length, parallel to the side |
| `labels:` | (`off` is the only recognised non-default value) | unset (labels emit) | Suppress the vertex name labels |

Validation:

- `marks` outside `{on, off}` raises `<draw> marks: takes 'on' or 'off' (got 'V')` (`scholatex-figure.lua:742`).
- `measures` outside `{off, cm, mm}` raises an equivalent error (`scholatex-figure.lua:745`).
- `labels` is **unvalidated** — any non-`off` value silently keeps labels on. A typo like `labels:hide` is silently ignored. See `memory/doc-gaps.md`.

Block-level options are scraped from `attrs` on **any** figure in the block — `gopt.marks = gopt.marks or attrs.marks` runs per-figure (`scholatex-figure.lua:731-733`). So setting `marks:on` on the last figure still applies to the whole block.

### Mark emission

- **Equal-side ticks** (`scholatex-figure.lua:566-595`). `marks.sides` is `"all"` (square, equilateral, rhombus) or a list of `{i, j}` or `{i, j, multiplicity}` triples. Each tick is a perpendicular segment of length 0.08 cm placed at the side's midpoint with `mult` parallel marks `gap=0.08` cm apart.
- **Right-angle squares** (`scholatex-figure.lua:545-565`). If `marks.right` is a vertex index, that one gets the inner-square coding. If `"all"`, the loop tests every corner with `|u1·u2| < 1e-6` and codes only the truly perpendicular ones — so a future shape passing `right="all"` would not get bogus coding.
- **Shared-edge dedup**. A `ticked` dictionary keyed by sorted-name-pair `(na < nb) and na.."\1"..nb or nb.."\1"..na` (`scholatex-figure.lua:573`) skips edges already marked by an earlier figure. The `measured` dictionary (`scholatex-figure.lua:615-617`) uses the same scheme so shared edges carry one label, not two.

### Measure emission

`scholatex-figure.lua:604-635`. For each edge: compute the outward normal from the centroid (`scholatex-figure.lua:625`: flip if `px*(mx-cx)+py*(my-cy) < 0`); place the label 0.28 cm out from the edge midpoint, rotated parallel.

## Composite figures: graft

`graft` (`scholatex-figure.lua:405-473`) is the welder. Behaviour depends on how many of the new figure's named vertices already exist in the running `dict` (the points placed by earlier figures).

- **0 shared points** (`scholatex-figure.lua:408`) — the figure keeps its canonical layout.
- **1 shared point** (`scholatex-figure.lua:409-416`) — translate every vertex by `dict[name] - verts[i]` so the named vertex sits on top of the existing one. No rotation, no flip.
- **≥ 2 shared points** — graft over the shared edge:
  1. Translate so the first shared vertex `la` lands on its existing position `ga`.
  2. Rotate by `ang_g - ang_l` (the angle difference between the two edges).
  3. Sanity-check side length: tolerance `1e-3 * max(glen, 1)` (`scholatex-figure.lua:423`). Mismatch raises `<draw> cannot graft 'AB': shared side length X differs from the existing Y — make the measurements match`.
  4. **Side-of-edge test** to decide whether to reflect (`scholatex-figure.lua:437-471`):
     - Signed function `side_of(p) = (px-ga[1])*ey - (py-ga[2])*ex` using the existing edge as the reference vector.
     - Centroid of the existing body (all points already in `dict` minus the two shared ones).
     - Centroid of the new body (this figure's non-shared vertices).
     - If both signs are non-zero and equal — the new body lies on the same side as the existing one and would overlap — **reflect across the shared edge** with `p' = 2·proj(p-ga onto edge) - (p - ga) + ga`. Single-vertex figures (`point()` primitives) skip this test because a centroid of a single point is degenerate.

Edge-share detection (`scholatex-figure.lua:407`) is "the first two `verts[i]` whose names already exist in `dict`". `compute` (`scholatex-figure.lua:208-227`) also runs an auto-deduction for single-length figures (`equilateral`, `square`, `rhombus`): if `attrs.side` is missing and the shared edge length is known, use it.

## Naming forms

`compute` (`scholatex-figure.lua:152-171`) dispatches on the first non-space character after the tag word:

- `(` → parenthesised list: `triangle (O, A0, B0) ...`. Multi-character names supported. Useful inside a loop where each iteration constructs synthetic names.
- otherwise → glued letter form: `triangle ABC`. The first word that is `^%a+$` and contains no `:` becomes the point string; every Lua `%a` (single letter) is one point name.

**Named-side syntax (`AB:6`) only works in the glued form** (`scholatex-figure.lua:184-202`). The check is `#k == 2 and pointset[k:sub(1,1)] and pointset[k:sub(2,2)]` — unambiguous only when every point is a single letter.

## In-block control flow and interpolation

The block-form closure (`scholatex-figure.lua:853-884`) walks every line of `inner`:

- `}` alone → emit Lua `end\n`.
- `api.is_control_open(l)` true → emit `api.lua_control(l)`. Reuses the core's `is_control_open` / `lua_control` (`scholatex.lua:64-91`) so the same five shapes — `for VAR in [list] {`, `for VAR in A..B {`, `} else {`, `if COND {`, `while COND {` — are recognised inside `<draw>` as anywhere else.
- Any other non-empty line → either `primitive_to_lua` (if it starts with `point(` or `line(`) or `__dadd(line_to_luaexpr(line))`.

### `#k` and `#{expr}` interpolation

`line_to_luaexpr` (`scholatex-figure.lua:760-780`). If the line contains no `#`, the whole line is `%q`-quoted as a single Lua string. Otherwise:

- `#NAME` (`[%a_][%w_]*`) → `tostring(NAME)` at runtime.
- `#{expr}` (balanced-read by `U.read_group`) → `tostring(expr)` at runtime.

The pieces concat with `..`. So:

```
triangle (O, A#k, B#k) isosceles side:4 base:2 rotate:#{k*30}
```

compiles to roughly:

```lua
"triangle (O, A"..tostring(k)..", B"..tostring(k)
.. ") isosceles side:4 base:2 rotate:"..tostring(k*30)
```

evaluated inside the surrounding `for k = 0, 11 do ... end`.

### `rotate:θ`

`compute` lines 387-400. After the shape solver returns its canonical `verts`, rotation applies about **`verts[1]`** (the first vertex's coordinates), not about an arbitrary anchor. Every vertex rotates by `θ` degrees. This is the *post-canonical* rotation, before `graft`. For the rosette/fan use case (one shared point + rotate), the first vertex coincides with the shared apex, so it rotates around the apex.

`rotate:V` non-numeric raises `rotate: must be a number of degrees, got 'V'` (`scholatex-figure.lua:390`).

### `labels:off`

Read from `attrs.labels` into `gopt.labels` (`scholatex-figure.lua:733`). At `scholatex-figure.lua:751` the vertex-label pass is skipped entirely when `gopt.labels == "off"`. Side labels and tick marks are **not** affected — only the `\node {$NAME$}` calls.

## Primitives `point` and `line`

Both detected at transpile time by `primitive_to_lua` (`scholatex-figure.lua:796-829`). They are not figures — they bypass `compute` and feed `__dfig` directly.

### `point(P)`

- Argument syntax: `^point%s*(%b())%s*(.-)$` (line 799).
- If the argument is a simple identifier `^([%a_][%w_]*)$` (line 802), a `name=` field is added. The emitted Lua is `__dadd({kind="point", name="P", x=(P)[1], y=(P)[2]})`.
- At runtime `P` must be indexable with `[1]` / `[2]`. The common patterns are `let P = {x, y}` (table) or `let u = vector(x, y)` (sequence).
- Named points are added to `dict` (`scholatex-figure.lua:713`) so later figures and labels can reference them.

### `line(A, B)`

- Argument syntax: `^line%s*(%b())%s*(.-)$` (line 808). The argument list is split on the **top-level** comma (lines 813-818) so a literal pair `{x, y}` inside is preserved.
- Emitted: `__dadd({kind="line", x1=(A)[1], y1=(A)[2], x2=(B)[1], y2=(B)[2]})`.
- Optional `measures:cm` / `measures:mm` trailing word; parsed by `primitive_opts` (lines 788-794). Any other trailing word raises `<draw> primitive option not understood: '...'`.

There are no other primitives — no `arc()`, no `bezier()`, no `text()`.

### `vector(...)` interaction

`vector(...)` is published by the core (`scholatex.lua:657-664` and `710-717`) and returns a sequence table `{x1, x2, ...}` of length ≥ 2. `point(u)` and `line(u, v)` work with `vector(...)` results because `primitive_to_lua` emits `(u)[1]` / `(u)[2]`. `vector(3, 5, 7)` is legal but the third component is silently ignored (only `[1]` and `[2]` are read).

## Failure modes

The most-likely errors users hit, with the trigger and the message. Full list is in `.llmdoc-tmp/investigations/04-draw-figure-block.md` § "Failure modes" (table of every `error()` call).

| Trigger | Message |
|---|---|
| Numeric attribute non-numeric | `<draw> WHAT must be a number, got 'V'` (`scholatex-figure.lua:23`) |
| Unclosed `(` in point list | `<draw> TAG has an unclosed '(' in its point list` (`scholatex-figure.lua:155`) |
| No point names found | `<draw> TAG needs point names, e.g. TAG ABC ...` (`scholatex-figure.lua:169`) |
| `circle … radius:` with wrong point count | `circle by radius needs exactly one point, the centre, e.g. circle O radius:3` (`scholatex-figure.lua:238`) |
| `circle ABC` with wrong point count | `circle through points needs three points (circle ABC), or a centre with radius:/diameter:` (`scholatex-figure.lua:263`) |
| Circumscribed circle through three collinear points | `circle ABCD — the three points are collinear, no circle through them` (`scholatex-figure.lua:282`) |
| `triangle` with wrong point count | `triangle needs 3 points, got N` (`scholatex-figure.lua:290`) |
| `triangle right` missing legs | `triangle right needs the two legs — give sides:(p,q), or name a side like AB:6, or share an edge` (`scholatex-figure.lua:317`) |
| Unknown `triangle` definition | listing the eight legal forms (`scholatex-figure.lua:341`) |
| Polygon point count mismatch | `TAG needs N points, got M` (`scholatex-figure.lua:376`) |
| Unknown shape | `<draw> unknown figure 'TAG'` (`scholatex-figure.lua:380`) |
| `rotate:` non-numeric | `rotate: must be a number of degrees, got 'V'` (`scholatex-figure.lua:390`) |
| Graft shared-edge length mismatch | `<draw> cannot graft 'AB': shared side length X differs from the existing Y — make the measurements match` (`scholatex-figure.lua:424`) |
| Invalid `marks:` | `<draw> marks: takes 'on' or 'off' (got 'V')` (`scholatex-figure.lua:742`) |
| Invalid `measures:` | `<draw> measures: takes 'off', 'cm' or 'mm' (got 'V')` (`scholatex-figure.lua:745`) |
| Primitive trailing option not understood | `<draw> primitive option not understood: 'V'` (`scholatex-figure.lua:793`) |
| `line(...)` with < 2 args | `<draw> line(...) needs two points, e.g. line(A, B)` (`scholatex-figure.lua:820`) |

### Solver-returned errors

Three solvers still raise French strings (residual from the project origin):

- `Tri.isosceles` line 41: `"côté égal trop court pour cette base"`.
- `Tri.sss` line 54: `"côtés incompatibles (inégalité triangulaire non respectée)"`.
- `Tri.asa` line 60: `"la somme des deux angles atteint ou dépasse 180°"`.

Other v2.3 errors (`Quad.kite` at lines 91-94) are English. The `<draw>` examples all use `lang=en`, so the bilingual leak is jarring. Tracked in `memory/doc-gaps.md`.

## Name collisions with the math mini-language

Three names exist as **both** `<draw>` shapes and `mathlite` operators. Context decides:

| Name | Inside `$ ... $` (math) | Inside `<draw>` |
|---|---|---|
| `triangle` | `triangle(ABC)` → `\bigtriangleup ABC` (`scholatex-math.lua:373-376`) | `triangle ABC equilateral side:5`, etc. (`scholatex-figure.lua:289-341`) |
| `circle` | `circle(O, r)` → `\mathcal{C}\left(O, r\right)` (`scholatex-math.lua:403-413`) | `circle O radius:3`, `circle ABC`, etc. (`scholatex-figure.lua:235-286`) |
| `parallelogram` | bare word → `\scholatexparallelogram` glyph (`scholatex-math.lua:71`) | `parallelogram ABCD sides:(a,b) angle:t` (`scholatex-figure.lua:355-359`) |

The other `<draw>` shape names (`square`, `rectangle`, `rhombus`, `trapezoid`, `kite`, `polygon`, `pentagon`, `hexagon`, `octagon`) have no math counterpart. The other math geometry operators (`frame`, `orthoframe`, `arc`, `angle`, `vector`, `colvec`, `triple`, ...) are math-only.

## Related

- `architecture/compile-pipeline.md` — the surrounding transpile flow, including how `__drawbuild` is injected into both execution envs.
- `architecture/math-pipeline.md` — the geometry operators in the inline math mini-language.
- `reference/draw-shape-catalogue.md` (wave 2) — the user-facing shape table with required / optional / default attributes for every shape.
- `memory/doc-gaps.md` — bilingual error messages, undocumented `<figure>` alias, unvalidated `labels:` value.
