<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# Worktrees

Work on several feature branches in parallel without re-cloning,
re-configuring, or paying a cold compile per branch.

## Why this is cheap here

Two properties of the setup compound nicely:

1. `.git/info/exclude` and the hooks live in the **common** git directory
   — isolation registered once covers every worktree automatically.
2. The **ccache is shared** across worktrees, while each worktree keeps
   its own `build/` and `.dev-env/` state. A new worktree branched from a
   recently built revision compiles mostly from cache (≥ 80 % hits).

## Lifecycle

```bash
# create — one command does git worktree add AND bootstrap
qgis-dev worktree add fix-labeling-crash          # sibling: ../QGIS-fix-labeling-crash

# work there
cd ../QGIS-fix-labeling-crash && qgis-dev build   # warm from shared ccache

# overview
qgis-dev worktree status
# WORKTREE                       BRANCH               DIRTY  AHEAD  BUILD
# …/QGIS                         master                   0      0   28G
# …/QGIS-fix-labeling-crash      fix-labeling-crash       2      1   9G

# finish — guarded: refuses if dirty or unpushed (override with --force)
qgis-dev worktree remove ../QGIS-fix-labeling-crash
```

From Neovim: `<leader>pwn` create · `<leader>pwl` switch (`:tcd`, so
tasks, clangd and quickfix all follow) · `<leader>pws` dashboard ·
`<leader>pwD` remove · `<leader>pwp` prune.

!!! note "Each worktree is fully independent"
    Own build tree, own compile database (clangd follows the buffer), own
    build profile, own throwaway QGIS run-profiles. Only the ccache — and
    the isolation guarantee — are shared.
