# Math Vocabulary Reference

## Scope

Every named word listed below is recognised by the inline-math compiler `mathlite` and rewritten to LaTeX whenever it appears inside a `$ ... $` span. Catalogue source: `scholatex-math.lua` (declarations) and `scholatex-math.lua:293` `read_atom` / `scholatex-math.lua:753` top-level loop (dispatchers).

The mini-language is **not a registered tag** — `scholatex-math.lua` calls neither `sl.register_tag` nor `sl.register_block`. The compiler is invoked once, from the `$` arm of `forward_text` at `scholatex.lua:219`, and re-exposed as `sl._mathlite` at `scholatex.lua:777` for cell-level math (matrix, table, vartab, plot cells).

For the dispatcher and tokeniser internals — script-vs-fraction precedence, ISO 80000-2 upright-d, the extensible-parenthesis heuristic — see `architecture/math-pipeline.md`. This reference only lists the surface contract: which source word produces which LaTeX.

The geometry subset (e.g. `angle`, `triangle`, `vec(u).vec(v)`, `perp`, `parallel`) lives in `reference/math-geometry-vocabulary.md`.

## Family tables

Every row cites the declaration line in `scholatex-math.lua`. Each entry is keyed by the source word the user types inside `$ ... $`; the rendered LaTeX is what `mathlite` emits.

### Number sets (blackboard bold, doubled letters)

Declared in `BBSET` (`scholatex-math.lua:32-37`); dispatcher arm `scholatex-math.lua:351`. Because the lexer greedy-matches a letter run, a single `N`/`R`/`P`/`E`/`K`/`H`/`F`/`U` stays an ordinary variable — the doubling is the disambiguator.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `NN` | 0 | `\mathbb{N}` | 33 | naturals |
| `ZZ` | 0 | `\mathbb{Z}` | 33 | integers |
| `DD` | 0 | `\mathbb{D}` | 33 | decimals |
| `QQ` | 0 | `\mathbb{Q}` | 34 | rationals |
| `RR` | 0 | `\mathbb{R}` | 34 | reals |
| `CC` | 0 | `\mathbb{C}` | 34 | complex |
| `PP` | 0 | `\mathbb{P}` | 35 | probability (also accepts `PP(A)` form via the bare doubled letter followed by `(`) |
| `KK` | 0 | `\mathbb{K}` | 35 | base field |
| `HH` | 0 | `\mathbb{H}` | 35 | quaternions / half-plane |
| `FF` | 0 | `\mathbb{F}` | 36 | finite field |
| `EE` | 0 | `\mathbb{E}` | 36 | expectation |
| `UU` | 0 | `\mathbb{U}` | 36 | unit circle |

### Quantifiers and logical connectives

Declared in `SYM` (`scholatex-math.lua:45-50`); dispatcher arm `scholatex-math.lua:729`. Every emitted LaTeX carries a trailing space.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `forall` | 0 | `\forall ` | 45 | |
| `exists` | 0 | `\exists ` | 45 | |
| `and` | 0 | `\land ` | 47 | |
| `or` | 0 | `\lor ` | 47 | |
| `land` | 0 | `\land ` | 48 | alias of `and` |
| `lor` | 0 | `\lor ` | 48 | alias of `or` |
| `lnot` | 0 | `\lnot ` | 48 | |
| `neg` | 0 | `\neg ` | 49 | alias of `lnot` |
| `xorsym` | 0 | `\oplus ` | 49 | |

### Implication and equivalence

Two forms: word forms in `SYM` (`scholatex-math.lua:50`), and the chevron symbolic literals intercepted in the top-level loop before the word lookup (`scholatex-math.lua:762-778`). The chevron forms are longest-match-first, so `<=>` always beats `<=`.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `implies` | 0 | `\implies ` | 50 | word form |
| `=>` | 0 | `\Rightarrow` | 767 | symbolic literal |
| `iff` | 0 | `\iff ` | 50 | word form |
| `<=>` | 0 | `\Leftrightarrow` | 763 | symbolic literal |
| `impliedby` | 0 | `\impliedby ` | 50 | word form |
| `<-` | 0 | `\leftarrow` | 775 | symbolic literal |
| `<->` | 0 | `\leftrightarrow` | 765 | symbolic literal |
| `<=` | 0 | `\leq` | 769 | symbolic literal |
| `>=` | 0 | `\geq` | 771 | symbolic literal |
| `->` | 0 | `\to` | 773 | symbolic literal |

