# Open Pull Requests

Displays open PRs with status checks and review state.

## Commands

```bash
gh pr list --json number,title,author,statusCheckRollup,isDraft,reviewDecision,headRefName,createdAt
```

## Parsing

- `author`: use `author.login`
- `statusCheckRollup`: summarize as "checks passing", "checks failing", "checks pending", or "no checks" based on the rollup conclusion states
- `reviewDecision`: show as "approved", "changes requested", "review required", or omit if empty
- `isDraft`: prefix with `[DRAFT]` if true
- Sort by creation date (newest first)

## Display Template

```
### Open Pull Requests
- #28 `fix: sort picker broken on web` — @ImCesar — checks passing
- #27 `fix: app test suite` — @ImCesar — review approved
- #30 [DRAFT] `feat: marketplace listing` — @ImCesar — checks pending, review required
```

- If no open PRs, display: "No open pull requests."
