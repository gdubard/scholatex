# Changelog

All notable changes to **scholatex** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to a simple `MAJOR.MINOR` scheme. Entries marked
**BREAKING** change the surface syntax: a document written for an earlier
version may need a small edit, described in the migration note.

## [2.5] — 2026-07-03

The lycée release: the nine figures and tables of the French secondary
curriculum that were still missing, so that a worksheet from seconde to
terminale never leaves the tag language — plus a full transcendental
function library, document-wide display rounding, and an audit pass
(one mathematical bug, sandbox hardening, zero static-analysis warnings).

### Added

- **The equation form of `<fn>`.** `<fn f(x) = (x+2)(x-3)>` reads as the
  board does ("let f(x) = ...") and registers itself under the left-hand
  name — no `let`, no `name:`, no `expr:`. The variable is declared in
  situ (`<fn g(t) = t^2 - 2t>`), and the table attributes stay attributes
  after the expression (`x:`, `deriv:`, `var:`, `second:`). A tabular-only
  object takes the head without `=`: `<fn v(x) x:{...} var:{...}>`.
  Objects rebind **sequentially**: a later `<fn f(x) = ...>` shadows the
  name for what follows, never for what precedes.
- **Sign tables: `<signtab>`.** Automatic: `<signtab f>` **computes** the
  rows from a product/quotient of affine factors — exact rational zeros, a
  forbidden value at each denominator zero, even multiplicities known not
  to change sign, one row per written factor plus the conclusion. Manual
  (block) form for rows the affine engine cannot derive:
  `x+2 : - | 0 | + | +`, a `0` marking a zero, `||` a forbidden value; the
  invariant is checked at compile time — a row that changes sign without a
  `0` or `||` is an error.
- **Weighted probability trees: `<tree>`.** Declarative branches
  (`A 0.3 { ... }`), `!B` for the complementary event, symbolic
  probabilities accepted. A node with exactly one branch receives its
  complement automatically; siblings that sum to something other than 1
  are a compile error. `products:on` writes `P(A ∩ B) = 0.18` at each
  leaf. Layout computed.
- **Areas, cobwebs and probability laws in `<plot>`.** `area:{a,b}` shades
  under the curve, `between:g` between two curves; `cobweb:{u0, n}` draws
  the staircase of a recurrent sequence with computed iterates;
  `normal:{mu, sigma}` and `binomial:{n, p}` need no `<fn>` object, and
  `area:` highlights `P(a ≤ X ≤ b)` on both.
- **Descriptive statistics: `<stats>`.** Five `kind:`s — `bars`
  (dictionary of frequencies; **symbolic keys render as horizontal bars**,
  the categories on the y-axis, so long names never truncate),
  `histogram` (draws *density*, so unequal classes stay honest), `pie`
  (12 o'clock start, clockwise, percentages rounded, labels anchored
  outside the disc), `boxplot` (French secondary-school quartiles),
  `scatter` with `fit:on` (least-squares line). A Lua table declared with
  `let` is passed to the tag by name: `let notes = {...}` then
  `<stats kind:bars data:notes>` — one source, several figures.
- **The trigonometric circle.** `<draw>trigcircle radius:4` — sixteen
  remarkable angles in principal measure; `values:on` adds the dashed
  cos/sin projections (exact at the remarkable angles, decimals
  elsewhere); `step:{pi/12}` and `range:{0, pi/2}` for a dynamic close-up.
- **The number line: `<numberline>`.** Declared interval sets
  (`set:{[-2, 3) union (4, inf)}`, `points:`), or solved: the block form
  takes the inequality and computes the set exactly — endpoints open or
  closed as the inequality is strict or not, a denominator zero always
  excluded, an isolated solution a point.
- **Space geometry: `solid` in `<draw>`.** `cube`, `cuboid`, `pyramid`,
  `cylinder`, `cone`, `sphere` in the French *perspective cavalière*.
  Hidden edges are **computed, not declared**: an edge is dashed exactly
  when both its faces are hidden. Vertex labels go into the widest empty
  angular sector between the projected edges, never onto an edge.
- **A transcendental function library**, one shared source
  (`scholatex-numeval`) backing both the `#{...}` interpolation and
  `<plot>`, radians by default: circular `sin cos tan cot sec csc` and
  inverses (`sind`/`arcsind`… for degrees), hyperbolic
  `sinh cosh tanh coth sech csch` and inverses, `exp`, `ln`, `log`
  (base 10), `log2`, `logb(v, b)`, `sqrt cbrt abs sign floor ceil`,
  `round(x, d)`, and the constants `pi` and `e`. `<plot>` translates each
  to its pgfplots form; the value and the curve come from the identical
  definition.
