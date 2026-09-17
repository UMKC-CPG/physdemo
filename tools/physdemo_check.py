#!/usr/bin/env python3

"""physdemo-check -- is this environment able to run the tools?

Two questions, asked separately because they have different answers on
different machines:

  physdemo-check              Packages present at the pinned versions?
                              Can VTK draw OFFSCREEN (tests, batch jobs,
                              screenshots)? Needs no display.

  physdemo-check --onscreen   Can VTK open a WINDOW here, and how fast
                              does it draw? Needs a display: a desktop,
                              `ssh -X`, a scheduler's X11 forwarding, a
                              remote-desktop session.

Every render is verified by reading the framebuffer back. A VTK window
with no valid OpenGL context accepts Render() calls and returns at
once, reporting a gratifying and entirely fictitious frame rate while
drawing nothing; a result is believed only if the pixels are there.

The report names the OpenGL renderer in use. "llvmpipe" means software
rendering on the CPU, which is adequate for these tools; a GPU name
means hardware rendering.

On Linux with no usable X display, VTK's default window class cannot
open. Setting VTK_DEFAULT_OPENGL_WINDOW=vtkEGLRenderWindow before VTK
is imported gives an offscreen context where EGL is available. This
script does that for the offscreen test on Linux only; macOS and
Windows need nothing. The tools apply the same rule themselves.
"""

import argparse
import importlib
import os
import platform
import sys
import time
from pathlib import Path

DIRECT_PACKAGES = ['numpy', 'scipy', 'matplotlib', 'vedo', 'vtk', 'h5py',
                   'pint', 'tomli_w', 'pytest']


def pinned_versions():
    """The pins from requirements.txt beside this script's repository,
    as {lowercase name: version}; empty if the file is not found (an
    installed copy of this script may be far from its repository)."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        candidate = parent / 'requirements.txt'
        if candidate.is_file():
            pins = {}
            for line in candidate.read_text().splitlines():
                line = line.split('#')[0].split(';')[0].strip()
                if '==' in line:
                    name, version = line.split('==')
                    pins[name.strip().lower().replace('-', '_')] = \
                        version.strip()
            return pins
    return {}


def report_environment():
    """Print the interpreter, the platform, the display variables, and
    each direct package's version against its pin. Returns True if
    every direct package imports."""
    print(f'python     {sys.version.split()[0]}  ({sys.executable})')
    print(f'platform   {platform.system()} {platform.machine()}')
    for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'VIRTUAL_ENV',
                 'PHYSDEMO_HOME', 'VTK_DEFAULT_OPENGL_WINDOW'):
        print(f'{name:<26} {os.environ.get(name, "(unset)")}')
    pins = pinned_versions()
    all_present = True
    print('packages:')
    for name in DIRECT_PACKAGES:
        try:
            module = importlib.import_module(name)
        except Exception as problem:             # noqa: BLE001
            print(f'  {name:<12} MISSING ({problem})')
            all_present = False
            continue
        version = getattr(module, '__version__', None)
        if version is None and name == 'vtk':
            version = module.vtkVersion.GetVTKVersion()
        pin = pins.get(name)
        note = '' if pin in (None, version) else f'  (pinned {pin})'
        print(f'  {name:<12} {version}{note}')
    return all_present


def draw_frames(offscreen, seconds, size):
    """Open a window (or an offscreen buffer), spin a small scene for
    `seconds`, and return (frames_per_second, pixels_verified,
    renderer_description)."""
    import numpy as np
    import vedo

    plotter = vedo.Plotter(offscreen=offscreen, size=size, axes=0,
                           title='physdemo-check')
    sphere = vedo.Sphere(r=1.0, res=48).c('tomato')
    points = vedo.Points(np.random.default_rng(0).normal(size=(2000, 3)),
                         r=4).c('steelblue')
    line = vedo.Line(np.cumsum(np.random.default_rng(1).normal(
        size=(500, 3)), axis=0) * 0.05).c('black')
    plotter.add(sphere, points, line)
    plotter.show(interactive=False)
    first = plotter.screenshot(asarray=True)

    frames = 0
    start = time.time()
    while time.time() - start < seconds:
        plotter.camera.Azimuth(3.0)
        plotter.render()
        frames += 1
    elapsed = time.time() - start
    last = plotter.screenshot(asarray=True)

    description = 'unknown'
    try:
        capabilities = plotter.window.ReportCapabilities()
        for line_text in capabilities.splitlines():
            if 'renderer string' in line_text.lower():
                description = line_text.split(':', 1)[1].strip()
    except Exception:                            # noqa: BLE001
        pass
    plotter.close()
    verified = bool(first.min() != first.max()
                    and not np.array_equal(first, last))
    return frames / max(elapsed, 1e-9), verified, description


def main(command_line_args=None):
    parser = argparse.ArgumentParser(
        prog='physdemo-check', description=__doc__.split('\n\n')[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split('\n\n', 1)[1])
    parser.add_argument('--onscreen', action='store_true',
                        help='open a real window instead of drawing '
                             'offscreen')
    parser.add_argument('--seconds', type=float, default=4.0,
                        help='how long to draw (default 4)')
    parser.add_argument('--size', type=int, nargs=2, default=[960, 720],
                        metavar=('W', 'H'), help='window size')
    args = parser.parse_args(command_line_args)

    # The window class must be chosen BEFORE vtk is imported.
    if (not args.onscreen and sys.platform.startswith('linux')
            and 'VTK_DEFAULT_OPENGL_WINDOW' not in os.environ):
        os.environ['VTK_DEFAULT_OPENGL_WINDOW'] = 'vtkEGLRenderWindow'

    packages_ok = report_environment()
    if not packages_ok:
        print('\nRESULT: FAIL -- packages are missing; see install.sh')
        return 1

    mode = 'on screen' if args.onscreen else 'offscreen'
    print(f'\nrendering {mode} for {args.seconds:g} s at '
          f'{args.size[0]}x{args.size[1]} ...')
    try:
        rate, verified, description = draw_frames(
            offscreen=not args.onscreen, seconds=args.seconds,
            size=tuple(args.size))
    except Exception as problem:                 # noqa: BLE001
        print(f'RESULT: FAIL -- could not render {mode}: {problem}')
        return 1
    print(f'OpenGL renderer   {description}')
    print(f'frame rate        {rate:.1f} frames per second')
    print(f'pixels verified   {verified}')
    if not verified:
        print(f'\nRESULT: FAIL -- the {mode} framebuffer was empty or '
              f'did not change: no working OpenGL context')
        return 1
    print(f'\nRESULT: PASS ({mode})')
    if not args.onscreen:
        print('To test a real window on this machine: '
              'physdemo-check --onscreen')
    return 0


if __name__ == '__main__':
    sys.exit(main())
