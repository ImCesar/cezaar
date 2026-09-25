---
name: architecture
description: Designs a solution-design into an architecture — the whole system, its parts and contracts, and a build-spec per part a builder can follow without deciding anything.
lead: architect
members:
  - persona: system-architect
    display_name: System architect
  - persona: component-architect
    display_name: Component architect
  - persona: architecture-reviewer
    display_name: Architecture reviewer
  - persona: researcher
    display_name: Researcher
takes: [solution-design]
produces: [architecture]
policy: [review-bar.md]
# Reserved for #28 (in-team builder/reviewer loop). Empty until that issue
# gives it a shape.
loop: {}
peers: []
---

The second stage of the work: designing the solution the operator chose
into something the execution team can build. Its `architecture` is what the
builders' briefs come from, and what the validation team checks the finished
system against.

`/herdr-fleet:invoke-team architecture` makes the operator's session this
team's lead, `architect`, which carries the procedure. The design thinking
happens in the members, so it runs on their models: the `system-architect`
designs the whole system and later reconciles the parts, a
`component-architect` designs each part, and the `architecture-reviewer`
checks the result in a fresh context. **The operator settles the
hard-to-change decisions and the options kept open**, before any part is
designed.

`policy: [review-bar.md]` is there because `architecture-reviewer` produces
`findings`, and its "Designs" section is what separates a blocking finding
from a note. Paths in this file's frontmatter resolve from the repository
root, as in every team file.

There are no `peers`. Component architects must not negotiate contracts
between themselves, because the contracts belong to the system architect,
and every other step reads what the one before it wrote.
