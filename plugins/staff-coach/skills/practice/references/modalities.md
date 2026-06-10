# Input Modalities

The coach session can begin from three input channels. Once the problem is established, coaching
downstream is identical regardless of which channel was used — the same probing protocol, the same
examiner handoff, the same rubric scoring.

---

## Document-first

The user supplies a written artifact: a design doc, an RFC, a tech-spec, or an architecture
narrative. The coach reads it to establish the problem space, then probes the dimensions that the
document left underspecified or undefended.

This is the natural channel for "I have a real thing I want to think through" — the document is the
problem statement, and the coaching session is the scrutiny it would face in a real design review.

---

## Whiteboard-style dialogue

The user starts from nothing and builds the design through conversation. The coach opens with a
problem statement (generated or provided) and the user constructs their answer incrementally through
dialogue.

This channel is most useful for unfamiliar problem types or for practicing the structured reasoning
that real architecture discussions require — the ability to build coherently under questioning, not
just to critique an existing thing.

---

## Diagram

The user supplies a boxes-and-arrows architecture diagram as either an image file or an
`.excalidraw` JSON export. Both are acceptable. When a JSON export is present, the coach reads
structural information directly from it — exact nodes, labels, and arrows — which is more reliable
than interpreting spatial layout from an image alone. When only an image is provided, the coach
reads from the visual layout.

Diagram input is supported in v1. (The whiteboard companion that lets the user draw live during the
session is a separate capability; see `whiteboard.md` when it is available.)

The coach uses the diagram as the problem statement and probes the design decisions it represents —
the same way it would probe a written doc or a spoken design.

---

## How modality affects coaching

It doesn't, beyond the first few turns. The coach's job in the opening turns is to establish a
shared understanding of the problem and the user's current position. Once that is established — the
problem is clear, the user has staked an initial answer — the probing protocol takes over and runs
identically from that point forward.

A document or diagram gives the coach more to work from at the start; whiteboard dialogue requires
the coach to draw the problem out more deliberately before probing begins. The rubric, escalation
ladder, breadcrumb recording, trade-off ledger, and examiner handoff are the same across all three.
