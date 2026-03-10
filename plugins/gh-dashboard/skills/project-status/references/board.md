# Board Overview

Displays project board items grouped by status column.

## Commands

1. **Discover project boards:**

   ```bash
   gh project list --owner <owner> --format json
   ```

   Pick the first project (or let the user choose if multiple exist).

2. **Fetch board items:**

   ```bash
   gh project item-list <project-number> --owner <owner> --format json -L 100
   ```

   Each item has `title`, `number`, `status`, `type` (Issue, PullRequest, DraftIssue), and `labels`.

## Parsing

- Group items by their `status` field value (these are the column names)
- Count items per column
- For each column, collect `#<number> (<short-title>)` — truncate titles over 30 chars
- For the "Done" column, only show the 3 most recent items (by number, descending)

## Display Template

```
### Board
| Column      | Count | Items                             |
|-------------|-------|-----------------------------------|
| Backlog     |     5 | #12 (auth flow), #14 (upload)...  |
| In Progress |     2 | #22 (auth flow), #23 (upload)     |
| Review      |     1 | #20 (sort picker fix)             |
| Done        |    14 | (recent: #19, #17, #16)           |
```

- Column order: preserve the order returned by the project (this matches the board's configured column order)
- If a column has more than 5 items, show the first 5 and append `...+N more`
- If no project boards exist, display: "No project boards found for this repository."
