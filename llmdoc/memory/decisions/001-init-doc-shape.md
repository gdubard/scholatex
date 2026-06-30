# Decision 001 — Initial llmdoc Shape

## Status

Accepted (wave 1).

## Context

scholatex's stable code base is small (`scholatex.cls` plus 14 Lua modules, ~6 KLOC total) but its user-facing contract surface is large: 12 class options, the closed body-syntax language (tags + blocks + `let` + control flow + escapes), the inline math mini-language with 14 dispatch tables plus bespoke arms, the `<draw>` shape catalogue with closed-form solvers, and the function-studies object/tag chain. The wave-1 init investigations (`02`-`10` under `.llmdoc-tmp/investigations/`) produced extensive but raw evidence. The init reflection (`memory/reflections/init-process.md`) called for a tighter doc shape than "one architecture doc per module" — too many shallow files would scatter the read order and hide ownership.

## Decision

The wave-1 doc tree groups by **ownership boundary** for architecture and by **stable contract surface** for reference, not by source file or module.

Concretely:

1. **One architecture doc per ownership boundary.** The three boundaries are the transpiler core, the `<draw>` block, and the math mini-language. They are pipeline-shaped (each has a clear entry point, a recursive descent, an emission step, and failure modes); each merits a single deep doc rather than four shallow ones.
   - `architecture/compile-pipeline.md` for `scholatex.cls` + `scholatex.lua` + the style/util helpers it depends on.
   - `architecture/figure-draw.md` for `scholatex-figure.lua` and the `__drawbuild` runtime hand-off.
   - `architecture/math-pipeline.md` for `scholatex-math.lua` and its single call site.
   - Wave 2 will add `architecture/style-and-tags.md` (for `scholatex-style.lua` and the three-way `emit_tag` dispatch) and `architecture/function-studies.md` (for `<fn>` + `<vartab>` + `<plot>`).
2. **One reference doc per stable contract.** Class options, body syntax, tag/block registry, math vocabulary, geometry math vocabulary, text-style vocabulary, draw shape catalogue, fn-object schema. Each maps to one user-facing surface a doc reader will look up by name.
3. **Geometry math vocabulary kept separate from the main math vocabulary.** `examples/geometry.tex` exercises ~20 geometry operators (`angle`, `triangle`, `frame`, `vec` infix dot/cross, `collinear`, `distance`, ...) as a distinct surface. None is documented in README or `scholatex.tex`. Splitting the reference makes the omission visible and lets the geometry doc land verbatim from the investigation catalogue without bloating the main math vocabulary.
4. **`doc-gaps.md` is one rolling file, not split per module.** A wave of ~30 doc-vs-code drifts surfaced during init. A single rolling file is easier to triage, easier to track in `git`, and easier to update from any future investigation. Per-module gap files would scatter the same evidence across five places without adding retrieval value.
5. **Wave-1 ships only a subset of the planned tree.** The `index.md` already lists the wave-2 docs and marks them `(wave 2)`. This is more honest than back-fitting the index later and gives wave 2 a known target. It also signals to readers that the routing decisions in `must/doc-routing.md` may forward to a not-yet-existing doc — explicitly tagged.

## Consequences

- **Read order is short and predictable.** The three `must/` docs plus the relevant `architecture/*` doc cover almost any non-trivial task. The reference docs are lookup destinations, not read-on-startup.
- **Init-discovered bugs go to `memory/decisions/` plus `memory/doc-gaps.md`, never silent doc fixes.** This is the rule the init reflection asked for (`memory/reflections/init-process.md` §"Promotion Candidates"). Wave 1 records the surfaced bugs in `memory/doc-gaps.md`; this decision file records the structural reasoning.
- **Wave 2 has a clear scope.** The wave-2 docs are listed in `index.md` with `(wave 2)` markers; they fill in the reference contracts and the two remaining architecture docs. No structural decisions are deferred to wave 2 except how to format each individual reference page (which is a templates question, not an ownership question).

## Alternatives considered

- **One architecture doc per Lua module.** Rejected: too shallow, too many cross-references, and the four "small" modules (`scholatex-img.lua`, `scholatex-toc.lua`, `scholatex-section.lua`, `scholatex-list.lua`) do not justify a doc each — they belong in `reference/tags-and-blocks.md`.
- **Merge math and geometry vocabularies.** Rejected: the geometry surface is currently undocumented anywhere and merging would hide that gap. Keeping it separate makes the discovery surface in `examples/geometry.tex` a first-class doc input.
- **Per-module `doc-gaps.md`.** Rejected: ~30 entries fan out into 5 files at ~6 each, and the cross-module entries (e.g. the bilingual error strings spanning `scholatex-math.lua` and `scholatex-figure.lua`) would force duplication.
- **Single `architecture/overview.md` instead of three deep docs.** Rejected: the three pipelines are large enough (each in the 100-300 line range when written compactly) that merging would create a single 600+ line doc whose retrieval beat would suffer.

## References

- `memory/reflections/init-process.md` — the wave-1 reflection that established the discover-from-examples rule and the "no silent doc fixes" discipline.
- `.llmdoc-tmp/investigations/02-transpile-pipeline.md` § "Promotion Notes" — the seed for `architecture/compile-pipeline.md`.
- `.llmdoc-tmp/investigations/09-inline-geometry-vocabulary.md` § "Promotion Notes" — explicitly asked for a separate geometry doc.
- `.llmdoc-tmp/investigations/10-document-body-contract.md` § "Promotion Notes" — explicitly asked for `reference/body-syntax-rules.md` as one canonical user-facing rule reference.
