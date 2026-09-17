# physdemo

A small suite of **interactive physics demonstration tools** for
teaching, and the one environment they share. Each tool is its own
repository; this one defines what they have in common — the Python
packages, how a tool's commands get on the `PATH`, and the one command
that turns the suite on — so that a student types

```bash
sdemo                          # turn the suite on
scsim runs/rutherford.toml     # run a tool by name, from anywhere
```

and never an absolute path.

## The tools

| Command | Tool | Subject |
| --- | --- | --- |
| `rbsim`, `rbbatch` | `rigid_body` | Rigid-body rotation, Poinsot |
| `scsim`, `scbatch` | `scattering` | Classical scattering, inversion |

Planned: Euler angles; pseudo-forces in a rotating frame. The suite is
not limited to mechanics — solid state, E&M, quantum, and thermal
demonstrations belong here too, as long as they rest on the same
packages.

## Design

Three thin layers, none of them specific to any one computer:

1. **One Python environment** holding the third-party packages every
   tool needs (`requirements.txt`: NumPy, SciPy, vedo/VTK, h5py, pint,
   matplotlib, pytest). No tool is installed *into* it; each tool's
   entry-point script finds its own library beside itself.
2. **One `bin/` of symbolic links** to each tool's entry points, named
   without the `.py`. The entry points stay what they are — executable
   Python scripts beginning `#!/usr/bin/env python3` — so they can be
   read, edited, and tested as ordinary files.
3. **One `activate.sh`** that puts the environment's `bin/` and the
   suite's `bin/` on the `PATH`. Plain bash or zsh; Linux or macOS.

An Lmod modulefile that does the same thing is available for clusters
(`extras/lmod/`), and notes for particular sites live under `site/`.
Nothing in the suite depends on either.

**Why not `pip install` each tool with console entry points?** It is
the conventional answer and would work. It was not chosen because it
replaces readable scripts with generated launchers, requires packaging
metadata every tool would have to maintain, and — for an instructor —
puts a home-directory working copy inside an environment students
share. Links get the same convenience with none of that.

## Installing

Requires bash, Python 3.10 or later, and pip.

```bash
git clone <this repository> physdemo-src && cd physdemo-src

# Build a suite with its own venv under ~/physdemo:
./install.sh --prefix ~/physdemo

# Add tools (clone each one wherever you like first):
./install_tool.sh --prefix ~/physdemo /path/to/rigid_body
./install_tool.sh --prefix ~/physdemo /path/to/scattering

# Turn it on; make it one word:
source ~/physdemo/activate.sh
echo "alias sdemo='source ~/physdemo/activate.sh'" >> ~/.bashrc
```

`./install.sh --help` and `./install_tool.sh --help` list every option.
Two are worth knowing:

- **`--venv DIR`** adopts an environment that already exists — a venv or
  a conda environment prefix — instead of creating one. With
  `--no-packages` nothing is installed into it.
- **Several prefixes can share one environment.** A *release* suite
  whose links point at tagged checkouts (for students) and a *dev* suite
  whose links point at working copies (for the instructor) are two
  `install.sh` runs with different `--prefix` and the same `--venv`.

`physdemo` (the command) lists what an activated suite provides.

## What a tool must do to join

The group's project template produces tools that already satisfy this:

- Entry points in `src/scripts/<name>.py`, **executable**, first line
  `#!/usr/bin/env python3`.
- Each entry point locates its library relative to its own file **with
  symlinks resolved** — `Path(__file__).resolve()` or
  `os.path.realpath(__file__)`, never `os.path.abspath` — because it is
  run through a link.
- Defaults in `src/scripts/<name>rc.py`, looked up in the working
  directory, then `$<TOOL>_RC`, then beside the script, so that no
  environment variable has to be set for a tool to run.
- No dependency outside `requirements.in`. A tool that needs a new
  package proposes it here first, so that every tool keeps working.

## Rendering without a display

The tools draw with VTK. On a Linux machine with no X display (a
cluster node, a test runner) VTK's default window class cannot open;
setting `VTK_DEFAULT_OPENGL_WINDOW=vtkEGLRenderWindow` gives a working
offscreen context where EGL is present. Tools set this themselves
**only on Linux and only when `DISPLAY` is unset**; macOS and Windows
need nothing. Whether a given machine can render on screen — over SSH
with X forwarding, on a login node, on a laptop — is a property of
that machine and is recorded per site under `site/`.

## Updating the pinned packages

See the header of `requirements.in`: install from it into a fresh
environment, run every tool's tests, write `pip freeze` back to
`requirements.txt`, and commit the two together with the reason.

## Layout

```
requirements.in    Direct dependencies, loosely bounded
requirements.txt   The pinned, tested set
install.sh         Build or adopt an environment; write activate.sh
install_tool.sh    Link one tool's entry points into a suite's bin/
extras/lmod/       Optional Lmod modulefile template
site/              Notes for particular computers; never required
```
