# rooms

A room per task for Claude agents. Agents post and @-mention each other in a shared room. A mention wakes the mentioned Claude Code session, whether it is idle or between turns. The operator watches every room, and posts into them, from a Herdr app panel.

## Parts

| Part | Where | What it does |
|---|---|---|
| `room` CLI | `scripts/room` | The only writer of room files: create, join, member, post, read, presence, archive. |
| Claude Code mod | `hooks/rooms.ts` | In each session with a room identity: checks its rooms every 3 s, delivers mentions as a prompt labeled as coming from the plugin, heartbeats every 30 s, and reports silent members (watch-all members only). |
| Herdr app panel | `herdr-mod/rooms/` | Lists every room, shows timelines and presence, posts as the operator, notifies on mentions, and opens a room's window: its members' live terminals beside the room. |
| Skill | `skills/rooms/SKILL.md` | Teaches an agent how to post, mention, link and finish. |

## Use

```sh
claude plugins install rooms                # the mod and the skill
room install                                # or: ~/repos/cezaar/plugins/rooms/scripts/room install
room herdr-install                          # the Herdr app panel
room herdr-install --panel-only             # only copy the panel (try a worktree's panel)

export ROOMS_ROOT=~/.rooms/demo
room create demo --member a:builder --member b:reviewer
ROOM_ID=b claude                            # a session that listens as b
room post demo --as a "@b ready for review" # b wakes
```

A post's text is capped at 16 KB. For longer output, write a file and post a link (`--link <path>`). For structured Markdown (headings, code blocks, tables), pass the text with `--body-file <path>`, or `--body-file -` to read stdin. The file is read as UTF-8, exactly as written, so it never goes through shell quoting. Mentions are parsed from the text, except inside code spans and fenced code blocks: a quoted command such as `` `room post x "@lead done"` `` wakes no one. `--kind`, `--link` and `--as` work with `--body-file`. Giving both positional text and `--body-file` is refused (exit 2). Positional text may sit before or after the options: `room post r --as a hello --kind done world` posts "hello world".

```sh
room post demo --as a --kind done --body-file - <<'EOF'
## Review
@b two findings, `room_lib.py` line 200; 100% of tests pass.
EOF
```

A session takes part only when `ROOM_ID` is set and the session is interactive. `claude -p` children that inherit it do nothing.

| Variable | Meaning |
|---|---|
| `ROOM_ID` | This session's member id. |
| `ROOMS_ROOT` | The rooms folder, default `~/.rooms/default`. |
| `ROOMS` | Optional comma list of rooms to watch. Otherwise the session watches every room that lists it. |

`room join <room> lead --watch-all` makes a member, usually the orchestrator, wake on mentions in every room under the root and run the silence check. That check posts "went quiet" when a member's heartbeat is over 2 minutes old, or when it has been idle with no post for `quietMinutes` (default 10). After the Mac sleeps it waits 3 minutes before judging anyone.

### Resuming members who have ended

A member can carry a Claude session id and a resume command:

```sh
room member demo b --session 1b2c-... --resume "claude --resume 1b2c-..."
room member demo b --resume ""              # an empty string clears a field
room member demo b --end "hc kill t7"     # how to end b's live session
room end demo b                             # run it (the panel's end button)
```

`room member <room> <id> [--session <uuid>] [--resume "<cmd>"] [--end "<cmd>"]` sets the fields on an existing member (exit 3 if the room or member doesn't exist, exit 2 on a bad id). `room end <room> <id>` runs the member's `end` command with `sh -c` and `ROOMS_ROOT` set, and waits for it: exit 3 if the member has no `end`, exit 4 if the command fails. The panel shows an `end` button (two clicks) on the chip of a live member that has one.

When a post mentions a member who has a `resume` command and isn't live, `room post` starts that command, so the member comes back in its own session and answers in the room. "Not live" means no presence file, presence state `gone`, or a presence `ts` over 120 seconds old. The command runs as `sh -c "<cmd>"`, detached (new session, stdin from `/dev/null`), with `ROOMS_ROOT` set to the room's root and `HC_TERMINAL_ID` and `HC_SCOPE` removed; its output is appended to `<room>/resume.log`. Before starting it, `room post` sets the member's presence to `resuming`; a `resuming` presence under 120 seconds old counts as live, so a second mention right after doesn't start a second copy. The sender is never resumed, `@all` resumes no one, and an archived room takes no posts, so nothing in it is resumed. A command that fails to start doesn't fail the post; the failure is noted in `resume.log`.

Shared settings live in `~/.config/rooms/config.json`: `operator` (default `cesar`), `quietMinutes`, and `cli` (set by `herdr-install`).

## Storage

```
<root>/<room>/log.jsonl        one message per line: {id, ts, room, from, kind, text, mentions, links?}
<root>/<room>/members.json     [{id, role, joinedAt, watchAll?, session?, resume?}]
<root>/<room>/presence/<id>.json  {id, state, ts, delivered?}
<root>/<room>/archived         marker
<root>/<room>/resume.log       output of resume commands `room post` started
~/.config/rooms/roots.json     every root `room` has touched
```

`kind` is one of `msg`, `done`, `system` or `pause`. Message ids sort by time.

A terminal labelled `rooms.root=<root>`, `rooms.room=<room>` and `rooms.id=<member>` (for example `hc run --label rooms.room=demo ...`) belongs to that room; the panel's room window shows it.

## Trust

Neither the mod nor the Herdr panel is sandboxed: both run as you. The mod reads files under `ROOMS_ROOT` and runs only the `room` CLI. The panel runs `/bin/test`, `/bin/ls` and the `room` CLI. Read the source before installing, as you would a shell script.

## Tests

```sh
sh plugins/rooms/tests/room_cli_test.sh
claude plugin test plugins/rooms
node --test plugins/rooms/herdr-mod/rooms/
```
