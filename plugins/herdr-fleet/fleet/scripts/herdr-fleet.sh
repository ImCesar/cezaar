#!/bin/sh
# herdr-fleet.sh -- deterministic wrapper around Herdr's CLI for orchestrator ->
# worker control. Verified against herdr 0.8.0 (server protocol 19).
#
# Usage:
#   herdr-fleet.sh preflight
#   herdr-fleet.sh spawn <id> <persona-file> [--brief <file>] [--cwd <dir>]
#                        [--model <m>] [--label <text>] [--timeout <ms>]
#                        [--trust-cwd] [--no-peers] [--own-tab] [-- <extra claude args>...]
#   herdr-fleet.sh assign <id> --brief <file>
#           re-tasks an idle worker in place instead of respawning it -- same
#           premature-await guard as spawn (stage_brief). Refuses, with no way
#           to override, if the worker is `working`, or if its tab is gone
#           ("gone -- spawn instead").
#   herdr-fleet.sh prompt <id> "<text>" [--wait] [--until <state>] [--timeout <ms>]
#   herdr-fleet.sh tell   <from-id> <to-id-or-persona> "<text>"
#           delivers a peer message between two workers whose personas share a
#           declared edge in the team file (teams/default.md's `peers:`, or
#           $FLEET_TEAM) -- refused otherwise.
#   herdr-fleet.sh await  <id> [--timeout <seconds>]
#           exit 0  the worker's report.md is written and settled; path on stdout
#           exit 1  timed out (only reachable with --timeout)
#           exit 3  the worker is blocked -- waiting on input, not finished
#           exit 4  the worker is gone (its pane/tab is gone) and left no report
#           These are a contract: an orchestrator that treats every nonzero the
#           same conflates "go look at the pane" with "it will never finish".
#   herdr-fleet.sh read   <id> [--lines <n>] [--source <visible|recent|recent-unwrapped>]
#   herdr-fleet.sh status
#           worker rows, including a CTX column parsed from the pane (see
#           CLAUDE_UI below); reads `?` when the marker is not visible.
#   herdr-fleet.sh curate  [<id>] [--persona <file>] [--cwd <dir>] [--brief <file>]
#                          [-- <extra claude args>...]
#           spawns the one persona declaring `curates_memory: true` against a
#           brief naming this run's workers. Run it BEFORE cleanup --all.
#   herdr-fleet.sh cleanup <id> | --all
#
# v1 is kind: claude only. A persona declaring any other kind is refused rather
# than silently launched as claude -- mixed-harness support is V2.
#
# Delegation is file-based: `spawn --brief <file>` puts the brief at
# $FLEET_HOME/.herdr-fleet/workers/<id>/brief.md and kicks the worker off
# against it by absolute path, and `await` waits for that worker's own
# $FLEET_HOME/.herdr-fleet/workers/<id>/report.md -- a completion contract the
# worker has to satisfy deliberately. Pane lifecycle state is NOT a completion
# signal: a worker that stopped to ask a question settles exactly like one that
# finished, so `herdr agent wait` alone would report "done" for a run that is
# waiting on a human. await falls back to it only for workers spawned without a
# brief, and says so when it does.
#
# State lives in ONE place per fleet: $FLEET_HOME/.herdr-fleet/ -- the
# manifest, every worker's brief/report/scratch under workers/<id>/, personas,
# permissions. Export FLEET_HOME once (default: this repo); never cd-wrap
# calls to this script -- pass worker cwds as arguments instead.
#
# Three things this wrapper exists to get right, each verified by hand against
# a live server rather than assumed from the docs:
#
#   1. `herdr agent start` needs an EXISTING pane already at a shell prompt.
#      Workers therefore get a pane inside one fleet workspace, created here
#      before the agent is started -- packed into 2x2 grid tabs rather than
#      one tab per worker (see item 7 below).
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
#   6. The fleet workspace is ADOPTED, not always created: if $HERDR_WORKSPACE_ID
#      is set (the wrapper is already running inside a Herdr pane), spawn
#      renames that workspace instead of opening a new one, and puts workers in
#      tabs of it. `cleanup --all` restores the pre-adoption label and NEVER
#      closes an adopted workspace -- closing it would kill the pane the
#      wrapper itself is running in, mid-teardown.
#   7. Workers pack into 2x2 grid tabs (`fleet grid <n>`), four to a tab,
#      instead of one tab per worker. `cleanup <id>` therefore closes the
#      worker's PANE, and the tab only when no other live worker still shares
#      it. An entry persona (`escalation_authority: orchestrator`) or any
#      `--own-tab` spawn gets a full-size tab of its own instead of a grid
#      slot.
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

