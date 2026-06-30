# Class Options Reference

## Scope

The complete user-facing class-options surface declared in `scholatex.cls`. Covers all 11 `\DeclareStringOption` entries, the single `\DeclareBoolOption`, the silent fall-through to `extarticle`, the font-fallback chain with `scholatex.respace`, the `imgdir` flattening, the `margins` arity rule, and the Lua-side switches (`padding`, `lang`, `untrusted`).

For the runtime consequences of `untrusted` (sandbox env, instruction limit, string caps), forward to `architecture/compile-pipeline.md` § "Sandbox (`untrusted=true`)". Do not duplicate that detail here.

For an inventory of known doc-vs-code drifts that touch this surface (notably `sep:` vs `boxsep:` and the `tex.jobname` fragility), see `memory/doc-gaps.md`.

## Stable Facts

### 1. Option declarations

All declarations live in `scholatex.cls:12-26` and are parsed by `kvoptions` (`\SetupKeyvalOptions{family=scholatex, prefix=scholatex@}`, `scholatex.cls:13`).

| Line | Name | Default | Type | Where consumed | What it does |
|---|---|---|---|---|---|
| `scholatex.cls:14` | `margins` | `20` | string (mm; scalar or 4-tuple) | `scholatex.cls:77-85` | Routes to `\geometry{...}` — see § 1.4. |
| `scholatex.cls:15` | `font` | `Latin Modern Roman` | string (font name) | `scholatex.cls:93-103` | Sets `\setmainfont` via the 3-step fallback chain — see § 1.2. |
| `scholatex.cls:16` | `size` | `11` | string (pt) | `scholatex.cls:28` | Passed straight to `extarticle` as `\LoadClass[<size>pt, a4paper]{extarticle}`. Use values `extarticle` supports (10, 11, 12, 14, 17, 20). `a4paper` is hardcoded. |
| `scholatex.cls:17` | `mathfont` | `Latin Modern Math` | string (font name) | `scholatex.cls:104-114` | Sets `\setmathfont` via the same 3-step chain. |
| `scholatex.cls:18` | `imgdir` | `img` | string (comma list) | `scholatex.cls:34-48` | Flattens to multi-entry `\graphicspath` — see § 1.3. |
| `scholatex.cls:19` | `tabwidth` | `8` | string (mm) | `scholatex.cls:64-65` | `\newlength{\scholatextab}` set to `<tabwidth>mm`. Consumed by the `tab` / `Ntab` style words. |
| `scholatex.cls:20` | `lineheight` | `8` | string (mm) | `scholatex.cls:66-67` | `\newlength{\scholatexline}` set to `<lineheight>mm`. Consumed by `line` / `Nlines` style words. |
| `scholatex.cls:21` | `linespread` | `1.0` | string (multiplier) | `scholatex.cls:132` | `\linespread{<linespread>}`. |
| `scholatex.cls:22` | `scriptscale` | `100` | string (percent) | `scholatex.cls:72-73` | `\scholatex@scriptfactor = scriptscale / 100`, fed to `\newcommand{\scholatexscript}[2]{\raisebox{#1}{\scalebox{...}{#2}}}` for `upN` / `downN`. |
| `scholatex.cls:23` | `padding` | `2` | string (mm; Lua-side) | `scholatex.cls:87` | `\directlua` writes `scholatex.config.padding`. Consumed by `<box>` defaults. |
| `scholatex.cls:24` | `lang` | `fr` | string (`fr` or `en`; Lua-side) | `scholatex.cls:87` | `\directlua` writes `scholatex.config.lang`. Consumed in `scholatex.lua:450-452, 692-693` to set `_SEPT` / `_SEPM` (text and math decimal separators) — see § 1.5. |
| `scholatex.cls:25` | `untrusted` | `false` | boolean (`\DeclareBoolOption`) | `scholatex.cls:88-92` | Switches `sl.transpile` between the trusted `_G` load and the sandbox env via `scholatex.config.untrusted`. Sandbox detail in `architecture/compile-pipeline.md` § "Sandbox (`untrusted=true`)". |

### 1.1 Silent fall-through to `extarticle`

`scholatex.cls:26`:

```latex
\DeclareDefaultOption{\PassOptionsToClass{\CurrentOption}{extarticle}}
```

Any class option scholatex does not declare is silently forwarded to `extarticle`. So `\documentclass[twocolumn, draft, oneside]{scholatex}` works without warning — the `extarticle` semantics apply. This pass-through is not mentioned in the README.

### 1.2 Font fallback chain (text and math)

Both text font (`scholatex.cls:93-103`) and math font (`scholatex.cls:104-114`) use the same three-step chain, written with `\IfFontExistsTF` (from `fontspec`):

1. **Step 1**: `\IfFontExistsTF{<name>}{ \setmainfont{<name>} }` — if the font name exists as typed, use it directly.
2. **Step 2 (respace retry)**: call `\directlua{scholatex.respace("scholatex@font")}`, which rewrites the macro body in place by inserting spaces at case boundaries; then re-test `\IfFontExistsTF`.
3. **Step 3 (warning + fallback)**: emit `\ClassWarningNoLine{scholatex}{Font '<name>' not found, falling back to ...}` and use `Latin Modern Roman` (text) or `Latin Modern Math` (math).

