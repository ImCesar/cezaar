#!/bin/sh
# Shell tests for scripts/room. Each case runs in a fresh root and config dir.
# Prints "ok <name>" or "not ok <name>: <why>"; exits non-zero on any failure.

HERE=$(cd "$(dirname "$0")" && pwd)
ROOM="$HERE/../scripts/room"
FAILS=0

fresh() {
  T=$(mktemp -d)
  export ROOMS_ROOT="$T/root"
  export ROOMS_CONFIG_DIR="$T/config"
  export ROOMS_BIN_DIR="$T/bin"
  unset ROOM_ID ROOMS
}
ok() { echo "ok $1"; }
fail() { echo "not ok $1: $2"; FAILS=$((FAILS + 1)); }
jq_py() { python3 -I -c "import sys,json; d=json.load(sys.stdin); print($1)"; }

t_create_then_ls() {
  fresh
  "$ROOM" create r --member a:builder --member b:reviewer >/dev/null 2>&1 || { fail create_then_ls "create failed"; return; }
  out=$("$ROOM" ls --json 2>/dev/null)
  got=$(printf '%s' "$out" | jq_py "[(x['room'],x['members'],x['messages']) for x in d]")
  [ "$got" = "[('r', 2, 0)]" ] && ok create_then_ls || fail create_then_ls "got $got"
}

t_post_parses_mentions() {
  fresh
  "$ROOM" create r --member a:builder --member b:reviewer >/dev/null 2>&1
  "$ROOM" post r --as a "@b ready, cc @all @b" >/dev/null 2>&1 || { fail post_parses_mentions "post failed"; return; }
  lines=$(wc -l < "$ROOMS_ROOT/r/log.jsonl" 2>/dev/null | tr -d ' ')
  got=$(head -1 "$ROOMS_ROOT/r/log.jsonl" 2>/dev/null | jq_py "(d['mentions'], d['from'], d['kind'])")
  [ "$lines" = 1 ] && [ "$got" = "(['b', 'all'], 'a', 'msg')" ] && ok post_parses_mentions || fail post_parses_mentions "lines=$lines got=$got"
}

t_post_refuses_big() {
  fresh
  "$ROOM" create r >/dev/null 2>&1
  big=$(python3 -I -c "print('x'*4097, end='')")
  "$ROOM" post r --as a "$big" >/dev/null 2>&1; rc=$?
  size=$(wc -c < "$ROOMS_ROOT/r/log.jsonl" 2>/dev/null | tr -d ' ')
  [ "$rc" = 2 ] && [ "${size:-0}" = 0 ] && ok post_refuses_big || fail post_refuses_big "rc=$rc size=$size"
}

