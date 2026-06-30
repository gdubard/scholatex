# How to Add a New Tag or Block

This guide is for adding a new built-in tag or block to scholatex. For user-side aliases (`let h = <...>` and friends) read `reference/tags-and-blocks.md` instead — those are runtime constructs, not new modules.

## 1. Preconditions

### Choose tag or block

- **Tag** — single-line `<name OPTS>{CONTENT}` or `<name OPTS>...end-of-line`. Body is one logical line. Examples: `<img>`, `<plot>`, `<vartab>`, `<tableofcontents>`.
- **Block** — multi-line `<name OPTS>{` ... `}`. The opener regex (`scholatex.lua:402`) requires `{` to be the **last non-whitespace character on the line**. Examples: `<box>`, `<grid>`, `<list>`, `<section>`, `<matrix>`, `<table>`, `<draw>`.

If body content spans more than one source line, you need a block. If the content fits on one line and you do not need control-flow inside it, a tag is enough.

### Check for name collisions

The name must not already be used. Search:

- Existing `sl._tags` / `sl._blocks` entries — any other `sl.register_tag("NAME", ...)` or `sl.register_block("NAME", ...)` call. `sl.register_*` raises `scholatex: tag/block 'NAME' is already registered (name clash)` (`scholatex.lua:17-21, 22-28`) at module load if a clash exists.
- `STYLE.resolve` matchers (`scholatex-style.lua:40-134`). A name that resolves as a style word will be unreachable as a tag because the STYLE fallback is reached after `sl._tags` (`scholatex.lua:118-122`) — but `warn_if_shadows` will only catch user-side collisions, not module-registered ones.
- Names a user might want for `let` — grep `examples/*.tex` for `let NAME =` patterns. Conservative choice: avoid one- and two-letter names, lowercase Greek letters, and English nouns that read naturally as variables.
- The math vocabulary (`reference/math-vocabulary.md`, `reference/math-geometry-vocabulary.md`) if the name might look like a math operator. Math operators live in `scholatex-math.lua` and do not collide with tags — but a name like `<circle>` would surprise a user who knows `circle(O, r)` inside `$ ... $`.

## 2. Main steps

### Pick the module file

Add a new module file alongside the existing `scholatex-<topic>.lua` files (`scholatex-box.lua`, `scholatex-list.lua`, `scholatex-grid.lua`, `scholatex-section.lua`, `scholatex-img.lua`, `scholatex-table.lua`, `scholatex-matrix.lua`, `scholatex-vartab.lua`, `scholatex-plot.lua`, `scholatex-figure.lua`, `scholatex-toc.lua`). Choose by domain:

- Layout / structure → `scholatex-<your-block>.lua` in the layout family.
- Math object → `scholatex-<your-block>.lua` next to `-matrix`, `-vartab`, `-plot`.
- Data → next to `-table`, `-matrix`.
- Figure / drawing → either inside `scholatex-figure.lua` (composes with `<draw>`) or a fresh module.

Require it from the eager-load chain at `scholatex.lua:779-789`:

```lua
sl.use("scholatex-<topic>")
```

There is **no lazy load**. Every module is loaded once at class boot.

### Implement the dispatch

Use the standard skeleton from one of the existing simplest modules. `scholatex-img.lua:4` (registered tag) is the smallest:

```lua
local U = require("scholatex-util")
return function(sl)
  sl.register_tag("img", function(api, words, content)
    local opt = "width=\\linewidth"
    local w = words[2]
    if w then
      -- ... dimension parsing ...
    end
    api.lit("\\includegraphics[" .. opt .. "]{" .. content .. "}")
  end)
end
```

For a block, the signature changes to `function(api, words_str, inner_str)`. See `scholatex-toc.lua:1-14` for a six-line block, or `scholatex-box.lua:94` for the canonical block pattern with options.

The `api` table (`mkapi` at `scholatex.lua:95-111`) gives you:

- `api.lit(t)` — append `emit("LITERAL")` to the chunk.
- `api.raw(t)` — append raw Lua to the chunk (for lifting your own control flow).
- `api.forward_text(t)` — recursively process inline text (tags, `$...$`, `#NAME`).
- `api.process_block(lines)` — wrap a list of strings as `{text=...}` records and recurse into `process_lines`. Use this for nested block bodies.
- `api.is_control_open` / `api.lua_control` — the core's control-flow detector (`scholatex.lua:64-91`), exposed for blocks that lift loops inside their own bodies (`<draw>` uses this).

### Handle options