Chevron handling depends on the body-syntax escape rule (a leading `<` is parsed as the head of a tag unless followed by `=`, `<`, `-`, etc.). See `reference/body-syntax-rules.md` § "Chevron escape" before relying on `<-` or `<=` at the start of a line.

### Set membership, relations, and operations

Declared in `SYM` (`scholatex-math.lua:52-57`); dispatcher arm `scholatex-math.lua:729`.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `in` | 0 | `\in ` | 52 | |
| `ni` | 0 | `\ni ` | 52 | reversed `in` |
| `subset` | 0 | `\subset ` | 53 | |
| `supset` | 0 | `\supset ` | 53 | |
| `subseteq` | 0 | `\subseteq ` | 54 | |
| `supseteq` | 0 | `\supseteq ` | 54 | |
| `cup` | 0 | `\cup ` | 55 | |
| `cap` | 0 | `\cap ` | 55 | |
| `union` | 0 | `\cup ` | 57 | alias of `cup` |
| `inter` | 0 | `\cap ` | 57 | alias of `cap` |
| `setminus` | 0 | `\setminus ` | 56 | |
| `emptyset` | 0 | `\varnothing ` | 56 | |

### Integer-part wrappers (`FENCE`)

Declared in `FENCE` (`scholatex-math.lua:93-101`); dispatcher arm `scholatex-math.lua:485`. Each takes exactly one parenthesised argument.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `floor(x)` | 1 | `\left\lfloor x\right\rfloor` | 96 | |
| `ceil(x)` | 1 | `\left\lceil x\right\rceil` | 97 | |
| `round(x)` | 1 | `\left\lfloor x\right\rceil` | 98 | asymmetric brackets — round to nearest |
| `abs(x)` | 1 | `\left|x\right|` | 94 | absolute value |
| `norm(v)` | 1 | `\left\|v\right\|` | 95 | norm |

### One-argument wrappers and accents

Declared in `FENCE` (`scholatex-math.lua:99-100`) and `ACCENT` (`scholatex-math.lua:106-116`); dispatcher arms `scholatex-math.lua:485` and `scholatex-math.lua:462`. Each takes one parenthesised argument that is re-cooked through `mathlite`.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `set(...)` | 1 | `\left\{...\right\}` | 99 | also rewrites bare `\|` to `\mid ` for set-builder notation (`scholatex-math.lua:488-490`) |
| `abr(...)` | 1 | `\left\langle ... \right\rangle` | 100 | inner-product / angle brackets |
| `bar(x)` | 1 | `\overline{x}` | 107 | |
| `conj(x)` | 1 | `\overline{x}` | 109 | alias — complex conjugate |
| `not(x)` | 1 | `\overline{x}` | 108 | reads as "bar over" (negation in propositional sense) |
| `hat(x)` | 1 | `\widehat{x}` | 111 | wide hat |
| `tilde(x)` | 1 | `\widetilde{x}` | 112 | wide tilde |
| `dotacc(x)` | 1 | `\dot{x}` | 113 | first time-derivative dot |
| `ddotacc(x)` | 1 | `\ddot{x}` | 114 | second time-derivative dot |
| `underbar(x)` | 1 | `\underline{x}` | 115 | |

`vec` is also in `ACCENT` (`scholatex-math.lua:110`) but carries the dot/cross-product postfix rule used by geometry. See `reference/math-geometry-vocabulary.md`.

### Negation by `!` prefix

The `!`-prefix branch lives in the top-level loop (`scholatex-math.lua:781-795`). It runs in two paths:

1. **Curated `NEG` table** (`scholatex-math.lua:82-89`) — native *amssymb* glyphs preferred over a struck-through `\not`.
2. **Fallback `\not<word>`** — any `SYM[word]` not in `NEG` is rewritten as `\not<symbol>`. So `!forall` becomes `\not\forall ` (legal but visually weak).

`!=` is a separate top-level branch (`scholatex-math.lua:777`) intercepted before `!`-letter resolution; it always emits `\neq`.

| source | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `!in` | 0 | `\notin ` | 83 | |
| `!exists` | 0 | `\nexists ` | 83 | |
| `!subset` | 0 | `\not\subset ` | 84 | |
| `!subseteq` | 0 | `\nsubseteq ` | 85 | |
| `!equiv` | 0 | `\not\equiv ` | 86 | |
| `!=` | 0 | `\neq` | 777 | top-level symbolic, not via `NEG` |
| `!parallel` | 0 | `\mathbin{/\!/\mkern-12.5mu\backslash}` | 87 | also used by `reference/math-geometry-vocabulary.md` |
| `!cong` | 0 | `\ncong ` | 86 | |
| `!sim` | 0 | `\nsim ` | 86 | |
| `!<any other SYM word>` | 0 | `\not<symbol>` | 789 | runtime fallback; works on any `SYM` entry but is ugly |

Errors: `!FOO` where `FOO` is in neither `NEG` nor `SYM` raises `scholatex: '!FOO' is not a negatable symbol; ...` (`scholatex-math.lua:792-794`).

### Limit arrow

A bespoke arm — not in any table.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `arrow(spec)` | 1 (parenthesised) | `\mathrel{\underset{spec}{\longrightarrow}}` | 616-620 | the body is re-cooked through `mathlite`; used for limit-arrow notation `u_n arrow(n to +inf) l` |

### Counting

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `C(n, k)` | exactly 2 | `\binom{n}{k}` | 169 (`TWOARG`) | binomial coefficient. With any arity other than 2 the call falls back to the verbatim form `C(...)` (`scholatex-math.lua:610-612`) |
| `A(n, k)` | exactly 2 | `A_{n}^{k}` | 170 (`TWOARG`) | arrangement count (French convention); same fallback rule |
| `factorial(n)` | 1 | `n!` | 155 (`WRAP1`) | |
| `n!` | n/a | passed through as written | n/a | `!` after a digit-or-letter token is not rewritten — `mathlite` does not special-case factorial; the literal `!` is emitted only by the `!`-prefix path |

### Linear algebra (named upright operators)

Declared in `NAMED` (`scholatex-math.lua:122-130`); dispatcher arm `scholatex-math.lua:516`. Each requires a parenthesised argument (`s:sub(after, after) == "("`); without a `(` the word falls through to the regular identifier path.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `ker(f)` | 1 | `\operatorname{Ker}\left(f\right)` | 126 | also a `FUNC` entry (line 20); the `NAMED` path wins when `(` follows |
| `im(f)` | 1 | `\operatorname{Im}\left(f\right)` | 126 | |
| `rank(A)` | 1 | `\operatorname{rg}\left(A\right)` | 126 | French "rang" |
| `span(...)` | 1 | `\operatorname{Span}\left(...\right)` | 127 | |
| `tr(A)` | 1 | `\operatorname{tr}\left(A\right)` | 126 | trace |
| `com(A)` | 1 | `\operatorname{com}\left(A\right)` | 127 | comatrix |
| `eigen(A)` | 1 | `\operatorname{Sp}\left(A\right)` | 127 | spectrum |
| `adj(A)` | 1 | `\operatorname{adj}\left(A\right)` | 127 | adjoint |
| `transpose(A)` | 1 | `A^{\top}` | 149 (`WRAP1`) | |
| `inv(A)` | 1 | `A^{-1}` | 150 (`WRAP1`) | |

### Differential operators

