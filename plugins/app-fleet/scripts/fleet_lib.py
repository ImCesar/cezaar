"""Implementation of the `fleet` CLI: the fleet on the Herdr app, talking in rooms.

Python 3.9+, stdlib only, run with -I. Drives git (worktrees, merges), `room` (channels and
threads), `herdr-app do` (spaces, tabs, panes) and `hc` (terminals).

Exit codes: 0 ok, 2 bad usage, 3 refused by state, 4 an external tool failed.
"""

import argparse
import json
import shutil
import time
import os
import re
import secrets
import subprocess
import sys

NAME = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
# git cannot hold a branch that is also a folder of branches, so the integration branch
# lives beside the thread branches: fleet/<run>/integration and fleet/<run>/<task>.
RESERVED_TASKS = ("integration", "lead")
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


# ---------- roster ----------

def roster_dir():
    return os.environ.get("APP_FLEET_ROSTER") or os.path.join(plugin_root(), "roster")


def persona(name):
    """A persona file: frontmatter {name, model, effort, description} and the body."""
    path = os.path.join(roster_dir(), "personas", f"{name}.md")
    try:
        with open(path) as fh:
            text = fh.read()
    except FileNotFoundError:
        raise Refused(f"fleet: no persona {name!r} in {roster_dir()}", 3)
    meta, body = {}, text
    if text.startswith("---\n"):
        head, _, body = text[4:].partition("\n---\n")
        for line in head.splitlines():
            k, _, v = line.partition(":")
            if k.strip():
                meta[k.strip()] = v.strip()
    return {"name": meta.get("name", name), "model": meta.get("model", ""), "effort": meta.get("effort", ""),
            "description": meta.get("description", ""), "body": body.strip() + "\n"}


def templates():
    with open(os.path.join(roster_dir(), "templates.json")) as fh:
        return json.load(fh)


def cmd_roster_check(a):
    problems = []
    try:
        tpl = templates()
    except (OSError, ValueError) as e:
        raise Refused(f"fleet: templates.json unreadable: {e}", 3)
    names = sorted({p for members in tpl.values() for p in members} | {"lead"})
    for n in names:
        try:
            p = persona(n)
        except Refused:
            problems.append(f"missing persona {n}")
            continue
        if not p["model"] or not p["effort"]:
            problems.append(f"persona {n} has no model or effort")
    if not os.path.exists(os.path.join(roster_dir(), "norms.md")):
        problems.append("missing norms.md")
    if problems:
        raise Refused("fleet: roster problems: " + "; ".join(problems), 3)
    print(f"roster ok: {len(names)} personas, {len(tpl)} templates")


# ---------- composing a member ----------

MEMORY_CAP = 4096
REVIEW_BAR_PERSONAS = ("reviewer", "judge")


def _read(path):
    try:
        with open(path) as fh:
            return fh.read()
    except OSError:
        return ""


