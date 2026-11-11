# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
{
  description = "Kartoza QGIS developer environment overlay — sidecar devshell, task runner and editor tooling";

  nixConfig.bash-prompt = "\\[\\033[1m\\][qgis-dev]\\[\\033[m\\] \\w > ";

  inputs = {
    # Upstream QGIS flake, used read-only: we compose our devshell on top of
    # theirs (SRS C2, FR-N1) and reuse their nixpkgs pin (FR-N6).
    qgis.url = "github:qgis/QGIS";
    nixpkgs.follows = "qgis/nixpkgs";
    # Tim's fully configured Neovim — the standard editor of this devshell
    # (FR-N8). Keeps its own pins so it behaves exactly as released.
    nix-vim.url = "github:timlinux/nix-vim";
    # Provides clang-format/clang-tidy at the SAME major QGIS pre-commit
    # pins (v21), which the QGIS-pinned nixpkgs (LLVM 19) does not have.
    # Formatting must match CI exactly (FR-Q4), so we source these two
    # binaries from here rather than the toolchain pin.
    clang-tools-pin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      qgis,
      nix-vim,
      clang-tools-pin,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      lib = nixpkgs.lib;
      forAllSystems = f: lib.genAttrs systems (system: f (import nixpkgs { inherit system; config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) [
            "vscode"
          ];}) system);

      # Every task exposed as `nix run .#<task>` — same names as the Neovim
      # menu; both call the single qgis-dev implementation (FR-N4, NFR-M1).
      taskNames = [
        "configure"
        "build"
        "clean"
        "run"
        "designer"
        "qtcreator"
        "test"
        "docs"
        "docs-serve"
        "precommit"
        "tags"
        "flags"
        "targets"
        "profile"
        "worktree"
        "qa"
        "stats"
        "report"
        "perf"
        "ccache-stats"
        "ccache-zero"
        "doctor"
        "vscode"
      ];
    in
    {
      devShells = forAllSystems (
        pkgs: system:
        let
          qt = pkgs.qt6Packages;
          py = pkgs.python3Packages;

          # The task runner: a real dotfile deployed by reference (SRS C5).
          qgisDev = pkgs.runCommandLocal "qgis-dev" { } ''
            install -Dm755 ${./lib/tasks.sh} $out/bin/qgis-dev
          '';

          # Python interpreter for basedpyright (PyQGIS imports resolve
          # against the built tree; PyQt6 comes from here). FR-L3.
          devPython = pkgs.python3.withPackages (
            p:
            [
              p.pyqt6
              p.qscintilla-qt6
              p.nose2 # required by processing/tests/ProcessingGeneralTest.py
            ]
            ++ lib.optionals (p ? pyqt6-stubs) [ p.pyqt6-stubs ]
          );

          # clang-format / clang-tidy at v21 to match QGIS pre-commit exactly.
          # Exposed to qgis-dev via env vars (below) so PATH order can't shadow
          # them with the toolchain pin's older clang-format.
          clangToolsCI = clang-tools-pin.legacyPackages.${system}.clang-tools;

          lspServers = [
            pkgs.basedpyright
            pkgs.ruff
            pkgs.neocmakelsp
            pkgs.nixd
            pkgs.bash-language-server
            pkgs.lua-language-server
            pkgs.yaml-language-server
            pkgs.clang-tools # clangd for LSP (indexing, navigation)
          ];

          buildTools = [
            pkgs.ccache
            # mold-wrapped, not mold: -fuse-ld=mold must resolve to the
            # bintools-wrapped linker or NIX_LDFLAGS rpath injection is
            # bypassed and built binaries can't find store libs at runtime.
            pkgs.mold-wrapped
            pkgs.ninja
            pkgs.cmake
            pkgs.gdb
            pkgs.universal-ctags
            pkgs.doxygen
            pkgs.graphviz
            pkgs.pre-commit
            pkgs.shellcheck
            pkgs.pkg-config # cmake feature probes degrade silently without it
            pkgs.gnuplot # build-time trend graphs (qgis-dev stats --graph)
            pkgs.qt6.qttools # Qt Designer / Linguist / Assistant for .ui work
          ];

          qaTools =
            [
              pkgs.valgrind
              pkgs.heaptrack
              pkgs.cppcheck
            ]
            ++ lib.optionals (pkgs ? hotspot) [ pkgs.hotspot ]
            ++ lib.optionals (pkgs ? massif-visualizer) [ pkgs.massif-visualizer ]
            ++ lib.optionals (pkgs ? kdePackages && pkgs.kdePackages ? kcachegrind) [
              pkgs.kdePackages.kcachegrind
            ]
            ++ lib.optionals (pkgs ? gammaray) [ pkgs.gammaray ]
            ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.linuxPackages.perf ];

          sidecarTools = [
            pkgs.bats
            pkgs.gitleaks
            pkgs.reuse
          ];

          # nix-vim: the standard editor of this environment (FR-N8).
          editor = lib.optionals (nix-vim.packages ? ${system}) [
            nix-vim.packages.${system}.default
          ];

          # Qt Creator: optional full-IDE alternative (FR-K4). CMakePresets.json
          # (overlay-owned) gives it the same build/ tree + ccache as the CLI
          # and Neovim with no manual kit setup. Guarded: absent on some pins.
          qtCreator = lib.optionals (pkgs ? qtcreator) [ pkgs.qtcreator ];

          # Visual Studio Code
          vsCode = lib.optionals (pkgs ? vscode) [ pkgs.vscode ];

          # mkdocs stack for the developer handbook (FR-D4) — mirrors the
          # kartoza/InfrastructureMapper documentation toolchain.
          docsPython = pkgs.python3.withPackages (ps: [
            ps.mkdocs
            ps.mkdocs-material
            ps.mkdocs-material-extensions
            ps.mkdocs-glightbox
            ps.mkdocs-git-revision-date-localized-plugin
          ]);
        in
        {
          # The overlay devshell: upstream QGIS's dependency set + everything
          # else. Composed from their packages (not their devShell) so we own
          # the activation experience instead of inheriting dev-help noise.
          default = pkgs.mkShell {
            inputsFrom = [
              qgis.packages.${system}.qgis
              qgis.packages.${system}.qgis.passthru.unwrapped
            ];
            packages = [
              qgisDev
              devPython
              qt.qtbase
              qt.qtwayland
            ]
            ++ editor
            ++ qtCreator
            ++ vsCode
            ++ lspServers
            ++ buildTools
            ++ qaTools
            ++ sidecarTools;

            shellHook = ''
              # Qt runtime plugin discovery for build-tree binaries. Roots,
              # not a single dir: the wayland platform plugin lives in
              # qtwayland, SVG icon rendering in qtsvg/qtimageformats. Never
              # pin QT_QPA_PLATFORM_PLUGIN_PATH — it restricts the platform
              # search to one directory and breaks wayland sessions.
              export QT_PLUGIN_PATH="${qt.qtbase}/${qt.qtbase.qtPluginPrefix}:${qt.qtwayland}/${qt.qtbase.qtPluginPrefix}:${qt.qtsvg}/${qt.qtbase.qtPluginPrefix}:${qt.qtimageformats}/${qt.qtbase.qtPluginPrefix}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
              # QML modules (QtQuick.Controls etc. — the app's QML UI parts)
              export QML_IMPORT_PATH="${qt.qtdeclarative}/${qt.qtbase.qtQmlPrefix}''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
              export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
              # Store paths are resolved here, at shell time — never committed
              # into dotfiles (SRS C6). Consumed by `qgis-dev configure`.
              export QGIS_DEV_QT_PLUGINS_DIR="${qt.qtbase}/${qt.qtbase.qtPluginPrefix}"
              export QGIS_DEV_QSCI_SIP_DIR="${py.qscintilla-qt6}/${pkgs.python3.sitePackages}/PyQt6/bindings"
              export QGIS_DEV_QSCI_DIST_INFO="${py.qscintilla-qt6}/${pkgs.python3.sitePackages}/pyqt6_qscintilla-${py.qscintilla-qt6.version}.dist-info"
              export QGIS_DEV_PYQT6_DIST_INFO="${py.pyqt6}/${pkgs.python3.sitePackages}/pyqt6-${py.pyqt6.version}.dist-info"
              export QGIS_DEV_PYTHON="${devPython}/bin/python3"
              # Report infographic template as a store path, so `qgis-dev
              # report` works from a plain `nix develop`/`nix run` too.
              export QGIS_DEV_REPORT_GNUPLOT="${./lib/report.gnuplot}"
              # clang-format / clang-tidy at the QGIS pre-commit version (v21),
              # referenced explicitly so PATH order never resolves the older
              # toolchain clang-format (FR-Q4).
              export QGIS_DEV_CLANG_FORMAT="${clangToolsCI}/bin/clang-format"
              export QGIS_DEV_CLANG_TIDY="${clangToolsCI}/bin/clang-tidy"
              # Point pyright's committed pythonPath at today's interpreter.
              if [ -f CMakeLists.txt ] && [ -d src/core ]; then
                mkdir -p .dev-env
                ln -sfn "$QGIS_DEV_PYTHON" .dev-env/python
              fi
              # Visual Studio Code
              export VSCODE_USER_DIR="$(pwd)/qgis-dev-env/.vscode"
              export VSCODE_PROFILE="qgis-dev-env"
              export VSCODE_EXT_DIR="$(pwd)/qgis-dev-env/.vscode-extensions"
              export VSCODE_SETTINGS_FILE="$VSCODE_USER_DIR/settings.json"
              # Branded activation banner (real dotfile per SRS C5).
              source ${./lib/shell-motd.sh}
            '';
          };

          # Lightweight shell for hacking on the sidecar repo itself.
          tooling = pkgs.mkShell {
            packages = [
              qgisDev
              docsPython
              pkgs.bats
              pkgs.shellcheck
              pkgs.gitleaks
              pkgs.reuse
              pkgs.pre-commit
              pkgs.statix
              (pkgs.nixfmt-rfc-style or pkgs.nixfmt)
              pkgs.stylua
            ];
          };
        }
      );

      apps = forAllSystems (
        pkgs: system:
        let
          # mkdocs stack — used directly on PATH (no nested `nix develop`,
          # which would require nix-command to be enabled system-wide).
          docsPython = pkgs.python3.withPackages (ps: [
            ps.mkdocs
            ps.mkdocs-material
            ps.mkdocs-material-extensions
            ps.mkdocs-glightbox
            ps.mkdocs-git-revision-date-localized-plugin
          ]);
          # TeX Live for the handbook PDF (approach from
          # kartoza/qgis-desktop-docker) — combine, not scheme-full, to keep
          # the closure ~500 MB.
          pdfLatex = pkgs.texlive.combine {
            inherit (pkgs.texlive)
              scheme-medium
              # preamble.tex
              titlesec
              sectsty
              fancyhdr
              fvextra
              soul
              booktabs
              enumitem
              xcolor
              pgf
              fontspec
              unicode-math
              selnolig
              # pandoc's default LaTeX writer requirements
              upquote
              microtype
              parskip
              xurl
              bookmark
              hyperref
              xkeyval
              etoolbox
              pdftexcmds
              infwarerr
              kvoptions
              ltxcmds
              # Kartoza brand-pack body font (Lato) + transitive deps
              lato
              inconsolata
              fontaxes
              mweights
              ;
          };
          mkTask = name: {
            type = "app";
            program = toString (
              pkgs.writeShellScript "qgis-dev-${name}" ''
                exec nix --extra-experimental-features "nix-command flakes" \
                  develop ${self} --command qgis-dev ${name} "$@"
              ''
            );
            meta.description = "qgis-dev ${name} (inside the overlay devshell)";
          };
        in
        lib.genAttrs taskNames mkTask
        // {
          bootstrap = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "qgis-dev-bootstrap" ''
                exec ${lib.getExe pkgs.bash} ${./bootstrap.sh} "$@"
              ''
            );
            meta.description = "Overlay this sidecar onto a QGIS checkout";
          };
          handbook = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "qgis-dev-handbook" ''
                export PATH=${
                  lib.makeBinPath [
                    docsPython
                    pkgs.git
                  ]
                }:$PATH
                exec mkdocs serve -a localhost:8001 "$@"
              ''
            );
            meta.description = "Serve the developer handbook (run from the sidecar repo)";
          };
          handbook-build = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "qgis-dev-handbook-build" ''
                export PATH=${
                  lib.makeBinPath [
                    docsPython
                    pkgs.git
                  ]
                }:$PATH
                exec mkdocs build --strict "$@"
              ''
            );
            meta.description = "Build the handbook site into ./site (run from the sidecar repo)";
          };
          diagrams = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "qgis-dev-diagrams" ''
                export PATH=${
                  lib.makeBinPath [
                    pkgs.plantuml
                    pkgs.coreutils
                  ]
                }:$PATH
                mkdir -p docs/assets/uml
                echo "Rendering UML diagrams (docs/uml/*.puml -> docs/assets/uml/*.svg)…"
                plantuml -tsvg -nometadata -o "$PWD/docs/assets/uml" docs/uml/*.puml
                echo "Done: $(ls docs/assets/uml/*.svg | wc -l) SVG diagrams."
              ''
            );
            meta.description = "Render the UML diagrams (PlantUML -> SVG) into docs/assets/uml";
          };
          handbook-pdf = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "qgis-dev-handbook-pdf" ''
                export PATH=${
                  lib.makeBinPath [
                    pkgs.pandoc
                    pdfLatex
                    pkgs.librsvg
                    pkgs.coreutils
                    pkgs.gnused
                    pkgs.gawk
                    pkgs.bash
                  ]
                }:$PATH
                export QDE_DOCS_DIR=${./docs}
                export QDE_SPEC_FILE=${./SPECIFICATION.md}
                export QDE_PDF_DIR=${./docs/pdf}
                exec ${lib.getExe pkgs.bash} ${./lib/docs-pdf.sh} "$@"
              ''
            );
            meta.description = "Assemble the handbook into a Kartoza-branded PDF";
          };
        }
      );

      checks = forAllSystems (
        pkgs: _system: {
          tests =
            pkgs.runCommand "qgis-dev-env-bats"
              {
                nativeBuildInputs = [
                  pkgs.bats
                  pkgs.git
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.gawk
                ];
              }
              ''
                export HOME="$TMPDIR"
                git config --global user.email "ci@example.com"
                git config --global user.name "CI"
                git config --global init.defaultBranch master
                cp -r ${self} repo && chmod -R u+w repo && cd repo
                patchShebangs --build . >/dev/null
                bats tests
                touch $out
              '';
          shellcheck =
            pkgs.runCommand "qgis-dev-env-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; }
              ''
                shellcheck ${./bootstrap.sh} ${./lib/tasks.sh} ${./overlay/hooks/pre-push}
                touch $out
              '';
        }
      );

      formatter = forAllSystems (pkgs: _system: (pkgs.nixfmt-rfc-style or pkgs.nixfmt));
    };
}
