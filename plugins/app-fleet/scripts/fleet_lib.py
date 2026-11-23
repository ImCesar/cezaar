"""Implementation of the `fleet` CLI: the fleet on the Herdr app, talking in rooms.

Python 3.9+, stdlib only, run with -I. Drives git (worktrees, merges), `room` (channels and
threads), `herdr-app do` (spaces, tabs, panes) and `hc` (terminals).

Exit codes: 0 ok, 2 bad usage, 3 refused by state, 4 an external tool failed.
"""

import argparse
import json
import os
import re
import secrets
import subprocess
import sys

NAME = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
CONFIG_KEYS = {"maxThreads": int, "verify": str, "teardown": str}


class Refused(Exception):
    def __init__(self, message, code=3):
        super().__init__(message)
        self.code = code


# ---------- paths and run state ----------

def plugin_root():
    return os.path.dirname(os.path.dirname(os.path.realpath(os.environ.get("APP_FLEET_CLI_PATH") or __file__)))


def home():
    h = os.environ.get("APP_FLEET_HOME") or os.path.expanduser("~/.app-fleet")
    os.makedirs(h, exist_ok=True)
    return os.path.realpath(h)


def check_name(kind, value):
    if not NAME.match(value or ""):
        raise Refused(f"fleet: bad {kind} name {value!r} (use a-z 0-9 _ -)", 2)
    return value


def run_dir(name):
    return os.path.join(home(), "runs", check_name("run", name))


def load_run(name):
    path = os.path.join(run_dir(name), "run.json")
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        raise Refused(f"fleet: no run {name!r} (start one with `fleet lead`)", 3)


def save_run(run):
    d = run_dir(run["run"])
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "run.json")
    tmp = f"{path}.{os.getpid()}.{secrets.token_hex(3)}.tmp"
    with open(tmp, "w") as fh:
        json.dump(run, fh, indent=1)
        fh.write("\n")
    os.replace(tmp, path)


def rooms_root(run):
    return os.path.join(run_dir(run["run"]), "rooms")


# ---------- external tools ----------

def tool(argv, env=None, cwd=None, check=False):
    try:
        r = subprocess.run(argv, capture_output=True, text=True, env=env, cwd=cwd)
    except FileNotFoundError:
        raise Refused(f"fleet: {argv[0]} is not installed or not on PATH", 4)
    if check and r.returncode != 0:
        raise Refused(f"fleet: {' '.join(argv[:3])} failed: {(r.stderr or r.stdout).strip()}", 4)
    return r


def room(run, *args, check=True):
    env = {**os.environ, "ROOMS_ROOT": rooms_root(run)}
    return tool(["room", *args], env=env, check=check)


def herdr(*args):
    """`herdr-app do <args>`; returns the parsed JSON reply."""
    r = tool(["herdr-app", "do", *args])
    try:
        reply = json.loads(r.stdout or "{}")
    except ValueError:
        reply = {}
    if r.returncode != 0 or (isinstance(reply, dict) and "error" in reply):
        raise Refused(f"fleet: herdr-app do {args[0]} failed: {reply.get('error') if isinstance(reply, dict) else r.stderr}", 4)
    return reply


def require_app():
    r = tool(["herdr-app", "status"])
    if r.returncode != 0:
        raise Refused("fleet: open the Herdr app first (herdr-app status failed)", 4)


def operator():
    cfg_dir = os.environ.get("ROOMS_CONFIG_DIR") or os.path.expanduser("~/.config/rooms")
    try:
        with open(os.path.join(cfg_dir, "config.json")) as fh:
            return str(json.load(fh).get("operator") or "cesar")
    except (OSError, ValueError):
        return "cesar"


# ---------- commands ----------

def cmd_config(a):
    run = load_run(a.run)
    if a.key not in CONFIG_KEYS:
        raise Refused(f"fleet: unknown setting {a.key!r}; settable: {', '.join(CONFIG_KEYS)}", 2)
    try:
        run[a.key] = CONFIG_KEYS[a.key](a.value)
    except ValueError:
        raise Refused(f"fleet: {a.key} needs a {CONFIG_KEYS[a.key].__name__}", 2)
    save_run(run)


def thread_rows(run):
    rows = []
    for task, t in run.get("threads", {}).items():
        members = []
        for mid in t.get("members", []):
            r = room(run, "presence-get", t.get("room", task), mid, check=False)
            try:
                state = json.loads(r.stdout or "{}").get("state", "?")
            except ValueError:
                state = "?"
            members.append({"id": mid, "state": state})
        rows.append({"task": task, "template": t.get("template"), "state": t.get("state"), "members": members})
    return rows


def cmd_status(a):
    run = load_run(a.run)
    rows = thread_rows(run)
    if a.json:
        json.dump({**run, "threadRows": rows}, sys.stdout)
        print()
        return
    print(f"run {run['run']}  repo {run['repo']}  integration {run['integration']}  max {run['maxThreads']} threads")
    if not rows:
        print("  no threads yet")
    for r in rows:
        people = ", ".join(f"{m['id']} {m['state']}" for m in r["members"])
        print(f"  #{r['task']:<20} {r['template']:<9} {r['state']:<7} {people}")


# ---------- entry ----------

def parser():
    p = argparse.ArgumentParser(prog="fleet", description="Run the fleet on the Herdr app, talking in rooms.")
    sub = p.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("config", help="change a run setting (maxThreads, verify, teardown)")
    c.add_argument("run")
    c.add_argument("key")
    c.add_argument("value")
    c.set_defaults(fn=cmd_config)

    s = sub.add_parser("status", help="threads, members and their states")
    s.add_argument("run")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_status)
    return p


def main(argv):
    a = parser().parse_args(argv)
    try:
        a.fn(a)
    except Refused as e:
        print(str(e), file=sys.stderr)
        return e.code
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
