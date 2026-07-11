<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# PACKAGES

Annotated list of every tool the overlay devshell adds on top of upstream
QGIS's own devshell (which supplies all compile/link dependencies). All are
sourced from nixpkgs, pinned by `flake.lock` — no pip, no npm (SRS C3).

## Build acceleration

| Package | Why |
|---|---|
| `ccache` | Object cache; makes rebuilds after branch switches warm (FR-B1/B2) |
| `mold-wrapped` | Fast linker; linking dominates warm rebuild time (FR-B3). Wrapped variant is mandatory: bare mold bypasses nix's bintools wrapper and drops store RUNPATHs (FR-B15) |
| `ninja`, `cmake` | Build system (upstream standard) |
| `gnuplot` | Build-time trend graphs (`qgis-dev stats --graph`) |
| `qt6.qttools` | Qt Designer / Linguist / Assistant — `.ui` editing (`qgis-dev designer`, FR-E10) |

## Language servers & editing

| Package | Why |
|---|---|
| `clang-tools` (v21 preferred) | clangd LSP + clang-format matching upstream's pre-commit pin (FR-L1/L2) |
| `basedpyright` | Python/PyQGIS LSP (FR-L3) |
| `ruff` | Python lint/format, config from upstream `.ruff.toml` |
| `neocmakelsp` | CMake LSP (FR-L4) |
| `nixd` | Nix LSP (FR-L6) |
| `bash-language-server`, `shellcheck` | Shell LSP + lint (FR-L6) |
| `lua-language-server` | For editing the overlay's own nvim.lua |
| `yaml-language-server` | CI/config editing |
| `universal-ctags` | Supplementary tags for SIP/CMake/shell — what clangd doesn't index (FR-L8) |
| python `pyqt6`, `qscintilla-qt6` (+stubs when available) | Import resolution + typed completion for PyQGIS (FR-L3) |

## QA & diagnostics

| Package | Why |
|---|---|
| `valgrind` | memcheck, callgrind, massif (FR-G1) |
| `heaptrack` (+GUI) | Heap profiling, better fit for Qt apps (FR-G4) |
| `linuxPackages.perf`, `hotspot` | CPU profiling + flamegraph GUI (FR-G5) |
| `massif-visualizer`, `kcachegrind` | Visualizers (when available in the pin) |
| `cppcheck` | On-demand static analysis (FR-G8) |
| `gammaray` | Qt introspection (FR-G7; included when available in the pin) |
| `gdb` | Debugging; split-dwarf + gdb-index configured by the debug profile |

## Editor

| Package | Why |
|---|---|
| `nix-vim` (flake input, [timlinux/nix-vim](https://github.com/timlinux/nix-vim)) | The standard, fully configured team Neovim — `nvim` inside the devshell (FR-N8) |

## Documentation toolchain

| Package | Why |
|---|---|
| `mkdocs`, `mkdocs-material` (+extensions, glightbox, git-revision-date) | Developer handbook site, Kartoza-themed (FR-D4) |
| `pandoc`, `texlive.combine` (scheme-medium + brand fonts) | Kartoza-branded handbook PDF on PR/release (FR-D5) |

## Standards & repo hygiene

| Package | Why |
|---|---|
| `pre-commit` | Runs upstream QGIS hooks and this repo's own suite (FR-Q1/Q5) |
| `doxygen`, `graphviz` | API docs builds (FR-D1) |
| `bats` | This repo's test suite (FR-T1) |
| `gitleaks` | Secret scanning (NFR-S1) |
| `reuse` | SPDX/REUSE compliance (NFR-S1) |
| `statix`, `nixfmt-rfc-style`, `stylua` | Lint/format for the sidecar itself (tooling shell) |
