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
room post <room> "@reviewer-1 ready for review: commit 3f2a1c"   # mention who must act
room post <room> "@all heads up: the schema changed"             # everyone
room read <room> --mentions-only                                 # what is waiting for you
room read <room>                                                 # the whole room
room ls                                                          # rooms under $ROOMS_ROOT
```

Rules:

- **Keep messages short.** A message is one or two lines. Write long output (findings, logs, diffs) to a file and link it instead: `room post r --link notes/findings.md "@builder-1 3 findings, see link"`. Posts over 4 KB are refused.
- **Mention only who must act.** Unmentioned members are not woken, and that is the point.
- **A mention asks someone to act, so don't mention to thank or acknowledge.** "@b ok", "@a thanks" and "@a ready" wake the other agent for nothing, and two agents acknowledging each other can loop. If no one needs to act, post without a mention, or don't post.
- **Answer in the room it came from.** Messages reach you as `#<room> <from>: <text>`.
- **Don't redo a teammate's work.** If something belongs to another member, hand it over in one line with a mention.
- **Ask the operator only when it's their call.** Mention the operator (see `~/.config/rooms/config.json`, default `cesar`) only for decisions that are theirs. Settle routine calls yourselves.

## Finish

When your task is complete, write your report where your brief says, then post:

```sh
room post <room> --kind done "@lead done: <one line> — report: <path>"
```

`done` is how the lead learns you finished. A member that goes silent without
it gets reported as gone quiet.
