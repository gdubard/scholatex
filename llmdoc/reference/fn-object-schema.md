# `<fn>` Object Schema

## Scope

`<fn>` is the function-study record. It is built once at a `let` line and
later read by `<vartab>` (for the variation table) and `<plot>` (for the
graph). This document is the schema of that record — the contract between the
producer (`<fn>` parser) and the two consumers (`<vartab>`, `<plot>`).

`<fn>` is **not** a registered tag. The transpiler recognises it at the level
of `build_lua` when it sees `let X = <fn ...>`. The parser callable is
`sl.fn_parse`, defined in `scholatex-vartab.lua:405-407`:

```lua
sl.fn_parse = function(inner)
  return parse_attrs(U.trim(inner or ""))
end
```

Storage is `sl._objects[name]` — a flat string-attribute dictionary, set by
the transpiler at `scholatex.lua:483-484` (multi-line accumulator) and
`scholatex.lua:498-499` (single-line). Lookup is `<vartab>` at
`scholatex-vartab.lua:420-421` and `<plot>` at `scholatex-plot.lua:115`.

A bare `<fn ...>` outside a `let` line falls through to the unknown-tag path
(`scholatex.lua:113-122` → `STYLE.classify_into` else branch →
`scholatex-style.lua:201` `unknown tag attribute: 'fn'`)¹.

## Schema

Every recognised field is the **unparsed string** the user typed between
`{...}` — `parse_attrs(require_group=true)` keys the value by attribute name
(`scholatex-vartab.lua:32-38`). There is no schema validation at storage
time, no derived fields, no defaults filling at parse time; every consumer
re-parses these strings from scratch.

| Field    | Type                                                                                           | Required?                                          | Default                                                     | Consumed by      |
|----------|------------------------------------------------------------------------------------------------|----------------------------------------------------|-------------------------------------------------------------|------------------|
| `name`   | `f` or `f(x)` — function name and (optional) variable name                                     | optional                                           | `f, x` (re-derived at `scholatex-vartab.lua:315-328` and `scholatex-plot.lua:125-130`) | both             |
| `x`      | `|`-separated abscissas; tokens may include `inf` / `-inf` / `+inf`                            | required by `<vartab>`; optional for `<plot>`      | `<plot>` inherits the window from this list when no inline `x:{a,b}` is given, skipping `inf` cells (`scholatex-plot.lua:84-101`) | both             |
| `deriv`  | `|`-separated signs (`+`, `-`, `0`, empty) — one per **interval**; `||` marks a pole (the derivative is undefined at that bound) | optional                                           | absent → the f' sign row is omitted                          | `<vartab>` only  |
| `second` | same shape as `deriv` — the f″ sign line                                                       | optional                                           | absent → the f″ row is omitted                               | `<vartab>` only  |
| `var`    | value/arrow alternation `value /` or `value \` ... ending in a value; `||` is a double bar with up to one bordering value on each side | required by `<vartab>`                             | —                                                           | `<vartab>` only  |
| `expr`   | free expression in the user's variable; goes through `translate()` on `<plot>` use             | required by `<plot>`                               | —                                                           | `<plot>` only    |

`x` is required by `<vartab>` (`scholatex-vartab.lua:341-343`). `expr` is
required by `<plot>` (`scholatex-plot.lua:120-123`).

Unknown attributes are accepted silently — `parse_attrs` stores anything
keyed `key:{value}`, and consumers read only the keys they recognise
(`scholatex-vartab.lua:337-339` documents that vartab-only and plot-only
attributes coexist on the same object).

## Lifecycle

```
                                    +-----------------+
let X = <fn ...> (line 5)  ----->   | sl._objects[X]  |  <-----  <vartab X> (line 50)
                                    | { name?, x,     |  <-----  <plot X opts> (line 80)
                                    |   deriv?,       |
                                    |   second?,      |
                                    |   var, expr? }  |
                                    +-----------------+
