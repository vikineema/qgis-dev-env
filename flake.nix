{
  description = "Kartoza QGIS developer environment overlay — sidecar devshell, task runner and editor tooling";

  nixConfig.bash-prompt = "\\[\\033[1m\\][qgis-dev]\\[\\033[m\\] \\w > ";

  inputs = {
    # Upstream QGIS flake, used read-only: we compose our devshell on top of
    # theirs (SRS C2, FR-N1) and reuse their nixpkgs pin (FR-N6).
    qgis.url = "github:qgis/QGIS";
    nixpkgs.follows = "qgis/nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      qgis,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      lib = nixpkgs.lib;
      forAllSystems = f: lib.genAttrs systems (system: f (import nixpkgs { inherit system; }) system);

      # Every task exposed as `nix run .#<task>` — same names as the Neovim
      # menu; both call the single qgis-dev implementation (FR-N4, NFR-M1).
      taskNames = [
        "configure"
        "build"
        "clean"
        "run"
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
        "perf"
        "ccache-stats"
        "ccache-zero"
        "doctor"
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
            ]
            ++ lib.optionals (p ? pyqt6-stubs) [ p.pyqt6-stubs ]
          );

          lspServers = [
            pkgs.basedpyright
            pkgs.ruff
            pkgs.neocmakelsp
            pkgs.nixd
            pkgs.bash-language-server
            pkgs.lua-language-server
            pkgs.yaml-language-server
            (pkgs.clang-tools_21 or pkgs.clang-tools) # clangd + clang-format matching upstream pre-commit pin
          ];

          buildTools = [
            pkgs.ccache
            pkgs.mold
            pkgs.ninja
            pkgs.cmake
            pkgs.gdb
            pkgs.universal-ctags
            pkgs.doxygen
            pkgs.graphviz
            pkgs.pre-commit
            pkgs.shellcheck
            pkgs.gnuplot # build-time trend graphs (qgis-dev stats --graph)
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
        in
        {
          # The overlay devshell: upstream QGIS devshell + everything else.
          default = pkgs.mkShell {
            inputsFrom = [ qgis.devShells.${system}.default ];
            packages = [
              qgisDev
              devPython
            ]
            ++ lspServers
            ++ buildTools
            ++ qaTools
            ++ sidecarTools;

            shellHook = ''
              # Store paths are resolved here, at shell time — never committed
              # into dotfiles (SRS C6). Consumed by `qgis-dev configure`.
              export QGIS_DEV_QT_PLUGINS_DIR="${qt.qtbase}/${qt.qtbase.qtPluginPrefix}"
              export QGIS_DEV_QSCI_SIP_DIR="${py.qscintilla-qt6}/${pkgs.python3.sitePackages}/PyQt6/bindings"
              export QGIS_DEV_QSCI_DIST_INFO="${py.qscintilla-qt6}/${pkgs.python3.sitePackages}/pyqt6_qscintilla-${py.qscintilla-qt6.version}.dist-info"
              export QGIS_DEV_PYQT6_DIST_INFO="${py.pyqt6}/${pkgs.python3.sitePackages}/pyqt6-${py.pyqt6.version}.dist-info"
              export QGIS_DEV_PYTHON="${devPython}/bin/python3"
              # Point pyright's committed pythonPath at today's interpreter.
              if [ -f CMakeLists.txt ] && [ -d src/core ]; then
                mkdir -p .dev-env
                ln -sfn "$QGIS_DEV_PYTHON" .dev-env/python
              fi
            '';
          };

          # Lightweight shell for hacking on the sidecar repo itself.
          tooling = pkgs.mkShell {
            packages = [
              qgisDev
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
          mkTask = name: {
            type = "app";
            program = toString (
              pkgs.writeShellScript "qgis-dev-${name}" ''
                exec nix develop ${self} --command qgis-dev ${name} "$@"
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
