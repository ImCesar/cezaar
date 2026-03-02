---
name: project-status
description: >
  Fetches and displays GitHub project status — board overview, milestone progress,
  open PRs, and recent activity. Use this skill whenever the user asks about project
  status, wants to check the board, asks about open PRs or pull requests, checks
  milestone progress, asks "what should I work on", "what's left to do", "where are
  we", "show me active PRs", or any variation of checking in on project health.
  Handles both full dashboard views and focused queries (just PRs, just milestones, etc.).
---

# Project Status Dashboard

A GitHub project status dashboard that auto-detects the repo and fetches live data via `gh` CLI.

## Step 1: Discover the Repository

Parse the repo owner and name from git:

    git remote get-url origin

Extract `<owner>` and `<repo>` from the URL (handles both HTTPS and SSH formats).

If not in a git repo, ask the user for the owner/repo.

## Step 2: Route the Request

Determine what the user is asking for and load only the relevant reference files. This keeps the context lean — partial queries skip sections they don't need.

| User intent | Reference files to read | What's Next? |
|---|---|---|
| Full status — "project status", "where are we", "what's going on", "status update" | Read `references/full-dashboard.md`, then all four section references in order | Yes |
| Board — "board", "issues", "what's in progress", "backlog" | `references/board.md` | No |
| Milestones — "milestones", "progress", "how far along", "roadmap" | `references/milestones.md` | No |
| PRs — "open PRs", "pull requests", "active PRs", "my PRs" | `references/prs.md` | No |
| Activity — "recent activity", "what happened", "what was merged" | `references/activity.md` | No |
| Work suggestion — "what should I work on", "what's next", "pick something" | `references/board.md` → What's Next only | Yes |

When in doubt, default to full dashboard — it's better to show too much than too little.

## Step 3: Fetch and Display

For each reference file loaded:

1. Run the `gh` commands listed in the reference
2. Parse the JSON output as described
3. Format using the display template

Run commands in parallel where possible (e.g., board and milestones don't depend on each other).

## Step 4: What's Next? (when applicable)

If the routing table says "Yes" for What's Next, follow the prioritization and template in `references/full-dashboard.md` to suggest work items and prompt the user.

## Error Handling

- **`gh` not authenticated:** Tell the user to run `gh auth login`
- **No project boards:** Skip the board section, note "No project boards found"
- **Rate limited:** Tell the user and show whatever data was fetched before the limit
- **Not a git repo:** Ask the user for owner/repo instead of failing
