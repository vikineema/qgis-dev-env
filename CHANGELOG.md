<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [SemVer](https://semver.org/).

## [0.2.0] - 2026-07-09

### Added

- **Embedded layout**: the sidecar now lives at `<QGIS>/qgis-dev-env`
  (plain nested clone, excluded locally, relative overlay symlinks);
  external placement still supported (FR-I1/I3 updated).
- **nix-vim** (`timlinux/nix-vim`) as a flake input and the standard
  editor of the devshell (FR-N8).
- **Developer handbook**: mkdocs-material site with the Kartoza brand
  theming from `kartoza/InfrastructureMapper` — the full developer
  journey (checkout → embed → bootstrap/trust → first compile → Neovim →
  pre-commit → first patch with the QGIS no-AI acknowledgement),
  reference section and embedded SRS. `nix run .#handbook[-build]`
  (FR-D4).
- **Handbook PDF** on the `kartoza/qgis-desktop-docker` pattern:
  `nix run .#handbook-pdf` (pandoc + pdflatex, branded cover/preamble);
  docs CI builds it on every PR/push and attaches it to releases (FR-D5).
- Spec constraint C10: development builds happen in the working tree
  (`build/`), never into the nix store.

### Fixed

- Publish helper forces ssh remote URLs (gh defaults to https); helper
  scripts are now ephemeral and gitignored, scrubbed from history.

## [0.1.0] - 2026-07-09

### Added

- Overlay flake composing the upstream QGIS devshell with build
  acceleration (ccache, mold, split-dwarf), LSP servers (clangd,
  basedpyright, neocmakelsp, nixd, bashls, luals, yamlls), QA tooling
  (valgrind, heaptrack, perf/hotspot, cppcheck, sanitizer profile) and
  docs tooling — all pinned via `flake.lock` (SRS groups N, B, L, G).
- `qgis-dev` task runner shared by `nix run .#<task>`, the terminal and
  Neovim: configure/build/clean/run/test/docs/precommit/tags/flags/
  profile/worktree/qa/stats/perf/doctor (FR-N4, NFR-M1).
- Build profiles: `debug` (default), `minimal`, `release`, `asan-ubsan`,
  with per-profile ccache namespacing (FR-B6).
- Build-time telemetry: every build logged (duration, ccache hit rate,
  branch, profile) to `~/.local/state/qgis-dev-env/build-log.tsv`;
  `qgis-dev stats` renders trends, `--graph` an SVG via gnuplot.
- Optional CPU performance-mode boost during builds
  (`qgis-dev perf build-toggle`, via powerprofilesctl).
- `bootstrap.sh`: idempotent overlay install/removal with managed
  `.git/info/exclude` block, anti-leak pre-push guard, pre-commit hook
  install, blame-ignore-revs wiring (group I).
- Neovim `<leader>p` project menu (`.nvim.lua`): async tasks with
  quickfix on failure, CMake flag toggling, worktree submenu, QA
  submenu, native LSP wiring — degrades gracefully without plugins
  (group E).
- Git worktree workflow: add (auto-bootstrapped), switch, status
  dashboard, guarded remove, prune (group W).
- Valgrind suppression starter sets for Qt6, glib and CPython (FR-G1).
- bats test suite covering bootstrap idempotency, isolation, the
  pre-push guard and doctor leak detection (FR-T1); GitHub Actions CI
  with shellcheck, gitleaks, reuse lint and flake evaluation (FR-T2).
