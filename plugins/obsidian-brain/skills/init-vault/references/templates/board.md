---
type: board
---

# Board

## In Progress

```dataview
TABLE file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "in-progress"
SORT created DESC
```

## Blocked

```dataview
TABLE file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "blocked"
SORT created DESC
```

## Backlog

```dataview
TABLE file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "backlog"
SORT created DESC
```

## Captured

```dataview
TABLE file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "captured"
SORT created DESC
```

## Done (Last 7 Days)

```dataview
TABLE file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "done" AND created >= date(today) - dur(7 days)
SORT created DESC
```
