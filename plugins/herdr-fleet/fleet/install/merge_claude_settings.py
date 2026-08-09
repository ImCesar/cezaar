#!/usr/bin/env python3
"""Non-destructive merge of fleet's permission template into a Claude Code settings.json.

Writes into exactly two paths and nowhere else:

    permissions.allow                 (list of permission rule strings)
    permissions.additionalDirectories (list of paths)

Both are NESTED under "permissions". `additionalDirectories` is a sibling of
`allow`/`deny`/`ask`/`defaultMode`, not a top-level key: written top-level it
merges cleanly, validates, and does nothing.

Two of what it writes cannot live in a static template, because they are
properties of WHERE fleet is installed rather than of the fleet: the fleet home
itself (--add-dir) and any rule naming a path inside it (--add-allow). Both
arrive on the command line and are appended after the template's own entries.

Merge semantics:

  * append-and-dedupe. Entries already present are not re-added; the user's
    existing entries keep their original order and are never removed or
    reordered, including entries the user duplicated themselves.
  * permissions.allow is deduped by exact string match (it holds permission
    rule strings, not paths). permissions.additionalDirectories is deduped by
    os.path.normpath on both sides, so "/x/y" and "/x/y/" count as the same
    directory -- but the user's existing spelling is never rewritten, only a
    duplicate addition is skipped.
  * every other key in the file -- env, hooks, model, statusLine, enabledPlugins,
    permissions.deny, permissions.ask, permissions.defaultMode, anything unknown
    to us -- is carried through untouched.
  * nothing to add => the file is not written at all, so it stays byte-identical.
  * the file is re-serialized with 2-space indent (what Claude Code itself
    writes; verified to round-trip byte-identically on a real settings.json).
    Unrelated keys are guaranteed preserved BY VALUE; byte layout is preserved
    for any file already in that format.
  * if --settings is a symlink (e.g. into a dotfiles repo), the backup, the
    write, and the read-back all happen through os.path.realpath() of it --
    never os.replace() on the symlink itself, which would silently swap the
    symlink for a regular file and orphan whatever it pointed at.
  * an existing .bak is never overwritten: the backup filename gets a numeric
    suffix if a run inside the same second already claimed the timestamp.
  * after writing, the result is read back and every unrelated key is compared
    against the original. A mismatch restores the original and exits nonzero --
    the installer never leaves a settings file it cannot vouch for.

Refuses (exit 2) rather than guessing: unreadable/invalid JSON, a non-object at
the top level, a non-object "permissions", a non-list at either target path, a
non-string entry already inside either target list, a template that asks to
write outside the two allowed paths, or a settings directory it cannot write
to (for the backup or for the merged file).

Usage:
    merge_claude_settings.py --template <file> --settings <file>
                             [--dry-run] [--no-backup] [--quiet]
"""

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
import time

# The only two paths this tool is allowed to touch.
TARGETS = ("allow", "additionalDirectories")

EXIT_OK = 0
EXIT_REFUSED = 2


class Refused(Exception):
    """A condition where guessing would risk the user's settings."""


def load_json_object(path, what):
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
    except OSError as exc:
        raise Refused("cannot read %s %s: %s" % (what, path, exc))
    try:
        data = json.loads(raw)
    except ValueError as exc:
        raise Refused(
            "%s %s is not valid JSON (%s) -- refusing to touch it" % (what, path, exc)
        )
    if not isinstance(data, dict):
        raise Refused("%s %s must be a JSON object, got %s" % (what, path, type(data).__name__))
    return data


def template_additions(template):
    """Pull the two lists out of the template, refusing anything wider."""
    extra_top = [k for k in template if k != "permissions"]
    if extra_top:
        raise Refused(
            "template may only contain a \"permissions\" object; also found: %s"
            % ", ".join(sorted(extra_top))
        )
    perms = template.get("permissions", {})
    if not isinstance(perms, dict):
        raise Refused("template \"permissions\" must be an object")
    extra_nested = [k for k in perms if k not in TARGETS]
    if extra_nested:
        raise Refused(
            "template may only write permissions.%s; also found: %s"
            % ("/".join(TARGETS), ", ".join(sorted(extra_nested)))
        )
    additions = {}
    for key in TARGETS:
        values = perms.get(key, [])
        if not isinstance(values, list) or not all(isinstance(v, str) for v in values):
            raise Refused("template permissions.%s must be a list of strings" % key)
        additions[key] = values
    return additions


RULE = re.compile(r"^([A-Za-z]+)\((.*)\)$")


def rule_prefix(rule):
    """(tool, the literal part of the pattern) for a permission rule string.

    `Bash(git checkout:*)` and `Bash(git checkout -- *)` are two spellings of a
    matcher on the same command prefix, so both reduce to their literal head:
    "git checkout" and "git checkout --". A bare `Bash` (no parentheses) is the
    whole tool, which is the empty prefix -- it matches every command.
    """
    match = RULE.match(rule.strip())
    if not match:
        return rule.strip(), ""
    tool, pattern = match.group(1), match.group(2)
    return tool, pattern.rstrip("*").rstrip(":").strip()


