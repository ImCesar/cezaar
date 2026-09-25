---
name: solution-recommendation
description: Every option scored against the acceptance criteria, and the one to build. Read by whoever writes the solution design.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Inputs
The problem-statement and solution-options scored here, as paths.

## Scoring
Every option from the solution-options artifact, scored against every
acceptance criterion from the problem-statement, by the criterion's number.
Each score carries its reasoning. A criterion that does not separate the
options still gets its row, saying so.

## Recommendation
One option, and why it wins the scoring above. Advice to the operator, who
makes the pick.

## What would change this
The fact, constraint, or priority that would flip the recommendation to a
different option, and to which one.
