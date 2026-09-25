---
name: solution-design
description: The chosen solution, its acceptance criteria, and what's out of scope. Read by the architecture and validation teams.
written_to: outputs/{slug}/{type}.md
---

## Problem statement
The problem-statement artifact this design answers, inline or linked.

## Options considered
The options weighed, and why each one not chosen was set aside.

## Chosen solution
What was chosen and why, and that the operator made the pick. It says what
solves the problem, not how to build it: files, interfaces, data shapes, and
build order belong to the architecture.

## Acceptance criteria
The problem-statement's numbered list, carried forward unchanged: same
numbers, same wording. Every later stage checks its work against exactly this
list, by number. A criterion changes during this stage only when an operator
answer changes it, and every change is marked at the criterion: what the
statement said, what it says now, and which operator answer changed it. A
changed or dropped criterion keeps its number; a new one takes the next
unused number.

## Out of scope
What this design deliberately does not solve.

## Review
The solution-reviewer's verdict, each blocking finding and how it was
resolved, and the notes left as follow-ups for the operator. This team has
no judge: the lead checks each blocking finding itself and fixes the ones
that hold, and the operator rules on every one the lead disputed. Each
disputed finding records the lead's reason and the operator's ruling.
