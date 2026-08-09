#!/bin/sh
# install-permissions.sh -- merge fleet's permission template into a Claude Code
# settings.json without disturbing anything already in it.
#
# Usage:
#   install/install-permissions.sh [options]
#
#   --settings <path>   settings file to merge into
#                       (default: <fleet-home>/.claude/settings.json)
#   --user              shorthand for --settings "$HOME/.claude/settings.json"
#   --fleet-home <dir>  fleet root; granted in permissions.additionalDirectories,
#                       and the absolute wrapper path is allowed from it. Both
#                       the given path and its resolved path when they differ.
#                       (default: the repo this script lives in)
#   --template <file>   permission template (default: install/claude-permissions.json)
#   --dry-run           print what would change, write nothing
#   --no-backup         skip the timestamped .bak copy
#
# The merge itself lives in merge_claude_settings.py -- read its docstring for
# the exact guarantees. This wrapper only decides WHICH files to hand it.
# Python 3 is the single dependency: no Node, no jq, both of which would be a
# heavier ask than the thing being installed.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH='' cd -- "$here/.." && pwd)

die() { echo "install-permissions: $*" >&2; exit 1; }

settings=""
fleet_home="$repo"
template="$here/claude-permissions.json"
user_scope=0
extra=""

while [ $# -gt 0 ]; do
  case "$1" in
    --settings)   [ $# -ge 2 ] || die "--settings needs a path";   settings="$2"; shift 2 ;;
    --user)       user_scope=1; shift ;;
    --fleet-home) [ $# -ge 2 ] || die "--fleet-home needs a path"; fleet_home="$2"; shift 2 ;;
    --template)   [ $# -ge 2 ] || die "--template needs a path";   template="$2"; shift 2 ;;
    --dry-run)    extra="$extra --dry-run"; shift ;;
    --no-backup)  extra="$extra --no-backup"; shift ;;
    # The header, however long it is: a pinned line range silently truncates
    # --help the next time someone documents a flag, and the flag they were
    # documenting is the one that disappears.
    -h|--help)    awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *)            die "unknown argument: $1" ;;
  esac
done

[ -d "$fleet_home" ] || die "fleet home is not a directory: $fleet_home"
fleet_home=$(CDPATH='' cd -- "$fleet_home" && pwd)
# A SYMLINKED FLEET HOME IS THE NORMAL CASE, not an exotic one: `~/.fleet` is
# how the docs tell you to reach an install that is really a checkout somewhere
# else, and then the path a session USES and the path it RESOLVES TO are two
# different strings. Which of the two a permission grant is matched against is
# not something to assume, so both are granted -- the cost is one redundant
# line in a settings file, and the failure it prevents is a stalled unattended
# run that nobody is watching.
fleet_home_real=$(CDPATH='' cd -- "$fleet_home" && pwd -P)

if [ -z "$settings" ]; then
  if [ "$user_scope" -eq 1 ]; then
    settings="$HOME/.claude/settings.json"
  else
    settings="$fleet_home/.claude/settings.json"
  fi
elif [ "$user_scope" -eq 1 ]; then
  die "--user and --settings both given; pick one"
fi

[ -f "$template" ] || die "template not found: $template"
command -v python3 >/dev/null 2>&1 || die "python3 not found (required)"

echo "template:   $template"
echo "settings:   $settings"
echo "fleet home: $fleet_home"
[ "$fleet_home_real" = "$fleet_home" ] || echo "            -> $fleet_home_real (granting both)"

# The template's `Bash(scripts/herdr-fleet.sh:*)` is a RELATIVE rule, so it
# only ever matches a session whose cwd is the fleet home. An orchestrator runs
# in the repo it is orchestrating and reaches the wrapper by absolute path, and
# that command is a different string with a different prefix. Only the
# installer knows where fleet lives, so only the installer can compose it.
set -- --add-dir "$fleet_home" --add-allow "Bash($fleet_home/scripts/herdr-fleet.sh:*)"
if [ "$fleet_home_real" != "$fleet_home" ]; then
  set -- "$@" --add-dir "$fleet_home_real" --add-allow "Bash($fleet_home_real/scripts/herdr-fleet.sh:*)"
fi

# THE SHARP COMMANDS ARE NOT INSTALLED MACHINE-WIDE, DELIBERATELY: workers get
# them per session, in a worktree of their own (see worker-permissions.json and
# the wrapper's spawn). But an operator can have a guard of their own on one of
# those commands -- an `ask` on `git checkout -- *` is a perfectly sensible
# thing to have -- and that guard stops a worker just as dead. Widening it is
# the operator's decision, so this reports the collision and changes nothing.
# Captured into a variable FIRST, and checked. Read straight into the heredoc,
# a failing python -- an unparseable worker-permissions.json, say -- leaves the
# loop with nothing to iterate and the install exits 0 having quietly skipped
# the entire disclosure. A warning that can vanish without a word is worse than
# no warning: it reads as "you have no conflicting guards".
worker_perms="$here/worker-permissions.json"
if [ -f "$worker_perms" ]; then
  worker_rules=$(python3 -c 'import json,sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
print("\n".join(data.get("permissions", {}).get("allow", [])))' "$worker_perms") \
    || die "cannot read the worker permission set ($worker_perms) -- refusing to install without the guard disclosure"
  while IFS= read -r rule; do
    [ -n "$rule" ] && set -- "$@" --warn-shadowed "$rule"
  done <<EOF
$worker_rules
EOF
else
  echo "install-permissions: no $worker_perms -- installing without the guard disclosure" >&2
fi

# shellcheck disable=SC2086  # $extra is a deliberate list of flags
exec python3 "$here/merge_claude_settings.py" \
  --template "$template" \
  --settings "$settings" \
  "$@" \
  $extra
