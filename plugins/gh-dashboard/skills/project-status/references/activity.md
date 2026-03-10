# Recent Activity

Displays recently closed issues and merged PRs from the last 7 days.

## Commands

```bash
gh issue list --state closed --json number,title,closedAt -L 10
```

```bash
gh pr list --state merged --json number,title,mergedAt -L 10
```

## Parsing

- Combine both lists into a single timeline
- Filter to items from the last 7 days only
- Sort by date descending (most recent first)
- Compute relative timestamps: "today", "1d ago", "2d ago", etc.
- Tag each item: "Merged" for PRs, "Closed" for issues
- Limit to 10 items total

## Display Template

```
### Recent Activity (last 7 days)
- Merged #28 `fix: sort picker broken on web` (2d ago)
- Closed #25 `chore: seed data` (3d ago)
- Merged #27 `fix: app test suite` (4d ago)
```

- If no activity in the last 7 days, display: "No recent activity."
