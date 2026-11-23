"""Implementation of the `room` CLI. Python 3.9+, stdlib only, run with -I.

Storage (under a rooms root, $ROOMS_ROOT, default ~/.rooms/default):
  <room>/log.jsonl       one message per line, append-only, written under <room>/.lock
  <room>/members.json    [{id, role, joinedAt, watchAll?}]
  <room>/presence/<id>.json
  <room>/archived        marker
"""

import argparse
import contextlib
import datetime
import fcntl
import json
import os
import re
import secrets
import sys

MAX_TEXT = 4096
KINDS = ("msg", "done", "system", "pause")
MENTION = re.compile(r"@([a-z0-9][a-z0-9_-]*)")
ROOM_NAME = re.compile(r"^[a-z0-9][a-z0-9_.-]*$")


class Refused(Exception):
    def __init__(self, message, code=2):
        super().__init__(message)
        self.code = code


# ---------- paths and small helpers ----------

def rooms_root():
    root = os.environ.get("ROOMS_ROOT") or os.path.expanduser("~/.rooms/default")
    os.makedirs(root, exist_ok=True)
    return os.path.realpath(root)


def config_dir():
    d = os.environ.get("ROOMS_CONFIG_DIR") or os.path.expanduser("~/.config/rooms")
    os.makedirs(d, exist_ok=True)
    return d


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def compact(iso):
    """ISO time -> the sortable prefix message ids start with."""
    return iso.replace("-", "").replace(":", "")


def new_id(ts):
    return f"{compact(ts)}-{secrets.token_hex(3)}"


def mentions_in(text):
    seen = []
    for m in MENTION.findall(text):
        if m not in seen:
            seen.append(m)
    return seen


@contextlib.contextmanager
def locked(path):
    with open(path, "a") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)


def write_atomic(path, data):
    tmp = f"{path}.{os.getpid()}.{secrets.token_hex(3)}.tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh, indent=1)
        fh.write("\n")
    os.replace(tmp, path)


def read_json(path, default):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def register_root(root):
    cfg = config_dir()
    path = os.path.join(cfg, "roots.json")
    with locked(os.path.join(cfg, ".lock")):
        roots = [r for r in read_json(path, []) if isinstance(r, dict) and r.get("path") != root]
        roots.append({"path": root, "lastUsed": now_iso()})
        write_atomic(path, roots)


def room_dir(root, room, must_exist=True):
    if not ROOM_NAME.match(room):
        raise Refused(f"room: bad room name {room!r} (use a-z 0-9 . _ -)")
    d = os.path.join(root, room)
    if must_exist and not os.path.isdir(d):
        raise Refused(f"room: no room {room!r} under {root}", 3)
    return d


def read_log(d, warn=True):
    msgs, bad = [], 0
    try:
        with open(os.path.join(d, "log.jsonl")) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    m = json.loads(line)
                    if isinstance(m, dict) and "id" in m:
                        msgs.append(m)
                        continue
                except ValueError:
                    pass
                bad += 1
    except OSError:
        pass
    if bad and warn:
        print(f"room: skipped {bad} unreadable line(s) in {os.path.join(d, 'log.jsonl')}", file=sys.stderr)
    return msgs


def me():
    return os.environ.get("ROOM_ID") or None


# ---------- commands ----------

def cmd_create(a, root):
    d = room_dir(root, a.room, must_exist=False)
    os.makedirs(os.path.join(d, "presence"), exist_ok=True)
    with locked(os.path.join(d, ".lock")):
        open(os.path.join(d, "log.jsonl"), "a").close()
        members = read_json(os.path.join(d, "members.json"), [])
        for spec in a.member or []:
            mid, _, role = spec.partition(":")
            upsert_member(members, mid, role or None, False)
        write_atomic(os.path.join(d, "members.json"), members)
    print(d)


def upsert_member(members, mid, role, watch_all):
    if not MENTION.fullmatch("@" + mid):
        raise Refused(f"room: bad member id {mid!r}")
    for m in members:
        if m.get("id") == mid:
            if role:
                m["role"] = role
            if watch_all:
                m["watchAll"] = True
            return
    entry = {"id": mid, "role": role, "joinedAt": now_iso()}
    if watch_all:
        entry["watchAll"] = True
    members.append(entry)


def cmd_join(a, root):
    d = room_dir(root, a.room)
    with locked(os.path.join(d, ".lock")):
        members = read_json(os.path.join(d, "members.json"), [])
        upsert_member(members, a.id, a.role, a.watch_all)
        write_atomic(os.path.join(d, "members.json"), members)


def cmd_post(a, root):
    d = room_dir(root, a.room)
    sender = a.as_ or me()
    if not sender:
        raise Refused("room: who is posting? pass --as <id> or set ROOM_ID")
    text = " ".join(a.text)
    if len(text.encode()) > MAX_TEXT:
        raise Refused(f"room: message is over {MAX_TEXT} bytes; write long output to a file and post a link (--link <path>)")
    if os.path.exists(os.path.join(d, "archived")):
        raise Refused(f"room: {a.room} is archived", 3)
    ts = now_iso()
    msg = {"id": new_id(ts), "ts": ts, "room": a.room, "from": sender, "kind": a.kind,
           "text": text, "mentions": mentions_in(text)}
    if a.link:
        msg["links"] = a.link
    line = json.dumps(msg, ensure_ascii=False) + "\n"
    with locked(os.path.join(d, ".lock")):
        with open(os.path.join(d, "log.jsonl"), "a") as fh:
            fh.write(line)
    print(msg["id"])


