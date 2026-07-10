<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# 3 · Bootstrap & trust

## Run bootstrap

From the QGIS checkout root:

```bash
./qgis-dev-env/bootstrap.sh .
```

It is idempotent — run it as often as you like. It performs, and only
performs, these actions (none touch a tracked upstream file):

| Action | Detail |
|---|---|
| Relative symlinks | `.envrc`, `.nvim.lua`, `.exrc`, `.clangd`, `pyrightconfig.json`, `.luarc.json` → into `qgis-dev-env/overlay/` |
| Managed exclude block | Registers every overlay path **and the embed itself** in `.git/info/exclude` |
| Anti-leak guard | Installs a `pre-push` hook that refuses to push commits touching overlay paths — even after `git add -f` |
| Pre-commit hooks | Runs `pre-commit install` for QGIS's own hook suite (deferred to first devshell entry if `pre-commit` isn't on your PATH yet) |
| Blame hygiene | Sets `blame.ignoreRevsFile .git-blame-ignore-revs` so editor blame skips upstream's mass-reformat commits |
| Local state | Creates `.dev-env/` (per-worktree state) and `PROMPT.log` |

Verify the promise immediately:

```bash
git status          # → nothing. Pristine.
```

`bootstrap.sh --remove .` undoes everything and preserves your
`PROMPT.log`/state under `~/.local/state/qgis-dev-env/`.

## Enter the devshell

```bash
direnv allow
```

direnv reads the symlinked `.envrc`, which activates the sidecar flake's
devshell. The **first** activation downloads the pinned toolchain — every
compiler, library, LSP server, QA tool and the nix-vim editor — into the
nix store. Subsequent entries are instant. From now on, simply `cd`-ing
into the checkout gives you the complete environment; there is nothing to
configure by hand.

Every activation greets you with the Kartoza banner — live branch, active
build profile, configured state, perf-boost toggle, ccache fill/hit-rate
and your last logged build:

```text
────────────────────────────────────────────────────────────────
  QGIS Dev Env  ·  Made with 💗 by Kartoza
────────────────────────────────────────────────────────────────
  branch     master
  profile    debug   configured yes   boost off
  ccache     12.3/50.0 GB (24.6%)   hits 4521 / 5820 (77.7%)
  last build ok in 94s, 92% ccache (debug, 2026-07-10)
  ...
```

Suppress it with `QGIS_DEV_QUIET=1`; it honours `NO_COLOR`. Whenever the
sidecar itself changes you'll see one quick re-evaluation on entry, and if
`.envrc` content changed direnv asks you to `direnv allow` again — that's
the trust model working, not breakage.

## Trust the editor config

Neovim (rightly) refuses to execute project-local config from strangers.
The first time you open Neovim in the checkout it will show:

```text
exrc: Found untrusted code. To enable it, choose (v)iew then run `:trust`
```

Press ++v++ to **view** `.nvim.lua` (read it — that's the point of the
mechanism), then run:

```vim
:trust
```

This records a hash in Neovim's trust database; you'll only be asked again
if the file changes. If your personal config doesn't load project files at
all, enable the standard mechanism:

```lua
-- in your init.lua
vim.o.exrc = true      -- load trusted .nvim.lua / .exrc from the cwd
```

The `.exrc` shim exists for setups that source `.exrc` but not `.nvim.lua`
— trust it the same way if prompted.

## Health check

```bash
qgis-dev doctor
```

Doctor verifies the toolchain is on PATH, the symlinks and exclude block
are intact, the guards are installed, and — across **every** worktree —
that no overlay file is visible to upstream git.

Continue to [4 · Your first compile](04-first-compile.md).
