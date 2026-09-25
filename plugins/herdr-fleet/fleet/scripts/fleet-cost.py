#!/usr/bin/env python3
"""What did a fleet run cost? Read from the workers' own transcripts.

Every model and effort choice in cezaar#40 is a bet made on Anthropic's
published benchmarks, not on this fleet's work. This turns the hand
measurement behind #40's cost baseline into something any run can repeat.

THE METHOD. Each Claude Code session writes `<projects>/<dir>/<session>.jsonl`,
where `<dir>` is the session's cwd with every character outside [A-Za-z0-9]
replaced by `-` (so `/Users/x/.fleet` is `-Users-x--fleet`). Claude Code
records the REAL path, symlinks resolved: a worker spawned in `~/.fleet` writes
under the directory of whatever `~/.fleet` points at. Every assistant record
carries `message.id`, `message.model` and `message.usage`; streaming writes one
record per content block, all with the same id and the same usage, so a
message is counted once, by id.

ATTRIBUTION -- which session belongs to which worker. Several workers can
share a cwd (a judge runs in its validator's worktree), so the directory alone
settles nothing. Two signals, and they must agree:
  * the brief id: `spawn` and `assign` kick a worker off with "Read
    .../workers/<id>/brief.md", which is the session's first typed prompt;
  * the window: a spawn in a cwd owns the sessions that start there from its
    spawn until the next spawn in the same cwd, or its own cleanup.
A session whose signals disagree, or that has neither, is listed as
unattributed with the reason. It is never folded into a worker: a wrong
attribution is worse than a visible gap, because nobody goes looking for it.

THE NUMBERS are API-equivalent dollars, priced from PRICES below. An unknown
model ID is reported and left unpriced rather than priced at some default.

Usage: python3 scripts/fleet-cost.py [--reprice MODEL] [--flat-cache-writes]
                                     [--projects DIR] RUN
  RUN      an archived run directory, an archive timestamp, or `current`
           ($FLEET_HOME/.herdr-fleet, FLEET_HOME defaulting to this repo, as
           the wrapper does)
Exit 0 = report written, 2 = the report could not run (no manifest, etc).
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys

CANNOT_RUN = 2

# Per million tokens: (input, output, cache-read multiplier of input). Dated,
# because prices change and a report priced from a stale table is wrong
# without looking wrong. Update the date with the numbers.
PRICES_AS_OF = "2026-09-23"
PRICES_SOURCE = "https://platform.claude.com/docs/en/about-claude/pricing"
PRICES = {
    "claude-fable-5-1": (10.0, 50.0, 0.025),
    "claude-opus-5-5": (4.0, 20.0, 0.05),
    "claude-opus-5": (5.0, 25.0, 0.1),
    "claude-sonnet-5": (2.0, 10.0, 0.1),
    "claude-haiku-4-5-20251001": (1.0, 5.0, 0.1),
}
# Cache writes are priced as a multiple of input: 1.25x for the 5-minute TTL,
# 2x for the 1-hour TTL.
CACHE_WRITE_5M = 1.25
CACHE_WRITE_1H = 2.0

# The aliases personas name (cezaar#41), as Claude Code 2.1.281 resolves them.
ALIASES = {
    "fable": "claude-fable-5-1",
    "opus": "claude-opus-5-5",
    "sonnet": "claude-sonnet-5",
    "haiku": "claude-haiku-4-5-20251001",
}

# Claude Code writes locally generated messages (an API error shown in the
# transcript, an interrupted turn) as assistant records with this model. They
# are not API calls and carry no usage worth pricing.
SYNTHETIC_MODEL = "<synthetic>"

# The statuses `spawn` writes. `assign` and `cleanup` rows re-snapshot a worker
# that already exists, so they start no window.
SPAWN_STATUSES = ("ready", "unverified", "blocked-on-trust")

# `spawn` logs its manifest row only after boot-verify, which waits up to
# FLEET_BOOT_TIMEOUT (default 90s) for Claude's UI -- and the session file
# starts before that. Measured in the 2026-09-23 run: every session started
# 0.7-2.2s before its row. A window opens this much before its spawn row.
BOOT_SLACK = datetime.timedelta(seconds=120)

BRIEF_ID = re.compile(r"\.herdr-fleet/workers/([^/\s]+)/brief\.md")

# Role families for the totals. The personas are cezaar#40 section 2.4's
# roster, so the first run on the new personas is sorted without an edit.
# Anything not listed is `other`.
FAMILIES = {
    "builder": "build", "integrator": "build",
    "reviewer": "review", "solution-reviewer": "review",
    "architecture-reviewer": "review", "system-verifier": "review",
    "security-reviewer": "review", "acceptance-tester": "review",
    "judge": "judge",
    "architect": "design", "system-architect": "design",
    "component-architect": "design", "problem-analyst": "design",
    "solution-ideator": "design", "solution-evaluator": "design",
    "product-manager": "design",
}
FAMILY_ORDER = ("build", "review", "judge", "design", "other")
# Runs from before cezaar#47 split out the `judge` persona ran a judge as a
# `reviewer` briefed to judge, and the only record of that is the heading of
# its brief. Kept so archived runs, the #40 baseline among them, still sort.
JUDGE_HEADING = re.compile(r"\bjudge\b", re.IGNORECASE)


def cannot_run(msg):
    print(f"fleet-cost: {msg}", file=sys.stderr)
    sys.exit(CANNOT_RUN)


def parse_ts(text):
    if not text:
        return None
    try:
        ts = datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    return ts if ts.tzinfo else ts.replace(tzinfo=datetime.timezone.utc)


def model_id(name):
    return ALIASES.get(name, name)


def project_dir_names(path):
    """Claude Code's name for a cwd's transcript directory. Past 200 characters
    it truncates and appends a hash of the full path, which is not reproduced
    here: a long path matches every directory sharing the truncated prefix,
    and the session's own recorded cwd then decides."""
    name = re.sub(r"[^a-zA-Z0-9]", "-", path)
    return (name, True) if len(name) <= 200 else (name[:200], False)


