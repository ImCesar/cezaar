# Reconciliation Review

After the examiner returns its verdict, that verdict passes through a collaborative review before
anything is written to the permanent store. This step exists because neither the examiner nor the
coach alone can be trusted as the final arbiter: the examiner graded cold and may have misread
context; the coach participated in the dialogue and carries a co-author bias. The user, accountable
for their own learning, is the circuit-breaker.

---

## The immutable-verdict rule

The raw examiner output is never edited in place. Dispositions are layered on top of it as a
separate structure; the underlying verdict stays exactly as the examiner wrote it.

The reason this matters: if the reconciliation step could rewrite findings, the store would end up
holding the *negotiated* version of the user's skills — the result of a conversation about the
assessment, not the assessment itself. That is the version that flatters rather than informs. The
unmodified examiner output is the only unbiased datapoint available; once it is gone it cannot be
reconstructed. Keeping it immutable also means a future session can re-examine whether a disputed
finding was real — the evidence is still there.

---

## Three dispositions

Each finding from the examiner receives exactly one disposition:

### Accepted

The finding stands as a real gap. No further action required at reconciliation time; the score
contributes to the dimension's history in `progress.json` normally.

### Factually corrected

The coach or user shows that the examiner made a verifiable error — it misread the transcript,
missed a ledger entry that already accounted for the issue, or attributed a gap to the wrong
dimension. The finding is overturned cleanly and is not counted as a gap.

This is the legitimate correction path, not a general-purpose appeal. The threshold is objective:
either the examiner had the information and misread it, or it didn't. "I disagree with the severity"
is not a factual correction; it is a dispute (see below).

### Disputed on the merits

The user disagrees that the finding represents a real weakness in their design — not because the
examiner made a factual error, but because they believe the judgment call was wrong. This is allowed.
A one-line reason is required: "I already addressed this via the circuit-breaker pattern in the
service mesh layer."

That one line is the full extent of the negotiation. No extended rebuttal. The reason creates a
visible paper trail: if the user disputes the same dimension repeatedly across sessions, that pattern
itself becomes a signal — either the examiner is consistently miscalibrated on this dimension, or the
user has a blind spot they are consistently arguing away. Both are useful to know.

---

## Coach informs; user adjudicates

During reconciliation, the coach's role is to provide context: "The examiner flagged this because
your transcript didn't mention back-pressure handling — is that accurate?" or "This one does look
like it was covered by the ledger entry you made in turn 12."

The coach does not make the call. It does not edit a score directly. The user is the final arbiter
for every disposition, which is appropriate: the user is the one whose learning depends on the
assessment being accurate. An incentive to argue away a real weakness only harms the user's own
progress.

---

## Disposition values (the machine contract)

When you assemble the session dict, each entry in `dispositions` is
`{ "finding_id": "<id from the verdict>", "disposition": "<value>", "reason": "<one line, only if disputed>" }`.
The `disposition` value must be exactly one of these lowercase tokens — `write_session.js` matches them
literally, so a prose variant like `"disputed on the merits"` would silently fail to register:

- `accepted`
- `factually-corrected`
- `disputed`

## How dispositions affect the store

Once dispositions are assigned, `write_session.js` applies them when updating `progress.json`:

- **Accepted** findings contribute to the dimension's score history as gaps.
- **Factually corrected** findings are removed from the gap count — the dimension is treated as
  though that finding was not raised.
- **Disputed** findings increment `disputed_count` for the dimension. The score impact is held in
  suspension. The dimension will be re-probed in a future session; if the same gap surfaces again
  without a successful dispute, it will accumulate normally. This is the safety net for the scenario
  where a user has talked themselves out of a real weakness — the periodic re-probe catches it
  without forcing an immediate confrontation.

The session record in `sessions/<date>-<slug>.md` stores the full examiner verdict, all
dispositions, and their reasons, so the complete picture is always reconstructable from the store.
