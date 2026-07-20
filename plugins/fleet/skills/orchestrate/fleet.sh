#!/bin/sh
# fleet.sh — deterministic wrapper for the cmux fleet delegation protocol.
# See cmux-delegation.md for the full protocol. Verified against cmux 0.64.19.
# Usage:
#   fleet.sh preflight
#   fleet.sh window <name>                      # new window for an orchestration; prints ref
#   fleet.sh spawn <id> <label> <model> <cwd> <brief-file> [--layout split|workspace] [--dir down|right] [--window <ref>] [-- extra claude args...]
#   fleet.sh await <id> [timeout-seconds]
#   fleet.sh report <id>
#   fleet.sh steer <id> "<message>"
#   fleet.sh status
#   fleet.sh cleanup <id> | --all
# Layout rule: split (default) for <=3 workers in one orchestration — whole fleet
# on one page. workspace (+ --window per orchestration) for bigger/multiple fleets.
#
# Cleanup contract: every close is VERIFIED against `cmux tree` (ground truth).
# cleanup prints "closed <id> (<ref>)" only for something the tree confirms is
# gone, "FAILED to close ..." otherwise, and exits nonzero if anything failed.
# It never claims success from a close command's own exit status.
#
# TESTING: set FLEET_TEST_CMD to replace the worker command (normally
# `claude ...`) with a cheap fake, so the whole spawn -> boot-verify -> kickoff
# -> await -> cleanup cycle can be exercised without real Claude sessions. The
# substituted command is run with FLEET_ID and FLEET_ROOT in its environment.
# A fake worker only needs to print something matching CLAUDE_UI (e.g.
# "-- INSERT --" or "ctx 5%") and then idle so the pane stays alive:
#   FLEET_TEST_CMD='sh /path/to/fakeworker.sh' fleet.sh spawn w1 ... --layout grid
# See fleetlab/fakeworker.sh and fleetlab/matrix.sh for the integration matrix.
set -eu

CMUX="${CMUX_BIN:-cmux}"
export CMUX_QUIET=1   # silence alias/deprecation notices that pollute parseable output

# Config: ~/.fleetrc (global defaults) then $FLEET_HOME/.fleetrc (per-project).
# Explicit env vars at invocation still win over rc values.
_e_page="${FLEET_PAGE:-}"; _e_pmode="${FLEET_PERMISSION_MODE:-}"
for _rc in "$HOME/.fleetrc" "${FLEET_HOME:-.}/.fleetrc"; do
  [ -f "$_rc" ] && . "$_rc"
done
[ -n "$_e_page" ] && FLEET_PAGE="$_e_page"
[ -n "$_e_pmode" ] && FLEET_PERMISSION_MODE="$_e_pmode"
# Fleet state lives in ONE place per orchestration. Export FLEET_HOME=<orchestration root>
# once at the start; never cd-wrap fleet.sh calls (pass worktree paths as args instead) —
# cwd-relative state scattered across worktrees breaks tiling and the manifest.
FLEET_DIR="${FLEET_HOME:-.}/.fleet"
MANIFEST="$FLEET_DIR/manifest.jsonl"

die() { echo "fleet: $*" >&2; exit 1; }

# count non-empty lines matching a pattern. NEVER use `grep -c` in a command
# substitution: on zero matches it prints "0" AND exits 1, so under `set -e`
# a bare assignment aborts the script, and the usual `|| echo 0` guard appends
# a SECOND zero ("0\n0") which then blows up in arithmetic. awk always prints
# exactly one integer and exits 0.
count_matching() { # pattern file -> integer (0 if file missing/empty)
  [ -f "$2" ] || { echo 0; return 0; }
  awk -v p="$1" 'p=="" ? NF : $0 ~ p {c++} END{print c+0}' "$2"
}
count_stdin() { # pattern -> integer, counts matching lines on stdin
  awk -v p="$1" -v ic="${2:-0}" \
    '{ l = ic ? tolower($0) : $0 } l ~ p {c++} END{print c+0}'
}