def compose_member(run, member_id, persona_name, task, worktree=None, room_name=None, extra_allow=()):
    """Write the member's prompt and settings files; return their paths and the launch argv."""
    p = persona(persona_name)
    d = run_dir(run["run"])
    members = os.path.join(d, "members")
    os.makedirs(members, exist_ok=True)
    room_name = room_name or task
    brief = os.path.join(d, "briefs", f"{task}.md")
    report = os.path.join(d, "reports", f"{task}.md")
    parts = [p["body"], _read(os.path.join(roster_dir(), "norms.md"))]
    if persona_name in REVIEW_BAR_PERSONAS:
        parts.append(_read(os.path.join(roster_dir(), "policy", "review-bar.md")))
    memory = _read(os.path.join(home(), "memory", persona_name, "MEMORY.md"))
    if memory:
        parts.append("## What earlier runs taught this role\n\n" + memory.encode()[:MEMORY_CAP].decode("utf-8", "ignore"))
    parts.append("\n".join([
        "## Who and where you are",
        "",
        f"- You are `{member_id}` ({persona_name}) in run `{run['run']}`.",
        f"- Your thread room: `{room_name}`. The stage channel: `{run['stage']}`.",
        f"- Your worktree: `{worktree or '(none)'}`. Work only there.",
        f"- Your brief: `{brief}`. Write your report to `{report}`.",
        f"- The lead is `lead`; the operator is `{operator()}`.",
    ]))
    prompt_path = os.path.join(members, f"{member_id}.prompt.md")
    with open(prompt_path, "w") as fh:
        fh.write("\n\n".join(x.strip() for x in parts if x.strip()) + "\n")
    # Briefs and reports live in the run folder, outside the worktree: make it a working folder
    # and allow edits there, or an unattended member would stop at a permission prompt.
    allow = ["Bash(room *)", f"Edit({d}/**)", *extra_allow]
    if persona_name == "runner":
        allow += [f"Bash({run[k]})" for k in ("verify", "teardown") if run.get(k)]
    env = {"ROOM_ID": member_id, "ROOMS_ROOT": rooms_root(run), "APP_FLEET_RUN": run["run"], "APP_FLEET_HOME": home()}
    settings_path = os.path.join(members, f"{member_id}.settings.json")
    with open(settings_path, "w") as fh:
        json.dump({"env": env, "permissions": {"allow": allow, "additionalDirectories": [d]}}, fh, indent=1)
    first = (f"You are {member_id}. Read your brief at {brief} and the room {room_name} "
             f"(room read {room_name}), then begin.")
    argv = ["env", *[f"{k}={v}" for k, v in env.items()], "claude", "--model", p["model"], "--effort", p["effort"],
            "--settings", settings_path, "--append-system-prompt-file", prompt_path, first]
    return {"prompt_path": prompt_path, "settings_path": settings_path, "argv": argv}


def cmd_compose(a):
    run = load_run(a.run)
    json.dump(compose_member(run, a.member, a.persona, a.task), sys.stdout)
    print()


# ---------- git ----------

def git(repo, *args, check=True):
    return tool(["git", "-C", repo, *args], check=check)


def branch_exists(repo, branch):
    return git(repo, "rev-parse", "--verify", "--quiet", f"refs/heads/{branch}", check=False).returncode == 0


def wt_root(run):
    return os.path.join(run["repo"], ".worktrees", run["run"])


def integration_wt(run):
    return os.path.join(wt_root(run), "_integration")


def ensure_integration(run):
    """The run's integration branch and worktree, cut from the base the first time."""
    wt = integration_wt(run)
    if os.path.isdir(wt):
        return wt
    os.makedirs(wt_root(run), exist_ok=True)
    if branch_exists(run["repo"], run["integration"]):
        git(run["repo"], "worktree", "add", wt, run["integration"])
    else:
        git(run["repo"], "worktree", "add", "-b", run["integration"], wt, run["base"])
    return wt


# ---------- Herdr terminals ----------

TRUST_MSG = "trust this folder"


def term_status(term):
    r = tool(["hc", "get", term, "--json"])
    try:
        return json.loads(r.stdout or "{}").get("status") or {}
    except ValueError:
        return {}


def clear_trust(term, timeout_s=None):
    """Answer Claude's trust prompt for a fresh worktree: Down, then Enter (Enter alone means No)."""
    deadline = time.time() + (timeout_s if timeout_s is not None else float(os.environ.get("APP_FLEET_TRUST_WAIT", "25")))
    while time.time() < deadline:
        st = term_status(term)
        if st.get("msg") == TRUST_MSG:
            tool(["hc", "keys", term, "down", "enter"])
            return True
        if st.get("state") in ("idle", "done", "working"):
            return False
        time.sleep(1)
    return False


def pane_of(tab):
    reply = tool(["herdr-app", "ls"])
    try:
        for sp in json.loads(reply.stdout or "{}").get("spaces", []):
            for t in sp.get("tabs", []):
                if t.get("id") == tab and t.get("terminals"):
                    return t["terminals"][0]["pane"]
    except (ValueError, KeyError, IndexError):
        pass
    raise Refused(f"fleet: could not find the pane of tab {tab}", 4)