def shadowed_by(settings, wanted):
    """Existing ask/deny rules that would stop a command fleet is going to run.

    THE INSTALLER DOES NOT GET TO WIDEN THESE. An `ask` on `git checkout -- *`
    is an operator's deliberate guard on a destructive command; quietly
    out-voting it from an installer would be the installer deciding something
    that is not its to decide. What it can do is refuse to let the operator
    find out from a stalled unattended run at 2am instead of from here.
    """
    perms = settings.get("permissions")
    if not isinstance(perms, dict):
        return []
    hits = []
    for want in wanted:
        want_tool, want_prefix = rule_prefix(want)
        for list_name in ("deny", "ask"):
            existing = perms.get(list_name)
            if not isinstance(existing, list):
                continue
            for rule in existing:
                if not isinstance(rule, str):
                    continue
                tool, prefix = rule_prefix(rule)
                if tool != want_tool:
                    continue
                # Either direction is a collision: their rule may be narrower
                # than the command (`git checkout -- *` under our `git
                # checkout`), or wider (a bare `Bash` deny over anything).
                if prefix.startswith(want_prefix) or want_prefix.startswith(prefix):
                    hits.append((want, list_name, rule))
    return hits


def merge(settings, additions):
    """Mutate `settings` in place. Returns {key: [entries actually added]}."""
    perms = settings.setdefault("permissions", {})
    if not isinstance(perms, dict):
        raise Refused(
            "existing \"permissions\" is %s, expected an object -- refusing to overwrite it"
            % type(perms).__name__
        )
    added = {}
    for key in TARGETS:
        wanted = additions[key]
        if not wanted:
            added[key] = []
            continue
        existing = perms.get(key)
        if existing is None:
            existing = []
            perms[key] = existing
        if not isinstance(existing, list):
            raise Refused(
                "existing permissions.%s is %s, expected a list -- refusing to overwrite it"
                % (key, type(existing).__name__)
            )
        if not all(isinstance(v, str) for v in existing):
            # set(existing) below would blow up on an unhashable element (e.g.
            # a dict); that's exactly the kind of guess this tool refuses to
            # make, so catch it before it becomes a traceback.
            raise Refused(
                "existing permissions.%s contains a non-string entry -- refusing to merge into it"
                % key
            )
        # additionalDirectories holds filesystem paths, where "/x/y" and
        # "/x/y/" are the same directory; allow holds permission-rule
        # strings, where that normalisation would be wrong. Only the former
        # gets normalised, and only for comparison -- the user's existing
        # spelling is never rewritten.
        normalize = os.path.normpath if key == "additionalDirectories" else (lambda v: v)
        seen = set(normalize(v) for v in existing)
        new = []
        for value in wanted:
            norm_value = normalize(value)
            if norm_value in seen:
                continue  # already present, or repeated within `wanted` itself
            seen.add(norm_value)
            new.append(value)
        existing.extend(new)
        added[key] = new
    return added


def strip_targets(settings):
    """A copy of `settings` with the two merged lists removed.

    Everything left is what the merge promised not to touch, so comparing this
    before and after is the whole safety claim in one expression.
    """
    clone = json.loads(json.dumps(settings))
    perms = clone.get("permissions")
    if isinstance(perms, dict):
        for key in TARGETS:
            perms.pop(key, None)
        # A "permissions" object that held nothing but our two lists is our own
        # doing, not the user's content: drop it, so a file we created from
        # scratch compares equal to the nothing that was there before.
        if not perms:
            clone.pop("permissions")
    return clone


def serialize(settings):
    return json.dumps(settings, indent=2, ensure_ascii=False) + "\n"