Declared in `NAMED` (`scholatex-math.lua:129`) and `SYMOP`/`TWOARG`; dispatcher arms `scholatex-math.lua:516` and `scholatex-math.lua:497` / `:603`.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `grad(f)` | 1 | `\operatorname{grad}\left(f\right)` | 129 | |
| `div(F)` | 1 | `\operatorname{div}\left(F\right)` | 129 | |
| `curl(F)` | 1 | `\operatorname{rot}\left(F\right)` | 129 | French "rotationnel" |
| `lap f` | 1 (bare or parenthesised) | `\Delta f` for a single token; `\Delta\left(...\right)` for compound | 137 (`SYMOP`) | the "simple operand" heuristic checks for a single token (lines 510-511) |
| `dirderiv(f, u)` | exactly 2 | `\nabla_{u} f` | 177 (`TWOARG`) | directional derivative |

### Landau notation

Declared in `WRAP1` (`scholatex-math.lua:159-160`); dispatcher arm `scholatex-math.lua:528`. Single-letter `o` and `O` are deliberately kept as free variables — use the named forms.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `bigO(g)` | 1 | `O\left(g\right)` | 159 | Landau big-O |
| `litO(g)` | 1 | `o\left(g\right)` | 160 | Landau little-o |

### Transforms

Declared in `WRAP1` (`scholatex-math.lua:145-148`); dispatcher arm `scholatex-math.lua:528`.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `laplace(f)` | 1 | `\mathcal{L}\left\{f\right\}` | 145 | |
| `fourier(f)` | 1 | `\mathcal{F}\left\{f\right\}` | 146 | |
| `ilaplace(f)` | 1 | `\mathcal{L}^{-1}\left\{f\right\}` | 147 | |
| `ifourier(f)` | 1 | `\mathcal{F}^{-1}\left\{f\right\}` | 148 | |

### Integrals

Driven by `INTOP` (`scholatex-math.lua:22-27`) and the `INTOP` arm at `scholatex-math.lua:636-686`. The output is wrapped in `{\displaystyle ...}` (`scholatex-math.lua:686`) to force under-letter limits inline.

Body parsing stops at the first top-level `=` (via `find_top_eq`, `scholatex-math.lua:246`) so an identity keeps its right-hand side outside the integral.

| syntactic form | LaTeX core | source line | notes |
|---|---|---|---|
| `int(x) body` | `\int body \,\mathrm{d}x` | 22, 680 | single letter → unbounded with differential `dx` |
| `int(x=a, b) body` | `\int_{a}^{b} body \,\mathrm{d}x` | 22, 675 | bounded |
| `int(D) body` | `\iint_{D} body \,\mathrm{d}\omega` | 22, 664 | uppercase / non-single-letter spec → domain integral, double sign |
| `int(x=a, b ; y=c, d) body` | `\int_{a}^{b}\int_{c}^{d} body \,\mathrm{d}y\,\mathrm{d}x` | 650-666 | `;`-separated specs; differentials emitted in **reverse** order (Fubini) |
| `contourint(C) body` | `\oint_{C} body \,\mathrm{d}z` | 24, 669 | variable falls back to `z` if spec is not a single lowercase letter |
| `pvint(x=a, b) body` | `\mathrm{p.v.}\!\int_{a}^{b} body` | 25 | Cauchy principal value |
| `meanint(x=a, b) body` | `\fint_{a}^{b} body` | 26 | `\fint` provided by `scholatex.cls` preamble; mean integral |
| `surfint(S) body` | `\oiint_{S} body` | 573 | bespoke arm, outside `INTOP` |
| `volint(V) body` | `\iiint_{V} body` | 577 | bespoke arm |
| `flux(F, S)` | `\iint_{S} F\cdot\mathrm{d}\overrightarrow{S}` | 584 | bespoke arm |

### Probability

