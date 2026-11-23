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
    "$1" "$REPO" "$1" > "$APP_FLEET_HOME/runs/$1/run.json"
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

for t in $(grep -o '^t_[a-z_0-9]*' "$0"); do "$t"; done
[ "$FAILS" = 0 ]
