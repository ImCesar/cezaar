#!/bin/sh
# Tests for scripts/fleet. Real git and the real `room` CLI in temp dirs; stub hc/herdr-app/claude.
HERE=$(cd "$(dirname "$0")" && pwd)
PLUGIN=$(cd "$HERE/.." && pwd)
FLEET="$PLUGIN/scripts/fleet"
ROOMS_SCRIPTS=$(cd "$PLUGIN/../rooms/scripts" && pwd)
FAILS=0

fresh() {
  T=$(mktemp -d)
  export APP_FLEET_HOME="$T/home" STUB_LOG="$T/stub.log" STUB_DIR="$T/stub" ROOMS_CONFIG_DIR="$T/roomscfg"
  export PATH="$HERE/stubs:$ROOMS_SCRIPTS:$ORIG_PATH"
  unset STUB_HERDR_STATUS STUB_FAIL STUB_FAIL_ROOMS_TAB STUB_HC_KILL_STATUS STUB_HC_RUN_FAIL_AT APP_FLEET_ROSTER ROOM_ID ROOMS_ROOT HC_TERMINAL_ID HC_SCOPE
  mkdir -p "$STUB_DIR" "$ROOMS_CONFIG_DIR"
  printf '{"operator":"cesar","quietMinutes":10}\n' > "$ROOMS_CONFIG_DIR/config.json"
  REPO="$T/repo"; mkdir -p "$REPO"
  (cd "$REPO" && git init -q -b main && printf 'one\ntwo\n' > f.txt && git add . \
    && git -c user.email=t@t -c user.name=t commit -qm init)
}
ok() { echo "ok $1"; }
fail() { echo "not ok $1: $2"; FAILS=$((FAILS + 1)); }
jq_py() { python3 -I -c "import sys,json; d=json.load(sys.stdin); print($1)"; }
ORIG_PATH=$PATH

# A run.json written directly, for tests of commands that read runs. $2: the lead's terminal (optional).
seed_run() {
  mkdir -p "$APP_FLEET_HOME/runs/$1/rooms"
  lt=null; [ -n "$2" ] && lt="\"$2\""
  printf '{"run":"%s","repo":"%s","stage":"execution","base":"main","integration":"fleet/%s","space":"sp1","leadTab":null,"leadTerminal":%s,"maxThreads":4,"verify":null,"teardown":null,"architecture":null,"threads":{}}\n' \
    "$1" "$REPO" "$1/integration" "$lt" > "$APP_FLEET_HOME/runs/$1/run.json"
}

t_status_of_missing_run_exits_3() {
  fresh
  "$FLEET" status nope >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && ok status_of_missing_run_exits_3 || fail status_of_missing_run_exits_3 "rc=$rc"
}

t_config_sets_and_status_shows() {
  fresh; seed_run r1
  "$FLEET" config r1 maxThreads 2 >/dev/null 2>&1 && "$FLEET" config r1 verify "make test" >/dev/null 2>&1 || { fail config_sets_and_status_shows "config failed"; return; }
  got=$("$FLEET" status r1 --json 2>/dev/null | jq_py "(d['maxThreads'], d['verify'])")
  [ "$got" = "(2, 'make test')" ] && ok config_sets_and_status_shows || fail config_sets_and_status_shows "got $got"
}

t_config_rejects_unknown_key() {
  fresh; seed_run r1
  "$FLEET" config r1 color blue >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && ok config_rejects_unknown_key || fail config_rejects_unknown_key "rc=$rc"
}

t_roster_check_passes() {
  fresh
  out=$("$FLEET" roster check 2>&1); rc=$?
  [ "$rc" = 0 ] && ok roster_check_passes || fail roster_check_passes "rc=$rc $out"
}

t_roster_check_catches_missing_persona() {
  fresh
  cp -R "$PLUGIN/roster" "$T/roster" 2>/dev/null && rm -f "$T/roster/personas/runner.md"
  out=$(APP_FLEET_ROSTER="$T/roster" "$FLEET" roster check 2>&1); rc=$?
  case $out in *runner*) named=1 ;; *) named=0 ;; esac
  [ "$rc" = 3 ] && [ "$named" = 1 ] && ok roster_check_catches_missing_persona || fail roster_check_catches_missing_persona "rc=$rc out=$out"
}

t_personas_have_no_old_verbs() {
  fresh
  hits=$(grep -l -E 'herdr-fleet\.sh|herdr agent|\bawait\b|\btell\b|report\.md freshness|FLEET_HOME' "$PLUGIN"/roster/personas/*.md "$PLUGIN"/roster/norms.md 2>/dev/null)
  [ -d "$PLUGIN/roster/personas" ] && [ -z "$hits" ] && ok personas_have_no_old_verbs || fail personas_have_no_old_verbs "hits=$hits"
}

t_compose_builder() {
  fresh; seed_run r1
  out=$("$FLEET" _compose r1 t1-builder builder t1 2>&1) || { fail compose_builder "rc=$? $out"; return; }
  prompt=$(printf '%s' "$out" | jq_py "d['prompt_path']"); settings=$(printf '%s' "$out" | jq_py "d['settings_path']")
  last=$(printf '%s' "$out" | jq_py "d['argv'][-1]"); model=$(printf '%s' "$out" | jq_py "d['argv'][d['argv'].index('--model')+1]")
  rid=$(jq_py "d['env']['ROOM_ID']" < "$settings")
  want_model=$(sed -n 's/^model: *//p' "$PLUGIN/roster/personas/builder.md" | head -1)
  grep -q "Review bar" "$prompt"; bar=$?
  case $last in "You are t1-builder."*) first=1 ;; *) first=0 ;; esac
  [ "$rid" = t1-builder ] && [ "$model" = "$want_model" ] && [ "$first" = 1 ] && [ "$bar" != 0 ] \
    && grep -q "t1-builder" "$prompt" && grep -q -i "mention" "$prompt" \
    && ok compose_builder || fail compose_builder "rid=$rid model=$model/$want_model first=$first bar=$bar"
}

t_compose_reviewer_has_review_bar() {
  fresh; seed_run r1
  prompt=$("$FLEET" _compose r1 t1-reviewer reviewer t1 2>/dev/null | jq_py "d['prompt_path']")
  first_line=$(head -1 "$PLUGIN/roster/policy/review-bar.md")
  grep -q -F "$first_line" "$prompt" && ok compose_reviewer_has_review_bar || fail compose_reviewer_has_review_bar "no review bar in $prompt"
}

t_compose_includes_memory_capped() {
  fresh; seed_run r1
  mkdir -p "$APP_FLEET_HOME/memory/builder"
  python3 -I -c "print('M' * 10240, end='')" > "$APP_FLEET_HOME/memory/builder/MEMORY.md"
  prompt=$("$FLEET" _compose r1 t1-builder builder t1 2>/dev/null | jq_py "d['prompt_path']")
  n=$(grep -o 'MMMMMMMM*' "$prompt" | awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }')
  [ "$n" -gt 0 ] && [ "$n" -le 4096 ] && ok compose_includes_memory_capped || fail compose_includes_memory_capped "M count=$n"
}

