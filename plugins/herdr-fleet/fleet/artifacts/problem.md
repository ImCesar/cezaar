---
name: problem
description: The raw ask — an issue, text, or file, and who raised it. Read by whoever turns it into a problem-statement.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Source
The issue URL, text, or file this problem came from.

## Text
The problem as given, unedited. Anything the operator added in conversation
goes under its own heading below, not mixed into this.

## Raised by
Who raised it — the operator, a linked issue's author, or an earlier
artifact's open question.

## Added in conversation
What the operator said about the problem beyond the source, in their words.
None is a complete answer.