field_of() { # id field -> value (last manifest entry wins)
  grep "\"id\":\"$1\"" "$MANIFEST" 2>/dev/null | tail -1 | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p"
}
log_manifest() { # id ref worktree model status layout [wsref] [placement]
  # `layout` is what was REQUESTED; `placement` is what cmux actually created
  # (surface = a split inside an existing page workspace, workspace = its own
  # workspace). cleanup picks its close verb from placement, never from layout:
  # grid-mode page-first tiles and every fallback path are real WORKSPACES even
  # though the requested layout said grid/split.
  mkdir -p "$FLEET_DIR"
  printf '{"id":"%s","ref":"%s","worktree":"%s","model":"%s","status":"%s","layout":"%s","wsref":"%s","placement":"%s","ts":"%s"}\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "${7:-}" "${8:-}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$MANIFEST"
}
ref_alive() { # ref -> 0 while the ref still appears in cmux tree. TREE IS GROUND
  # TRUTH: the close command's own exit status lies (it can report OK for a
  # no-op, and its stderr was historically swallowed). Compare whole tokens so
  # surface:4 never matches surface:45.
  "$CMUX" tree --all 2>/dev/null | awk -v r="$1" \
    '{for(i=1;i<=NF;i++) if($i==r) f=1} END{exit f?0:1}'
}
verify_gone() { # ref [tries] — poll the tree until the ref disappears
  _v=0; _vmax="${2:-6}"
  while ref_alive "$1"; do
    [ "$_v" -ge "$_vmax" ] && return 1
    sleep 0.5; _v=$((_v+1))
  done
  return 0
}
group_anchor() { # group-ref -> the workspace ref cmux uses as that group's header
  # `workspace-group create` ALWAYS mints a fresh empty workspace to be the
  # group header (--from only adds members). Nothing else closes it, so without
  # recording it every orchestration strands one "fleet: <root>" workspace.
  # In the JSON each group's anchor_workspace_ref precedes its own "ref".
  "$CMUX" workspace-group list --json 2>/dev/null | awk -v g="$1" '
    /"anchor_workspace_ref"/ { a=$0; sub(/.*: *"/,"",a); sub(/".*/,"",a) }
    /"ref" *:/ { r=$0; sub(/.*: *"/,"",r); sub(/".*/,"",r); if (r==g) { print a; exit } }'
}
ws_surface_count() { # wsref -> how many surfaces the workspace still holds
  # MUST use `tree --workspace`: list-pane-surfaces only lists ONE pane (the
  # focused one by default), so it reports 1 for a 2x2 page and cleanup would
  # wrongly close the whole workspace, taking sibling tiles down with it.
  "$CMUX" tree --workspace "$1" 2>/dev/null | awk \
    '{for(i=1;i<=NF;i++) if($i ~ /^surface:[0-9]+$/) c++} END{print c+0}'
}
close_worker() { # ref wsref placement -> 0 when the target is verifiably gone.
  # Sets CLOSE_CHECK (the ref that had to disappear) and CLOSE_ERR (cmux stderr).
  # The verb comes from what the workspace ACTUALLY holds right now, not from
  # creation-time placement alone: a page-first grid tile OWNS its workspace,
  # but siblings get split INTO that workspace afterwards, and closing it would
  # take them down too. So: other surfaces present -> close just this surface;
  # this is the last surface -> close the workspace.
  _cr="$1"; _cw="$2"; _cp="$3"; CLOSE_ERR=""; CLOSE_CHECK="$1"
  ref_alive "$_cr" || return 0   # already gone
  _verb="$_cp"
  if [ -n "$_cw" ] && [ "$_cr" != "$_cw" ]; then
    if [ "$(ws_surface_count "$_cw")" -gt 1 ]; then _verb="surface"; else _verb="workspace"; fi
  elif [ "$_cr" = "$_cw" ]; then
    _verb="workspace"
  fi
  if [ "$_verb" = "workspace" ]; then
    CLOSE_CHECK="${_cw:-$_cr}"
    CLOSE_ERR=$("$CMUX" close-workspace --workspace "$CLOSE_CHECK" 2>&1) || true
  else
    # close-surface resolves --surface in a workspace context too — pass it when
    # the manifest recorded one (grid workers live in a page workspace, not the
    # caller's)
    set -- --surface "$_cr"
    [ -n "$_cw" ] && set -- --workspace "$_cw" "$@"
    CLOSE_ERR=$("$CMUX" close-surface "$@" 2>&1) || true
    CLOSE_CHECK="$_cr"
    # A tile that is its workspace's LAST surface cannot be closed with
    # close-surface ("invalid_state: Cannot close the last surface"). Escalate
    # ONLY when nothing else is in there, so siblings are never collateral.
    if ref_alive "$_cr" && [ -n "$_cw" ] && [ "$(ws_surface_count "$_cw")" -le 1 ]; then
      CLOSE_ERR=$("$CMUX" close-workspace --workspace "$_cw" 2>&1) || true
      CLOSE_CHECK="$_cw"
    fi
  fi
  verify_gone "$CLOSE_CHECK"
}
drop_tile() { # ref — free its grid slot (line: "<surface> <workspace>")
  [ -f "$FLEET_DIR/.tiles" ] || return 0
  awk -v r="$1" '$1 != r' "$FLEET_DIR/.tiles" > "$FLEET_DIR/.tiles.tmp" 2>/dev/null || true
  mv "$FLEET_DIR/.tiles.tmp" "$FLEET_DIR/.tiles"
}
parse_ref() { # kind — extract first "<kind>:N" token from stdin (cmux prefixes output with "OK ")
  tr ' \t' '\n\n' | grep -m1 "^$1:[0-9]" || true
}
surface_of_ws() { # wsref — resolve a workspace's terminal surface (workspace create may print no surface ref)
  "$CMUX" list-pane-surfaces --workspace "$1" 2>/dev/null | parse_ref surface
}
detect_page() { # auto display density: external monitor attached → 4 (2x2 quad), laptop-only → 1
  _sp=$(system_profiler SPDisplaysDataType 2>/dev/null)
  _total=$(printf '%s' "$_sp" | count_stdin "Resolution:")
  _int=$(printf '%s' "$_sp" | count_stdin "built-in|internal" 1)
  if [ "${_int:-0}" -gt 0 ]; then _ext=$((_total - 1)); else _ext="${_total:-0}"; fi
  if [ "$_ext" -ge 1 ]; then echo 4; else echo 1; fi
}
screen_has() { # ref pattern [workspace] — probe pane content
  # surface refs resolve within a workspace context (defaults to the CALLER's
  # workspace) — pass the pane's own workspace when known, else fall back
  _ws="${3:-}"
  if [ -n "$_ws" ]; then
    "$CMUX" read-screen --workspace "$_ws" --surface "$1" --lines 10 2>/dev/null | grep -qiE "$2"
  else
    "$CMUX" read-screen --surface "$1" --lines 10 2>/dev/null | grep -qiE "$2"
  fi
}
wait_for_screen() { # ref pattern max_tries interval [workspace] — poll until pattern appears
  _i=0
  until screen_has "$1" "$2" "${5:-}" || [ "$_i" -ge "$3" ]; do sleep "$4"; _i=$((_i+1)); done
  screen_has "$1" "$2" "${5:-}"
}
CLAUDE_UI='ctx [0-9]+%|for shortcuts|INSERT|esc to interrupt'
kickoff() { # ref id [workspace]
  _id="$2"; _kws="${3:-}"
  # brief only lands once claude's UI is actually up
  wait_for_screen "$1" "$CLAUDE_UI" 20 1 "$_kws" || echo "warn: claude UI not detected on $1 before kickoff" >&2
  set -- --surface "$1"
  [ -n "$_kws" ] && set -- --workspace "$_kws" "$@"
  # keep this string short and quote-free — the contract details live in the brief itself
  "$CMUX" send "$@" "Read .fleet/$_id/brief.md and execute it exactly, including its completion contract."
  "$CMUX" send-key "$@" enter
}