t_compose_runner_grants_verify() {
  fresh; seed_run r1
  "$FLEET" config r1 verify "make verify" >/dev/null 2>&1; "$FLEET" config r1 teardown "make down" >/dev/null 2>&1
  settings=$("$FLEET" _compose r1 runner-verify-w1 runner verify-w1 2>/dev/null | jq_py "d['settings_path']")
  got=$(jq_py "sorted(d['permissions']['allow'])" < "$settings")
  case $got in *"Bash(make verify)"*"Bash(make down)"*|*"Bash(make down)"*"Bash(make verify)"*) ok compose_runner_grants_verify ;; *) fail compose_runner_grants_verify "got $got" ;; esac
}

brief() { printf '# Task %s\nDo the thing.\n' "$1" > "$T/$1.brief.md"; echo "$T/$1.brief.md"; }

# Members run under hc, whose PATH is not the operator's: nvm's node, say, is missing there.
t_members_get_the_runs_path() {
  fresh; seed_run r1
  python3 -I -c "import json,sys; p=sys.argv[1]; d=json.load(open(p)); d['path']='/nvm/bin:/usr/bin:/bin'; json.dump(d, open(p,'w'))" "$APP_FLEET_HOME/runs/r1/run.json"
  out=$("$FLEET" _compose r1 t1-builder builder t1 2>/dev/null)
  settings=$(printf '%s' "$out" | jq_py "d['settings_path']")
  env_path=$(jq_py "d['env'].get('PATH')" < "$settings")
  in_argv=$(printf '%s' "$out" | jq_py "'PATH=/nvm/bin:/usr/bin:/bin' in d['argv']")
  [ "$env_path" = /nvm/bin:/usr/bin:/bin ] && [ "$in_argv" = True ] && ok members_get_the_runs_path || fail members_get_the_runs_path "env=$env_path argv=$in_argv"
}

t_lead_records_the_operators_path() {
  fresh
  PATH="$PATH:/nvm/bin" "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1; rc=$?
  got=$(jq_py "d.get('path', '')" < "$APP_FLEET_HOME/runs/p1/run.json" 2>/dev/null)
  case $got in *:/nvm/bin) [ "$rc" = 0 ] && ok lead_records_the_operators_path || fail lead_records_the_operators_path "rc=$rc" ;; *) fail lead_records_the_operators_path "path=$got" ;; esac
}

t_resume_records_path_for_old_run() {
  fresh; seed_run r1 t9
  PATH="$PATH:/nvm/bin" "$FLEET" lead r1 >/dev/null 2>&1; rc=$?
  got=$(jq_py "d.get('path', '')" < "$APP_FLEET_HOME/runs/r1/run.json" 2>/dev/null)
  case $got in *:/nvm/bin) [ "$rc" = 0 ] && ok resume_records_path_for_old_run || fail resume_records_path_for_old_run "rc=$rc" ;; *) fail resume_records_path_for_old_run "rc=$rc path=$got" ;; esac
}

# The lead wrote its own curate brief and sent the curator to persona files: fleet writes it now.
t_curate_writes_brief_and_opens_thread() {
  fresh; seed_run r1 t9
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  "$FLEET" curate r1 --note "verify shell had no node" >/dev/null 2>&1; rc=$?
  b="$APP_FLEET_HOME/runs/r1/briefs/curate.md"
  m="$APP_FLEET_HOME/memory"
  [ "$rc" = 0 ] && grep -q "^hc run.*--name curate-curator " "$STUB_LOG" \
    && grep -q "rooms/t1/log.jsonl" "$b" && grep -q "$m/builder/MEMORY.md" "$b" && grep -q "$m/reviewer/MEMORY.md" "$b" \
    && grep -q "$m/lead/MEMORY.md" "$b" && grep -q "verify shell had no node" "$b" && grep -q "never edit the persona files" "$b" \
    && ok curate_writes_brief_and_opens_thread || fail curate_writes_brief_and_opens_thread "rc=$rc brief=$(head -c 400 "$b" 2>/dev/null)"
}

t_curate_twice_gets_new_name() {
  fresh; seed_run r1 t9
  "$FLEET" curate r1 >/dev/null 2>&1; "$FLEET" curate r1 >/dev/null 2>&1; rc=$?
  got=$(jq_py "sorted(t for t in d['threads'] if t.startswith('curate'))" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$rc" = 0 ] && [ "$got" = "['curate', 'curate-2']" ] && ok curate_twice_gets_new_name || fail curate_twice_gets_new_name "rc=$rc got=$got"
}

# `fleet try`: put the run's merged work where the operator can use it live, before it merges.
t_try_runs_in_the_integration_worktree() {
  fresh; seed_run r1
  "$FLEET" config r1 try "pwd -P > \"$T/try.out\"" >/dev/null 2>&1
  "$FLEET" try r1 >/dev/null 2>&1; rc=$?
  want="$(cd "$REPO" && pwd -P)/.worktrees/r1/_integration"
  [ "$rc" = 0 ] && [ "$(cat "$T/try.out" 2>/dev/null)" = "$want" ] && ok try_runs_in_the_integration_worktree || fail try_runs_in_the_integration_worktree "rc=$rc got=$(cat "$T/try.out" 2>/dev/null)"
}

t_try_without_command_exits_3() {
  fresh; seed_run r1
  "$FLEET" try r1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && ok try_without_command_exits_3 || fail try_without_command_exits_3 "rc=$rc"
}

t_try_failure_exits_4() {
  fresh; seed_run r1
  "$FLEET" config r1 try "exit 7" >/dev/null 2>&1
  "$FLEET" try r1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 4 ] && ok try_failure_exits_4 || fail try_failure_exits_4 "rc=$rc"
}

t_lead_takes_try() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" --try "make try" >/dev/null 2>&1; rc=$?
  got=$(jq_py "d.get('try')" < "$APP_FLEET_HOME/runs/p1/run.json" 2>/dev/null)
  shown=$("$FLEET" status p1 2>/dev/null | grep -c "try: make try")
  [ "$rc" = 0 ] && [ "$got" = "make try" ] && [ "$shown" = 1 ] && ok lead_takes_try || fail lead_takes_try "rc=$rc got=$got shown=$shown"
}

