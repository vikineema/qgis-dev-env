<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# Build profiles & flags

A profile is a committed set of CMake arguments (`profiles/*.profile`).
Switch with `qgis-dev profile <name>` or `<leader>px`; the active profile
is stored per-worktree in `.dev-env/profile` and reconfigures on switch.

| Profile | Build type | Feature set | Use for |
|---|---|---|---|
| `debug` *(default)* | Debug | Everything on (3D, PDAL, WebEngine, tests) | Everyday development and debugging |
| `minimal` | Debug | 3D/PDAL/WebEngine/tests/**bindings** off | Fastest core-C++ iteration (not PyQGIS work) |
| `release` | RelWithDebInfo | Everything on | Profiling and performance work — Debug timings mislead |
| `asan-ubsan` | Debug + sanitizers | 3D/PDAL/WebEngine off | Memory and UB bug hunts (`qgis-dev qa asan`) |

All profiles share: Ninja, ccache compiler launchers, the (wrapped) mold
linker, `compile_commands.json` export, and (Debug) split dwarf +
gdb-index for fast links and fast debugger startup. Debug-config profiles
also pass `-UGDAL_DEBUG` (see
[Troubleshooting](troubleshooting.md) for why). ccache objects are
**namespaced per profile**, so switching never poisons the cache.

## Tweaking individual flags

Interactive: `<leader>pk` lists the current `WITH_*` / `ENABLE_*` /
`BUILD_*` cache values — booleans toggle in one keypress, strings prompt
for a value, and the tree reconfigures.

Terminal:

```bash
qgis-dev flags                          # see current values
qgis-dev configure -DWITH_3D=OFF        # persist any override
```

Overrides live in `build/CMakeCache.txt` and survive rebuilds; switching
profile resets to that profile's declared set.

## Where the time goes

Every build appends to `~/.local/state/qgis-dev-env/build-log.tsv`:

```text
timestamp  host  worktree  branch  profile  targets  jobs  duration_s
ccache_hit_pct  result  ccache_hits  ccache_misses
```

The hit rate and the raw hit/miss counts are **per build** (counter deltas
around each ninja run), not lifetime averages — so builds of different
sizes compare honestly.

`qgis-dev stats` (or `<leader>pG`) summarises; `qgis-dev stats --graph`
renders `build-times.svg` for the long view. Compare profiles, branches
and machines with real numbers instead of vibes.