Declared across `WRAP1`, `TWOARG`, and `SYM`; dispatchers `scholatex-math.lua:528` and `:603`.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `PP(...)` | 1 (parenthesised after `BBSET`) | `\mathbb{P}(...)` | 35 (`BBSET`) | the doubled-letter resolves first; `(...)` is then a regular juxtaposed group passed through `mathlite` |
| `EE(...)` | 1 | `\mathbb{E}(...)` | 36 (`BBSET`) | expectation; same pattern |
| `var(X)` | 1 | `\operatorname{Var}(X)` | 153 (`WRAP1`) | variance |
| `std(X)` | 1 | `\sigma(X)` | 154 (`WRAP1`) | standard deviation |
| `cov(X, Y)` | exactly 2 | `\operatorname{Cov}(X, Y)` | 171 (`TWOARG`) | covariance |
| `normal(mu, sigma)` | exactly 2 | `\mathcal{N}\left(mu, sigma^{2}\right)` | 173 (`TWOARG`) | Gaussian — note `sigma^{2}` is inserted as the variance |
| `poisson(lambda)` | 1 | `\mathcal{P}\left(lambda\right)` | 156 (`WRAP1`) | Poisson |
| `binomial(n, p)` | exactly 2 | `\mathcal{B}\left(n, p\right)` | 174 (`TWOARG`) | binomial law |
| `repart(X, x)` | exactly 2 | `F_{X}(x)` | 175 (`TWOARG`) | CDF (French "fonction de répartition") |
| `densite(X, x)` | exactly 2 | `f_{X}(x)` | 176 (`TWOARG`) | density (French spelling) |
| `mid` | 0 | `\mid ` | 57 (`SYM`) | the spaced conditional bar (`PP(A mid B)`). Also serves as the set-builder bar inside `set(...)`; see `set` in § "One-argument wrappers and accents" |

### Number theory and combinatorial sets

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `euler(n)` | 1 | `\varphi(n)` | 151 (`WRAP1`) | Euler totient |
| `mobius(n)` | 1 | `\mu(n)` | 152 (`WRAP1`) | Möbius |
| `equiv ... mod ...` | 0 + 1 | `\equiv ... \pmod{...}` | 61 (`SYM`), 722 (`mod` arm) | `equiv` emits `\equiv `; `mod` consumes the next atom and wraps as `\pmod{...}` (`scholatex-math.lua:722-726`) |
| `lcm(a, b)` | 1 (single arg) | `\operatorname{lcm}\left(a, b\right)` | 124 (`NAMED`) | the arg is a re-cooked `mathlite` expression so a comma works |
| `sign(x)` | 1 | `\operatorname{sgn}\left(x\right)` | 124 (`NAMED`) | |
| `card(A)` | 1 | `\operatorname{card}\left(A\right)` | 124 (`NAMED`) | cardinality |
| `powerset(A)` | 1 | `\mathcal{P}(A)` | 144 (`WRAP1`) | power set |
| `range(1, n)` | exactly 2 | `\lBrack 1, n\rBrack ` | 172 (`TWOARG`) | integer range — `\lBrack`/`\rBrack` provided by `scholatex.tex:30-42` preamble |
| `mid` (set-builder bar) | 0 | `\mid ` | 57 (`SYM`) | inside `set(x mid x > 0)`. The shortcut `set(x | x > 0)` is also accepted: the `set` arm rewrites bare `\|` to `\mid ` (`scholatex-math.lua:488-490`) |

### Templates (no computation)

These three emit a fixed visual form — no symbolic differentiation or expansion is performed. Each enforces an exact argument count.

| name | arity | LaTeX template | source line | notes |
|---|---|---|---|---|
| `taylor(f, x, a, n)` | exactly 4 | `f(a)+f'(a)(x-a)+\dots+\dfrac{f^{(n)}(a)}{n!}(x-a)^{n}+o\left((x-a)^{n}\right)` | 534-548 | wrong arity raises an error |
| `jacobian(f, n)` | exactly 2 | `\left(\dfrac{\partial f_{i}}{\partial x_{j}}\right)_{1\le i,j\le n}` | 551-563 | |
| `hessian(f, n)` | exactly 2 | `\left(\dfrac{\partial^{2} f}{\partial x_{i}\,\partial x_{j}}\right)_{1\le i,j\le n}` | 565-567 | |