worker_alive() { # id -- 0 (true) iff the worker itself is still there
  # Since D, a worker's PANE is what identifies it -- a grid tab holds up to
  # four workers and outlives whichever of them gets cleaned up first, so
  # tab_alive alone answers "is the tab still open", not "is this worker still
  # here". This is the one worker-liveness predicate the wrapper has: pane get
  # on the manifest row's recorded pane_id when there is one, falling back to
  # tab_alive for rows with no pane recorded (pre-D manifest rows, or any
  # future row that legitimately has none). Every place that used to ask
  # tab_alive "is this worker gone" -- assign's gone-guard, tell's live-carrier
  # scan, await's exit-4 branch, status -- asks this instead, so the answer
  # agrees everywhere it is used.
  _waid="$1"
  _wapane=$(manifest_field "$_waid" pane_id)
  if [ -n "$_wapane" ]; then
    "$HERDR" pane get "$_wapane" >/dev/null 2>&1
  else
    _watab=$(manifest_field "$_waid" tab_id)
    [ -n "$_watab" ] && tab_alive "$_watab"
  fi
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

fleet_workspace() { # reuse this fleet's workspace, adopt the current one, or create it
  ws=$(cat "$WS_FILE" 2>/dev/null || true)
  if [ -n "$ws" ] && workspace_alive "$ws"; then
    echo "$ws"; return 0
  fi
  # ADOPT: if HERDR_WORKSPACE_ID is set, this wrapper is itself running inside
  # a Herdr pane -- put workers in tabs of THAT workspace rather than opening a
  # new one. The pre-adoption label is recorded so cleanup --all can put it
  # back; the marker is what tells cleanup this workspace must never be
  # closed, only renamed back (closing it would kill the pane the wrapper is
  # running in, mid-teardown -- the binding constraint this feature exists
  # around).
  if [ -n "${HERDR_WORKSPACE_ID:-}" ]; then
    ws="$HERDR_WORKSPACE_ID"
    label_before=$("$HERDR" workspace get "$ws" | jget result workspace label)
    mkdir -p "$STATE"
    printf '%s\n' "$label_before" > "$STATE/workspace.label-before"
    "$HERDR" workspace rename "$ws" "fleet: $(basename "$FLEET_HOME")" >/dev/null \
      || die "could not rename adopted workspace $ws"
    printf '%s\n' "$ws" > "$WS_FILE"
    : > "$STATE/workspace.adopted"
    note "adopted workspace $ws (was \"$label_before\")"
    echo "$ws"
    return 0
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

stage_brief() { # id brief-src -> stages brief-src at $STATE/workers/<id>/brief.md,
  # archives any stale report.md, and refreshes the spawn stamp. EXACTLY the
  # premature-await guard spawn already ran (a report.md from an earlier
  # attempt with this id would satisfy a file-first await the instant it is
  # called), factored here so spawn and assign cannot drift on the freshness
  # contract await depends on. Prints the resolved absolute brief-src path.
  _sid="$1"; _sbrief="$2"
  [ -f "$_sbrief" ] || die "brief file not found: $_sbrief"
  _sbrief=$(CDPATH='' cd -- "$(dirname -- "$_sbrief")" && pwd)/$(basename -- "$_sbrief")
  _sws="$STATE/workers/$_sid"
  _sreport="$_sws/report.md"
  mkdir -p "$_sws"
  _sdest="$_sws/brief.md"
  [ "$_sbrief" = "$_sdest" ] || cp "$_sbrief" "$_sdest"
  if [ -f "$_sreport" ]; then
    _sstale="$_sws/report.stale-$(date -u +%Y%m%d-%H%M%S).md"
    mv "$_sreport" "$_sstale"
    note "archived a stale report for $_sid -> $(basename "$_sstale")"
  fi
  : > "$STATE/$_sid.spawn-stamp"
  printf '%s\n' "$_sbrief"
}

worker_ctx() { # agent -> "NN%" parsed from the pane's visible ctx marker, or "?"
  # `ctx [0-9]+%` is Claude-TUI's own context-remaining readout, not Herdr's --
  # the same marker CLAUDE_UI already greps for at boot. Claude-TUI fact,
  # checked: 2026-08-12 against a live 0.8.0 pane. If the marker is ever gone
  # (a Claude UI change) this reads "?" rather than breaking `status`.
  # `|| true` on the pipeline itself, not just the herdr call: under this
  # script's set -e, a `var=$(pipeline)` whose LAST stage is a no-match grep
  # exits nonzero and takes the whole script down with it -- measured against
  # this repo's own /bin/sh, which enforces that POSIX rule strictly. That is
  # precisely the "marker absent" case this function must degrade through, not
  # die on.
  _screen=$("$HERDR" agent read "$1" --source visible --lines 40 --format text 2>/dev/null || true)
  _ctx=$(printf '%s' "$_screen" | grep -oE 'ctx [0-9]+%' | tail -1 | grep -oE '[0-9]+%' || true)
  [ -n "$_ctx" ] && printf '%s\n' "$_ctx" || printf '?\n'
}

team_peers() { # -> "personaA personaB" per declared edge, one per line, sorted
  # A small awk parser over the team file's `peers:` frontmatter block --
  # nothing more elaborate is needed for a handful of `- [a, b]` lines.
  # Defaults to $FLEET_HOME/teams/default.md; FLEET_TEAM overrides.
  _team="${FLEET_TEAM:-$FLEET_HOME/teams/default.md}"
  [ -f "$_team" ] || return 0
  awk '
    NR==1 && $0=="---" {fm=1; next}
    fm==1 && $0=="---" {exit}
    fm!=1 {next}
    /^peers:/ {inpeers=1; next}
    inpeers && $0 !~ /^[ \t]*(-|#|$)/ {inpeers=0}
    inpeers && /^[ \t]*-[ \t]*\[/ {
      line=$0
      sub(/^[ \t]*-[ \t]*\[/, "", line)
      sub(/\].*$/, "", line)
      n=split(line, parts, ",")
      if (n == 2) {
        a=parts[1]; b=parts[2]
        gsub(/^[ \t]+|[ \t]+$/, "", a); gsub(/^[ \t]+|[ \t]+$/, "", b)
        if (a > b) { t=a; a=b; b=t }
        if (a != "" && b != "") print a" "b
      }
    }
  ' "$_team"
}

peers_declared() { # persona1 persona2 -> 0 if the pair is a declared edge (unordered)
  _pair=$(printf '%s\n%s\n' "$1" "$2" | sort | tr '\n' ' ')
  _pair=${_pair% }
  team_peers | grep -qxF -- "$_pair"
}

persona_peers() { # persona-name -> the other persona of each edge touching it, one per line
  team_peers | awk -v p="$1" '$1==p{print $2} $2==p{print $1}'
}

# GRID SLOT ALLOCATION (D). $STATE/grid holds one line -- "tab_id p0 p1 n" --
# for the currently-filling 2x2 grid tab; p1 is "-" until slot 2 exists. Slots
# are taken in order (tab create, then three splits) and never backfilled: a
# freed slot just leaves a sparse grid, which is cheaper than the geometry math
# backfill would need, and reuse (assign, elsewhere) makes churn rare anyway.
grid_slot() { # ws cwd -> "pane_id tab_id" for the next worker's slot
  ws="$1"; g_cwd="$2"
  grid_file="$STATE/grid"
  g_tab=""; g_p0=""; g_p1=""; g_n=0
  if [ -s "$grid_file" ]; then
    read -r g_tab g_p0 g_p1 g_n < "$grid_file" || true
  fi
  if [ -n "$g_tab" ] && [ "$g_n" -lt 4 ]; then
    # SELF-HEAL: about to split against p0 (and p1, once it exists). An
    # operator closing a pane by hand is one way this state can lie, but it is
    # not the only one any more: the respawn guard's per-worker pane close and
    # `cleanup <id>`'s pane close are two more, both routine paths that now
    # leave a grid tab's root or #2 pane closed while the tab itself stays
    # open for its other worker(s). Any miss abandons the file rather than
    # splitting against a pane that is gone, which is a fresh grid tab, not a
    # wedged spawn.
    stale=0
    "$HERDR" pane get "$g_p0" >/dev/null 2>&1 || stale=1
    if [ "$stale" -eq 0 ] && [ "$g_n" -ge 2 ]; then
      "$HERDR" pane get "$g_p1" >/dev/null 2>&1 || stale=1
    fi
    if [ "$stale" -eq 1 ]; then
      note "grid tab $g_tab desynced (a recorded pane is gone) -- abandoning it, opening a fresh grid tab"
      g_tab=""
    fi
  else
    g_tab=""   # no grid file yet, or the last one is full
  fi

  if [ -z "$g_tab" ]; then
    gnum=$(cat "$STATE/grid.next" 2>/dev/null || echo 1)
    p0=$("$HERDR" tab create --workspace "$ws" --label "fleet grid $gnum" --cwd "$g_cwd" --no-focus \
          | jget result root_pane pane_id)
    [ -n "$p0" ] || die "tab create returned no pane_id (grid $gnum)"
    g_tab=$("$HERDR" pane get "$p0" | jget result pane tab_id)
    mkdir -p "$STATE"
    printf '%s\n' "$((gnum + 1))" > "$STATE/grid.next"
    printf '%s %s - 1\n' "$g_tab" "$p0" > "$grid_file"
    echo "$p0 $g_tab"
    return 0
  fi

  case "$g_n" in
    1)
      p1=$("$HERDR" pane split "$g_p0" --direction right --ratio 0.5 --cwd "$g_cwd" --no-focus \
            | jget result pane pane_id)
      [ -n "$p1" ] || die "pane split returned no pane_id (grid slot 2)"
      printf '%s %s %s 2\n' "$g_tab" "$g_p0" "$p1" > "$grid_file"
      echo "$p1 $g_tab"
      ;;
    2)
      p2=$("$HERDR" pane split "$g_p0" --direction down --ratio 0.5 --cwd "$g_cwd" --no-focus \
            | jget result pane pane_id)
      [ -n "$p2" ] || die "pane split returned no pane_id (grid slot 3)"
      printf '%s %s %s 3\n' "$g_tab" "$g_p0" "$g_p1" > "$grid_file"
      echo "$p2 $g_tab"
      ;;
    3)
      p3=$("$HERDR" pane split "$g_p1" --direction down --ratio 0.5 --cwd "$g_cwd" --no-focus \
            | jget result pane pane_id)
      [ -n "$p3" ] || die "pane split returned no pane_id (grid slot 4)"
      printf '%s %s %s 4\n' "$g_tab" "$g_p0" "$g_p1" > "$grid_file"
      echo "$p3 $g_tab"
      ;;
  esac
}

tab_has_live_sibling() { # exclude_id tab -- 0 (true) iff another live manifest row still shares this tab
  ex="$1"; t="$2"
  for other in $(manifest_ids); do
    [ "$other" = "$ex" ] && continue
    [ "$(manifest_field "$other" tab_id)" = "$t" ] || continue
    [ "$(manifest_field "$other" status)" = "cleaned" ] && continue
    return 0
  done
  return 1
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
    cwd="$FLEET_HOME"; model=""; label=""; timeout="60000"; trust=0; brief=""; no_peers=0; own_tab=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --brief)   [ $# -ge 2 ] || die "--brief needs a path"; brief="$2"; shift 2 ;;
        --cwd)     [ $# -ge 2 ] || die "--cwd needs a path";  cwd="$2"; shift 2 ;;
        --model)   [ $# -ge 2 ] || die "--model needs a value"; model="$2"; shift 2 ;;
        --label)   [ $# -ge 2 ] || die "--label needs a value"; label="$2"; shift 2 ;;
        --timeout) [ $# -ge 2 ] || die "--timeout needs ms";   timeout="$2"; shift 2 ;;
        --trust-cwd) trust=1; shift ;;
        --no-peers) no_peers=1; shift ;;
        --own-tab) own_tab=1; shift ;;
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
    # ENTRY AGENTS GET THEIR OWN TAB, DERIVED FROM A FIELD THAT ALREADY EXISTS.
    # `escalation_authority: orchestrator` already means "the point of contact"
    # everywhere else in this repo (teams/default.md), so reusing it here avoids
    # inventing a second notion of rank just for tab layout. --own-tab covers
    # anyone else who needs the same treatment; curate does not pass it, so the
    # curator (escalation_authority: worker) takes a grid slot like any worker.
    [ "$(persona_field "$persona" escalation_authority)" = "orchestrator" ] && own_tab=1
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

    # PEER BLOCK: composed only when this persona has a declared edge in the
    # team file AND --no-peers was not passed. It carries the worker's own id
    # (only known here, at spawn -- unlike the protocol/curation files this
    # cannot be a static file), so it is built as text rather than composed
    # from disk.
    pname=$(persona_field "$persona" name)
    peer_block=""
    if [ "$no_peers" -ne 1 ] && [ -n "$pname" ]; then
      _peer_others=$(persona_peers "$pname")
      if [ -n "$_peer_others" ]; then
        _peer_list=$(printf '%s\n' "$_peer_others" | awk 'NF{a[++n]=$0} END{for(i=1;i<=n;i++)printf "%s%s", a[i], (i<n?", ":"")}')
        peer_block="# Peers -- you can message some of your teammates directly

