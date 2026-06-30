# Architecture: Function Studies

## Purpose

Function studies are a small three-tag DSL: one schema, two renderers. The schema is `<fn>`; the renderers are `<vartab>` (variation table via `tkz-tab`) and `<plot>` (graph via `pgfplots`). All three share the `sl._objects[name]` store as their only contract.

This is its own ownership boundary because the schema is parsed by the transpiler itself (not by a registered tag), the shared store has no class or validator, and the two renderers re-parse every field on every use with no caching. The math compiler invoked by these tags is documented in `architecture/math-pipeline.md`.

## Surface vs implementation

### `<fn>` is parsed by the transpiler

`<fn>` is **not** a registered tag. There is no `sl.register_tag("fn", ...)` anywhere. The transpiler recognises a `let X = <fn ARGS>` line as a special form:

- Single-line shape (`scholatex.lua:491-505`): `^%s*let%s+([%a_][%w_]*)%s*=%s*<%s*fn%f[%s>](.*)$`. If the line already closes with `>`, the inner string is parsed immediately.
- Multi-line accumulator (`scholatex.lua:467-487`, `:472-488`): if the opener does not close on the same line, `pending_obj.buf` collects subsequent lines until one ends with `>`, then the buffer is joined with `\n` and fed to `sl.fn_parse`.

The parser callable is `sl.fn_parse(inner)`, defined at `scholatex-vartab.lua:405-407`:

```lua
sl.fn_parse = function(inner) return parse_attrs(inner) end
```

It is a thin wrapper around `U.parse_attrs` with vartab-specific options (`require_group=true`). **`scholatex-vartab.lua` is therefore a hard prerequisite for `<fn>`** — without it, the transpiler crashes on the first `<fn>` line. Module load order in `scholatex.lua:779-789` puts vartab before plot, so this works deterministically.

Writing `<fn ...>` outside a `let` line falls through to the normal tag dispatch and produces `unknown tag attribute: 'fn'`.

### `<vartab>` is a tag

Registered at `scholatex-vartab.lua:409` via `sl.register_tag("vartab", ...)`. Two call shapes:

- Object reference: `<vartab f>` — a single bare word looked up in `sl._objects` (`scholatex-vartab.lua:419-421`).
- Inline attributes: `<vartab x:{...} var:{...} ...>` — same attribute set as `<fn>` but supplied directly.

A bare-word reference that does not name an object raises `<vartab> refers to an object that is not defined`.

### `<plot>` is a tag

Registered at `scholatex-plot.lua:105` via `sl.register_tag("plot", ...)`. Stricter than `<vartab>`: it **always** needs an object reference (`scholatex-plot.lua:111-114` errors when no `_ref` was set). The bare word is captured by an `on_bare` hook (`scholatex-plot.lua:7-11`) into `attrs._ref`, then looked up in `sl._objects` (`:115-123`). The object must carry `expr` (`:120-123`).

## Shared store: `sl._objects[name]`

Created lazily at `scholatex.lua:483, 498` (`sl._objects = sl._objects or {}`). A flat name → attribute-table map. Keys are the identifier on the left of `let`. Values are the raw attribute table returned by `parse_attrs(inner)` — every field is an unparsed string.

Schema (cited from `scholatex-vartab.lua:33-38` and the four consumer arms):

| Field | Required | Format | Consumer |
|---|---|---|---|
| `name` | optional | `f` or `f(x)` (function and variable); defaults to `f, x` | both (labels) |
| `x` | required (`<vartab>`); optional (`<plot>` if `x:` window given) | `\|`-separated abscissas; tokens include `inf`, `-inf`, `+inf` | both |
| `deriv` | optional | `\|`-separated signs (`+ - 0` or empty); `\|\|` marks a pole | `<vartab>` only |
| `second` | optional | same shape as `deriv`; the f″ line | `<vartab>` only |
| `var` | required (`<vartab>`) | alternation `value / value \ ... `; `\|\|` is a double bar | `<vartab>` only |
| `expr` | required (`<plot>`) | free expression in the user's variable | `<plot>` only |

The full schema with examples lives in `reference/fn-object-schema.md`.

No deep validation runs at storage time. Typos in a `let f = <fn ...>` at line 5 are only reported when `<vartab f>` (line 50) or `<plot f>` (line 80) reads the field. Forward references are impossible: the transpiler executes top-down.

Each module accesses the store independently:

- `<vartab>` reads `sl._objects[word]` at `scholatex-vartab.lua:419-421`.
- `<plot>` reads `sl._objects[attrs._ref]` at `scholatex-plot.lua:115`.

Neither module mutates the record; both re-`mathlite` every cell on every render (no memoisation).

## `<vartab>` shape switching

`generate(attrs)` at `scholatex-vartab.lua:340-397` is the single builder. The four row patterns fall out of which optional fields the `<fn>` object set:

| Shape | `second` | `deriv` | Rows top-to-bottom |
|---|---|---|---|
| Full | present | present | x, f″, f′, f |
| Classic | absent | present | x, f′, f |
| Convexity | present | absent | x, f″, f |
| Plain values | absent | absent | x, f |

Order enforced by the **append order** to `rowdefs` and `rowbodies` (`scholatex-vartab.lua:369-380`):