t_thread_open_creates_everything() {
  fresh; seed_run r1 t9
  out=$("$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" 2>&1) || { fail thread_open_creates_everything "rc=$? $out"; return; }
  wt="$REPO/.worktrees/r1/t1"
  br=$(git -C "$wt" branch --show-current 2>/dev/null)
  members=$(ROOMS_ROOT="$APP_FLEET_HOME/runs/r1/rooms" room ls --json | jq_py "{r['room']: r['members'] for r in d}")
  mem_t1=$(jq_py "sorted(m['id'] for m in d)" < "$APP_FLEET_HOME/runs/r1/rooms/t1/members.json")
  mem_ch=$(jq_py "sorted(m['id'] for m in d)" < "$APP_FLEET_HOME/runs/r1/rooms/execution/members.json")
  first=$(head -1 "$APP_FLEET_HOME/runs/r1/rooms/t1/log.jsonl" | jq_py "sorted(d['mentions'])")
  tabs=$(grep -c "do tab.new\|do pane.split" "$STUB_LOG"); runs=$(grep -c "^hc run" "$STUB_LOG")
  b=$(grep "^hc run.*--name t1-builder " "$STUB_LOG"); r=$(grep "^hc run.*--name t1-reviewer " "$STUB_LOG")
  flags=0; for f in "--parent t9" --outlive-parent --no-notify "--label rooms.room=t1" "--label rooms.id=t1-builder" "--label fleet.thread=t1" "--label fleet.run=r1"; do
    case $b in *"$f"*) ;; *) flags=$((flags + 1)) ;; esac; done
  case $r in *"--parent tm1 "*) rp=1 ;; *) rp=0 ;; esac
  state=$(jq_py "d['threads']['t1']['state']" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$br" = fleet/r1/t1 ] && [ "$mem_t1" = "['cesar', 't1-builder', 't1-reviewer']" ] \
    && case $mem_ch in *t1-builder*t1-reviewer*) true ;; *) false ;; esac \
    && [ -f "$APP_FLEET_HOME/runs/r1/briefs/t1.md" ] && [ "$first" = "['t1-builder', 't1-reviewer']" ] \
    && [ "$tabs" = 0 ] && [ "$runs" = 2 ] && [ "$flags" = 0 ] && [ "$rp" = 1 ] && [ "$state" = open ] \
    && ok thread_open_creates_everything || fail thread_open_creates_everything "br=$br t1=$mem_t1 ch=$mem_ch first=$first tabs=$tabs runs=$runs flags=$flags rp=$rp state=$state"
}

t_thread_open_refuses_duplicate_and_bad_names() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  before=$(wc -l < "$STUB_LOG" | tr -d ' ')
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; dup=$?
  "$FLEET" thread open r1 ../x --template build --brief "$(brief t1)" >/dev/null 2>&1; bad=$?
  after=$(wc -l < "$STUB_LOG" | tr -d ' ')
  [ "$dup" = 3 ] && [ "$bad" = 2 ] && [ ! -e "$REPO/.worktrees/x" ] && [ "$before" = "$after" ] \
    && ok thread_open_refuses_duplicate_and_bad_names || fail thread_open_refuses_duplicate_and_bad_names "dup=$dup bad=$bad calls $before->$after"
}

t_thread_open_respects_max_threads() {
  fresh; seed_run r1; "$FLEET" config r1 maxThreads 1 >/dev/null 2>&1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  "$FLEET" thread open r1 t2 --template build --brief "$(brief t2)" >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && [ ! -e "$REPO/.worktrees/r1/t2" ] && ok thread_open_respects_max_threads || fail thread_open_respects_max_threads "rc=$rc"
}

t_thread_open_from_another_thread() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  (cd "$REPO/.worktrees/r1/t1" && echo x > x.txt && git add x.txt && git -c user.email=t@t -c user.name=t commit -qm x)
  "$FLEET" thread open r1 t1-fix --template fix --brief "$(brief t1-fix)" --from t1 >/dev/null 2>&1 || { fail thread_open_from_another_thread "open failed"; return; }
  [ -f "$REPO/.worktrees/r1/t1-fix/x.txt" ] && ok thread_open_from_another_thread || fail thread_open_from_another_thread "fix branch lacks t1's commit"
}

t_thread_open_without_app_makes_nothing() {
  fresh; seed_run r1; export STUB_HERDR_STATUS=1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; rc=$?
  [ "$rc" = 4 ] && [ ! -e "$REPO/.worktrees/r1/t1" ] && [ ! -e "$APP_FLEET_HOME/runs/r1/rooms/t1" ] \
    && ok thread_open_without_app_makes_nothing || fail thread_open_without_app_makes_nothing "rc=$rc"
}

t_thread_open_undoes_on_spawn_failure() {
  fresh; seed_run r1; export STUB_HC_RUN_FAIL_AT=1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; rc=$?
  br=$(git -C "$REPO" branch --list fleet/r1/t1)
  thr=$(jq_py "list(d['threads'])" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$rc" = 4 ] && [ ! -e "$REPO/.worktrees/r1/t1" ] && [ -z "$br" ] && [ ! -e "$APP_FLEET_HOME/runs/r1/rooms/t1" ] && [ "$thr" = "[]" ] \
    && ok thread_open_undoes_on_spawn_failure || fail thread_open_undoes_on_spawn_failure "rc=$rc br=$br thr=$thr"
}

t_thread_close_archives_kills_and_removes() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  terms=$(jq_py "' '.join(d['threads']['t1']['terminals'])" < "$APP_FLEET_HOME/runs/r1/run.json")
  "$FLEET" thread close r1 t1 >/dev/null 2>&1; rc=$?
  kills=0; for t in $terms; do grep -q "hc kill $t" "$STUB_LOG" && kills=$((kills + 1)); done
  state=$(jq_py "d['threads']['t1']['state']" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$rc" = 0 ] && [ -e "$APP_FLEET_HOME/runs/r1/rooms/t1/archived" ] && [ "$kills" = 2 ] \
    && [ ! -e "$REPO/.worktrees/r1/t1" ] && [ "$state" = closed ] \
    && ok thread_close_archives_kills_and_removes || fail thread_close_archives_kills_and_removes "rc=$rc kills=$kills state=$state"
}

t_thread_close_tolerates_dead_terminals() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  export STUB_HC_KILL_STATUS=1 STUB_FAIL=tab.close
  "$FLEET" thread close r1 t1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && [ -e "$APP_FLEET_HOME/runs/r1/rooms/t1/archived" ] && ok thread_close_tolerates_dead_terminals || fail thread_close_tolerates_dead_terminals "rc=$rc"
}

t_thread_close_keeps_unmerged_worktree() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  (cd "$REPO/.worktrees/r1/t1" && echo y > y.txt && git add y.txt && git -c user.email=t@t -c user.name=t commit -qm y)
  out=$("$FLEET" thread close r1 t1 2>&1); rc=$?
  [ "$rc" = 0 ] && [ -d "$REPO/.worktrees/r1/t1" ] && case $out in *unmerged*|*kept*) true ;; *) false ;; esac \
    && ok thread_close_keeps_unmerged_worktree || fail thread_close_keeps_unmerged_worktree "rc=$rc out=$out"
}

t_cleanup_closes_all_and_keeps_integration_branch() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  "$FLEET" thread open r1 t2 --template build --brief "$(brief t2)" >/dev/null 2>&1
  "$FLEET" cleanup r1 --all >/dev/null 2>&1; rc=$?
  open=$(jq_py "[t for t, v in d['threads'].items() if v['state'] == 'open']" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$rc" = 0 ] && [ "$open" = "[]" ] && [ ! -e "$REPO/.worktrees/r1/_integration" ] \
    && [ -n "$(git -C "$REPO" branch --list fleet/r1/integration)" ] && [ -z "$(git -C "$REPO" branch --list fleet/r1/t1)" ] \
    && ok cleanup_closes_all_and_keeps_integration_branch || fail cleanup_closes_all_and_keeps_integration_branch "rc=$rc open=$open"
}

