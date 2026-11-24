"""Implementation of the `room` CLI. Python 3.9+, stdlib only, run with -I.

Storage (under a rooms root, $ROOMS_ROOT, default ~/.rooms/default):
  <room>/log.jsonl       one message per line, append-only, written under <room>/.lock
  <room>/members.json    [{id, role, joinedAt, watchAll?, session?, resume?, end?}]
  <room>/presence/<id>.json
  <room>/archived        marker
  <room>/resume.log      output of resume commands `room post` started
"""

import argparse
import contextlib
import datetime
import fcntl
import json
import os
import re
import secrets
import subprocess
import sys

MAX_TEXT = 16384
KINDS = ("msg", "done", "system", "pause")
MENTION = re.compile(r"@([a-z0-9][a-z0-9_-]*)")
ROOM_NAME = re.compile(r"^[a-z0-9][a-z0-9_.-]*$")
SYSTEM_ID = "rooms"  # the sender of the mod's own reports; no member may take it
REGISTER_EVERY_S = 600
LIVE_S = 120  # a presence older than this is not live; the mod heartbeats more often


class Refused(Exception):
    def __init__(self, message, code=2):
        super().__init__(message)
        self.code = code


# ---------- paths and small helpers ----------

def rooms_root(create):
    """The rooms root. Only `create` makes it: a root a run's cleanup removed stays gone."""
    root = os.environ.get("ROOMS_ROOT") or os.path.expanduser("~/.rooms/default")
    if create:
        os.makedirs(root, exist_ok=True)
    elif not os.path.isdir(root):
        raise Refused(f"room: no rooms root at {root} (create a room first)", 3)
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


FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
CODE_SPAN = re.compile(r"(`+)(?!`).*?(?<!`)\1(?!`)", re.S)


def without_code(text):
    """The text with fenced blocks and code spans removed: an id quoted in code wakes nobody."""
    out, fence = [], None
    for line in text.split("\n"):
        m = FENCE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence):
                fence = None
            continue
        if m:
            fence = m.group(1)
            continue
        out.append(line)
    return CODE_SPAN.sub(" ", "\n".join(out))


