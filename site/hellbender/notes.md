# Hellbender (University of Missouri RSS)

Notes for the CPG group's installation. Nothing here is required by
the suite; see `../../README.md` for the portable instructions.

## Where things are

| What | Path |
| --- | --- |
| Shared group area | `$CPG_SHARE` = `/cluster/VAST/rulisp-lab/cpg` |
| The environment | `$CPG_SHARE/virtual_envs/physdemo` |
| Release suite (students) | `$CPG_SHARE/physdemo` |
| Dev suite (instructor) | `$HOME/physdemo-dev` |
| Modulefiles | `$CPG_SHARE/modulefiles/cpg_physdemo/` |

The environment is built on the group's own `cpg10` conda
environment's Python (3.10), **not** on the system `mamba` module's
Python: a venv records the absolute path of the interpreter that made
it, and an interpreter the group does not control can be moved or
removed by a system update.

## The rule for the release suite

Home directories on this cluster are mode 700, so **nothing a student
runs may be a link into anyone's home**. The release suite is
therefore installed from checkouts that live in the shared area —
this repository and every tool — never from a working copy:

```bash
mkdir -p $CPG_SHARE/physdemo/src && cd $CPG_SHARE/physdemo/src
git clone git@github.com:UMKC-CPG/physdemo.git
git clone git@github.com:UMKC-CPG/rigid_body.git && \
    git -C rigid_body checkout v1.0-classroom
# ... one clone per tool, each at a release tag
```

and `install.sh` / `install_tool.sh` are run from *those* copies.
Updating a tool for students is then `git fetch && git checkout
<tag>` in its checkout; no link changes. The dev suite has no such
constraint and links straight into `~/CPG/cpg-repo/`.

## Installing here

```bash
PY=$CPG_SHARE/mamba/envs/cpg10/bin/python
./install.sh --prefix $CPG_SHARE/physdemo \
             --venv $CPG_SHARE/virtual_envs/physdemo --python $PY \
             --lmod-out $CPG_SHARE/modulefiles/cpg_physdemo/release.lua
./install.sh --prefix $HOME/physdemo-dev \
             --venv $CPG_SHARE/virtual_envs/physdemo --no-packages \
             --lmod-out $CPG_SHARE/modulefiles/cpg_physdemo/dev.lua
```

Then `install_tool.sh` once per tool per suite: tagged checkouts under
`$CPG_SHARE/physdemo/tools/` for the release suite, working copies in
`~/CPG/cpg-repo/` for the dev suite.

## Turning it on

```bash
alias sdemo='source $HOME/physdemo-dev/activate.sh'     # instructor
module load cpg_physdemo/release                        # students
```

`module use $CPG_SHARE/modulefiles` must be in effect for the second.

## Rendering

- **Offscreen** (tests, batch, screenshots): works on login and
  compute nodes with `DISPLAY` unset; the tools select VTK's EGL
  window class themselves. OSMesa is not installed. `xvfb-run` is
  available as a fallback.
- **On screen**: needs an X display. Measured 2026-09-17 with
  `physdemo-check --onscreen` (4 s, 960x720), all three PASS with
  pixels verified:

  | How the display is reached | Renderer | Frame rate |
  | --- | --- | --- |
  | Open OnDemand desktop | llvmpipe (LLVM 17.0.6) | 9.7 fps |
  | `ssh -X` to a login node | llvmpipe (LLVM 17.0.6) | 6.2 fps |
  | `salloc -p interactive --x11` | llvmpipe (LLVM 17.0.6) | 4.4 fps |

  Every path is **software rendering**: no GPU is involved, so the
  frame rate is set by CPU fill rate and, over X forwarding, by
  shipping each uncompressed frame across the network. **Recommend
  the Open OnDemand desktop to students**: it is the fastest, it
  does not depend on the student's own X server or connection, and
  it works from Windows and ChromeOS without extra software. X
  forwarding works and is a fine fallback. A smaller window helps
  in every case, since the cost is per pixel.
- **A stale `DISPLAY`** is common here: a shell inside `tmux` or a
  long-lived session keeps `DISPLAY=localhost:NN.0` after the SSH
  connection that forwarded it has gone. On-screen drawing then hangs
  or fails. The group's `rx` shell function re-derives `DISPLAY` from
  `xauth list`; run it before an on-screen tool in such a shell.
  Offscreen drawing is unaffected (the tools choose EGL by what was
  asked for, not by `DISPLAY`).
- VTK's import takes tens of seconds on the shared filesystem when it
  is busy; this is the filesystem, not the tools.

## Scheduler

Batch tiers (`rbbatch`, `scbatch`) run under Slurm. Submission
templates belong here, not in the tools' repositories.
