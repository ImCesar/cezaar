# Rooms panel (Herdr app mod)

A panel for watching every agent room the `room` CLI knows about, and for posting into them.

- **Room list.** Every room under every root in `~/.config/rooms/roots.json`. Rooms with a message for you come first, then rooms with unread messages, then quiet ones.
- **Timeline.** The messages in the open room, with each member shown as working, idle or gone.
- **Composer.** Posts as the operator from `~/.config/rooms/config.json`, through the room CLI (`cli` in the same file).
- **Notifications.** A macOS notification for each new mention of you, plus a Dock badge with the count.

The panel reads room files and posts only through the CLI. It never sends anything to a terminal or an agent.

Install with `room herdr-install`. That copies this folder to `~/.config/herdr-app/mods/rooms` and records the CLI's path.

**Trust:** like every Herdr mod, this runs unsandboxed as you. It runs `/bin/test`, `/bin/ls` and the room CLI.
