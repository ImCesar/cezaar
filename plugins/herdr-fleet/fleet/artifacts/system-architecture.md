---
name: system-architecture
description: The whole system a change lands in — boundaries, data and control flows, feedback loops, failure behaviour, the decisions made now and the options kept open — and its parts, their contracts and build order. Read by each component architect and the architecture reviewer.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Solution design
The solution-design this answers, linked, and the acceptance criteria by
number.

## Where this sits
The existing system this change lands in, cited by file and line, and where
this design draws its boundary: what is inside, and what is taken as given.

## Data and control flow
The end-to-end path a request or piece of data takes through the parts,
from where it enters to where it leaves, and which part drives each step of
that sequence.

## Stocks, flows and feedback
What accumulates (queues, files, state, work in progress) and the flows that
fill and drain it. The feedback loops: what the system watches about itself,
what it does in response, and the delay between the two.

## Failure behaviour
For each part: how it fails, who notices, what contains the damage, and
what state is left behind. Every path an acceptance criterion depends on has
designed behaviour.

## Decisions made now
Each significant decision that is expensive to change later and is made in
this design: the options, the trade-off, the choice and why.

## Options kept open
Each significant decision deliberately deferred. For every one:
- **Premium:** what keeping it open costs now — the interface, indirection,
  extra work or unused capability paid for today.
- **Why it is worth paying:** what is uncertain, and why that uncertainty
  makes the flexibility worth its cost.
- **Trigger:** the event or evidence that should make someone decide it, and
  who.

"None" is a complete answer. A deferred decision without a trigger does not
belong here.

## Parts
Every part, its one responsibility, and the acceptance criteria it serves.

## Contracts
For each pair of parts that talk: the interface, data shape, file format or
exit codes, who calls whom, and what each side may assume when the other
fails. Concrete enough that the two sides can be built apart and fit.

## Build order
The order the parts get built in, which can be built in parallel, and why.

## Reconciliation
Filled in when the build-specs come back: each problem found, classified as
system-level or part-level, and what was changed or sent back.

## Assumptions and open questions
Every unverified belief, marked "assumption, unverified", and every question
with who or what would settle it.
