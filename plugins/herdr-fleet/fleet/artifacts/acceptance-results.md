---
name: acceptance-results
description: One pass/fail row per acceptance criterion, with evidence from running the system. Read by whoever writes the validation report.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Tested
The solution-design and the integrated change this run tested: its branch,
worktree and commit.

## Results
One row for every numbered criterion in the solution-design's "Acceptance
criteria", in its numbering, none skipped:

| # | Result | Evidence |
|---|---|---|

Result is one of:
- `pass` or `fail` — decided by running the system; the evidence is the
  commands and the output that decided it;
- `untestable` — the criterion can't be tested as written; the evidence is
  why. It points back to the solution design;
- `not run` — the test couldn't run; the evidence is the error.

## Could not run
Anything that failed to build, start or execute, with the error.