```

| Step           | Who                                                                                              | How                                                                  |
|----------------|--------------------------------------------------------------------------------------------------|----------------------------------------------------------------------|
| Define         | Transpiler reads `let X = <fn ...>` lines                                                        | `scholatex.lua:492-505` (single-line), `scholatex.lua:467-487` (multi-line) |
| Parse          | `sl.fn_parse(inner)` → `parse_attrs(require_group=true)`                                          | `scholatex-vartab.lua:32-38, 405-407`                                |
| Store          | `sl._objects[X] = attrs` (idempotent lazy init)                                                  | `scholatex.lua:483-484, 498-499`                                     |
| Render table   | `<vartab X>` → lookup, then `generate(attrs)` builds tkz-tab rows                                | `scholatex-vartab.lua:419-431, 340-397`                              |
| Render plot    | `<plot X opts>` → lookup, then `translate(expr, var)` → `\begin{axis}...\addplot[...]{body};\end{axis}` | `scholatex-plot.lua:115-171`                                         |

### Multi-line accumulation

When `let X = <fn ...` does not close on the same line, the transpiler opens
a `pending_obj` accumulator (`scholatex.lua:467-487`) and concatenates the
following lines until one ends in `>`. The concatenated inner text is then
handed to `sl.fn_parse`. Lines that do not close are reported as
`scholatex: unterminated  let X = <fn ...>` if EOF is reached first².

### Forward references are impossible

The transpiler executes top-down. `let X = <fn ...>` must appear **before**
any `<vartab X>` or `<plot X>`. A reference to an undefined name raises (see
"Cross-module contract" below).

## Cross-module contract

The two consumers read the same record but enforce different fields.

### `<vartab>` lookup

`scholatex-vartab.lua:419-425`:

- If the only word (no `:` in it) names an object → use the attribute table
  directly.
- If the only word names no object → raise:
  `scholatex: <vartab X> refers to an object that is not defined; write let X = <fn ...> first, or give x:{...} var:{...} inline`.
- Otherwise → treat the words as inline attributes and re-parse with
  `parse_attrs` (`scholatex-vartab.lua:426-428`).

After lookup, `<vartab>` requires `attrs.x` (raises at
`scholatex-vartab.lua:341-343` if absent). `attrs.var` is also required by
the value-row builder (`scholatex-vartab.lua:344-345`).

`expr:` and `name:` are read if present but neither is mandatory: `<vartab>`
can render purely from `x` + `var` (+ optional `deriv` / `second`).

### `<plot>` lookup

`<plot>` always requires a reference. The first bare word becomes
`attrs._ref` through the `on_bare` hook (`scholatex-plot.lua:7-11`);
`scholatex-plot.lua:111-114` raises if none was given:

```
scholatex: <plot> needs a function object, e.g. <plot k ...> after  let k = <fn ...>
```

After the reference is resolved (`scholatex-plot.lua:115`), `<plot>`
requires the object to carry `expr:`:

```
scholatex: <plot k> needs the object to carry an expr:{...} (the formula to plot)
```

(`scholatex-plot.lua:120-123`.)

`<plot>` does **not** need `var`, `deriv`, or `second` — a plot can be drawn
from an `<fn>` that has no variation data. It does, however, use `obj.x` to
infer the x-window when no inline `x:{a, b}` is given
(`scholatex-plot.lua:84-101`).

### Dependency on `scholatex-vartab.lua`

`sl.fn_parse` is defined inside `scholatex-vartab.lua`'s registration block
(`:405-407`). The transpiler calls `sl.fn_parse` at `scholatex.lua:484` and
`:499`. If `scholatex-vartab.lua` were not `sl.use`-d, the transpiler would
crash on the first `<fn>` line. The load order is guaranteed by
`scholatex.lua:779-789`: vartab is loaded before plot, both before document
processing begins.

`<plot>` does not call any `<vartab>` API — both modules talk directly to
`sl._objects`.

## Canonical use

From `examples/functions.tex:30-35`:

```
let f = <fn name:{f(x)}
            expr:{-x^4 + 2x^2 + 1}
            x:{-inf | -1 | -1/sqrt(3) | 0 | 1/sqrt(3) | 1 | +inf}
            second:{- | - | + | + | - | -}
            deriv:{+ | + | + | - | - | -}
            var:{-inf / 2 \ 1 / 2 \ -inf}>