def atomic_write(path, text):
    directory = os.path.dirname(os.path.abspath(path)) or "."
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".settings-merge-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def unique_backup_path(path):
    """A ".bak.<timestamp>" path guaranteed not to already exist.

    The timestamp is only second-resolution, so two runs inside the same
    second would otherwise collide -- and the second run would silently
    clobber the first backup, which is the original pre-install state and
    the only one worth keeping.
    """
    base = "%s.bak.%s" % (path, time.strftime("%Y%m%d-%H%M%S"))
    candidate = base
    suffix = 1
    while os.path.exists(candidate):
        candidate = "%s.%d" % (base, suffix)
        suffix += 1
    return candidate


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--template", required=True)
    parser.add_argument("--settings", required=True)
    parser.add_argument(
        "--add-dir",
        action="append",
        default=[],
        metavar="PATH",
        help="extra directory for permissions.additionalDirectories; "
        "repeatable, resolved to an absolute path. Appended after the template's own entries.",
    )
    parser.add_argument(
        "--add-allow",
        action="append",
        default=[],
        metavar="RULE",
        help="extra permissions.allow rule; repeatable, taken verbatim. For rules that "
        "name an install-dependent path, which a static template cannot know. "
        "Appended after the template's own entries.",
    )
    parser.add_argument(
        "--warn-shadowed",
        action="append",
        default=[],
        metavar="RULE",
        help="a command fleet runs but deliberately does NOT grant; report, without "
        "changing anything, any existing ask/deny rule that would stop it. Repeatable.",
    )
    parser.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    parser.add_argument("--no-backup", action="store_true", help="skip the .bak copy of an existing file")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    def say(msg):
        if not args.quiet:
            print(msg)

    try:
        additions = template_additions(load_json_object(args.template, "template"))
        # Directories are a property of where fleet is installed, not of the
        # template, so they arrive on the command line and are absolutised here.
        additions["additionalDirectories"] = additions["additionalDirectories"] + [
            os.path.abspath(os.path.expanduser(d)) for d in args.add_dir
        ]
        # Same reason, for a rule that names a path inside the install: the
        # template can hold `Bash(scripts/herdr-fleet.sh:*)`, which only ever
        # matches a session whose cwd IS the fleet home, and an orchestrator
        # runs in the repo it is orchestrating. The absolute form has to be
        # composed by whoever knows where fleet lives.
        additions["allow"] = additions["allow"] + list(args.add_allow)

        exists = os.path.exists(args.settings)
        # Resolve through any symlink (e.g. ~/.claude/settings.json pointing
        # into a dotfiles repo) before backup, write, or read-back touch the
        # file. os.replace() on a symlink path swaps the symlink itself for a
        # regular file, silently orphaning whatever it used to point at; this
        # also puts the tempfile on the target's filesystem, not the link's.
        real_settings = os.path.realpath(args.settings)
        if real_settings != os.path.abspath(args.settings):
            # Say which it is. A symlinked settings.json is the case an operator
            # needs to see; a symlinked *parent* (macOS /tmp -> /private/tmp) is
            # noise, and calling it "the symlink" either way would be a claim
            # about their setup that is only sometimes true.
            why = "symlink" if os.path.islink(args.settings) else "resolved path"
            say("%s -> %s (writing through the %s)" % (args.settings, real_settings, why))

        if exists:
            with open(real_settings, encoding="utf-8") as fh:
                original_raw = fh.read()
            settings = load_json_object(real_settings, "settings file")
        else:
            original_raw = None
            settings = {}
        untouched_before = strip_targets(settings)

        # Reported before the merge and on every path, including --dry-run and
        # "already up to date": it is a fact about the settings file as it
        # stands, not about what this run changed. stderr, and not silenced by
        # --quiet -- an operator who asked for quiet asked about progress
        # chatter, not about being told their run will stall.
        for want, list_name, rule in shadowed_by(settings, args.warn_shadowed):
            sys.stderr.write(
                "merge-claude-settings: NOT GRANTED and your own settings will stop it:\n"
                "    fleet workers run:      %s\n"
                "    permissions.%-4s holds: %s\n"
                "  An unattended worker stalls on that prompt with nobody watching.\n"
                "  Left exactly as it is: widening a guard you set is your call.\n"
                % (want, list_name, rule)
            )

        added = merge(settings, additions)
        total = sum(len(v) for v in added.values())

        if exists and total == 0:
            say("settings already up to date: %s (not rewritten)" % args.settings)
            return EXIT_OK

        for key in TARGETS:
            for entry in added[key]:
                say("  + permissions.%s: %s" % (key, entry))

        if args.dry_run:
            say("dry run: %s would gain %d entr%s" % (args.settings, total, "y" if total == 1 else "ies"))
            return EXIT_OK

        if exists and not args.no_backup:
            backup = unique_backup_path(real_settings)
            try:
                shutil.copy2(real_settings, backup)
            except OSError as exc:
                raise Refused("cannot write backup %s: %s" % (backup, exc))
            say("backed up existing settings -> %s" % backup)

        try:
            atomic_write(real_settings, serialize(settings))
        except OSError as exc:
            raise Refused("cannot write %s: %s" % (real_settings, exc))

        # Read back and prove the promise: everything outside the two merged
        # lists is still exactly what it was.
        written = load_json_object(real_settings, "written settings file")
        if strip_targets(written) != untouched_before:
            if original_raw is not None:
                atomic_write(real_settings, original_raw)
                raise Refused(
                    "post-write check failed: unrelated keys changed. Original restored."
                )
            os.unlink(real_settings)
            raise Refused("post-write check failed: unrelated keys changed. New file removed.")

        say("merged %d entr%s into %s" % (total, "y" if total == 1 else "ies", args.settings))
        return EXIT_OK

    except Refused as exc:
        sys.stderr.write("merge-claude-settings: %s\n" % exc)
        return EXIT_REFUSED


if __name__ == "__main__":
    sys.exit(main())