- **`precision` class option — document-wide display rounding.**
  `precision:N` rounds every number the reader sees to N decimals —
  `#{...}` values, pie percentages, trig-circle projections, figure
  measure labels — trailing zeros dropped (`3.50` → `3.5`); default `-1`
  prints as computed. A local `round(x, d)` overrides it for one value.
  Internal TikZ coordinates keep full precision.
- **`scale:F` on `<draw>`.** One factor multiplies every coordinate of
  the picture and leaves the text size alone (default 1, all forms:
  inline, block, `axes:`).
- **`<box>`** accepts `sep:` (canonical) and `boxsep:` (synonym) for the
  inner padding.

### Changed

- The class loads pgfplots' `fillbetween` library.
- Point labels in `<draw axes>` are deferred and placed in the freest
  diagonal quadrant relative to every line, tangent, region boundary and
  vector arrow through the point.
- Axis labels of `<plot>` are anchored past the axis tips, so the ylabel
  of a density centred at 0 no longer sits on the peak of the bell.
- Warnings reach the `.log` (via `texio`), not just stderr.
- The example files are regrouped one domain per file: `analysis.tex`
  (vocabulary, sign tables, number line, areas, cobwebs, four full
  function studies from polynomial to hyperbolic), `geometry.tex`
  (figures, axes, trigonometric circle, solids),
  `statistics-probability.tex` (vocabulary, trees, laws, descriptive
  statistics), alongside `basics.tex`, `algebra.tex`, `text-style.tex`
  and `containers.tex`.
- The tree is **luacheck-clean** (a `.luacheckrc` documents the LuaTeX
  globals); a 48-test regression suite ships as `tests-audit.lua`.

### Fixed

- **General circle equation in `<draw axes>`**: non-monic coefficients
  (`2x^2 + 2y^2 - 4x - 4y - 8 = 0`) silently produced a wrong circle; the
  equation is now normalised, an ellipse or an unreadable term is a
  compile error. The name of an equation-form circle is registered, so
  `tangent to:C` finds it.
- **Untrusted mode**: the sandbox now bounds memory as well as
  instructions — a doubling-concatenation bomb aborts cleanly instead of
  starving the TeX run.
- `for k in [1, 2, 3]` keeps numeric items as numbers, so `if k > 2`
  compares numbers, exactly as the range form does.
- Counter styles in the attribute form (`<section ROMAN>Title`) work as
  documented.
- The class reopens the actual source file (`status.filename`), robust
  against `-jobname` and `.ltx`; a literal `\end{document}` in the body
  warns instead of truncating silently; CRLF endings are normalised.
- Triangle constructor error messages are in English and the isosceles
  diagnostic is reachable; `<fn>` objects reset between transpilations.

## [2.4] — 2026-06-29

### Added

- **Analytic geometry in `<draw>`: the `axes:` mode.** With
  `axes:{xmin,xmax,ymin,ymax}` the block draws a graduated cartesian frame
  and reads every line as a coordinate directive rather than a construction.
  One unit stays one centimetre and the drawing is clipped to the window.
  - `point NAME (x,y)` places and labels a point; the name is then available
    to later lines.
  - `vector u (x,y)` draws a free vector from the origin; `vector AB` the
    bound vector between two placed points. A named vector is remembered:
    `vector s = u+v` / `u-v` draws the sum or difference, labelled with the
    expression along the arrow; `from:` translates any vector's tail (a
    placed point, a literal pair, or `~u` for the tip of a drawn vector);
    `style:` restyles a copy (`style:dashed-gray`, `style:Blue`).
  - `line` by equation (`y = 2x-1`, `x = -3`, or the general `2x+3y = 6`) or
    `line through A B` by two placed points.
  - `circle center:A radius:r` (centre a placed point or a literal pair),
    or by equation `circle x^2+y^2 = 4`; a named circle carries a
    `tangent to:C at:P` at a point on it.
  - `region` shades the half-plane of a linear inequality (`<`, `>`), the
    boundary dashed.
  The construction mode of 2.3 (named figures, measurements, composites,
  loops) is unchanged: a block without `axes:` behaves exactly as before.
