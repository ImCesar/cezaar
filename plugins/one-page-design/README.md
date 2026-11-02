# one-page-design

A skill that turns any design into a Librande-style one-page document: one
printable HTML surface, a depiction in the middle, the words hung off it.
Invoke by asking for a one-page design, or load `SKILL.md`. Spec and plan
are in `docs/`. Reference slides and what each teaches are in
`examples/librande/`. Tests: `python3 -m pytest tests/` for the script;
`tests/baselines/` and `tests/results/` hold the skill's own
before-and-after runs.

## Not yet tested

Route A, the commissioned illustration, has not been run in this repo's
tests. No illustrator is configured here, and the brief is written to work
with any illustrator rather than one model, so there was none to call. Every
recorded run uses route B, the hand-drawn SVG.

## Follow-ups

- **Render-based out-of-bounds check.** The scaffold's poster clips anything
  past its edges, and the fit-check parses the page without rendering it, so
  clipped content passes. For now SKILL.md step 5 has the agent check the
  preview PNG by eye. When Chrome is present, the fit-check should render the
  page and report any element that falls outside the poster box.
