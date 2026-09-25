---
name: problem-statement
description: The problem restated with who it affects, constraints, and checkable acceptance criteria. Read by whoever ideates and evaluates solutions.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Problem
The problem restated in the analyst's own words, not a copy of the input. The
need, never a solution to it.

## Who it affects
The people or systems whose behavior or work changes.

## Constraints
Limits the solution must respect — technical, resource, or policy.

## Acceptance criteria
A numbered list, starting at 1. Each item names an outcome, not a mechanism,
and is checkable by inspection, a command, or a test — never a description of
intent. Every later stage refers to these by number.

## Assumptions
Every unverified belief this statement rests on, each marked "assumption,
unverified".

## Open questions
Questions only the operator can answer, and what depends on each answer.

## Sources
The code, tools, or documents read to write this, as file:line, command, or
URL. None is a complete answer when the problem touches nothing that exists.
