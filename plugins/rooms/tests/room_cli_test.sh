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
  "$ROOM" ls >/dev/null 2>&1
  abs=$(mkdir -p "$ROOMS_ROOT" && cd "$ROOMS_ROOT" && pwd -P)
  got=$(jq_py "[r['path'] for r in d]" < "$ROOMS_CONFIG_DIR/roots.json" 2>/dev/null)
  [ "$got" = "['$abs']" ] && ok root_registered || fail root_registered "got $got want $abs"
}

for t in $(grep -o '^t_[a-z_]*' "$0"); do "$t"; done
[ "$FAILS" = 0 ]