Your worker id is \`$id\`. Your persona (\`$pname\`) has a declared peer edge
with: $_peer_list. Reach them with:

    $FLEET_HOME/scripts/herdr-fleet.sh tell $id <to-id-or-persona> \"<text>\"

Two rules, in spirit as much as in words:

1. A peer message never substitutes for your report -- the completion
   contract is still the only thing \`await\` sees. Use \`tell\` to
   coordinate, never to finish the task.
2. Route product decisions to the orchestrator, not to a peer. A peer can
   help you get unstuck technically; only a human, through the orchestrator,
   can approve scope, waive a constraint, or make a call that is not yours."
      fi
    fi

    if [ -f "$_proto" ]; then
      {
        cat "$_proto"
        printf '\n---\n\n'
        if [ -n "$peer_block" ]; then printf '%s\n\n---\n\n' "$peer_block"; fi
        printf '%s\n' "$body"
      } > "$prompt_file"
    else
      {
        if [ -n "$peer_block" ]; then printf '%s\n\n---\n\n' "$peer_block"; fi
        printf '%s\n' "$body"
      } > "$prompt_file"
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
tmpl, out, home, sharp, no_peers, wid = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5] == "1", sys.argv[6]
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
# TELL/STATUS GRANTS, ALONGSIDE THE DIRECTORY GRANT AND LIKE IT NEVER GATED ON
# own_worktree: messaging a peer or reading fleet status mutates no tree, so
# the reviewer-first-rule reason for withholding "allow" from a shared
# checkout does not apply here. Both spellings, same reason as the directory
# grant -- a symlinked fleet home resolves to a different string. Skipped
# only under --no-peers.
#
# THE TELL GRANT IS PINNED TO id, THE WORKER BEING SPAWNED HERE -- `tell
# <id>:*`, never a bare `tell:*`. The edge check inside `tell` authenticates
# the PAIR of personas named on the command line, not which worker actually
# ran it: an unpinned grant would let any worker holding it pass a different
# id as <from-id> and have `tell` deliver under a forged, provenance-prefixed
# identity -- the one thing the design calls non-negotiable. Pinning costs
# nothing extra (spawn already knows $id here) and is what makes "the edge
# check is the enforcement" true for who is talking, not only for which pairs
# may. `status` takes no from-id argument, so it stays unpinned.
#
# CAVEAT: this pin assumes the Claude permission matcher for `Bash(prefix:*)`
# requires a word boundary after the prefix. If the matcher is actually a
# bare startsWith, an id that is a string prefix of another (w1 / w10) could
# let the shorter id grant cross-authorize the longer one -- unverified
# against the real matcher (checked: offline-only 2026-08-13). Operators can
# avoid prefix-sharing worker ids if it turns out to matter.
if not no_peers:
    allow = perms["allow"]
    for spelling in (home, os.path.realpath(home)):
        tell_grant = "Bash(%s/scripts/herdr-fleet.sh tell %s:*)" % (spelling, wid)
        if tell_grant not in allow:
            allow.append(tell_grant)
        status_grant = "Bash(%s/scripts/herdr-fleet.sh status:*)" % spelling
        if status_grant not in allow:
            allow.append(status_grant)
