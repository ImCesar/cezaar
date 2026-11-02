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
