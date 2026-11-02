# Baseline: single-mechanic, no skill, 2026-11-01

Reply (verbatim):
> I wrote the one-page design doc to `/Users/cesar/.agents/skills/one-page-design/tests/baselines/output/2026-11-01-single-mechanic-no-skill.html`. It opens with a verdict box, then an SVG timeline of one wrong pick across nine choices, a table of when the cost applies, and a short recommendation with what to playtest. I didn't open it in a browser or check how it renders.
>
> It's shaped that way because a producer needs the answer first. The answer is that the claim is only partly right. Undoing the pick costs 1 of 9 choices, about 11%. Counting the pick itself, the real cost is 2 of 9, about 22%, and only when the roster is full. If empty slots remain, the bad piece can just sit there and the cost is close to zero.
>
> I corrected the claim instead of restating it, because "one ninth" leaves out the choice already spent on the wrong piece and the full-roster condition.

(The request was three sentences. The reply ran to nine.)

Output: output/2026-11-01-single-mechanic-no-skill.html, 60 lines.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | No | `<h1>Merge-and-sell economy: does it punish impatient picks?</h1>` is a question. The answer is in `<div class="verdict">` below it. |
| Date on the page | No | No date anywhere in the file. |
| One depiction holding the middle | Yes | One `<svg viewBox="0 0 800 130">`: a timeline of nine choices with the wrong pick at 3. It sits below a text verdict and above two tables, and it shows only the timeline, not the eight-slot roster. |
| Callouts tied to the depiction (leader lines or numbers) | No | Labels are plain `<text>` placed under the boxes ("Choices 3 and 4: spent, no progress (2/9)"). No leader lines. Box numbers 1 to 9 are the only numbering. |
| Legend for reused symbols | No | Pink fill (`#f6c9c5`) and grey fill (`#eee`) are used with no key. |
| Three text registers (criterion: italic for story or flavour text, roman for rules, small italic for parameters, used consistently; heading sizes alone are hierarchy, not registers) | No | The file has no italic anywhere (no `<i>`, `<em>`, `font-style`). Georgia body, uppercase sans h2 and 11px SVG labels are hierarchy and font changes, not the three registers. |
| Repeated things as identical cards (criterion: the same box anatomy repeated for each member of a set, with the same slots filled) | Yes | Nine identical `<rect width="78" height="40">` cells, each with the same two slots filled (choice number and role label). Fill varies for the three that matter. |
| Time or difficulty drawn, not described | Yes | The SVG draws the nine choices along a line and where the cost lands. |
| One surface, no navigation, nothing hidden | Yes | No nav, links, scripts or hidden elements. Single scrolling body. |
| Surface sized in inches with print CSS | No | `max-width:820px`; no `@page`, no `@media print`, no inch units. |
| Self-contained (no external resources) | Yes | No `http` URLs, system fonts, inline `<style>` and inline SVG. |

Rationalizations or shortcuts seen in the reply (verbatim):
- "I didn't open it in a browser or check how it renders." (no render check)
- "a producer needs the answer first" (answer first, but as a text box rather than the title)
- "I corrected the claim instead of restating it, because "one ninth" leaves out the choice already spent on the wrong piece and the full-roster condition." (rewrote the claim the page was asked to show)