def spawn_members(run, task, folder, composed):
    """First member in a new tab named after the task, the rest split beside it."""
    first = composed[0]
    reply = herdr("tab.new", "--name", task, *(("--space", run["space"]) if run.get("space") else ()),
                  "--focus", "false", "--folder", folder, "--argv", json.dumps(first["argv"]))
    tab, terms = reply["tab"], [reply["terminal"]]
    clear_trust(reply["terminal"])
    pane = pane_of(tab)
    for c in composed[1:]:
        r = herdr("pane.split", "--direction", "right", "--pane", pane, "--argv", json.dumps(c["argv"]))
        terms.append(r["terminal"])
    return tab, terms


# ---------- threads ----------

def open_threads(run):
    return [t for t, v in run.get("threads", {}).items() if v.get("state") == "open"]


def cmd_thread_open(a):
    run = load_run(a.run)
    task = check_name("task", a.task)
    if task in RESERVED_TASKS:
        raise Refused(f"fleet: {task!r} is a reserved name", 2)
    tpl = templates()
    if a.template not in tpl:
        raise Refused(f"fleet: unknown template {a.template!r}; known: {', '.join(tpl)}", 2)
    if task in run["threads"]:
        raise Refused(f"fleet: a thread named {task!r} already exists in run {run['run']}", 3)
    open_now = open_threads(run)
    if len(open_now) >= int(run.get("maxThreads", 4)):
        raise Refused(f"fleet: {len(open_now)} threads are open ({', '.join(open_now)}); maxThreads is {run['maxThreads']}", 3)
    if not os.path.isfile(a.brief):
        raise Refused(f"fleet: no brief at {a.brief}", 2)
    if a.from_ and a.from_ not in run["threads"]:
        raise Refused(f"fleet: no thread {a.from_!r} to branch from", 3)
    if a.template == "judge":  # judge-<task>: one judge, working in the disputed thread's worktree
        disputed = task[len("judge-"):] if task.startswith("judge-") else ""
        if disputed not in run["threads"]:
            raise Refused(f"fleet: a judge thread is named judge-<task> after an existing thread", 2)
        a.folder = run["threads"][disputed]["worktree"]
    require_app()
    made = {"worktree": None, "branch": None, "room": None}
    try:
        open_thread(run, task, a.template, a.brief, a.from_, a.wave, made, folder=a.folder)
    except Exception:
        undo_open(run, task, made)
        raise
    print(f"opened #{task} ({a.template}): {', '.join(run['threads'][task]['members'])}")


def open_thread(run, task, template, brief_src, from_task, wave, made, folder=None):
    personas = templates()[template]
    op = operator()
    ensure_integration(run)
    room_name = task
    if folder:  # verify and judge threads use an existing worktree and make no branch
        wt, branch = folder, None
    else:
        wt = os.path.join(wt_root(run), task)
        branch = f"fleet/{run['run']}/{task}"
        start = run["threads"][from_task]["branch"] if from_task else run["integration"]
        git(run["repo"], "worktree", "add", "-b", branch, wt, start)
        made["worktree"], made["branch"] = wt, branch
    d = run_dir(run["run"])
    os.makedirs(os.path.join(d, "briefs"), exist_ok=True)
    os.makedirs(os.path.join(d, "reports"), exist_ok=True)
    dest = os.path.join(d, "briefs", f"{task}.md")
    if os.path.realpath(brief_src) != os.path.realpath(dest):  # the lead may write it there directly
        shutil.copyfile(brief_src, dest)
    ids = [task] if template == "judge" else [f"{p}-{task}" for p in personas]
    room(run, "create", run["stage"], "--member", f"{op}:operator")
    room(run, "create", room_name, *[x for i, p in zip(ids, personas) for x in ("--member", f"{i}:{p}")],
         "--member", f"{op}:operator")
    made["room"] = os.path.join(rooms_root(run), room_name)
    for i, p in zip(ids, personas):
        room(run, "join", run["stage"], i, "--role", p)
    composed = [compose_member(run, i, p, task, worktree=wt, room_name=room_name) for i, p in zip(ids, personas)]
    tab, terms = spawn_members(run, task, wt, composed)
    mentions = " ".join(f"@{i}" for i in ids)
    room(run, "post", room_name, "--as", "lead", f"{mentions} brief: {os.path.join(d, 'briefs', task + '.md')}")
    run["threads"][task] = {"template": template, "room": room_name, "branch": branch, "worktree": wt,
                            "tab": tab, "terminals": terms, "members": ids, "state": "open", "wave": wave}
    save_run(run)