t_parallel_posts_intact() {
  fresh
  "$ROOM" create r >/dev/null 2>&1
  i=0
  while [ $i -lt 20 ]; do "$ROOM" post r --as a "msg $i @b" >/dev/null 2>&1 & i=$((i + 1)); done
  wait
  got=$(python3 -I -c "
import json,sys
ls=open(sys.argv[1]).read().splitlines()
ids=[json.loads(l)['id'] for l in ls]
print(len(ls), len(set(ids)))" "$ROOMS_ROOT/r/log.jsonl" 2>&1)
  [ "$got" = "20 20" ] && ok parallel_posts_intact || fail parallel_posts_intact "got $got"
}

t_read_since_and_mentions_only() {
  fresh
  "$ROOM" create r --member a:x --member b:y >/dev/null 2>&1
  id1=$("$ROOM" post r --as a "one @b" 2>/dev/null)
  id2=$("$ROOM" post r --as a "two" 2>/dev/null)
  id3=$("$ROOM" post r --as b "three @b @all" 2>/dev/null)
  id4=$("$ROOM" post r --as a "four @all" 2>/dev/null)
  since=$("$ROOM" read r --since "$id2" --json 2>/dev/null | jq_py "[m['text'] for m in d]")
  mine=$(ROOM_ID=b "$ROOM" read r --mentions-only --json 2>/dev/null | jq_py "[m['text'] for m in d]")
  [ "$since" = "['three @b @all', 'four @all']" ] && [ "$mine" = "['one @b', 'four @all']" ] \
    && ok read_since_and_mentions_only || fail read_since_and_mentions_only "since=$since mine=$mine ids=$id1,$id2,$id3,$id4"
}

t_read_skips_garbled() {
  fresh
  "$ROOM" create r >/dev/null 2>&1
  "$ROOM" post r --as a "good one" >/dev/null 2>&1
  printf '{"broken\n' >> "$ROOMS_ROOT/r/log.jsonl"
  "$ROOM" post r --as a "good two" >/dev/null 2>&1
  out=$("$ROOM" read r --json 2>"$T/err"); rc=$?
  got=$(printf '%s' "$out" | jq_py "[m['text'] for m in d]")
  warns=$(wc -l < "$T/err" | tr -d ' ')
  [ "$rc" = 0 ] && [ "$got" = "['good one', 'good two']" ] && [ "$warns" = 1 ] \
    && ok read_skips_garbled || fail read_skips_garbled "rc=$rc got=$got warns=$warns"
}

t_root_registered() {
  fresh
  "$ROOM" create r >/dev/null 2>&1
  abs=$(mkdir -p "$ROOMS_ROOT" && cd "$ROOMS_ROOT" && pwd -P)
  got=$(jq_py "[r['path'] for r in d]" < "$ROOMS_CONFIG_DIR/roots.json" 2>/dev/null)
  [ "$got" = "['$abs']" ] && ok root_registered || fail root_registered "got $got want $abs"
}

t_presence_roundtrip() {
  fresh
  "$ROOM" create r --member a:x >/dev/null 2>&1
  "$ROOM" presence r a idle --delivered X >/dev/null 2>&1 && "$ROOM" presence r a working >/dev/null 2>&1 \
    || { fail presence_roundtrip "presence failed"; return; }
  got=$("$ROOM" presence-get r a 2>/dev/null | jq_py "(d.get('delivered'), d.get('state'), bool(d.get('ts')))")
  [ "$got" = "('X', 'working', True)" ] && ok presence_roundtrip || fail presence_roundtrip "got $got"
}

t_presence_atomic() {
  fresh
  "$ROOM" create r --member a:x >/dev/null 2>&1
  i=0
  while [ $i -lt 20 ]; do "$ROOM" presence r a idle --delivered "d$i" >/dev/null 2>&1 & i=$((i + 1)); done
  wait
  got=$(jq_py "d['state']" < "$ROOMS_ROOT/r/presence/a.json" 2>/dev/null)
  left=$(ls "$ROOMS_ROOT/r/presence" | grep -c tmp)
  [ "$got" = idle ] && [ "$left" = 0 ] && ok presence_atomic || fail presence_atomic "got=$got tmpfiles=$left"
}

t_archive_blocks_post() {
  fresh
  "$ROOM" create r >/dev/null 2>&1
  "$ROOM" archive r >/dev/null 2>&1 || { fail archive_blocks_post "archive failed"; return; }
  "$ROOM" post r --as a "late" >/dev/null 2>&1; rc=$?
  [ "$rc" = 3 ] && [ -e "$ROOMS_ROOT/r/archived" ] && ok archive_blocks_post || fail archive_blocks_post "rc=$rc"
}

t_install_creates_link_and_config() {
  fresh
  out=$("$ROOM" install 2>/dev/null) || { fail install_creates_link_and_config "install failed"; return; }
  want=$(cd "$HERE/../scripts" && pwd -P)/room
  link=$(cd "$ROOMS_BIN_DIR" 2>/dev/null && python3 -I -c "import os;print(os.path.realpath('room'))")
  cfg=$(jq_py "d" < "$ROOMS_CONFIG_DIR/config.json" 2>/dev/null)
  printf '{"operator": "someone", "quietMinutes": 3}\n' > "$ROOMS_CONFIG_DIR/config.json"
  "$ROOM" install >/dev/null 2>&1
  kept=$(jq_py "d['operator']" < "$ROOMS_CONFIG_DIR/config.json" 2>/dev/null)
  [ "$out" = "$want" ] && [ "$link" = "$want" ] && [ "$cfg" = "{'operator': 'cesar', 'quietMinutes': 10}" ] && [ "$kept" = someone ] \
    && ok install_creates_link_and_config || fail install_creates_link_and_config "out=$out link=$link cfg=$cfg kept=$kept"
}

t_herdr_install_to_temp_dest() {
  fresh
  dest="$T/mods/rooms"
  ROOMS_SKIP_HERDR_CHECK=1 "$ROOM" herdr-install --dest "$dest" >/dev/null 2>&1 || { fail herdr_install_to_temp_dest "herdr-install failed"; return; }
  cli=$(jq_py "d.get('cli', '')" < "$ROOMS_CONFIG_DIR/config.json" 2>/dev/null)
  op=$(jq_py "d.get('operator')" < "$ROOMS_CONFIG_DIR/config.json" 2>/dev/null)
  [ -f "$dest/main.js" ] && [ -f "$dest/model.js" ] && [ -f "$dest/mod.json" ] && [ ! -e "$dest/model.test.mjs" ] \
    && case $cli in /*) [ -x "$cli" ] ;; *) false ;; esac && [ "$op" = cesar ] \
    && ok herdr_install_to_temp_dest || fail herdr_install_to_temp_dest "cli=$cli op=$op files=$(ls "$dest" 2>/dev/null | tr '\n' ' ')"
}

t_herdr_install_panel_only_leaves_link_and_config() {
  fresh
  dest="$T/mods/rooms"
  mkdir -p "$ROOMS_CONFIG_DIR" "$ROOMS_BIN_DIR"
  printf '{"operator": "cesar", "cli": "/keep/room"}' > "$ROOMS_CONFIG_DIR/config.json"
  ln -s /keep/room "$ROOMS_BIN_DIR/room"
  ROOMS_SKIP_HERDR_CHECK=1 "$ROOM" herdr-install --panel-only --dest "$dest" >/dev/null 2>&1 || { fail herdr_install_panel_only_leaves_link_and_config "install failed"; return; }
  cli=$(jq_py "d.get('cli', '')" < "$ROOMS_CONFIG_DIR/config.json" 2>/dev/null)
  link=$(readlink "$ROOMS_BIN_DIR/room")
  [ -f "$dest/main.js" ] && [ -f "$dest/model.js" ] && [ "$cli" = /keep/room ] && [ "$link" = /keep/room ] \
    && ok herdr_install_panel_only_leaves_link_and_config || fail herdr_install_panel_only_leaves_link_and_config "cli=$cli link=$link files=$(ls "$dest" 2>/dev/null | tr '\n' ' ')"
}

t_truncated_utf8_line_does_not_crash_or_eat_next() {
  fresh
  "$ROOM" create r >/dev/null 2>&1
  "$ROOM" post r --as a "before" >/dev/null 2>&1
  printf '{"id":"zz","text":"caf\303' >> "$ROOMS_ROOT/r/log.jsonl"
  "$ROOM" post r --as a "@b after" >/dev/null 2>&1
  got=$("$ROOM" read r --json 2>/dev/null | jq_py "[m['text'] for m in d]"); rc=$?
  "$ROOM" ls >/dev/null 2>&1; lsrc=$?
  [ "$got" = "['before', '@b after']" ] && [ "$lsrc" = 0 ] \
    && ok truncated_utf8_line_does_not_crash_or_eat_next || fail truncated_utf8_line_does_not_crash_or_eat_next "got=$got ls=$lsrc"
}

t_missing_root_not_recreated() {
  fresh
  "$ROOM" post r --as a "hello" >/dev/null 2>&1; rc=$?
  "$ROOM" presence r a idle >/dev/null 2>&1; prc=$?
  reg=$(cat "$ROOMS_CONFIG_DIR/roots.json" 2>/dev/null)
  [ "$rc" = 3 ] && [ "$prc" = 3 ] && [ ! -e "$ROOMS_ROOT" ] && [ -z "$reg" -o "$reg" = "[]" ] \
    && ok missing_root_not_recreated || fail missing_root_not_recreated "rc=$rc prc=$prc exists=$([ -e "$ROOMS_ROOT" ] && echo y) reg=$reg"
}

t_dead_roots_pruned() {
  fresh
  mkdir -p "$ROOMS_CONFIG_DIR"
  printf '[{"path": "/nonexistent/rooms-root", "lastUsed": "x"}]\n' > "$ROOMS_CONFIG_DIR/roots.json"
  "$ROOM" create r >/dev/null 2>&1
  got=$(jq_py "[r['path'] for r in d if 'nonexistent' in r['path']]" < "$ROOMS_CONFIG_DIR/roots.json" 2>/dev/null)
  [ "$got" = "[]" ] && ok dead_roots_pruned || fail dead_roots_pruned "got $got"
}

t_install_refuses_regular_file() {
  fresh
  mkdir -p "$ROOMS_BIN_DIR"
  printf 'mine\n' > "$ROOMS_BIN_DIR/room"
  "$ROOM" install >/dev/null 2>&1; rc=$?
  kept=$(cat "$ROOMS_BIN_DIR/room")
  [ "$rc" != 0 ] && [ "$kept" = mine ] && ok install_refuses_regular_file || fail install_refuses_regular_file "rc=$rc kept=$kept"
}

t_registry_not_rewritten_each_call() {
  fresh
  "$ROOM" create r --member a:x >/dev/null 2>&1
  first=$(jq_py "d[0]['lastUsed']" < "$ROOMS_CONFIG_DIR/roots.json" 2>/dev/null)
  "$ROOM" presence r a idle >/dev/null 2>&1
  "$ROOM" post r --as a "hi" >/dev/null 2>&1
  second=$(jq_py "d[0]['lastUsed']" < "$ROOMS_CONFIG_DIR/roots.json" 2>/dev/null)
  [ -n "$first" ] && [ "$first" = "$second" ] && ok registry_not_rewritten_each_call || fail registry_not_rewritten_each_call "first=$first second=$second"
}

t_presence_rejects_bad_id() {
  fresh
  "$ROOM" create r --member a:x >/dev/null 2>&1
  "$ROOM" presence r ../../escape idle >/dev/null 2>&1; rc=$?
  "$ROOM" presence-get r ../../escape >/dev/null 2>&1; grc=$?
  [ "$rc" = 2 ] && [ "$grc" = 2 ] && [ ! -e "$ROOMS_ROOT/escape.json" ] && ok presence_rejects_bad_id || fail presence_rejects_bad_id "rc=$rc grc=$grc"
}

t_rooms_id_reserved() {
  fresh
  "$ROOM" create r --member rooms:x >/dev/null 2>&1; crc=$?
  "$ROOM" create r2 >/dev/null 2>&1
  "$ROOM" join r2 rooms >/dev/null 2>&1; jrc=$?
  "$ROOM" post r2 --as rooms --kind system "@lead note" >/dev/null 2>&1; prc=$?
  [ "$crc" = 2 ] && [ "$jrc" = 2 ] && [ "$prc" = 0 ] && ok rooms_id_reserved || fail rooms_id_reserved "create=$crc join=$jrc post=$prc"
}

for t in $(grep -o '^t_[a-z_0-9]*' "$0"); do "$t"; done
[ "$FAILS" = 0 ]
