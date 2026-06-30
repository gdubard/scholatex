# Startup

## Required reading, in order, on every run

1. `llmdoc/must/project-basics.md` — what scholatex is and the non-negotiable constraints.
2. `llmdoc/must/working-agreement.md` — how the assistant works on this repo.
3. `llmdoc/must/doc-routing.md` — decision tree for "where do I read next?".

That is the entire must-read pack. The category catalogue lives in `llmdoc/index.md`.

## Escalate immediately when

- About to edit `scholatex.cls`, `scholatex.lua`, or any `scholatex-*.lua` module → read the relevant `architecture/*.md` first.
- About to extend the inline math language → read `architecture/math-pipeline.md` and the `reference/math-vocabulary.md` / `reference/math-geometry-vocabulary.md` so the new name does not collide.
- About to add a `<draw>` shape, mark, or primitive → read `architecture/figure-draw.md` and `reference/draw-shape-catalogue.md`.
- About to change the body-syntax rules (escapes, math delimiters, `let` forms, control flow) → read `architecture/compile-pipeline.md` and `reference/body-syntax-rules.md`. These rules are user-facing contract.
- About to triage a "doc says X, code does Y" report → read `memory/doc-gaps.md` first.
- Re-running an `/llmdoc:*` workflow or any process that previously surprised you → read the matching `memory/reflections/*.md`.

## When in doubt

Run the lookup through `must/doc-routing.md`. It is the index of typical situations to next-document mappings.