def undo_open(run, task, made):
    if made.get("worktree"):
        git(run["repo"], "worktree", "remove", "--force", made["worktree"], check=False)
    if made.get("branch"):
        git(run["repo"], "branch", "-D", made["branch"], check=False)
    if made.get("room") and os.path.isdir(made["room"]):
        shutil.rmtree(made["room"], ignore_errors=True)
    run["threads"].pop(task, None)


def is_merged(run, branch):
    return git(run["repo"], "merge-base", "--is-ancestor", branch, run["integration"], check=False).returncode == 0


def close_thread(run, task):
    t = run["threads"].get(task)
    if not t:
        raise Refused(f"fleet: no thread {task!r} in run {run['run']}", 3)
    for term in t.get("terminals", []):
        tool(["hc", "kill", term])  # a terminal that already ended is fine
    # Ended on purpose, not crashed: say so in every room they were in, so the lead's
    # silence check does not report them as gone quiet in the channel.
    for mid in t.get("members", []):
        for rn in (t.get("room", task), run["stage"]):
            room(run, "presence", rn, mid, "gone", check=False)
    room(run, "archive", t.get("room", task), check=False)
    if t.get("tab"):
        tool(["herdr-app", "do", "tab.close", "--id", t["tab"], "--confirmed", "true"])  # killing usually closes it
    note = ""
    if t.get("branch"):
        if is_merged(run, t["branch"]):
            git(run["repo"], "worktree", "remove", "--force", t["worktree"], check=False)
        else:
            note = f" (worktree kept: {t['branch']} is unmerged)"
    t["state"] = "closed"
    save_run(run)
    return note


def cmd_thread_close(a):
    run = load_run(a.run)
    note = close_thread(run, a.task)
    print(f"closed #{a.task}{note}")


def cmd_cleanup(a):
    run = load_run(a.run)
    for task in open_threads(run):
        close_thread(run, task)
    for task, t in run["threads"].items():
        if t.get("branch") and branch_exists(run["repo"], t["branch"]) and is_merged(run, t["branch"]):
            if not os.path.isdir(t.get("worktree") or ""):
                git(run["repo"], "branch", "-D", t["branch"], check=False)  # merged into integration, checked above
    if a.all:
        if os.path.isdir(integration_wt(run)):
            git(run["repo"], "worktree", "remove", "--force", integration_wt(run), check=False)
        if run.get("space"):
            tool(["herdr-app", "do", "space.close", "--id", run["space"], "--confirmed", "true"])
        run["space"], run["leadTab"] = None, None
        save_run(run)
    git(run["repo"], "worktree", "prune", check=False)
    print(f"cleaned up run {run['run']}; {run['integration']} is kept for you")


def cmd_merge(a):
    run = load_run(a.run)
    t = run["threads"].get(a.task)
    if not t or not t.get("branch"):
        raise Refused(f"fleet: no thread {a.task!r} with a branch to merge", 3)
    wt = ensure_integration(run)
    if git(wt, "status", "--porcelain").stdout.strip():
        raise Refused(f"fleet: the integration worktree {wt} has uncommitted changes; clean it first", 3)
    r = git(wt, "merge", "--no-ff", "-m", f"fleet: merge {a.task}", t["branch"], check=False)
    if r.returncode != 0:
        conflicted = git(wt, "diff", "--name-only", "--diff-filter=U", check=False).stdout.split()
        git(wt, "merge", "--abort", check=False)
        raise Refused(f"fleet: merging {t['branch']} conflicts in: {', '.join(conflicted) or '(see git)'}; "
                      f"open a fix thread with --from {a.task}", 3)
    head = git(wt, "rev-parse", "--short", "HEAD").stdout.strip()
    print(f"merged {t['branch']} into {run['integration']} at {head}")


