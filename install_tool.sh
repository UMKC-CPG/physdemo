#!/usr/bin/env bash

# install_tool.sh -- make one demonstration tool's commands available
#   in a physdemo suite, named without their ".py" suffix. For each
#   entry point it makes two links: links/<name>, which names the
#   tool's script, and bin/<name>, which names the suite's launcher
#   (libexec/physdemo-launch; its header comment says what it is for).
#
# A tool is a repository laid out as the group's project template has
#   it: executable entry points in src/scripts/<name>.py, each beginning
#   with "#!/usr/bin/env python3", each finding its own library beside
#   itself (so nothing needs to be pip-installed), with its defaults in
#   src/scripts/<name>rc.py. Files ending in "rc.py" and the template's
#   XYZ.py are not entry points and are skipped.
#
# Usage:
#   ./install_tool.sh [--prefix DIR] [--force] TOOL_REPO
#
#   --prefix DIR   The suite root that install.sh made.
#                  Default: $PHYSDEMO_HOME, else $HOME/physdemo
#   --force        Replace a command that already links somewhere else.
#   TOOL_REPO      The tool's repository: a working copy for a "dev"
#                  suite, a tagged checkout for a "release" suite.
#
# The links are symbolic and absolute, so the tool is never copied: a
#   working copy stays live, and updating a release is `git checkout` in
#   the checkout. An entry point must resolve symlinks when it looks for
#   its library (Path(__file__).resolve() or os.path.realpath), because
#   it will be run through one.

set -euo pipefail

prefix="${PHYSDEMO_HOME:-$HOME/physdemo}"
force=0
tool_repo=""

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)  prefix="$2"; shift 2 ;;
        --force)   force=1; shift ;;
        -h|--help) sed -n '3,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "install_tool.sh: unknown option: $1" >&2; exit 2 ;;
        *)  tool_repo="$1"; shift ;;
    esac
done

[ -n "$tool_repo" ] || { echo "install_tool.sh: no TOOL_REPO given" >&2
                         exit 2; }
[ -d "$prefix/bin" ] || { echo "install_tool.sh: $prefix is not a suite" \
                               "(run install.sh first)" >&2; exit 1; }
[ -x "$prefix/libexec/physdemo-launch" ] \
    || { echo "install_tool.sh: $prefix has no launcher; re-run" \
              "install.sh on it first (it keeps the installed tools)" >&2
         exit 1; }
scripts_dir="$(cd "$tool_repo/src/scripts" 2>/dev/null && pwd -P)" \
    || { echo "install_tool.sh: $tool_repo has no src/scripts/" >&2
         exit 1; }
tool_name="$(basename "$(dirname "$(dirname "$scripts_dir")")")"

linked=0
for script in "$scripts_dir"/*.py; do
    [ -e "$script" ] || continue
    base="$(basename "$script" .py)"
    case "$base" in
        *rc|XYZ) continue ;;                 # defaults files; the template
    esac
    if ! head -1 "$script" | grep -q '^#!.*python'; then
        echo "  skip $base: no python shebang on its first line"
        continue
    fi
    if [ ! -x "$script" ]; then
        echo "  skip $base: not executable (chmod +x $script)"
        continue
    fi
    target="$prefix/links/$base"
    # Where the command points now: links/<name>, or, in a suite made
    #   before the launcher existed, bin/<name> itself.
    current=""
    if [ -L "$target" ]; then
        current="$(readlink "$target")"
    elif [ -L "$prefix/bin/$base" ]; then
        current="$(readlink "$prefix/bin/$base")"
    fi
    if [ -n "$current" ] && [ "$current" != "$script" ] \
            && [ "$force" -eq 0 ]; then
        echo "  skip $base: already links to $current (use --force)"
        continue
    fi
    ln -sfn "$script" "$target"
    ln -sfn ../libexec/physdemo-launch "$prefix/bin/$base"
    echo "  $base -> $script"
    # Keep one line per command in the suite's list.
    grep -v "^$base " "$prefix/tools.list" > "$prefix/tools.list.tmp" \
        || true
    echo "$base  ($tool_name)  $script" >> "$prefix/tools.list.tmp"
    sort "$prefix/tools.list.tmp" > "$prefix/tools.list"
    rm -f "$prefix/tools.list.tmp"
    linked=$((linked + 1))
done

echo "$linked command(s) linked from $tool_name into $prefix/bin"
