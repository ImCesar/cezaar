# Whiteboard Companion (Tier 1)

The whiteboard companion lets the user sketch diagrams and send them to the coach for analysis.
This is **one-way**: user → coach. The coach does not annotate or draw back (Tier 2, out of scope).

---

## When to launch

When the user says anything like "I need a whiteboard", "let me draw this", "can I sketch it out",
or similar — launch the server immediately, then open the URL.

---

## Launch sequence

```bash
# 1. Start the server in the background (from the project root)
cd plugins/staff-coach/scripts/whiteboard && node server.js &

# 2. Open the canvas in the default browser
open http://localhost:4137
```

The server prints:
```
Whiteboard at http://localhost:4137  (canvas: /Users/<you>/.staff-coach/canvas/)
```

Tell the user:
> "Your whiteboard is open at http://localhost:4137 — draw whatever you like, then click **Send to coach**."

---

## Receiving the board

The server writes two files per submission into `~/.staff-coach/canvas/`:

| File | Purpose |
|------|---------|
| `board-N.png` | Full-colour PNG export — use for visual layout, spatial reasoning |
| `board-N.excalidraw.json` | Exact scene graph (elements, labels, arrows, types) — use for structural analysis |

Watch for new files:

```bash
# Poll (simple)
ls -lt ~/.staff-coach/canvas/ | head -5

# Or use fswatch (if installed)
fswatch -o ~/.staff-coach/canvas/ | xargs -n1 -I{} echo "New board saved"
```

When a new `board-N.excalidraw.json` appears, read it:

```js
// elements array — each item has: type, id, x, y, width, height, label, boundElements, …
const scene = JSON.parse(fs.readFileSync('~/.staff-coach/canvas/board-1.excalidraw.json', 'utf8'));
scene.elements.forEach(el => console.log(el.type, el.label ?? ''));
```

Read the PNG for the overall layout impression; read the JSON for precise structural data (node types,
arrow directions, text labels).

---

## Teardown

When the user is done, ask them to press **Ctrl-C** in the terminal where the server is running,
or kill it by PID:

```bash
kill $(lsof -ti tcp:4137)
```

---

## Port & config

| Setting | Default |
|---------|---------|
| Port | `4137` |
| Canvas dir | `$STAFF_COACH_HOME/canvas/` or `~/.staff-coach/canvas/` |

To use a different port: `node server.js 5000`

---

## Scope

- **Tier 1 (implemented):** user draws → clicks Send → coach reads the files.
- **Tier 2 (out of scope):** coach annotates the canvas and sends it back to the user.