# ---------------------------------------------------------------- the run

def resolve_run(arg):
    if arg == "current":
        home = os.environ.get("FLEET_HOME") or os.path.dirname(
            os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(home, ".herdr-fleet")
    path = os.path.expanduser(arg)
    if os.path.isdir(path):
        return path
    home = os.environ.get("FLEET_HOME") or os.path.dirname(
        os.path.dirname(os.path.abspath(__file__)))
    archived = os.path.join(home, ".herdr-fleet", "archive", arg)
    if os.path.isdir(archived):
        return archived
    cannot_run(f"no run at {arg!r} (nor {archived})")


def read_manifest(run_dir):
    path = os.path.join(run_dir, "manifest.jsonl")
    if not os.path.isfile(path):
        cannot_run(f"no manifest.jsonl in {run_dir}")
    rows = []
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            if not line.strip():
                continue
            try:
                rows.append(json.loads(line))
            except ValueError:
                cannot_run(f"{path}:{n} is not JSON")
    if not rows:
        cannot_run(f"{path} is empty")
    return rows


def persona_name(path):
    return os.path.splitext(os.path.basename(path or ""))[0] or "?"


def brief_heading(run_dir, wid):
    path = os.path.join(run_dir, "workers", wid, "brief.md")
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if line.strip():
                    return line.strip()
    except OSError:
        pass
    return ""


def family_of(persona, heading):
    if persona == "reviewer" and JUDGE_HEADING.search(heading):
        return "judge"
    return FAMILIES.get(persona, "other")


def spawns_from(rows, run_dir):
    """One entry per spawn row, with the window it owns in its cwd."""
    spawns = []
    for i, row in enumerate(rows):
        if row.get("status") not in SPAWN_STATUSES:
            continue
        ts = parse_ts(row.get("ts"))
        if ts is None:
            cannot_run(f"manifest row for {row.get('id')!r} has no usable ts")
        cleaned = next((parse_ts(r.get("ts")) for r in rows[i + 1:]
                        if r.get("id") == row.get("id")
                        and r.get("status") == "cleaned"), None)
        spawns.append({
            "id": row["id"],
            "persona": persona_name(row.get("persona")),
            "cwd": row.get("cwd", ""),
            "real_cwd": os.path.realpath(os.path.expanduser(row.get("cwd", ""))),
            "ts": ts,
            "cleaned": cleaned,
            "model": row.get("model") or "",
            "effort": row.get("effort") or "",
        })
    for s in spawns:
        later = [o["ts"] for o in spawns
                 if o is not s and o["real_cwd"] == s["real_cwd"]
                 and o["ts"] > s["ts"]]
        s["start"] = s["ts"] - BOOT_SLACK
        ends = [t - BOOT_SLACK for t in later]
        if s["cleaned"]:
            ends.append(s["cleaned"])
        s["end"] = min(ends) if ends else None
    for s in spawns:
        s["family"] = family_of(s["persona"], brief_heading(run_dir, s["id"]))
    return spawns


# ---------------------------------------------------------- transcripts

def read_jsonl(path):
    records = []
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                try:
                    records.append(json.loads(line))
                except ValueError:
                    continue   # a torn last line from a live session
    except OSError:
        pass
    return records


def is_typed_prompt(record, has_origin):
    """A prompt the operator or the lead typed into the pane -- the proxy for
    rounds. Recent Claude Code marks these `origin.kind == "human"`; without
    that field, anything that is not a tool result or a meta record."""
    if record.get("type") != "user":
        return False
    if has_origin:
        return (record.get("origin") or {}).get("kind") == "human"
    if record.get("isMeta"):
        return False
    content = (record.get("message") or {}).get("content")
    if isinstance(content, list):
        return any(isinstance(b, dict) and b.get("type") == "text"
                   for b in content)
    return isinstance(content, str)


def prompt_text(record):
    content = (record.get("message") or {}).get("content")
    if isinstance(content, list):
        return " ".join(b.get("text", "") for b in content
                        if isinstance(b, dict))
    return content if isinstance(content, str) else ""


def load_session(path):
    records = read_jsonl(path)
    # A session's subagents are its own API spend, written beside it.
    sub_dir = os.path.join(os.path.splitext(path)[0], "subagents")
    sub_records = []
    for sub in sorted(glob.glob(os.path.join(sub_dir, "*.jsonl"))):
        sub_records.extend(read_jsonl(sub))
    stamps = [t for t in (parse_ts(r.get("timestamp")) for r in records) if t]
    if not stamps:
        return None
    has_origin = any("origin" in r for r in records if r.get("type") == "user")
    prompts = [r for r in records if is_typed_prompt(r, has_origin)]
    messages = {}
    for r in records + sub_records:
        msg = r.get("message") or {}
        if r.get("type") != "assistant" or not msg.get("id") \
                or "usage" not in msg:
            continue
        if msg.get("model") == SYNTHETIC_MODEL:
            continue
        messages[msg["id"]] = msg   # every record of one id carries one usage
    return {
        "path": path,
        "session": os.path.splitext(os.path.basename(path))[0],
        "cwd": next((r["cwd"] for r in records if r.get("cwd")), ""),
        "start": min(stamps),
        "first_prompt": prompt_text(prompts[0]) if prompts else "",
        "prompts": len(prompts),
        "messages": messages,
        "efforts": sorted({r["effort"] for r in records
                           if isinstance(r.get("effort"), str)}),
        "subagent_files": len(glob.glob(os.path.join(sub_dir, "*.jsonl"))),
    }


def sessions_for(projects, real_cwd):
    name, exact = project_dir_names(real_cwd)
    dirs = [os.path.join(projects, name)] if exact else \
        glob.glob(os.path.join(projects, glob.escape(name) + "*"))
    out = []
    for d in dirs:
        for path in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
            s = load_session(path)
            # The directory name is lossy (`/a.b` and `/a-b` share one); the
            # cwd the session recorded is not.
            if s and s["cwd"] == real_cwd:
                out.append(s)
    return out


# ---------------------------------------------------------- attribution

def attribute(sessions, spawns):
    by_id = {}
    for s in spawns:
        by_id.setdefault(s["id"], []).append(s)
    first = min(s["start"] for s in spawns)
    last = None if any(s["end"] is None for s in spawns) else \
        max(s["end"] for s in spawns)
    attributed, unattributed, outside = [], [], 0
    for sess in sessions:
        if sess["start"] < first or (last and sess["start"] >= last):
            outside += 1
            continue
        windows = [s for s in spawns if s["real_cwd"] == sess["cwd"]
                   and s["start"] <= sess["start"]
                   and (s["end"] is None or sess["start"] < s["end"])]
        m = BRIEF_ID.search(sess["first_prompt"])
        named = m.group(1) if m else None
        window_ids = sorted({s["id"] for s in windows})
        if named and named not in by_id:
            why = f"first prompt names workers/{named}, not in this manifest"
        elif named and window_ids == [named]:
            attributed.append((sess, windows[0], "brief id + window"))
            continue
        elif named and not window_ids:
            why = (f"first prompt names {named}, but the session started "
                   "outside every spawn window in this cwd")
        elif named:
            why = (f"first prompt names {named}, but the window belongs to "
                   f"{', '.join(window_ids)}")
        elif len(window_ids) == 1:
            attributed.append((sess, windows[0], "window only"))
            continue
        elif window_ids:
            why = f"no brief id; windows overlap ({', '.join(window_ids)})"
        else:
            why = "no brief id, and outside every spawn window in this cwd"
        unattributed.append((sess, why))
    return attributed, unattributed, outside


# ------------------------------------------------------------- pricing

def tokens(usage):
    written = usage.get("cache_creation_input_tokens", 0) or 0
    split = usage.get("cache_creation")
    # Without the TTL split the write was made at the default 5-minute TTL.
    one_hour = (split or {}).get("ephemeral_1h_input_tokens", 0) or 0
    return {
        "input": usage.get("input_tokens", 0) or 0,
        "write_5m": written - one_hour,
        "write_1h": one_hour,
        "read": usage.get("cache_read_input_tokens", 0) or 0,
        "output": usage.get("output_tokens", 0) or 0,
    }


def price(tok, model, flat_writes):
    if model not in PRICES:
        return None
    inp, out, read = PRICES[model]
    one_hour = CACHE_WRITE_5M if flat_writes else CACHE_WRITE_1H
    return (tok["input"] * inp
            + tok["write_5m"] * CACHE_WRITE_5M * inp
            + tok["write_1h"] * one_hour * inp
            + tok["read"] * read * inp
            + tok["output"] * out) / 1e6


TOKEN_KINDS = ("input", "write_5m", "write_1h", "read", "output")


def new_tally():
    return {"calls": 0, "cost": 0.0, "repriced": 0.0, "unpriced": {},
            **{k: 0 for k in TOKEN_KINDS}}


def add_message(tally, msg, reprice, flat_writes):
    tok = tokens(msg["usage"])
    model = msg.get("model", "")
    tally["calls"] += 1
    for k in TOKEN_KINDS:
        tally[k] += tok[k]
    cost = price(tok, model, flat_writes)
    if cost is None:
        tally["unpriced"][model] = tally["unpriced"].get(model, 0) + 1
    else:
        tally["cost"] += cost
    if reprice:
        tally["repriced"] += price(tok, reprice, flat_writes)


# -------------------------------------------------------------- report

def money(x):
    return f"${x:,.2f}"


def share(x, total):
    return f"{100 * x / total:.0f}%" if total else "-"


def table(head, rows):
    out = ["| " + " | ".join(head) + " |",
           "|" + "|".join("---" for _ in head) + "|"]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


def report(run_dir, spawns, attributed, unattributed, outside, reprice,
           flat_writes, missing_dirs):
    counted = set()   # a resumed session copies earlier messages: once only
    workers = {}
    for sess, spawn, _ in sorted(attributed, key=lambda a: a[0]["start"]):
        w = workers.setdefault(spawn["id"], {
            "spawn": spawn, "sessions": 0, "prompts": 0, "models": set(),
            "efforts": set(), "tally": new_tally()})
        w["sessions"] += 1
        w["prompts"] += sess["prompts"]
        w["efforts"].update(sess["efforts"])
        for mid, msg in sess["messages"].items():
            if mid in counted:
                continue
            counted.add(mid)
            w["models"].add(msg.get("model", ""))
            add_message(w["tally"], msg, reprice, flat_writes)

    lines = [f"# Fleet cost: {os.path.basename(os.path.normpath(run_dir))}",
             "",
             f"Run: `{run_dir}`. Prices as of {PRICES_AS_OF}, per million "
             f"tokens, from {PRICES_SOURCE}.",
             "",
             "These are API-equivalent dollars: on a subscription plan the "
             "real constraint is usage limits, not dollars.",
             "The operator's lead session is excluded: it is not a fleet "
             "worker, and the manifest records no handle on its transcript.",
             ]
    if flat_writes:
        lines.append("Every cache write is priced at the 5-minute rate "
                     f"({CACHE_WRITE_5M}x input), as the 2026-09-23 baseline "
                     "in cezaar#40 was; 1-hour writes really cost "
                     f"{CACHE_WRITE_1H}x.")
    if reprice:
        lines.append(f"`on {reprice}`: the same tokens at {reprice}'s rates.")
    lines.append("")

    alt = [f"on {reprice}"] if reprice else []
    head = ["Worker", "Persona", "Model", "Effort", "Sessions", "API calls",
            "Prompts", "Input", "Cache write 5m", "Cache write 1h",
            "Cache read", "Output", "Cost"] + alt
    rows, noted = [], False
    for wid, w in sorted(workers.items(), key=lambda kv: kv[1]["spawn"]["ts"]):
        s, t = w["spawn"], w["tally"]
        model, effort = s["model"], s["effort"]
        if not model:
            model = ", ".join(sorted(w["models"])) + " *"
            noted = True
        if not effort:
            effort = (", ".join(sorted(w["efforts"])) or "?") + " *"
            noted = True
        cost = money(t["cost"]) + (" +unpriced" if t["unpriced"] else "")
        rows.append([wid, s["persona"], model, effort, w["sessions"],
                     t["calls"], w["prompts"]]
                    + [f"{t[k]:,}" for k in TOKEN_KINDS] + [cost]
                    + ([money(t["repriced"])] if reprice else []))
    never = sorted({s["id"] for s in spawns} - set(workers))
    lines += ["## Workers", "", table(head, rows), ""]
    if noted:
        lines += ["\\* not in the manifest (spawned before cezaar#41 "
                  "recorded it): what the transcripts show instead.", ""]
    if never:
        lines += ["No transcript found for: " + ", ".join(never) + ".", ""]

    total = sum(w["tally"]["cost"] for w in workers.values())
    total_alt = sum(w["tally"]["repriced"] for w in workers.values())

    def grouped(key):
        groups = {}
        for w in workers.values():
            g = groups.setdefault(key(w), {"workers": 0, "cost": 0.0,
                                           "repriced": 0.0})
            g["workers"] += 1
            g["cost"] += w["tally"]["cost"]
            g["repriced"] += w["tally"]["repriced"]
        return groups

    def totals_rows(groups, order):
        out = []
        for name in order:
            g = groups[name]
            out.append([name, g["workers"], money(g["cost"]),
                        share(g["cost"], total)]
                       + ([money(g["repriced"])] if reprice else []))
        out.append(["**total**", len(workers), f"**{money(total)}**", ""]
                   + ([f"**{money(total_alt)}**"] if reprice else []))
        return out

    personas = grouped(lambda w: w["spawn"]["persona"])
    families = grouped(lambda w: w["spawn"]["family"])
    lines += ["## By persona", "",
              table(["Persona", "Workers", "Cost", "Share"] + alt,
                    totals_rows(personas, sorted(personas))), "",
              "## By role family", "",
              table(["Family", "Workers", "Cost", "Share"] + alt,
                    totals_rows(families, [f for f in FAMILY_ORDER
                                           if f in families])), "",
              "A `reviewer` whose brief heading says JUDGE counts as a "
              "judge.", ""]

    unpriced = {}
    for wid, w in workers.items():
        for model, n in w["tally"]["unpriced"].items():
            unpriced.setdefault(model, []).append(f"{wid} ({n} calls)")
    if unpriced:
        lines += ["## Unpriced models", "",
                  "Not in the price table, so left out of every cost above "
                  "(their tokens are still counted, and repriced if asked):",
                  ""]
        lines += [f"- `{m}`: {', '.join(ws)}" for m, ws in sorted(unpriced.items())]
        lines.append("")

    lines += ["## Unattributed sessions", ""]
    if unattributed:
        rows = []
        for sess, why in sorted(unattributed, key=lambda u: u[0]["start"]):
            t = new_tally()
            for mid, msg in sess["messages"].items():
                if mid not in counted:
                    add_message(t, msg, reprice, flat_writes)
            rows.append([sess["session"], sess["cwd"],
                         sess["start"].strftime("%Y-%m-%dT%H:%M:%SZ"),
                         t["calls"], money(t["cost"]), why])
        lines += ["Started during the run in a worker's cwd, but not "
                  "provably any one worker's. Not in any total above.", "",
                  table(["Session", "cwd", "Started", "API calls", "Cost",
                         "Why"], rows), ""]
    else:
        lines += ["None.", ""]
    if outside:
        lines += [f"{outside} other session(s) in these directories started "
                  "outside the run and were ignored.", ""]
    if missing_dirs:
        lines += ["No transcript directory for: "
                  + ", ".join(f"`{d}`" for d in missing_dirs) + ".", ""]

    lines += ["## Attribution", "",
              table(["Session", "Worker", "By"],
                    [[sess["session"], spawn["id"], by]
                     for sess, spawn, by in sorted(
                         attributed, key=lambda a: a[0]["start"])]), ""]
    return "\n".join(lines)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("run")
    ap.add_argument("--reprice", metavar="MODEL",
                    help="also price the same tokens at this model's rates "
                         "(an alias or a model ID)")
    ap.add_argument("--flat-cache-writes", action="store_true",
                    help="price 1-hour cache writes at the 5-minute rate, "
                         "as cezaar#40's 2026-09-23 baseline did")
    ap.add_argument("--projects",
                    default=os.path.expanduser("~/.claude/projects"),
                    help="Claude Code's transcript root")
    args = ap.parse_args(argv)
    reprice = model_id(args.reprice) if args.reprice else None
    if reprice and reprice not in PRICES:
        cannot_run(f"--reprice {args.reprice}: not in the price table "
                   f"({', '.join(sorted(ALIASES))} or {', '.join(PRICES)})")

    run_dir = resolve_run(args.run)
    spawns = spawns_from(read_manifest(run_dir), run_dir)
    if not spawns:
        cannot_run(f"{run_dir}/manifest.jsonl records no spawn")
    sessions, missing = [], []
    for cwd in sorted({s["real_cwd"] for s in spawns}):
        name, _ = project_dir_names(cwd)
        found = sessions_for(args.projects, cwd)
        if not found and not glob.glob(
                os.path.join(args.projects, glob.escape(name) + "*")):
            missing.append(cwd)
        sessions.extend(found)
    attributed, unattributed, outside = attribute(sessions, spawns)
    print(report(run_dir, spawns, attributed, unattributed, outside,
                 reprice, args.flat_cache_writes, missing))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