- **Parametric and polar curves in `<plot>`: the `kind:` field.**
  `kind:parametric` reads `expr:{x(t), y(t)}` over `t:{a, b}`;
  `kind:polar` reads `expr:{r(theta)}` over `theta:{a, b}` and is drawn as
  the pair `(r cos theta, r sin theta)`. Bounds accept `pi`. Conics are
  drawn through their parametrisation (ellipse `{a cos(t), b sin(t)}`,
  parabola `{t, t^2}`, hyperbola `{a cosh(t), b sinh(t)}`) — no separate
  conic directive. A `<plot>` without `kind:` is the function graph of 2.1,
  unchanged.

## [2.3] — 2026-06-28

### Added

- **Figure drawing: the `<draw>` block.** A figure is described, not
  hand-placed: name the shape and give its measurements, and the coordinates
  are computed trigonometrically and emitted as hard TikZ numbers. One unit
  is one centimetre, so `side:5` draws a 5 cm side; nothing is rescaled.
  - **Triangles** by any classical definition — `equilateral`, `isosceles`,
    `right`, three sides `sides:(a,b,c)`, two sides and the included angle
    `sides:(a,b) angle:t`, two angles and a side `angles:(A,B) side:c`, or
    three sides named one by one (`AB:3 BC:4 CA:5`, the same as
    `sides:(3,4,5)`).
  - **Quadrilaterals** — `square`, `rectangle`, `rhombus`,
    `parallelogram`, `trapezoid`, and `kite` (two pairs of adjacent equal
    sides, the rhombus being the case where both pairs are equal).
  - **Regular polygons** by name from the pentagon up (`pentagon`,
    `hexagon`, `octagon`) or `polygon` with as many points as given.
  - **Circles** by centre and radius or diameter (`circle O radius:3`), the
    radius optionally a named segment (`radius:AB`, the compass span);
    `circle ABC` is the circumscribed circle of three placed points, with
    `inscribed` for the incircle.
- **Coding and measurement.** `marks:on` codes equal sides and right angles
  (off by default); `measures:cm` / `measures:mm` labels each side with its
  length, set parallel to the side. Both are opt-in.
- **Composite figures.** Several figures in one block share their points; a
  figure repeating a point is grafted onto it, and a figure sharing an edge
  deduces that edge's length and is flipped to the far side so the pieces
  abut instead of overlapping.
- **Multi-character point names.** Besides the glued single letters
  (`triangle ABC`), a parenthesised comma-separated list names
  multi-character points: `triangle (O, A0, B0)`. The first character of the
  argument list chooses the form — `(` for the list, anything else for the
  glued form.
- **Loops, interpolation and rotation inside `<draw>`.** A draw block runs
  the same `for VARIABLE in FROM..TO { … }` loops as the rest of the
  language; `#k` and `#{expr}` interpolate point names and measurements;
  `rotate:θ` turns a figure about its first point and `labels:off` hides the
  vertex names — together enough to fan, rosette or step figures round a
  centre.
- **Low-level primitives `point` and `line`.** `point(P)` places a dot at
  coordinates declared with `let P = {x, y}`; `line(A, B)` draws a segment
  between two points (names or literal `{x, y}` pairs), taking `measures:`
  like a figure side. As each coordinate is an ordinary expression, a loop
  can compute endpoints — the building block for free-form drawings such as
  a sun.

### Migration (2.2 → 2.3)

- Purely additive. The `<draw>` block and its primitives are new; existing
  documents are unaffected.

## [2.2] — 2026-06-24

### Added

- **Probability and statistics.** A full vocabulary for a probability
  course: the blackboard operators `PP(...)` ℙ and `EE(...)` 𝔼 (the doubled
  letters, the same rule as the number sets), with the conditional bar
  written `mid` so `PP(A mid B)` spaces correctly. Spread: `var(X)`,
  `std(X)`, `cov(X, Y)`. Distributions: `normal(mu, sigma)` 𝒩(μ, σ²),
  `poisson(lambda)` 𝒫(λ), `binomial(n, p)` ℬ(n, p). Distribution and
  density functions: `repart(X, x)` F\_X(x), `densite(X, x)` f\_X(x).
- **Counting.** The binomial coefficient `C(n, k)` ⁽ⁿₖ⁾ and the arrangement
  `A(n, k)` Aₙᵏ, recognised by their two comma-separated arguments, so a
  one-argument `C(t)` stays an ordinary function. The factorial is
  `factorial(n)` or simply `n!`.
- **Linear-algebra vocabulary.** Named operators on top of the existing
  matrix blocks: `ker(f)`, `im(f)`, `rank(A)`, `span(...)`, `tr(A)`,
  `com(A)`, `eigen(A)` (the spectrum Sp), `adj(A)`. The transpose `transpose(A)`
  sets Aᵀ and the inverse `inv(A)` sets A⁻¹.
