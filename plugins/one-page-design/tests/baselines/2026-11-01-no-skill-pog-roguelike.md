# Baseline: pog-roguelike, no skill, 2026-11-01

Reply (verbatim):
> I wrote a one-page HTML design doc to `/Users/cesar/.agents/skills/one-page-design/tests/baselines/output/2026-11-01-pog-roguelike-no-skill.html`. I haven't opened it in a browser. It runs from the five-step turn loop through effects, slammers, readability, roster and run structure, and ends with a table answering each of your six risks. A short "Open" section lists what is still unspecified: the Heavy, Slick and Sticky rules, shop prices and elite rewards, boss design, and how the AI opponent picks its slammer and aim.
>
> I shaped it that way so a programmer with no context can follow the order of play first, then look up numbers in compact tables. The central rule is stated up front: effects go to the slammer, not the pog's owner, so your own pogs can hurt you and the enemy's can help you.
>
> I added three things your brief didn't say. Resolution speed scales with the number of flipped pogs to fit the 3 s cap. Charms can't change an effect's type, such as turning Poison into Heal. Elites are described as a harder roster with a better reward. Check those three against your intent.

(The request was three sentences. The reply ran well past that, with a paragraph of unrequested additions.)

Output: output/2026-11-01-pog-roguelike-no-skill.html, 129 lines.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | No | `<h1>Pog Roguelike</h1>` names the game only. The point sits in a separate `<p class="tag">` paragraph. |
| Date on the page | No | No date anywhere in the file. |
| One depiction holding the middle | No | No SVG, image, or drawing. The centre is `<section class="span3">` "Core loop" made of five text boxes (`.step`), then tables. The tower and strip are described in a bullet list, never drawn. |
| Callouts tied to the depiction (leader lines or numbers) | No | No depiction to tie to. The only numbering is "1. Stack" to "5. Reshuffle" in the loop boxes. |
| Legend for reused symbols | No | No legend. The "contributor colour" and icon are described in prose; Heavy/Slick/Sticky are bare `.pill` spans with "exact rules ... see Open". |
| Three text registers (criterion: italic for story or flavour text, roman for rules, small italic for parameters, used consistently; heading sizes alone are hierarchy, not registers) | No | The file has no italic anywhere (no `<i>`, `<em>`, `font-style`). Rules, flavour and parameters are all roman. The h1 22px, uppercase accent h2 and 13px body are hierarchy only. |
| Repeated things as identical cards (criterion: the same box anatomy repeated for each member of a set, with the same slots filled) | Yes, five loop steps only | The five `.step` boxes each repeat a bold title plus one sentence. The sets that repeat in the design (effects, slammers, risks) are `<table>` rows, not cards. |
| Time or difficulty drawn, not described | No | "Run structure (40 to 50 min)" is a bullet list. The 12-node map and 3 s budget are text only. |
| One surface, no navigation, nothing hidden | Yes | No nav, links, scripts, tabs or hidden elements. Content is a single scrolling `<main>` grid. |
| Surface sized in inches with print CSS | No | `max-width:1100px`; no `@page`, no `@media print`, no inch units. |
| Self-contained (no external resources) | Yes | No `http` URLs, system font stack, inline `<style>` only. |

Rationalizations or shortcuts seen in the reply (verbatim):
- "I haven't opened it in a browser." (no render check)
- "so a programmer with no context can follow the order of play first, then look up numbers in compact tables" (tables and prose chosen as the shape; no drawing considered)
- "I added three things your brief didn't say." (invented rules: speed scaling, charms cannot change effect type, elite rewards)
- "Check those three against your intent." (hands verification back to the user)
