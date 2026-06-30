# How to Extend the Math Vocabulary

This guide is for adding a new named operator to the inline math mini-language (`scholatex-math.lua`) — for example, a new transform `Z(...)`, a new accent, a new fence, or a new bigop. The architecture is in `architecture/math-pipeline.md`; this guide is the imperative checklist.

## 1. Preconditions

### Choose the right table

`scholatex-math.lua` dispatches identifiers through 14 named maps plus a handful of bespoke `if word == "..."` arms. Pick the shape that matches your operator:

| Shape | Table | Source lines | Use when |
|---|---|---|---|
| One-arg wrapper with bespoke rendering | `WRAP1` | 143-163 | `transpose(A) → A^{\top}`, `factorial(n) → n!`, `bigO(g) → O\left(g\right)` |
| Two-arg primitive | `TWOARG` | 168-184 | `C(n,k) → \binom{n}{k}`, `distance(A,B) → d(A,B)`, `cov(X,Y) → \operatorname{Cov}(X,Y)` |
| Named upright operator | `NAMED` | 122-130 | `ker(f) → \operatorname{Ker}(f)`, `rank(A) → \operatorname{rg}(A)`, `grad(f) → \operatorname{grad}(f)` |
| Fence (one parenthesised arg, wrapped delimiters) | `FENCE` | 93-101 | `abs(x) → \left|x\right|`, `floor(x) → \left\lfloor x\right\rfloor`, `set(...) → \left\{ ... \right\}` |
| Accent over one arg | `ACCENT` | 106-116 | `vec(u) → \overrightarrow{u}`, `bar(z) → \overline{z}`, `hat(p) → \widehat{p}` |
| Forward symbolic relation | `SYM` | 43-77 | `subseteq → \subseteq`, `forall → \forall`, `approx → \approx` |
| Negated relation (curated glyph) | `NEG` | 82-89 | `!in → \notin`, `!cong → \ncong`. The `!` rewriter at `scholatex-math.lua:781-795` checks `NEG` first, falls back to `\not<symbol>` |
| Bigop (display-style with `(spec) body`) | `BIGOP` | 13 + arm 688-707 | `sum`, `prod`, `int` family. `_lo^hi body` shape, terminated by top-level `=` |
| Underop with `\limits` | `UNDEROP` | 14 + arm 622-634 | `lim` style. `\underset` under the operator |
| Integral with optional contour | `INTOP` | 22-27 + arm 636-686 | `int`, `contourint`, `pvint`, `meanint` — semicolon-separated specs for Fubini ordering |
| Variadic, bespoke render | own `if word == "..."` arm in `read_atom` | `scholatex-math.lua:354, 363, 373, 386, 403, 417, 430, 446, 534, 551, 565, 573, 577, 584, 591, 616` | `sqrt`, `angle`, `triangle`, `frame`, `circle`, `vector`, `colvec`, `orthoframe`, `taylor`, `jacobian`, `hessian`, `surfint`, `volint`, `flux`, `triple`, `arrow` |

### Check for name collisions

The full algebraic catalogue is in `reference/math-vocabulary.md`. The geometry-flavoured subset is in `reference/math-geometry-vocabulary.md`. Confirm no existing table already claims the name. Two specific gotchas:

- **Single letters collide with variables.** `o` and `O` cannot be wrappers because they are valid identifiers (this is why `bigO` and `litO` exist — `scholatex-math.lua:159-160`). Any one-letter name conflicts.
- **Three names collide with `<draw>` shapes.** `triangle`, `circle`, `parallelogram` exist in both layers. The math layer wins inside `$ ... $`; the `<draw>` block wins inside `<draw>{...}`. See `architecture/figure-draw.md` § "Name collisions". Adding a math operator for a shape name already in `<draw>` is OK but raises the cognitive load.
- **User `let` may shadow.** A user can `let circle = <Navy b>` and then `$circle$` would still resolve to your operator (math is its own dispatch path; `STYLE.classify_split` is not consulted inside `$ ... $`). But the inverse is not protected: a built-in math name has no `warn_if_shadows`. Pick a name unlikely to clash with reading flow.

## 2. Main steps

### Locate the right table

Open `scholatex-math.lua` and jump to the line range from the table above. Each map is declared as a local Lua table; entries are typically one line each. Read the surrounding comments for ordering invariants (the `MATCHERS` ordering in `scholatex-style.lua` has a precedent for "ordering is load-bearing"; the math tables do not have ordering issues because dispatch is by exact-key lookup).

### Add the entry

Use a minimal LaTeX template. Most entries are one line:

```lua
-- WRAP1 (around line 159)
mytransform = function(a) return "\\mathcal{M}\\left\\{" .. a .. "\\right\\}" end,

-- TWOARG (around line 175)
mycov = "\\operatorname{Cov}(%s, %s)",   -- the %s slots are filled by the dispatcher

-- NAMED (around line 127)
myop = "myop",   -- becomes \operatorname{myop}(arg)

-- FENCE (around line 100)
mybr = {"\\left[\\!\\!\\[", "\\right]\\!\\!\\]"},

-- ACCENT (around line 114)
breve = "\\breve",   -- becomes \breve{arg}

-- SYM (around line 64)
mysym = "\\mysymcmd ",   -- include trailing space; matches the SYM convention
```