def cmd_read(a, root):
    d = room_dir(root, a.room)
    msgs = read_log(d)
    if a.since:
        msgs = [m for m in msgs if m["id"] > a.since]
    if a.mentions_only:
        who = me()
        if not who:
            raise Refused("room: --mentions-only needs ROOM_ID")
        msgs = [m for m in msgs if m.get("from") != who
                and (who in m.get("mentions", []) or "all" in m.get("mentions", []))]
    if a.json:
        json.dump(msgs, sys.stdout, ensure_ascii=False)
        print()
        return
    for m in msgs:
        tag = "" if m.get("kind", "msg") == "msg" else f"[{m['kind']}] "
        links = "".join(f" <{l}>" for l in m.get("links", []))
        print(f"{m.get('ts', '')[:19]} {m.get('from')}: {tag}{m.get('text')}{links}")


def cmd_ls(a, root):
    rows = []
    for name in sorted(os.listdir(root)):
        d = os.path.join(root, name)
        if not os.path.isdir(d) or not ROOM_NAME.match(name):
            continue
        if not (os.path.exists(os.path.join(d, "members.json")) or os.path.exists(os.path.join(d, "log.jsonl"))):
            continue
        msgs = read_log(d, warn=False)
        rows.append({"room": name, "members": len(read_json(os.path.join(d, "members.json"), [])),
                     "messages": len(msgs), "lastTs": msgs[-1].get("ts") if msgs else None,
                     "archived": os.path.exists(os.path.join(d, "archived"))})
    if a.json:
        json.dump(rows, sys.stdout)
        print()
        return
    for r in rows:
        flag = " (archived)" if r["archived"] else ""
        print(f"{r['room']}{flag}: {r['members']} members, {r['messages']} messages")


PRESENCE_STATES = ("working", "idle", "gone")
DEFAULT_CONFIG = {"operator": "cesar", "quietMinutes": 10}


def cmd_presence(a, root):
    d = room_dir(root, a.room)
    pdir = os.path.join(d, "presence")
    os.makedirs(pdir, exist_ok=True)
    path = os.path.join(pdir, f"{a.id}.json")
    with locked(os.path.join(d, ".lock")):
        cur = read_json(path, {})
        cur.update({"id": a.id, "state": a.state, "ts": now_iso()})
        if a.delivered:
            cur["delivered"] = a.delivered
        if a.session:
            cur["session"] = a.session
        write_atomic(path, cur)


def cmd_presence_get(a, root):
    d = room_dir(root, a.room)
    json.dump(read_json(os.path.join(d, "presence", f"{a.id}.json"), {}), sys.stdout)
    print()


def cmd_archive(a, root):
    d = room_dir(root, a.room)
    open(os.path.join(d, "archived"), "a").close()


def cli_path():
    return os.path.realpath(os.environ.get("ROOMS_CLI_PATH") or os.path.join(os.path.dirname(__file__), "room"))


def cmd_install(a, root):
    target = cli_path()
    bindir = os.environ.get("ROOMS_BIN_DIR") or os.path.expanduser("~/.local/bin")
    os.makedirs(bindir, exist_ok=True)
    link = os.path.join(bindir, "room")
    if os.path.islink(link) or os.path.exists(link):
        if os.path.realpath(link) != target:
            os.remove(link)
    if not os.path.lexists(link):
        os.symlink(target, link)
    cfg = os.path.join(config_dir(), "config.json")
    if not os.path.exists(cfg):
        write_atomic(cfg, DEFAULT_CONFIG)
    print(target)


# ---------- entry ----------

def parser():
    p = argparse.ArgumentParser(prog="room", description="Chat rooms for agents.")
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("create", help="create a room")
    c.add_argument("room")
    c.add_argument("--member", action="append", metavar="id:role")
    c.set_defaults(fn=cmd_create)

    j = sub.add_parser("join", help="add a member to a room")
    j.add_argument("room")
    j.add_argument("id")
    j.add_argument("--role")
    j.add_argument("--watch-all", action="store_true", help="woken by mentions in every room under the root")
    j.set_defaults(fn=cmd_join)

    po = sub.add_parser("post", help="post a message")
    po.add_argument("room")
    po.add_argument("--as", dest="as_", metavar="id")
    po.add_argument("--kind", choices=KINDS, default="msg")
    po.add_argument("--link", action="append", metavar="path")
    po.add_argument("text", nargs="+")
    po.set_defaults(fn=cmd_post)

    r = sub.add_parser("read", help="read messages")
    r.add_argument("room")
    r.add_argument("--since", metavar="msg-id")
    r.add_argument("--mentions-only", action="store_true")
    r.add_argument("--json", action="store_true")
    r.set_defaults(fn=cmd_read)

    ls = sub.add_parser("ls", help="list rooms under the root")
    ls.add_argument("--json", action="store_true")
    ls.set_defaults(fn=cmd_ls)

    pr = sub.add_parser("presence", help="record a member's heartbeat")
    pr.add_argument("room")
    pr.add_argument("id")
    pr.add_argument("state", choices=PRESENCE_STATES)
    pr.add_argument("--delivered", metavar="msg-id")
    pr.add_argument("--session", metavar="session-id")
    pr.set_defaults(fn=cmd_presence)

    pg = sub.add_parser("presence-get", help="print a member's presence JSON")
    pg.add_argument("room")
    pg.add_argument("id")
    pg.set_defaults(fn=cmd_presence_get)

    ar = sub.add_parser("archive", help="archive a room (no more posts)")
    ar.add_argument("room")
    ar.set_defaults(fn=cmd_archive)

    ins = sub.add_parser("install", help="put room on PATH and write default config")
    ins.set_defaults(fn=cmd_install)
    return p


def main(argv):
    a = parser().parse_args(argv)
    try:
        root = rooms_root()
        register_root(root)
        a.fn(a, root)
    except Refused as e:
        print(str(e), file=sys.stderr)
        return e.code
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