VERIFY_BRIEF = """# Verify wave {wave}

Run the full suite once on the merged tree in your worktree (the integration worktree).

1. Run: `{verify}`
2. Whatever the result, run the teardown so no simulator or container is left behind: `{teardown}`
3. Write what ran and what failed to your report.
4. Post the result:
   - all green: `room post {task} --kind done "@lead done: wave {wave} verified — report: <path>"`
   - anything failed: `room post {task} "@lead wave {wave} failed: <the failing tests, one line each> — report: <path>"`

Do not fix anything yourself. The lead opens fix threads from your report.
"""


def cmd_verify(a):
    run = load_run(a.run)
    if not run.get("verify"):
        raise Refused("fleet: no verify command for this run; set it with `fleet config <run> verify \"<cmd>\"`", 3)
    task = f"verify-w{a.wave}"
    tmp = os.path.join(run_dir(run["run"]), f".{task}.brief.md")
    with open(tmp, "w") as fh:
        fh.write(VERIFY_BRIEF.format(wave=a.wave, verify=run["verify"], teardown=run.get("teardown") or "true", task=task))
    a2 = argparse.Namespace(run=a.run, task=task, template="verify", brief=tmp, from_=None, wave=a.wave,
                            folder=ensure_integration(run))
    try:
        cmd_thread_open(a2)
    finally:
        os.remove(tmp)


# ---------- the lead ----------

def exclude_worktrees(repo):
    common = git(repo, "rev-parse", "--git-common-dir").stdout.strip()
    common = common if os.path.isabs(common) else os.path.join(repo, common)
    path = os.path.join(common, "info", "exclude")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = _read(path).splitlines()
    if ".worktrees/" not in lines:
        with open(path, "a") as fh:
            fh.write(("" if not lines or _read(path).endswith("\n") else "\n") + ".worktrees/\n")


def launch_lead(run, first_message):
    c = compose_member(run, "lead", "lead", "lead", worktree=run["repo"], room_name=run["stage"],
                       extra_allow=("Bash(fleet *)", "Bash(git *)"))
    argv = c["argv"][:-1] + [first_message]
    if run.get("space"):
        reply = herdr("tab.new", "--name", "lead", "--space", run["space"], "--folder", run["repo"], "--argv", json.dumps(argv))
    else:
        reply = herdr("space.new", "--name", run["run"], "--folder", run["repo"], "--tab", "lead", "--argv", json.dumps(argv))
        run["space"] = reply.get("space")
    run["leadTab"] = reply.get("tab")
    clear_trust(reply["terminal"])
    save_run(run)


def cmd_lead(a):
    name = check_name("run", a.run)
    path = os.path.join(run_dir(name), "run.json")
    if os.path.exists(path):  # resume: never reset rooms or threads
        run = load_run(name)
        require_app()
        launch_lead(run, f"You are the lead of run {name}, resuming. Run `fleet status {name}` and "
                         f"`room read {run['stage']}` first, then carry on.")
        print(f"resumed run {name}: switch to its lead tab")
        return
    if not a.repo or not a.architecture:
        raise Refused("fleet: a new run needs --repo and --architecture", 2)
    repo = os.path.realpath(a.repo)
    if tool(["git", "-C", repo, "rev-parse", "--is-inside-work-tree"]).returncode != 0:
        raise Refused(f"fleet: {repo} is not a git work tree", 3)
    arch = os.path.realpath(a.architecture)
    if not os.path.isfile(arch):
        raise Refused(f"fleet: no architecture file at {arch}", 2)
    require_app()
    base = a.base or git(repo, "branch", "--show-current").stdout.strip() or "main"
    run = {"run": name, "repo": repo, "stage": "execution", "base": base, "integration": f"fleet/{name}/integration",
           "space": None, "leadTab": None, "maxThreads": 4, "verify": a.verify, "teardown": a.teardown,
           "architecture": arch, "threads": {}}
    try:
        save_run(run)
        os.makedirs(rooms_root(run), exist_ok=True)
        exclude_worktrees(repo)
        room(run, "create", run["stage"], "--member", f"{operator()}:operator")
        room(run, "join", run["stage"], "lead", "--role", "lead", "--watch-all")
        launch_lead(run, f"You are the lead of run {name}. Read the architecture at {arch}, then plan the waves.")
    except Exception:
        shutil.rmtree(run_dir(name), ignore_errors=True)
        raise
    print(f"started run {name}: switch to the lead tab in the {name} space")


