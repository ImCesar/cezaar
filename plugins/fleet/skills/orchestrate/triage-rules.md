# Triage Rules — auto-pass vs. escalate

*The editable policy knob. The orchestrator applies these after validation. Tighten or loosen as trust builds — this file is the line between "Cesar never sees it" and "Cesar decides."*

## AUTO-PASS (finish without asking) — ALL must hold
1. **Validation green** — validator ran real verification, and review-judge confirmed zero findings (or all findings refuted).
2. **No sensitive paths touched** — see list below.
3. **Bounded blast radius** — change is localized (one module/area); no public API contract, schema, or config-format changes.
4. **No judgment calls made** — the plan was followed as written; the worker didn't have to invent product/design decisions mid-flight.
5. **Reversible** — plain local commits only; nothing published, pushed, deleted, or sent anywhere external.

Typical auto-pass work: docs, typos, comments, formatting, test-only changes, small localized fixes with green tests, mechanical renames.

## ESCALATE (brief + wait) — ANY triggers
- Touches a **sensitive path**: auth/authz, payments/billing, data migration or deletion, secrets/keys, CI/CD pipelines, public API contracts, anything security-adjacent. **"Touches" includes shared infrastructure those flows pass through** (HTTP clients, middleware, serializers, base classes) — a change to the pipe counts as a change to what flows through it, even if validation came back green.
- **Confirmed or surviving-uncertain finding** from the validation chain.
- **Large or cross-cutting** change (many modules, shared interfaces, dependency major-bumps).
- Worker or orchestrator had to make a **product/design judgment** the plan didn't cover — including **behavioral policy defaults** (what to retry/cache/timeout/rate-limit, what errors to swallow). Standard-engineering-practice defaults still count: the user gets to veto policy, not just bugs.
- Anything **irreversible or outward-facing**: git push, PRs, publishing, external service calls, destructive ops.
- Validation **couldn't actually run** (no test runner, sandbox failure) — absence of evidence ≠ evidence of safety.

**Hard rule regardless of triage: never `git push` or open a PR without explicit approval** (per user-level CLAUDE.md). Auto-pass ends at a local commit.

## Escalation brief format
Plain language, four lines — technical detail only on request:
```
HELD FOR YOU: <what the change is, one sentence>
WHY HELD: <which trigger fired>
DECISION NEEDED: <the one question to answer>
EVIDENCE: <tests run + result; validator/judge verdicts; where the diff lives>
```
