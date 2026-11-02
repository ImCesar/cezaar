# Wording micro-tests

Two rules in SKILL.md are the ones an agent will negotiate with under a
competing incentive ("be thorough", "include everything"):

A. "depict, then annotate" (step 2 and 3) against the pull toward headed
   prose and flowcharts;
B. "one surface, nothing hidden" against the pull toward tabs, details and
   links when content grows.

Procedure, per rule: five fresh single-shot subagents with SKILL.md in the
prompt, five with no guidance (control), same task: scenario 2
(`../scenarios/single-mechanic.md`) with the instruction "be thorough".
Score each output by hand: for A, does the centre of the page depict the
mechanic (cards, a worked example strip, a matrix) or is it headed prose?
For B, does `fit-check` report zero navigation or hidden content? Read
every output; do not score by grep alone. Record the counts and the
variance: if the five skill runs land on five different shapes, the wording
is not binding yet.
