<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# 5 · Editing with Neovim

## nix-vim: the standard editor

The devshell ships [timlinux/nix-vim](https://github.com/timlinux/nix-vim)
as a **flake input and standard dev package** — a fully configured Neovim
(plugins, which-key, treesitter, sensible defaults) pinned by this repo's
`flake.lock`. Inside the devshell, it *is* `nvim`:

```bash
cd ~/dev/cpp/QGIS
nvim src/core/qgsvectorlayer.cpp
```

No plugin manager to run, nothing to install: the same editor, byte for
byte, on every colleague's machine. (Your own system Neovim still works —
the project config degrades gracefully to any Neovim ≥ 0.10 — but nix-vim
is the supported, documented experience.)

## The `<leader>p` project menu

Everything routine hangs off `<leader>p`, with which-key labels so the
menu is discoverable — press `<leader>p` and read:

| Keys | Action |
|------|--------|
| `<leader>pb` / `pB` | Build all / pick a Ninja target |
| `<leader>pc` / `pk` / `px` | Configure · toggle CMake flags · switch build profile |
| `<leader>pr` | Run QGIS (throwaway profile) |
| `<leader>pt` / `pT` | ctest all / test for the current file |
| `<leader>pp` / `pP` | Pre-commit on changed files / on the branch diff |
| `<leader>pd` / `pD` | Build / serve the QGIS API docs |
| `<leader>pw…` | Worktrees: new, switch, dashboard, remove, prune |
| `<leader>pa…` | Analyse: sanitizers, valgrind, heaptrack, perf, GammaRay, cppcheck |
| `<leader>ps` / `pG` / `pe` | ccache stats · build-time trends · perf-mode toggle |
| `<leader>pv` / `pq` | Doctor · last task output |

Every task runs **asynchronously** — the editor never blocks during a
build — and failures land in the **quickfix list** at the exact
`file:line` (`]q` / `[q` to walk them). The full contract is in the
[keymap reference](../reference/keymap.md).

## Language intelligence

| Language | Server | Notes |
|---|---|---|
| C++20 / Qt6 | clangd | Driven by `build/compile_commands.json`; go-to-definition works into Qt headers; generated code is parsed but never nags |
| Python / PyQGIS | basedpyright + ruff | `from qgis.core import …` resolves against your built tree |
| CMake | neocmakelsp | Completion and hover across QGIS's ~400 cmake files |
| Doxygen | treesitter | `\brief`, `\param`, `\since` fully highlighted in C++ comments |
| Nix / Bash / Lua / YAML | nixd · bashls · luals · yamlls | For the sidecar and scripts |

A supplementary ctags file covers what LSPs don't index — SIP bindings,
CMake variables, shell — regenerate with `<leader>pg`.

Continue to [6 · Pre-commit & standards](06-precommit.md).