cmd="${1:-}"; [ $# -gt 0 ] && shift || true

case "$cmd" in
  preflight)
    "$CMUX" ping >/dev/null 2>&1 || die "cmux socket unreachable (app not running, or orchestrator not inside cmux)"
    echo "ok: cmux socket reachable"
    ;;

  window)
    [ $# -ge 1 ] || die "window needs: name"
    ref=$("$CMUX" new-window | parse_ref window)
    [ -n "$ref" ] || die "new-window returned no window ref"
    "$CMUX" rename-window --window "$ref" "$1" 2>/dev/null || true
    echo "$ref"
    ;;

  spawn)
    [ $# -ge 5 ] || die "spawn needs: id label model cwd brief-file [--layout ...] [--dir ...] [--window ...]"
    id="$1"; label="$2"; model="$3"; cwd="$4"; brief="$5"; shift 5
    layout="split"; dir="right"; window=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --layout) layout="$2"; shift 2 ;;
        --dir) dir="$2"; shift 2 ;;
        --window) window="$2"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
      esac
    done
    [ -f "$brief" ] || die "brief file not found: $brief"
    mkdir -p "$FLEET_DIR/$id" "$cwd/.fleet/$id"
    # The brief may ALREADY sit at the destination: when the worker's cwd is the
    # orchestration root and the caller wrote the brief straight to
    # .fleet/<id>/brief.md, src and dest are the same file. cp then fails with
    # "are identical" and set -e aborts the spawn. Compare canonical paths.
    brief_dest="$cwd/.fleet/$id/brief.md"
    abspath() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
    if [ "$(abspath "$brief")" != "$(abspath "$brief_dest")" ]; then
      cp "$brief" "$brief_dest"
    fi
    # RESPAWN GUARD: reusing an id strands the previous attempt's pane. The
    # manifest is keyed by id and field_of only ever resolves the LAST entry, so
    # once a second entry lands the older pane can never be closed again — it
    # survives every cleanup, including --all. Retire it before taking the id.
    old_ref=$(field_of "$id" ref); old_ws=$(field_of "$id" wsref)
    old_pl=$(field_of "$id" placement); old_status=$(field_of "$id" status)
    if [ -n "$old_ref" ] && [ "$old_status" != "cleaned" ] && ref_alive "$old_ref"; then
      if close_worker "$old_ref" "$old_ws" "$old_pl"; then
        drop_tile "$old_ref"
        echo "note: retired previous pane for $id ($CLOSE_CHECK) before respawn" >&2
      else
        echo "warn: could not retire previous pane for $id ($CLOSE_CHECK) — it will be orphaned${CLOSE_ERR:+; cmux said: $CLOSE_ERR}" >&2
      fi
    fi
    # PREMATURE-AWAIT GUARD: a report.md left behind by an earlier attempt with
    # this same id makes the file-first await return "done" the instant it is
    # called. Archive any stale report, and drop a spawn stamp so await can
    # reject reports older than THIS attempt even if one reappears.
    _sstamp=$(date -u +%Y%m%d-%H%M%S)
    for _rd in "$cwd/.fleet/$id" "$FLEET_DIR/$id"; do
      if [ -f "$_rd/report.md" ]; then
        mv "$_rd/report.md" "$_rd/report.stale-$_sstamp.md"
        echo "note: archived stale report for $id -> report.stale-$_sstamp.md" >&2
      fi
    done
    : > "$FLEET_DIR/$id/.spawn-stamp"
    # The done signal is LATCHED, not fleeting: a token signalled by a previous
    # attempt stays pending until some waiter consumes it. When that attempt's
    # await returned via the report FILE it never consumed the latch, so this
    # attempt's await would fire on it instantly. Drain it (--timeout 0 is a
    # non-blocking poll: consumes a pending latch, returns immediately if none).
    "$CMUX" wait-for "wk-$id-done" --timeout 0 >/dev/null 2>&1 \
      && echo "note: drained a stale done-signal for $id" >&2 || true
    # Workers get the orchestration root as an ADDITIONAL working directory so
    # central .fleet/ writes are inside the permission boundary (acceptEdits only
    # auto-approves edits within the session's working dirs — out-of-boundary
    # writes prompt the human, which defeats hands-off).
    # FLEET_PERMISSION_MODE=bypassPermissions for fully unattended fleets.
    pmode="${FLEET_PERMISSION_MODE:-acceptEdits}"
    fleet_root=$(cd "${FLEET_HOME:-.}" && pwd)
    claude_cmd="claude --model $model --permission-mode $pmode --add-dir '$fleet_root' $*"
    # TEST HOOK: FLEET_TEST_CMD replaces the worker command so the full
    # spawn -> boot-verify -> kickoff -> await -> cleanup cycle can be
    # exercised with cheap fake workers instead of real claude sessions.
    # The substituted command receives FLEET_ID and FLEET_ROOT in its env.
    if [ -n "${FLEET_TEST_CMD:-}" ]; then
      claude_cmd="FLEET_ID='$id' FLEET_ROOT='$fleet_root' $FLEET_TEST_CMD"
    fi
    placement=""   # set to surface|workspace by whichever path actually creates the pane
    case "$layout" in
      grid|split)
        # GROUPED GRID (default): the whole orchestration lives in ONE sidebar
        # group anchored by the orchestrator's workspace (the group header IS
        # the orchestrator). Workers tile 2x2 per "page" workspace in the group:
        #   page 1: 1 2    page 2: 5 6
        #           3 4            7 8
        # Nothing ever teleports to a new window; the group forming in the
        # sidebar is itself the announcement that a fleet is spinning up.
        mkdir -p "$FLEET_DIR"; TILES="$FLEET_DIR/.tiles"
        # density: explicit FLEET_PAGE (env/rc) > cached auto-detect > fresh auto-detect
        if [ -n "${FLEET_PAGE:-}" ]; then
          page_size="$FLEET_PAGE"
        elif [ -f "$FLEET_DIR/.page" ]; then
          page_size=$(cat "$FLEET_DIR/.page")
        else
          page_size=$(detect_page)
          printf '%s\n' "$page_size" > "$FLEET_DIR/.page"
          echo "note: display auto-detect → $page_size pane(s) per page (set FLEET_PAGE or ~/.fleetrc to override)" >&2
        fi
        GROUP=$(cat "$FLEET_DIR/.group" 2>/dev/null || true)
        if [ -n "$GROUP" ] && ! "$CMUX" workspace-group list 2>/dev/null | grep -q "$GROUP"; then
          GROUP=""   # stale ref from a previous run — recreate
          # That group's header workspace is now orphaned, and we are about to
          # overwrite the only record of it. Reclaim it first, or it survives
          # every future cleanup. Only ever holds anchor refs, so this cannot
          # hit a worker pane; still guard the orchestrator explicitly.
          OLDA=$(cat "$FLEET_DIR/.anchor" 2>/dev/null || true)
          if [ -n "$OLDA" ] && [ "$OLDA" != "${CMUX_WORKSPACE_ID:-}" ] && ref_alive "$OLDA"; then
            "$CMUX" close-workspace --workspace "$OLDA" >/dev/null 2>&1 || true
            verify_gone "$OLDA" && echo "note: reclaimed orphaned group header $OLDA" >&2 \
              || echo "warn: could not reclaim orphaned group header $OLDA" >&2
          fi
          : > "$FLEET_DIR/.anchor"
        fi
        if [ -z "$GROUP" ]; then
          GROUP=$("$CMUX" workspace-group create --name "fleet: $(basename "$fleet_root")" 2>/dev/null | parse_ref workspace_group) || true
          if [ -n "$GROUP" ]; then
            printf '%s\n' "$GROUP" > "$FLEET_DIR/.group"
            # remember the header workspace cmux created so cleanup can reclaim it
            group_anchor "$GROUP" > "$FLEET_DIR/.anchor" 2>/dev/null || true
            echo "note: created sidebar group $GROUP — workers nest inside" >&2
          fi
        fi
        if [ -f "$TILES" ]; then   # purge tiles whose panes are gone (line: "<surface> <workspace>")
          : > "$TILES.tmp"
          while IFS= read -r tline; do
            t=${tline%% *}; tw=${tline#* }; [ "$tw" = "$tline" ] && tw=""
            set -- --surface "$t" --lines 1
            [ -n "$tw" ] && set -- --workspace "$tw" "$@"
            "$CMUX" read-screen "$@" >/dev/null 2>&1 && printf '%s\n' "$tline" >> "$TILES.tmp"
          done < "$TILES"
          mv "$TILES.tmp" "$TILES"
        fi
        k=$(count_matching "" "$TILES")
        pos=$((k % page_size)); ref="" tile_ws=""
        if [ "$pos" -ne 0 ] && [ -f "$TILES" ]; then   # extend current page's quad
          case "$pos" in
            1) tline=$(tail -1 "$TILES"); d=right ;;                # 2 goes right of 1
            2) tline=$(tail -2 "$TILES" | head -1); d=down ;;      # 3 goes under 1
            *) tline=$(tail -3 "$TILES" | sed -n 2p); d=down ;;    # 4 goes under 2
          esac
          tsurf=${tline%% *}; tws=${tline#* }; [ "$tws" = "$tline" ] && tws=""
          case "$tsurf" in workspace:*) tws="$tsurf"; tsurf=$(surface_of_ws "$tsurf") ;; esac
          if [ -n "$tsurf" ]; then
            # split resolves --surface within a workspace context (defaults to the
            # CALLER's workspace) — must pass the page's workspace explicitly
            set -- "$d" --focus false
            [ -n "$tws" ] && set -- "$@" --workspace "$tws"
            set -- "$@" --surface "$tsurf"
            ref=$("$CMUX" new-split "$@" 2>/dev/null | parse_ref surface) || true
            tile_ws="$tws"
            [ -n "$ref" ] && placement="surface"   # a split INSIDE an existing page workspace
          fi
        fi
        if [ -z "$ref" ]; then   # first tile of a new page (or fallback)
          set -- --name "wk-$id-$label" --cwd "$fleet_root" --focus false
          [ -n "$GROUP" ] && set -- "$@" --group "$GROUP" --group-placement end
          out=$("$CMUX" new-workspace "$@")
          pg_ws=$(printf '%s' "$out" | parse_ref workspace)
          ref=$(printf '%s' "$out" | parse_ref surface)
          if [ -z "$ref" ] && [ -n "$pg_ws" ]; then   # workspace create may print only the workspace ref
            _t=0
            while [ -z "$ref" ] && [ "$_t" -lt 5 ]; do   # surface registers a beat after creation
              sleep 1; ref=$(surface_of_ws "$pg_ws"); _t=$((_t+1))
            done
          fi
          [ -z "$ref" ] && [ -n "$pg_ws" ] && ref="$pg_ws"   # last resort: target the workspace itself
          tile_ws="$pg_ws"
          # This tile came from new-workspace, so it OWNS its workspace and is
          # that workspace's only surface — close-surface would fail with
          # "Cannot close the last surface". Record it as a workspace.
          placement="workspace"
        fi
        [ -n "$ref" ] || die "could not create a pane for worker $id (no surface or workspace ref in cmux output)"
        if [ -n "$tile_ws" ]; then printf '%s %s\n' "$ref" "$tile_ws" >> "$TILES"; else printf '%s\n' "$ref" >> "$TILES"; fi
        # same workspace-context issue as new-split above: resolve --surface
        # calls against this tile's own workspace, not the caller's
        set -- --surface "$ref"
        [ -n "$tile_ws" ] && set -- --workspace "$tile_ws" "$@"
        "$CMUX" rename-tab "$@" "wk-$id-$label" 2>/dev/null || true
        # RACE GUARD: a fresh pane's shell isn't listening yet — typing into it
        # immediately loses the keystrokes. Wait for a prompt first.
        wait_for_screen "$ref" '[❯$%#]' 20 0.5 "$tile_ws" || echo "warn: no shell prompt detected on $ref" >&2
        "$CMUX" send "$@" "cd '$cwd' && $claude_cmd"
        "$CMUX" send-key "$@" enter
        # verify claude actually booted; one retry if the send was swallowed
        if ! wait_for_screen "$ref" "$CLAUDE_UI" 15 1 "$tile_ws"; then
          "$CMUX" send "$@" "cd '$cwd' && $claude_cmd"
          "$CMUX" send-key "$@" enter
          wait_for_screen "$ref" "$CLAUDE_UI" 10 1 "$tile_ws" || true
        fi
        ;;
      workspace)
        # --focus false, NOT --no-focus: cmux rejects the latter outright
        # ("unknown flag"), which broke every workspace-layout spawn.
        set -- --name "wk-$id-$label" --cwd "$cwd" --focus false --command "$claude_cmd"
        [ -n "$window" ] && set -- "$@" --window "$window"
        out=$("$CMUX" new-workspace "$@")
        wsref=$(printf '%s' "$out" | parse_ref workspace)
        ref=$(printf '%s' "$out" | parse_ref surface)
        [ -z "$ref" ] && [ -n "$wsref" ] && { sleep 1; ref=$(surface_of_ws "$wsref"); }
        [ -n "$ref" ] || ref="$wsref"   # last resort: target the workspace itself
        [ -n "$ref" ] || die "new-workspace returned no ref"
        placement="workspace"
        set -- --surface "$ref"
        [ -n "$wsref" ] && set -- --workspace "$wsref" "$@"
        "$CMUX" rename-tab "$@" "wk-$id-$label" 2>/dev/null || true
        ;;
      *) die "unknown layout: $layout (split|workspace)" ;;
    esac
    # workspace context for this worker's surface: grid tiles carry it as
    # tile_ws, workspace-layout workers carry it as wsref
    ws="${tile_ws:-${wsref:-}}"
    kickoff "$ref" "$id" "$ws"
    # honest status: only report running if claude's UI is actually on screen
    if screen_has "$ref" "$CLAUDE_UI" "$ws"; then
      log_manifest "$id" "$ref" "$cwd" "$model" "running" "$layout" "$ws" "$placement"
      echo "$ref"
    else
      log_manifest "$id" "$ref" "$cwd" "$model" "FAILED-TO-BOOT" "$layout" "$ws" "$placement"
      die "worker $id pane created ($ref) but claude did not boot — check the pane, then respawn or steer manually"
    fi
    ;;

  await)
    [ $# -ge 1 ] || die "await needs: id [timeout]"
    id="$1"; timeout="${2:-1800}"
    wt=$(field_of "$id" worktree); report="$wt/.fleet/$id/report.md"
    stamp="$FLEET_DIR/$id/.spawn-stamp"
    # A report counts as THIS attempt's only if it postdates the spawn stamp.
    # Without this, a leftover report.md from a previous run with the same id
    # makes the file-first check fire immediately and await returns early.
    report_fresh() {
      [ -f "$report" ] || return 1
      [ -f "$stamp" ] || return 0   # pre-stamp manifest entry — trust the file
      [ -n "$(find "$report" -newer "$stamp" 2>/dev/null)" ]
    }
    # wait-for signals are EPHEMERAL — one fired before we listen is lost forever.
    # The report file is the durable truth; the signal is only a wake-up. So:
    # check the file first, then listen in short slices, re-checking between each.
    elapsed=0; result=""
    while [ "$elapsed" -lt "$timeout" ]; do
      if report_fresh; then result="done: report present"; break; fi
      if "$CMUX" wait-for "wk-$id-done" --timeout 15 >/dev/null 2>&1; then
        result="done: signal received"; break
      fi
      elapsed=$((elapsed + 15))
    done
    [ -z "$result" ] && report_fresh && result="done: report present"
    if [ -n "$result" ]; then
      echo "$result"
    else
      wsref=$(field_of "$id" wsref)
      if [ -n "$wsref" ]; then
        echo "TIMEOUT: no signal, no report — probe with: cmux read-screen --workspace $wsref --surface $(field_of "$id" ref) --lines 40" >&2
      else
        echo "TIMEOUT: no signal, no report — probe with: cmux read-screen --surface $(field_of "$id" ref) --lines 40" >&2
      fi
      exit 2
    fi
    # carry wsref forward — field_of takes the LAST manifest entry, so without
    # this, cleanup's later close-surface would see an empty workspace context
    log_manifest "$id" "$(field_of "$id" ref)" "$wt" "-" "done" "$(field_of "$id" layout)" "$(field_of "$id" wsref)" "$(field_of "$id" placement)"
    ;;

  report)
    [ $# -ge 1 ] || die "report needs: id"
    wt=$(field_of "$1" worktree); cat "$wt/.fleet/$1/report.md" 2>/dev/null || die "no report for $1"
    ;;

  steer)
    [ $# -ge 2 ] || die "steer needs: id message"
    ref=$(field_of "$1" ref); [ -n "$ref" ] || die "unknown worker: $1"
    wsref=$(field_of "$1" wsref); msg="$2"
    set -- --surface "$ref"
    [ -n "$wsref" ] && set -- --workspace "$wsref" "$@"
    "$CMUX" send "$@" "$msg"
    "$CMUX" send-key "$@" enter
    ;;

  status)
    [ -f "$MANIFEST" ] || { echo "no fleet"; exit 0; }
    awk -F'"' '{ids[$4]=$0} END{for (i in ids) print ids[i]}' "$MANIFEST"
    "$CMUX" tree --all 2>/dev/null | grep -i "wk-" || true
    ;;

  cleanup)
    [ $# -ge 1 ] || die "cleanup needs: id | --all"
    ids="$1"; rc=0
    if [ "$1" = "--all" ]; then
      ids=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$MANIFEST" 2>/dev/null | sort -u)
      G=$(cat "$FLEET_DIR/.group" 2>/dev/null || true)
      if [ -n "$G" ]; then   # dissolve; orchestrator survives as anchor
        if "$CMUX" workspace-group ungroup "$G" >/dev/null 2>&1; then
          echo "dissolved group $G (member workspaces preserved)"
        else
          echo "warn: could not dissolve group $G" >&2
        fi
      fi
      # Reclaim the empty header workspace cmux minted for the group; ungroup
      # preserves it as a stray otherwise. Verified against the tree like any
      # other close — never reported as reclaimed unless it actually went away.
      A=$(cat "$FLEET_DIR/.anchor" 2>/dev/null || true)
      [ -z "$A" ] && [ -n "$G" ] && A=$(group_anchor "$G")   # group predates .anchor tracking
      if [ -n "$A" ] && [ "$A" != "${CMUX_WORKSPACE_ID:-}" ] && ref_alive "$A"; then
        "$CMUX" close-workspace --workspace "$A" >/dev/null 2>&1 || true
        if verify_gone "$A"; then
          echo "reclaimed group header workspace $A"
        else
          echo "FAILED to reclaim group header workspace $A" >&2
          rc=1
        fi
      fi
      rm -f "$FLEET_DIR/.anchor" "$FLEET_DIR/.tiles" "$FLEET_DIR/.group"
    fi
    for id in $ids; do
      ref=$(field_of "$id" ref); wt=$(field_of "$id" worktree); layout=$(field_of "$id" layout)
      wsref=$(field_of "$id" wsref); placement=$(field_of "$id" placement)
      [ -z "$layout" ] && layout="workspace"   # pre-layout manifest entries were workspace mode
      # Legacy manifests predate `placement`: infer it from layout, where only an
      # explicit workspace layout meant "the worker owns its own workspace".
      if [ -z "$placement" ]; then
        if [ "$layout" = "workspace" ]; then placement="workspace"; else placement="surface"; fi
      fi
      if [ -z "$ref" ]; then
        echo "skipped $id (no ref in manifest)" >&2
        continue
      fi
      # Already gone (earlier cleanup, or a human closed the pane) — not a failure.
      if ! ref_alive "$ref"; then
        log_manifest "$id" "$ref" "${wt:-?}" "-" "cleaned" "$layout" "$wsref" "$placement"
        echo "closed $id ($ref, already gone)"
        continue
      fi
      # `|| cw_rc=$?`, never a bare call: under set -e a nonzero return from a
      # standalone statement aborts the script, which would kill the honest
      # FAILED report this whole command exists to produce.
      cw_rc=0; close_worker "$ref" "$wsref" "$placement" || cw_rc=$?
      check="$CLOSE_CHECK"; err="$CLOSE_ERR"
      # VERIFY against cmux tree — the close command's own exit status is not
      # evidence. Report "closed" only for something the tree says is gone.
      if [ "$cw_rc" -eq 0 ]; then
        drop_tile "$ref"
        log_manifest "$id" "$ref" "${wt:-?}" "-" "cleaned" "$layout" "$wsref" "$placement"
        echo "closed $id ($check)"
      else
        log_manifest "$id" "$ref" "${wt:-?}" "-" "CLEANUP-FAILED" "$layout" "$wsref" "$placement"
        echo "FAILED to close $id ($check) — still present in cmux tree${err:+; cmux said: $err}" >&2
        rc=1
      fi
      if [ -n "$wt" ] && command -v treehouse >/dev/null 2>&1; then
        treehouse return "$wt" 2>/dev/null || true
      fi
    done
    [ "$rc" -eq 0 ] || die "cleanup incomplete — see FAILED lines above; cmux tree is ground truth"
    ;;

  *)
    die "unknown command '${cmd:-}' — see header for usage"
    ;;
esac