with open(out, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
' "$_tmpl" "$worker_settings" "$FLEET_HOME" "$_sharp" "$no_peers" "$id" \
      || die "could not compose worker permissions for $id"

    # DELEGATION STATE lives under the FLEET HOME, not the worker's own cwd --
    # spawn already puts the fleet home (both spellings) in every worker's
    # additionalDirectories for memory, so an absolute path here rides the same
    # grant rather than crossing a boundary nothing opened. This is why the
    # kickoff prompt below can name an absolute path safely: the old
    # cwd-relative rule existed to dodge a permission stall on a tree nobody
    # granted, and the fleet home is the one tree every worker always has.
    # Paths to PROJECT files inside a brief's own content stay worker-cwd-
    # relative, as before -- this is only about where brief.md/report.md live.
    worker_state="$STATE/workers/$id"
    report_file="$worker_state/report.md"
    stamp_file="$STATE/$id.spawn-stamp"
    if [ -n "$brief" ]; then
      # The brief may already BE at the destination when the caller wrote it
      # straight there; stage_brief handles that (copy-onto-self is a no-op).
      brief=$(stage_brief "$id" "$brief") || exit $?
    else
      : > "$stamp_file"
    fi

    # RESPAWN GUARD: reusing an id would strand the previous worker's tab, and
    # manifest lookups only ever resolve the LAST entry, so it could never be
    # closed again. Retire it first -- but a grid tab is not this worker's
    # alone, so this closes the PANE unconditionally and the tab only when no
    # other live worker still shares it (same rule cleanup uses below, or
    # respawning a grid-packed id would take its siblings down with it).
    old_tab=$(manifest_field "$id" tab_id)
    old_pane=$(manifest_field "$id" pane_id)
    if [ -n "$old_tab" ] && tab_alive "$old_tab"; then
      # TOLERATED, NOT ASSUMED TO SUCCEED: under this script's set -eu, `[ -n
      # "$old_pane" ] && cmd` as a bare statement dies on ANY failure of cmd,
      # because a failing command in the tail position of an AND-list is what
      # set -e treats as the whole statement's exit status. A worker cleaned
      # up individually (its pane already closed, its tab kept open for
      # siblings) and then respawned hits exactly that -- pane close on a pane
      # that is already gone -- which must not be fatal here any more than
      # "already gone" is fatal to cleanup itself.
      if [ -n "$old_pane" ]; then
        "$HERDR" pane close "$old_pane" >/dev/null 2>&1 || true
      fi
      if tab_has_live_sibling "$id" "$old_tab"; then
        note "retired previous pane $old_pane for $id -- tab $old_tab stays open for its other worker(s)"
      else
        "$HERDR" tab close "$old_tab" >/dev/null 2>&1 || true
        if tab_alive "$old_tab"; then
          note "warn: could not retire previous tab $old_tab for $id -- it will be orphaned"
        else
          note "retired previous tab $old_tab before respawning $id"
        fi
      fi
    fi

    ws=$(fleet_workspace)
    if [ "$own_tab" -eq 1 ]; then
      pane=$("$HERDR" tab create --workspace "$ws" --label "${label:-$id}" --cwd "$cwd" --no-focus \
              | jget result root_pane pane_id)
      [ -n "$pane" ] || die "tab create returned no pane_id"
      tab=$("$HERDR" pane get "$pane" | jget result pane tab_id)
    else
      slot=$(grid_slot "$ws" "$cwd")
      pane=$(printf '%s' "$slot" | awk '{print $1}')
      tab=$(printf '%s' "$slot" | awk '{print $2}')
      [ -n "$pane" ] && [ -n "$tab" ] || die "grid slot allocation returned no pane/tab"
    fi
    # WORKER IDENTITY MOVES TO THE PANE, not the tab -- a grid tab holds up to
    # four workers and cannot carry all of their names in one label.
    "$HERDR" pane rename "$pane" "$id" >/dev/null 2>&1 || note "could not rename pane $pane to $id"

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
      # purpose: the contract lives in the brief, not in this line. Absolute
      # path: the fleet home is granted to every worker regardless of cwd, so
      # naming it directly is safe here in a way it is not for project paths.
      "$HERDR" agent prompt "$agent" \
        "Read $worker_state/brief.md and execute it exactly, including its completion contract." \
        >/dev/null || die "worker $id started but the kickoff prompt failed; brief is at $worker_state/brief.md"
      echo "briefed $id -> $worker_state/brief.md (report expected at $report_file)"
    fi
    ;;

  assign)
    # RE-TASK, NOT REPLACE. assign is symmetric with spawn but never touches a
    # tab or an agent -- same worker, same warm context, a new brief. Two
    # verbs keep "replace" (spawn, respawn guard) and "re-task" (assign)
    # distinct in the manifest and in the orchestrator's head (see the
    # decision table in designs/2026-08-12-fleet-mechanics.md §3).
    [ $# -ge 1 ] || die "assign needs: <id> --brief <file>"
    id="$1"; shift
    brief=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --brief) [ $# -ge 2 ] || die "--brief needs a path"; brief="$2"; shift 2 ;;
        *) die "unknown assign option: $1" ;;
      esac
    done
    [ -n "$brief" ] || die "assign needs: <id> --brief <file>"

    agent=$(resolve_agent "$id")
    tab=$(manifest_field "$id" tab_id)
    if [ -z "$tab" ] || ! worker_alive "$id"; then
      die "worker $id is gone -- spawn instead"
    fi

    # NO --force: a brief injected mid-task interleaves two tasks in one
    # context, and there is no way to unwind that once it has happened. `tell`
    # or `prompt` exist for steering a worker that is already `working`.
    state=$("$HERDR" agent get "$agent" 2>/dev/null | jget result agent agent_status)
    [ "$state" = "working" ] \
      && die "worker $id is working -- assign refuses to interleave a new brief mid-task (no --force; use 'prompt $id ...' to steer it, or wait for it to finish)"

    # SAME PREMATURE-AWAIT GUARD SPAWN RUNS, via the one shared function --
    # archives any stale report.md and refreshes the spawn stamp, so `await`
    # cannot mistake the outgoing task's report for this one's.
    brief=$(stage_brief "$id" "$brief") || exit $?

    worker_state="$STATE/workers/$id"
    report_file="$worker_state/report.md"
    stamp_file="$STATE/$id.spawn-stamp"
    log_manifest id="$id" agent="$agent" pane_id="$(manifest_field "$id" pane_id)" \
      tab_id="$tab" workspace_id="$(manifest_field "$id" workspace_id)" \
      persona="$(manifest_field "$id" persona)" cwd="$(manifest_field "$id" cwd)" \
      brief="$brief" report="$report_file" stamp="$stamp_file" \
      settings="$(manifest_field "$id" settings)" status=assigned

    "$HERDR" agent prompt "$agent" \
      "Read $worker_state/brief.md and execute it exactly, including its completion contract." \
      >/dev/null || die "assign staged the brief but the kickoff prompt failed; brief is at $worker_state/brief.md"
    echo "assigned $id -> $worker_state/brief.md (report expected at $report_file)"
    ;;

  prompt|steer)
    [ $# -ge 2 ] || die "prompt needs: <id> \"<text>\" [--wait] [--until <state>] [--timeout <ms>]"
    id="$1"; text="$2"; shift 2
    agent=$(resolve_agent "$id")
    "$HERDR" agent prompt "$agent" "$text" "$@"
    ;;

  tell)
    # PEER TRANSPORT: `herdr agent prompt`, same as a human steering a worker
    # -- a prompt wakes the peer, where a mailbox would need the peer to poll,
    # and an idle Claude session polls nothing.
    [ $# -eq 3 ] || die "tell needs: <from-id> <to-id-or-persona> \"<text>\""
    from_id="$1"; to_ref="$2"; text="$3"

    from_agent=$(resolve_agent "$from_id")
    from_persona=$(persona_field "$(manifest_field "$from_id" persona)" name)
    [ -n "$from_persona" ] || die "could not resolve $from_id's persona from $MANIFEST"

    # <to> is an id when the manifest knows one; otherwise a persona name,
    # valid only when exactly one LIVE worker carries it -- ambiguity is an
    # error naming the ids, not a guess.
    to_agent=$(manifest_field "$to_ref" agent)
    if [ -n "$to_agent" ]; then
      to_id="$to_ref"
      to_persona=$(persona_field "$(manifest_field "$to_id" persona)" name)
    else
      candidates=""; n_candidates=0; to_id=""
      for wid in $(manifest_ids); do
        worker_alive "$wid" || continue
        [ "$(persona_field "$(manifest_field "$wid" persona)" name)" = "$to_ref" ] || continue
        n_candidates=$((n_candidates + 1))
        candidates="$candidates $wid"
      done
      case "$n_candidates" in
        0) die "no live worker with persona $to_ref (and no worker id $to_ref in $MANIFEST)" ;;
        1) to_id=$(printf '%s' "$candidates" | tr -d ' '); to_agent=$(resolve_agent "$to_id"); to_persona="$to_ref" ;;
        *) die "persona $to_ref is ambiguous -- live carriers:$candidates" ;;
      esac
    fi
    [ -n "$to_persona" ] || die "could not resolve $to_id's persona from $MANIFEST"

    peers_declared "$from_persona" "$to_persona" \
      || die "no declared peer edge between $from_persona and $to_persona (see ${FLEET_TEAM:-$FLEET_HOME/teams/default.md} 'peers:')"

    # PROVENANCE IS NON-NEGOTIABLE: a bare injected prompt is indistinguishable
    # from the human, and a worker must never mistake a peer for the operator.
    "$HERDR" agent prompt "$to_agent" "[peer message from $from_id ($from_persona)] $text" >/dev/null \
      || die "tell failed to deliver to $to_id"
    echo "told $to_id (agent $to_agent, persona $to_persona)"
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
      # can unblock it. worker_alive is the ground truth here, same as
      # everywhere else -- it checks the worker's own pane first, falling back
      # to the tab only for rows with no pane recorded.
      if [ -n "$tab" ] && ! worker_alive "$id"; then
        # It may have finished and been cleaned up between polls -- a report
        # from a dead worker cannot still be growing, so one check is enough.
        if [ -f "$report" ] && { [ -z "$stamp" ] || file_newer_than "$report" "$stamp"; }; then
          echo "$report"
          exit 0
        fi
        note "worker $id is gone (its pane/tab is gone) and left no report -- nothing will ever satisfy this await"
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
    printf '%-16s %-16s %-6s %-8s %-10s %s\n' ID STATUS CTX REPORT TAB CWD
    for id in $ids; do
      agent=$(manifest_field "$id" agent)
      tab=$(manifest_field "$id" tab_id)
      cwd=$(manifest_field "$id" cwd)
      report=$(manifest_field "$id" report)
      stamp=$(manifest_field "$id" stamp)
      if worker_alive "$id"; then
        st=$("$HERDR" agent get "$agent" 2>/dev/null | jget result agent agent_status)
        [ -n "$st" ] || st="no-agent"
        # A row recorded as blocked-on-trust never reached a usable agent, so
        # herdr's own status for it means nothing -- keep the recorded one.
        recorded=$(manifest_field "$id" status)
        [ "$recorded" = "blocked-on-trust" ] && st="$recorded"
        # One more herdr call per live worker, on top of the `agent get` above
        # -- acceptable at the cap-5 fleet size the orchestrator enforces;
        # revisit (batch, or drop CTX) if that cap ever rises.
        ctx=$(worker_ctx "$agent")
      else
        st="gone"
        ctx="?"
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
      printf '%-16s %-16s %-6s %-8s %-10s %s\n' "$id" "$st" "$ctx" "$rp" "$tab" "$cwd"
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
      pane=$(manifest_field "$id" pane_id)
      [ -n "$tab" ] || { note "no tab recorded for $id"; continue; }
      if ! tab_alive "$tab"; then echo "already gone: $id ($tab)"; continue; fi
      # CLOSES THE PANE, NOT THE TAB, UNCONDITIONALLY -- a grid tab holds up to
      # four workers, so a worker's own cleanup must not take its siblings'
      # panes down with it (D). The tab only follows when no other live
      # manifest row still shares it.
      #
      # TOLERATED, LOGGED, NOT FATAL: `cleanup --all` sweeps every id the
      # manifest has ever seen, including ones a PRIOR per-worker `cleanup
      # <id>` already closed the pane for (tab kept open for siblings, so
      # tab_alive above did not skip it) -- that pane close fails here, and
      # under this script's set -eu a bare `[ -n "$pane" ] && cmd` statement
      # takes the whole sweep down with it on that failure, silently (the
      # command's own stderr is already discarded), before the workspace step
      # and long before the archive step. Note it and move on instead; the
      # rest of the sweep (this id's manifest row, its siblings, the archive)
      # must not depend on a pane that was already closed.
      pane_closed=1
      if [ -n "$pane" ]; then
        if ! "$HERDR" pane close "$pane" >/dev/null 2>&1; then
          pane_closed=0
          note "pane close failed for $id ($pane) during cleanup -- already gone?"
        fi
      fi
      if tab_has_live_sibling "$id" "$tab"; then
        if [ "$pane_closed" = 1 ]; then
          echo "closed pane for $id ($pane); tab $tab stays open for its other worker(s)"
        else
          echo "pane for $id ($pane) was already gone; marking its row cleaned. tab $tab stays open for its other worker(s)"
        fi
        log_manifest id="$id" agent="$(manifest_field "$id" agent)" \
                     pane_id="$pane" tab_id="$tab" \
                     workspace_id="$(manifest_field "$id" workspace_id)" \
                     persona="$(manifest_field "$id" persona)" \
                     cwd="$(manifest_field "$id" cwd)" \
                     brief="$(manifest_field "$id" brief)" \
                     report="$(manifest_field "$id" report)" \
                     stamp="$(manifest_field "$id" stamp)" \
                     settings="$(manifest_field "$id" settings)" status=cleaned
        continue
      fi
      "$HERDR" tab close "$tab" >/dev/null 2>&1 || true
      j=0
      while tab_alive "$tab" && [ "$j" -lt 6 ]; do sleep 0.5; j=$((j + 1)); done
      if tab_alive "$tab"; then
        echo "FAILED to close $id ($tab)" >&2; failed=1
      else
        echo "closed $id ($tab)"
        log_manifest id="$id" agent="$(manifest_field "$id" agent)" \
                     pane_id="$pane" tab_id="$tab" \
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
      if [ -f "$STATE/workspace.adopted" ]; then
        # ADOPTED WORKSPACES ARE NEVER CLOSED -- binding constraint. Only the
        # label comes back; closing it would kill the pane the wrapper itself
        # (or the orchestrator that ran it) is running in, mid-teardown.
        ws=$(cat "$WS_FILE" 2>/dev/null || true)
        label_before=$(cat "$STATE/workspace.label-before" 2>/dev/null || true)
        if [ -n "$ws" ] && workspace_alive "$ws"; then
          if "$HERDR" workspace rename "$ws" "$label_before" >/dev/null 2>&1; then
            echo "restored adopted workspace $ws label -> \"$label_before\""
          else
            echo "FAILED to restore adopted workspace $ws label" >&2; failed=1
          fi
        elif [ -n "$ws" ]; then
          echo "adopted workspace $ws already gone -- nothing to restore"
        fi
        rm -f "$WS_FILE" "$STATE/workspace.adopted" "$STATE/workspace.label-before"
      else
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

      # ARCHIVE, NOT DELETE: reports are the audit trail and the curator's raw
      # material, so a torn-down run's state is swept aside, not lost. Each of
      # these is whichever exists -- a fleet that never spawned a worker has no
      # workers/ to move, and that is not a failure. The next run starts with
      # no manifest, which is also what fixes `status` accreting every worker
      # id since the dawn of the fleet.
      ts=$(date -u +%Y%m%dT%H%M%SZ)
      archive_dir="$STATE/archive/$ts"
      # A second `cleanup --all` inside the same UTC second (scripted teardown,
      # or a test) would otherwise collide with the previous run's directory
      # and merge into it silently -- disambiguate rather than assume runs are
      # a second apart.
      if [ -e "$archive_dir" ]; then
        n=1
        while [ -e "$archive_dir-$(printf '%02d' "$n")" ]; do n=$((n + 1)); done
        archive_dir="$archive_dir-$(printf '%02d' "$n")"
      fi
      archived=0
      # grid and grid.next are D's state files, added after this list -- they
      # are part of the run's state exactly like the manifest is: leaving them
      # behind means the next run's first spawn "self-heals" a grid that was
      # never actually desynced, and grid numbering never resets to 1.
      for name in workers personas permissions curation-brief.md manifest.jsonl last-curation grid grid.next; do
        if [ -e "$STATE/$name" ]; then
          mkdir -p "$archive_dir"
          mv "$STATE/$name" "$archive_dir/$name"
          archived=1
        fi
      done
      # *.spawn-stamp is a glob, not a fixed name -- one file per worker that
      # ever spawned this run, sitting directly under $STATE rather than under
      # workers/<id>/ (the stamp exists to outlive a respawn of that id).
      for stamp in "$STATE"/*.spawn-stamp; do
        [ -e "$stamp" ] || continue
        mkdir -p "$archive_dir"
        mv "$stamp" "$archive_dir/$(basename "$stamp")"
        archived=1
      done
      [ "$archived" -eq 1 ] && echo "archived this run's state -> $archive_dir"

      # PRUNE TO 5: the timestamp format is fixed-width UTC, so a reverse
      # lexical sort is a reverse chronological sort -- nothing to parse.
      stale=$(ls -1 "$STATE/archive" 2>/dev/null | sort -r | tail -n +6)
      if [ -n "$stale" ]; then
        printf '%s\n' "$stale" | while IFS= read -r old; do
          # `|| true`: this AND-list is the BODY of a while loop, not an if
          # condition, so it is not exempt from set -e -- a failing rm -rf
          # here (permissions, a concurrent prune) would otherwise abort the
          # pipeline's subshell and, with it, this whole teardown, after the
          # archive step already succeeded. Pruning old archives is best
          # effort; it must never take a successful cleanup down with it.
          [ -n "$old" ] && { rm -rf "$STATE/archive/$old" || true; }
        done
      fi
    fi
    exit "$failed"
    ;;

  ""|-h|--help|help)
    sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    die "unknown command: $cmd (try --help)"
    ;;
esac
