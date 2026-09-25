<!--
Ported from cezaar/plugins/fleet/skills/orchestrate/triage-rules.md.
Changes from the source, and nothing else:
  1. "validator"/"review-judge" (fleet's two agents) are now the `reviewer`
     and `judge` personas, run as two separate fresh-context sessions
     (cezaar#47 split the judge out of the reviewer).
  2. "Cesar" -> "the human" in the intro; this repo is meant to be portable.
  3. Dropped "(per user-level CLAUDE.md)" from the hard no-push rule — a
     citation that dangles once this is installed somewhere else. The rule
     stands on its own text.
  4. AUTO-PASS rule 1 and the finding ESCALATE trigger now read against
     review-bar.md's verdict and blocking findings (cezaar#52, approved by
     the operator 2026-09-24).
  5. AUTO-PASS rule 1 names the `reviewer` and `judge` personas instead of
     one reviewer's "validate mode" and "judge mode" (cezaar#47). A rename;
     the rule is unchanged.
  6. AUTO-PASS rule 1 requires the review to be of the change being triaged,
     so an integrator's conflict resolution never auto-passes on the parts'
     earlier reviews (the operator's decision after the epic-40 run, cezaar#40,
     2026-09-25).
Policy content is otherwise byte-identical.
-->

# Triage Rules — auto-pass vs. escalate

*The editable policy knob. The orchestrator applies these after validation. Tighten or loosen as trust builds — this file is the line between "the human never sees it" and "the human decides."*

## AUTO-PASS (finish without asking) — ALL must hold
1. **Validation green** — a `reviewer` ran real verification on the change being triaged, and either its verdict is APPROVE, or every blocking finding was fixed, or downgraded or refuted by the `judge` persona in a separate, fresh-context session. When an `integrator` resolved any conflict, the change being triaged is the integrated branch: the parts' earlier reviews don't cover the resolution.
2. **No sensitive paths touched** — see list below.
3. **Bounded blast radius** — change is localized (one module/area); no public API contract, schema, or config-format changes.
4. **No judgment calls made** — the plan was followed as written; the worker didn't have to invent product/design decisions mid-flight.
5. **Reversible** — plain local commits only; nothing published, pushed, deleted, or sent anywhere external.

Typical auto-pass work: docs, typos, comments, formatting, test-only changes, small localized fixes with green tests, mechanical renames.

## ESCALATE (brief + wait) — ANY triggers
- Touches a **sensitive path**: auth/authz, payments/billing, data migration or deletion, secrets/keys, CI/CD pipelines, public API contracts, anything security-adjacent. **"Touches" includes shared infrastructure those flows pass through** (HTTP clients, middleware, serializers, base classes) — a change to the pipe counts as a change to what flows through it, even if validation came back green.
- **An upheld blocking finding that wasn't fixed** from the validation chain. Notes never escalate by themselves.
- **Large or cross-cutting** change (many modules, shared interfaces, dependency major-bumps).
- Worker or orchestrator had to make a **product/design judgment** the plan didn't cover — including **behavioral policy defaults** (what to retry/cache/timeout/rate-limit, what errors to swallow). Standard-engineering-practice defaults still count: the user gets to veto policy, not just bugs.
- Anything **irreversible or outward-facing**: git push, PRs, publishing, external service calls, destructive ops.
- Validation **couldn't actually run** (no test runner, sandbox failure) — absence of evidence ≠ evidence of safety.

**Hard rule regardless of triage: never `git push` or open a PR without explicit approval.** Auto-pass ends at a local commit.

## Escalation brief format
Plain language, four lines — technical detail only on request:
```
HELD FOR YOU: <what the change is, one sentence>
WHY HELD: <which trigger fired>
DECISION NEEDED: <the one question to answer>
EVIDENCE: <tests run + result; validate/judge verdicts; where the diff lives>
```
