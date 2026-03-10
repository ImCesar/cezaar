# Vault Structure Reference

This document is the single source of truth for the obsidian-brain vault layout, frontmatter schema, and Dataview queries. The init-vault skill reads this during scaffolding; other skills reference it when they need to know where things live or what metadata is valid.

## Directory Tree

```
MyVault/
├── .obsidian/                 # Obsidian config (already exists or created by Obsidian)
├── inbox/
│   ├── ideas/                 # Raw, unprocessed ideas — captured fast, refined later
│   ├── todos/                 # Actionable items that haven't been triaged yet
│   ├── questions/             # Things the user wants to explore or answer
│   └── research/              # Research threads — deeper dives into a topic
├── projects/                  # Active epics and standalone work
│   └── <epic-name>/           # Sub-folder per epic; standalone todos live at root
├── knowledge/                 # Graduated questions and research that proved useful
├── journal/
│   ├── daily/                 # One note per day, append-only stream of thought
│   └── weekly/                # Weekly rollup — patterns, energy, wins, blockers
├── reviews/
│   ├── summaries/             # Lightweight review summaries (weekly/monthly)
│   └── formal/                # Performance review artifacts with evidence
├── templates/                 # Obsidian-native templates folder (copied from references/templates/)
└── archive/                   # Completed or parked items moved here to reduce noise
```

## Folder Purposes

| Folder | Purpose |
|--------|---------|
| `inbox/ideas/` | Landing zone for ideas. Capture first, evaluate later — the goal is zero friction. |
| `inbox/todos/` | New actionable items before triage. Triage moves them to `projects/` or `archive/`. |
| `inbox/questions/` | Open questions worth tracking. Once answered, graduate to `knowledge/`. |
| `inbox/research/` | Active research threads. Findings that prove useful graduate to `knowledge/`. |
| `projects/` | Active work. Epics get their own sub-folder; standalone todos sit at the root level. |
| `knowledge/` | Durable reference material — graduated questions, research findings, how-tos. |
| `journal/daily/` | Daily stream-of-consciousness entries. One file per day, append throughout the day. |
| `journal/weekly/` | Weekly reflections synthesized from daily entries and project progress. |
| `reviews/summaries/` | Lightweight review snapshots — what happened, what mattered, what's next. |
| `reviews/formal/` | Structured performance review docs with goals, outcomes, and evidence links. |
| `templates/` | Obsidian template files. These are copied from the skill's `references/templates/` during init. |
| `archive/` | Done or abandoned items. Keeps the active folders clean without losing history. |

## Frontmatter Schema

Every note created by obsidian-brain skills uses this frontmatter structure:

```yaml
---
type: <string>        # Required. The kind of note.
status: <string>      # Required. Where the note is in its lifecycle.
created: <YYYY-MM-DD> # Required. Date the note was created.
tags: <array>         # Required. Free-form tags for filtering.
parent: <wikilink>    # Optional. Link to the parent epic or project.
---
```

### Valid `type` Values

| Type | Used For |
|------|----------|
| `todo` | Actionable tasks with acceptance criteria |
| `idea` | Raw ideas, shower thoughts, sparks |
| `question` | Something to explore or answer |
| `research` | Deeper investigation into a topic |
| `project` | Epic or project-level tracking note |
| `journal` | Daily or weekly journal entries |
| `review` | Review summaries and formal performance reviews |

### Valid `status` Values

| Status | Meaning |
|--------|---------|
| `captured` | Just landed — hasn't been looked at yet |
| `backlog` | Triaged and accepted, but not started |
| `in-progress` | Actively being worked on |
| `done` | Completed |
| `archived` | Moved to archive — no longer active |

### `parent` Field

The `parent` field uses Obsidian wikilink syntax to connect a note to its epic or project:

```yaml
parent: "[[projects/website-redesign]]"
```

Leave empty (`""`) for standalone items with no parent.

## Example Dataview Queries

These queries work with the [Dataview plugin](https://github.com/blacksmithgu/obsidian-dataview) and the frontmatter schema above.

### Kanban Board View — Todos by Status

```dataview
TABLE WITHOUT ID
  file.link AS "Task",
  status AS "Status",
  parent AS "Project"
FROM "inbox/todos" OR "projects"
WHERE type = "todo" AND status != "archived"
SORT choice(status, "in-progress", 1, "backlog", 2, "captured", 3, "done", 4) ASC
```

### Inbox Count — How Many Items Need Triage

```dataview
LIST
FROM "inbox"
WHERE status = "captured"
GROUP BY type
```

### Active Projects — What's In Flight

```dataview
TABLE WITHOUT ID
  file.link AS "Project",
  length(filter(file.inlinks, (l) => meta(l).frontmatter.status = "in-progress")) AS "Active Tasks",
  length(filter(file.inlinks, (l) => meta(l).frontmatter.status = "done")) AS "Done"
FROM "projects"
WHERE type = "project" AND status = "in-progress"
```

### Recent Journal Entries — Last 7 Days

```dataview
TABLE WITHOUT ID
  file.link AS "Entry",
  created AS "Date",
  tags AS "Tags"
FROM "journal"
WHERE created >= date(today) - dur(7 days)
SORT created DESC
```
