---
name: herdr-orchestrate
description: Alias for /herdr-fleet:invoke-team execution - your session leads the execution team, which builds an `architecture` into reviewed changes with Claude workers in Herdr panes. It needs an `architecture` as input. For small, clear work with no architecture, use /herdr-fleet:invoke-agent builder with a `build-spec` instead.
---

# Alias: `invoke-team execution`

This skill is a thin forwarder, kept so the old name keeps working. It holds
no procedure of its own.

Read `<plugin>/skills/invoke-team/SKILL.md` and follow it exactly as if
the operator had typed `/herdr-fleet:invoke-team execution`, passing along any
input they gave here.
You are reading `<plugin>/skills/herdr-orchestrate/SKILL.md`, so you know
`<plugin>`.

The execution team takes an `architecture`. If the operator has small, clear
work and no architecture, say that `/herdr-fleet:invoke-agent builder` with a
`build-spec` is the fit for it, and ask which they want, rather than
stretching the execution team over it.
