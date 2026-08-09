#!/bin/sh
# herdr-fleet.sh -- deterministic wrapper around Herdr's CLI for orchestrator ->
# worker control. Verified against herdr 0.8.0 (server protocol 19).
#
# Usage:
#   herdr-fleet.sh preflight
#   herdr-fleet.sh spawn <id> <persona-file> [--brief <file>] [--cwd <dir>]
#                        [--model <m>] [--label <text>] [--timeout <ms>]
#                        [--trust-cwd] [-- <extra claude args>...]
#   herdr-fleet.sh prompt <id> "<text>" [--wait] [--until <state>] [--timeout <ms>]
#   herdr-fleet.sh await  <id> [--timeout <seconds>]
#           exit 0  the worker's report.md is written and settled; path on stdout
#           exit 1  timed out (only reachable with --timeout)
#           exit 3  the worker is blocked -- waiting on input, not finished
#           exit 4  the worker is gone (tab closed) and left no report
#           These are a contract: an orchestrator that treats every nonzero the
#           same conflates "go look at the pane" with "it will never finish".
#   herdr-fleet.sh read   <id> [--lines <n>] [--source <visible|recent|recent-unwrapped>]
#   herdr-fleet.sh status
#   herdr-fleet.sh curate  [<id>] [--persona <file>] [--cwd <dir>] [--brief <file>]
#                          [-- <extra claude args>...]
#           spawns the one persona declaring `curates_memory: true` against a
#           brief naming this run's workers. Run it BEFORE cleanup --all.
#   herdr-fleet.sh cleanup <id> | --all
#
# v1 is kind: claude only. A persona declaring any other kind is refused rather
# than silently launched as claude -- mixed-harness support is V2.
#
# Delegation is file-based, following fleet.sh: `spawn --brief <file>` puts the
# brief at <worker cwd>/.herdr-fleet/<id>/brief.md and kicks the worker off
# against it, and `await` waits for that worker's own
# .herdr-fleet/<id>/report.md -- a completion contract the worker has to
# satisfy deliberately. Pane lifecycle state is NOT a completion signal: a
# worker that stopped to ask a question settles exactly like one that finished,
# so `herdr agent wait` alone would report "done" for a run that is waiting on a
# human. await falls back to it only for workers spawned without a brief, and
# says so when it does.
#
# State lives in ONE place per fleet: $FLEET_HOME/.herdr-fleet/manifest.jsonl.
# Export FLEET_HOME once (default: this repo); never cd-wrap calls to this
# script -- pass worker cwds as arguments instead.
#
# Three things this wrapper exists to get right, each verified by hand against
# a live server rather than assumed from the docs:
#
#   1. `herdr agent start` needs an EXISTING pane already at a shell prompt.
#      Workers therefore get a tab of their own inside one fleet workspace,
#      created here before the agent is started.
#   2. `agent start` returning interactive_ready=true is NOT the same as
#      Claude's TUI being ready for input: a prompt submitted immediately after
#      start is swallowed while the UI paints, and `agent prompt --wait` still
#      reports done. spawn therefore polls the pane for Claude's own UI markers
#      before reporting the worker ready, and refuses to report ready if they
#      never appear.
#   3. Herdr refuses an agent argument containing a newline --
#      `invalid_agent_argument: agent arguments cannot be encoded safely for the
#      target shell` -- so a persona body cannot be handed to
#      `--append-system-prompt` inline. The body is written to
#      $FLEET_HOME/.herdr-fleet/personas/<id>.txt and passed with Claude's
#      `--append-system-prompt-file` instead, which also keeps the injected
#      prompt on disk where a human can read exactly what a worker was given.
#   4. Closing something is verified against `herdr tab list`, never against the
#      close command's exit status.
#   5. A worker in a worktree of its own is started with fleet's worker
#      permissions (install/worker-permissions.json) handed to claude on the
#      command line. Writing them into the worker's tree instead does nothing:
#      a project settings file is discarded in a workspace that has not been
#      trusted, which a fresh worktree never has. A worker sharing the
#      operator's main checkout is given no such grant, and the spawn says so.
set -eu

HERDR="${HERDR_BIN:-herdr}"
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
FLEET_HOME="${FLEET_HOME:-$(CDPATH='' cd -- "$here/.." && pwd)}"
STATE="$FLEET_HOME/.herdr-fleet"
MANIFEST="$STATE/manifest.jsonl"
WS_FILE="$STATE/workspace"

# Claude's TUI, as it actually renders in a herdr pane (confirmed on 0.8.0).
CLAUDE_UI='ctx [0-9]+%|-- INSERT|for shortcuts|esc to interrupt'
# Claude asks this once per directory it has never been run in. A worker spawned
# into a fresh worktree hits it every time, and it looks exactly like a hung boot.
CLAUDE_TRUST_UI='trust the files in this folder|Yes, I trust this folder'

