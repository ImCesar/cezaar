# Review bar

Every review starts with a verdict: APPROVE or BLOCK. APPROVE is the expected
outcome for work that meets its acceptance criteria. A reviewer is not
measured by how many problems it finds, and a review with no findings is
complete.

Report everything you notice, but classify each finding against this bar.
Only blocking findings cost a round.

## Code changes

Blocks, if any of these hold:
- an acceptance criterion in the spec is not met;
- a test fails, or a test the spec requires is missing;
- a correctness bug with a concrete failure scenario: a specific input or
  state that produces a wrong result, a crash, a hang or lost data;
- a contract from the spec or architecture is broken: an interface, data
  shape, file format or exit code;
- a security or data-loss risk;
- the change alters behaviour the spec didn't ask it to.

Never blocks (report it as a note):
- wording, naming, comments, doc phrasing, formatting, style;
- test polish: titles, structure, extra cases beyond what the spec requires;
- "could be clearer", "could be simpler", refactoring suggestions;
- hypothetical future problems with no failure scenario in this change's
  actual use.

## Designs (solution design, architecture, build specs)

Blocks, if any of these hold:
- an acceptance criterion is not addressed, or can't be checked;
- the document contradicts itself or its input;
- a build spec leaves a design decision to the builder;
- a contract between parts can't hold when the parts are built together;
- a failure on a path the acceptance criteria depend on has no designed
  behaviour.

Never blocks (report it as a note): wording, structure, approaches that
weren't chosen, detail a builder doesn't need.

## After the first round

Only regressions block: a problem the fix itself introduced that meets the
bar above. Anything else found in a later round is a note.

## Notes

Notes never trigger a fix round. The lead collects them into the stage's
report as a follow-up list for the operator.
