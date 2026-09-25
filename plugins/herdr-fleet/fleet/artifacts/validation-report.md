---
name: validation-report
description: A verdict per acceptance criterion, with confirmed findings and every failure traced to its stage. Read by the operator.
written_to: outputs/{slug}/{type}.md
---

## Validated
The solution-design, architecture and execution-report this run took, and
the integrated branch and commit it validated.

## Verdicts
One row for every numbered acceptance criterion in the solution-design, in
its numbering:

| # | Verdict | Evidence |
|---|---|---|

Verdict is pass, fail, untestable or not run, from the acceptance results.

## Confirmed findings
Every blocking finding from the system verifier and the security reviewer,
with the judge's ruling on it.

## Traced failures
Every failing or untestable criterion and every upheld finding, traced to
the stage it came from:

| Failure | Origin stage | Why that stage |
|---|---|---|

Origin stage is `solution` (the wrong solution was chosen, or a criterion
can't be tested as written), `architecture` (built as designed, and the
design falls short) or `execution` (a departure from the architecture or a
build-spec, or a defect). When the evidence doesn't settle it, name the
candidate stages and what would decide between them. A failed final suite
on the integrated branch stops validation: it is the one traced failure,
origin `execution`, and every verdict above is not run.

## Security review
The lead's run log for the security decision; there is no other record of
it. Whether the security reviewer was spawned. If it was, the sensitive
paths that triggered it. If not, what was checked against triage-rules.md's
sensitive-path list and why nothing matched.

## Escalated
`upheld, uncertain` security or data-loss findings, for the operator.

## Not run
Every check that couldn't run, and what that leaves unverified.

## Follow-ups
Every note and downgraded finding, one line each. Notes never cost a round.