commit_in() { (cd "$1" && printf '%s\n' "$2" > "$3" && git add "$3" && git -c user.email=t@t -c user.name=t commit -qm "$2"); }

t_merge_clean() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  commit_in "$REPO/.worktrees/r1/t1" "feature one" one.txt
  "$FLEET" merge r1 t1 >/dev/null 2>&1; rc=$?
  has=$(git -C "$REPO" show fleet/r1/integration:one.txt 2>/dev/null)
  [ "$rc" = 0 ] && [ "$has" = "feature one" ] && ok merge_clean || fail merge_clean "rc=$rc has=$has"
}

t_merge_conflict_aborts() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  "$FLEET" thread open r1 t2 --template build --brief "$(brief t2)" >/dev/null 2>&1
  commit_in "$REPO/.worktrees/r1/t1" "from t1" f.txt
  commit_in "$REPO/.worktrees/r1/t2" "from t2" f.txt
  "$FLEET" merge r1 t1 >/dev/null 2>&1
  out=$("$FLEET" merge r1 t2 2>&1); rc=$?
  dirty=$(git -C "$REPO/.worktrees/r1/_integration" status --porcelain)
  [ "$rc" = 3 ] && case $out in *f.txt*) true ;; *) false ;; esac && [ -z "$dirty" ] \
    && ok merge_conflict_aborts || fail merge_conflict_aborts "rc=$rc out=$out dirty=$dirty"
}

t_merge_refuses_dirty_integration() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  echo edited >> "$REPO/.worktrees/r1/_integration/f.txt"
  "$FLEET" merge r1 t1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && ok merge_refuses_dirty_integration || fail merge_refuses_dirty_integration "rc=$rc"
}

t_verify_opens_runner_thread_on_integration() {
  fresh; seed_run r1
  "$FLEET" config r1 verify "make verify" >/dev/null 2>&1; "$FLEET" config r1 teardown "make down" >/dev/null 2>&1
  "$FLEET" verify r1 1 >/dev/null 2>&1; rc=$?
  b="$APP_FLEET_HOME/runs/r1/briefs/verify-w1.md"
  [ "$rc" = 0 ] && grep -q "^hc run.*--name verify-w1-runner " "$STUB_LOG" && grep -q -- "--cwd $REPO/.worktrees/r1/_integration" "$STUB_LOG" \
    && grep -q "make verify" "$b" && grep -q "make down" "$b" \
    && [ "$(jq_py "d['threads']['verify-w1']['members']" < "$APP_FLEET_HOME/runs/r1/run.json")" = "['verify-w1-runner']" ] \
    && ok verify_opens_runner_thread_on_integration || fail verify_opens_runner_thread_on_integration "rc=$rc"
}

t_verify_without_command_exits_3() {
  fresh; seed_run r1
  "$FLEET" verify r1 1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && ok verify_without_command_exits_3 || fail verify_without_command_exits_3 "rc=$rc"
}

arch() { printf '# Architecture\n\n- task one\n' > "$REPO/ARCHITECTURE.md"; echo "$REPO/ARCHITECTURE.md"; }

t_lead_new_run_sets_up() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" --verify "make verify" >/dev/null 2>&1; rc=$?
  rj="$APP_FLEET_HOME/runs/p1/run.json"
  lead=$(jq_py "[m for m in d if m['id'] == 'lead'][0].get('watchAll')" < "$APP_FLEET_HOME/runs/p1/rooms/execution/members.json" 2>/dev/null)
  [ "$rc" = 0 ] && [ -f "$rj" ] && [ "$lead" = True ] && grep -q "do space.new --name p1" "$STUB_LOG" \
    && grep -q -- "--tab lead" "$STUB_LOG" && grep -q '^\.worktrees/$' "$REPO/.git/info/exclude" \
    && [ "$(jq_py "d['verify']" < "$rj")" = "make verify" ] \
    && ok lead_new_run_sets_up || fail lead_new_run_sets_up "rc=$rc lead=$lead"
}

t_lead_without_app_makes_nothing() {
  fresh; export STUB_HERDR_STATUS=1
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1; rc=$?
  [ "$rc" = 4 ] && [ ! -e "$APP_FLEET_HOME/runs/p1" ] && ok lead_without_app_makes_nothing || fail lead_without_app_makes_nothing "rc=$rc"
}

t_lead_resume_keeps_state() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  "$FLEET" thread open p1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  before=$(jq_py "sorted(d['threads'])" < "$APP_FLEET_HOME/runs/p1/run.json")
  herdr-app do tab.close --id "$(jq_py "d['leadTab']" < "$APP_FLEET_HOME/runs/p1/run.json")" --confirmed true >/dev/null 2>&1
  jq_py "d['leadTerminal']" < "$APP_FLEET_HOME/runs/p1/run.json" > "$STUB_DIR/hc.dead"   # closing a tab ends its terminal
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  after=$(jq_py "sorted(d['threads'])" < "$APP_FLEET_HOME/runs/p1/run.json")
  [ "$rc" = 0 ] && [ "$before" = "['t1']" ] && [ "$after" = "$before" ] && grep -q "resuming" "$STUB_LOG" \
    && ok lead_resume_keeps_state || fail lead_resume_keeps_state "rc=$rc before=$before after=$after"
}

t_lead_rejects_non_git_repo() {
  fresh; mkdir -p "$T/plain"
  "$FLEET" lead p1 --repo "$T/plain" --architecture "$(arch)" >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && [ ! -e "$APP_FLEET_HOME/runs/p1" ] && ok lead_rejects_non_git_repo || fail lead_rejects_non_git_repo "rc=$rc"
}

t_install_links_and_refuses_regular_file() {
  fresh; export APP_FLEET_BIN_DIR="$T/bin"
  "$FLEET" install >/dev/null 2>&1; rc=$?
  link=$(cd "$T/bin" 2>/dev/null && python3 -I -c "import os;print(os.path.realpath('fleet'))")
  want=$(cd "$PLUGIN/scripts" && pwd -P)/fleet
  rm -f "$T/bin/fleet"; printf 'mine\n' > "$T/bin/fleet"
  "$FLEET" install >/dev/null 2>&1; rc2=$?
  [ "$rc" = 0 ] && [ "$link" = "$want" ] && [ "$rc2" != 0 ] && [ "$(cat "$T/bin/fleet")" = mine ] \
    && ok install_links_and_refuses_regular_file || fail install_links_and_refuses_regular_file "rc=$rc link=$link rc2=$rc2"
}

