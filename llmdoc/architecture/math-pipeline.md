# Architecture: Math Pipeline

## Purpose

The inline math mini-language `mathlite` is a closed expression-oriented compiler that turns `$ ... $` content into LaTeX. It lives entirely in `scholatex-math.lua` (861 lines) and is invoked **only** from `forward_text` when it hits a `$` (`scholatex.lua:182-231`). The math module owns: number-set blackboard letters, quantifiers, named operators and wrappers, the integral and big-operator families, derivatives with the ISO 80000-2 upright `d`, the inline geometry vocabulary, and the extensible-parenthesis rule over fractions.

This is its own ownership boundary, distinct from the core transpiler (the `forward_text` → `mathlite` call is the **single** entry point) and distinct from the `<draw>` block (three names collide: `triangle`, `circle`, `parallelogram` — see `architecture/figure-draw.md` § "Name collisions").

## Surface vs implementation

### `mathlite` is not a tag

`scholatex-math.lua` calls `sl.register_tag` **zero** times and `sl.register_block` **zero** times. The module exposes only:

- `M.mathlite(s)` — the compiler. Re-exported on the `sl` namespace as `sl._mathlite` at `scholatex.lua:777`.
- `M.differential(num, den)` — the ISO 80000-2 upright-d helper, called from the `/` arm.

Call sites:

- `scholatex.lua:219` — the only invocation in the core. Inside `forward_text`, when a `$ ... $` span is found, `mathlite` runs over the inner string.
- `sl._mathlite` is also called by table/cell modules to compile per-cell math (`scholatex-matrix.lua`, `scholatex-table.lua`, `scholatex-vartab.lua`, `scholatex-plot.lua` — outside the scope of this doc).

### `<fn>`, `<vartab>`, `<plot>` are separate

These three are commonly thought of as "math features" but they are **not** part of the math mini-language:

- **`<fn>` is parsed by the core** (`scholatex.lua:470-504`) as a multi-line object accumulator. The actual parser `sl.fn_parse` is defined in `scholatex-vartab.lua:405-407`. There is **no** `sl.register_tag("fn", ...)` anywhere. `<fn ...>` stores its result in `sl._objects[name]` and the object is later consumed by `<vartab>` and `<plot>`.
- **`<vartab>`** is `sl.register_tag("vartab", ...)` in `scholatex-vartab.lua:409`.
- **`<plot>`** is `sl.register_tag("plot", ...)` in `scholatex-plot.lua:105`.

See `architecture/function-studies.md` (wave 2).

### Geometry operators are part of `mathlite`

Operators like `angle()`, `triangle()`, `vec()`, `frame()`, `perp`, `parallel` live in the `mathlite` tables (`scholatex-math.lua`) and are invoked from inside `$ ... $`. They are **not** part of the `<draw>` block. See `reference/math-geometry-vocabulary.md` (wave 2) for the geometry vocabulary; the dispatcher is the same one described below.

## Tokeniser

The "lexer" is not a separate pass — `mathlite` runs one cursor `pos` across the source string and dispatches per-character. The atom reader `read_atom` (`scholatex-math.lua:293`) and the top-level loop (`scholatex-math.lua:753`) share the cursor.