1. `scholatex-vartab.lua:369-373` — if `attrs.second` is present, append `ddlabel` (the `f''` line) via `build_deriv(scells, #xs)` with step weight `1`.
2. `scholatex-vartab.lua:374-378` — if `attrs.deriv` is present, append `dlabel` (the `f'` line) via `build_deriv` with step weight `1`.
3. `scholatex-vartab.lua:379-380` — always append `flabel` (the `f` variation line) with step weight `2.6` so the value row gets more vertical room.

The x row is always emitted via the `\tkzTabInit` first argument (`scholatex-vartab.lua:382-383`); f is always last via `\tkzTabVar` (`:380, :392`).

Emitted `tkz-tab` commands (`scholatex-vartab.lua:386-395`):

1. `\begin{center}\begin{tikzpicture}` (`:386`).
2. `\tkzTabInit[espcl=2.2]{init}{xlist}` (`:387`). The `espcl=2.2` is hardcoded.
3. For each row in `rowbodies`: `\tkzTabLine{...}` for sign rows (f′, f″) or `\tkzTabVar{...}` for the value row.
4. `\end{tikzpicture}\end{center}` (`:395`).

Only three `tkz-tab` commands are used: `\tkzTabInit`, `\tkzTabLine`, `\tkzTabVar`. No `\tkzTabSlope`, no `\tkzTabImage`, no `\tkzTabVal`.

**Column-step convention**: x row gets weight `1` (`scholatex-vartab.lua:382`), each sign row gets weight `1` (`:371, :376`), the variation row gets weight `2.6` (`:379`).

Pole tokens (`||`) appearing in `deriv` / `second` mark a column boundary where the derivative is undefined. `build_deriv` at `scholatex-vartab.lua:102-137` separates the sign sequence and the bar marks into parallel arrays (`signs`, `barat`) and emits `tkz-tab`'s double-bar code `"d"` at each pole, `"z"` for a regular zero/sign change. `<var>` poles are processed in `lex_var` (`scholatex-vartab.lua:160-184`) and `build_var` (`:281-296`).

## `<plot>` pole handling

`<plot>` does **not** detect poles syntactically. It layers three mitigations, all in `scholatex-plot.lua:137-159`:

1. **`unbounded coords=jump`** (`scholatex-plot.lua:159`). The load-bearing flag: tells pgfplots that any sampled coordinate flagged unbounded breaks the path. The drawn line **gaps** across the pole instead of connecting `-inf` to `+inf` with a vertical streak.
2. **`restrict y to domain=3c:3d`** (`scholatex-plot.lua:154-156`). When the user passes a numeric `y:{c, d}` window, the numerical domain is widened to `3c:3d` and pgfplots is told to mark samples outside `[3c, 3d]` as unbounded. Combined with `unbounded coords=jump`, the curve climbs three times the visible y-range before disappearing. The factor 3 is hardcoded at `scholatex-plot.lua:155` and is not exposed as an option.
3. **Domain inference from the object** (`scholatex-plot.lua:84-101`). When `<plot>` falls back on `obj.x` because no explicit `x:{a, b}` was given, **infinite cells are skipped**: `if not c:match("inf") then lo = lo or c; hi = c end` (`scholatex-plot.lua:95`). When `<fn>` says `x:{-inf | ... | 1 | ... | +inf}`, the x window for the plot uses only the finite bounds.

There is no explicit domain split (no `\addplot domain=a:p1` then `\addplot domain=p2:b`), no `restrict x`, no nan-removal filter. The whole curve is one `\addplot` call (`scholatex-plot.lua:166-167`).

The contrast with `<vartab>` pole handling is intentional: variation tables treat poles as **declarative** (`||` written exactly where meant); plots treat them as a **runtime sampling problem** to suppress.

## 2.2 plot readability

CHANGELOG 2.2 added two axis-level options to make tick labels readable when they overlap the curve at `axis lines=middle`:

- **White-plate tick labels** at `scholatex-plot.lua:140-141`:
  ```
  every tick label/.append style={fill=white, inner sep=1pt, font=\footnotesize}
  ```
  Each automatically-generated tick number sits on its own opaque rectangle and shrinks to `\footnotesize`. No manual `\node` calls; `clip=false` is not used.
- **Negative-shorten axis extension** at `scholatex-plot.lua:142`:
  ```
  axis line style={shorten >=-6pt}
  ```
  A negative `shorten >` value *lengthens* the axis line at the end-arrow side by 6 pt, so the arrow clears the last tick number.

Both keys live on the same `\begin{axis}[...]` directive (`scholatex-plot.lua:137-167`); the `axis lines=middle` setting at `:139` predates 2.2 and is what causes the labels to overlap the curve in the first place.

## Related

- `architecture/compile-pipeline.md` — the `<fn>` accumulator, `sl.fn_parse`, and how the `let X = <fn ...>` form is lifted in the pre-pass.
- `architecture/math-pipeline.md` — the math compiler (`MATH.mathlite`) that runs over every cell of `<vartab>` and the labels of `<plot>`.
- `reference/fn-object-schema.md` — the field-by-field schema, examples, and the rules around `||` poles and `name:` defaults.
- `reference/tags-and-blocks.md` — the user-facing surface of `<vartab>` and `<plot>` (option set, error messages).