t_judge_thread_uses_disputed_worktree_and_plain_id() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  out=$("$FLEET" thread open r1 judge-t1 --template judge --brief "$(brief judge-t1)" 2>&1); rc=$?
  mem=$(jq_py "sorted(m['id'] for m in d)" < "$APP_FLEET_HOME/runs/r1/rooms/judge-t1/members.json" 2>/dev/null)
  folder=$(jq_py "d['threads']['judge-t1']['worktree']" < "$APP_FLEET_HOME/runs/r1/run.json" 2>/dev/null)
  [ "$rc" = 0 ] && [ "$mem" = "['cesar', 'judge-t1']" ] && [ "$folder" = "$REPO/.worktrees/r1/t1" ] \
    && [ -z "$(git -C "$REPO" branch --list 'fleet/r1/judge-t1')" ] \
    && ok judge_thread_uses_disputed_worktree_and_plain_id || fail judge_thread_uses_disputed_worktree_and_plain_id "rc=$rc mem=$mem folder=$folder out=$out"
}

t_compose_grants_run_dir() {
  fresh; seed_run r1
  settings=$("$FLEET" _compose r1 t1-builder builder t1 2>/dev/null | jq_py "d['settings_path']")
  rd=$(cd "$APP_FLEET_HOME/runs/r1" && pwd -P)
  got=$(jq_py "(d['permissions'].get('additionalDirectories'), [a for a in d['permissions']['allow'] if a.startswith('Edit(')])" < "$settings")
  case $got in *"$rd"*"Edit(/$rd/**)"*) ok compose_grants_run_dir ;; *) fail compose_grants_run_dir "got $got" ;; esac
}

t_thread_open_accepts_brief_already_in_run() {
  fresh; seed_run r1
  mkdir -p "$APP_FLEET_HOME/runs/r1/briefs"; printf '# t1\n' > "$APP_FLEET_HOME/runs/r1/briefs/t1.md"
  out=$("$FLEET" thread open r1 t1 --template build --brief "$APP_FLEET_HOME/runs/r1/briefs/t1.md" 2>&1); rc=$?
  [ "$rc" = 0 ] && ok thread_open_accepts_brief_already_in_run || fail thread_open_accepts_brief_already_in_run "rc=$rc $out"
}

t_thread_close_marks_members_gone_everywhere() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  "$FLEET" thread close r1 t1 >/dev/null 2>&1
  r="$APP_FLEET_HOME/runs/r1/rooms"
  ch=$(jq_py "d.get('state')" < "$r/execution/presence/t1-builder.json" 2>/dev/null)
  th=$(jq_py "d.get('state')" < "$r/t1/presence/t1-reviewer.json" 2>/dev/null)
  [ "$ch" = gone ] && [ "$th" = gone ] && ok thread_close_marks_members_gone_everywhere || fail thread_close_marks_members_gone_everywhere "channel=$ch thread=$th"
}

t_cleanup_deletes_branches_merged_into_integration() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  commit_in "$REPO/.worktrees/r1/t1" "feature one" one.txt
  "$FLEET" merge r1 t1 >/dev/null 2>&1 && "$FLEET" thread close r1 t1 >/dev/null 2>&1
  "$FLEET" cleanup r1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && [ -z "$(git -C "$REPO" branch --list fleet/r1/t1)" ] && [ -n "$(git -C "$REPO" branch --list fleet/r1/integration)" ] \
    && ok cleanup_deletes_branches_merged_into_integration || fail cleanup_deletes_branches_merged_into_integration "rc=$rc branches=$(git -C "$REPO" branch | tr '\n' ' ')"
}

t_parallel_opens_keep_all_threads() {
  fresh; seed_run r1
  for x in pa pb pc; do "$FLEET" thread open r1 $x --template build --brief "$(brief $x)" >/dev/null 2>&1 & done; wait
  got=$(jq_py "sorted(d['threads'])" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$got" = "['pa', 'pb', 'pc']" ] && ok parallel_opens_keep_all_threads || fail parallel_opens_keep_all_threads "got $got"
}

t_close_keeps_dirty_worktree() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  echo forgotten > "$REPO/.worktrees/r1/t1/new.txt"
  "$FLEET" thread close r1 t1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && [ -f "$REPO/.worktrees/r1/t1/new.txt" ] && ok close_keeps_dirty_worktree || fail close_keeps_dirty_worktree "rc=$rc"
}

t_merge_refuses_dirty_thread() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  echo changed >> "$REPO/.worktrees/r1/t1/f.txt"
  "$FLEET" merge r1 t1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && ok merge_refuses_dirty_thread || fail merge_refuses_dirty_thread "rc=$rc"
}

t_undo_kills_spawned_members() {
  fresh; seed_run r1; export STUB_HC_RUN_FAIL_AT=2
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; rc=$?
  ch=$(jq_py "[m['id'] for m in d]" < "$APP_FLEET_HOME/runs/r1/rooms/execution/members.json" 2>/dev/null)
  [ "$rc" = 4 ] && grep -q "^hc kill tm1" "$STUB_LOG" && case $ch in *t1-builder*) false ;; *) true ;; esac \
    && ok undo_kills_spawned_members || fail undo_kills_spawned_members "rc=$rc ch=$ch"
}

t_verify_twice_gets_new_name() {
  fresh; seed_run r1; "$FLEET" config r1 verify "make verify" >/dev/null 2>&1
  "$FLEET" verify r1 1 >/dev/null 2>&1; "$FLEET" verify r1 1 >/dev/null 2>&1; rc=$?
  got=$(jq_py "sorted(t for t in d['threads'] if t.startswith('verify'))" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$rc" = 0 ] && [ "$got" = "['verify-w1', 'verify-w1-2']" ] && ok verify_twice_gets_new_name || fail verify_twice_gets_new_name "rc=$rc got=$got"
}

t_reserved_names_refused() {
  fresh; seed_run r1
  "$FLEET" thread open r1 execution --template build --brief "$(brief x)" >/dev/null 2>&1; a=$?
  "$FLEET" thread open r1 verify-w2 --template build --brief "$(brief x)" >/dev/null 2>&1; b=$?
  "$FLEET" thread open r1 judge-zz --template build --brief "$(brief x)" >/dev/null 2>&1; c=$?
  "$FLEET" thread open r1 cesar --template build --brief "$(brief x)" >/dev/null 2>&1; d=$?
  [ "$a$b$c$d" = 2222 ] && ok reserved_names_refused || fail reserved_names_refused "codes=$a$b$c$d"
}

# The thread's first post, as JSON fields: text, mentions, links.
root_of() { head -1 "$APP_FLEET_HOME/runs/r1/rooms/$1/log.jsonl"; }

t_root_post_full_brief() {
  fresh; seed_run r1
  b="$T/t1.brief.md"
  printf '# t1: make the widget readable\nGoal: widgets read well.\nScope: in - widget.py. out - the rest.\nInterfaces and contracts (quoted verbatim, task 3):\n- secret contract text\nNotes: secret notes\nDone when:\n- [ ] widgets read well\n- [ ] tests pass\nReport: somewhere\n' > "$b"
  "$FLEET" thread open r1 t1 --template build --brief "$b" >/dev/null 2>&1
  dest=$(root_of t1 | jq_py "d['links'][0]"); case $dest in */runs/r1/briefs/t1.md) ;; *) dest="bad link $dest" ;; esac
  got=$(root_of t1 | jq_py "(sorted(d['mentions']), d['links'], d['text'])")
  want=$(printf '%s' "(['t1-builder', 't1-reviewer'], ['$dest'], '@t1-builder @t1-reviewer — **make the widget readable**\\n\\n**Goal:** widgets read well.\\n**Scope:** in - widget.py. out - the rest.\\n**Done when:**\\n- [ ] widgets read well\\n- [ ] tests pass\\n\\nFull brief: \`$dest\`')")
  [ "$got" = "$want" ] && ok root_post_full_brief || fail root_post_full_brief "got $got"
}

