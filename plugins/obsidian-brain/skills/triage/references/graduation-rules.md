# Graduation Rules

Detailed routing logic for moving items out of the inbox. The triage skill references this file when the user chooses to graduate an item.

## Graduation Paths by Type

### Todo → `projects/`

Todos graduate to the `projects/` directory. Ask the user where it should land:

- **Standalone** — move to `projects/` root as a standalone file.
- **Inside an epic** — move into an existing epic folder under `projects/<epic-name>/`. List available epic folders and let the user pick, or create a new one.

Frontmatter mutations:
- `status: captured` → `status: backlog`
- `parent: ""` → `parent: <epic-name>` (if assigned to an epic)

### Idea → `projects/` as a project

Ideas graduate by becoming projects. Change the type during graduation:

- `type: idea` → `type: project`
- `status: captured` → `status: backlog`

Ask the user: **standalone project or epic?**

- **Standalone** — move to `projects/` root. Update type and status.
- **Epic** — create a folder and project summary inside it (see Epic Creation Flow below). Optionally spawn child todos (see Todo Spawning below).

### Question → `knowledge/`

Questions graduate when they have an answer. Before graduating:

1. Check if the `## Answer` section is filled in.
2. If empty, ask the user to provide the answer now or skip.
3. If filled, move to `knowledge/`.

Frontmatter mutations:
- `status: captured` → `status: answered`

The file keeps `type: question` — no type change needed.

### Research → `knowledge/` or `projects/`

Research can go two directions depending on outcome:

- **Findings documented** → `knowledge/`. The research becomes a knowledge note. Set `status: captured` → `status: documented`.
- **Actionable** → `projects/`. The research spawns a project. Follow the Idea graduation path (change `type: research` → `type: project`, set `status: backlog`). Ask about standalone vs epic.

Ask the user which direction fits.

## Epic Creation Flow

When graduating an idea (or research) to an epic:

1. **Name the epic** — derive from the item's title, or let the user rename.
2. **Create the folder** — `projects/<epic-name>/`.
3. **Create the summary note** — `projects/<epic-name>/<epic-name>.md` with the original content, updated frontmatter:
   ```yaml
   ---
   type: project
   status: backlog
   created: "<original created date>"
   tags: [<original tags>]
   parent: ""
   ---
   ```
4. **Remove the original** — the inbox file is replaced by the epic summary. Don't leave a copy behind.

## Todo Spawning

When graduating an idea to an epic, offer to break it into child todos:

1. Ask: "Want to break this into smaller tasks?"
2. If yes, ask the user to list the tasks (or suggest a breakdown based on the idea's content).
3. For each child todo, create a file in `projects/<epic-name>/`:
   - Filename: `YYYY-MM-DD-<slug>.md`
   - Frontmatter:
     ```yaml
     ---
     type: todo
     status: backlog
     created: "<today's date>"
     tags: [<inherited from epic>]
     parent: "<epic-name>"
     ---
     ```
   - Body: minimal description of the task with an acceptance criteria section.

Keep child todos lightweight — they can be fleshed out later.

## Archive Rules

When the user chooses to archive an item:

1. Move the file to `archive/` (flat directory, no subfolders).
2. Update frontmatter:
   - `status: <any>` → `status: archived`
   - Preserve the original `type` — don't change it.
3. Keep the filename as-is. If a file with the same name exists in archive, append a numeric suffix.

## Frontmatter Mutation Summary

| Action | Field | Before | After |
|--------|-------|--------|-------|
| Graduate todo | status | captured | backlog |
| Graduate todo to epic | parent | "" | `<epic-name>` |
| Graduate idea | type | idea | project |
| Graduate idea | status | captured | backlog |
| Graduate question | status | captured | answered |
| Graduate research (knowledge) | status | captured | documented |
| Graduate research (project) | type | research | project |
| Graduate research (project) | status | captured | backlog |
| Archive any | status | * | archived |
