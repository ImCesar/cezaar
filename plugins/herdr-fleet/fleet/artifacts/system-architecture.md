---
name: system-architecture
description: Where a change sits in the existing system, its flows, failure behaviour, and its parts' contracts. Read by whoever writes each part's build-spec.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Where this sits
The existing system this change lands in, and its boundary.

## Data and control flow
How data and control move through the change, including feedback loops.

## Failure behaviour
What happens when each part fails, and what contains it.

## Hard-to-change decisions
Each decision that is expensive to reverse later, its trade-off, and why
it was made this way.

## Options kept open
For each option deliberately left undecided: what it costs to keep open,
why that cost is worth paying, and when to decide it.

## Parts
Every part of the system, and the contract between each pair that talks
to each other.

## Build order
The order the parts get built in, and why.