t_root_post_title_only_brief() {
  fresh; seed_run r1
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  dest=$(root_of t1 | jq_py "d['links'][0]"); case $dest in */runs/r1/briefs/t1.md) ;; *) dest="bad link $dest" ;; esac
  got=$(root_of t1 | jq_py "d['text']")
  want=$(printf '@t1-builder @t1-reviewer — **Task t1**\n\nFull brief: `%s`' "$dest")
  [ "$got" = "$want" ] && ok root_post_title_only_brief || fail root_post_title_only_brief "got $got"
}

t_root_post_oversized_falls_back() {
  fresh; seed_run r1
  b="$T/t1.brief.md"
  { printf '# t1: big one\nGoal: '; python3 -I -c "print('x' * 5000)"; printf 'Done when:\n- [ ] done\n'; } > "$b"
  "$FLEET" thread open r1 t1 --template build --brief "$b" >/dev/null 2>&1; rc=$?
  dest=$(root_of t1 | jq_py "d['links'][0]"); case $dest in */runs/r1/briefs/t1.md) ;; *) dest="bad link $dest" ;; esac
  got=$(root_of t1 | jq_py "(sorted(d['mentions']), d['text'])")
  want="(['t1-builder', 't1-reviewer'], '@t1-builder @t1-reviewer — **big one**\\n\\nFull brief: \`$dest\`')"
  [ "$rc" = 0 ] && [ "$got" = "$want" ] && ok root_post_oversized_falls_back || fail root_post_oversized_falls_back "rc=$rc got $got"
}

t_verify_thread_root_from_title() {
  fresh; seed_run r1; "$FLEET" config r1 verify "make verify" >/dev/null 2>&1
  "$FLEET" verify r1 1 >/dev/null 2>&1
  got=$(root_of verify-w1 | jq_py "(d['mentions'], d['text'].split(chr(10))[0])")
  [ "$got" = "(['verify-w1-runner'], '@verify-w1-runner — **Verify wave 1**')" ] && ok verify_thread_root_from_title || fail verify_thread_root_from_title "got $got"
}

t_research_answers_go_to_the_askers_thread() {
  fresh
  grep -q -- '--as <task>-researcher' "$PLUGIN/roster/personas/researcher.md" && grep -q -i "asker" "$PLUGIN/roster/personas/lead.md" \
    && ok research_answers_go_to_the_askers_thread || fail research_answers_go_to_the_askers_thread "researcher must post into the asker's thread room"
}

t_resume_with_live_lead_selects_it() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  n1=$(grep -c "do tab.new --name lead\|do space.new" "$STUB_LOG")
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  n2=$(grep -c "do tab.new --name lead\|do space.new" "$STUB_LOG")
  [ "$rc" = 0 ] && [ "$n1" = "$n2" ] && grep -q "do tab.select" "$STUB_LOG" && ok resume_with_live_lead_selects_it || fail resume_with_live_lead_selects_it "rc=$rc $n1->$n2"
}

t_resume_after_space_closed_makes_new_space() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  sp=$(jq_py "d['space']" < "$APP_FLEET_HOME/runs/p1/run.json")
  herdr-app do space.close --id "$sp" --confirmed true >/dev/null 2>&1
  jq_py "d['leadTerminal']" < "$APP_FLEET_HOME/runs/p1/run.json" > "$STUB_DIR/hc.dead"   # closing a space ends its terminals
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  sp2=$(jq_py "d['space']" < "$APP_FLEET_HOME/runs/p1/run.json")
  [ "$rc" = 0 ] && [ "$sp2" != "$sp" ] && ok resume_after_space_closed_makes_new_space || fail resume_after_space_closed_makes_new_space "rc=$rc $sp->$sp2"
}

t_cleanup_removes_worktree_merged_via_followup() {
  fresh; seed_run r1
  "$FLEET" thread open r1 q --template build --brief "$(brief q)" >/dev/null 2>&1
  commit_in "$REPO/.worktrees/r1/q" "q work" q.txt
  "$FLEET" thread close r1 q >/dev/null 2>&1
  "$FLEET" thread open r1 q-2 --template build --brief "$(brief q-2)" --from q >/dev/null 2>&1
  "$FLEET" merge r1 q-2 >/dev/null 2>&1 && "$FLEET" thread close r1 q-2 >/dev/null 2>&1
  "$FLEET" cleanup r1 >/dev/null 2>&1
  [ ! -e "$REPO/.worktrees/r1/q" ] && [ -z "$(git -C "$REPO" branch --list fleet/r1/q)" ] \
    && ok cleanup_removes_worktree_merged_via_followup || fail cleanup_removes_worktree_merged_via_followup "q worktree or branch left"
}

t_merge_refuses_detached_integration() {
  fresh; seed_run r1
  "$FLEET" thread open r1 m --template build --brief "$(brief m)" >/dev/null 2>&1
  commit_in "$REPO/.worktrees/r1/m" "m work" m.txt
  git -C "$REPO/.worktrees/r1/_integration" checkout -q --detach
  "$FLEET" merge r1 m >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && ok merge_refuses_detached_integration || fail merge_refuses_detached_integration "rc=$rc"
}

t_lead_refuses_detached_repo_without_base() {
  fresh; git -C "$REPO" checkout -q --detach
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1; rc=$?
  "$FLEET" lead p2 --repo "$REPO" --architecture "$REPO/ARCHITECTURE.md" --base main >/dev/null 2>&1; rc2=$?
  [ "$rc" = 3 ] && [ "$rc2" = 0 ] && ok lead_refuses_detached_repo_without_base || fail lead_refuses_detached_repo_without_base "rc=$rc rc2=$rc2"
}

t_compose_settings_work_unattended() {
  fresh; seed_run r1; "$FLEET" config r1 verify "make verify" >/dev/null 2>&1
  b=$("$FLEET" _compose r1 t1-builder builder t1 2>/dev/null | jq_py "d['settings_path']")
  c=$("$FLEET" _compose r1 curator-curate curator curate 2>/dev/null | jq_py "d['settings_path']")
  r=$("$FLEET" _compose r1 runner-v runner v 2>/dev/null | jq_py "d['settings_path']")
  mode=$(jq_py "d['permissions'].get('defaultMode')" < "$b")
  edit=$(jq_py "[a for a in d['permissions']['allow'] if a.startswith('Edit(')][0]" < "$b")
  mem=$(jq_py "any(p.endswith('/memory') for p in d['permissions']['additionalDirectories'])" < "$c")
  run=$(jq_py "'Bash(make verify *)' in d['permissions']['allow']" < "$r")
  case $edit in "Edit(//"*) e=1 ;; *) e=0 ;; esac
  [ "$mode" = acceptEdits ] && [ "$e" = 1 ] && [ "$mem" = True ] && [ "$run" = True ] \
    && ok compose_settings_work_unattended || fail compose_settings_work_unattended "mode=$mode edit=$edit mem=$mem run=$run"
}

