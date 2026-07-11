<!--
SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
SPDX-License-Identifier: MIT
-->

# Changelog

All notable changes to this project will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- **`qgis-dev report`**: branded multi-panel build-performance infographic
  (PDF/SVG/PNG) — log-scaled duration trend, ccache hit-rate area,
  average duration per profile, summary band. `nix run .#report`,
  `<leader>pR`. Build log gained per-build ccache hit/miss counts.
- **Under the Hood** handbook section: architecture, flake, task runner,
  bootstrap/isolation, activation and build/run internals, illustrated
  with **10 PlantUML diagrams** rendered to SVG (`nix run .#diagrams`)
  and embedded as vector PDF in the handbook.
- Kartoza hero banner on the landing page, README and PDF cover.
- **DAP debugging**: gdb (`--interpreter=dap`) adapter + "Launch QGIS" /
  "Attach to running QGIS" configs in the overlay, driving nix-vim's DAP
  framework, UI and persistent breakpoints; `qgis-dev debugprep` helper.
  New journey step 8 "Debugging with DAP" with an illustrated walkthrough
  (11th UML diagram) — breakpoints, stepping, inspection, attach.
- **FAQ** page (why Neovim not Qt Creator, first-download, incremental
  builds, clangd index location/reuse, what keeps you waiting).
- **Qt Designer** provisioned (`qt6.qttools`) and launchable non-blocking
  via `qgis-dev designer` / `nix run .#designer` / `<leader>pu` —
  context-aware: resolves a source file's `.ui` from its `ui_<name>.h`
  include (FR-E10).

### Fixed

- Bootstrap excludes `.cache/` (clangd background index) from git, so the
  editor index never dirties the pristine checkout.

- Kartoza-branded devshell activation banner (branch, profile, ccache
  stats, last build) on every direnv load and `nix develop` (FR-N9);
  devshell now composes on upstream's packages, not their devShell.
- `qgis-dev relink`: safe force-relink keeping all compiled objects and
  regenerating configure-time artifacts like `qgisbuildpath.txt`
  (FR-B14).
- Per-build ccache **hit/miss counts** in the build log alongside the
  per-build hit rate; migration for existing logs (FR-B13).
- `.luarc.json` overlay fencing lua-language-server away from the huge
  QGIS tree (multi-minute editor startups otherwise).
- Handbook **Troubleshooting** page recording all field learnings.

### Fixed

- Debug builds: `-UGDAL_DEBUG` in Debug-config profiles — nixpkgs GDAL
  propagates `GDAL_DEBUG` to Debug consumers, breaking PDAL 2.8.4's
  headers in the vendored pdal_wrench (FR-B15).
- Linking through `mold-wrapped` instead of bare mold — unwrapped mold
  bypasses nix's bintools wrapper, producing binaries without store
  RUNPATHs that fail at build-time tool runs (FR-B15).
- pkg-config in the devshell (silent cmake feature-probe degradation);
  UTF-8 locale exported in user context (Qt/uic warnings); Qt
  plugin-path exports replicated from the dropped upstream hook.
- Banner prints exactly once per activation; devshell reloads when
  `lib/tasks.sh` changes (it is baked into the `qgis-dev` binary).
- **Running from the build tree on Wayland**: Qt plugin roots now cover
  qtwayland (platform), qtsvg/qtimageformats (icons) and a QML import
  path for qtdeclarative (welcome screen); the harmful
  `QT_QPA_PLATFORM_PLUGIN_PATH` pin is gone.
- **PyQGIS from the build tree**: runners launch bare (no
  `QGIS_PREFIX_PATH`, which selects install-layout paths) and self-heal
  the `qgisbuildpath.txt` marker and the configure-staged `qgis.PyQt`
  shim; doctor checks the staging.
- Recovery for stranded staging files (a raced parallel build can leave
  a *file* where `output/python/qgis/<pkg>` needs a directory), blocking
  later configures — documented in the handbook.

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
