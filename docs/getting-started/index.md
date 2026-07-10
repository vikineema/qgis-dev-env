<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# The Developer Journey

Eight steps take you from nothing to an accepted upstream patch. Steps 1–4
happen once per machine; steps 5–8 are your daily loop.

| # | Step | What you end up with |
|---|------|----------------------|
| 1 | [Check out QGIS](01-checkout-qgis.md) | A pristine upstream clone |
| 2 | [Embed qgis-dev-env](02-embed-sidecar.md) | This repo nested inside it, invisible to upstream git |
| 3 | [Bootstrap & trust](03-bootstrap.md) | Symlinks, guards, direnv devshell, trusted editor config |
| 4 | [Your first compile](04-first-compile.md) | A running, freshly built QGIS (the only slow step, once) |
| 5 | [Editing with Neovim](05-neovim.md) | nix-vim + the `<leader>p` menu + full LSP |
| 6 | [Pre-commit & standards](06-precommit.md) | QGIS's own checks passing locally, findings in quickfix |
| 7 | [Your first patch](07-first-patch.md) | A clean, human-authored PR to upstream |
| 8 | [Debugging with DAP](08-debugging.md) | Step through QGIS core in Neovim — breakpoints, inspection, attach |

## Prerequisites

- **NixOS** (or any Linux with the Nix package manager) with flakes enabled:

    ```ini
    # /etc/nix/nix.conf or ~/.config/nix/nix.conf
    experimental-features = nix-command flakes
    ```

- **direnv + nix-direnv** enabled in your shell (on NixOS:
  `programs.direnv.enable = true;` in your configuration).
- An **ssh key registered with GitHub** — every git operation in this
  handbook uses ssh, never https.
- Roughly **100 GB of free disk**: a Debug build tree is ~30 GB and the
  shared ccache is capped at 50 GB.

!!! tip "Time budget"
    Steps 1–3 are minutes of typing. Step 4 downloads the toolchain and
    compiles QGIS once — start it, go for lunch. Everything after that is
    seconds-to-minutes, forever.
