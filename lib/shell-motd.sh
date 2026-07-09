# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
# shellcheck shell=bash
#
# Devshell activation banner — sourced from the flake's shellHook, so it
# must never `exit`, never `set -e`, and always degrade gracefully.
# Suppress with QGIS_DEV_QUIET=1; colours honour NO_COLOR.

_qde_motd() {
  [ -n "${QGIS_DEV_QUIET:-}" ] && return 0
  # Print once per activation: under direnv both the flake shellHook and
  # .envrc source this file in the same process.
  [ -n "${_QDE_MOTD_DONE:-}" ] && return 0
  _QDE_MOTD_DONE=1
  # Only in a QGIS checkout root — silent elsewhere (e.g. sidecar hacking).
  [ -f CMakeLists.txt ] && [ -d src/core ] || return 0

  local blue amber dim bold reset grey
  if [ -z "${NO_COLOR:-}" ]; then
    blue=$'\033[38;2;84;162;204m'
    amber=$'\033[38;2;238;179;72m'
    grey=$'\033[38;2;138;139;139m'
    dim=$'\033[2m'
    bold=$'\033[1m'
    reset=$'\033[0m'
  else
    blue="" amber="" grey="" dim="" bold="" reset=""
  fi

  local branch profile ccache_line last_line boost configured
  branch="$(git branch --show-current 2>/dev/null || echo '?')"
  profile="$(cat .dev-env/profile 2>/dev/null || echo debug)"

  if command -v ccache >/dev/null 2>&1; then
    ccache_line="$(ccache -s 2>/dev/null | awk -F': *' '
      /^ *Hits/ && hits == "" { gsub(/ +/, " ", $2); hits = $2 }
      /Cache size/ {
        unit = "GB"
        if ($1 ~ /GiB/) unit = "GiB"
        gsub(/ +/, " ", $2)
        size = $2 " " unit
      }
      END {
        if (size ~ /^0\.0 /) { printf "empty - first build will fill it"; exit }
        if (size != "") printf "%s", size
        if (hits != "") printf "   hits %s", hits
      }')"
    [ -n "$ccache_line" ] || ccache_line="empty - first build will fill it"
  else
    ccache_line="unavailable"
  fi

  local log="${XDG_STATE_HOME:-$HOME/.local/state}/qgis-dev-env/build-log.tsv"
  if [ -s "$log" ]; then
    last_line="$(tail -1 "$log" | awk -F'\t' \
      '{ printf "%s in %ss, %s%% ccache (%s, %s)", $10, $8, $9, $5, substr($1, 1, 10) }')"
  else
    last_line="none yet - run: qgis-dev build"
  fi

  if [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/qgis-dev-env/perf-during-build" ]; then
    boost="${amber}on${reset}"
  else
    boost="${dim}off${reset}"
  fi
  if [ -f build/compile_commands.json ]; then
    configured="yes"
  else
    configured="${amber}not yet${reset} ${dim}(qgis-dev configure)${reset}"
  fi

  {
    printf '%s\n' "${blue}────────────────────────────────────────────────────────────────${reset}"
    printf '  %sQGIS Dev Env%s  %s·%s  Made with %s💗%s by %sKartoza%s\n' \
      "$bold" "$reset" "$grey" "$reset" "$amber" "$reset" "$blue" "$reset"
    printf '%s\n' "${blue}────────────────────────────────────────────────────────────────${reset}"
    printf '  %sbranch%s     %s\n' "$grey" "$reset" "$branch"
    printf '  %sprofile%s    %s   %sconfigured%s %s   %sboost%s %b\n' \
      "$grey" "$reset" "$profile" "$grey" "$reset" "$configured" "$grey" "$reset" "$boost"
    printf '  %sccache%s     %s\n' "$grey" "$reset" "$ccache_line"
    printf '  %slast build%s %s\n' "$grey" "$reset" "$last_line"
    printf '\n'
    printf '  %sqgis-dev%s build %s·%s run %s·%s test %s·%s doctor %s·%s help' \
      "$bold" "$reset" "$grey" "$reset" "$grey" "$reset" "$grey" "$reset" "$grey" "$reset"
    printf '     %s<leader>p%s in nvim\n' "$amber" "$reset"
    printf '  %shandbook%s   https://timlinux.github.io/qgis-dev-env/\n' "$grey" "$reset"
    printf '%s\n' "${blue}────────────────────────────────────────────────────────────────${reset}"
  } >&2
}
_qde_motd
unset -f _qde_motd