t_status_shows_verify_and_teardown() {
  fresh; seed_run r1; "$FLEET" config r1 verify "make verify" >/dev/null 2>&1
  out=$("$FLEET" status r1 2>&1)
  case $out in *"verify: make verify"*"teardown: "*) ok status_shows_verify_and_teardown ;; *) fail status_shows_verify_and_teardown "out=$out" ;; esac
}

t_merge_ignores_untracked_cache_in_integration() {
  fresh; seed_run r1
  "$FLEET" thread open r1 m --template build --brief "$(brief m)" >/dev/null 2>&1
  commit_in "$REPO/.worktrees/r1/m" "m work" m.txt
  mkdir -p "$REPO/.worktrees/r1/_integration/__pycache__"; echo x > "$REPO/.worktrees/r1/_integration/__pycache__/c.pyc"
  "$FLEET" merge r1 m >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && ok merge_ignores_untracked_cache_in_integration || fail merge_ignores_untracked_cache_in_integration "rc=$rc"
}

t_long_task_name_refused() {
  fresh; seed_run r1
  "$FLEET" thread open r1 abcdefghijklmnopqrstuv --template build --brief "$(brief x)" >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && [ ! -e "$REPO/.worktrees/r1/abcdefghijklmnopqrstuv" ] && ok long_task_name_refused || fail long_task_name_refused "rc=$rc"
}

t_member_parent_is_lead_terminal() {
  fresh; seed_run r1 t9
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; rc=$?
  first=$(grep "^hc run" "$STUB_LOG" | head -1)
  case $first in *"--parent t9 "*) p=1 ;; *) p=0 ;; esac
  [ "$rc" = 0 ] && [ "$p" = 1 ] && ! grep -q "terminal.keep" "$STUB_LOG" && ok member_parent_is_lead_terminal || fail member_parent_is_lead_terminal "rc=$rc first=$first"
}

t_members_without_live_lead_get_tabs() {
  fresh; seed_run r1 t9; echo t9 > "$STUB_DIR/hc.dead"
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; rc=$?
  first=$(grep "^hc run" "$STUB_LOG" | head -1)
  case $first in *--no-parent*) p=1 ;; *) p=0 ;; esac
  [ "$rc" = 0 ] && [ "$p" = 1 ] && grep -q "do terminal.keep --terminal tm1" "$STUB_LOG" \
    && ok members_without_live_lead_get_tabs || fail members_without_live_lead_get_tabs "rc=$rc first=$first"
}

t_member_name_collision_gets_run_suffix() {
  fresh; seed_run r1 t9; echo "tx5 t1-builder" > "$STUB_DIR/hc.ls.extra"
  "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && grep -q "^hc run.*--name t1-builder-r1 " "$STUB_LOG" && grep -q "^hc run.*--name t1-reviewer " "$STUB_LOG" \
    && ok member_name_collision_gets_run_suffix || fail member_name_collision_gets_run_suffix "rc=$rc"
}

t_lead_is_shell_hosted_with_session() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1; rc=$?
  rj="$APP_FLEET_HOME/runs/p1/run.json"
  line=$(grep "do space.new --name p1" "$STUB_LOG")
  sess=$(jq_py "d.get('leadSession') or ''" < "$rj"); term=$(jq_py "d.get('leadTerminal') or ''" < "$rj")
  case $line in *'"-lc"'*"--session-id"*"$sess"*"exec"*) shape=1 ;; *) shape=0 ;; esac
  [ "$rc" = 0 ] && [ -n "$sess" ] && [ -n "$term" ] && [ "$shape" = 1 ] \
    && ok lead_is_shell_hosted_with_session || fail lead_is_shell_hosted_with_session "rc=$rc sess=$sess term=$term line=$line"
}

t_resume_types_into_live_shell() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  rj="$APP_FLEET_HOME/runs/p1/run.json"
  term=$(jq_py "d['leadTerminal']" < "$rj"); sess=$(jq_py "d['leadSession']" < "$rj")
  echo "$term" > "$STUB_DIR/hc.noapp"
  n1=$(grep -c "do tab.new --name lead\|do space.new" "$STUB_LOG")
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  n2=$(grep -c "do tab.new --name lead\|do space.new" "$STUB_LOG")
  [ "$rc" = 0 ] && [ "$n1" = "$n2" ] && grep -q "^hc send $term .*--resume $sess" "$STUB_LOG" \
    && ok resume_types_into_live_shell || fail resume_types_into_live_shell "rc=$rc $n1->$n2"
}

t_resume_after_tab_closed_keeps_members() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  "$FLEET" thread open p1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  rj="$APP_FLEET_HOME/runs/p1/run.json"; sess=$(jq_py "d['leadSession']" < "$rj")
  herdr-app do tab.close --id "$(jq_py "d['leadTab']" < "$rj")" --confirmed true >/dev/null 2>&1
  jq_py "d['leadTerminal']" < "$rj" > "$STUB_DIR/hc.dead"   # closing a tab ends its terminal
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && grep "do tab.new --name lead" "$STUB_LOG" | grep -q -- "--resume $sess" \
    && grep -q "do terminal.keep --terminal tm1" "$STUB_LOG" && ! grep -q "do terminal.keep --terminal tm2" "$STUB_LOG" \
    && ok resume_after_tab_closed_keeps_members || fail resume_after_tab_closed_keeps_members "rc=$rc"
}

t_resume_old_run_without_lead_terminal() {
  fresh; seed_run r1
  python3 -I - "$APP_FLEET_HOME/runs/r1/run.json" "$REPO" <<'PY'
import json, sys
p, repo = sys.argv[1], sys.argv[2]
d = json.load(open(p)); del d["leadTerminal"]
d["threads"]["t1"] = {"template": "build", "room": "t1", "branch": None, "worktree": repo + "/.worktrees/r1/t1",
                      "tab": "tbold", "terminals": ["tz1"], "members": ["builder-t1"], "state": "open", "wave": None}
json.dump(d, open(p, "w"))
PY
  "$FLEET" lead r1 >/dev/null 2>&1; a=$?
  sess=$(jq_py "d.get('leadSession') or ''" < "$APP_FLEET_HOME/runs/r1/run.json")
  "$FLEET" thread close r1 t1 >/dev/null 2>&1; b=$?
  [ "$a$b" = 00 ] && [ -n "$sess" ] && ok resume_old_run_without_lead_terminal || fail resume_old_run_without_lead_terminal "codes=$a$b sess=$sess"
}

t_stale_status_with_shell_in_front_restarts_lead() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  rj="$APP_FLEET_HOME/runs/p1/run.json"; term=$(jq_py "d['leadTerminal']" < "$rj")
  echo "$term" > "$STUB_DIR/hc.shell"   # Herdr still reports app=claude-code, but a shell is in front
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && grep -q "^hc send $term .*--resume" "$STUB_LOG" \
    && ok stale_status_with_shell_in_front_restarts_lead || fail stale_status_with_shell_in_front_restarts_lead "rc=$rc"
}

