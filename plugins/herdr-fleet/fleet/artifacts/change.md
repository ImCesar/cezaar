---
name: change
description: A builder's or integrator's branch, commits, and how they verified it. Read by a reviewer or judge.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Branch

## Worktree

## Commits

## Built against
Which build-spec this change implements. For an integrated change, which
changes it merged and the system-architecture it merged them against.

## Merges
Integrated changes only: each merge in order, the part it brought in, and
every conflict with the contract clause that resolved it.

## Verification
The commands run and their output.

## Left open
Anything not done, and why.
