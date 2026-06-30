# llmdoc Index

## Purpose

- Global map of the llmdoc system for scholatex.
- This file lists categories and the key documents in each category.
- The startup reading order lives in `llmdoc/startup.md`, not here.
- The situation-to-document decision tree lives in `llmdoc/must/doc-routing.md`, not here.

## Categories

- `must/`: tiny, stable startup pack — read on every run.
- `overview/`: project identity, scope, boundaries, major areas.
- `architecture/`: pipelines, ownership boundaries, invariants, dispatch tables.
- `guides/`: one workflow per document.
- `reference/`: stable lookup facts — class options, body syntax, vocabularies, schemas.
- `memory/`: process memory — reflections (owned by `reflector`), decisions and doc gaps (owned by `recorder`).

## Key Documents

### must

- `must/project-basics.md`: what scholatex is, hard engine requirement, repo layout, compile model, naming taboo, closed-language stance.
- `must/working-agreement.md`: how the assistant works on this repo — alignment, citation style, extension points, contract discipline.
- `must/doc-routing.md`: decision tree mapping common situations to the next document or source file.

### overview

- `overview/project-overview.md`: identity, boundaries, major areas, BREAKING migration anchors.

### architecture

- `architecture/compile-pipeline.md`: end-to-end transpile and execute pipeline from `scholatex.cls` boot to `tex.print`.
- `architecture/figure-draw.md`: the `<draw>` block — solvers, graft, marks, primitives.
- `architecture/math-pipeline.md`: the inline math mini-language `mathlite` (`$ ... $`).
- `architecture/style-and-tags.md`: the three-way tag dispatch and the STYLE classifier.
- `architecture/function-studies.md`: `<fn>` parsing, `<vartab>`, `<plot>`.
- `architecture/test-pipeline.md`: l3build regression harness, `testfiles/` layout, `_keep_patterns` whitelist, parallel-check buckets, baseline-regen cycle.
- `architecture/release-pipeline.md`: tag-push to GitHub prerelease to manual CTAN upload, with the `ctan-release` environment gate and the `l3build upload` stdin workaround.

### guides

- `guides/add-tag-or-block.md`: how to register a new tag or block in a new module.
- `guides/extend-math-vocabulary.md`: how to add a math keyword to `mathlite`.
- `guides/write-example-document.md`: how to write a compilable example under `examples/`.

### reference

- `reference/class-options.md`: the 12 class options and their consumption sites.
- `reference/body-syntax-rules.md`: the canonical body-syntax contract (escapes, math, control flow, `let`, edge effects).
- `reference/tags-and-blocks.md`: the full tag/block registry.
- `reference/math-vocabulary.md`: the algebraic math vocabulary in `mathlite`.
- `reference/math-geometry-vocabulary.md`: the geometry subset of `mathlite` (kept separate because `examples/geometry.tex` is the only exercise surface).
- `reference/text-style-vocabulary.md`: style words, colours, fonts, alignment, tabs, skips, scripts.
- `reference/draw-shape-catalogue.md`: the `<draw>` shape catalogue with required/optional/defaulted attributes.
- `reference/fn-object-schema.md`: the `<fn>` object fields and how `<vartab>` and `<plot>` consume them.
- `reference/build-and-ci-files.md`: per-file reference for `build.lua`, `Makefile`, `.github/workflows/*`, `.github/tl_packages`, `scripts/*`, and `testfiles/support/regression-test.cfg`.

## Routing Rules

- Start with `startup.md` on every run — the startup reading order lives there.
- For a typical situation (extending the language, diagnosing a failure, writing an example, picking a name, working on build / CI / release), consult the decision tree in `must/doc-routing.md`.
- Touching a subsystem → read the matching `architecture/*` doc before editing. The l3build regression harness has its own architecture doc (`architecture/test-pipeline.md`); the tag-push and CTAN-upload flow is in `architecture/release-pipeline.md`.
- Looking up a stable fact (option, escape, vocabulary entry, build-file shape) → read the matching `reference/*` doc. Per-file build / CI references live in `reference/build-and-ci-files.md`.
- Following a workflow (new tag, new shape, new example) → read the matching `guides/*` doc.
- Revisiting a known-fragile area or repeating a workflow → read the matching `memory/reflections/*` entry first.
- For a doc-vs-code discrepancy or known gap → consult `memory/doc-gaps.md` before changing either side.

## Memory

`memory/` is process memory, not project knowledge. It is not part of the stable-doc inventory above.

- `memory/reflections/`: process lessons (owned by `reflector`).
- `memory/decisions/`: structural decisions (owned by `recorder`); current entry `001-init-doc-shape.md`.
- `memory/doc-gaps.md`: rolling list of documentation gaps and doc-vs-code drifts.

## Known doc gaps

See `memory/doc-gaps.md` for the rolling list of documentation gaps and doc-vs-code drifts surfaced during init investigations.
