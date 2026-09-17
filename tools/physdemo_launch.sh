#!/usr/bin/env bash

# physdemo-launch -- start one of the suite's commands in a loader
#   environment that lets it open a window.
#
# Every command in the suite's bin/ is a symbolic link to this script.
#   Run as bin/<name>, it starts links/<name>, which is a symbolic link
#   to the tool's real entry point. (The tool is still run through a
#   link, so its name in usage messages is <name>, and it must still
#   find its library from its RESOLVED path.)
#
# Why a launcher and not a plain link. On Linux, VTK does not link the
#   OpenGL library; it opens libGL by name when a window is created, so
#   LD_LIBRARY_PATH decides which copy it gets. A conda environment's
#   lib/ directory on that path supplies conda's libGL and libGLX in
#   place of the system's. Conda's libGLX lacks the fallback to the
#   system's driver that Linux distributions patch in, so with an X
#   server that does not announce its OpenGL vendor (a forwarded one:
#   `ssh -X`, a batch system's X11 option) it finds no driver at all.
#   VTK then reports "Could not find a decent config" and the tool dies
#   with a segmentation fault. A local X server does announce its
#   vendor, so the same shell works on a remote desktop, which makes
#   the failure look random.
#
# What it does. For the launched command ONLY, it sets aside each
#   LD_LIBRARY_PATH directory that both (a) holds libGL.so.1 or
#   libGLX.so.0 and (b) is a conda environment's lib/ (its parent holds
#   conda-meta/). The calling shell is never changed, because that
#   LD_LIBRARY_PATH may be deliberate there (compiled codes that need
#   the environment's libraries). Doing this at launch rather than at
#   activation means the order in which a user activated things does
#   not matter. A directory holding a site's own OpenGL build (a Mesa
#   module on a cluster) fails test (b) and is left alone.
#
# Controls:
#   PHYSDEMO_KEEP_LOADER_PATH=1   change nothing
#   PHYSDEMO_QUIET=1              do not print the one-line notice
# The directories set aside are exported to the command as
#   PHYSDEMO_SET_ASIDE, so that physdemo-check can report them.

# Find the bin/<name> this was run as. Follow links by hand until the
#   next one points at this launcher; `readlink -f` is not portable.
invoked="$0"
while [ -L "$invoked" ]; do
    link_target="$(readlink "$invoked")"
    [ "$(basename "$link_target")" = "physdemo-launch" ] && break
    case "$link_target" in
        /*) invoked="$link_target" ;;
        *)  invoked="$(dirname "$invoked")/$link_target" ;;
    esac
done
command_name="$(basename "$invoked")"
suite_root="$(cd "$(dirname "$invoked")/.." && pwd)"

if [ "$command_name" = "physdemo-launch" ]; then
    echo "physdemo-launch: not run directly; it is what each command" \
         "in the suite's bin/ links to. See its header comment." >&2
    exit 2
fi
entry_point="$suite_root/links/$command_name"
if [ ! -e "$entry_point" ]; then
    echo "physdemo: $command_name is not installed in $suite_root" \
         "(install_tool.sh adds it)" >&2
    exit 127
fi

if [ "$(uname -s)" = "Linux" ] && [ -n "${LD_LIBRARY_PATH:-}" ] \
        && [ -z "${PHYSDEMO_KEEP_LOADER_PATH:-}" ]; then
    kept=""
    set_aside=""
    IFS=':' read -r -a loader_directories <<< "$LD_LIBRARY_PATH"
    for directory in "${loader_directories[@]}"; do
        [ -n "$directory" ] || continue
        if { [ -e "$directory/libGL.so.1" ] \
                || [ -e "$directory/libGLX.so.0" ]; } \
                && [ -d "$directory/../conda-meta" ]; then
            set_aside="${set_aside:+$set_aside:}$directory"
        else
            kept="${kept:+$kept:}$directory"
        fi
    done
    # Rebuild the path only if something was set aside, so that an
    #   unaffected LD_LIBRARY_PATH reaches the command byte for byte.
    if [ -n "$set_aside" ]; then
        if [ -n "$kept" ]; then
            LD_LIBRARY_PATH="$kept"; export LD_LIBRARY_PATH
        else
            unset LD_LIBRARY_PATH
        fi
        PHYSDEMO_SET_ASIDE="$set_aside"; export PHYSDEMO_SET_ASIDE
        if [ -z "${PHYSDEMO_QUIET:-}" ]; then
            echo "physdemo: LD_LIBRARY_PATH without $set_aside for" \
                 "this command (why: physdemo-check)" >&2
        fi
    fi
fi

exec "$entry_point" "$@"
