# Rooms panel (Herdr app mod)

A panel for watching every agent room the `room` CLI knows about, and for posting into them.

- **Room list.** Every room under every root in `~/.config/rooms/roots.json`. Rooms with a message for you come first, then rooms with unread messages, then quiet ones.
- **Timeline.** The messages in the open room, with each member shown as working, idle or gone.
- **Composer.** Posts as the operator from `~/.config/rooms/config.json`, through the room CLI (`cli` in the same file).
- **One run only.** Opened with props `{root}` (app-fleet's per-run `rooms` tab: `herdr-app do tab.new --mod rooms --props '{"root": "<root>"}'`), the panel shows only that root's rooms.
- **Room window.** When live terminals carry a room's labels (`rooms.root`, `rooms.room`, `rooms.id`; app-fleet sets them on its members), the room's row and its header get a `window` button. It opens a floating window with each member's live terminal on the left and the room's timeline and composer on the right. You can type into either. The window remembers where you left it, and closes itself when a member's terminal ends; the button reopens it. Reading a room in its window marks it read in the panel (shared through Herdr's `rooms.read` shared state).
- **Notifications.** A macOS notification for each new mention of you, plus a Dock badge with the count.

The panel reads room files and posts only through the CLI. It never sends anything to a terminal or an agent; in the room window, what you type into a terminal goes there directly, as in any Herdr pane.

Install with `room herdr-install`. That copies this folder to `~/.config/herdr-app/mods/rooms` and records the CLI's path.

**Trust:** like every Herdr mod, this runs unsandboxed as you. It runs `/bin/test`, `/bin/ls` and the room CLI.