- **Differential operators.** `grad(f)`, `div(F)`, `curl(F)` (the named
  operators), the Laplacian `lap(f)` Δf which prefixes its operand without
  parentheses, and the directional derivative `dirderiv(f, u)` ∇_u f.
- **Landau notation.** `bigO(...)` O(·) and `litO(...)` o(·), spelt out so
  the bare letters `o` and `O` remain free as variables.
- **Integral transforms.** `laplace(f)` ℒ{f}, `fourier(f)` ℱ{f}, and their
  inverses `ilaplace(f)`, `ifourier(f)`.
- **Surface and volume integrals.** `surfint(S)` ∯, `volint(V)` ∭ and a
  flux `flux(F, S)`, built on the integral signs unicode-math already
  provides — no new package.
- **Number theory and more sets.** Euler's totient `euler(n)` φ(n), the
  Möbius function `mobius(n)` μ(n), congruence with the keyword `mod`
  (`a equiv b mod n` → a ≡ b (mod n)). Arithmetic helpers `lcm(a, b)`,
  `sign(x)`, `card(A)`, the power set `powerset(A)` 𝒫(A), the integer
  interval `range(1, n)` ⟦1, n⟧, and the keyword `mid` for a spaced bar in
  `set(x mid x > 0)`.
- **Calculation templates.** `taylor(f, x, a, n)` writes the Taylor form
  (template, not a computation), and `jacobian(f, n)` / `hessian(f, n)`
  write the generic partial-derivative matrices.
- **Examples reorganised by domain.** Each mathematical domain is one file:
  `math-analysis` absorbs the vector operators, transforms and Landau
  notations; `math-algebra` absorbs the linear-algebra vocabulary; a new
  `math-probability` covers the probability domain.

### Fixed

- **Extensible parentheses over a fraction.** A parenthesised group holding
  a fraction now grows to full height, so `(a/b)^2` sets ⎛a/b⎞² with tall
  delimiters instead of text-height ones. Plain groups such as `(a+b)` and
  calls like `f(-x)` are untouched.
- **Higher-order differentials.** `d^2y/dx^2` now sets the second-order
  derivative with the upright d throughout; the unparenthesised form is read
  the same as the parenthesised `(d^2 y)/(d x^2)`.
- **Plot axis readability.** A curve crossing an axis no longer blots out
  the tick numbers sitting on it: each tick label is backed by a thin white
  plate, and the axis line runs a little past its last graduation so the
  arrow clears the final number.

### Migration (2.1 → 2.2)

- Purely additive. Existing documents are unaffected; the new vocabulary
  only claims names that were not in use (the two-argument `C(...)` and
  `A(...)`, the doubled `PP`/`EE` already meant the blackboard letters).

## [2.1] — 2026-06-23

### Added

- **Mathematical vocabulary.** The inline mini-language now carries the
  notation a course needs to *state* things, not only compute:
  - Number sets in blackboard bold, doubled-capital ASCIIMath style:
    `NN ZZ DD QQ RR CC`, plus `PP KK HH FF EE UU` for the advanced ones.
  - Quantifiers and connectives: `forall` ∀, `exists` ∃, `and` ∧, `or` ∨,
    `lnot`/`neg` ¬.
  - Implication and equivalence, as words or ASCII arrows: `=>`/`implies`
    ⇒, `<=>`/`iff` ⇔.
  - Set relations and operations: `in subset supset subseteq supseteq cup
    cap setminus emptyset`.
  - The integer part: `floor(x)` ⌊x⌋, `ceil(x)` ⌈x⌉, `round(x)`.
  - One-argument wrappers `set(...)` and `abr(...)` (inner product), and the
    accents `bar`/`conj` (the conjugate–mean–closure overline), `not` (the
    same overline read as logical negation), `hat`, `tilde`.
- **Negation with a single `!`.** A `!` in front of a relation or
  quantifier negates it with the proper struck-through glyph: `!in` ∉,
  `!exists` ∄, `!subset` ⊄, `!subseteq` ⊈, `!equiv` ≢. `!=` keeps its
  meaning "not equal" (≠).
- **Limit arrow.** `arrow(n to +inf)` sets a long right arrow with its
  condition written underneath, for the "uₙ → l" phrasing in running maths.
- **Function studies.** Three tags share one source of truth: `<fn>` builds
  a function object (name, formula, abscissas, derivative signs, variation),
  `<vartab>` renders its variation table, `<plot>` draws its curve through
  pgfplots with pole handling. The table comes in four shapes — full
  (f″, f′, f), classic (f′, f), convexity (f″, f), or a plain value table —
  since the two derivative lines are independent and optional.
