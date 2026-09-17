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
- **On screen**: needs an X display. *To be verified and recorded
  here:* `ssh -X` to a login node; `salloc -p interactive --x11` on an
  interactive node; Open OnDemand desktop. Record which work, the
  frame rate of `dev/spikes/render_budget.py` from the scattering
  tool on each, and any `LIBGL_*` or VirtualGL setting that was
  needed.
- VTK's import takes tens of seconds on the shared filesystem when it
  is busy; this is the filesystem, not the tools.

## Scheduler

Batch tiers (`rbbatch`, `scbatch`) run under Slurm. Submission
templates belong here, not in the tools' repositories.
