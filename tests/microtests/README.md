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

## Control isolation

The installed skill is offered to every subagent in this harness, so control
runs must be made with the symlink at
`/Users/cesar/.claude/skills/one-page-design` moved aside (`mv` it to
`.one-page-design.off`, restore it after, verify with `ls -la`) and with the
line "Do not invoke any skills; work from this brief alone." appended. The
first five controls in the 2026-11-01 run were contaminated and are kept as
`*-contaminated-*.html`. (The final controls that run used the wording "Do
not load or follow any skill." with the symlink moved aside.)
