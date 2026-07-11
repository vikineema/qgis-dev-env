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

## Format-on-save: only the lines you touched

Saving a C/C++ file inside the checkout runs **clang-format on just the
lines you changed** (versus `HEAD`), using the **exact clang-format version
QGIS pins (v21.1.8)** — not the editor's LSP formatter. Two problems this
solves:

- **Version match.** The QGIS-pinned toolchain nixpkgs ships clang-format
  19; QGIS CI enforces 21. Formatting with the wrong version rewrites lines
  QGIS already formatted, so what you save no longer matches CI. The
  devshell therefore sources clang-format/clang-tidy at **v21** (a separate
  pinned input) and points `qgis-dev` straight at them.
- **Minimal diffs.** Only your touched line ranges are reformatted, so a
  save never churns code you didn't write — including **never rewrapping
  comments you didn't edit** (QGIS sets `ColumnLimit: 200` and
  `ReflowComments: false`; the formatter is pinned to the checkout's
  `.clang-format` explicitly so it can't silently fall back to LLVM defaults
  that wrap at 80). nix-vim's whole-file format-on-save is re-wrapped to
  honour the per-buffer opt-out, so it no longer fights or reformats the
  whole file.

| Action | Key | Scope |
|---|---|---|
| On save (automatic) | — | touched lines only |
| Format the **whole** file | `<leader>pf` | entire file (manual) |
| Naming check | `<leader>pn` | identifier naming for the file |

Turn the save behaviour off per session with `:lua vim.g.qgis_format_on_save
= false`, or from any terminal use `qgis-dev fmt [--all] <file>`.

### Variable naming

QGIS's `.clang-tidy` defines the identifier rules (members `camelBack`,
enums `CamelCase`, constants `UPPER_CASE`, …), and **clangd surfaces them
live** as you type. One correction the overlay makes: QGIS's `.clang-tidy`
demands static members be `sCamelCase`, but QGIS's own static *settings*
entries are camelBack (`settingsShowInstallFromZipWarning`), so the raw
rule flags QGIS's own compliant code on nearly every such line. The overlay
`.clangd` (and `qgis-dev naming`) relax `ClassMemberCase` to **camelBack**
with no forced prefix — genuine violations (a leading-uppercase name) are
still caught. `<leader>pn` runs a full-file check and surfaces violations as
diagnostics on the offending lines. Naming is **reported, not auto-renamed** — renaming
a symbol safely means touching every use of it, which is your call to make,
not a silent save-time rewrite. (Enable naming checks on every save with
`:lua vim.g.qgis_naming_on_save = true` if you want them nagging live —
it's a full-file clang-tidy pass, so it runs asynchronously.)

Continue to [7 · Your first patch](07-first-patch.md).
