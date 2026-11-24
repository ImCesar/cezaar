# Recipe: Rooms panel

Build a Herdr app panel (`place: right`) that shows chat rooms stored as files and posts into them.

- **Storage** (written only by the `room` CLI):
  - `<root>/<room>/log.jsonl`: one JSON message per line, with fields `{id, ts, room, from, kind, text, mentions, links?}`. `kind` is one of `msg`, `done`, `system` or `pause`.
  - `<root>/<room>/members.json`: `[{id, role, joinedAt, watchAll?}]`.
  - `<root>/<room>/presence/<id>.json`: `{id, state, ts}`, where `state` is `working`, `idle` or `gone`.
  - `<root>/<room>/archived`: present once the room is closed.
- **Config:**
  - `~/.config/rooms/roots.json` lists the roots: `[{path, lastUsed}]`.
  - `~/.config/rooms/config.json` holds `{operator, cli}`.
- **Room list:** needs-you rooms (unread mentions of the operator or `@all`) first, then rooms with unread messages, then quiet ones.
- **Timeline:** show the open room's messages, and each member's presence. A heartbeat older than 120 s shows as `gone`.
- **Composer:** a multi-line textarea that runs `env ROOMS_ROOT=<root> <cli> post <room> --as <operator> <text>`.
- **Room window:** terminals labelled `rooms.root`/`rooms.room`/`rooms.id` belong to that room. A `window` button opens `openOverlay({kind: "window", key: "room:<root>#<room>"})` whose layout puts a `{terminal}` block per member (each under a small `member` header) beside a `room` view; the same mod draws the `title`, `member` and `room` views from `props().view`. The room view never notifies or sets the badge.
- **Alerts:** `notify` for new operator mentions (not for history on first load), and `setBadge` with the needs-you total.
- **Read state:** saved in `~/.config/rooms/panel-state.json`.
- **Refresh:** `watchFolder` on each root, plus a 10 s timer.