`scholatex.respace` (`scholatex.lua:770-775`) applies two regex substitutions to the macro body before the second `\IfFontExistsTF`:

- `("(%l)(%u)", "%1 %2")` — insert a space between lowercase followed by uppercase. Turns `LatinModernRoman` into `Latin Modern Roman`.
- `("(%u)(%u%l)", "%1 %2")` — insert a space between a run of uppercase and an uppercase-then-lowercase pair. Turns `DEJAVUSans` into `DEJAVU Sans`.

The rewrite happens via `token.get_macro` / `token.set_macro` so the subsequent `\IfFontExistsTF` sees the new name. The original `\scholatex@font` macro is mutated.

### 1.3 `imgdir` flattening

The `imgdir` option accepts a comma list and is expanded into a single multi-entry `\graphicspath` at class boot:

1. **Trailing slash on the single value** (unused). `scholatex.cls:34-38` computes `\scholatex@imgpath` by appending `/` if missing. This macro is then **never read again** in `scholatex.cls` — a code smell. (Note in § "Known issues".)
2. **`./` always first** (`scholatex.cls:39`). `\scholatex@graphicspaths = {./}` so the current directory wins over any `imgdir` entry. Files in the source directory take priority.
3. **Per-entry walk** (`scholatex.cls:40-47`). `\@for \scholatex@dir := \scholatex@imgdir \do{...}`:
   - `\StrDel{\scholatex@dir}{ }` strips spaces (so `imgdir=IMG, IMAGES/PNG` works with whitespace inside the list).
   - Append a trailing `/` if missing.
   - Concatenate onto `\scholatex@graphicspaths`.
4. **Single `\graphicspath` call** (`scholatex.cls:48`): `\expandafter\graphicspath\expandafter{\scholatex@graphicspaths}`.

So `imgdir=IMG, IMAGES/PNG` yields `\graphicspath{{./}{IMG/}{IMAGES/PNG/}}`.

**Note**: `imgdir` does **not** expand `~` or environment variables. The string is passed verbatim to LaTeX's file-search machinery, which on most distributions does not expand `~` either. README does not surface this.

### 1.4 `margins` semantics (scalar vs 4-tuple)

`scholatex.cls:77-85`:

```latex
\StrCount{\scholatex@margins}{,}[\scholatex@ncommas]
\ifnum\scholatex@ncommas>0\relax
  \StrCut{\scholatex@margins}{,}\scholatex@mt\scholatex@mrest
  \StrCut{\scholatex@mrest}{,}\scholatex@mr\scholatex@mrest
  \StrCut{\scholatex@mrest}{,}\scholatex@mb\scholatex@ml
  \geometry{top=\scholatex@mt mm, right=\scholatex@mr mm,
            bottom=\scholatex@mb mm, left=\scholatex@ml mm}
\else
  \geometry{margin=\scholatex@margins mm}
\fi
```

Comma count rules:

- **0 commas** (scalar form): `margins=N` → `\geometry{margin=N mm}` (all four sides).
- **≥ 1 commas** (4-tuple form): `margins=T,R,B,L` → `\geometry{top=T mm, right=R mm, bottom=B mm, left=L mm}`. Order is **top, right, bottom, left** (TRBL, CSS-margin-shorthand convention).

There is no 2-tuple shorthand or 3-tuple shorthand. With 1, 2, or 3 commas the `\StrCut` chain will populate some fields with empty strings, and `\geometry` will fail with a `Missing number` or `Illegal unit` error. Always pass exactly four values in the multi-form.

### 1.5 `lang` consequence on decimal separators

`scholatex.lua:450-452` reads `sl.config.lang` inside `build_lua`:

```lua
local sep_txt  = (lang == "en") and "." or ","
local sep_math = (lang == "en") and "." or "{,}"
```

These become the `_SEPT` (text) and `_SEPM` (math) locals injected into every transpiled chunk's preamble (`scholatex.lua:460`). The text formatter `_fmt(v)` (line 461) replaces the decimal dot via `gsub('%.', _SEPT, 1)`; the math formatter `_fmtm(v)` (line 462) uses `_SEPM`.

The math separator is `{,}` not `,` because a bare comma in math mode triggers TeX's punctuation-spacing rule. Wrapping in braces suppresses that.

Any value of `lang` other than `en` falls into the default branch and behaves like `fr` (French) — the `lang=fr` default uses comma as the decimal separator. So `lang=de`, `lang=es`, etc. silently render with comma decimals; that may or may not be the user's intent.

### 1.6 `untrusted` consequence

`scholatex.cls:88-92`:

```latex
\ifscholatex@untrusted
  \directlua{scholatex.config.untrusted = true}
\else
  \directlua{scholatex.config.untrusted = false}
\fi
```

`sl.transpile` (`scholatex.lua:703-746`) reads `sl.config.untrusted` and routes the generated chunk through either:

- **Trusted (default)**: `load(lua_code, "=sl-body")` directly under `_G`. Full Lua standard library, with `_G.vector` and `_G.__drawbuild = sl.build_figure_block` injected.
- **Sandboxed (`untrusted=true`)**: `load(lua_code, "=sl-body", "t", env)` with `env` from `make_sandbox_env()`. Whitelist only: `math`, `string`, `table`, `type`, `tostring`, `tonumber`, `ipairs`, `pairs`, `next`, `select`, `error`, `assert`, `unpack` (via `table.unpack`). Mode `"t"` forbids bytecode. The chunk runs inside `run_limited`, a coroutine with a `debug.sethook` budget of ≤ 200 hook firings × 10⁵ instructions = ≤ 2 × 10⁷ Lua VM instructions. `string.rep` / `string.format` are capped at 100 000 characters.

For full sandbox semantics, error rewriting, and the security boundary, forward to **`architecture/compile-pipeline.md` § "Sandbox (`untrusted=true`)"** (do not duplicate here).

`untrusted=true` does **not** sandbox LuaLaTeX as a whole — it only sandboxes the expression layer (`#{...}`, `for` loop bodies, `let X = EXPR` RHS). The class-level `\directlua` calls in `scholatex.cls:86-92, 135-145` run with full privileges regardless of the option.

## Sources of Truth

- `scholatex.cls:12-13` — `\RequirePackage{kvoptions}` and `\SetupKeyvalOptions`.
- `scholatex.cls:14-24` — the 11 `\DeclareStringOption` declarations.
- `scholatex.cls:25` — the single `\DeclareBoolOption[false]{untrusted}`.
- `scholatex.cls:26` — `\DeclareDefaultOption{\PassOptionsToClass{\CurrentOption}{extarticle}}`.
- `scholatex.cls:27-28` — `\ProcessKeyvalOptions*` and `\LoadClass[<size>pt, a4paper]{extarticle}`.
- `scholatex.cls:34-48` — `imgdir` flattening into `\graphicspath`.
- `scholatex.cls:64-67` — `\scholatextab` and `\scholatexline` length registers.
- `scholatex.cls:72-73` — `\scholatex@scriptfactor` derivation.
- `scholatex.cls:77-85` — `margins` comma-count branching.
- `scholatex.cls:86` — `\directlua{scholatex = require("scholatex")}` (Lua bootstrap).
- `scholatex.cls:87-92` — `\directlua` writes to `scholatex.config.{padding, lang, untrusted}`.
- `scholatex.cls:93-114` — text and math font fallback chains.
- `scholatex.cls:132` — `\linespread{\scholatex@linespread}`.
- `scholatex.lua:450-452` — `_SEPT` / `_SEPM` derivation from `sl.config.lang`.
- `scholatex.lua:770-775` — `scholatex.respace` case-boundary regex.
- `README.md:114-133` — the user-facing 12-row table that matches these declarations 1-for-1.

## Known issues

These are doc-vs-code drifts and code smells that intersect the class-options surface but are **not** about a class option itself. Catalogued centrally in `memory/doc-gaps.md`; surfaced here so users do not look in the wrong place.

### `sep:` is not a class option

The README documents `sep:N` as a `<box>` block attribute that "overrides locally" the class `padding` (`README.md:129`). It is **not** a class option — it is a per-block option on `<box>`. Worse, the README and the standalone manual also document `boxsep:N` at `README.md:515` and `scholatex.tex:449`, which the code **does not honour** (`scholatex-box.lua:41` only reads `opts.sep`). If you want to override per-box padding, write `<box sep:4>` — `<box boxsep:4>` is silently ignored and the class `padding` default applies.

See `memory/doc-gaps.md` § "Real user-visible bugs" for the citation chain.

### `tex.jobname` fragility

The body extraction in `scholatex.cls:135-145` reads `tex.jobname .. ".tex"` from disk. If the user compiles with `lualatex --jobname=other main.tex`, `tex.jobname` is `other`, not `main`; the class tries to read `other.tex` and either fails with a Lua I/O error or extracts the **wrong** body (a different file's `\begin{document}...\end{document}` content) without warning. This also breaks under build wrappers that use a temporary jobname (some latexmk configurations, arara recipes, CI scripts that pre-process).

See `memory/doc-gaps.md` § "Compile-time fragility not documented" and `architecture/compile-pipeline.md` § "Failure modes" for the full discussion.

### `imgdir` does not expand `~` or environment variables

The README does not say so, but `scholatex.cls:40-47` passes each comma-split directory verbatim to `\graphicspath` after only stripping spaces with `\StrDel`. LaTeX's file-search machinery on most distributions does **not** expand `~` (home-directory shorthand) or shell environment variables. So `imgdir=~/my-images` will look for a literal directory named `~` containing a `my-images/` subdirectory — almost never what the user wants. Use a relative or absolute path. README:114-133 omits this constraint.

See `memory/doc-gaps.md` for the rolling list of doc gaps that touch the class surface.