## Pitfalls

- **Single-letter `o` and `O` are kept free.** They are ordinary variables — use `litO(g)` and `bigO(g)` for the Landau forms (`scholatex-math.lua:159-160`).
- **The ISO 80000-2 upright-d rule.** When the user writes `dy/dx`, `M.differential` (`scholatex-math.lua:186-199`) rewrites both leading `d`s to `\mathrm{d}` only if the numerator matches `^d`, `^d%a`, or `^d%^` AND the denominator matches `^d%a`. So `d/2` stays `\frac{d}{2}` (a variable). For `\partial` both sides are returned as-is. The CHANGELOG 2.2 repair makes `d^2 y / dx^2` read identically to the parenthesised `(d^2 y)/(d x^2)` by rejoining the script-split `d^{2}` with the following atom at the `/` arm (`scholatex-math.lua:810-815`). See `architecture/math-pipeline.md` § "Derivatives and `M.differential`" for the full handling.
- **Extensible parentheses around a fraction.** The `(` arm uses a literal string-search for `\frac` inside the already-cooked body (`scholatex-math.lua:298-319`). Hit → `\left(`/`\right)` extensible pair; miss → ordinary `(` and `)`. So `(a/b)^2` grows tall (the body contains `\frac`), but `f(-x)` stays flat (no `\frac`). See `architecture/math-pipeline.md` § "Extensible parentheses over a fraction".
- **No precedence table.** `^`/`_` bind tighter than `/` because scripts are folded into the atom before the `/` arm pops it as the numerator. This is the CHANGELOG 1.2 fix; see `architecture/math-pipeline.md` § "Recursive descent (no precedence table)".
- **Colour words inside math are not colour-classified.** Colour parsing lives in `scholatex-style.lua` (`scholatex-style.lua:194-201`) and fires only on tag attributes. A literal `red` inside `$ ... $` falls through the identifier path (`scholatex-math.lua:736`) and is emitted as the variable `red`. The CHANGELOG 2.1 BREAKING about CamelCase colours is about tag attributes only, not about math content.

## Known issues

The full doc-vs-code gap list is in `memory/doc-gaps.md` § "Other undocumented math vocabulary":

- Many `SYM` relations (`approx`, `equiv`, `propto`, `sim`, `cong`, `mapsto`, `ldots`, `cdots`, `vdots`, `ddots`, `dots`, `times`, `cdot`, `pm`, `mp`, `ast`, `circop`, `star`, `bullet`, `aleph`, `wp`, `Real`, `Imag`, `Top`, `Bot`, `models`, `vdash`, `thus`, `because`) are recognised but absent from `README.md` and `scholatex.tex`.
- The `round` fence is mentioned only in `CHANGELOG.md:722` (CHANGELOG 2.1) — it is absent from the basics math table at `README.md:222-247` and `scholatex.tex:639-671`.
- `ni`, `union`/`inter`, `dotacc`/`ddotacc`/`underbar`, `hom`, `xorsym` are recognised but undocumented.
- `!word` fallback can emit ugly `\not\forall ` style output — no allow-list restricts which `SYM` entries are negatable.
- Several error messages remain in French (e.g. `scholatex-math.lua:369-370` for bare `angle`).

## See also

- `reference/math-geometry-vocabulary.md` — the geometry subset (`angle`, `triangle`, `arc`, `frame`, `vec(u).vec(v)`, `perp`, `parallel`, ...), kept separate because it is undocumented in `README.md` and only exercised in `examples/geometry.tex`.
- `architecture/math-pipeline.md` — the parser dispatcher, the precedence ladder, the ISO 80000-2 rule, the extensible-parenthesis heuristic.
- `reference/body-syntax-rules.md` — chevron escape, auto-escape characters, the `$ ... $` boundary.
