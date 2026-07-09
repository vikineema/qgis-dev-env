<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# 4 · Your first compile

!!! info "Build strategy: the working tree, not the nix store"
    Development builds are ordinary CMake/Ninja builds in
    `<checkout>/build/`, and you run QGIS straight from
    `build/output/bin/`. Nix provisions the *toolchain* only — QGIS is
    never compiled into the nix store during development, because a store
    build would forfeit the incrementality this whole environment exists
    to deliver.

## The one slow build

```bash
qgis-dev build
```

That's the whole command. It configures CMake on first run (Ninja
generator, ccache launchers, mold linker, split dwarf, compile database
for clangd — all from the `debug` profile), then builds **on all cores**.

This first build is the only expensive one you will ever pay on this
machine: every object file lands in a 50 GB ccache shared across all your
checkouts, worktrees and branches.

While you wait, two optional quality-of-life switches:

```bash
qgis-dev perf build-toggle   # switch CPU to `performance` power profile
                             # during builds, restored automatically after
qgis-dev stats               # build-time history: table + trend sparkline
```

Every build is logged (duration, ccache hit rate, branch, profile, jobs)
to `~/.local/state/qgis-dev-env/build-log.tsv`, so you can graph your
build performance over time — `qgis-dev stats --graph` renders an SVG.

## Run it

```bash
qgis-dev run
```

Launches your freshly built QGIS with an **isolated throwaway profile**
(under `.dev-env/profiles/`), so a debug build can never corrupt your real
QGIS user profile.

## The everyday loop from here on

```bash
# touch one file in src/core, then:
qgis-dev build        # seconds to ~2 minutes, not hours
qgis-dev run          # click around
qgis-dev test -R name # run the relevant tests
```

Need it faster still? `qgis-dev profile minimal` turns off 3D, WebEngine,
PDAL, tests and Python bindings for core-C++ iteration. See
[Build profiles & flags](../reference/profiles.md).

!!! info "All cores, or fewer"
    Ninja saturates every core by default. On a machine you're also using
    for meetings, `qgis-dev build -j8` keeps it responsive.

Continue to [5 · Editing with Neovim](05-neovim.md).