die() { echo "herdr-fleet: $*" >&2; exit 1; }
note() { echo "herdr-fleet: $*" >&2; }

need_python() { command -v python3 >/dev/null 2>&1 || die "python3 not found (required to read herdr's JSON)"; }

# jget <json-path...> -- read a value out of herdr's JSON on stdin.
# Missing keys print nothing and exit 0, so callers can test for emptiness.
jget() {
  need_python
  python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
node = data
for key in sys.argv[1:]:
    if isinstance(node, dict) and key in node:
        node = node[key]
    else:
        sys.exit(0)
print(node if not isinstance(node, (dict, list)) else json.dumps(node))
' "$@"
}

manifest_field() { # id field -> value (last entry for that id wins)
  [ -f "$MANIFEST" ] || return 0
  need_python
  python3 -c '
import json, sys
wanted, field = sys.argv[1], sys.argv[2]
value = ""
for line in open(sys.argv[3], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    row = json.loads(line)
    if row.get("id") == wanted:
        value = row.get(field, "")
print(value)
' "$1" "$2" "$MANIFEST"
}

manifest_ids() {
  [ -f "$MANIFEST" ] || return 0
  need_python
  python3 -c '
import json, sys
seen = []
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    row = json.loads(line)
    if row["id"] not in seen:
        seen.append(row["id"])
print("\n".join(seen))
' "$MANIFEST"
}

log_manifest() { # key=value ... -- `id` is required; every row is a full snapshot
  # key=value rather than positional: a row gained fields (brief, report) after
  # the first version shipped, and positional args silently shift when that
  # happens -- a cleanup row would have recorded its status as its cwd.
  mkdir -p "$STATE"
  need_python
  python3 -c '
import json, sys, time
row = {}
for pair in sys.argv[2:]:
    key, _, value = pair.partition("=")
    row[key] = value
if "id" not in row:
    sys.stderr.write("log_manifest: no id= given\n"); sys.exit(1)
row["ts"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
with open(sys.argv[1], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(row) + "\n")
' "$MANIFEST" "$@"
}

tab_alive() { # tab_id -- herdr's tab list is the ground truth, not a close command's exit code
  "$HERDR" tab list 2>/dev/null | python3 -c '
import json, sys
try:
    tabs = json.load(sys.stdin)["result"]["tabs"]
except Exception:
    sys.exit(1)
sys.exit(0 if any(t["tab_id"] == sys.argv[1] for t in tabs) else 1)
' "$1"
}

workspace_alive() { # workspace_id
  "$HERDR" workspace list 2>/dev/null | python3 -c '
import json, sys
try:
    spaces = json.load(sys.stdin)["result"]["workspaces"]
except Exception:
    sys.exit(1)
sys.exit(0 if any(w["workspace_id"] == sys.argv[1] for w in spaces) else 1)
' "$1"
}

file_newer_than() { # file stamp -- 0 when file's mtime is >= stamp's
  # Freshness, not existence. Reused ids are normal here (the respawn guard at
  # spawn exists for exactly that), so a report.md left by the PREVIOUS task
  # with this id would otherwise satisfy await the instant it is called, and an
  # unattended orchestrator would read the last task's result as this one's.
  need_python
  python3 -c '
import os, sys
try:
    sys.exit(0 if os.path.getmtime(sys.argv[1]) >= os.path.getmtime(sys.argv[2]) else 1)
except OSError:
    sys.exit(1)
' "$1" "$2"
}

resolved_git_dir() { # dir flag -- the physical path `git rev-parse <flag>` names
  # RESOLVED, BECAUSE THE TWO ANSWERS ARE NOT SPELLED THE SAME WAY. Standing in
  # a SUBDIRECTORY of a main checkout, git answers --git-dir with an absolute
  # path and --git-common-dir with a relative one (`../../.git`), so comparing
  # the raw strings calls the operator's own tree a worker's worktree -- which
  # is the direction that hands out restore-and-rewrite commands. Both sides go
  # through the same cd + `pwd -P` so neither relative-vs-absolute nor a
  # symlink can make two names for one directory look like two directories.
  ( CDPATH='' cd -- "$1" 2>/dev/null || exit 1
    _d=$(git rev-parse "$2" 2>/dev/null) || exit 1
    [ -n "$_d" ] || exit 1
    CDPATH='' cd -- "$_d" 2>/dev/null || exit 1
    pwd -P )
}

own_worktree() { # dir -- 0 when dir is a git worktree that is NOT the main one
  # The git dir and the common git dir are one directory in a main checkout and
  # two in a linked worktree, which is the durable way to ask "is this tree the
  # operator's, or one created for a worker?". A missing git, or a cwd that is
  # not a repository at all, answers no and costs the worker nothing it had
  # before.
  _gd=$(resolved_git_dir "$1" --git-dir) || return 1
  _cd=$(resolved_git_dir "$1" --git-common-dir) || return 1
  [ -n "$_gd" ] && [ -n "$_cd" ] && [ "$_gd" != "$_cd" ]
}

persona_body() { # persona-file -- everything after the YAML frontmatter
  awk 'NR==1 && $0=="---" {fm=1; next} fm==1 && $0=="---" {fm=2; next} fm!=1 {print}' "$1"
}

persona_field() { # persona-file key -- a scalar from the YAML frontmatter
  awk -v key="$2" '
    NR==1 && $0=="---" {fm=1; next}
    fm==1 && $0=="---" {exit}
    fm==1 {
      idx = index($0, ":")
      if (idx == 0) next
      k = substr($0, 1, idx-1); v = substr($0, idx+1)
      gsub(/^[ \t]+|[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", v)
      gsub(/^"|"$/, "", v)
      sub(/[ \t]+#.*$/, "", v)
      if (k == key) { print v; exit }
    }' "$1"
}

fleet_workspace() { # reuse this fleet's workspace, or create it
  ws=$(cat "$WS_FILE" 2>/dev/null || true)
  if [ -n "$ws" ] && workspace_alive "$ws"; then
    echo "$ws"; return 0
  fi
  ws=$("$HERDR" workspace create --label "fleet: $(basename "$FLEET_HOME")" --cwd "$FLEET_HOME" --no-focus \
        | jget result workspace workspace_id)
  [ -n "$ws" ] || die "workspace create returned no workspace_id"
  mkdir -p "$STATE"
  printf '%s\n' "$ws" > "$WS_FILE"
  note "created fleet workspace $ws"
  echo "$ws"
}

resolve_agent() { # id -> agent name, or die
  agent=$(manifest_field "$1" agent)
  [ -n "$agent" ] || die "unknown worker: $1 (nothing in $MANIFEST)"
  echo "$agent"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift || true

case "$cmd" in
  preflight)
    command -v "$HERDR" >/dev/null 2>&1 || die "herdr not found on PATH (set HERDR_BIN)"
    "$HERDR" pane list >/dev/null 2>&1 || die "herdr socket unreachable -- is the server running? (herdr status)"
    echo "ok: herdr reachable, fleet home $FLEET_HOME"
    ;;

  spawn)
    [ $# -ge 2 ] || die "spawn needs: <id> <persona-file> [options] [-- extra claude args]"
    id="$1"; persona="$2"; shift 2
    cwd="$FLEET_HOME"; model=""; label=""; timeout="60000"; trust=0; brief=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --brief)   [ $# -ge 2 ] || die "--brief needs a path"; brief="$2"; shift 2 ;;
        --cwd)     [ $# -ge 2 ] || die "--cwd needs a path";  cwd="$2"; shift 2 ;;
        --model)   [ $# -ge 2 ] || die "--model needs a value"; model="$2"; shift 2 ;;
        --label)   [ $# -ge 2 ] || die "--label needs a value"; label="$2"; shift 2 ;;
        --timeout) [ $# -ge 2 ] || die "--timeout needs ms";   timeout="$2"; shift 2 ;;
        --trust-cwd) trust=1; shift ;;
        --) shift; break ;;
        *) die "unknown spawn option: $1" ;;
      esac
    done
    [ -f "$persona" ] || die "persona file not found: $persona"
    [ -d "$cwd" ] || die "worker cwd is not a directory: $cwd"
    cwd=$(CDPATH='' cd -- "$cwd" && pwd)
    persona=$(CDPATH='' cd -- "$(dirname -- "$persona")" && pwd)/$(basename -- "$persona")

    kind=$(persona_field "$persona" kind)
    [ -n "$kind" ] || kind="claude"
    [ "$kind" = "claude" ] || die "persona $persona declares kind: $kind -- v1 supports kind: claude only"
    [ -n "$model" ] || model=$(persona_field "$persona" model)
    body=$(persona_body "$persona")
    [ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] || die "persona $persona has an empty body -- nothing to inject"
    mkdir -p "$STATE/personas"
    prompt_file="$STATE/personas/$id.txt"
    # THE SHARED PROTOCOL GOES AHEAD OF THE PERSONA BODY, and its absence costs
    # ITSELF and never the body. memory-protocol.md is the one copy of a block
    # that used to be pasted into all six personas -- which is how a paragraph
    # true of five roles reached the sixth where it was false. Composing it here
    # means a persona anyone writes later gets memory by existing rather than by
    # remembering to copy 31 lines.
    #
    # The body is written first and unconditionally: a worker that silently
    # loses its persona because a shared file went missing is a far worse
    # failure than one that loses the protocol, and it would look like a working
    # spawn. Same shape as the template guard that took memory down with it.
    #
    # CURATION COMPOSES ON A FLAG, AND ONLY FOR ITS CARRIER. Every line of a
    # shared surface is paid for by every worker on every spawn, and a builder
    # can never act on a curation duty -- so the duties live in their own file
    # and reach exactly the persona whose frontmatter claims them. The flag is
    # the same field check_personas.py asserts exactly one team member carries;
    # this composition and that check read one field, not two conventions.
    _proto="$here/../memory-protocol.md"
    _curation="$here/../memory-curation.md"
    if [ -f "$_proto" ]; then
      { cat "$_proto"; printf '\n---\n\n'; printf '%s\n' "$body"; } > "$prompt_file"
    else
      printf '%s\n' "$body" > "$prompt_file"
      note "no $_proto -- worker $id gets its persona but no memory protocol"
    fi
    if [ "$(persona_field "$persona" curates_memory)" = "true" ]; then
      if [ -f "$_curation" ]; then
        # Ahead of both, for the same reason the protocol leads: the persona
        # body is the half that must never be lost, so it is written first and
        # everything else is prepended to a file that already has it.
        { cat "$_curation"; printf '\n---\n\n'; cat "$prompt_file"; } > "$prompt_file.tmp" \
          && mv "$prompt_file.tmp" "$prompt_file"
      else
        # Loud, because this one fails silently in the worst way: the curator
        # spawns, looks right, and edits nobody's index.
        note "no $_curation -- $id declares curates_memory but gets NO curation duties"
      fi
    fi

    # WORKER PERMISSIONS ARRIVE ON THE COMMAND LINE, NOT IN THE WORKER'S TREE.
    # The obvious alternative -- write $cwd/.claude/settings.json -- is inert
    # exactly where it is needed: Claude Code discards a project settings file
    # wholesale in a workspace that has not been through the trust dialog
    # ("Ignoring 1 permissions.allow entry ... this workspace has not been
    # trusted"), and a worktree created for a worker never has. That is the same
    # dialog --trust-cwd exists for. `--settings` is honoured there, measured.
    # It also leaves the worker's tree untouched, so nothing new shows up in the
    # `git status --porcelain` the reviewer persona must see come back empty.
    #
    # ONLY IN A TREE THE WORKER OWNS. The grants are restore-and-rewrite
    # commands; a linked worktree is the worker's, a main checkout is the
    # operator's, and reviewer.md's first rule is never to mutate the latter.
    # A worker that shares the main checkout gets no grant and says so.
    #
    # THE GRANT IS COMPOSED, NOT A STATIC FILE. A worker's memory lives at
    # $FLEET_HOME/memory/<persona>/, and a worker spawned into another repo
    # reaches it by an absolute path out of its own tree -- the boundary this
    # script's own delegation state avoids crossing (see the brief staging
    # below). Without a directory grant the READ is denied, and a denied read
    # is indistinguishable from an absent file: the worker concludes it has no
    # memory, forever, on every machine but one that ran the installer.
    # Only the installer knew the fleet home before; spawn knows it too, so it
    # composes it in. Both spellings, because a symlinked fleet home resolves
    # to a different string and a grant is matched against the one used.
    # TWO INDEPENDENT GRANTS IN ONE FILE, AND ONLY ONE IS CONDITIONAL.
    #   directories  so the worker can READ ITS MEMORY at $FLEET_HOME/memory/,
    #                outside its cwd and therefore denied by default. A denied
    #                read is indistinguishable from an empty one, so the worker
    #                concludes it has no memory, forever. Never withheld.
    #   allow        restore-and-rewrite, withheld from a tree the worker does
    #                not own -- reviewer.md's first rule.
    # Composed ALWAYS, never conditioned on either input: gating the whole file
    # on own_worktree took memory down with the sharp tools (Mordecai), and
    # gating it on the template's existence would take memory down with a
    # missing file (Mordecai again, one level up). A missing template means an
    # empty allow list, not an absent settings file.
    if own_worktree "$cwd"; then
      _sharp=1
    else
      _sharp=0
      note "$cwd is not a worktree of its own -- worker $id gets no mutation grants (memory is still granted)"
    fi
    _tmpl="$here/../install/worker-permissions.json"
    [ -f "$_tmpl" ] || note "no $_tmpl -- worker $id gets memory but no command grants"
    mkdir -p "$STATE/permissions"
    worker_settings="$STATE/permissions/$id.json"
    need_python
    python3 -c '
import json, os, sys
tmpl, out, home, sharp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
try:
    data = json.load(open(tmpl, encoding="utf-8"))
except (OSError, ValueError):
    data = {}
perms = data.setdefault("permissions", {})
if not sharp or not isinstance(perms.get("allow"), list):
    perms["allow"] = [] if not sharp else perms.get("allow") or []
dirs = perms.setdefault("additionalDirectories", [])
for spelling in (home, os.path.realpath(home)):
    if spelling not in dirs:
        dirs.append(spelling)
with open(out, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
' "$_tmpl" "$worker_settings" "$FLEET_HOME" "$_sharp" \
      || die "could not compose worker permissions for $id"

    # DELEGATION STATE lives in the worker's own cwd, so every path inside a
    # brief can be relative to it -- an absolute path into another tree crosses
    # the worker's permission boundary and stalls the run on a prompt nobody is
    # watching.
    worker_state="$cwd/.herdr-fleet/$id"
    report_file="$worker_state/report.md"
    stamp_file="$STATE/$id.spawn-stamp"
    if [ -n "$brief" ]; then
      [ -f "$brief" ] || die "brief file not found: $brief"
      brief=$(CDPATH='' cd -- "$(dirname -- "$brief")" && pwd)/$(basename -- "$brief")
      mkdir -p "$worker_state"
      brief_dest="$worker_state/brief.md"
      # The brief may ALREADY be at the destination when the caller wrote it
      # straight there; copying a file onto itself fails and would abort the
      # spawn under set -e.
      [ "$brief" = "$brief_dest" ] || cp "$brief" "$brief_dest"
      # PREMATURE-AWAIT GUARD: a report.md from an earlier attempt with this id
      # makes a file-first await return the instant it is called. Archive it,
      # and stamp this attempt so await can also reject anything older.
      if [ -f "$report_file" ]; then
        stale="$worker_state/report.stale-$(date -u +%Y%m%d-%H%M%S).md"
        mv "$report_file" "$stale"
        note "archived a stale report for $id -> $(basename "$stale")"
      fi
    fi
    : > "$stamp_file"

    # RESPAWN GUARD: reusing an id would strand the previous worker's tab, and
    # manifest lookups only ever resolve the LAST entry, so it could never be
    # closed again. Retire it first.
    old_tab=$(manifest_field "$id" tab_id)
    if [ -n "$old_tab" ] && tab_alive "$old_tab"; then
      "$HERDR" tab close "$old_tab" >/dev/null 2>&1 || true
      if tab_alive "$old_tab"; then
        note "warn: could not retire previous tab $old_tab for $id -- it will be orphaned"
      else
        note "retired previous tab $old_tab before respawning $id"
      fi
    fi

    ws=$(fleet_workspace)
    pane=$("$HERDR" tab create --workspace "$ws" --label "${label:-$id}" --cwd "$cwd" --no-focus \
            | jget result root_pane pane_id)
    [ -n "$pane" ] || die "tab create returned no pane_id"
    tab=$("$HERDR" pane get "$pane" | jget result pane tab_id)

    set -- "$@"
    if [ -n "$model" ]; then
      set -- --model "$model" "$@"
    fi
    # Prepended, so a caller who passes their own --settings after `--` is the
    # later of the two rather than fighting this one for position.
    if [ -n "$worker_settings" ]; then
      set -- --settings "$worker_settings" "$@"
    fi
    # A tab's shell is not ready the instant `tab create` returns: starting an
    # agent too early fails with agent_pane_busy ("not an available shell").
    # That one error is transient, so it is retried; anything else is real.
    # On a real failure the tab this spawn just created is retired, otherwise
    # every failed start leaves an empty pane behind -- and since herdr's agent
    # names are server-global, the usual failure (agent_name_taken) would then
    # repeat forever.
    attempt=0; started=""; start_ok=0
    while [ "$attempt" -lt 15 ]; do
      if started=$("$HERDR" agent start "$id" --kind claude --pane "$pane" --timeout "$timeout" \
                     -- --append-system-prompt-file "$prompt_file" "$@" 2>&1); then
        start_ok=1; break
      fi
      case "$started" in
        *agent_pane_busy*) sleep 1; attempt=$((attempt + 1)) ;;
        *) break ;;
      esac
    done
    if [ "$start_ok" -ne 1 ]; then
      note "agent start failed for $id (pane $pane): $started"
      "$HERDR" tab close "$tab" >/dev/null 2>&1 || true
      die "spawn aborted; the tab created for $id was closed again"
    fi
    agent=$(printf '%s' "$started" | jget result agent name)
    [ -n "$agent" ] || agent="$id"

    # BOOT VERIFY: interactive_ready is the shell handing over to claude, not
    # claude's TUI being ready. A prompt sent before the UI paints is swallowed,
    # and --wait still reports done -- so wait for Claude's own markers here
    # instead of letting the first brief disappear.
    i=0; ready=0
    boot_wait="${FLEET_BOOT_TIMEOUT:-90}"   # seconds; a cold claude start is slower than it looks
    while [ "$i" -lt "$boot_wait" ]; do
      screen=$("$HERDR" agent read "$agent" --source visible --lines 40 --format text 2>/dev/null || true)
      if printf '%s' "$screen" | grep -qE "$CLAUDE_UI"; then
        ready=1; break
      fi
      if printf '%s' "$screen" | grep -qE "$CLAUDE_TRUST_UI"; then
        # Trusting a directory is the operator's call, so it is opt-in. Without
        # --trust-cwd this is reported as what it is rather than waited out.
        if [ "$trust" -eq 1 ]; then
          "$HERDR" agent send-keys "$agent" enter >/dev/null 2>&1 || true
          note "accepted Claude's trust prompt for $cwd (--trust-cwd)"
        else
          blocked=1; break
        fi
      fi
      sleep 1; i=$((i + 1))
    done

    # THE MANIFEST ROW IS THE ONLY HANDLE ON A STARTED AGENT. It is written
    # before any failure exit below, because at this point `agent start` has
    # already succeeded: the agent exists server-side, its tab is open, and
    # herdr's agent names are server-global. Exiting without recording it makes
    # the worker invisible to `status` and unreachable by `cleanup`, and burns
    # the id -- the next spawn gets agent_name_taken forever. The tab is
    # deliberately left open on both failure paths, since both tell the
    # operator to go look at it.
    status_row=unverified
    [ "$ready" -eq 1 ] && status_row=ready
    [ "${blocked:-0}" -eq 1 ] && status_row=blocked-on-trust
    log_manifest id="$id" agent="$agent" pane_id="$pane" tab_id="$tab" \
      workspace_id="$ws" persona="$persona" cwd="$cwd" brief="${brief:-}" \
      report="${report_file:-}" stamp="${stamp_file:-}" \
      settings="${worker_settings:-}" status="$status_row"

    if [ "${blocked:-0}" -eq 1 ]; then
      note "worker $id is waiting on Claude's trust-folder prompt for $cwd"
      note "recorded as $status_row -- '$0 status' can see it and '$0 cleanup $id' can close it"
      die "spawn blocked: approve the prompt in pane $pane, then '$0 prompt $id ...'; or '$0 cleanup $id' and respawn with --trust-cwd"
    fi
    if [ "$ready" -ne 1 ]; then
      note "last ${boot_wait}s of pane $pane:"
      "$HERDR" agent read "$agent" --source visible --lines 12 --format text 2>&1 | sed 's/^/    /' >&2 || true
      die "spawned $id (pane $pane) but Claude's UI never appeared within ${boot_wait}s -- do not prompt it blind (raise FLEET_BOOT_TIMEOUT, or look at the pane above)"
    fi

    echo "spawned $id -> agent $agent, pane $pane, tab $tab, workspace $ws"
    if [ -n "$brief" ]; then
      # Kick off against the file, not the pane. Short and quote-free on
      # purpose: the contract lives in the brief, not in this line.
      "$HERDR" agent prompt "$agent" \
        "Read .herdr-fleet/$id/brief.md and execute it exactly, including its completion contract." \
        >/dev/null || die "worker $id started but the kickoff prompt failed; brief is at $worker_state/brief.md"
      echo "briefed $id -> $worker_state/brief.md (report expected at $report_file)"
    fi
    ;;

  prompt|steer)
    [ $# -ge 2 ] || die "prompt needs: <id> \"<text>\" [--wait] [--until <state>] [--timeout <ms>]"
    id="$1"; text="$2"; shift 2
    agent=$(resolve_agent "$id")
    "$HERDR" agent prompt "$agent" "$text" "$@"
    ;;

  await)
    [ $# -ge 1 ] || die "await needs: <id> [--timeout <seconds>]"
    id="$1"; shift
    agent=$(resolve_agent "$id")
    report=$(manifest_field "$id" report)
    stamp=$(manifest_field "$id" stamp)
    tab=$(manifest_field "$id" tab_id)
    wait_secs=0   # 0 = wait indefinitely
    while [ $# -gt 0 ]; do
      case "$1" in
        --timeout) [ $# -ge 2 ] || die "--timeout needs seconds"; wait_secs="$2"; shift 2 ;;
        *) die "unknown await option: $1 (await takes --timeout <seconds>)" ;;
      esac
    done

    if [ -z "$report" ] || [ -z "$(manifest_field "$id" brief)" ]; then
      # No brief means no completion contract to wait on. Fall back to pane
      # lifecycle state and SAY SO -- `agent wait` settles on `blocked` too, so
      # a worker that stopped to ask a question looks exactly like one that
      # finished, and an orchestrator that cannot tell those apart is not
      # running unattended, it is only pretending to.
      note "worker $id was spawned without --brief: no report contract, falling back to herdr agent wait (settles on blocked as well as done)"
      if [ "$wait_secs" -gt 0 ]; then
        exec "$HERDR" agent wait "$agent" --timeout "$((wait_secs * 1000))"
      fi
      exec "$HERDR" agent wait "$agent"
    fi

    waited=0; prev_size=""
    while : ; do
      if [ -f "$report" ] && { [ -z "$stamp" ] || file_newer_than "$report" "$stamp"; }; then
        size=$(wc -c < "$report" | tr -d ' ')
        # Two consecutive polls at the same size: cheap insurance against
        # reading a report mid-write. Costs one poll interval, and only after
        # the report already exists.
        if [ -n "$prev_size" ] && [ "$size" = "$prev_size" ]; then
          echo "$report"
          exit 0
        fi
        prev_size="$size"
      else
        prev_size=""
      fi
      # A WORKER THAT NO LONGER EXISTS never satisfies this await. Its agent is
      # gone from herdr, so `agent get` returns nothing and `state` is empty --
      # which is not `blocked`, so without this the default (indefinite) wait
      # spins forever on something that cannot finish. That is worse than the
      # blocked case it sits next to: a blocked worker at least has a human who
      # can unblock it. The tab list is the ground truth, same as everywhere else.
      if [ -n "$tab" ] && ! tab_alive "$tab"; then
        # It may have finished and been cleaned up between polls -- a report
        # from a dead worker cannot still be growing, so one check is enough.
        if [ -f "$report" ] && { [ -z "$stamp" ] || file_newer_than "$report" "$stamp"; }; then
          echo "$report"
          exit 0
        fi
        note "worker $id is gone (tab $tab is closed) and left no report -- nothing will ever satisfy this await"
        exit 4
      fi
      state=$("$HERDR" agent get "$agent" 2>/dev/null | jget result agent agent_status)
      if [ "$state" = "blocked" ]; then
        note "worker $id is blocked with no report yet -- it is waiting on input, not finished"
        "$HERDR" agent read "$agent" --source visible --lines 12 --format text 2>&1 | sed 's/^/    /' >&2 || true
        exit 3
      fi
      if [ "$wait_secs" -gt 0 ] && [ "$waited" -ge "$wait_secs" ]; then
        note "timed out after ${wait_secs}s waiting for $report (agent state: ${state:-unknown})"
        exit 1
      fi
      sleep 2; waited=$((waited + 2))
    done
    ;;

  read)
    [ $# -ge 1 ] || die "read needs: <id> [--lines <n>] [--source <source>]"
    id="$1"; shift
    agent=$(resolve_agent "$id")
    if [ $# -eq 0 ]; then
      set -- --source visible --lines 40 --format text
    fi
    "$HERDR" agent read "$agent" "$@"
    ;;

  status)
    ids=$(manifest_ids)
    [ -n "$ids" ] || { echo "no workers recorded in $MANIFEST"; exit 0; }
    printf '%-16s %-16s %-8s %-10s %s\n' ID STATUS REPORT TAB CWD
    for id in $ids; do
      agent=$(manifest_field "$id" agent)
      tab=$(manifest_field "$id" tab_id)
      cwd=$(manifest_field "$id" cwd)
      report=$(manifest_field "$id" report)
      stamp=$(manifest_field "$id" stamp)
      if tab_alive "$tab"; then
        st=$("$HERDR" agent get "$agent" 2>/dev/null | jget result agent agent_status)
        [ -n "$st" ] || st="no-agent"
        # A row recorded as blocked-on-trust never reached a usable agent, so
        # herdr's own status for it means nothing -- keep the recorded one.
        recorded=$(manifest_field "$id" status)
        [ "$recorded" = "blocked-on-trust" ] && st="$recorded"
      else
        st="gone"
      fi
      # Same freshness rule await uses: a report from a previous task with this
      # id is not this task's report.
      if [ -z "$report" ] || [ -z "$(manifest_field "$id" brief)" ]; then
        rp="n/a"
      elif [ -f "$report" ] && { [ -z "$stamp" ] || file_newer_than "$report" "$stamp"; }; then
        rp="yes"
      else
        rp="no"
      fi
      printf '%-16s %-16s %-8s %-10s %s\n' "$id" "$st" "$rp" "$tab" "$cwd"
    done
    ;;

  curate)
    # CLOSE-OF-RUN CURATION IS ITS OWN VERB, NOT A LIMB OF `cleanup --all`.
    # Teardown that also spawns is the defect this wrapper has now been bitten
    # by twice (a worktree gate that swept up memory grants; a template guard
    # that took memory down with it) -- two jobs in one branch means one of
    # them fails in the other's shadow. `cleanup --all` is also the abort path,
    # and curating a run that was killed halfway would promote lessons from
    # work nobody finished. So: separate verb, and cleanup NOTES when it runs
    # with no curation recorded, which keeps forgetting visible without making
    # teardown responsible for remembering.
    id="curator"; cwd=$PWD; brief=""; set_persona=""
    [ $# -gt 0 ] && case "$1" in -*) ;; *) id="$1"; shift ;; esac
    while [ $# -gt 0 ]; do
      case "$1" in
        --persona) set_persona="$2"; shift 2 ;;
        --cwd)     cwd="$2"; shift 2 ;;
        --brief)   brief="$2"; shift 2 ;;
        --)        shift; break ;;
        *) die "unknown curate option: $1" ;;
      esac
    done

    # WHICH PERSONA CURATES IS READ, NEVER ASSUMED. A missing or duplicated
    # flag is refused here rather than resolved by picking one: two sessions
    # editing one index is precisely what the single-writer rule forbids, and
    # a wrapper that guesses would make the check that enforces it decorative.
    if [ -n "$set_persona" ]; then
      persona="$set_persona"
      [ -f "$persona" ] || die "persona file not found: $persona"
      [ "$(persona_field "$persona" curates_memory)" = "true" ] \
        || die "$persona does not declare curates_memory: true -- it would spawn with no curation duties"
    else
      # Counted WITHOUT touching $@ -- the extra claude args after `--` are
      # sitting in there, and `set -- $carriers` would hand a persona path to
      # claude as a flag while losing the caller's arguments entirely.
      carriers=""; n_carriers=0; persona=""
      for f in "$here"/../agents/*.md; do
        [ -f "$f" ] || continue
        if [ "$(persona_field "$f" curates_memory)" = "true" ]; then
          persona="$f"; n_carriers=$((n_carriers + 1)); carriers="$carriers
  $f"
        fi
      done
      [ "$n_carriers" -eq 1 ] \
        || die "expected exactly 1 persona under $here/../agents declaring curates_memory: true, found $n_carriers${carriers}"
    fi

    # The brief names where the logs are, because the curator arrives with no
    # context by design and cannot infer a run it did not see.
    if [ -z "$brief" ]; then
      brief="$STATE/curation-brief.md"
      mkdir -p "$STATE"
      {
        echo "# Curation pass"
        echo
        echo "Curate the memory of the run below. Read each worker's"
        echo "\`memory/<persona>/decisions.md\`, promote/merge/prune its persona"
        echo "index, and report what you promoted, merged, removed, and what you"
        echo "deliberately left in the logs."
        echo
        echo "## Workers in this run"
        echo
        if [ -n "$(manifest_ids)" ]; then
          for w in $(manifest_ids); do
            printf -- '- %s (%s) -- cwd %s\n' "$w" "$(manifest_field "$w" persona)" "$(manifest_field "$w" cwd)"
          done
        else
          echo "- (none recorded in $MANIFEST -- say so in your report rather than"
          echo "  curating from an empty set)"
        fi
      } > "$brief"
      note "wrote curation brief $brief"
    fi
    [ -f "$brief" ] || die "brief not found: $brief"

    # `--` is re-supplied because this parser consumed the caller's: without
    # it spawn reads the extras as its OWN options and dies on the first one.
    if [ $# -gt 0 ]; then
      "$0" spawn "$id" "$persona" --brief "$brief" --cwd "$cwd" -- "$@" || exit $?
    else
      "$0" spawn "$id" "$persona" --brief "$brief" --cwd "$cwd" || exit $?
    fi
    # Recorded only after the spawn succeeded, so cleanup's note tells the
    # truth about whether a pass actually started.
    mkdir -p "$STATE"; date >"$STATE/last-curation"
    ;;

  cleanup)
    [ $# -ge 1 ] || die "cleanup needs: <id> | --all"
    failed=0
    if [ "$1" = "--all" ]; then targets=$(manifest_ids); else targets="$1"; fi
    for id in $targets; do
      tab=$(manifest_field "$id" tab_id)
      [ -n "$tab" ] || { note "no tab recorded for $id"; continue; }
      if ! tab_alive "$tab"; then echo "already gone: $id ($tab)"; continue; fi
      "$HERDR" tab close "$tab" >/dev/null 2>&1 || true
      j=0
      while tab_alive "$tab" && [ "$j" -lt 6 ]; do sleep 0.5; j=$((j + 1)); done
      if tab_alive "$tab"; then
        echo "FAILED to close $id ($tab)" >&2; failed=1
      else
        echo "closed $id ($tab)"
        log_manifest id="$id" agent="$(manifest_field "$id" agent)" \
                     pane_id="$(manifest_field "$id" pane_id)" tab_id="$tab" \
                     workspace_id="$(manifest_field "$id" workspace_id)" \
                     persona="$(manifest_field "$id" persona)" \
                     cwd="$(manifest_field "$id" cwd)" \
                     brief="$(manifest_field "$id" brief)" \
                     report="$(manifest_field "$id" report)" \
                     stamp="$(manifest_field "$id" stamp)" \
                     settings="$(manifest_field "$id" settings)" status=cleaned
      fi
    done
    if [ "${1:-}" = "--all" ]; then
      # Teardown does not curate -- but it is the last moment anyone would
      # notice that nothing did.
      [ -f "$STATE/last-curation" ] \
        || note "no curation pass recorded for this fleet -- '$0 curate' promotes this run's lessons; tearing down now loses them"
      ws=$(cat "$WS_FILE" 2>/dev/null || true)
      if [ -n "$ws" ] && workspace_alive "$ws"; then
        "$HERDR" workspace close "$ws" >/dev/null 2>&1 || true
        if workspace_alive "$ws"; then
          echo "FAILED to close fleet workspace $ws" >&2; failed=1
        else
          echo "closed fleet workspace $ws"; rm -f "$WS_FILE"
        fi
      fi
    fi
    exit "$failed"
    ;;

  ""|-h|--help|help)
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    die "unknown command: $cmd (try --help)"
    ;;
esac
