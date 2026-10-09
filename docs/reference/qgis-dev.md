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
| `qgis-dev qtcreator [args…]` | Configure `build/` for real, generate a single CMake preset pointing at it, then open Qt Creator on this checkout — non-blocking, isolated settings path (`.dev-env/qtcreator`). No kit wizard, no preset picker: Build/Run work immediately. Editor font is pre-set larger via Qt Creator's own `[FontSettings]` (seeded once — override with `QGIS_DEV_QTCREATOR_FONT_SIZE` before the first launch; later changes via Options → Text Editor → Fonts & Color stick). Code completion/format/lint parity with Neovim is a one-time manual step, not automatic — see the [FAQ](../about/faq.md) |
| `qgis-dev test [ctest args…]` | `ctest --output-on-failure` (offscreen platform) |
| `qgis-dev test-file <path>` | Run the test matching a source file's name |

> **Known hang: `test_core_authmanager` / `testPasswordHelper`.** This test
> calls `QgsAuthManager::passwordHelperSync`, which blocks on a D-Bus Secret
> Service backend (gnome-keyring/kwallet) to store/retrieve the master
> password. The dev shell runs no such daemon, so the call never returns —
> the test sits until Qt's 300s watchdog fires and aborts the binary (seen as
> a `SIGABRT` with a GDB stack dump, ~5 minutes wasted per run). This is
> missing test infrastructure, not a QGIS bug — upstream CI containers start
> a keyring daemon before running ctest. To avoid it locally, either run with
> a real desktop session keyring active, or skip it explicitly:
> `qgis-dev test -E test_core_authmanager`.

## Docs & standards

| Command | Does |
|---|---|
| `qgis-dev docs` / `docs-serve` | Build / serve the QGIS API (Doxygen) docs |
| `qgis-dev precommit [--branch]` | Upstream pre-commit hooks over changed files / branch diff |
| `qgis-dev fmt [--all] <file>` | clang-format at the QGIS pin (v21) — **touched lines only** by default (vs `HEAD`), or the whole file with `--all` |
| `qgis-dev naming <file>` | QGIS identifier-naming check (clang-tidy `readability-identifier-naming`) → `file:line:col` warnings |
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