- **Whitespace.** `skipws` (`scholatex-math.lua:205`) skips any `%s` between atoms. Whitespace is significant only as an atom separator.
- **Identifier reading.** `read_atom` matches a longest run of letters via `^(%a+)` (`scholatex-math.lua:347`). The captured word is then looked up in `BBSET`, `ACCENT`, `FENCE`, `SYMOP`, `NAMED`, `WRAP1`, `TWOARG`, `BIGOP`, `UNDEROP`, `INTOP`, `FUNC`, `SYM`, `GREEK`. **First match wins.** Unknown words fall through to `else: pos = after; return word` (`scholatex-math.lua:736`) — emitted verbatim. The language is closed but permissive on names.
- **Operator detection** (top-level loop, `scholatex-math.lua:753`). Longest-match-first for multi-character symbols: `<=>`, `<->`, `=>`, `<=`, `>=`, `->`, `<-`, `!=`, `+-`, `-+`. Then `°` (UTF-8 `\194\176`). Then `!word` for negation. Then single-character `+ - = < > , ) * / ^ _` with dedicated arms.
- **Number literals.** `read_atom:740`: `if c:match("%d")` grabs the longest run of `[%d.]`. If `M.decsep` is `,` (default for French), the dot is rewritten via `gsub` to the locale separator (`scholatex-math.lua:744`). No exponent or sign handling — a leading `-` is a separate token.
- **Special characters.**
  - `(` (`scholatex-math.lua:298`) → bracket-balanced read, body recursed through `M.mathlite`, then wrapped — see § "Extensible parentheses".
  - `{` (`scholatex-math.lua:321`) → balanced read, kept as `{ ... }`.
  - `\` (`scholatex-math.lua:334`) → pass-through escape hatch: backslash-letters pass through verbatim. Lets advanced users inject raw LaTeX.
- **`!` prefix** (`scholatex-math.lua:781-795`). Runtime rewriter. Two paths:
  - Curated `NEG` table (`scholatex-math.lua:82-89`) for the *amssymb* native glyphs (`\notin`, `\nexists`, `\nsubseteq`, etc.).
  - Fallback `\not<symbol>` on any other `SYM[word]`. So `!forall` becomes `\not\forall ` — legal but ugly.
- **Doubled letters → blackboard.** `BBSET` (`scholatex-math.lua:32-37`) lists exactly twelve doubled identifiers: `NN ZZ DD QQ RR CC PP KK HH FF EE UU`. Because the lexer greedy-matches the longest letter run, a single `N`/`R`/`P`/`E`/`K`/`H`/`F`/`U` stays an ordinary variable; the doubling is the disambiguator.

## Recursive descent (no precedence table)

`mathlite` has no precedence array. The language uses a recursive-descent ladder with a deliberate split between the atom reader and the top-level loop.

- **Top-level loop** (`scholatex-math.lua:753-857`). Walks atoms separated by binary operators. For each atom it calls `read_scripts(read_atom())` (`scholatex-math.lua:855`) — **the script handling is attached to the atom**, not to the surrounding binary operator.
- **`read_scripts`** (`scholatex-math.lua:265-291`). Repeatedly consumes `^` / `_` plus a braced group or one further atom, accumulating onto a single base.
- **The `/` arm** (`scholatex-math.lua:802-829`). **Pops the last finished atom** from the output list and uses it as the numerator. Because `^`/`_` have already been folded into that atom by `read_scripts`, the script binds tighter than the fraction — exactly the CHANGELOG 1.2 fix.

Effective ladder (highest to lowest):

| Level | Operator | Where |
|---:|---|---|
| 1 | `( )`, `{ }` parens | `read_atom:298, 321` |
| 2 | Named keywords / wrappers | `read_atom` keyword arms |
| 3 | Scripts `^`, `_` | `read_scripts:265` |
| 4 | Implicit juxtaposition / pop | top-level fall-through `:855` |
| 5 | Fraction `/` | `/` arm `:802` |
| 6 | Unary `+`/`-` | inside script + top-level emit |
| 7 | Binary `+ - * = < > ,` | top-level literal emit `:851` |

Proof that scripts beat fraction: `x^2/y`. The loop reads `x`, then `read_scripts(read_atom())` sees `^2` and pushes `x^{2}`. Next char is `/`. The `/` arm pops `x^{2}` as `num` and reads the next script-glued atom `y` as `den`. Result: `\frac{x^{2}}{y}`. For `(a/b)^2`, the parenthesised group is read as a complete atom, wrapped into `\left( ... \right)` because its body contains `\frac` (line 315), then the parent loop's `read_scripts` lifts `^2` onto the whole group.

The longest-match symbolic ladder is also explicit (`scholatex-math.lua:762-799`):
- `<=>` → `\Leftrightarrow`
- `<->` → `\leftrightarrow`
- `=>` → `\Rightarrow`
- `<=` → `\leq`
- `>=` → `\geq`
- `->` → `\to`
- `<-` → `\leftarrow`
- `!=` → `\neq`
- `+-` → `\pm`
- `-+` → `\mp`

## Dispatch tables

The 14 named maps and how they fire. All declarations live near the top of `scholatex-math.lua`; the dispatcher arms are inside `read_atom` (or the top-level loop for the symbolic ones).

| Table | Lines | Dispatcher arm | Shape |
|---|---|---|---|
| `GREEK` | 3-12 | `:733` (fall-through emit `\<word> `) | Bare Greek letters: `alpha`, `Gamma`, `varepsilon`, ..., plus `partial`, `nabla`, `ell`, `hbar` |
| `BIGOP` | 13 | 688-707 | `sum`, `prod`, `int` with `(spec) body`, `=`-terminated, `{\displaystyle ...}` wrap |
| `UNDEROP` | 14 | 622-634 | `lim(x->0) body` → `{\displaystyle \lim\limits_{x \to 0} body}` |
| `FUNC` | 15-21 | 709 (or 717 for `inf`) | Upright function names: `sin cos tan ... ln log exp det dim gcd deg ker arg hom max min sup` |
| `INTOP` | 22-27 | 636-686 | `int`, `contourint`, `pvint`, `meanint` integral families |
| `BBSET` | 32-37 | 351 | Blackboard letters: 12 doubled-letter codes `NN ZZ DD QQ RR CC PP KK HH FF EE UU` |
| `SYM` | 43-77 | 729-730 | Forward-form quantifiers, connectives, set relations, arrows, relations, misc (~50 entries) |
| `NEG` | 82-89 | 781-795 (via `!` prefix) | Curated *amssymb* negated glyphs: `!in → \notin`, etc. |
| `FENCE` | 93-101 | 485 | `abs(x)`, `norm(v)`, `floor`, `ceil`, `round`, `set(...)`, `abr(...)` — wrappers around exactly one parenthesised argument |
| `ACCENT` | 106-116 | 462 | `bar`, `not`, `conj`, `vec`, `hat`, `tilde`, `dotacc`, `ddotacc`, `underbar` |
| `NAMED` | 122-130 | 516 | Named upright operators: `lcm`, `sign`, `card`, `tr`, `rank`, `ker`, `im`, `span`, `com`, `eigen`, `adj`, `grad`, `div`, `curl` |
| `SYMOP` | 136-138 | 497 | Symbolic operators with bare operand: `lap` |
| `WRAP1` | 143-163 | 528-531 | Bespoke one-arg wrappers: `powerset`, `laplace`, `transpose`, `inv`, `euler`, `mobius`, `var`, `std`, `factorial`, `poisson`, `bigO`, `litO`, `ortho`, `fourier`, `ilaplace`, `ifourier` |
| `TWOARG` | 168-184 | 603-612 | Exactly-two-argument primitives: `C(n,k)`, `A(n,k)`, `cov`, `range`, `normal`, `binomial`, `repart`, `densite`, `dirderiv`, `collinear`, `inner`, `distance`, `midpoint`, `orthogonalprojection` |

### Bespoke arms

Some operators are not in any table — they have their own `if word == "..."` arms inside `read_atom` because their argument shapes do not fit a table:

| Word | File:line | Emits |
|---|---|---|
| `sqrt(x)` | 354 | `\sqrt{x}` |
| `angle(A)` / `angle(ABC)` | 363 | `\widehat{A}` / `\widehat{ABC}`. Bare `angle` raises (French message, line 369) |
| `triangle(ABC)` | 373 | `\bigtriangleup ABC` |
| `arc(AB)` | 379 | `\overparen{AB}` |
| `frame(O, i, j[, k])` | 386 | `\left(O, \overrightarrow{i}, \overrightarrow{j}[, ...]\right)` |
| `orthoframe(...)` | 446 | same as `frame` (separate name for intent) |
| `circle(O, r)` / `circle(A, B, C)` | 403 | `\mathcal{C}\left(...\right)` |
| `vector(x, y[, z, ...])` | 417 | `\left(x, y[, z, ...]\right)` |
| `colvec(x, y[, z])` | 430 | `\begin{pmatrix} x \\ y[ \\ z] \end{pmatrix}` |
| `triple(u, v, w)` | 591 | `\left[\overrightarrow{u}, \overrightarrow{v}, \overrightarrow{w}\right]` |
| `arrow(spec)` | 616 | `\mathrel{\underset{spec}{\longrightarrow}}` |
| `taylor(f, x, a, n)` | 534 | Full Taylor form with remainder |
| `jacobian(f, n)` | 551 | `\left(\dfrac{\partial f_{i}}{\partial x_{j}}\right)_{1\le i,j\le n}` |
| `hessian(f, n)` | 565 | `\left(\dfrac{\partial^{2} f}{\partial x_{i}\,\partial x_{j}}\right)_{1\le i,j\le n}` |
| `surfint(S)` | 573 | `\oiint_{S} ... \,\mathrm{d}\sigma` |
| `volint(V)` | 577 | `\iiint_{V} ... \,\mathrm{d}V` |
| `flux(F, S)` | 584 | `\iint_{S} F \cdot \mathrm{d}\overrightarrow{S}` |

### Postfix infix for `vec`

The `ACCENT` arm at `scholatex-math.lua:466-481` has a runtime special case: a `vec(u)` immediately followed by `.` or `^` and another `vec(v)` becomes the dot product (`\cdot`) or wedge/cross product (`\wedge`). This is the **only** infix shortcut in the language. A bare `^` after `vec(u)` (no `vec(...)` on the right) reverts to ordinary script handling.

## Extensible parentheses over a fraction

The `(` arm of `read_atom` (`scholatex-math.lua:298-319`):

```lua
if c == "(" then
  -- ... balanced read into `inner` ...
  local body = M.mathlite(inner)
  if body:find("\\frac", 1, true) then
    return "\\left(" .. body .. "\\right)"
  end
  return "(" .. body .. ")"
end
```

The height decision is a **literal string search** for `\frac` in the already-cooked body. Hit → extensible `\left(`/`\right)` pair; miss → ordinary `(` and `)`. Because `mathlite` is run recursively on the inner content first, this catches nested fractions too. Concrete cases:

- `f(-x)` → plain `(-x)` (no `\frac`).
- `(a+b)` → plain `(a+b)`.
- `(a/b)^2` → tall `\left(\frac{a}{b}\right)^{2}` (the parent loop's `read_scripts` lifts `^2` onto the whole tall group).

This is the CHANGELOG 2.2 fix for extensible parentheses.

## Derivatives and `M.differential`

The fraction code path drives the derivative rewrite. The `/` arm (`scholatex-math.lua:802-829`) has a pre-step for the differential `d`:

```lua
elseif c == "/" then
  local num = table.remove(out) or ""
  -- d^2y reads as two atoms d^{2} then y; rejoin at the bar
  local prev = out[#out]
  if (num:match("^%a") or num:match("^\\")) and prev
     and (prev == "d" or prev:match("^d%^{%d+}$")) then
    table.remove(out)
    num = prev .. num
  end
  num = strip_paren(num)
  pos = pos + 1
  local den = read_scripts(read_atom())
  den = strip_paren(den)
  num, den = M.differential(num, den)
  local frac = "\\frac{" .. num .. "}{" .. den .. "}"
```

`M.differential` (`scholatex-math.lua:186-199`) is the ISO 80000-2 upright-d rule:

- If `num` matches `^d`, `^d%a`, or `^d%^` AND `den` matches `^d%a`, both get their leading `d` replaced by `\mathrm{d}` (lines 187-194). So `dy/dx` → `\frac{\mathrm{d}y}{\mathrm{d}x}`. But `d/2` stays `\frac{d}{2}` (a variable called *d*).
- If both sides start with `\partial`, they are returned as-is (lines 195-197): `(partial u)/(partial t)` → `\frac{\partial u}{\partial t}`.

### The CHANGELOG 2.2 `d^2 y / dx^2` fix

When the user writes `d^2 y / dx^2`:

1. `read_scripts` pushes `d^{2}` to `out`, then `y` as a *separate* atom.
2. When `/` fires, `num = out.pop() = y` and the immediately preceding entry is `d^{2}`.
3. The match `prev:match("^d%^{%d+}$")` (`scholatex-math.lua:812`) recognises this, pops `d^{2}` too, and rejoins them: `num = "d^{2}y"`.
4. `M.differential` rewrites the leading `d` to `\mathrm{d}` and emits `\frac{\mathrm{d}^{2}y}{\mathrm{d}x^{2}}`.

This is the "unparenthesised form is read the same as the parenthesised `(d^2 y)/(d x^2)`" guarantee in CHANGELOG 2.2.

## Locale

The decimal separator is locale-driven. `sl.config.lang` (set by `scholatex.cls:87` from the `lang` class option) is read by `sl.transpile` at `scholatex.lua:692-693`:

- `MATH.decsep = "."` when `lang == "en"`.
- `MATH.decsep = "{,}"` otherwise (default `fr`).

`mathlite` consumes `decsep` in the digit-run path (`scholatex-math.lua:744`). The braces around the comma keep TeX from treating it as a punctuation glyph with extra spacing.

The text-side separator is set independently in `build_lua` (`scholatex.lua:450-452`) into the chunk-local `_SEPT`. See `architecture/compile-pipeline.md` § "`build_lua` preamble".

## Integrals: `INTOP` arm

`INTOP` (`scholatex-math.lua:22-27`) lists four entries: `int`, `contourint`, `pvint`, `meanint`. Each is a record `{pre, multi, contour}`. The `INTOP` arm (`scholatex-math.lua:636-686`) reads the parenthesised `spec`, then captures the remaining body up to a top-level `=` via `find_top_eq` (so a body ending in an identity keeps the right-hand side outside the integral).

Behaviour by sub-form (all wrapped in `{\displaystyle ...}` at line 686):

- `int(x)` — single-letter spec → `\int ... \,\mathrm{d}x` (lines 680-681).
- `int(x=a, b)` — bounded → `\int_{a}^{b} ... \,\mathrm{d}x` (lines 675-678).
- `int(x=a, b ; y=c, d)` — `;`-separated specs → `\int_{a}^{b}\int_{c}^{d} ... \,\mathrm{d}y\,\mathrm{d}x` (Fubini-order: differentials in **reverse**, lines 650-666). Three specs → `\int\int\int`, same loop.
- `int(D)` — uppercase / non-single-letter spec → `\iint_{D} ... \,\mathrm{d}\omega` (line 664-665).
- `contourint(C)` → `\oint_{C} ... \,\mathrm{d}z` (lines 669-673; variable falls back to `z` if the spec is not a single lowercase letter).
- `pvint(x=a, b)` → `op.pre = "\mathrm{p.v.}\!\int"` (line 25).
- `meanint(x=a, b)` → `op.pre = "\fint"` (line 26). `\fint` is provided by the class preamble (`scholatex.cls:115-121`).

`surfint`, `volint`, `flux` are bespoke arms outside `INTOP`.

## Big operators with under-letter limits

`BIGOP` (`scholatex-math.lua:13`): `sum = \sum`, `prod = \prod`, `int = \int`. The `BIGOP` arm (`scholatex-math.lua:688-707`) emits `{\displaystyle \sum_{lo}^{hi} body}` — `\displaystyle` forces under-letter limits inside running text. Body parsing also stops at `find_top_eq` so the right-hand side of an identity stays outside.

`UNDEROP` (`scholatex-math.lua:14`): `lim = \lim`. The `UNDEROP` arm (`scholatex-math.lua:622-634`) emits `{\displaystyle \lim\limits_{x \to 0} body}`. The `\limits` is the TeX primitive that forces limits under the operator even in inline math.

`arrow(...)` (`scholatex-math.lua:616-620`) is its own arm: `\mathrel{\underset{...}{\longrightarrow}}`. Used for limit-arrow notation `u_n arrow(n to +inf) l`.

## Quantifiers, connectives, and the `!` rewriter

The forward (non-negated) forms live in `SYM` (`scholatex-math.lua:43-77`). Key entries (with the trailing space included in the LaTeX output):

| Source | Emits | Line |
|---|---|---|
| `forall` | `\forall ` | 45 |
| `exists` | `\exists ` | 45 |
| `and` / `land` | `\land ` | 47-48 |
| `or` / `lor` | `\lor ` | 47-48 |
| `lnot` | `\lnot ` | 48 |
| `neg` | `\neg ` | 49 |
| `implies` / `iff` / `impliedby` | `\implies ` / `\iff ` / `\impliedby ` | 50 |

`!` is a single runtime branch (`scholatex-math.lua:781-795`). Its two paths:

- `NEG` table (`scholatex-math.lua:82-89`): curated entries `in → \notin`, `exists → \nexists`, `subset → \not\subset`, `subseteq → \nsubseteq`, `equiv → \not\equiv`, `sim → \nsim`, `cong → \ncong`, `parallel → \mathbin{/\!/\mkern-12.5mu\backslash}`, `models → \nvDash`, `vdash → \nvdash`, `approx → \not\approx`.
- Fallback: if word is in `SYM` but not `NEG`, emit `\not<symbol>`.

`!=` is intercepted *before* the `!`-letter branch fires (top-level loop line 777), so it always emits `\neq`.

## Failure modes

Most `mathlite` errors come from argument-count violations on bespoke arms or `TWOARG`/`WRAP1` mismatches. The full list lives in the investigation report; the common ones:

- **Bare `angle`** (no `(`): `scholatex: angle s'utilise avec des points : angle(A) ou angle(ABC)` (French, `scholatex-math.lua:369`).
- **`circle` with wrong arg count**: `circle takes circle(O, r) (centre, radius) or circle(A, B, C) (three points); got N argument(s)` (`scholatex-math.lua:407-410`).
- **`frame` / `orthoframe` with fewer than 3 args**: `frame(O, i, j) needs an origin and at least two basis vectors` (`scholatex-math.lua:390-393, 450-453`).
- **`vector` / `colvec` with fewer than 2 components**: similar messages.
- **`triple` not exactly 3 args**.
- **`!word` where `word` is not in `SYM`**: `scholatex: '!FOO' is not a negatable symbol; ...`.

`TWOARG` keys called with the wrong arg count silently fall back to a verbatim function-call form `word .. "(" .. M.mathlite(raw) .. ")"` (`scholatex-math.lua:610-612`) — no error. So `collinear(u, v, w)` renders as `collinear(u, v, w)` rather than raising.

## Related

- `architecture/compile-pipeline.md` — how `forward_text` calls `mathlite` from the `$` arm and what the `#NAME` / `#{EXPR}` placeholder rewrite does (`scholatex.lua:194-217`).
- `architecture/figure-draw.md` — the name collisions with `triangle`, `circle`, `parallelogram`.
- `reference/math-vocabulary.md` (wave 2) — the full algebraic vocabulary catalogue.
- `reference/math-geometry-vocabulary.md` (wave 2) — the geometry-specific subset (kept separate because `examples/geometry.tex` is the only existing exercise surface for it, and the README does not document any of it).
