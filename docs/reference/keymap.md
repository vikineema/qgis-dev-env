<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# Neovim keymap

The complete `<leader>p` contract. Every binding carries a which-key
label, runs asynchronously, and reports failures to the quickfix list.

## Project root

| Keys | Label | Action |
|------|-------|--------|
| `<leader>pc` | Configure (cmake) | configure `build/` with the active profile |
| `<leader>pk` | CMake flags… | toggle/edit `WITH_*` cache flags, reconfigure |
| `<leader>px` | Build profile… | pick debug / minimal / release / asan-ubsan |
| `<leader>pb` | Build (all) | `ninja` → quickfix on failure |
| `<leader>pB` | Build target… | pick from `ninja -t targets` |
| `<leader>pC` | Clean | `ninja clean` (confirm prompt) |
| `<leader>pr` | Run QGIS | launch built binary, throwaway profile |
| `<leader>pt` | Test (ctest) | full test run → quickfix |
| `<leader>pT` | Test this file | ctest matching current buffer |
| `<leader>pd` | Docs (apidoc) | Doxygen build → warnings in quickfix |
| `<leader>pD` | Docs serve | serve built API docs |
| `<leader>pp` | Pre-commit (changed) | hooks on changed files → quickfix |
| `<leader>pP` | Pre-commit (branch) | hooks on diff vs `origin/master` |
| `<leader>pf` | Format buffer | LSP formatting (clang-format / ruff) |
| `<leader>pl` | Lint file | clang-tidy on current file → quickfix |
| `<leader>pg` | Refresh tags | regenerate ctags supplement |
| `<leader>ps` | ccache stats | statistics window |
| `<leader>pS` | ccache zero | reset counters |
| `<leader>pe` | Perf boost toggle | performance power profile during builds |
| `<leader>pG` | Build-time trends | logged history: table + sparkline |
| `<leader>pR` | Build report | branded PDF infographic, opens in your viewer |
| `<leader>pv` | Doctor | health + isolation report (all worktrees) |
| `<leader>pq` | Last task output | reopen the last task's output buffer |

## Worktrees — `<leader>pw`

| Keys | Label | Action |
|------|-------|--------|
| `<leader>pwn` | New worktree… | branch + base → `git worktree add` + auto-bootstrap |
| `<leader>pwl` | List / switch… | picker; `:tcd` there — tasks and LSP follow |
| `<leader>pws` | Dashboard | branch, dirty, ahead, build size per worktree |
| `<leader>pwD` | Remove… | guarded removal (dirty/unpushed refused) |
| `<leader>pwp` | Prune stale | drop stale worktree records |

## Analyse — `<leader>pa`

| Keys | Label | Action |
|------|-------|--------|
| `<leader>pas` | Sanitizer run | asan-ubsan profile: rebuild, run, report → quickfix |
| `<leader>pam` | Valgrind memcheck | suppressions applied → findings at `file:line` |
| `<leader>pah` | Heap profile | heaptrack → GUI on exit |
| `<leader>pac` | CPU profile | perf record → hotspot on exit |
| `<leader>pag` | GammaRay | attach to running QGIS |
| `<leader>paa` | Cppcheck | static analysis of current file → quickfix |
| `<leader>pal` | Past reports | browse `.dev-env/diagnostics/` |

!!! note "Quickfix rhythm"
    `]q` next finding · `[q` previous · `:copen` reopen the list ·
    `<leader>pq` full raw output of the last task.