If the operator needs upright (`\mathrm`) rendering, follow `M.differential` conventions at `scholatex-math.lua:186-199` — the rule there is that both numerator and denominator are checked before the `d` is rewritten to `\mathrm{d}`. For a brand-new differential-like operator, study that function and re-use its checking pattern.

For a bespoke arm with non-uniform argument shape, model the structure on `frame` (`scholatex-math.lua:386-398`) or `taylor` (`:534-548`): read the parenthesised group, split arguments via `U.split_commas`, validate the count, and assemble the LaTeX directly. Raise a clear error on bad arg counts.

### Test against `examples/math-*.tex`

These files are the canonical exercise corpus:

- `examples/math-language.tex` — number sets, quantifiers, set operations, negation, basic fences and accents.
- `examples/math-analysis.tex` — sums, products, limits, derivatives, integrals (basic).
- `examples/math-algebra.tex` — matrix blocks (`<matrix>`, `<det>`, `<bmatrix>`), `<system>`.
- `examples/analysis.tex` — fuller version of math-analysis with vector ops, Landau, transforms.
- `examples/algebra.tex` — fuller version with named operators (`ker`, `im`, `rank`, `span`, `tr`, `det`, `transpose`, `inv`, `com`, `eigen`, `adj`).
- `examples/probability.tex` — `C`, `A`, `PP`, `EE`, `var`, `cov`, `normal`, `binomial`, `poisson`, `repart`, `densite`.
- `examples/geometry.tex` — the inline geometry vocabulary (`angle`, `triangle`, `arc`, `frame`, `circle`, `vector`, `colvec`, `inner`, `distance`, `midpoint`, `triple`, `ortho`, `perp`, `parallel`, etc.).
- `examples/basics.tex` — broad sampler.

Pick the file matching your operator's domain. Add a new line to its appropriate `<box>` section with a `$...$` showing the operator in use, or create a new example file following `guides/write-example-document.md`.

## 3. Verification

1. Recompile the chosen `examples/*.tex` file: `lualatex examples/<file>.tex`.
2. Check spacing and display style. For limit-like operators verify `\limits` and `\underset` follow the existing `BIGOP` / `UNDEROP` pattern (`scholatex-math.lua:622-634, 688-707`).
3. For an extensible-parens operator that may sit inside `(...)`, test `(myop(...) + 1)/2` — the parent `(` arm at `scholatex-math.lua:298-319` checks for `\frac` and switches to `\left(...\right)`, so your operator should render correctly inside an extensible group.
4. If you added a `WRAP1` / `TWOARG` entry whose name is also a variable letter, test ambiguity cases: `myop` followed by `(` is a call; `myop` not followed by `(` may need fallback handling. `TWOARG` entries default to verbatim function-call form on wrong arg count (`scholatex-math.lua:610-612`) — no error is raised. Decide whether you want strict arg-count checking via a bespoke arm.
5. Confirm decimal-separator behaviour if the operator emits literal numbers: `MATH.decsep` is `.` in `lang=en` and `{,}` in default `lang=fr` (`scholatex.lua:692-693`, `scholatex-math.lua:744`).

## 4. Common failure points

| Symptom | Likely cause |
|---|---|
| Operator collides with a single-letter variable (`o`, `O`) | The lexer greedy-matches `^(%a+)` so `O` then `(`-call is a function call shape — but the same letter as a variable will silently route to the dispatcher. Use `bigO` / `litO`-style prefixes |
| User `let N = 5` then `$N$` gives blackboard-bold | The lexer greedy-matches `^(%a+)`; `NN` is blackboard, single `N` stays a variable. But a user who `let N = ...` does not change the math layer — `let` only mutates `ALIAS` / `MACRO` / `BLOCKALIAS`, never the math dispatch tables. Math identifiers are inert to user `let` |
| `^` / `_` bind tighter than `/` and surprise the writer | The fraction `/` arm pops a script-finished atom (`scholatex-math.lua:802`); scripts always glue first. `x^2/y` is `\frac{x^{2}}{y}`. Document this in the operator's example |
| Operator parses but renders without spacing in display | Forgot the trailing space in a `SYM` entry. The convention is `mysym = "\\mysym ",` with the trailing space — see `scholatex-math.lua:43-77` |
| `mathlite` raises a French error on bad input | Three existing solver messages are in French (`angle`, `Tri.isosceles`, `Tri.sss`, `Tri.asa`). For new operators, write English error strings to match the project's standard |
| Operator silently breaks the rest of a formula | A bespoke arm forgot to advance the cursor `pos` past the closing `)`. Check that every branch ends with `pos = after` or `pos = matching_close + 1` |

## 5. Related docs

- `architecture/math-pipeline.md` — the tokeniser, recursive-descent ladder, all 14 dispatch tables, and the bespoke arms.
- `reference/math-vocabulary.md` — the full catalogue grouped by table.
- `reference/math-geometry-vocabulary.md` — the geometry-flavoured subset.