def cmd_install(a):
    target = os.path.realpath(os.environ.get("APP_FLEET_CLI_PATH") or os.path.join(os.path.dirname(__file__), "fleet"))
    bindir = os.environ.get("APP_FLEET_BIN_DIR") or os.path.expanduser("~/.local/bin")
    os.makedirs(bindir, exist_ok=True)
    link = os.path.join(bindir, "fleet")
    if os.path.lexists(link) and not os.path.islink(link):
        raise Refused(f"fleet: {link} exists and is not a symlink; move it away or set APP_FLEET_BIN_DIR", 2)
    if os.path.islink(link) and os.path.realpath(link) != target:
        os.remove(link)
    if not os.path.lexists(link):
        os.symlink(target, link)
    print(target)


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

    r = sub.add_parser("roster", help="roster tools")
    rs = r.add_subparsers(dest="roster_cmd", required=True)
    rc = rs.add_parser("check", help="every template persona exists with a model and effort")
    rc.set_defaults(fn=cmd_roster_check)

    co = sub.add_parser("_compose")  # for tests: compose one member and print the result
    co.add_argument("run")
    co.add_argument("member")
    co.add_argument("persona")
    co.add_argument("task")
    co.set_defaults(fn=cmd_compose)

    th = sub.add_parser("thread", help="open or close a thread")
    ths = th.add_subparsers(dest="thread_cmd", required=True)
    to = ths.add_parser("open", help="open a thread: worktree, room, members, brief")
    to.add_argument("run")
    to.add_argument("task")
    to.add_argument("--template", required=True)
    to.add_argument("--brief", required=True)
    to.add_argument("--from", dest="from_", metavar="task")
    to.add_argument("--wave", type=int)
    to.set_defaults(fn=cmd_thread_open, folder=None)
    tc = ths.add_parser("close", help="archive the room, end its terminals, remove a merged worktree")
    tc.add_argument("run")
    tc.add_argument("task")
    tc.set_defaults(fn=cmd_thread_close)

    cl = sub.add_parser("cleanup", help="close every thread; --all also removes the integration worktree and space")
    cl.add_argument("run")
    cl.add_argument("--all", action="store_true")
    cl.set_defaults(fn=cmd_cleanup)

    mg = sub.add_parser("merge", help="merge a thread's branch into the run's integration branch")
    mg.add_argument("run")
    mg.add_argument("task")
    mg.set_defaults(fn=cmd_merge)

    vf = sub.add_parser("verify", help="open a verify thread for a wave on the integration worktree")
    vf.add_argument("run")
    vf.add_argument("wave", type=int)
    vf.set_defaults(fn=cmd_verify)

    ld = sub.add_parser("lead", help="start a run and its lead (or resume an existing run's lead)")
    ld.add_argument("run")
    ld.add_argument("--repo")
    ld.add_argument("--architecture")
    ld.add_argument("--base")
    ld.add_argument("--verify")
    ld.add_argument("--teardown")
    ld.set_defaults(fn=cmd_lead)

    ins = sub.add_parser("install", help="put fleet on PATH (~/.local/bin)")
    ins.set_defaults(fn=cmd_install)
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