def mentions_in(text):
    seen = []
    for m in MENTION.findall(without_code(text)):
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
    """Record a root for the panel. Skipped when it was recorded recently: heartbeats call this."""
    cfg = config_dir()
    path = os.path.join(cfg, "roots.json")
    for r in read_json(path, []):
        if isinstance(r, dict) and r.get("path") == root:
            try:
                last = datetime.datetime.strptime(r.get("lastUsed", ""), "%Y-%m-%dT%H:%M:%S.%fZ")
                age = datetime.datetime.utcnow() - last
                if age.total_seconds() < REGISTER_EVERY_S:
                    return
            except ValueError:
                pass
    with locked(os.path.join(cfg, ".lock")):
        roots = [r for r in read_json(path, []) if isinstance(r, dict) and r.get("path") != root
                 and isinstance(r.get("path"), str) and os.path.isdir(r["path"])]
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
        with open(os.path.join(d, "log.jsonl"), encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    m = json.loads(line)
                    if isinstance(m, dict) and isinstance(m.get("id"), str):
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


def check_member_id(mid):
    if not MENTION.fullmatch("@" + mid):
        raise Refused(f"room: bad member id {mid!r} (use a-z 0-9 _ -)")


def upsert_member(members, mid, role, watch_all):
    check_member_id(mid)
    if mid == SYSTEM_ID:
        raise Refused(f"room: {SYSTEM_ID!r} is reserved for the rooms mod's own reports")
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


def cmd_member(a, root):
    check_member_id(a.id)
    d = room_dir(root, a.room)
    with locked(os.path.join(d, ".lock")):
        members = read_json(os.path.join(d, "members.json"), [])
        entry = next((m for m in members if isinstance(m, dict) and m.get("id") == a.id), None)
        if entry is None:
            raise Refused(f"room: no member {a.id!r} in {a.room}", 3)
        for field in ("session", "resume", "end"):
            value = getattr(a, field)
            if value is None:
                continue
            if value:
                entry[field] = value
            else:
                entry.pop(field, None)
        write_atomic(os.path.join(d, "members.json"), members)


def presence_live(p):
    """Whether a presence record shows a live (or just-resumed) member."""
    if not isinstance(p, dict) or p.get("state") not in ("working", "idle", "resuming"):
        return False
    try:
        ts = datetime.datetime.strptime(p.get("ts", ""), "%Y-%m-%dT%H:%M:%S.%fZ")
    except (TypeError, ValueError):
        return False
    return (datetime.datetime.utcnow() - ts).total_seconds() < LIVE_S


def cmd_end(a, root):
    """Run a member's recorded end command, to end its live session (the panel's end button)."""
    import subprocess
    check_member_id(a.id)
    d = room_dir(root, a.room)
    members = read_json(os.path.join(d, "members.json"), [])
    entry = next((m for m in members if isinstance(m, dict) and m.get("id") == a.id), None)
    if entry is None:
        raise Refused(f"room: no member {a.id!r} in {a.room}", 3)
    cmd = entry.get("end")
    if not cmd:
        raise Refused(f"room: {a.id} has no end command (room member {a.room} {a.id} --end ...)", 3)
    env = {k: v for k, v in os.environ.items() if k not in ("HC_TERMINAL_ID", "HC_SCOPE")}
    env["ROOMS_ROOT"] = root
    r = subprocess.run(["sh", "-c", cmd], env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    if r.returncode != 0:
        raise Refused(f"room: ending {a.id} failed (exit {r.returncode}): {(r.stderr or r.stdout).strip()}", 4)
    print(f"ended {a.id}")


def resume_log(d, line):
    with open(os.path.join(d, "resume.log"), "a") as fh:
        fh.write(f"{now_iso()} {line}\n")


def resume_mentioned(d, root, mentions, sender):
    """Start the resume command of each mentioned member who has one and isn't live."""
    ids = [m for m in mentions if m != "all" and m != sender]
    if not ids:
        return
    to_start = []
    with locked(os.path.join(d, ".lock")):
        members = {m.get("id"): m for m in read_json(os.path.join(d, "members.json"), []) if isinstance(m, dict)}
        for mid in ids:
            cmd = (members.get(mid) or {}).get("resume")
            if not isinstance(cmd, str) or not cmd:
                continue
            path = os.path.join(d, "presence", f"{mid}.json")
            cur = read_json(path, {})
            if presence_live(cur):
                continue
            if not isinstance(cur, dict):
                cur = {}
            cur.update({"id": mid, "state": "resuming", "ts": now_iso()})
            os.makedirs(os.path.dirname(path), exist_ok=True)
            write_atomic(path, cur)
            to_start.append((mid, cmd))
    env = {k: v for k, v in os.environ.items() if k not in ("HC_TERMINAL_ID", "HC_SCOPE")}
    env["ROOMS_ROOT"] = root
    for mid, cmd in to_start:
        try:
            resume_log(d, f"resuming {mid}: {cmd}")
            with open(os.path.join(d, "resume.log"), "ab") as out:
                subprocess.Popen(["sh", "-c", cmd], stdin=subprocess.DEVNULL, stdout=out,
                                 stderr=subprocess.STDOUT, env=env, start_new_session=True)
        except OSError as e:
            try:
                resume_log(d, f"could not start resume for {mid}: {e}")
            except OSError:
                pass


def cmd_post(a, root):
    d = room_dir(root, a.room)
    sender = a.as_ or me()
    if not sender:
        raise Refused("room: who is posting? pass --as <id> or set ROOM_ID")
    if a.text and a.body_file is not None:
        raise Refused("room: give the text or --body-file, not both")
    if a.body_file is not None:
        try:
            if a.body_file == "-":
                text = sys.stdin.buffer.read().decode("utf-8")
            else:
                with open(a.body_file, "rb") as f:
                    text = f.read().decode("utf-8")
        except (OSError, UnicodeDecodeError) as e:
            raise Refused(f"room: cannot read --body-file {a.body_file}: {e}")
    elif a.text:
        text = " ".join(a.text)
    else:
        raise Refused("room post: the following arguments are required: text (or --body-file)")
    if len(text.encode()) > MAX_TEXT:
        raise Refused("room: message is over 16 KB; write long output to a file and post a link (--link <path>)")
    if os.path.exists(os.path.join(d, "archived")):
        raise Refused(f"room: {a.room} is archived", 3)
    ts = now_iso()
    msg = {"id": new_id(ts), "ts": ts, "room": a.room, "from": sender, "kind": a.kind,
           "text": text, "mentions": mentions_in(text)}
    if a.link:
        msg["links"] = a.link
    line = json.dumps(msg, ensure_ascii=False) + "\n"
    log = os.path.join(d, "log.jsonl")
    with locked(os.path.join(d, ".lock")):
        # A writer that died mid-line leaves no newline: end that line so this message stands alone.
        with open(log, "ab") as fh:
            if fh.tell() > 0:
                with open(log, "rb") as rh:
                    rh.seek(-1, os.SEEK_END)
                    if rh.read(1) != b"\n":
                        fh.write(b"\n")
            fh.write(line.encode("utf-8"))
    print(msg["id"])
    sys.stdout.flush()
    resume_mentioned(d, root, msg["mentions"], sender)


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


PRESENCE_STATES = ("working", "idle", "gone", "resuming")
DEFAULT_CONFIG = {"operator": "cesar", "quietMinutes": 10}


def cmd_presence(a, root):
    check_member_id(a.id)
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
    check_member_id(a.id)
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
    if os.path.lexists(link) and not os.path.islink(link):
        raise Refused(f"room: {link} exists and is not a symlink; move it away or set ROOMS_BIN_DIR", 2)
    if os.path.islink(link) and os.path.realpath(link) != target:
        os.remove(link)
    if not os.path.lexists(link):
        os.symlink(target, link)
    cfg = os.path.join(config_dir(), "config.json")
    if not os.path.exists(cfg):
        write_atomic(cfg, DEFAULT_CONFIG)
    print(target)


def cmd_herdr_install(a, root):
    import shutil
    import subprocess
    if not a.panel_only:  # --panel-only: try a worktree's panel without repointing `room` at it
        cmd_install(a, root)
    src = os.path.join(os.path.dirname(os.path.dirname(cli_path())), "herdr-mod", "rooms")
    dest = a.dest or os.path.expanduser("~/.config/herdr-app/mods/rooms")
    os.makedirs(dest, exist_ok=True)
    for name in sorted(os.listdir(src)):
        if name.endswith(".test.mjs") or name == "package.json":
            continue
        shutil.copy2(os.path.join(src, name), os.path.join(dest, name))
    if not a.panel_only:
        cfg_path = os.path.join(config_dir(), "config.json")
        with locked(os.path.join(config_dir(), ".lock")):
            cfg = {**DEFAULT_CONFIG, **read_json(cfg_path, {})}
            cfg["cli"] = cli_path()
            write_atomic(cfg_path, cfg)
    print(dest)
    if os.environ.get("ROOMS_SKIP_HERDR_CHECK") or not shutil.which("herdr-app"):
        return
    r = subprocess.run(["herdr-app", "check", dest], capture_output=True, text=True)
    print((r.stdout + r.stderr).strip())
    if r.returncode != 0:
        raise Refused("room: herdr-app check failed for the installed panel", 4)


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

    mb = sub.add_parser("member", help="set a member's Claude session id and resume command")
    mb.add_argument("room")
    mb.add_argument("id")
    mb.add_argument("--session", metavar="uuid", help="empty string clears it")
    mb.add_argument("--resume", metavar="cmd", help="run with sh -c when a post mentions this member and it isn't live; empty clears it")
    mb.add_argument("--end", metavar="cmd", help="run with sh -c by `room end` to end the member's live session; empty clears it")
    mb.set_defaults(fn=cmd_member)

    en = sub.add_parser("end", help="run a member's end command (ends its live session)")
    en.add_argument("room")
    en.add_argument("id")
    en.set_defaults(fn=cmd_end)

    po = sub.add_parser("post", help="post a message")
    po.add_argument("room")
    po.add_argument("--as", dest="as_", metavar="id")
    po.add_argument("--kind", choices=KINDS, default="msg")
    po.add_argument("--link", action="append", metavar="path")
    po.add_argument("--body-file", metavar="path|-", help="read the text from a file, or stdin with -, as UTF-8")
    po.add_argument("text", nargs="*")
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

    hi = sub.add_parser("herdr-install", help="install, then copy the Rooms panel into the Herdr app")
    hi.add_argument("--dest", metavar="dir", help="default ~/.config/herdr-app/mods/rooms")
    hi.add_argument("--panel-only", action="store_true",
                    help="copy only the panel: leave the room link and config.json's cli as they are")
    hi.set_defaults(fn=cmd_herdr_install)
    return p


def looks_like_option(word):
    """Whether argparse would have read `word` as an option, not as text."""
    if not word.startswith("-") or word == "-" or " " in word:
        return False
    return not re.match(r"^-\d+$|^-\d*\.\d+$", word)


def main(argv):
    p = parser()
    a, extra = p.parse_known_args(argv)
    # `text` is nargs="*" so --body-file can stand in for it, and argparse then
    # leaves words given after an option (`post r --as a hi`) unparsed.
    if extra and a.cmd == "post":
        words = extra[1:] if extra[0] == "--" else extra
        if extra[0] != "--" and any(looks_like_option(w) for w in words):
            p.error("unrecognized arguments: " + " ".join(extra))
        a.text += words
    elif extra:
        p.error("unrecognized arguments: " + " ".join(extra))
    try:
        if a.cmd in ("install", "herdr-install"):
            a.fn(a, None)
            return 0
        root = rooms_root(create=a.cmd == "create")
        a.fn(a, root)
        register_root(root)
    except Refused as e:
        print(str(e), file=sys.stderr)
        return e.code
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
