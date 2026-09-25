---
name: execution-report
description: What an execution team built, reviewed, and shipped, and what's still open. Read by the validation team and the operator.
written_to: outputs/{slug}/{type}.md
---

## Architecture
The architecture this run built, and where it lives.

## Integrated branch
The branch holding every wave, its worktree, and the integrator's final
suite run on it.

## Built
What was built, per part of the architecture, and which wave each part
was in.

## Review rounds
One row per part per round, so every run can be compared with the #40
baseline:

| Part | Round | Verdict | Blocking | Notes | Judge's rulings |
|---|---|---|---|---|---|

Rulings are counted as upheld / upheld, uncertain / downgraded / refuted,
or "not judged" for an APPROVE.

## Fixed
Upheld findings that were fixed, and the round that fixed each.

## Effort raises
Each builder whose effort was raised for a fix round, and the pane line
confirming it.

## Escalated
Everything sent to the operator: upheld, uncertain findings, integration
conflicts outside the contracts, triage triggers.

## Follow-ups
Every note from every round, downgraded findings included, one line each,
for the operator. Notes never cost a round; this is where they go instead.

## Left open

## Triage outcome