t_caller_terminal_is_parent_only_for_the_lead() {
  fresh; seed_run r1 t9; echo t9 > "$STUB_DIR/hc.dead"
  HC_TERMINAL_ID=t5 "$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1; a=$?
  first=$(grep "^hc run" "$STUB_LOG" | head -1)
  case $first in *--no-parent*) p1=1 ;; *) p1=0 ;; esac
  HC_TERMINAL_ID=t5 ROOM_ID=lead "$FLEET" thread open r1 t2 --template build --brief "$(brief t2)" >/dev/null 2>&1; b=$?
  second=$(grep "^hc run.*--name t2-builder " "$STUB_LOG")
  case $second in *"--parent t5 "*) p2=1 ;; *) p2=0 ;; esac
  [ "$a$b" = 00 ] && [ "$p1$p2" = 11 ] && ok caller_terminal_is_parent_only_for_the_lead || fail caller_terminal_is_parent_only_for_the_lead "codes=$a$b p=$p1$p2"
}

t_resume_rescues_members_whose_parent_died() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  "$FLEET" thread open p1 t1 --template build --brief "$(brief t1)" >/dev/null 2>&1
  rj="$APP_FLEET_HOME/runs/p1/run.json"; term=$(jq_py "d['leadTerminal']" < "$rj")
  echo tm1 > "$STUB_DIR/hc.dead"; echo "$term" > "$STUB_DIR/hc.noapp"   # the builder died; the lead's Claude too
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && grep -q "do terminal.keep --terminal tm2" "$STUB_LOG" && ! grep -q "do terminal.keep --terminal tm1" "$STUB_LOG" \
    && ok resume_rescues_members_whose_parent_died || fail resume_rescues_members_whose_parent_died "rc=$rc"
}

t_judge_thread_fits_a_long_disputed_task() {
  fresh; seed_run r1 t9
  "$FLEET" thread open r1 billing-webhooks --template build --brief "$(brief b)" >/dev/null 2>&1; a=$?
  "$FLEET" thread open r1 judge-billing-webhooks --template judge --brief "$(brief j)" >/dev/null 2>&1; b=$?
  [ "$a$b" = 00 ] && grep -q "^hc run.*--name judge-billing-webhooks " "$STUB_LOG" \
    && ok judge_thread_fits_a_long_disputed_task || fail judge_thread_fits_a_long_disputed_task "codes=$a$b"
}

t_lead_opens_rooms_tab_for_the_run() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1; rc=$?
  line=$(grep "do tab.new --name rooms" "$STUB_LOG")
  case $line in *"--mod rooms"*"--props"*"$APP_FLEET_HOME/runs/p1/rooms"*"--focus false"*) shape=1 ;; *) shape=0 ;; esac
  rt=$(jq_py "d.get('roomsTab') or ''" < "$APP_FLEET_HOME/runs/p1/run.json")
  [ "$rc" = 0 ] && [ "$shape" = 1 ] && [ -n "$rt" ] && ok lead_opens_rooms_tab_for_the_run || fail lead_opens_rooms_tab_for_the_run "rc=$rc rt=$rt line=$line"
}

t_resume_reopens_closed_rooms_tab() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  rj="$APP_FLEET_HOME/runs/p1/run.json"
  herdr-app do tab.close --id "$(jq_py "d['roomsTab']" < "$rj")" --confirmed true >/dev/null 2>&1
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  n=$(grep -c "do tab.new --name rooms" "$STUB_LOG")
  [ "$rc" = 0 ] && [ "$n" = 2 ] && ok resume_reopens_closed_rooms_tab || fail resume_reopens_closed_rooms_tab "rc=$rc n=$n"
}

t_rooms_tab_failure_does_not_stop_the_run() {
  fresh; export STUB_FAIL_ROOMS_TAB=1
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && [ -f "$APP_FLEET_HOME/runs/p1/run.json" ] && ok rooms_tab_failure_does_not_stop_the_run || fail rooms_tab_failure_does_not_stop_the_run "rc=$rc"
}

t_resume_command_starts_in_the_repo() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  term=$(jq_py "d['leadTerminal']" < "$APP_FLEET_HOME/runs/p1/run.json"); echo "$term" > "$STUB_DIR/hc.noapp"
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && grep -q "^hc send $term cd $(cd "$REPO" && pwd -P) && " "$STUB_LOG" && ok resume_command_starts_in_the_repo || fail resume_command_starts_in_the_repo "rc=$rc"
}

t_running_lead_never_doubled_even_without_its_tab() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  rj="$APP_FLEET_HOME/runs/p1/run.json"
  python3 -I -c "import json,sys; p=sys.argv[1]; d=json.load(open(p)); d['leadTab']='tbgone'; json.dump(d,open(p,'w'))" "$rj"
  n1=$(grep -c "do tab.new --name lead\|do space.new" "$STUB_LOG")
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  n2=$(grep -c "do tab.new --name lead\|do space.new" "$STUB_LOG")
  [ "$rc" = 0 ] && [ "$n1" = "$n2" ] && ok running_lead_never_doubled_even_without_its_tab || fail running_lead_never_doubled_even_without_its_tab "rc=$rc $n1->$n2"
}

t_stale_lead_tab_closed_before_new_lead() {
  fresh
  "$FLEET" lead p1 --repo "$REPO" --architecture "$(arch)" >/dev/null 2>&1
  rj="$APP_FLEET_HOME/runs/p1/run.json"; tab=$(jq_py "d['leadTab']" < "$rj")
  jq_py "d['leadTerminal']" < "$rj" > "$STUB_DIR/hc.dead"   # its terminal ended, the tab record lingers
  "$FLEET" lead p1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && grep -q "do tab.close --id $tab" "$STUB_LOG" && [ "$(grep -c 'do tab.new --name lead' "$STUB_LOG")" = 1 ] \
    && ok stale_lead_tab_closed_before_new_lead || fail stale_lead_tab_closed_before_new_lead "rc=$rc"
}

t_resume_message_names_the_live_member_ids() {
  fresh; seed_run r1
  python3 -I - "$APP_FLEET_HOME/runs/r1/run.json" "$REPO" <<'PY'
import json, sys
p, repo = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d["threads"]["t1"] = {"template": "build", "room": "t1", "branch": None, "worktree": repo, "tab": "tbold",
                      "terminals": ["tz1"], "members": ["builder-t1", "reviewer-t1"], "state": "open", "wave": None}
json.dump(d, open(p, "w"))
PY
  "$FLEET" lead r1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && grep "do tab.new --name lead" "$STUB_LOG" | grep -q "builder-t1, reviewer-t1" \
    && ok resume_message_names_the_live_member_ids || fail resume_message_names_the_live_member_ids "rc=$rc"
}

for t in $(grep -o '^t_[a-z_0-9]*' "$0"); do "$t"; done
[ "$FAILS" = 0 ]
