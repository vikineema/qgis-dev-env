<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# Reference

Everything the environment can do, in lookup form. The
[Developer Journey](../getting-started/index.md) explains *when* to use
these; this section is the *what*.

- [qgis-dev commands](qgis-dev.md) — the complete task runner CLI
- [Neovim keymap](keymap.md) — the full `<leader>p` contract
- [Build profiles & flags](profiles.md) — debug / minimal / release / asan-ubsan, CMake tweaking
- [Worktrees](worktrees.md) — parallel feature branches
- [QA & diagnostics](qa.md) — sanitizers, valgrind, heaptrack, perf, GammaRay, cppcheck
- [Troubleshooting](troubleshooting.md) — field notes from real breakages, so nobody debugs them twice

Three interchangeable front-ends drive the same implementation, so pick
whichever fits the moment:

```bash
qgis-dev build              # in the devshell
nix run .#build             # from anywhere (enters the devshell for you)
```

…or `<leader>pb` in Neovim.