- **Section numbering styles.** `num`, `roman`, `ROMAN`, `alpha`, `ALPHA`
  set the counter style of a heading level on its own, with no inherited
  prefix; the default stays hierarchical.

### Changed

- **BREAKING — colours are CamelCase only.** The lowercase colour keywords
  (`red`, `blue`, `green`, `navy`, …) have been removed. There is now a
  single rule: a colour is one of the 151 CSS / svgnames names written in
  CamelCase. The everyday colours are simply the capitalised form (`Red`,
  `Blue`, `Navy`, `Gray`). A lowercase colour now raises an error that names
  its CamelCase replacement.
- **Examples reorganised.** The single `03-math.tex` is split by topic, and
  the showcase set drops its numbering: `text-style`, `containers`,
  `math-language`, `math-analysis`, `math-algebra`, `functions`.

### Migration (1.x / 2.0 → 2.1)

- Replace every lowercase colour keyword with its CamelCase form. The
  mapping is a plain capitalisation:
  `red→Red`, `blue→Blue`, `green→Green`, `navy→Navy`, `orange→Orange`,
  `purple→Purple`, `teal→Teal`, `brown→Brown`, `gray→Gray`, `grey→Grey`,
  `pink→Pink`, `yellow→Yellow`, `black→Black`, `white→White`,
  `violet→Violet`, `cyan→Cyan`, `magenta→Magenta`, `lime→Lime`,
  `olive→Olive`, `aqua→Aqua`, `silver→Silver`, `maroon→Maroon`.
  A sed one-liner for a single file:
  ```
  sed -i -E 's/\b(red|blue|green|navy|orange|purple|teal|brown|gray|grey|pink|yellow|black|white|violet|cyan|magenta|lime|olive|aqua|silver|maroon)\b/\u&/g' file.tex
  ```
  Apply it only to scholatex documents (not to English prose), since it
  capitalises whole words.
- To print a comparison or arrow operator **in running prose** (outside
  `$…$`), double the chevrons: `<<=>>` for ⇔, `<<=` for ≤, `>>=` for ≥.
  Inside a formula nothing changes.

## [2.0] — 2026-06-21

### Changed

- **BREAKING — new escape rules.** To print a special character, double it:
  `<<` `>>` `{{` `}}` `##` give a literal `<` `>` `{` `}` `#`. A backslash is
  now an ordinary character (so `C:\Users` just works) and no longer an
  escape; the old `\<` `\>` `\{` `\}` `\#` forms no longer apply.
- **BREAKING — line break is a tag.** Use `<nextline>` (in text and table
  cells) instead of the old `\\`. In running text a blank line already
  starts a new paragraph, so `<nextline>` is only for a break without a
  paragraph change.

### Security

- Closed-language design: the backslash is inert, so raw LaTeX in the body
  is typeset literally rather than executed. The `untrusted` option runs the
  document's Lua in a restricted sandbox.

## [1.2]

### Fixed

- **Script/fraction precedence.** `^` and `_` now bind tighter than `/`, so
  `x^2/y` is the fraction of `x^2` over `y` (and `1/i^2` is `1` over `i^2`),
  matching ordinary mathematical reading.

### Added

- **Automatic spacing for tall lines.** Consecutive lines with fractions or
  integrals no longer touch; ordinary text is unchanged.

## [1.1]

### Added

- **Maths expansion.** Full integral family (`int`, multiple integrals with
  Fubini ordering, `contourint`, `pvint`, `meanint`), upright functions and
  trigonometry, Leibniz and partial derivatives with ISO 80000-2 upright
  differentials.
- **Operators in display style.** `sum`, `prod`, `lim` keep fractions
  full-size and place limits under the word.
- **Full colour parity.** All 151 xcolor svgnames colours recognised,
  grouped by family in the colour reference.
- **Cross-platform install.** Documented `tlmgr` and manual paths for macOS,
  Linux and Windows.

## [1.0]

- First CTAN release: the tag-based language, text attributes, aliases and
  macros, tables, images, the inline maths mini-language, boxes, the
  named-area grid, lists, control flow.

[2.3]: https://ctan.org/pkg/scholatex
[2.2]: https://ctan.org/pkg/scholatex
[2.1]: https://ctan.org/pkg/scholatex
[2.0]: https://ctan.org/pkg/scholatex
[1.2]: https://ctan.org/pkg/scholatex
[1.1]: https://ctan.org/pkg/scholatex
[1.0]: https://ctan.org/pkg/scholatex
