# Full Dashboard

Combines all sections into a single project status view.

## Section Order

Render each section in this order. Read each reference file and follow its commands and template:

1. **Board** — read `references/board.md`
2. **Milestones** — read `references/milestones.md`
3. **Open Pull Requests** — read `references/prs.md`
4. **Recent Activity** — read `references/activity.md`

## Dashboard Header

```
## Project Status: <repo-name>
```

Use the repo name parsed from `git remote get-url origin`.

## What's Next? Section

After all four sections, add a "What's Next?" prompt. This only appears on full dashboard or when explicitly asked "what should I work on".

### Prioritization

Pull candidates from the board data. Rank by:

1. **Column priority:** In Progress > Review > Backlog (skip Done)
2. **Label priority:** `p0:critical` > `p1:important` > `p2:later` > unlabeled
3. **Assignment:** Assigned to current user > unassigned > assigned to others

### Template

```
---

### What's Next?

Here are candidates to pick up:

1. **#22 — Auth flow** (In Progress, p1:important, assigned to you)
2. **#18 — Upload endpoint** (Backlog, p1:important, unassigned)
3. **#21 — Marketplace listing** (Backlog, p2:later, unassigned)

What would you like to work on?
```

Show up to 5 candidates. If no candidates (all Done), display: "All caught up — nothing in the backlog!"
