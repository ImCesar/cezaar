# With skill: single-mechanic, 2026-11-01

Reply (verbatim, relayed by the controller; the subagent did not hand it back to me directly):
> I made a one-page design at /Users/cesar/.agents/skills/one-page-design/tests/results/output/2026-11-01-single-mechanic-with-skill.html. It draws two nine-choice runs, patient and impatient, as eight-slot roster strips on a time ruler, because the claim is about tempo over a run and the picture should show the lost choices directly. Its title states the claim, with one correction: undoing the stray costs one choice in nine (about 11%), but the stray pick used one too, so the total is two in nine (about 22%).

Output: output/2026-11-01-single-mechanic-with-skill.html, 81 lines. Preview: output/2026-11-01-single-mechanic-with-skill.png.

Fit-check (verbatim, run by me; exit code 0):
```
surface: 17.0 x 11.0 in
preview: tests/results/output/2026-11-01-single-mechanic-with-skill.png
```
Headless Chrome was found; the preview was produced. Findings: 0.

Shape chosen: a two-row comparison. A patient run and an impatient run are drawn one above the other, each as nine small eight-slot rosters left to right, a dashed leader marking where the first merge slips, a choice-by-choice time ruler with the lost choices as bars, and three numbered notes underneath tied by leader lines.

Centre of the PNG: two rows of nine roster snapshots, the patient run reaching three merges while the impatient run shows a stray X taken at choice 3, removed at choice 4, and ends one merge short.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | Yes | `<h1 class="title t1">An impatient pick costs one choice in nine to undo, and the pick itself cost another</h1>` |
| Date on the page | Yes | `<footer class="date">Proposal · 2026-11-01</footer>` |
| One depiction holding the middle | Yes | Inline `<svg viewBox="0 0 1700 1100">` with the two run strips and the ruler across the centre. |
| Callouts tied to the depiction (leader lines or numbers) | Yes | Three `<path class="leader" ...>` lines with dots run from the stray pick, the undo and the late merge to notes numbered 3, 4 and 5 below; choice numbers 1 to 9 sit on each roster. |
| Legend for reused symbols | Yes | `<div class="legend">` row: A, B, C, X stray, Blank, A+ merged (x1.5, rounded up), the undo choice. |
| Three text registers (criterion: italic for story or flavour text, roman for rules, small italic for parameters, used consistently; heading sizes alone are hierarchy, not registers) | Yes | Each of the three notes has the same three lines: an italic `.story` line ("It sounds good. It is not part of the build."), a roman `.rule` paragraph, and a small italic `.param` line ("Cost of undo: 1 of 9 choices, about 11% of the run."). Used identically in all three. |
| Repeated things as identical cards (criterion: the same box anatomy repeated for each member of a set, with the same slots filled) | Yes | The nine choices repeat as identical roster cells in both rows (numbered label, "take X" line, 8-slot grid), and the three notes share one anatomy: heading, story line, rule paragraph, parameter line. |
| Time or difficulty drawn, not described | Yes | A ruler marked "choice 1" to "choice 9" with a light bar for the stray pick and a dark bar for the undo. |
| One surface, no navigation, nothing hidden | Yes | One `.poster`; no `<nav>`, `<a>`, `<script>`, `<details>`; only `overflow:hidden` and `aria-hidden` matched. |
| Surface sized in inches with print CSS | Yes | `--w:17in; --h:11in`, `@page { size: var(--w) var(--h); margin: 0; }`, `@media print` rule. |
| Self-contained (no external resources) | Yes | No `http`, no `<script>`; inline style and SVG. |

Score: 11 of 11 present.

Note on content: the page corrects the brief's claim. The brief said undo costs about one ninth; the page says the undo is one in nine and the stray pick itself used a choice, so two in nine. The reply flagged this.

## Against the baseline

Moved from absent to present (6 items):
- Title states the point (baseline: a question; the answer sat in a verdict box).
- Date on the page (baseline: none).
- Callouts tied to the depiction (baseline: plain text labels, no leader lines).
- Legend for reused symbols (baseline: fills with no key).
- Three text registers (baseline: no italic anywhere).
- Surface sized in inches with print CSS (baseline: `max-width:820px`).

Present in both: one depiction (the baseline drew a single timeline; the skill page draws two full roster runs side by side), identical cards, time drawn, one surface, self-contained.

Still absent: none.

The claim correction (two in nine) also appeared in the baseline, so the skill did not cause it.

## Comparison with scenario 1

Shape chosen here: two-row comparison of runs on a choice ruler. Scenario 1: central object with margin cards and a run map. The shapes differ. Shared across both: title as claim, footer date, three registers, a boxed legend, numbered leader callouts, the same paper, ink and red accent palette, and an inch-sized sheet.

## fit-check after Task 8

The updated fit-check, which also checks unitless SVG font sizes at 100 units per inch, run on the existing page. Verbatim output, exit code 0:
```
surface: 17.0 x 11.0 in
```
Findings: 0. Scenario 2 was not re-run.

After the callout count was added in round 3 of scenario 1, the same check gives, verbatim, exit code 0:
```
callouts: 3
surface: 17.0 x 11.0 in
```

## Final run (after the final-review fix wave)

Changes under test: the same SKILL.md and fit-check as the final run of scenario 1. The full list is in that record. This is the first run of scenario 2 against the margin budget, the title exemption and the second-panel clause.

Run: one fresh `general-purpose` subagent on model `sonnet`. It was given the line "Use the one-page-design skill at /Users/cesar/.claude/skills/one-page-design/SKILL.md." followed by `tests/scenarios/single-mechanic.md` verbatim, with the output path filled in. Its reply did not come back to me, so this record is scored from the HTML and the PNG only.

