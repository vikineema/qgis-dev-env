<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# 6 · Pre-commit & standards

Your patch must pass QGIS's own quality gates *before* it leaves your
machine. The devshell carries everything upstream's
`.pre-commit-config.yaml` needs, at the same pinned versions as QGIS CI —
so "works locally" means "works in CI".

## What upstream checks

| Hook | Purpose |
|---|---|
| `clang-format` (v21) | C++ formatting per upstream `.clang-format` |
| `ruff` check + format | Python lint/format per upstream `.ruff.toml` |
| `spell_check` | QGIS's own dictionary-based spell checker |
| `banned_keywords`, `class_names`, `code_fixup` | QGIS coding conventions |
| `doxygen_test` | API documentation completeness |
| `shellcheck` | Shell script hygiene |
| `prepare_sip` | Regenerates SIP bindings from headers (runs last) |

## Run them the comfortable way

From Neovim: `<leader>pp` checks your **changed files**; `<leader>pP`
checks the full **branch diff** against `origin/master`. Findings are
parsed into the quickfix list — fix, `]q`, repeat, until the list closes
with a success notice.

From a terminal, identically:

```bash
qgis-dev precommit            # changed files
qgis-dev precommit --branch   # everything on the branch
```

## The safety net

Bootstrap ran `pre-commit install`, so a plain `git commit` runs the same
hooks again. Never bypass them — `--no-verify` is how broken patches reach
reviewers. Two more allies:

- `<leader>pl` runs **clang-tidy** on the current file (upstream
  `.clang-tidy` config) for deeper static analysis than formatting hooks.
- `qgis-dev doctor` confirms the hooks are actually installed.

!!! tip "Keep the diff boring"
    QGIS reviewers care that your diff contains *only* your change.
    Format-on-save over unrelated code creates noise — this environment
    deliberately formats only what the hooks require.

Continue to [7 · Your first patch](07-first-patch.md).
