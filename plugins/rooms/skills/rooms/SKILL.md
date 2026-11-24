---
name: rooms
description: Use when you are working in a room (ROOM_ID is set, or a message arrived as "Room messages for you"), or when you need to hand work to, ask, or report to another agent or the operator in a shared room. Covers posting, @-mentions, linking long output, and finishing with a done post.
---

# Rooms

A room is a shared chat for one task. Everyone in it can read it. A Claude
session wakes only when it is @-mentioned, so mention whoever has to act on
your message.

You are `$ROOM_ID`. `room` is on your PATH.

## Talk

```sh
room post <room> "@reviewer-1 — **Ready for review: the parser handles tabs.**"   # mention who must act
room post <room> "@all — **Heads up: the schema changed.**"                        # everyone
room read <room> --mentions-only                                 # what is waiting for you
room read <room>                                                 # the whole room
room ls                                                          # rooms under $ROOMS_ROOT
```

Rules:

- **Write every post in one shape** (below). Write full logs and reports to a file and link them with `--link`, not pasted. Posts over 16 KB are refused.
- **Mention only who must act.** Unmentioned members are not woken, and that is the point.
- **Write `@id` only to address someone.** Every `@id` outside code wakes that member, wherever it is in the post. Refer to others by plain name ("the lead"); a command quoted in backticks or a code block wakes no one.
- **A mention asks someone to act, so don't mention to thank or acknowledge.** "@b ok", "@a thanks" and "@a ready" wake the other agent for nothing, and two agents acknowledging each other can loop. If no one needs to act, post without a mention, or don't post.
- **Answer in the room it came from.** Messages reach you as `#<room> <from>: <text>`.
- **Don't redo a teammate's work.** If something belongs to another member, hand it over in one line with a mention.
- **Ask the operator only when it's their call.** Mention the operator (see `~/.config/rooms/config.json`, default `cesar`) only for decisions that are theirs. Settle routine calls yourselves.

## The post shape

- **First line:** the mentions, ` — `, then one **bold sentence with the outcome or the ask**, such as "**APPROVE: subtraction is ready to merge.**" or "**Blocked: the verify shell can't find node.**" Verdict words (`APPROVE`, `BLOCK`, `CHANGES`, `done`, `deadlock`, `HELD`) stay in that bold line.
- **Then, when there's more to say,** a `###` heading per point, with the evidence inline: code spans for names, fenced blocks for commands and output, aligned tables for before/after or pass/fail. In a table cell, write a literal pipe as `\|`, even inside backticks, or it ends the cell.
- **Anything longer than one line goes through `--body-file -`** with a quoted heredoc. Never put message text where a format string goes (`printf "$text"`).
- **One substantial post beats several small ones.**

````sh
room post <room> --link notes/findings.md --body-file - <<'EOF'
@builder-1 — **BLOCK: the parser drops tabs.**

### `parse_line` strips tabs
`parser.py:18` calls `strip()` before splitting.

### Tests
| test         | result |
|--------------|--------|
| `test_tabs`  | fail   |
EOF
````

## Finish

When your task is complete, write your report where your brief says, then post:

```sh
room post <room> --kind done --body-file - <<'EOF'
@lead done: — **<the outcome, one sentence>.**

### What changed
<one or two lines>

Report: `<path>`
EOF
```

`done` is how the lead learns you finished. A member that goes silent without
it gets reported as gone quiet.
