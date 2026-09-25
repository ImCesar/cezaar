---
name: build-spec
description: One part's files, interfaces, behaviour, and tests, with nothing left for the builder to decide. Read by a builder and the reviewer checking its work.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

A build-spec leaves nothing for the builder to decide — every choice below
is made here, not in the build.

## Part
Which part of the architecture this spec builds.

## Files
Every file to create or change.

## Interfaces and data shapes
Function signatures, schemas, formats — concrete enough to implement
against with no further decisions.

## Behaviour
What the part must do, including edge cases.

## Tests to write
The tests that prove the behaviour above.

## Done when
The exact command that proves this part is finished.

## Assumptions
Every unverified belief this spec rests on, each marked "assumption,
unverified".