```

Then later:

```
<vartab f>                                  (examples/functions.tex:70)
<plot f samples:200 x:{-2, 2} y:{-3, 3}>    (examples/functions.tex:73)
```

The same `sl._objects["f"]` is read by both: `<vartab>` consumes `x`,
`deriv`, `second`, `var`, `name`; `<plot>` consumes `expr`, `name`, and
falls back to `x` when no inline x-window is given.

## Failure modes

| Trigger                                                | Raised at                                  | Message                                                                                                                              |
|--------------------------------------------------------|--------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `<vartab X>` with no `sl._objects[X]`                  | `scholatex-vartab.lua:422-425`             | `<vartab X> refers to an object that is not defined; write let X = <fn ...> first, or give x:{...} var:{...} inline`                  |
| `<vartab>` missing `x:`                                | `scholatex-vartab.lua:341-343`             | `<vartab> needs x:{...} (the abscissas)`                                                                                              |
| `<vartab>` missing `var:`                              | `scholatex-vartab.lua:344-345`             | `<vartab> needs var:{...} (the values)`                                                                                               |
| `<vartab>` `deriv` / `second` row arity mismatches `x` | `scholatex-vartab.lua:115-118` (in `build_deriv`) | `<vartab> deriv has N tokens but x has M bounds, so the sign sequence should be ...`                                              |
| `<plot>` with no reference                             | `scholatex-plot.lua:111-114`               | `<plot> needs a function object, e.g. <plot k ...> after let k = <fn ...>`                                                            |
| `<plot X>` with no `sl._objects[X]`                    | `scholatex-plot.lua:116-118`               | `<plot X> refers to an object that is not defined; write let X = <fn ... expr:{...} ...> first`                                       |
| `<plot X>` missing `expr:` on the object               | `scholatex-plot.lua:120-123`               | `<plot X> needs the object to carry an expr:{...} (the formula to plot)`                                                              |
| `<fn>` inline outside a `let`                          | `scholatex.lua:113-122` (tag dispatch fallback) → `scholatex-style.lua:201` | `scholatex: unknown tag attribute: 'fn'` — see footnote¹                                                       |

Field validation is **lazy**: errors only fire when a consumer reads a
malformed field. A typo in `let f = <fn ...>` on line 5 might only be
reported at `<vartab f>` on line 50 or `<plot f>` on line 80. This is a
trade-off — see `memory/doc-gaps.md` ("No deep-validation of `<fn>` fields at
storage time").

A malformed `expr:` (e.g. unbalanced parens, unknown identifier) typically
fails at LaTeX time, not at `<plot>` parse time, because `<plot>` only does
syntactic rewrites; pgfplots evaluates the resulting math at compile.

## See also

- `reference/tags-and-blocks.md` — full registry of tags and blocks, with
  `<vartab>` and `<plot>` arguments and the `<fn>` non-registration noted.
- `architecture/math-pipeline.md` — the `mathlite` rewriter (used by
  `<vartab>` for cell math and by `<plot>` for the `translate(expr, var)`
  step).
- `memory/doc-gaps.md` — `<fn>` is documented in `CHANGELOG.md:149-154` as a
  tag, but it is recognised only on a `let` line. The lazy validation
  trade-off is also recorded there.

---

¹ `<fn>` is documented in `CHANGELOG.md:149-154` and `README.md:446-465` as if
it were a tag, but the only recognition path is `let X = <fn ...>` (a
transpiler-level construct). A bare `<fn ...>` outside a `let` raises
`unknown tag attribute: 'fn'`. See `memory/doc-gaps.md` ("`<fn>` is
undocumented as a `let`-line construct").

² The unterminated-`<fn>` error message and trigger are in
`scholatex.lua` around the `pending_obj` handling (`scholatex.lua:467-487`);
the exact wording depends on which guard fires first when the document ends
mid-record.
