<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# FAQ

## Why Neovim and not Qt Creator / VS Code / CLion?

Nothing stops you using any of them — the environment is **editor-neutral
underneath**. The devshell exports `build/compile_commands.json`, so any
clangd-based IDE (Qt Creator, VS Code + clangd, CLion) gets full C++
intelligence by opening the checkout; `pyrightconfig.json` does the same
for Python. Qt Creator in particular imports the CMake project directly and
is an excellent choice for GUI-heavy work and the visual designer.

What Neovim gets you *here specifically* is the packaged, reproducible
experience: [nix-vim](https://github.com/timlinux/nix-vim) is a flake input
pinned in `flake.lock`, so every colleague has the **same** editor to the
byte, and the `<leader>p` menu drives the same `qgis-dev` tasks the
terminal and CI use — no per-machine IDE setup, no config drift, nothing to
install. Qt Creator's project files, by contrast, are per-user state we'd
have to keep out of the pristine checkout, and its version isn't pinned by
our flake.

So: **Neovim is the supported, zero-setup default; Qt Creator is a
first-class option you can point at the same build tree.** If you want it,
open `CMakeLists.txt` in Qt Creator from inside the devshell (so it finds
the pinned toolchain) and set the build directory to `build/`. Just don't
let it write project files into tracked upstream paths — `qgis-dev doctor`
will warn you if anything lands where git can see it.

## Why embed the sidecar in the checkout instead of keeping it separate?

An external location works (bootstrap uses absolute symlinks then), but the
embed keeps the whole project under one folder and, crucially, lets tooling
that can only see the current directory tree — sandboxes, some editors —
reach it. Because it's a plain nested clone hidden by `.git/info/exclude`,
it costs nothing in isolation. See
[Bootstrap & isolation](../internals/bootstrap-isolation.md).

## Why not just use upstream QGIS's own flake / devShell?

We do — as an *input*. We compose our devshell on top of upstream's
**packages** so we inherit their full dependency set without maintaining a
copy, while owning the activation experience (our banner instead of their
`dev-help`). Editing their `flake.nix` to add our tooling would modify a
tracked upstream file — exactly what the isolation rules forbid. See
[The flake](../internals/the-flake.md).

## Why does the first `direnv allow` download ~240 MiB of "QGIS"?

Nix must fetch the pinned QGIS *source snapshot* to evaluate the devshell
(it reads upstream's `nix/` files). It is copied, not compiled — your build
still happens in `build/`. It's a one-time cost per lockfile pin, cached in
the nix store and shared across worktrees. See
[Troubleshooting](../reference/troubleshooting.md).

## Why is my first build so slow, and later ones fast?

The first build compiles ~6,000 units cold (hours). Every object lands in a
50 GB shared ccache, so subsequent builds — even after switching branches
or worktrees — mostly hit the cache and finish in seconds to minutes.
`qgis-dev report` shows the difference as a log-scaled trend.

## Does editing QGIS GUI recompile QGIS core too?

No. Ninja's dependency graph rebuilds only what actually changed and what
links against it. Editing a `.cpp` in `qgis_gui` recompiles one object and
relinks gui + the app; `qgis_core` is untouched. Editing a widely-included
*core header* is the expensive case (many translation units include it) —
inherent to C++, not a tooling limitation. See
[Build, run & profiles](../internals/build-run.md).

## Where does the clangd index live, and is it reused?

In `<checkout>/.cache/clangd/index/`, one shard per file, and **yes — it
persists and is reused across every session**. The first `nvim` in a fresh
checkout spends tens of minutes background-indexing QGIS (you can work
meanwhile; the open file is intelligent almost immediately), and every
session after that starts fully indexed. Bootstrap excludes `.cache/` from
git so it never dirties `git status`. Each worktree indexes once on its own
(the index is project-relative). See
[Editing with Neovim](../getting-started/05-neovim.md).

## What will keep me waiting, and how often?

| One-time cost | When | Roughly |
|---|---|---|
| Toolchain download (`direnv allow`) | first activation per machine/pin | minutes |
| Cold QGIS build | first `qgis-dev build` | hours (then ccache-warm) |
| clangd background index | first `nvim` per checkout/worktree | tens of minutes, non-blocking |

Everything after those is seconds-to-minutes. The [Under the
Hood](../internals/index.md) section explains why each is one-time.

## Can I run several feature branches at once?

Yes — `qgis-dev worktree add <branch>` creates a sibling worktree, already
bootstrapped, sharing the ccache so it builds warm. See
[Worktrees](../reference/worktrees.md).

## Is any of this OK to submit to upstream QGIS?

The **tooling** must never reach upstream — three isolation layers enforce
that. Your **code contributions** are welcome upstream provided they are
your own human-authored work: QGIS does not accept AI-generated
contributions. Read the [AI policy](ai-policy.md) before your first patch.

## Will this work on macOS / non-NixOS Linux?

It targets NixOS. It may work on any Linux with the Nix package manager and
`direnv`; macOS is untested (the flake declares the Linux systems). The
build-tree strategy and `qgis-dev` are platform-neutral, but some QA tools
(perf, GammaRay) are Linux-only.

## How do I remove it all cleanly?

`./qgis-dev-env/bootstrap.sh --remove .` unlinks the overlay, strips the
exclude block, and restores a byte-pristine checkout (your `PROMPT.log` and
state are preserved under `$XDG_STATE_HOME`). Then delete the
`qgis-dev-env/` folder if you want it gone entirely.

## Something's wrong — where do I start?

`qgis-dev doctor` (or `<leader>pv`) checks the toolchain, the symlinks and
exclude block, the guards, the compile database and Python staging, and
isolation across every worktree. Most answers are in
[Troubleshooting](../reference/troubleshooting.md).
