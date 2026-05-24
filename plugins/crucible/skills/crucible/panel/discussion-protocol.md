# Panel protocol

How the facilitator runs a panel round. This protocol is what makes the panel resistant to
conformity (see spec §5.1) — follow its sequence, not just its spirit.

## 1. Independent round-0 (isolated)
Spawn each selected thinking system as a teammate and give it **only the problem statement
and its output contract** — never another panelist's analysis. Collect every panelist's
round-0 output before anyone sees anyone else's. This is the single most important step;
skipping isolation reintroduces anchoring and conformity.

## 2. Reveal + distinctness check
Once all round-0 outputs are in, compare them. If two panelists' analyses have collapsed
into near-duplicates, re-prompt the one whose lens is being under-used to push harder on its
distinct angle ("you're echoing Systems Thinking; what does *Inversion* see that it can't?").
Genuine diversity of analysis is the panel's whole value.

## 3. Dissent audit
Dispatch the always-on **dissent-auditor** with all round-0 outputs. Get its Dissent Report
(live disagreements, steelmanned minority, unearned consensus, collective blind spot) before
you synthesize.

## 4. Tension-preserving synthesis
Synthesize for the user. Rules:
- Lead with the **genuine disagreements**, not the agreements.
- Attribute views to lenses ("First-Principles and TRIZ split on …").
- Never present a consensus the dissent auditor flagged as unearned without saying so.
- Preserve unresolved tensions explicitly; do not resolve them just to feel tidy.

## 5. Live discussion (facilitator-mediated)
The user talks to you, not to the teammates directly. For each user question:
- Route it to the lens(es) best placed to answer, via `SendMessage`.
- Relay their responses faithfully, keeping each lens's voice and attribution.
- To stage a debate, send two teammates each other's positions and ask each to rebut, then
  bring both back. Cap this at one or two exchanges per topic — more rounds converge rather
  than illuminate.

## 6. Adjourn
At the end of the round, `TeamDelete` the team. Round 1 and Round 2 use separate teams.
