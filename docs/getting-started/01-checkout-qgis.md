<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# 1 · Check out QGIS

Clone upstream QGIS wherever you keep source trees — over **ssh**:

```bash
git clone git@github.com:qgis/QGIS.git ~/dev/cpp/QGIS
cd ~/dev/cpp/QGIS
```

If you plan to submit patches (you do — that's step 7), fork
[qgis/QGIS](https://github.com/qgis/QGIS) on GitHub now and add your fork
as a second remote:

```bash
gh repo fork qgis/QGIS --remote=false      # or use the web UI
git remote add fork git@github.com:<you>/QGIS.git
```

!!! note "Why keep `origin` = upstream?"
    Branches track upstream master and `qgis-dev worktree add` bases new
    worktrees on it. Your fork is only a delivery vehicle for PRs.

## What you have now

A pristine upstream clone. `git status` is empty and — this is the promise
this whole environment keeps — **it will still be empty after every
remaining step of this journey.**

Continue to [2 · Embed qgis-dev-env](02-embed-sidecar.md).
