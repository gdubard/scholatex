# init Workflow (Wave 1) Reflection

## Task
- Run the `/llmdoc:init` workflow on the scholatex repository by fanning out seven parallel investigators (reports `02`-`08`) over the transpile pipeline, tag/block surface, body syntax, examples, and reference document.

## Expected vs Actual
- Expected: pre-seeded canonical examples and a clean core/shell split would let each investigator produce a self-contained slice that composes into the stable docs.
- Actual: several seed examples did not match the real tag contract, the example corpus exposed undocumented surface that no investigator owned, and a real `<box>` `sep:`/`boxsep:` contract mismatch surfaced and had to be parked as a doc-gap.

## What Went Wrong
- Pre-seeded `<text>{hello}` and `<box Navy>{...}` examples for investigator `02` were invented from language-family intuition and conflicted with the actual registered tags and the rule that `<box ...>{...}` requires `{` to be the last non-whitespace character on the line.
- `examples/geometry.tex` exercised roughly twenty inline-math geometry operators that neither `README.md` nor `scholatex.tex` documented, so no wave-1 slice owned them.
- Investigators were not told that the 47 KB reference doc `scholatex.tex` is itself written in scholatex, which slowed the people reading it.
- The wave-1 core/shell split left "inline geometry vocabulary" and "body-syntax rules as one surface" homeless, forcing a follow-up pass.
- A genuine bug (the `<box>` `sep:` vs `boxsep:` mismatch between docs and code) was discovered during init with no pre-agreed channel for recording it.

## Root Cause
- The init prompt drafted investigator seeds before reading the body-syntax rules or sweeping the tag/block registry, so the priming step ran on assumptions instead of repo facts.
- The slice plan was drawn from a mental model of the project rather than from a discovery pass over `examples/` and the registry, so cross-cutting surfaces had no owner.
- There was no explicit init rule that "real bugs found during discovery become memory decisions, not silent doc fixes."

## Missing Docs or Signals
- No `guides/run-init.md` capturing the required pre-priming sweep (`grep -E 'sl\.register_tag|sl\.register_block'`, scan of `examples/*.tex`).
- No note that `scholatex.tex` is itself scholatex source, not opaque LaTeX.
- No reserved "catch-all discovery" slot in the standard init fan-out plan.
- No memory-decision pointer for contract mismatches surfaced mid-init.

## Promotion Candidates
- Promote a "discover-from-examples and registry before priming" rule into `guides/run-init.md`.
- Promote the "reference doc may be written in the project's own DSL" note into `must/project-basics.md`.
- Promote the "init records contract bugs as `memory/decisions/` doc-gaps, never silently aligns docs to code" rule into `must/working-agreement.md`.

## Follow-up
- Pre-seeded examples can be wrong if body-syntax rules were not read first; apply by sourcing every investigator seed from `examples/*.tex` or a `grep -E 'sl\.register_tag|sl\.register_block'` sweep before drafting prompts.
- Undocumented surface can be wide; apply by running a "discover-from-examples" pass over `examples/` as a mandatory step before the main investigation wave, not after.
- The reference doc can be written in the language under investigation; apply by stating up front in each investigator prompt when the target doc (e.g. `scholatex.tex`) is itself a scholatex source.
- Real user-visible bugs surface during init; apply by recording them as entries under `llmdoc/memory/decisions/` plus a doc-gap note, and never silently reconciling docs with code during init.
- Blanket core/shell splits over-split cross-cutting surfaces; apply by reserving one of the fan-out slots for a "catch-all discovery" investigator running concurrently with the themed ones.
