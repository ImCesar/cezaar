---
name: solution-design
description: Turns a raw problem into a solution-design the operator chose — understand, ideate, pick, review.
lead: product-manager
members:
  - persona: problem-analyst
    display_name: Problem analyst
  - persona: solution-ideator
    display_name: Solution ideator
  - persona: solution-evaluator
    display_name: Solution evaluator
  - persona: solution-reviewer
    display_name: Solution reviewer
  - persona: researcher
    display_name: Researcher
takes: [problem]
produces: [solution-design]
policy: [review-bar.md]
# Reserved for #28 (in-team builder/reviewer loop). Empty until that issue
# gives it a shape.
loop: {}
peers: []
---

The first stage of the work: understanding a problem, finding ways to solve
it, letting the operator pick one, and checking the result. Its
`solution-design` is what the architecture team designs from, and what the
validation team checks the finished work against, criterion by criterion.

`/herdr-fleet:invoke-team solution-design` makes the operator's session this
team's lead, `product-manager`, which carries the procedure. Gathering the
problem through conversation is part of the job, so a thin `problem` is a
starting point rather than a gap. Each step has its own persona so it runs on
its own model and behaves the same way every run. **The operator makes the
pick**; no persona on this team chooses the solution.

`policy: [review-bar.md]` is there because `solution-reviewer` produces
`findings`, and its "Designs" section is what separates a blocking finding
from a note. Paths in this file's frontmatter resolve from the repository
root, as in every team file.

There are no `peers`: every step reads the artifact the one before it wrote,
and the lead carries each one forward, so no pair of members has anything to
say to each other directly.
