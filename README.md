# scholatex

**Print-ready teaching worksheets, without writing LaTeX.** — A small, consistent tag language for the documents a teacher actually makes.

[![CTAN](https://img.shields.io/badge/CTAN-scholatex-d35400?style=flat-square)](https://ctan.org/pkg/scholatex)
[![Version](https://img.shields.io/badge/version-2.3-2980b9?style=flat-square)](https://ctan.org/pkg/scholatex)
[![Engine](https://img.shields.io/badge/engine-LuaLaTeX-1F3A5F?style=flat-square)](https://www.luatex.org/)
[![TeX Live](https://img.shields.io/badge/TeX_Live-included-27ae60?style=flat-square)](https://tug.org/texlive/)
[![License](https://img.shields.io/badge/license-GPL_v3+-8e44ad?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)

## Why scholatex?

Write a single `.tex` file with a tiny, readable syntax and get a clean, print-ready worksheet — framed exercises, a results table, simple formulas, an image — without `\begin{tabular}{|c|c|}`, without counting ampersands, without remembering which package draws a coloured box.

```latex
% !TeX program = lualatex
\documentclass[margins=20, size=12]{scholatex}
\begin{document}

<Navy b 18pt c>My first scholatex document

This is a normal paragraph. <b>{Bold}, <i>{italic}, <Red>{red}.

<box line:Navy fill:AliceBlue radius:3 title:{A framed note}>{
Boxes, tables, images and maths all use the same tag syntax.
}

\end{document}
```

Compile with `lualatex myfile.tex` — the `scholatex` class reads the body between `\begin{document}` and `\end{document}`, transpiles it to LaTeX, and typesets it. The output has full LaTeX quality; the syntax is meant to be read and edited in minutes by someone who does not know LaTeX. scholatex is a **closed language**: the backslash is an ordinary character, so raw LaTeX commands in the body are typeset literally rather than executed. Everything a worksheet needs is expressed through tags, which keeps documents consistent and safe to share.

## Quick start

```bash
tlmgr install scholatex      # add sudo on macOS/Linux; see Installation below
```

```latex
\documentclass[margins=20, size=12, lang=en]{scholatex}
\begin{document}
<Navy b section>First topic
A paragraph with <b>{bold} and <Red>{colour}.
\end{document}
```

## Key features

- **🏷️ One tag syntax** — `<attributes>{content}` covers text, tables, images, maths, boxes, lists and full-page layouts
- **🎨 151 colours** — the full CSS / svgnames palette in CamelCase, 22 of them with a lowercase shortcut
- **📐 A maths mini-language** — fractions, roots, sums, products, integrals, derivatives, trigonometry, matrices and systems, all in `$...$`
- **📦 Framed boxes & grids** — coloured `<box>` panels and CSS-Grid-style named-area page layouts
- **📊 Tables without pain** — two-letter cell placement, spans, headers, borders, no ampersand counting
- **♻️ Aliases & macros** — factor a style once, name it everywhere; one edit restyles the whole document
- **🔁 Control flow** — loops, conditionals and `#{...}` interpolation in the document body
- **🔒 Sandbox option** — `untrusted=true` runs document Lua in a restricted environment

---

## The one rule

Everything is a **tag**: `<attributes>` followed either by `{content}` (inline) or by a line that ends in `{` (a block). Attribute words follow a single case convention:

| Form | Meaning | Examples |
|------|---------|----------|
| `lowercase` | a short keyword (style, alignment, skip) | `b`, `i`, `c`, `2tab` |
| `CamelCase` | an extended CSS colour (151 of them) | `SteelBlue`, `Crimson` |
| `UPPERCASE` | a font name | `DEJAVU SANS` |

The order of words inside a tag never matters — emission is always normalised (page break, then vertical skips, then alignment, then tabs, then styles).

---

## Installation

`scholatex` is on CTAN and ships with TeX Live, so on a current, fully updated TeX Live or MacTeX it is already there — compile with `lualatex` and nothing more is needed. If your installation predates the package, install it once with the TeX Live manager; the same two commands work on **macOS, Linux and Windows**:

```bash
tlmgr update --self
tlmgr install scholatex
```

On macOS (MacTeX) and most Linux setups `tlmgr` needs administrator rights, so prefix both with `sudo`. On Windows, open the *TeX Live Command-Line* (or a terminal as Administrator) and run them without `sudo`. MiKTeX users install through the MiKTeX Console (*Packages* → search `scholatex` → *Install*), or with `mpm --install=scholatex`.

`tlmgr update --self` comes first because the manager refuses to install packages when its own version is older than the repository's. After installing, check the class is found:

```bash
kpsewhich scholatex.cls
```

It should print a path under your TeX tree. From then on `\documentclass{scholatex}` works from any folder.

If `tlmgr install scholatex` reports the package is *not present in the repository*, your mirror has not yet synced a recent release; either wait a day or switch to the main CTAN mirror and retry:

```bash
sudo tlmgr option repository https://mirror.ctan.org/systems/texlive/tlnet
sudo tlmgr update --self
sudo tlmgr install scholatex
```

### Manual install (any OS, no waiting)

To use the package immediately without `tlmgr`, drop the files into your personal TeX tree, mirroring the CTAN layout, then refresh the filename database. The home tree is `~/Library/texmf` on macOS, `~/texmf` on Linux, and `%USERPROFILE%\texmf` on Windows:

```bash
mkdir -p ~/texmf/tex/luatex/latex/scholatex
cp scholatex.cls scholatex.lua scholatex-*.lua ~/texmf/tex/luatex/latex/scholatex/
mktexlsr ~/texmf
```

A LuaLaTeX engine is required (`lualatex`); the package does **not** compile with `pdflatex` or `xelatex`.

---
## Class options

Set in `\documentclass[...]{scholatex}`:

| Option | Default | Meaning |
|--------|---------|---------|
| `margins` | `20` | `N` (all sides) or `{top,right,bottom,left}` in mm |
| `font` | `Latin Modern Roman` | main text font |
| `mathfont` | `Latin Modern Math` | math font |
| `size` | `11` | base font size in pt |
| `imgdir` | `img` | folder(s) searched for bare image names; comma-separated list, e.g. `{IMG, IMAGES/PNG}` |
| `tabwidth` | `8` | width of one tab, in mm (a large Seyès square) |
| `lineheight` | `8` | height of one explicit line skip (`<line>`, `<Nlines>`), in mm |
| `linespread` | `1.0` | overall line spacing (1.5 = one-and-a-half); tall maths never touches even at 1.0 |
| `scriptscale` | `100` | scale (%) of `up`/`down` scripts |
| `padding` | `2` | inner padding (mm) between a box/grid frame and its content; override locally with `sep:N` |
| `lang` | `fr` | decimal separator: `fr` (comma) or `en` (point); affects typed and interpolated decimals alike |
| `untrusted` | `false` | run document Lua in a restricted sandbox — see [Security](#security) |

Headings carry no extra vertical space or built-in colour: to style one, fold a heading keyword into an alias, e.g. `let h = <line Navy b section>` then `<h>My title`.

---

## Text attributes

**Inline styles** — `b` bold, `i` italic, `u` underline, `emph`, `sf` sans-serif, `sc` small caps. They combine in one tag: `<b i red>{bold italic red}`.

**Colours** — a colour is always one of the 151 CSS colours, written in CamelCase: `Navy`, `Red`, `Tomato`, `SteelBlue`, `ForestGreen`, …. One rule, no lowercase shortcuts — the everyday colours are simply capitalised (`Red`, `Blue`, `Green`, `Gray`). See the [colour reference](#colour-reference).

**Fonts and sizes** — a font name in CAPITALS (`<DEJAVU SANS>{…}`); sizes as `Npt` or `Npx` (`<14pt>{…}`).

**Alignment** — `l` left, `c` centre, `r` right, `j` justified.

**Tabs and skips** (the number is always a prefix) — `Ntab` indents the first line by N tabs; vertical skips obey singular/plural agreement: `line` or `1line` skips one, `2lines`, `3lines`, … skip several. Bare `tab` = `1tab`.

**Scripts** — `upN` raises text by N mm, `downN` lowers it: `x<up4>{2}`, `H<down2>{2}O`.

**Page break** — `nextpage`.

**Section headings** — `section`, `subsection`, `subsubsection` give the three levels, numbered automatically:

```
<section>First topic
<subsection>A detail
<subsubsection>A finer point
```

renders as `1 First topic`, `1.1 A detail`, `1.1.1 A finer point`. A **table of contents** is printed with `<tableofcontents>`; give it a title in braces: `<tableofcontents>{Table of contents}`.

**Numbering style** — by default the numbers are hierarchical (`1`, then `1.1`, then `1.1.1`). A counter keyword on a heading changes the style of *that* level, on its own — no inherited prefix: `num` (1, 2, 3), `roman` (i, ii, iii), `ROMAN` (I, II, III), `alpha` (a, b, c), `ALPHA` (A, B, C). For example `let study = <Navy b section ROMAN>` and `let step = <Navy b subsection num>` give sections `I`, `II` and, under each, steps `1`, `2`, `3` (not `I.1`). Each level is independent; without a keyword, the default hierarchical numbering stands.

---

## Aliases and macros — the factoring tool

Define a style **once**, at the top of the document, then name it everywhere instead of repeating its attributes. One edit at the definition restyles the whole document.

```
let title = <Navy b 18pt c>          % style alias
let h1    = <Navy b section>         % a heading style, reusable
let p     = <tab>                    % a standard indented paragraph
<title>My heading
<h1>First topic
<p>{ A paragraph, indented and justified, named not described. }

let n = 7                            % value, usable in #{...}
Seven squared is #{n*n}.

let greet{name} = Hello #name!       % text macro with parameters
```

Change `let h1 = <Navy b section>` to `<ForestGreen b section>` once and **every** first-level heading follows — the single point of control that keeps a long worksheet consistent.

---

## Tables

Columns are declared in brackets, **one two-letter placement code per column**. The first letter is vertical (`t`/`m`/`b`), the second horizontal (`l`/`c`/`r`): `mc` is middle-centre, `br` bottom-right. This is the only placement syntax scholatex uses — in tables as in boxes and grids.

```
<table [mc, ml, mc, mc] borders header fill:AliceBlue line:Navy headerfill:Navy headertext:White>{
<colspan:4 mc>{Term report}
Day | Subject | Mark | Coef.
<rowspan:2 mc>{Monday} | Maths | 15 | 4
. | French | 12 | 3
}
```

One row per line, `|` between cells. `<colspan:N>` and `<rowspan:N>` span cells; `.` marks a cell covered by a span above. `N:` before a placement code fixes a column width in mm.

---

## Images

```
<img 30>{photo.png}        % 30 mm wide
<img 40x25>{photo.png}     % 40 mm × 25 mm
<img>{photo.png}           % full available width, never enlarged
```

A bare name is searched in each folder of `imgdir` in turn, then at the project root. An explicit path always works (`<img 20>{IMG/PNG/chat.png}`).

---
## Maths

Wrap maths in `$…$`. A small mini-language keeps it light:

| You write | You get |
|-----------|---------|
| `*` | × |
| `+-` | ± |
| `<=` `>=` `!=` | ≤ ≥ ≠ |
| `a/b` | fraction (chained `a/b/c` reads as `(a/b)/c`) |
| `x^2` `x_i` | power / index (bind tighter than `/`, so `x^2/y` is `\frac{x^2}{y}`) |
| `sqrt(2)` | √2 |
| `sum(i=1, n) i` | ∑ with bounds, display style |
| `prod(k=1, n) k` | ∏ with bounds, display style |
| `int(x) f(x)` | ∫ f(x) dx (primitive; the differential is added) |
| `int(x=a, b) f(x)` | ∫ from a to b, f(x) dx |
| `contourint(C) f(z)` | ∮ contour integral |
| `pvint(x=a, b) f(x)` | p.v. ∫ Cauchy principal value |
| `meanint(x=a, b) f(x)` | ⨍ average (normalised) integral |
| `dy/dx`, `df/dx` | derivative, upright differential d (ISO) |
| `sin(x)` `cos(x)` `ln(x)` … | upright function names |
| `abs(x)` | \|x\| |
| `norm(v)` | ‖v‖ |
| `vec(AB)` | →AB (over-arrow vector) |
| `floor(x)` `ceil(x)` | ⌊x⌋ ⌈x⌉ (integer part) |
| `bar(z)`, `conj(z)` | z̄ (conjugate, mean, closure) |
| `not(A cup B)` | (A∪B)‾ (logical negation, same overline) |
| `lim(x->0) f(x)` | limit, `->` becomes the arrow, target under the word |
| `partial`, `nabla` | ∂, ∇ (use `(partial f)/(partial x)` for ∂f/∂x) |
| `pi`, `alpha`, … | Greek letters |
| `inf` | ∞ |

The helpers nest, so the secondary-school staples come for free: `norm(vec(AB))` is the norm of a vector, `vec(AB) + vec(BC) = vec(AC)` is Chasles' relation.

### Sets, logic and relations

From collège to the upper years a worksheet needs the standard notation. It is carried as plain words and ASCII shortcuts, so a statement reads as one types it.

**Number sets** — a doubled capital gives the blackboard-bold set (the ASCIIMath convention). Doubling avoids any clash with a one-letter variable:

| You write | You get |
|---|---|
| `NN` `ZZ` `DD` `QQ` `RR` `CC` | ℕ ℤ 𝔻 ℚ ℝ ℂ |
| `PP` `KK` `HH` `FF` `EE` `UU` | ℙ 𝕂 ℍ 𝔽 𝔼 𝕌 (advanced) |

**Quantifiers and logic** — `forall` ∀, `exists` ∃; connectives `and` ∧, `or` ∨, `lnot` ¬, `neg` ¬. Implication and equivalence come both as words and as arrows: `=>` or `implies` ⇒, `<=>` or `iff` ⇔ (inside a formula; in running prose double the chevrons as `<<=>>`). The longer arrow forms win over the comparison they contain, so `abs(x) <= 1 <=> -1 <= x <= 1` parses correctly.

**Negation** — one rule: `!` before a relation or quantifier negates it, picking the proper struck-through glyph. So `!in` is ∉, `!exists` is ∄, `!subset` is ⊄, `!subseteq` is ⊈, `!equiv` is ≢. (`!=` stays "not equal", ≠.)

**Set relations** — `in` ∈, `subset` ⊂, `supset` ⊃, `subseteq` ⊆, `supseteq` ⊇, `cup` ∪, `cap` ∩, `setminus` ∖, `emptyset` ∅ (negate any with `!`).

**Arrows** — `->` or `to` →, `mapsto` ↦.

```
$forall epsilon > 0, exists eta > 0$
$x in RR setminus QQ$
$x !in QQ$
$(P and Q) => P$
```

### Brackets and accents

The integer part and a few one-argument wrappers follow the same `name(...)` shape as `abs` and `vec`: `floor(x)` ⌊x⌋, `ceil(x)` ⌈x⌉, `set(x : x > 0)` a brace set, `abr(u, v)` ⟨u, v⟩ an inner product.

An overline is named by intent — the same rule under two words: `bar(...)` for the generic bar (complex conjugate, mean, closure of a set) and `not(...)` for logical negation, so `bar(z)` is z̄ and `not(A cup B)` is (A∪B)‾. The usual accents complete the set: `hat(f)`, `tilde(x)`.

### Limits with an arrow

`lim(x->0) f(x)` already sets a limit with its target under the word. For the running phrase "uₙ tends to ℓ" written over an arrow, use `arrow(...)`: `u_n arrow(n to +inf) l` sets a long right arrow with the condition underneath. `to` and `->` are interchangeable inside it.

```
$lim(n -> +inf) u_n = l$
$u_n arrow(n to +inf) l$
```

### Operators with an index: sum, prod, lim

`sum`, `prod` and `lim` carry their index in `(...)` and set their whole expression in display style, so a fraction in the body keeps full size and a limit's target sits **under** the word, as on a blackboard. The body runs to the end of the formula or to the first `=`:

```
$sum(i=1, n) i = n(n+1)/2$
$prod(k=1, n) k$
$lim(x->0) sin(x)/x = 1$
$lim(x->+inf) 1/x$
```

### Functions and trigonometry

Function names are set upright automatically — no backslashes. The set covers `sin cos tan cot sec csc`, the inverses `arcsin arccos arctan`, the hyperbolics `sinh cosh tanh coth`, and `ln log exp det dim gcd deg ker arg max min sup`. A name glued to `(...)` takes its argument as one atom, so fractions and powers behave:

```
$sin(x)^2 + cos(x)^2 = 1$
$cos(a+b) = cos(a)cos(b) - sin(a)sin(b)$
$tan(x) = sin(x)/cos(x)$
```

### Integrals

The integral family writes its variable and bounds in the head `(...)` and captures the integrand as its body; the differential `\,dx` is appended automatically. No bounds gives a primitive, a comma-separated pair a definite integral:

```
$int(x) f(x)$              ∫ f(x) dx
$int(x=a, b) f(x)$         ∫ from a to b of f(x) dx
```

**Multiple integrals** — separate several domains with `;`. The count of domains chooses ∫, ∬ or ∭; the differentials come out in reverse order (Fubini):

```
$int(x=a, b ; y=c, d) f(x,y)$            ∬ … dy dx
$int(x=a, b ; y=c, d ; z=e, g) f$        ∭ … dz dy dx
```

A single named domain is a region integral: `int(D) f` gives ∬_D f dω. **Named integrals**: `contourint(C) f(z)` is a contour integral ∮, `pvint(x=a, b) f(x)` a Cauchy principal value, `meanint(x=a, b) f(x)` the average integral ⨍.

### Derivatives

A Leibniz derivative is written as the fraction it is, and the differential `d` is set upright (ISO 80000-2), matching the `d` of the integrals — **only** when both sides of the fraction carry it, so a variable named `d` is never disturbed (`d/2` stays the fraction d over 2):

```
$dy/dx$                 dy/dx, upright d
$(d^2 y)/(dx^2)$        second derivative
$dy/dx + y = 0$         a differential equation
```

Partial derivatives use `partial` (∂); parenthesise each side so the fraction groups correctly:

```
$(partial f)/(partial x)$
$(partial u)/(partial t) = (partial^2 u)/(partial x^2)$
```

`nabla` (∇) is available for gradients and divergences.

### Maths blocks

Matrices and systems are blocks: **one line is one row**, and inside a matrix `;` separates the entries. Every cell still goes through the mini-language.

```
<matrix>{
1 ; 2 ; 3
4 ; 5 ; 6
}
```

`<matrix>` draws parentheses, `<det>` the bars of a determinant, `<bmatrix>` square brackets. A single `|` inside a row draws the bar of an **augmented matrix** (allowed on `matrix` and `bmatrix`, never on `det`). A `<system>` stacks equations under a brace, aligned on the first relational operator:

```
<system>{
2x + 3y = 7
x - y = 1
}
```

Inject a computed value with `#{expr}` (or `#name`), including inside maths: `$#k^2$`. Decimal numbers follow the `lang` option.

### Advanced vocabulary

For the upper years, the mini-language carries the named notation of
probability, linear algebra and vector analysis. Each entry keeps the
`name(...)` shape, and the rendering is the canonical LaTeX a textbook uses.

**Counting and probability** — the binomial coefficient and arrangement are
recognised by their **two** arguments, so a one-argument `C(t)` stays an
ordinary function. Probability and expectation are the doubled blackboard
letters, with the conditional bar written `mid`:

| You write | You get |
|---|---|
| `C(n, k)` | binomial coefficient ⁽ⁿₖ⁾ |
| `A(n, k)` | arrangement Aₙᵏ |
| `factorial(n)` or `n!` | n! |
| `PP(A)`, `PP(A mid B)` | ℙ(A), ℙ(A ∣ B) |
| `EE(X)` | 𝔼(X) |
| `var(X)` `std(X)` `cov(X, Y)` | Var(X), σ(X), Cov(X, Y) |
| `normal(mu, sigma)` | 𝒩(μ, σ²) |
| `poisson(lambda)` | 𝒫(λ) |
| `binomial(n, p)` | ℬ(n, p) |
| `repart(X, x)` `densite(X, x)` | F\_X(x), f\_X(x) |

**Linear algebra** — named operators on top of the matrix blocks:

| You write | You get |
|---|---|
| `ker(f)` `im(f)` `rank(A)` | Ker(f), Im(f), rg(A) |
| `span(u, v)` `tr(A)` `com(A)` | Span(u, v), tr(A), com(A) |
| `transpose(A)` `inv(A)` | Aᵀ, A⁻¹ |
| `eigen(A)` `adj(A)` | Sp(A) (spectrum), adj(A) |

**Vector analysis and transforms** — the differential operators, the Landau
notations (spelt out so the letters `o`/`O` stay free), and the integral
transforms:

| You write | You get |
|---|---|
| `grad(f)` `div(F)` `curl(F)` | grad f, div F, rot F |
| `lap(f)` | Δf (prefixes its operand, no parentheses) |
| `dirderiv(f, u)` | ∇\_u f |
| `bigO(...)` `litO(...)` | O(·), o(·) |
| `laplace(f)` `fourier(f)` | ℒ{f}, ℱ{f} |
| `ilaplace(f)` `ifourier(f)` | ℒ⁻¹{f}, ℱ⁻¹{f} |
| `surfint(S)` `volint(V)` `flux(F, S)` | ∯\_S, ∭\_V, a flux |

**Arithmetic, number theory and sets** — and a few calculation templates:

| You write | You get |
|---|---|
| `lcm(a, b)` `gcd(a, b)` `sign(x)` | lcm, gcd, sgn |
| `card(A)` `powerset(A)` | card(A), 𝒫(A) |
| `range(1, n)` | ⟦1, n⟧ (integer interval) |
| `set(x mid x > 0)` | {x ∣ x > 0} (the keyword `mid` spaces the bar) |
| `euler(n)` `mobius(n)` | φ(n), μ(n) |
| `a equiv b mod n` | a ≡ b (mod n) |
| `taylor(f, x, a, n)` | the Taylor form (template) |
| `jacobian(f, n)` `hessian(f, n)` | the generic partial-derivative matrices |

```
$EE(X) = sum(k=1, n) k PP(X = k)$
$var(X) = EE(X^2) - EE(X)^2$
$dim(ker(f)) + rank(f) = dim(E)$
$lap(f) = div(grad(f))$
$flux(F, S) = volint(V) div(F)$
```

---

## Function studies

Three tags turn a function into a variation table and a curve. They share one source of truth: a **function object** built once with `<fn>`, then read by `<vartab>` (the table) and `<plot>` (the graph).

### The function object: `<fn>`

```
let k = <fn name:{k(x)}
            expr:{(x^2+1)/(x-1)}
            x:{-inf | 1-sqrt(2) | 1 | 1+sqrt(2) | +inf}
            second:{- | - || + | +}
            deriv:{+ | - || - | +}
            var:{-inf / 2-2sqrt(2) \ -inf || +inf \ 2+2sqrt(2) / +inf}>
```

`let NAME = <fn …>` stores the object under `NAME` (the assignment may span several lines, up to the closing `>`). Fields:

- `name:{k(x)}` — the function and its variable; sets the row labels `x`, `k'(x)`, `k(x)` (and `k''(x)` when a second-derivative line shows). `name:{k}` alone uses `x`; omit `name:` for `f(x)`.
- `expr:{…}` — the formula, in the maths mini-language. **Read only by `<plot>`**; `<vartab>` ignores it.
- `x:{… | … | …}` — the remarkable abscissas, separated by `|`.
- `deriv:{…}` — the sign of the first derivative, one sign per interval.
- `second:{…}` — the sign of the second derivative (convexity), one per interval. Optional.
- `var:{…}` — the variation line (see below).

### The table: `<vartab>`

`<vartab k>` reads the object `k`. Or write the data inline: `<vartab x:{…} deriv:{…} var:{…}>`.

**Four shapes** are allowed, depending on which sign lines you give. Only `x:` and `var:` are required; `deriv:` and `second:` are each optional:

| shape | fields | rows |
|-------|--------|------|
| full study | `second:` + `deriv:` | x, f″(x), f′(x), f(x) |
| classic variation | `deriv:` | x, f′(x), f(x) |
| convexity only | `second:` | x, f″(x), f(x) |
| value table | neither | x, f(x) |

`f″` always sits above `f′`. The value table (no sign line) just joins the listed values by arrows.

**Sign lines** (`deriv:`, `second:`) take one sign per interval: `+`, `-`, or empty. `||` (a double bar) marks a forbidden value (a pole): the bar crosses every row. Zeros at sign changes are placed automatically — you don't write them.

**The variation line** (`var:`) alternates value and connector. A connector is `/` (rising) or `\` (falling), **surrounded by spaces** — glued, as in `2/3`, it is a fraction, not an arrow. `||` carries the two limits around a pole. Values may be numbers, `+inf`/`-inf`, or any maths expression (`2-2sqrt(2)`, `27/4`).

Rules the table enforces: a value between two arrows of the **same** direction is rejected — a variation table lists only bounds and extrema, never a point on a monotone branch (that point belongs on the plot). When `f″` and `f′` show together, `x:` must list the **union** of their zeros, since all rows share the same columns.

### The graph: `<plot>`

```
<plot k samples:200 x:{-4, 6} y:{-10, 12}>
```

`<plot k>` reads `expr:` and `name:` from the object. Options:

- `x:{a, b}` — horizontal display window (comma between the two bounds). Defaults to the finite abscissas of the table.
- `y:{c, d}` — vertical window. Required when the function runs to infinity (a pole), so the view is framed.
- `samples:N` — number of points computed (default 100).

`expr:` is translated to the plotter's syntax: the variable becomes the plotting variable, trigonometric calls get the degree conversion, and implicit products (`2x`, `2(x-1)`) become explicit. Poles are handled so no spurious vertical line joins the branches. Supported in `expr:`: `+ - * / ^`, parentheses, `sin cos tan exp ln log sqrt abs`, and `pi`.

`<vartab>` is declarative, `<plot>` is computed. If `var:` does not match `expr:`, the table and the curve contradict each other silently — keeping them consistent is yours to ensure.

> Maths note: in prose use the mini-language spellings `!=`, `+-`, `>=`, `<=` (not `\neq`, `\pm`, …). Write `$f(x)$` to typeset a formula; an unbracketed `f(x)/x` parses as `f` times `(x)/x`, so phrase it as "the ratio of `$f(x)$` to `$x$`".

---

## Boxes

```
<box line:Crimson fill:MistyRose radius:4 title:{A note}>{
Content here.
}
```

Options: `line:` frame colour, `fill:` background, `text:` text colour, `radius:N` rounded corners (mm), `width:N` or `width:N%`, `boxrule:N`, `boxsep:N`, `break:yes`, `title:{…}`, `titlefill:`, `titletext:`. A line containing only `---` splits a box into two regions.

`<row gap:N>{ … }` lays its child boxes side by side, equal widths and equalised heights. A box also takes a two-letter placement code (`tl`…`br`, default `tl`); the vertical part needs a `height:` to act.

---

## Grid (named-area layout)

For full-page layouts — a worksheet header with a logo, a title bar, info fields, and a body — `<grid>` borrows CSS Grid's named-area idea. A `template:[ … ]` of quoted rows draws the layout; each word names a cell. A name repeated horizontally spans columns, vertically spans rows; a dot `.` is empty.

```
<grid template:[
  "title  title  logo"
  "intro  info   logo"
  "body   body   body"
] gap:4>{
  <area title>{ <Red b 16pt>Maths assessment }
  <area logo >{ <img>{blason.png} }
  <area intro>{ Instructions: no calculator. }
  <area info >{ Name: \\ First name: }
  <area body >{ <s1>Exercise 1
    Solve the equation... }
}
```

An area can be framed like a box (`line:`, `fill:`, `radius:`, `title:`). The grid takes `width:` and `height:`; an area or the grid takes a two-letter placement code for content position within cells.

---

## Lists

A list is `<list:STYLE>` — the style follows the name, one item per line, no item tag:

```
<list:decimal>{
Read the instructions
Underline the key words
Write your answer
}
```

Styles — bullets: `none` `disc` `circle` `square`; numbered: `decimal` `alpha` `ALPHA` `roman` `ROMAN` (the case of the keyword sets the case of the letters); checkboxes: `check`. A list written under an item becomes its sub-list, nested as deep as you like. Text attributes on the tag wrap the whole list: `<list:ROMAN TIMES NEW ROMAN 12pt i>{ … }`.

---

## Block aliases

Define a reusable component once; `#param` placeholders are filled at the call site, and the call-site body becomes the block content — so it may contain sub-blocks of its own.

```
let card{title, frame} = <box title:{#title} line:#frame radius:2>

<card First, Crimson>{ Called with two arguments. }
<card Second, Navy>{ Same component, different look. }
```

---

## Control flow

```
for n in 1..3 {
<c Navy b>Sheet #n
}

for f in [chat.png, chien.png] {
<img 16>{#f}
}

if score >= 10 {
<Green>Passed.
} else {
<Red>Try again.
}
```

Loops and conditions work in the document body, inside boxes, and inside table bodies. The loop variable interpolates everywhere via `#`.

---

## Escapes

To print a character that scholatex treats specially, **double it**: `<<` `>>` `{{` `}}` `##` give a literal `<` `>` `{` `}` `#`. The backslash is an ordinary character — a path like `C:\Users\Leo` or a regex `\d+\s*\w` prints verbatim, nothing to escape. The characters `_ & % ^ ~` are escaped automatically. A line break inside a paragraph is the tag `<nextline>`. A line whose first non-space character is `%` is a comment. A bare `#` not followed by a name or `{…}` is a literal `#`.

Braces carry structure, so a **literal brace must be balanced**: write the pair `{{…}}` to print `{…}`. A lone, unmatched `{{` or `}}` is reported as an unbalanced brace naming its line, rather than silently corrupting the surrounding block — so set-builder notation like `{{ x : x > 0 }}` is written as a pair. Angle brackets and hashes need no such balancing; only braces do.

---
## Colour reference

Every colour is written in **CamelCase** — there is one rule and no lowercase shortcuts. The everyday colours are simply capitalised: `Red` `Blue` `Green` `Navy` `Orange` `Purple` `Teal` `Brown` `Gray`/`Grey` `Pink` `Yellow` `Black` `White` `Violet` `Cyan` `Magenta` `Lime` `Olive` `Aqua` `Silver` `Maroon`.

For the full palette, write any of the **151 CSS / svgnames colours in CamelCase** (`<SteelBlue>{…}`, `fill:MistyRose`, `line:DarkOrange`). They are grouped below by family for browsing; all are valid anywhere a colour is expected (`line:` `fill:` `text:` and inline tags).

**Reds & pinks** (14) — `Brown`, `Crimson`, `DarkRed`, `FireBrick`, `IndianRed`, `LightCoral`, `LightPink`, `Maroon`, `MistyRose`, `Pink`, `Red`, `RosyBrown`, `Salmon`, `Tomato`

**Oranges & browns** (23) — `AntiqueWhite`, `Bisque`, `BlanchedAlmond`, `BurlyWood`, `Chocolate`, `Coral`, `DarkGoldenrod`, `DarkOrange`, `DarkSalmon`, `Goldenrod`, `LightSalmon`, `Moccasin`, `NavajoWhite`, `Orange`, `OrangeRed`, `PapayaWhip`, `PeachPuff`, `Peru`, `SaddleBrown`, `SandyBrown`, `Sienna`, `Tan`, `Wheat`

**Yellows & golds** (11) — `Cornsilk`, `DarkKhaki`, `Gold`, `Khaki`, `LemonChiffon`, `LightGoldenrod`, `LightGoldenrodYellow`, `LightYellow`, `Olive`, `PaleGoldenrod`, `Yellow`

**Greens** (20) — `Aquamarine`, `Chartreuse`, `DarkGreen`, `DarkOliveGreen`, `DarkSeaGreen`, `ForestGreen`, `Green`, `GreenYellow`, `LawnGreen`, `LightGreen`, `Lime`, `LimeGreen`, `MediumAquamarine`, `MediumSeaGreen`, `MediumSpringGreen`, `OliveDrab`, `PaleGreen`, `SeaGreen`, `SpringGreen`, `YellowGreen`

**Cyans & teals** (17) — `Aqua`, `CadetBlue`, `Cyan`, `DarkCyan`, `DarkSlateGray`, `DarkSlateGrey`, `DarkTurquoise`, `DeepSkyBlue`, `LightBlue`, `LightCyan`, `LightSeaGreen`, `MediumTurquoise`, `PaleTurquoise`, `PowderBlue`, `SkyBlue`, `Teal`, `Turquoise`

**Blues** (21) — `Blue`, `CornflowerBlue`, `DarkBlue`, `DarkSlateBlue`, `DodgerBlue`, `LightSkyBlue`, `LightSlateBlue`, `LightSlateGray`, `LightSlateGrey`, `LightSteelBlue`, `MediumBlue`, `MediumPurple`, `MediumSlateBlue`, `MidnightBlue`, `Navy`, `NavyBlue`, `RoyalBlue`, `SlateBlue`, `SlateGray`, `SlateGrey`, `SteelBlue`

**Purples & violets** (17) — `BlueViolet`, `DarkMagenta`, `DarkOrchid`, `DarkViolet`, `DeepPink`, `Fuchsia`, `HotPink`, `Indigo`, `Magenta`, `MediumOrchid`, `MediumVioletRed`, `Orchid`, `PaleVioletRed`, `Plum`, `Purple`, `Violet`, `VioletRed`

**Grays** (10) — `DarkGray`, `DarkGrey`, `DimGray`, `DimGrey`, `Gray`, `Grey`, `LightGray`, `LightGrey`, `Silver`, `Thistle`

**Whites & off-whites** (17) — `AliceBlue`, `Azure`, `Beige`, `FloralWhite`, `Gainsboro`, `GhostWhite`, `Honeydew`, `Ivory`, `Lavender`, `LavenderBlush`, `Linen`, `MintCream`, `OldLace`, `Seashell`, `Snow`, `White`, `WhiteSmoke`

**Black** (1) — `Black`

These are exactly the colours xcolor provides under its `svgnames` option (the 147 CSS Color Module names plus the four X11 extras `LightGoldenrod`, `LightSlateBlue`, `NavyBlue` and `VioletRed`). Names are case-sensitive: write `Seashell`, not `SeaShell`.

---
## Security

`scholatex` evaluates `let name = expr`, `#{expr}` and the conditions of `for`/`if`/`while` as Lua at compile time, so by default a document can run arbitrary code — exactly like `\directlua`.

Setting `untrusted=true` in `\documentclass[...]{scholatex}` runs that Lua in a restricted environment: only pure, side-effect-free names are visible; `os`, `io`, `package`, `require`, `load`, `debug` and other escape vectors are absent. A blocked access stops the compile with a clear message; a runaway loop is aborted by an instruction-count ceiling; `string.rep`/`string.format` are capped.

```latex
\documentclass[untrusted=true]{scholatex}
```

`untrusted` hardens **the scholatex expression layer only**. It does not sandbox LuaLaTeX as a whole — a hostile `.tex` can still call `\directlua`, `\write18`, `\input`. Use it when the scholatex **body** comes from a semi-trusted source while the surrounding `.tex` is your own; for a whole untrusted `.tex`, run `lualatex` without `--shell-escape`, ideally in a container.

---

## Examples

The `examples/` folder contains eleven self-contained, fully commented documents that together exercise every feature:

| File | Covers |
|------|--------|
| `text-style.tex` | the case rule, styles, colours, fonts, sizes, alignment, tabs, skips, scripts; **factoring styles into aliases**; a table of contents from the heading keywords |
| `containers.tex` | tables, boxes and the named-area grid, each built up from its simplest form to a full worksheet header |
| `basics.tex` | the inline mini-language, number sets, quantifiers and connectives, negation with `!`, set relations, the integer part, the overline, and arithmetic helpers |
| `math-language.tex` | a tour of the math mini-language built progressively from quantifiers to integrals |
| `math-analysis.tex` | analysis-flavoured math snippets: limits, derivatives, integrals, transforms |
| `math-algebra.tex` | algebra-flavoured math snippets: matrices, linear-algebra vocabulary |
| `analysis.tex` | operators with an index, limits (including the `arrow` form), trigonometry, derivatives, the vector operators, the integral family, transforms |
| `algebra.tex` | the matrix / determinant / augmented-matrix / system blocks, and the linear-algebra vocabulary |
| `probability.tex` | counting, probability and expectation, variance, distributions, density |
| `functions.tex` | full function studies — `<fn>`, `<vartab>` and `<plot>` over polynomial, rational-with-horizontal-asymptote and rational-with-pole examples |
| `geometry.tex` | the `<draw>` block — triangles, quadrilaterals, regular polygons, circles, composite figures, and the inline-math geometry vocabulary |

Compile any of them with `lualatex <file>.tex` from the `examples/` folder.

---

## Project layout

```
scholatex.cls            LaTeX class: options, packages, reads & injects the body
scholatex.lua            transpiler core: tags, text, control flow, aliases
scholatex-style.lua      attribute resolution (colours, styles, sizes, alignment…)
scholatex-math.lua       the $…$ math mini-language (operators, integrals, functions, trig)
scholatex-util.lua       parsing primitives (groups, brace balance, comma split)
scholatex-table.lua      the <table> block
scholatex-img.lua        the <img> tag
scholatex-box.lua        the <box> and <row> blocks
scholatex-grid.lua       the <grid> named-area layout block
scholatex-section.lua    the <section>/<subsection>/<subsubsection> blocks
scholatex-list.lua       the <list:STYLE> block
scholatex-matrix.lua     the <matrix>/<det>/<bmatrix> and <system> blocks
scholatex-vartab.lua     the <fn> object, <vartab> table and <plot> curve
scholatex-figure.lua     the <draw> block: geometric figures, points and segments
scholatex-toc.lua        the <tableofcontents> tag
examples/                six commented showcase documents
```

New tags register themselves via `scholatex.register_tag` / `scholatex.register_block`; a name clash raises an error rather than silently overwriting, so modules stay independent.

---

## Diagnostics

Errors point at the source line, e.g. `scholatex: line 12: unknown tag attribute: 'xyz'`. Defining an alias whose name is a built-in (`let section = …`) prints a warning: the built-in always wins, so the alias would be silently dead — pick a different name.

---

## What's new

### 2.3

- **Figure drawing: the `<draw>` block** — a plane figure is described, not hand-placed. Name the shape and give its measurements; the coordinates are computed trigonometrically and emitted as hard numbers. One drawing unit is one centimetre, so `side:5` draws a 5 cm side.
  - **Triangles** by any classical definition — `equilateral`, `isosceles`, `right` (right angle at the first point, or `right:X`), three sides `sides:(a,b,c)`, two sides and the included angle `sides:(a,b) angle:t`, two angles and a side `angles:(A,B) side:c`, or three sides named one by one (`AB:3 BC:4 CA:5`).
  - **Quadrilaterals** — `square`, `rectangle`, `rhombus`, `parallelogram`, `trapezoid`, and `kite` (two pairs of adjacent equal sides, the rhombus being the case where both pairs are equal).
  - **Regular polygons** by name from the pentagon up (`pentagon`, `hexagon`, `octagon`), or `polygon` with as many points as given.
  - **Circles** by centre and `radius:r` or `diameter:d` (the radius optionally a placed segment, `radius:AB`); `circle ABC` is the circumscribed circle of three placed points, with `inscribed` for the incircle.
- **Coding and measurement** — `marks:on` codes equal sides and right angles; `measures:cm` / `measures:mm` labels each side with its length. Both are opt-in. When a figure has two pairs of equal sides of different lengths (kite, rectangle, parallelogram), the pairs are told apart by their tick count — a single tick on one pair, a double tick on the other — so a kite never reads as a rhombus.
- **Composite figures** — several figures in one block share their points; a figure repeating a point is grafted onto it, and a figure sharing an edge deduces that edge's length and is flipped to the far side so the pieces abut. A shared edge is labelled once and ticked once, not twice.
- **Multi-character point names** — besides the glued single letters (`triangle ABC`), a parenthesised comma-separated list names multi-character points: `triangle (O, A0, B0)`.
- **Loops, interpolation and rotation inside `<draw>`** — the same `for VARIABLE in FROM..TO { … }` loops as the rest of the language; `#k` and `#{expr}` interpolate point names and measurements; `rotate:θ` turns a figure about its first point and `labels:off` hides the vertex names — enough to fan, rosette or step figures round a centre.
- **Low-level primitives `point` and `line`** — `point(P)` places a dot at coordinates declared with `let P = {x, y}`; `line(A, B)` draws a segment between two points (names or literal `{x, y}` pairs), taking `measures:` like a figure side. As each coordinate is an ordinary expression, a loop can compute endpoints — the building block for free-form drawings.
- **Examples** — a new `geometry` showcase covers the inline geometry vocabulary and the full `<draw>` block.

### 2.2

- **Probability and statistics** — the blackboard operators `PP(...)` ℙ and `EE(...)` 𝔼 (with `PP(A mid B)` for a conditional), spread (`var`, `std`, `cov`), distributions (`normal`, `poisson`, `binomial`), and the distribution/density functions (`repart`, `densite`).
- **Counting** — the binomial coefficient `C(n, k)` and arrangement `A(n, k)`, recognised by their two arguments so a one-argument `C(t)` stays a function; the factorial `factorial(n)` or `n!`.
- **Linear-algebra vocabulary** — `ker`, `im`, `rank`, `span`, `tr`, `com`, `eigen` (the spectrum), `adj`, with `transpose(A)` → Aᵀ and `inv(A)` → A⁻¹.
- **Vector analysis** — `grad`, `div`, `curl`, the Laplacian `lap(f)` Δf, the directional derivative `dirderiv(f, u)`, the Landau notations `bigO`/`litO`, the transforms `laplace`/`fourier` and their inverses, and the surface/volume integrals `surfint`/`volint`/`flux`.
- **Number theory and helpers** — `euler` φ, `mobius` μ, congruence `a equiv b mod n`, plus `lcm`, `sign`, `card`, `powerset`, the integer interval `range(1, n)` ⟦1, n⟧, the keyword `mid` for a spaced bar, and the templates `taylor`, `jacobian`, `hessian`.
- **Fixes** — a parenthesised group over a fraction now grows to full height (`(a/b)^2`); higher-order differentials `d^2y/dx^2` set the upright d throughout; plot tick numbers stay readable where a curve crosses an axis, and the axis arrow clears the last graduation.
- **Examples by domain** — the maths showcase now mirrors the manual's four categories: `basics`, `algebra`, `analysis` (which holds the function studies) and `probability`.

### 2.1

- **Mathematical vocabulary** — number sets in blackboard bold (`NN` `ZZ` `DD` `QQ` `RR` `CC`, plus `PP` `KK` `HH` `FF` `EE` `UU`), quantifiers and connectives (`forall` `exists` `and` `or` `lnot` `neg`), implication and equivalence as words or arrows (`=>`/`implies`, `<=>`/`iff`), set relations (`in` `subset` `cup` `cap` `setminus` `emptyset` …), the integer part (`floor` `ceil` `round`), and accents (`bar`/`conj` for the conjugate-mean-closure overline, `not` for logical negation, `hat` `tilde`).
- **Negation with a single `!`** — `!` in front of a relation or quantifier negates it with the proper struck-through glyph: `!in` ∉, `!exists` ∄, `!subset` ⊄, `!subseteq` ⊈, `!equiv` ≢. `!=` stays "not equal".
- **Limit arrow** — `arrow(n to +inf)` sets a long right arrow with its condition underneath, for the "uₙ → l" phrasing in running maths.
- **Colours are CamelCase only** *(breaking change)* — the lowercase keywords (`red`, `navy`, …) are removed; write the CamelCase form (`Red`, `Navy`). One rule for all 151 colours. A lowercase colour now raises an error that names the CamelCase replacement.
- **Function studies** — three new tags for analysis: `<fn>` builds a function object (name, formula, abscissas, derivative signs, variation), `<vartab>` renders its variation table, `<plot>` draws its curve (via pgfplots, with pole handling). The table comes in four shapes — full (f″, f′, f), classic (f′, f), convexity (f″, f), or a plain value table (f) — since the two derivative lines are independent and optional.
- **Section numbering styles** — `num`, `roman`, `ROMAN`, `alpha`, `ALPHA` set the counter style of a heading level on its own, with no inherited prefix; the default stays hierarchical.
- **Examples reorganised** — the showcase set is now `text-style`, `containers`, `math-language`, `math-analysis`, `math-algebra` and `functions` (the old single `03-math` is split by topic).

### 2.0

- **New escape rules** *(breaking change)* — to print a special character, double it: `<<` `>>` `{{` `}}` `##` give a literal `<` `>` `{` `}` `#`. A backslash is now an ordinary character (so `C:\Users` just works); it is no longer an escape. The old `\<` `\>` `\{` `\}` `\#` forms no longer apply.
- **Line break is a tag** *(breaking change)* — use `<nextline>` (in text and table cells) instead of the old `\\`. In running text a blank line already starts a new paragraph, so `<nextline>` is only for a break without a paragraph change.

### 1.2

- **Script/fraction precedence fix** — `^` and `_` now bind tighter than `/`, so `x^2/y` renders as the fraction of `x^2` over `y` (and `1/i^2` as `1` over `i^2`), matching ordinary mathematical reading
- **Automatic spacing for tall lines** — consecutive lines containing fractions or integrals no longer touch; TeX inserts just enough air where needed, leaving ordinary text unchanged

### 1.1

- **Maths expansion** — full integral family (`int`, multiple integrals with Fubini ordering, `contourint`, `pvint`, `meanint`), upright functions and trigonometry, Leibniz and partial derivatives with ISO 80000-2 upright differentials
- **Operators in display style** — `sum`, `prod`, `lim` keep fractions full-size and place limits under the word
- **Full colour parity** — all 151 xcolor svgnames colours recognised, grouped by family in the [reference](#colour-reference)
- **Cross-platform install** — documented `tlmgr` and manual paths for macOS, Linux and Windows

---

## Acknowledgments

`scholatex` is built on excellent LaTeX packages:

- [tcolorbox](https://ctan.org/pkg/tcolorbox) — framed boxes and posters
- [tabularray](https://ctan.org/pkg/tabularray) — reliable 2-D table layout
- [unicode-math](https://ctan.org/pkg/unicode-math) — OpenType maths
- [fontspec](https://ctan.org/pkg/fontspec) — system fonts in LuaLaTeX
- [xcolor](https://ctan.org/pkg/xcolor) — the svgnames colour palette

---

## License

Copyright © 2026 Gérard Dubard.

`scholatex` is free software: you can redistribute it and/or modify it under the terms of the **GNU General Public License version 3** (or later) as published by the Free Software Foundation. See the [`LICENSE`](LICENSE) file for the full text.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