Output: output/2026-11-01-single-mechanic-with-skill-final.html, 43 lines. Preview: output/2026-11-01-single-mechanic-with-skill-final.png.

Fit-check, the updated script, verbatim, exit code 0:
```
callouts: 6
surface: 19.5 x 11.0 in
preview: tests/results/output/2026-11-01-single-mechanic-with-skill-final.png
```
Findings: 0. The drawing layer is `viewBox="0 0 1950 1100"` on a 19.5 x 11 in surface, which is 100 units per inch, so the new viewBox check passes.

Preview inspected by eye at preview resolution: nothing is cut at the edges, and no two elements overlap.

Shape chosen: a framed two-column comparison. The patient run is on the left and the impatient run on the right. Each is drawn as nine eight-slot rosters, one row per choice, top to bottom. A vertical spine of circled choice numbers 1 to 9 runs between them, labelled "choice, then fight". The impatient run's stray S at choice 3 and its removal at choice 4 sit in a pink band. Dashed blue boxes mark patient choice 7 and impatient choice 9 as identical rosters (A+ B+ A). Earlier, the shape was two horizontal rows on a choice ruler. This time the runs are vertical columns on a spine.

Centre of the PNG: two columns of roster rows. The left reaches A+ B+ A+ by choice 9. The right shows a red S at choice 3, a hatched Blank at choice 4, merges at choices 6 and 8, and ends at A+ B+ A.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | Yes | `<h1 class="title t1">An impatient pick costs 2 of a run's 9 choices once undone: 1 for the pick, 1 for the undo</h1>`. |
| Date on the page | Yes | `<footer class="date">Proposal · 2026-11-01</footer>`, bottom-right. |
| One depiction holding the middle | Yes | `<svg viewBox="0 0 1950 1100" ...>` with the frame `<rect x="316" y="150" width="1288" height="870" rx="10" ...>` holding both runs and the choice spine. |
| Callouts tied to the depiction (leader lines or numbers) | Yes | There are 6 `<div class="callout">` and 6 `<path class="leader">`, each ending on a roster in the frame: `M300,240 L337,534` at patient choice 4, `M300,410 L331,786` at patient choice 7, `L1270,450` at the stray S, `L1270,534` at the undo Blank, `L1334,702` at the late merge, and `L1586,954` at impatient choice 9. Each callout heading names its choice number, which matches the spine. |
| Legend for reused symbols | Yes | `<div class="legend">`: A and B build pieces, A+ merged, S stray, Blank, empty. It also carries a note on the illustrative assumptions. |
| Three text registers (every callout and card carries an italic story line, roman rule text and a small italic parameter line where the design has them) | Yes, with a caveat | All 6 callouts carry `.story`, `.rule` and `.param`, for example "It sounded good." / "A piece with no copies in the build takes slot 3 ..." / "1 of 9 choices spent, nothing built." The 3 cards carry an italic `.story` line and roman row labels with italic `.param` values, but no roman rule sentence. |
| Repeated things as identical cards (same box anatomy, same slots filled) | Yes | 3 `<div class="card">` (1 Patient, 2 Undo at once, 3 Keep the stray), each with a head, a blue sub-line ("n of 9 picks build the roster"), a story line, and the rows Choices lost, Dead slots and Roster at choice 9. The 18 roster rows in the drawing share one anatomy. |
| Time or difficulty drawn, not described | Yes | The vertical spine of choices 1 to 9 is the run's time axis. Lost time is drawn as the pink band over choices 3 and 4 and as the two-row offset between the dashed boxes. |
| One surface, no navigation, nothing hidden | Yes | One `<main class="poster">`. There is no `<a>`, `<details>`, `<script>` or `<link>`, and fit-check is clean. |
| Surface sized in inches with print CSS | Yes | `--w:19.5in; --h:11in;` on `:root`, `@page { size: var(--w) var(--h); margin: 0; }`, and an `@media print` rule. |
| Self-contained (no external resources) | Yes | No `http` strings, no `<link>` and no `<script>`. |

Score: 11 of 11 present.

### Margin budget, by measurement

Coordinates are viewBox units at 100 per inch on a 19.5 x 11 in surface, which is 214.5 sq in.

| Predicate | Measured | Met? |
|---|---|---|
| Depiction box at least half the surface | Frame x 316 to 1604, y 150 to 1020: 12.88 x 8.70 in, 112.1 sq in, 52.2%. | Yes |
| Depiction is the widest thing on the page, apart from the title | Frame 12.88 in. Callouts, cards and the legend are 2.2 to 2.6 in wide. | Yes |
| Margin text 11 pt or less | Largest margin text: 10 pt (`.callout h3` and `.card .head`). Callout body and card story lines are 9 pt, the legend and rows 8 pt and params 7 pt. | Yes |
| At most eight callouts, each leader ending on the depiction | `callouts: 6`. All 6 leaders end on rosters inside the frame. | Yes |
| At most three card sets, along one or two edges | One set of 3 strategy cards on the left edge. | Yes |

Judgement: the margin budget is met on measurement. The earlier page's depiction was about 42% of the surface, which failed the final contract's half-surface rule. This run is at 52.2%.

Note on content: the page again corrects the brief's claim to two choices in nine, as the earlier run and the baseline did.

Observation for the reviewer: both final pages now share a frame. Each has a ruled panel of just over half the surface, callouts in narrow side margins, and a card column on the left edge. What sits inside the frames still differs: a scene of one slam over a run map here against a two-column roster comparison on a choice spine. The review's worry that the budget pushes pages toward one outer layout is partly borne out at the level of the frame, not of the depiction.
