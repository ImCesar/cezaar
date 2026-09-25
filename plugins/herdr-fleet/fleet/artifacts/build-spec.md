---
name: build-spec
description: One part's files, interfaces, behaviour, and tests, with nothing left for the builder to decide. Read by a builder and the reviewer checking its work.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

A build-spec leaves nothing for the builder to decide — every choice below
is made here, not in the build. If a builder would have to choose a name, a
shape or a behaviour, the spec is not finished.

## Part
Which part of the system-architecture this spec builds, linked, and the
acceptance criteria it serves, by number.

## Contracts
Every contract this part implements or depends on, as the
system-architecture states it, and where in this spec each is honoured.

## Files
Every file to create or change, by path.

## Interfaces and data shapes
Function signatures, types, schemas, formats, exit codes — concrete enough
to implement against with no further decisions.

## Behaviour
What the part must do, including each edge case and each error case and
what it returns or does.

## Tests to write
Each test, what it sets up, and what it asserts.

## Done when
The exact command that proves this part is finished, and what it prints on
success.

## Assumptions
Every unverified belief this spec rests on, each marked "assumption,
unverified".
