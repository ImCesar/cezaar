# Milestone Progress

Displays open milestones with progress bars.

## Commands

```bash
gh api repos/<owner>/<repo>/milestones --jq '.[] | {title, open_issues, closed_issues, due_on, description}'
```

## Parsing

- For each milestone: `total = open_issues + closed_issues`, `pct = closed_issues / total`
- Progress bar: 8 characters wide. Fill `round(pct * 8)` with `█`, remainder with `░`
- Sort by due date (earliest first), then by title alphabetically for milestones without due dates

## Display Template

```
### Milestones
| Milestone               | Progress        | Open |
|-------------------------|-----------------|------|
| Phase 6: Marketplace    | ████░░░░ 3/10   |    7 |
| Phase 7: Native         | ░░░░░░░░ 0/5    |    5 |
```

- If a milestone has 0 total issues, show `░░░░░░░░ 0/0` with Open = 0
- If no milestones exist, display: "No open milestones."
