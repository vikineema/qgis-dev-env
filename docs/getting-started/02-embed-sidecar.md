<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# 2 · Embed qgis-dev-env

Clone this repository **inside** the QGIS checkout, as a plain nested
clone (over ssh, as always):

```bash
cd ~/dev/cpp/QGIS
git clone git@github.com:timlinux/qgis-dev-env.git qgis-dev-env
```

The layout you are building:

```text
~/dev/cpp/QGIS/                ← upstream clone (pristine, always)
├── qgis-dev-env/              ← this repo: the embedded "sidecar"
│   ├── flake.nix              ← devshell: compilers, LSPs, QA tools, nix-vim
│   ├── bootstrap.sh           ← installs the overlay (next step)
│   ├── lib/tasks.sh           ← the qgis-dev command
│   └── overlay/ · profiles/ · suppressions/ · docs/
├── .envrc → qgis-dev-env/overlay/envrc          (after bootstrap)
├── .nvim.lua → qgis-dev-env/overlay/nvim.lua    (after bootstrap)
└── src/ · python/ · CMakeLists.txt …            (upstream, untouched)
```

## "Won't git see it?" — how the ignore works

Deliberately **not** a submodule: a submodule would put a committable
gitlink in the QGIS index — exactly the kind of upstream pollution this
project forbids. A plain nested clone has no representation in the outer
repo at all… except as an untracked directory.

That untracked directory (and every overlay symlink) is hidden using
`.git/info/exclude` — git's *local-only* ignore file. It behaves exactly
like `.gitignore` but lives inside `.git/`, is never committed, and is
shared by all worktrees. You don't edit it yourself: the next step's
bootstrap maintains a clearly marked managed block in it.

!!! warning "Never touch upstream's tracked `.gitignore`"
    Adding `qgis-dev-env/` to QGIS's own `.gitignore` would modify a
    tracked upstream file — a change you could accidentally commit.
    `.git/info/exclude` gives the identical effect with zero risk, and
    bootstrap writes it for you.

!!! warning "`git clean -fdx` deletes ignored files"
    That includes this embed and your `build/` tree. Plain
    `git clean -fd` is safe.

Continue to [3 · Bootstrap & trust](03-bootstrap.md).
