---
name: validation
description: Checks the whole built result against its solution-design and system-architecture, and traces every failure to the stage it came from.
lead: qa-lead
members:
  - persona: acceptance-tester
    display_name: Acceptance tester
  - persona: system-verifier
    display_name: System verifier
  - persona: security-reviewer
    display_name: Security reviewer
  - persona: judge
    display_name: Judge
  - persona: runner
    display_name: Runner
takes: [solution-design, architecture, execution-report]
produces: [validation-report]
policy: [triage-rules.md, review-bar.md]
# Reserved for #28 (in-team builder/reviewer loop). Empty until that issue
# gives it a shape.
loop: {}
peers: []
---

The last stage of the work. The execution team checked each change against
its `build-spec`; this team checks the whole result. It asks whether the
built system matches the `system-architecture`, and whether it solves the
problem the `solution-design` defined, criterion by criterion. Its
`validation-report` traces every failure to the stage it came from
(solution, architecture or execution), which tells the operator which stage
to invoke again.

`/herdr-fleet:invoke-team validation` makes the operator's session this
team's lead, `qa-lead`, which carries the procedure. It fixes nothing: a
failure is reported and traced, and the fix is a new run of the stage it
points at.

`policy` names both files. `triage-rules.md` holds the sensitive-path list
that decides whether `security-reviewer` is spawned at all, and
`review-bar.md` is what `system-verifier` and `security-reviewer` classify
their findings against. `judge` is the same persona the execution team uses.
Paths in this file's frontmatter resolve from the repository root, as in
every team file.

There are no `peers`: each worker reports to the lead, and the judge must
stay sealed off from the reviewers whose findings it rules on.
