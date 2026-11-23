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
  unset STUB_HERDR_STATUS STUB_FAIL STUB_HC_KILL_STATUS APP_FLEET_ROSTER ROOM_ID ROOMS_ROOT
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

# A run.json written directly, for tests of commands that read runs.
seed_run() {
  mkdir -p "$APP_FLEET_HOME/runs/$1/rooms"
  printf '{"run":"%s","repo":"%s","stage":"execution","base":"main","integration":"fleet/%s","space":"sp1","leadTab":null,"maxThreads":4,"verify":null,"teardown":null,"architecture":null,"threads":{}}\n' \
    "$1" "$REPO" "$1/integration" > "$APP_FLEET_HOME/runs/$1/run.json"
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
  out=$("$FLEET" _compose r1 builder-t1 builder t1 2>&1) || { fail compose_builder "rc=$? $out"; return; }
  prompt=$(printf '%s' "$out" | jq_py "d['prompt_path']"); settings=$(printf '%s' "$out" | jq_py "d['settings_path']")
  last=$(printf '%s' "$out" | jq_py "d['argv'][-1]"); model=$(printf '%s' "$out" | jq_py "d['argv'][d['argv'].index('--model')+1]")
  rid=$(jq_py "d['env']['ROOM_ID']" < "$settings")
  want_model=$(sed -n 's/^model: *//p' "$PLUGIN/roster/personas/builder.md" | head -1)
  grep -q "Review bar" "$prompt"; bar=$?
  case $last in "You are builder-t1."*) first=1 ;; *) first=0 ;; esac
  [ "$rid" = builder-t1 ] && [ "$model" = "$want_model" ] && [ "$first" = 1 ] && [ "$bar" != 0 ] \
    && grep -q "builder-t1" "$prompt" && grep -q -i "mention" "$prompt" \
    && ok compose_builder || fail compose_builder "rid=$rid model=$model/$want_model first=$first bar=$bar"
}

t_compose_reviewer_has_review_bar() {
  fresh; seed_run r1
  prompt=$("$FLEET" _compose r1 reviewer-t1 reviewer t1 2>/dev/null | jq_py "d['prompt_path']")
  first_line=$(head -1 "$PLUGIN/roster/policy/review-bar.md")
  grep -q -F "$first_line" "$prompt" && ok compose_reviewer_has_review_bar || fail compose_reviewer_has_review_bar "no review bar in $prompt"
}

t_compose_includes_memory_capped() {
  fresh; seed_run r1
  mkdir -p "$APP_FLEET_HOME/memory/builder"
  python3 -I -c "print('M' * 10240, end='')" > "$APP_FLEET_HOME/memory/builder/MEMORY.md"
  prompt=$("$FLEET" _compose r1 builder-t1 builder t1 2>/dev/null | jq_py "d['prompt_path']")
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

t_thread_open_creates_everything() {
  fresh; seed_run r1
  out=$("$FLEET" thread open r1 t1 --template build --brief "$(brief t1)" 2>&1) || { fail thread_open_creates_everything "rc=$? $out"; return; }
  wt="$REPO/.worktrees/r1/t1"
  br=$(git -C "$wt" branch --show-current 2>/dev/null)
  members=$(ROOMS_ROOT="$APP_FLEET_HOME/runs/r1/rooms" room ls --json | jq_py "{r['room']: r['members'] for r in d}")
  mem_t1=$(jq_py "sorted(m['id'] for m in d)" < "$APP_FLEET_HOME/runs/r1/rooms/t1/members.json")
  mem_ch=$(jq_py "sorted(m['id'] for m in d)" < "$APP_FLEET_HOME/runs/r1/rooms/execution/members.json")
  first=$(head -1 "$APP_FLEET_HOME/runs/r1/rooms/t1/log.jsonl" | jq_py "sorted(d['mentions'])")
  tabs=$(grep -c "do tab.new --name t1" "$STUB_LOG"); splits=$(grep -c "do pane.split" "$STUB_LOG")
  state=$(jq_py "d['threads']['t1']['state']" < "$APP_FLEET_HOME/runs/r1/run.json")
  [ "$br" = fleet/r1/t1 ] && [ "$mem_t1" = "['builder-t1', 'cesar', 'reviewer-t1']" ] \
    && case $mem_ch in *builder-t1*reviewer-t1*) true ;; *) false ;; esac \
    && [ -f "$APP_FLEET_HOME/runs/r1/briefs/t1.md" ] && [ "$first" = "['builder-t1', 'reviewer-t1']" ] \
    && [ "$tabs" = 1 ] && [ "$splits" = 1 ] && [ "$state" = open ] \
    && ok thread_open_creates_everything || fail thread_open_creates_everything "br=$br t1=$mem_t1 ch=$mem_ch first=$first tabs=$tabs splits=$splits state=$state"
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
  fresh; seed_run r1; export STUB_FAIL=tab.new
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
    && grep -q "do tab.close" "$STUB_LOG" && [ ! -e "$REPO/.worktrees/r1/t1" ] && [ "$state" = closed ] \
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
  echo stray > "$REPO/.worktrees/r1/_integration/stray.txt"
  "$FLEET" merge r1 t1 >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && ok merge_refuses_dirty_integration || fail merge_refuses_dirty_integration "rc=$rc"
}

t_verify_opens_runner_thread_on_integration() {
  fresh; seed_run r1
  "$FLEET" config r1 verify "make verify" >/dev/null 2>&1; "$FLEET" config r1 teardown "make down" >/dev/null 2>&1
  "$FLEET" verify r1 1 >/dev/null 2>&1; rc=$?
  b="$APP_FLEET_HOME/runs/r1/briefs/verify-w1.md"
  [ "$rc" = 0 ] && grep -q "do tab.new --name verify-w1" "$STUB_LOG" && grep -q -- "--folder $REPO/.worktrees/r1/_integration" "$STUB_LOG" \
    && grep -q "make verify" "$b" && grep -q "make down" "$b" \
    && [ "$(jq_py "d['threads']['verify-w1']['members']" < "$APP_FLEET_HOME/runs/r1/run.json")" = "['runner-verify-w1']" ] \
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
  settings=$("$FLEET" _compose r1 builder-t1 builder t1 2>/dev/null | jq_py "d['settings_path']")
  rd=$(cd "$APP_FLEET_HOME/runs/r1" && pwd -P)
  got=$(jq_py "(d['permissions'].get('additionalDirectories'), [a for a in d['permissions']['allow'] if a.startswith('Edit(')])" < "$settings")
  case $got in *"$rd"*"Edit($rd/**)"*) ok compose_grants_run_dir ;; *) fail compose_grants_run_dir "got $got" ;; esac
}

for t in $(grep -o '^t_[a-z_0-9]*' "$0"); do "$t"; done
[ "$FAILS" = 0 ]
