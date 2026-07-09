<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# qgis-dev-env

A reproducible, shareable, fully **isolated** developer environment overlay
for hacking on [QGIS](https://github.com/qgis/QGIS) core with **NixOS + Nix
flakes + Neovim**. Fast incremental builds (ccache + mold + Ninja), a
`<leader>p` project menu for every routine task, full LSP coverage
(C++20/Qt6, Python/PyQGIS, CMake, Nix, Bash), git-worktree workflows, and a
QA/diagnostics harness (sanitizers, valgrind, heaptrack, perf) — all without
a single file ever becoming visible to upstream QGIS git.

The complete requirements live in [SPECIFICATION.md](SPECIFICATION.md).

## Quickstart

```bash
# 1. upstream QGIS
git clone git@github.com:qgis/QGIS.git ~/dev/cpp/QGIS
cd ~/dev/cpp/QGIS

# 2. this sidecar, EMBEDDED in the checkout (a plain nested clone — not a
#    submodule; bootstrap hides it from upstream git via .git/info/exclude)
git clone git@github.com:timlinux/qgis-dev-env.git qgis-dev-env

# 3. overlay the checkout (idempotent; never touches tracked files)
./qgis-dev-env/bootstrap.sh .

# 4. enter — direnv builds the entire toolchain, pinned by flake.lock
direnv allow

# 5. the one unavoidable cold build (ccache remembers everything after)
qgis-dev build && qgis-dev run
```

Then open Neovim in the checkout and press `<leader>p` — every task
(configure, build, test, run, docs, pre-commit, worktrees, profilers…) is on
the menu with which-key labels. The same tasks exist as `qgis-dev <task>` in
any terminal and as `nix run .#<task>`.

## Everyday commands

| Task | Neovim | Terminal |
|---|---|---|
| Incremental build (all cores) | `<leader>pb` | `qgis-dev build` |
| Build one target | `<leader>pB` | `qgis-dev build qgis_core` |
| Run built QGIS (throwaway profile) | `<leader>pr` | `qgis-dev run` |
| Tests / test for this file | `<leader>pt` / `<leader>pT` | `qgis-dev test` |
| QGIS pre-commit checks → quickfix | `<leader>pp` | `qgis-dev precommit` |
| Toggle a CMake flag | `<leader>pk` | `qgis-dev configure -DWITH_3D=OFF` |
| Switch build profile (debug/minimal/release/asan-ubsan) | `<leader>px` | `qgis-dev profile minimal` |
| New bootstrapped worktree | `<leader>pwn` | `qgis-dev worktree add my-feature` |
| Sanitizer run / valgrind / heaptrack / perf | `<leader>pa…` | `qgis-dev qa asan` |
| Build-time trends (logged every build) | `<leader>pG` | `qgis-dev stats` |
| CPU performance mode during builds | `<leader>pe` | `qgis-dev perf build-toggle` |
| Health + isolation check | `<leader>pv` | `qgis-dev doctor` |

Build times are logged to
`~/.local/state/qgis-dev-env/build-log.tsv` (timestamp, branch, profile,
targets, duration, ccache hit rate) — `qgis-dev stats --graph` renders an
SVG trend with gnuplot.

## Isolation guarantee

Upstream QGIS does not accept AI contributions, and this tooling must never
leak there. Three layers enforce that (SRS group I):

1. Overlay files reach the checkout only as **relative symlinks registered
   in `.git/info/exclude`** — local-only, never committed, shared by all
   worktrees. The embedded `qgis-dev-env/` clone itself is excluded the same
   way (it is a plain nested repo, deliberately *not* a submodule, so no
   gitlink can ever be committed upstream by accident).
2. A **pre-push guard** blocks any commit touching overlay paths (including
   `qgis-dev-env/` itself), even after `git add -f`.
3. `qgis-dev doctor` verifies isolation across every worktree.

⚠️ One habit to keep: `git clean -fdx` (capital X/x variants) in the QGIS
checkout deletes *ignored* files — which now includes this embed and your
`build/`. Plain `git clean -fd` is safe.

`bootstrap.sh --remove <checkout>` restores a byte-pristine checkout (your
`PROMPT.log` and state are preserved under `~/.local/state/qgis-dev-env/`).

## Notes

- **perf profiling** needs `boot.kernel.sysctl."kernel.perf_event_paranoid" = 1;`
  (or lower) in your NixOS configuration.
- **Existing pre-push hook?** bootstrap won't overwrite it — chain the guard
  by calling `overlay/hooks/pre-push` from yours.
- **Hacking on this repo:** `nix develop .#tooling` gives shellcheck, bats,
  gitleaks, reuse, statix and nixfmt; run `pre-commit install` here too.
- Licence: MIT for this tooling. It orchestrates local builds of GPL-2.0+
  QGIS but links nothing, so no copyleft obligation attaches to the tooling
  itself.

---

*Made with 💗 by [Kartoza](https://kartoza.com) | [Donate!](https://github.com/sponsors/timlinux) | [GitHub](https://github.com/timlinux/qgis-dev-env)*
