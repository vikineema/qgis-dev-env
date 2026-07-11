<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# `qgis-dev` commands

The single task runner shared by the terminal, `nix run .#<task>` and the
Neovim menu. Run from anywhere inside a QGIS checkout or worktree.

## Build

| Command | Does |
|---|---|
| `qgis-dev configure [-DVAR=VAL…]` | CMake-configure `build/` with the active profile; extra `-D` flags persist in the cache |
| `qgis-dev build [-jN] [target…]` | Ninja build — all cores by default; timed, ccache-namespaced, appended to the build log |
| `qgis-dev clean` | `ninja clean` |
| `qgis-dev relink` | Clear linked outputs + reconfigure, **keeping all compiled objects** — the safe way to force a full relink after a linker/toolchain change (never `rm -rf build/output` by hand: configure-time files live there) |
| `qgis-dev targets` | List Ninja targets (feeds the editor picker) |
| `qgis-dev flags` | List `WITH_*` / `ENABLE_*` / `BUILD_*` cache flags |
| `qgis-dev profile [name\|list]` | Show / switch build profile (reconfigures) |

## Run & test

| Command | Does |
|---|---|
| `qgis-dev run [args…]` | Launch the built QGIS with an isolated throwaway profile; self-heals the build-tree marker and Python staging, launches bare (no `QGIS_PREFIX_PATH`) |
| `qgis-dev designer [file]` | Open Qt Designer, non-blocking. Given a source file, resolves and opens its associated `.ui` (via the `ui_<name>.h` include, checking the paired header); given a `.ui`, opens it; otherwise launches Designer empty |
| `qgis-dev test [ctest args…]` | `ctest --output-on-failure` (offscreen platform) |
| `qgis-dev test-file <path>` | Run the test matching a source file's name |

## Docs & standards

| Command | Does |
|---|---|
| `qgis-dev docs` / `docs-serve` | Build / serve the QGIS API (Doxygen) docs |
| `qgis-dev precommit [--branch]` | Upstream pre-commit hooks over changed files / branch diff |
| `qgis-dev tidy <file>` | clang-tidy one file against `build/compile_commands.json` |
| `qgis-dev tags` | Regenerate supplementary ctags (SIP, CMake, shell) |

## Worktrees

| Command | Does |
|---|---|
| `qgis-dev worktree add <branch> [base]` | Create sibling worktree **and** bootstrap it |
| `qgis-dev worktree list` / `status` | List / dashboard (branch, dirty, ahead, build size) |
| `qgis-dev worktree remove <path> [--force]` | Guarded removal (refuses dirty/unpushed without `--force`) |
| `qgis-dev worktree prune` | Drop stale worktree records |

## QA & diagnostics

| Command | Does |
|---|---|
| `qgis-dev qa asan [target]` | Switch to `asan-ubsan` profile, rebuild, run, report |
| `qgis-dev qa memcheck [exe]` | Valgrind with Qt6/glib/Python suppressions → `file:line` findings |
| `qgis-dev qa heaptrack [exe]` | Heap profile, opens `heaptrack_gui` |
| `qgis-dev qa perf [exe]` | CPU profile (dwarf call graphs), opens hotspot |
| `qgis-dev qa callgrind [exe]` | Callgrind, opens kcachegrind |
| `qgis-dev qa cppcheck [path]` | Static analysis (defaults to `src/core`) |
| `qgis-dev qa gammaray` | Attach GammaRay to the running QGIS |
| `qgis-dev qa list` | List archived reports (`.dev-env/diagnostics/`) |

## Performance & health

| Command | Does |
|---|---|
| `qgis-dev stats [N\|--graph]` | Build-time history — table, sparkline, SVG graph |
| `qgis-dev report [--pdf\|--svg\|--png] [--open]` | Branded multi-panel build-performance infographic (see [Build profiles & flags](profiles.md#analysing-your-build-history)) |
| `qgis-dev perf on\|off\|build-toggle\|status` | CPU performance power-profile control |
| `qgis-dev ccache-stats` / `ccache-zero` | Cache statistics / reset counters |
| `qgis-dev doctor` | Toolchain + isolation health across all worktrees |
