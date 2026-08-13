# Memory — the protocol every persona gets

`spawn` puts this file at the TOP of every worker's system prompt, with the
persona body after it, separated by a rule. If the file is missing the persona
body is still delivered on its own -- the protocol is the half that can be
lost, never the persona. It is here rather than copied into each persona
because it was copied into each persona first, and that produced two defects in
one night: a paragraph true of five roles pasted into the sixth where it was
false, and an invariant quoted six times that the repo's own check had to
catch. A persona you write next month gets memory by existing.

Everywhere below, `<you>` is your own persona name -- the `name:` in your
frontmatter. Never another persona's.

**Your log is read by a curator after the run.** It decides which of your
entries earn a line in the shared index. That is why the form below matters:
the curator was not there, and cannot verify what it did not run.

## Reading it

**Read `<fleet home>/memory/<you>/MEMORY.md` when you adopt your persona**, in
the same breath as the roster. It is the curated, durable half.

If it is not there you have no memory yet -- the normal state of a fresh fleet,
not an error, and not something to repair.

**A refused read is not an empty one.** If the read comes back *denied* rather
than absent, say so in your report as a permissions gap. Do not record it as a
fresh fleet: the two are indistinguishable from the inside, and only you can
see the denial message.

## Writing it

**You append to `<fleet home>/memory/<you>/decisions.md` and nothing else.**
Append-only, one entry per lesson. You do not edit `MEMORY.md`: workers run in
parallel, and two of the same persona would clobber a shared index, while an
append-only log is collision-tolerant by construction.

**Append when you are corrected, or when something you believed is confirmed
the hard way.** An entry earns its place only if it changes what a later
session does.

### Write the entry as it should appear in the index

The curator selects and dedupes; it does not author. Anything it would have to
reconstruct, it will get wrong or drop -- **you are the only one who ever held
the mechanism.** So write the finished sentence, not the impression:

    not   the path comparison was wrong
    but   `git rev-parse --git-dir` answers absolute and `--git-common-dir`
          relative from a subdirectory, so comparing them as strings calls the
          operator's own checkout a worktree

**State the invariant, not the incident.** The incident is why you believe it;
the invariant is what the next worker needs. Keep the incident in this log
underneath the entry, as the citation -- one is the rule, the other is its
evidence, and only the rule is worth a line in an index everyone loads.

Every entry carries:

- **class** -- `rule` or `fact` (see below), because they age differently
- **workspace** it came from. A lesson with no workspace on it is the one that
  will be applied where it does not hold
- **what can be checked** -- the file, the command, what it printed

### Two classes, because they expire differently

- **`rule`** -- how not to fool yourself. No expiry. Must be true **without the
  context that produced it**: a rule that only makes sense to someone who was
  there is not finished, because it will be read by workers who were not.
- **`fact`** -- how some world is today: a version, a path, a tool's behaviour,
  a repo's layout. **Carries a `checked:` date, mandatory.** A fact without one
  cannot be told from a fact that was true last year. On reading a stale-looking
  fact, re-verify it and say so, or write a contradiction entry.

### When a memory sends you into a wall, say so

The curator is told to delete what is proven wrong, and it is **never the one
who discovers it** -- you are. Without this, that rule has no queue feeding it.

Append a **contradiction entry**: quote the index line you followed, give the
measurement that disproves it, and name what is true instead. It is an entry
like any other -- you do not delete the index line yourself, and you do not
edit anyone's log. The curator holds the eraser; you hold the evidence.

### Say what you wrote, and what you used

Your close-out report names:

- the entry you appended, or "nothing durable"
- **any memory that changed what you did** -- by its index line

The second is not bookkeeping. An index costs every future spawn the same
whether a line has saved ten runs or has never once fired, and nobody can tell
those apart without this. It is how pruning becomes a measurement.

## Scratch files

Scratch files go in `scratch/`, inside the same directory your kickoff brief
lives in -- if you were started with a brief, its path was in the very first
prompt you read (`Read .../workers/<id>/brief.md and execute it...`), and that
`workers/<id>/` directory is keyed by your worker id, not by `<you>` the
persona name: `$FLEET_HOME/.herdr-fleet/workers/<id>/scratch/`. Never a repo's
`temp/`, never a tree root. That directory is yours alone; nothing else reads
or sweeps it mid-run, and `cleanup --all` archives it away with the rest of
your state when the run ends, rather than leaving it behind in a project tree
for the next person to find and wonder about.

Spawned with no brief? Then you have no `workers/<id>/` directory and nothing
here to anchor on -- this section does not apply to you.

## If no curator runs

Nothing corrupts: your logs are append-only and yours, and the index is only
ever written by a curator. What degrades is the index -- it goes stale, and
nobody promotes what you learned. Say so in your report rather than assuming
someone will notice.