Use `U.parse_attrs(s, opts)` from `scholatex-util.lua:142-187`. It is the canonical `key:{value}` parser, used by every block module. The `opts` knobs:

- `opts.tag` — used in error messages (`<TAG>`); default `"tag"`.
- `opts.hint` — custom suffix after the standard "expects key:value options" message.
- `opts.brackets` — also accept `key:[group]` form (depth-aware over `[ ]`). `scholatex-figure.lua:173` uses this for the `template:[...]` form on `<grid>`.
- `opts.require_group` — force `key:{value}`, forbidding `key:value`. Used by `<plot>` and `<vartab>` for stricter parsing.
- `opts.on_bare` — callback for non-`key:` words. Return truthy to consume; falsey to error. `<box>` uses this to accept placement codes (`tl mc br`) as bare words (`scholatex-box.lua:24-27`).

Two ways to expose option semantics outside your module: declare module-locals (see `scholatex-box.lua:18-29`), or expose helpers on `sl` (see `scholatex-box.lua:90-92`, used by `<grid>` and `<area>`).

### Emit LaTeX

A handler returns nothing; it emits by appending to the chunk through `api.lit` / `api.raw`. The final value the chunk returns is the assembled LaTeX string (`scholatex.lua:599-600`).

- For a tag, emit the LaTeX directly via `api.lit("...")` or string-concatenate the content first.
- For a block, the body comes in as `inner_str`. If you need to walk it line by line, use `api.process_block(inner_lines)` where `inner_lines` is a string array. If you need nested block handling, lean on `U.collect_block` (`scholatex-util.lua:85-106`) before recursing.

CamelCase colour names that appear in your options should go through `sl.style.resolve(word)` (`scholatex-box.lua:10-16` is the reference pattern). The matcher accepts any of the 151 names in `S.CSS` (`scholatex-style.lua:14`) and emits a descriptor whose `open` field is `\textcolor{NAME}{`. Extract the captured name with `open:match("\\textcolor{(.-)}")` and use it directly in your LaTeX option.

## 3. Verification

1. Compile `examples/basics.tex` and any example that exercises blocks similar to yours. Catches name clashes at boot time and broken registration paths.
2. Write a minimal example file `examples/<your-tag>.tex` exercising the new tag/block. Follow `guides/write-example-document.md` for the conventions.
3. Run `lualatex examples/<your-tag>.tex` twice (the second pass picks up cross-references).
4. Visually inspect the PDF.
5. Check stderr for unexpected `scholatex: warning: ...` output (especially `warn_if_shadows` — see `architecture/style-and-tags.md`).
6. Compile with `untrusted=true` if your tag will be used in sandboxed documents. Confirm no global accidentally leaks into the chunk.

## 4. Common failure points

| Symptom | Likely cause | Where to look |
|---|---|---|
| `scholatex: tag 'X' is already registered (name clash)` at compile | Two modules registering the same name | Search `sl.register_tag("X"` / `sl.register_block("X"` across all `scholatex-*.lua` |
| Silent dead-write of a user `let X = ...` | A user happened to `let` a name colliding with your built-in. `warn_if_shadows` logs to stderr but writes the table anyway; your built-in still wins via dispatch order | `architecture/style-and-tags.md` § "warn_if_shadows" |
| Block opener not detected (`unknown tag attribute: 'box'`) | The line did not end with `{`. The block-opener regex requires `{` to be the last non-whitespace character | `scholatex.lua:402`; `architecture/compile-pipeline.md` § "Failure modes" |
| `unknown tag attribute: 'X'` after registering | Your module is not in the eager-load list at `scholatex.lua:779-789`, or your module file did not `return function(sl) ... end` | Confirm the `sl.use` call exists; confirm the closure shape |
| Options parse but are silently ignored | A typo on the option key. `parse_attrs` accepts any `key:val`; an unread key falls through to default | Read `scholatex-util.lua:142-187`; ensure your handler reads every key you parse |
| Body emits with literal `\par` showing through | Your handler emitted text but forgot the trailing `emit(" \\par ")`. Block dispatch in `process_lines` does add one at `scholatex.lua:426`; tag handlers do not get this for free | `architecture/compile-pipeline.md` § 5 |

## 5. Related docs

- `architecture/compile-pipeline.md` — the dispatch order, the `process_lines` regex, what `api` exposes, and how the generated Lua chunk is run.
- `architecture/style-and-tags.md` — the three-way dispatch between `sl._tags`, `MACRO`, and `STYLE.classify_split`; the BLOCKALIAS rewrite.
- `reference/tags-and-blocks.md` — the existing tag/block catalogue with options and error messages.
