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
| `<leader>pr` / `pu` | Run QGIS (throwaway profile) · open this file's `.ui` in Qt Designer |
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

## What happens the first time you open Neovim

The environment front-loads some one-time work so that everything is fast
afterwards. On the **first** `nvim` in a fresh checkout, expect:

| Task | What it's doing | How long | Blocks you? |
|---|---|---|---|
| clangd **background index** | Parsing every TU in `compile_commands.json` to build the cross-reference database | Tens of minutes for QGIS | No — runs in the background |
| lua-language-server | Loading Lua runtime (fenced by `.luarc.json`, see below) | Seconds | No |
| Treesitter | Grammars ship prebuilt with nix-vim | None | No |

While clangd indexes, **completion and diagnostics for the file you have
open work almost immediately** — it indexes the open translation unit
first. What ripens over the next several minutes is *project-wide*
intelligence: go-to-definition into files you haven't opened, and
find-all-references. A progress indicator shows in the statusline/notify
area until it settles.

### Where the index lives, and is it reused?

clangd writes its index to **`<checkout>/.cache/clangd/index/`** — one
shard per file. It is **persistent and reused across sessions**: index once,
and every later `nvim` starts with full project intelligence immediately.
Bootstrap adds `.cache/` to the local git excludes, so it never dirties
`git status`. Two consequences worth knowing:

- Each **worktree** has its own `.cache/` and indexes once on its own —
  clangd's background index is project-relative, not shared. A new worktree
  is fast to *build* (shared ccache) but re-indexes for the editor.
- Deleting `.cache/clangd` (or `git clean -fdx`, which would) forces a full
  re-index next time. Don't, unless the index is corrupt.

!!! note "Why luals used to hang — and doesn't now"
    lua-language-server roots at the checkout and, unfenced, crawls the
    whole 1.5 M-file tree looking for Lua to preload — minutes of hang. The
    overlay's `.luarc.json` caps preload and ignores `build/`, `.git`,
    `src/` and friends, so it starts in seconds.

## Debugging

When you need to step through code rather than read it, the same editor
does that too — see [Debugging with DAP](08-debugging.md): breakpoints,
variable inspection, the call stack, and attach-to-running, all on
`<leader>d`.

Continue to [6 · Pre-commit & standards](06-precommit.md).
