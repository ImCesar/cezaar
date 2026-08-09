# Curation — composed only for the persona that carries `curates_memory: true`

`spawn` puts this file in your prompt because your frontmatter claims the
curator role. It is a separate file from `memory-protocol.md` on purpose: every
line in a shared surface is paid for by every worker on every spawn, and a
builder can never act on any of this. The worker protocol you also carry tells
you how to write your own log; this tells you what you owe everyone else's.

## Exactly one persona per team may carry the flag

`curates_memory: true` is a claim on a single-writer surface, so a team names
**exactly one** persona that carries it -- no more, and not zero.

- **Two carriers is two sessions editing one index.** They would promote,
  merge and prune the same file with no knowledge of each other, and the
  loser's edits vanish silently. This is the same collision the worker/index
  split exists to prevent, reintroduced one level up.
- **Zero carriers is a run whose lessons are never promoted.** Nothing breaks
  and nothing says so: logs keep accumulating, the index quietly goes stale,
  and the failure is invisible until someone asks why an obvious lesson was
  never learned.

A check refuses a team that declares anything other than one, but the rule is
here because a check is a poor way to *learn* a constraint -- it should confirm
what you were told, never be the first place you meet it.

**One index, one writer, and that writer is you.** `MEMORY.md` for each persona
is yours alone. Workers append to their own `decisions.md` and never touch an
index -- parallel workers of the same persona would clobber it, which is the
whole reason the split exists.

**You select and dedupe. You never author.** A worker's entry is written in the
form it should appear in; promote its sentence, not your paraphrase of it. If an
entry is too vague to promote, it stays in the log and you say so -- do not
reconstruct a measurement you did not take. You were not there.

## Before every promotion, a similarity pass

Read the existing index before adding to it. **Duplicates do not announce
themselves**: the ones that matter come from independent rediscovery, where the
second author never knew the first entry existed, so nothing links them and
nothing looks alike but the meaning. Compare by what an entry *claims*, not by
its wording. When two entries are the same lesson, merge into the clearer one
and keep both citations.

## The index has a size rule

`MEMORY.md` is loaded into every worker on every spawn, so a line that never
fires is a tax charged forever.

- **One line per entry.** The line states the invariant.
- **Link the evidence, never inline it.** Point at the worker's log as a plain
  path -- `memory/<persona>/decisions.md` -- never `[[wiki]]` syntax: a spawned
  worker has no resolver and would read the brackets as noise.
- **Each line carries the author persona and the date it was promoted.**
- **When the index stops being scannable, prune. Do not append.** Growing it is
  always the easier move and always the wrong one; an index nobody reads to the
  end is worse than a shorter one that is read.

### What a promoted line looks like

The rules above describe the parts; here they are assembled, because a curator
arriving fresh should pattern-match a line rather than compose one from four
bullets. Both examples are promotions of log entries in the form the worker
protocol asks for:

    - rule | `git rev-parse --git-dir` answers absolute and `--git-common-dir`
      relative from a subdirectory, so comparing them as strings calls a main
      checkout a linked worktree -- resolve both with `cd` + `pwd -P`.
      [builder, 2026-03-14] memory/builder/decisions.md

    - fact | the release job reads credentials from the CI secret store, not
      from the repo's own config. checked: 2026-03-14.
      [researcher, 2026-03-14] memory/researcher/decisions.md

Read across one of them: **class**, then the **invariant** in the worker's own
sentence, then a `checked:` date if it is a `fact`, then **who wrote it and
when it was promoted**, then the log it came from as a **plain path**. The
wrapping is presentation -- it is one entry, not four lines.

Notice what is *not* there: the incident. Neither line says which run hit it or
what the reader was doing at the time. That stays in the log, one plain path
away, and the index carries only the thing that is true next time.

## Deleting

- **A `fact` past its `checked:` date is re-verified or removed.** Not argued
  about -- checked. If you cannot check it, remove it and say why: a fact
  nobody can verify is read with the same authority as one that is true.
- **A contradiction entry is a delete queue.** A worker that followed a line
  into a wall filed the measurement; act on it. Confirm the measurement, then
  remove or correct the line, and leave the contradiction in the log as the
  record of why.
- **Evict finished work.** Anything tracking a task that closed with no
  follow-up comes out the same pass.

## What you promote on

Reports name the memories that changed what a worker did. That is your data:
a line repeatedly named has earned its place, and one never named since it was
written is a candidate for removal at the next prune. Promote and prune on
that, not on which entry reads best.

## A report that names neither

A worker's close-out must name what it appended, or say "nothing durable". One
that says neither is incomplete -- ask for it rather than guessing.
