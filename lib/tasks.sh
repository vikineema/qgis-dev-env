#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
#
# qgis-dev — the single task implementation behind both `nix run .#<task>`
# and the Neovim <leader>p project menu (SRS FR-N4, NFR-M1).
set -euo pipefail

die() {
  printf 'qgis-dev: error: %s\n' "$*" >&2
  exit 1
}
note() { printf '▸ %s\n' "$*" >&2; }

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/qgis-dev-env"
BUILD_LOG="$STATE_HOME/build-log.tsv"
mkdir -p "$STATE_HOME"

ROOT=""
SIDECAR=""
BUILD=""
STATE=""

init() {
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" ||
    die "not inside a git checkout (run from a QGIS worktree)"
  [[ -f "$ROOT/CMakeLists.txt" && -d "$ROOT/src/core" ]] ||
    die "'$ROOT' does not look like a QGIS checkout"
  if [[ -n "${QGIS_DEV_SIDECAR:-}" ]]; then
    SIDECAR="$QGIS_DEV_SIDECAR"
  elif [[ -f "$ROOT/.dev-env/sidecar" ]]; then
    SIDECAR="$(cat "$ROOT/.dev-env/sidecar")"
  elif [[ -L "$ROOT/.envrc" ]]; then
    SIDECAR="$(dirname "$(dirname "$(readlink -f "$ROOT/.envrc")")")"
  else
    die "cannot locate the qgis-dev-env sidecar (re-run bootstrap.sh)"
  fi
  BUILD="$ROOT/build"
  STATE="$ROOT/.dev-env"
  mkdir -p "$STATE"
}

current_profile() { cat "$STATE/profile" 2>/dev/null || echo debug; }

# ---------------------------------------------------------------- perf mode
perf_tool() { command -v powerprofilesctl || true; }

perf_set() {
  local tool
  tool="$(perf_tool)"
  if [[ -z "$tool" ]]; then
    note "powerprofilesctl not found — performance mode unavailable on this host"
    return 0
  fi
  "$tool" set "$1" 2>/dev/null || note "could not set power profile '$1'"
}

perf_get() {
  local tool
  tool="$(perf_tool)"
  if [[ -n "$tool" ]]; then "$tool" get 2>/dev/null || echo unknown; else echo unavailable; fi
}

cmd_perf() {
  local marker="$STATE_HOME/perf-during-build"
  case "${1:-status}" in
  on)
    perf_set performance
    note "power profile now: $(perf_get)"
    ;;
  off)
    perf_set balanced
    note "power profile now: $(perf_get)"
    ;;
  build-toggle)
    if [[ -f "$marker" ]]; then
      rm -f "$marker"
      note "build-time performance boost: OFF"
    else
      touch "$marker"
      note "build-time performance boost: ON (performance profile during builds, restored after)"
    fi
    ;;
  status)
    note "power profile now: $(perf_get)"
    if [[ -f "$marker" ]]; then note "build-time boost: on"; else note "build-time boost: off"; fi
    ;;
  *) die "usage: qgis-dev perf [on|off|build-toggle|status]" ;;
  esac
}

# ------------------------------------------------------------- ccache delta
ccache_counters() { # prints "<hits> <misses>"
  local hits=0 misses=0 key value
  if command -v ccache >/dev/null; then
    while read -r key value _; do
      case "$key" in
      direct_cache_hit | preprocessed_cache_hit) hits=$((hits + value)) ;;
      cache_miss) misses=$((misses + value)) ;;
      esac
    done < <(ccache --print-stats 2>/dev/null || true)
  fi
  echo "$hits $misses"
}

# ------------------------------------------------------------ configure/build
cmd_configure() {
  local prof pf
  prof="$(current_profile)"
  pf="$SIDECAR/profiles/$prof.profile"
  [[ -f "$pf" ]] || die "unknown build profile '$prof' (available: $(cmd_profile list | tr '\n' ' '))"
  local -a CMAKE_ARGS=(
    -G Ninja
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    -DCMAKE_C_COMPILER_LAUNCHER=ccache
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    -DCMAKE_INSTALL_PREFIX="$BUILD/app"
  )
  [[ -n "${QGIS_DEV_QT_PLUGINS_DIR:-}" ]] && CMAKE_ARGS+=(-DQT_PLUGINS_DIR="$QGIS_DEV_QT_PLUGINS_DIR")
  [[ -n "${QGIS_DEV_QSCI_SIP_DIR:-}" ]] && CMAKE_ARGS+=(-DQSCI_SIP_DIR="$QGIS_DEV_QSCI_SIP_DIR")
  [[ -n "${QGIS_DEV_QSCI_DIST_INFO:-}" ]] && CMAKE_ARGS+=(-DQSCI_DIST_INFO="$QGIS_DEV_QSCI_DIST_INFO")
  [[ -n "${QGIS_DEV_PYQT6_DIST_INFO:-}" ]] && CMAKE_ARGS+=(-DPYQT6_DIST_INFO="$QGIS_DEV_PYQT6_DIST_INFO")
  # shellcheck source=/dev/null
  source "$pf" # profile fragments append to CMAKE_ARGS
  note "configuring profile '$prof' → $BUILD"
  cmake -S "$ROOT" -B "$BUILD" "${CMAKE_ARGS[@]}" "$@"
}

log_build() { # ts host worktree branch profile targets jobs duration hitpct result hits misses
  if [[ ! -s "$BUILD_LOG" ]]; then
    printf 'timestamp\thost\tworktree\tbranch\tprofile\ttargets\tjobs\tduration_s\tccache_hit_pct\tresult\tccache_hits\tccache_misses\n' >"$BUILD_LOG"
  elif ! head -1 "$BUILD_LOG" | grep -q 'ccache_hits'; then
    # migrate pre-hits/misses logs: extend header, pad old rows
    local tmp
    tmp="$(mktemp)"
    awk 'NR == 1 { print $0 "\tccache_hits\tccache_misses"; next }
         { print $0 "\t-\t-" }' "$BUILD_LOG" >"$tmp"
    mv "$tmp" "$BUILD_LOG"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >>"$BUILD_LOG"
}

cmd_build() {
  local -a ninja_args=() targets=()
  local jobs=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -j)
      jobs="$2"
      ninja_args+=(-j "$2")
      shift
      ;;
    -j*)
      jobs="${1#-j}"
      ninja_args+=("$1")
      ;;
    *) targets+=("$1") ;;
    esac
    shift
  done
  [[ -n "$jobs" ]] || jobs="$(nproc)" # ninja defaults to all cores (FR: all-cores builds)
  [[ -f "$BUILD/build.ninja" ]] || cmd_configure

  local prof boost=0 prev_power=""
  prof="$(current_profile)"
  if [[ -f "$STATE_HOME/perf-during-build" ]]; then
    boost=1
    prev_power="$(perf_get)"
    perf_set performance
    note "performance boost active (was: $prev_power)"
  fi
  restore_power() {
    if [[ "$boost" -eq 1 ]]; then perf_set "${prev_power:-balanced}"; fi
  }
  trap restore_power EXIT

  local h0 m0 h1 m1 t0 t1 rc=0
  read -r h0 m0 <<<"$(ccache_counters)"
  t0="$(date +%s)"
  CCACHE_NAMESPACE="$prof" ninja -C "$BUILD" "${ninja_args[@]}" "${targets[@]}" || rc=$?
  t1="$(date +%s)"
  read -r h1 m1 <<<"$(ccache_counters)"

  local dh=$((h1 - h0)) dm=$((m1 - m0)) pct="-" dur=$((t1 - t0)) result=ok branch
  ((dh + dm > 0)) && pct=$((100 * dh / (dh + dm)))
  [[ "$rc" -eq 0 ]] || result=fail
  branch="$(git -C "$ROOT" branch --show-current 2>/dev/null || echo -)"
  log_build "$(date -Is)" "$(hostname)" "$ROOT" "$branch" "$prof" \
    "${targets[*]:-all}" "$jobs" "$dur" "$pct" "$result" "$dh" "$dm"
  note "build $result: ${dur}s, ccache ${pct}% (${dh} hits / ${dm} misses) — log: $BUILD_LOG"
  trap - EXIT
  restore_power
  return "$rc"
}

cmd_stats() {
  [[ -s "$BUILD_LOG" ]] || die "no builds logged yet"
  local n="${1:-20}" graph=0
  [[ "${1:-}" == "--graph" ]] && {
    graph=1
    n=200
  }
  {
    head -1 "$BUILD_LOG"
    tail -n "+2" "$BUILD_LOG" | tail -n "$n"
  } | cut -f1,4,5,6,7,8,9,10,11,12 | column -t -s"$(printf '\t')"
  echo
  tail -n "+2" "$BUILD_LOG" | tail -n "$n" | awk -F'\t' '
    { d[NR]=$8; sum+=$8; if (min==""||$8<min) min=$8; if ($8>max) max=$8 }
    END {
      if (NR==0) exit
      split("▁▂▃▄▅▆▇█", blocks, "")
      printf "trend  "
      for (i=1; i<=NR; i++) {
        idx = (max>min) ? int(((d[i]-min)/(max-min))*7)+1 : 1
        printf "%s", blocks[idx]
      }
      printf "\nbuilds %d   avg %.0fs   min %ds   max %ds\n", NR, sum/NR, min, max
    }'
  if [[ "$graph" -eq 1 ]]; then
    command -v gnuplot >/dev/null || die "gnuplot not available (enter the devshell)"
    local out="$STATE_HOME/build-times.svg"
    gnuplot <<EOF
set terminal svg size 1000,400 background rgb "white"
set output "$out"
set title "QGIS build times"
set ylabel "seconds"
set xlabel "build #"
set grid
plot "<tail -n +2 '$BUILD_LOG'" using 8 with linespoints title "duration (s)"
EOF
    note "graph written: $out"
  fi
}

fmt_hms() { # seconds -> "1h2m3s" / "2m3s" / "45s"
  local s="${1:-0}" h m
  s=${s%.*}
  h=$((s / 3600))
  m=$(((s % 3600) / 60))
  s=$((s % 60))
  if [[ "$h" -gt 0 ]]; then printf '%dh%dm%ds' "$h" "$m" "$s"; elif [[ "$m" -gt 0 ]]; then printf '%dm%ds' "$m" "$s"; else printf '%ds' "$s"; fi
}

cmd_report() {
  [[ -s "$BUILD_LOG" ]] || die "no builds logged yet — run 'qgis-dev build' first"
  command -v gnuplot >/dev/null || die "gnuplot not available (enter the devshell)"

  local fmt=pdf open=0 a
  for a in "$@"; do
    case "$a" in
    --pdf) fmt=pdf ;;
    --svg) fmt=svg ;;
    --png) fmt=png ;;
    --open) open=1 ;;
    *) die "usage: qgis-dev report [--pdf|--svg|--png] [--open]" ;;
    esac
  done

  local work clean prof
  work="$(mktemp -d)"
  clean="$work/clean.tsv"
  prof="$work/prof.tsv"

  # One awk pass: emit per-build numeric rows (clean.tsv), accumulate per-profile
  # averages (prof.tsv), and print scalar summary as KEY=VALUE lines.
  local vars
  vars="$(awk -F'\t' -v clean="$clean" -v prof="$prof" '
    NR == 1 { next }
    {
      idx++
      dur = $8 + 0
      ok = ($10 == "ok") ? 1 : 0
      hit = ($9 == "-" || $9 == "") ? "-" : $9
      printf "%d\t%d\t%s\t%d\n", idx, dur, hit, ok > clean
      sum += dur; durs[idx] = dur
      if (min == "" || dur < min) min = dur
      if (dur > max) max = dur
      if (ok) okc++; else failc++
      if ($9 != "-" && $9 != "") { hsum += $9; hn++ }
      hits += ($11 == "-" ? 0 : $11); miss += ($12 == "-" ? 0 : $12)
      pd[$5] += dur; pc[$5]++
      last = dur
    }
    END {
      if (idx == 0) { print "EMPTY=1"; exit }
      # per-profile file (index, avg, count, name)
      pi = 0
      for (p in pd) { pi++; printf "%d\t%.0f\t%d\t%s\n", pi, pd[p]/pc[p], pc[p], p > prof }
      # median
      n = asorti_simple(durs, sorted)
      if (n % 2) med = durs_sorted[(n+1)/2]; else med = (durs_sorted[n/2] + durs_sorted[n/2+1]) / 2
      printf "RPT_TOTAL=%d\n", idx
      printf "RPT_SUM=%d\n", sum
      printf "RPT_AVG=%d\n", sum/idx
      printf "RPT_MIN=%d\n", min
      printf "RPT_MAX=%d\n", max
      printf "RPT_MED=%d\n", med
      printf "RPT_OK=%d\n", okc
      printf "RPT_FAIL=%d\n", failc
      printf "RPT_HIT=%.1f\n", (hn ? hsum/hn : 0)
      printf "RPT_HITS=%d\n", hits
      printf "RPT_MISS=%d\n", miss
      printf "RPT_LAST=%d\n", last
      # log-scale the duration panel when a cold build dwarfs incrementals
      printf "RPT_YLOG=%d\n", (med > 0 && max > 15 * med) ? 1 : 0
    }
    # mawk-safe numeric sort of values in a[] -> global durs_sorted[1..n]
    function asorti_simple(arr, _tmp,   i, j, k, n, v) {
      n = 0
      for (i in arr) { n++; vals[n] = arr[i] }
      for (i = 2; i <= n; i++) { v = vals[i]; j = i - 1
        while (j >= 1 && vals[j] > v) { vals[j+1] = vals[j]; j-- }
        vals[j+1] = v }
      for (k = 1; k <= n; k++) durs_sorted[k] = vals[k]
      return n
    }
  ' "$BUILD_LOG")"
  eval "$vars"
  [[ "${EMPTY:-0}" == 1 ]] && die "no completed builds to report on"

  local cache="unknown"
  if command -v ccache >/dev/null; then
    cache="$(ccache -s 2>/dev/null | awk -F': *' '/Cache size/ {gsub(/ +/," ",$2); print $2; exit}')"
    [[ -n "$cache" ]] || cache="empty"
  fi

  local ext="$fmt" out
  out="$STATE_HOME/build-report.$ext"
  local host gendate
  host="$(hostname)"
  gendate="$(date '+%Y-%m-%d %H:%M')"

  gnuplot \
    -e "infile='$clean'" -e "proffile='$prof'" -e "outfile='$out'" -e "term='$fmt'" \
    -e "host='$host'" -e "gendate='$gendate'" \
    -e "rtotal=$RPT_TOTAL" -e "ravg='$(fmt_hms "$RPT_AVG")'" -e "rmed='$(fmt_hms "$RPT_MED")'" \
    -e "rmin='$(fmt_hms "$RPT_MIN")'" -e "rmax='$(fmt_hms "$RPT_MAX")'" -e "rlast='$(fmt_hms "$RPT_LAST")'" \
    -e "rhit=$RPT_HIT" -e "rhits=$RPT_HITS" -e "rmisses=$RPT_MISS" \
    -e "rok=$RPT_OK" -e "rfail=$RPT_FAIL" -e "rcache='$cache'" -e "ylog=$RPT_YLOG" \
    "${QGIS_DEV_REPORT_GNUPLOT:-$SIDECAR/lib/report.gnuplot}"

  rm -rf "$work"
  note "build report written: $out"
  note "$RPT_TOTAL builds · avg $(fmt_hms "$RPT_AVG") · median $(fmt_hms "$RPT_MED") · ccache ${RPT_HIT}%"
  if [[ "$open" -eq 1 ]]; then
    (xdg-open "$out" >/dev/null 2>&1 &) || note "could not open $out"
  fi
}

cmd_debugprep() {
  # Prepare a debug launch: self-heal the build-tree marker, warn if PyQGIS
  # staging is absent, and print the binary path on stdout for the DAP config.
  local bin="$BUILD/output/bin/qgis"
  [[ -x "$bin" ]] || die "no built binary at $bin — run 'qgis-dev build' first"
  ensure_build_marker
  [[ -f "$BUILD/output/python/qgis/PyQt/__init__.py" ]] ||
    note "python staging missing — run 'qgis-dev configure' if you need PyQGIS in the debugger"
  printf '%s\n' "$bin"
}

ensure_build_marker() {
  # qgisbuildpath.txt tells QGIS binaries they run from a build tree (PyQGIS
  # and resources then resolve against the build output, not the install
  # prefix). CMake writes it at configure time only; restore it if lost.
  local marker="$BUILD/output/bin/qgisbuildpath.txt"
  if [[ -d "$BUILD/output/bin" && ! -f "$marker" ]]; then
    printf '%s\n%s\n' "$ROOT" "$BUILD/output" >"$marker"
    note "restored qgisbuildpath.txt (running-from-build-tree marker)"
  fi
}

cmd_relink() {
  # Force every target to relink (e.g. after a linker/toolchain change)
  # WITHOUT losing compiled objects. A bare `rm -rf build/output` is a trap:
  # configure-time files (qgisbuildpath.txt) live there too, so we must
  # reconfigure after clearing it.
  [[ -f "$BUILD/build.ninja" ]] || die "not configured yet — nothing to relink"
  note "clearing linked artifacts ($BUILD/output) — compiled objects are kept"
  rm -rf "$BUILD/output"
  cmd_configure
  note "now run 'qgis-dev build' — it will relink from cached objects"
}

# --------------------------------------------------------------- run / test
cmd_run() {
  local bin="$BUILD/output/bin/qgis"
  [[ -x "$bin" ]] || die "no built binary at $bin — run 'qgis-dev build' first"
  ensure_build_marker
  # The qgis.PyQt shim is staged at configure time under build/output —
  # if it is gone, PyQGIS dies with "No module named 'qgis.PyQt'".
  if [[ ! -f "$BUILD/output/python/qgis/PyQt/__init__.py" ]]; then
    note "python staging incomplete (qgis.PyQt missing) — reconfiguring to restore it"
    cmd_configure
  fi
  mkdir -p "$STATE/profiles"
  note "launching $bin (isolated profile under .dev-env/profiles — your real QGIS profile is safe)"
  # No QGIS_PREFIX_PATH: the qgisbuildpath.txt marker drives path discovery;
  # a prefix env var selects install-layout paths and breaks PyQGIS.
  "$bin" --profiles-path "$STATE" "$@"
}

cmd_designer() {
  command -v designer >/dev/null || die "Qt Designer not available (enter the devshell)"
  local arg="${1:-}" uifile="" f base hdr uibase b
  if [[ "$arg" == *.ui && -f "$arg" ]]; then
    uifile="$arg"
  elif [[ -n "$arg" && -f "$arg" ]]; then
    # QGIS links a dialog to its .ui via an `#include "ui_<name>.h"` — often
    # in the paired header, so scan the file and its .cpp/.h counterpart.
    base="${arg%.*}"
    for f in "$arg" "${base}.h" "${base}.cpp"; do
      [[ -f "$f" ]] || continue
      hdr="$(grep -hoE 'ui_[a-zA-Z0-9_]+\.h' "$f" | head -1 || true)"
      if [[ -n "$hdr" ]]; then
        uibase="${hdr#ui_}"
        uibase="${uibase%.h}"
        uifile="$(find "$ROOT/src" -name "${uibase}.ui" 2>/dev/null | head -1)"
        [[ -n "$uifile" ]] && break
      fi
    done
    if [[ -z "$uifile" ]]; then # basename fallback (…base.ui or ….ui)
      b="$(basename "$base")"
      uifile="$(find "$ROOT/src" \( -iname "${b}base.ui" -o -iname "${b}.ui" \) 2>/dev/null | head -1)"
    fi
  fi
  if [[ -n "$uifile" && -f "$uifile" ]]; then
    note "Qt Designer: $uifile"
    setsid designer "$uifile" >/dev/null 2>&1 </dev/null &
  else
    [[ -n "$arg" ]] && note "no .ui found for $(basename "$arg") — launching Qt Designer"
    setsid designer >/dev/null 2>&1 </dev/null &
  fi
  disown 2>/dev/null || true
}

cmd_test() {
  [[ -f "$BUILD/build.ninja" ]] || die "not configured — run 'qgis-dev configure' first"
  (cd "$BUILD" && QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" ctest --output-on-failure "$@")
}

cmd_test_file() {
  local f="${1:?usage: qgis-dev test-file <path>}"
  local name
  name="$(basename "$f")"
  name="${name%.*}"
  note "running ctest matching '$name'"
  cmd_test -R "$name"
}

# --------------------------------------------------------------------- docs
cmd_docs() { cmd_build apidoc; }

cmd_docs_serve() {
  local idx dir
  idx="$(find "$BUILD/doc" -name index.html 2>/dev/null | head -1 || true)"
  [[ -n "$idx" ]] || die "no built docs found — run 'qgis-dev docs' first"
  dir="$(dirname "$idx")"
  note "serving $dir at http://localhost:8000 (Ctrl-C to stop)"
  python3 -m http.server 8000 -d "$dir"
}

# --------------------------------------------------------- standards / hooks
cmd_precommit() {
  command -v pre-commit >/dev/null || die "pre-commit not available (enter the devshell)"
  local -a files=() existing=()
  if [[ "${1:-}" == "--branch" ]]; then
    local base
    base="$(git -C "$ROOT" merge-base origin/master HEAD 2>/dev/null)" ||
      die "cannot find merge-base with origin/master"
    mapfile -t files < <(git -C "$ROOT" diff --name-only "$base"..HEAD)
  else
    mapfile -t files < <(
      {
        git -C "$ROOT" diff --name-only HEAD
        git -C "$ROOT" diff --cached --name-only
      } | sort -u
    )
  fi
  local f
  for f in "${files[@]}"; do [[ -f "$ROOT/$f" ]] && existing+=("$f"); done
  if [[ "${#existing[@]}" -eq 0 ]]; then
    note "no changed files — nothing to check"
    return 0
  fi
  note "pre-commit over ${#existing[@]} file(s)"
  (cd "$ROOT" && pre-commit run --files "${existing[@]}")
}

cmd_tidy() {
  local f="${1:?usage: qgis-dev tidy <file>}"
  local ct="${QGIS_DEV_CLANG_TIDY:-clang-tidy}"
  command -v "$ct" >/dev/null 2>&1 || [[ -x "$ct" ]] || die "clang-tidy not available (enter the devshell)"
  [[ -f "$BUILD/compile_commands.json" ]] || die "no compile_commands.json — run 'qgis-dev configure'"
  "$ct" -p "$BUILD" "$f"
}

# clang-format at the QGIS pre-commit version (FR-Q4). Default: only the
# lines changed vs HEAD (minimal, reviewer-friendly diffs). --all: whole file.
cmd_fmt() {
  local all=0 f="" a
  for a in "$@"; do
    case "$a" in
    --all) all=1 ;;
    *) f="$a" ;;
    esac
  done
  [[ -n "$f" && -f "$f" ]] || die "usage: qgis-dev fmt [--all] <file>"
  case "$f" in
  *.cpp | *.cc | *.cxx | *.c | *.h | *.hpp) ;;
  *) return 0 ;; # not a C/C++ file — nothing to do
  esac
  local cf="${QGIS_DEV_CLANG_FORMAT:-clang-format}"
  command -v "$cf" >/dev/null 2>&1 || [[ -x "$cf" ]] || die "clang-format not available (enter the devshell)"

  if [[ "$all" -eq 1 ]] || ! git -C "$ROOT" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    "$cf" -i --style=file "$f"
    if [[ "$all" -eq 1 ]]; then
      note "clang-format (whole file): $(basename "$f")"
    else
      note "clang-format (new file): $(basename "$f")"
    fi
    return 0
  fi

  # Touched-line ranges from the +side of the diff vs HEAD (staged+unstaged).
  local -a ranges=()
  local h start len
  while IFS= read -r h; do
    [[ "$h" =~ \+([0-9]+)(,([0-9]+))? ]] || continue
    start="${BASH_REMATCH[1]}"
    len="${BASH_REMATCH[3]:-1}"
    [[ "$len" -eq 0 ]] && continue # pure deletion — no lines to format
    ranges+=(--lines="$start:$((start + len - 1))")
  done < <(git -C "$ROOT" diff -U0 --no-color HEAD -- "$f" 2>/dev/null | grep '^@@')

  if [[ "${#ranges[@]}" -eq 0 ]]; then
    note "no changed lines in $(basename "$f")"
    return 0
  fi
  "$cf" -i --style=file "${ranges[@]}" "$f"
  note "clang-format (${#ranges[@]} touched range(s)): $(basename "$f")"
}

# Variable/identifier naming per QGIS's .clang-tidy (readability-identifier-
# naming). Prints file:line:col: warning lines for the editor to consume.
cmd_naming() {
  local f="${1:?usage: qgis-dev naming <file>}"
  [[ -f "$f" ]] || die "no such file: $f"
  local ct="${QGIS_DEV_CLANG_TIDY:-clang-tidy}"
  command -v "$ct" >/dev/null 2>&1 || [[ -x "$ct" ]] || die "clang-tidy not available (enter the devshell)"
  [[ -f "$BUILD/compile_commands.json" ]] || die "no compile_commands.json — run 'qgis-dev configure'"
  # Inherit the tree's .clang-tidy but relax ClassMemberCase to camelBack —
  # QGIS's static "settings" members are camelBack, not sCamelCase, so the
  # upstream rule flags QGIS's own compliant code. InheritParentConfig merges
  # (not replaces), so all other naming rules still apply. Mirrors .clangd.
  local cfg='{InheritParentConfig: true, CheckOptions: {readability-identifier-naming.ClassMemberCase: camelBack, readability-identifier-naming.ClassMemberPrefix: ""}}'
  "$ct" -p "$BUILD" --checks='-*,readability-identifier-naming' \
    --config="$cfg" --quiet "$f" 2>/dev/null |
    grep -E ':[0-9]+:[0-9]+: (warning|error):' || true
}

cmd_tags() {
  command -v ctags >/dev/null || die "ctags not available (enter the devshell)"
  note "regenerating supplementary tags (SIP, CMake, shell) → .dev-env/tags"
  (cd "$ROOT" && find . \( -path ./build -o -path ./.git -o -path ./external \) -prune -o \
    -type f \( -name '*.sip' -o -name '*.sip.in' -o -name 'CMakeLists.txt' \
    -o -name '*.cmake' -o -name '*.sh' \) -print |
    ctags -L - -o "$STATE/tags" --tag-relative=yes 2>/dev/null)
  note "done: $(wc -l <"$STATE/tags") tag entries"
}

# ------------------------------------------------------------ cmake tweaking
cmd_flags() {
  [[ -f "$BUILD/CMakeCache.txt" ]] || die "not configured yet — run 'qgis-dev configure'"
  grep -E '^(WITH_|ENABLE_|BUILD_|CMAKE_BUILD_TYPE)[A-Z0-9_]*:' "$BUILD/CMakeCache.txt" | sort
}

cmd_targets() {
  [[ -f "$BUILD/build.ninja" ]] || die "not configured yet — run 'qgis-dev configure'"
  ninja -C "$BUILD" -t targets depth 1 2>/dev/null | cut -d: -f1 | sort
}

cmd_profile() {
  case "${1:-}" in
  "") current_profile ;;
  list)
    local p
    for p in "$SIDECAR"/profiles/*.profile; do basename "$p" .profile; done
    ;;
  *)
    [[ -f "$SIDECAR/profiles/$1.profile" ]] ||
      die "no such profile '$1' (available: $(cmd_profile list | tr '\n' ' '))"
    echo "$1" >"$STATE/profile"
    note "build profile set to '$1' — reconfiguring"
    cmd_configure
    ;;
  esac
}

# ------------------------------------------------------------------ worktree
cmd_worktree() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
  add)
    local branch="${1:?usage: qgis-dev worktree add <branch> [<base>]}" base="${2:-master}"
    local safe dir
    safe="${branch//\//-}"
    dir="$(dirname "$ROOT")/$(basename "$ROOT")-$safe"
    [[ -e "$dir" ]] && die "$dir already exists"
    if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$ROOT" worktree add "$dir" "$branch"
    else
      git -C "$ROOT" worktree add -b "$branch" "$dir" "$base"
    fi
    "$SIDECAR/bootstrap.sh" "$dir"
    note "worktree ready: $dir (bootstrapped; ccache is shared, so builds start warm)"
    ;;
  list) git -C "$ROOT" worktree list ;;
  porcelain) git -C "$ROOT" worktree list --porcelain ;;
  status)
    local wt branch dirty ahead size
    printf '%-50s %-30s %6s %8s %8s\n' WORKTREE BRANCH DIRTY AHEAD BUILD
    while read -r wt; do
      branch="$(git -C "$wt" branch --show-current 2>/dev/null || echo '?')"
      dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l)"
      ahead="$(git -C "$wt" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo '-')"
      size="$(du -sh "$wt/build" 2>/dev/null | cut -f1 || true)"
      printf '%-50s %-30s %6s %8s %8s\n' "$wt" "$branch" "$dirty" "$ahead" "${size:--}"
    done < <(git -C "$ROOT" worktree list --porcelain | awk '/^worktree /{print $2}')
    ;;
  remove)
    local dir="${1:?usage: qgis-dev worktree remove <path> [--force]}" force="${2:-}"
    [[ -d "$dir" ]] || die "no such worktree: $dir"
    if [[ "$force" != "--force" ]]; then
      [[ -z "$(git -C "$dir" status --porcelain)" ]] ||
        die "worktree has uncommitted changes — commit/stash them or pass --force"
      if ! git -C "$dir" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
        die "branch has no upstream (nothing pushed) — pass --force to remove anyway"
      fi
      [[ -z "$(git -C "$dir" rev-list '@{upstream}..HEAD' 2>/dev/null)" ]] ||
        die "branch has unpushed commits — push them or pass --force"
    fi
    rm -rf "$dir/build" "$dir/.dev-env"
    if [[ "$force" == "--force" ]]; then
      git -C "$ROOT" worktree remove --force "$dir"
    else
      git -C "$ROOT" worktree remove "$dir"
    fi
    note "removed $dir (shared ccache untouched)"
    ;;
  prune) git -C "$ROOT" worktree prune -v ;;
  *) die "usage: qgis-dev worktree [add|list|status|remove|prune]" ;;
  esac
}

# ------------------------------------------------------------------------ QA
diag_dir() {
  local d
  d="$STATE/diagnostics/$(date +%Y%m%d-%H%M%S)-$1"
  mkdir -p "$d"
  printf '%s\n' "$d"
}

qa_exe() { # default to the qgis binary; accept an explicit executable
  if [[ -n "${1:-}" && -x "${1:-}" ]]; then printf '%s\n' "$1"; else printf '%s\n' "$BUILD/output/bin/qgis"; fi
}

memcheck_to_locations() { # valgrind log → "path:line: message" lines
  local log="$1" map="$STATE/filemap.tsv"
  if [[ ! -s "$map" ]]; then
    (cd "$ROOT" && find src -type f \( -name '*.cpp' -o -name '*.h' \) -printf '%f\t%p\n' >"$map")
  fi
  gawk -v mapfile="$map" -v root="$ROOT" '
    BEGIN {
      while ((getline line < mapfile) > 0) {
        split(line, a, "\t")
        if (!(a[1] in m)) m[a[1]] = a[2]
      }
    }
    /^==[0-9]+== [0-9,]+ bytes/ || /Invalid (read|write)/ || /Conditional jump/ || /uninitialised/ {
      head = $0; sub(/^==[0-9]+== */, "", head); found = 0
    }
    match($0, /\(([A-Za-z0-9_.-]+\.(cpp|h)):([0-9]+)\)/, g) {
      if (!found && (g[1] in m)) {
        printf "%s/%s:%s: %s\n", root, m[g[1]], g[3], head
        found = 1
      }
    }' "$log"
}

cmd_qa() {
  local tool="${1:-list}"
  shift || true
  case "$tool" in
  memcheck)
    command -v valgrind >/dev/null || die "valgrind not available (enter the devshell)"
    local exe d supp=()
    exe="$(qa_exe "${1:-}")"
    [[ $# -gt 0 && -x "${1:-}" ]] && shift
    d="$(diag_dir memcheck)"
    local f
    for f in "$SIDECAR"/suppressions/*.supp; do supp+=("--suppressions=$f"); done
    note "valgrind memcheck → $d/valgrind.log"
    note "(slow — for most memory bugs 'qgis-dev qa asan' is the better first tool)"
    mkdir -p "$STATE/profiles"
    valgrind --leak-check=full --num-callers=25 \
      "${supp[@]}" --log-file="$d/valgrind.log" \
      "$exe" --profiles-path "$STATE" "$@" || true
    memcheck_to_locations "$d/valgrind.log"
    note "full log: $d/valgrind.log"
    ;;
  asan)
    local target="${1:-qgis}" d exe
    shift || true
    note "switching to 'asan-ubsan' profile (was: $(current_profile))"
    echo asan-ubsan >"$STATE/profile"
    cmd_configure
    cmd_build "$target"
    d="$(diag_dir asan)"
    exe="$BUILD/output/bin/qgis"
    [[ "$target" != qgis && -x "$BUILD/output/bin/$target" ]] && exe="$BUILD/output/bin/$target"
    note "running $exe under ASan/UBSan…"
    mkdir -p "$STATE/profiles"
    ASAN_OPTIONS="log_path=$d/asan:halt_on_error=0:detect_leaks=1" \
      UBSAN_OPTIONS="log_path=$d/ubsan:print_stacktrace=1" \
      "$exe" --profiles-path "$STATE" "$@" || true
    cat "$d"/asan.* "$d"/ubsan.* 2>/dev/null || note "no sanitizer reports — clean run"
    note "reports (if any) in $d; switch back with 'qgis-dev profile debug'"
    ;;
  heaptrack)
    command -v heaptrack >/dev/null || die "heaptrack not available (enter the devshell)"
    local exe d
    exe="$(qa_exe "${1:-}")"
    d="$(diag_dir heaptrack)"
    mkdir -p "$STATE/profiles"
    note "heaptrack → $d"
    heaptrack -o "$d/heaptrack" \
      "$exe" --profiles-path "$STATE" || true
    if command -v heaptrack_gui >/dev/null; then heaptrack_gui "$d"/heaptrack.* & fi
    ;;
  perf)
    command -v perf >/dev/null || die "perf not available (enter the devshell; see README for kernel.perf_event_paranoid)"
    local exe d
    exe="$(qa_exe "${1:-}")"
    d="$(diag_dir perf)"
    mkdir -p "$STATE/profiles"
    note "perf record (dwarf call graphs) → $d/perf.data"
    perf record -g --call-graph dwarf -o "$d/perf.data" -- \
      "$exe" --profiles-path "$STATE" || true
    if command -v hotspot >/dev/null; then
      hotspot "$d/perf.data" &
    else
      note "open with: perf report -i $d/perf.data"
    fi
    ;;
  callgrind)
    command -v valgrind >/dev/null || die "valgrind not available (enter the devshell)"
    local exe d
    exe="$(qa_exe "${1:-}")"
    d="$(diag_dir callgrind)"
    mkdir -p "$STATE/profiles"
    valgrind --tool=callgrind \
      --callgrind-out-file="$d/callgrind.out" \
      "$exe" --profiles-path "$STATE" || true
    if command -v kcachegrind >/dev/null; then kcachegrind "$d/callgrind.out" & fi
    note "callgrind data: $d/callgrind.out"
    ;;
  cppcheck)
    command -v cppcheck >/dev/null || die "cppcheck not available (enter the devshell)"
    local path="${1:-$ROOT/src/core}"
    cppcheck --enable=warning,style,performance --inline-suppr --quiet \
      --template='{file}:{line}: {severity}: {message}' "$path"
    ;;
  gammaray)
    command -v gammaray >/dev/null || die "gammaray not available (see SRS FR-G7)"
    local pid
    pid="$(pgrep -n -f "$BUILD/output/bin/qgis" || true)"
    if [[ -n "$pid" ]]; then
      note "attaching GammaRay to running QGIS (pid $pid)"
      gammaray --pid "$pid" &
    else
      die "no running QGIS from this build tree — start it with 'qgis-dev run' first"
    fi
    ;;
  list)
    if [[ -d "$STATE/diagnostics" ]]; then
      find "$STATE/diagnostics" -mindepth 1 -maxdepth 1 -type d | sort
    else
      note "no diagnostic reports yet"
    fi
    ;;
  *) die "usage: qgis-dev qa [memcheck|asan|heaptrack|perf|callgrind|cppcheck|gammaray|list]" ;;
  esac
}

# -------------------------------------------------------------------- doctor
cmd_doctor() {
  local fails=0
  ok() { printf '  \342\234\223 %s\n' "$*"; }
  bad() {
    printf '  \342\234\227 %s\n' "$*"
    fails=$((fails + 1))
  }
  echo "qgis-dev doctor — $ROOT"
  local b
  for b in cmake ninja ccache clangd basedpyright pre-commit valgrind mold; do
    if command -v "$b" >/dev/null; then ok "$b available"; else bad "$b missing (devshell inactive? run 'direnv allow')"; fi
  done
  if [[ -d "$SIDECAR" ]]; then ok "sidecar: $SIDECAR"; else bad "sidecar directory missing"; fi
  if [[ -L "$ROOT/.envrc" ]]; then ok ".envrc symlink in place"; else bad ".envrc missing or not a symlink (re-run bootstrap.sh)"; fi
  if [[ -f "$BUILD/compile_commands.json" ]]; then ok "compile_commands.json present"; else bad "no compile_commands.json (run 'qgis-dev configure')"; fi
  if [[ ! -d "$BUILD/output" ]] || [[ -f "$BUILD/output/python/qgis/PyQt/__init__.py" ]]; then
    ok "python staging (qgis.PyQt) intact"
  else
    bad "qgis.PyQt staging missing — run 'qgis-dev configure' (PyQGIS would be disabled)"
  fi
  local common
  common="$(cd "$ROOT" && readlink -f "$(git rev-parse --git-common-dir)")"
  if grep -q 'qgis-dev-env' "$common/info/exclude" 2>/dev/null; then ok "git exclude block registered"; else bad "exclude block missing (re-run bootstrap.sh)"; fi
  if [[ -e "$common/hooks/pre-push" ]]; then ok "anti-leak pre-push guard installed"; else bad "pre-push guard missing"; fi
  if [[ -e "$common/hooks/pre-commit" ]]; then ok "pre-commit hooks installed"; else bad "pre-commit hooks not installed (run 'pre-commit install' in the checkout)"; fi
  # Isolation across every worktree (FR-W7, FR-I4)
  local wt leaks
  while read -r wt; do
    leaks="$(git -C "$wt" status --porcelain 2>/dev/null |
      grep -cE '(\.envrc|\.nvim\.lua|\.exrc|\.clangd|pyrightconfig\.json|\.luarc\.json|PROMPT\.log|SRS-qgis-dev-env\.md|\.dev-env|qgis-dev-env)' || true)"
    if [[ "$leaks" -eq 0 ]]; then
      ok "isolation intact: $wt"
    else
      bad "OVERLAY FILES VISIBLE to upstream git in $wt — unstage them now (git restore --staged <file>)"
    fi
  done < <(git -C "$ROOT" worktree list --porcelain | awk '/^worktree /{print $2}')
  if [[ "$fails" -eq 0 ]]; then
    note "all checks passed"
  else
    die "$fails check(s) failed"
  fi
}

usage() {
  cat <<'EOF'
qgis-dev — QGIS developer tasks (shared by `nix run .#<task>` and Neovim)

  configure [-DVAR=VAL…]     cmake-configure build/ with the active profile
  build [-jN] [target…]      ninja build (all cores by default; timed + logged)
  clean                      ninja clean
  relink                     clear linked outputs + reconfigure (objects kept)
  debugprep                  self-heal + print the binary path (used by nvim DAP)
  run [args…]                launch built QGIS with an isolated profile
  designer [file]            open Qt Designer (non-blocking); resolves the
                             .ui for a source file when given one
  test [ctest args…]         run ctest (offscreen)
  test-file <path>           run the test matching a source file
  docs | docs-serve          build / serve the API docs
  precommit [--branch]       QGIS pre-commit hooks on changed files (or branch diff)
  fmt [--all] <file>         clang-format (v21) — touched lines, or whole file
  naming <file>              QGIS identifier-naming check (clang-tidy) → warnings
  tidy <file>                clang-tidy one file
  tags                       regenerate supplementary ctags (SIP/CMake/shell)
  flags | targets            list cmake cache flags / ninja targets
  profile [name|list]        show / switch build profile (reconfigures)
  worktree <add|list|status|remove|prune>
  qa <memcheck|asan|heaptrack|perf|callgrind|cppcheck|gammaray|list>
  stats [N|--graph]          build-time history (table + trend; svg with --graph)
  report [--pdf|--svg|--png] [--open]   branded build-performance infographic
  perf [on|off|build-toggle|status]   CPU performance mode control
  ccache-stats | ccache-zero
  doctor                     health + isolation check (all worktrees)
EOF
}

cmd="${1:-help}"
shift || true
case "$cmd" in
help | --help | -h) usage ;;
stats) cmd_stats "$@" ;;
report)
  # reads the machine-global build log; no checkout needed (like stats). The
  # gnuplot template comes from QGIS_DEV_REPORT_GNUPLOT (store path) when set.
  cmd_report "$@"
  ;;
perf)
  # deliberately no init — perf mode is host-level and works outside a checkout
  cmd_perf "$@"
  ;;
configure)
  init
  cmd_configure "$@"
  ;;
build)
  init
  cmd_build "$@"
  ;;
clean)
  init
  note "cleaning $BUILD"
  ninja -C "$BUILD" clean
  ;;
relink)
  init
  cmd_relink
  ;;
debugprep)
  init
  cmd_debugprep
  ;;
run)
  init
  cmd_run "$@"
  ;;
designer)
  init
  cmd_designer "$@"
  ;;
test)
  init
  cmd_test "$@"
  ;;
test-file)
  init
  cmd_test_file "$@"
  ;;
docs)
  init
  cmd_docs
  ;;
docs-serve)
  init
  cmd_docs_serve
  ;;
precommit)
  init
  cmd_precommit "$@"
  ;;
tidy)
  init
  cmd_tidy "$@"
  ;;
fmt)
  init
  cmd_fmt "$@"
  ;;
naming)
  init
  cmd_naming "$@"
  ;;
tags)
  init
  cmd_tags
  ;;
flags)
  init
  cmd_flags
  ;;
targets)
  init
  cmd_targets
  ;;
profile)
  init
  cmd_profile "$@"
  ;;
worktree)
  init
  cmd_worktree "$@"
  ;;
qa)
  init
  cmd_qa "$@"
  ;;
ccache-stats)
  command -v ccache >/dev/null || die "ccache not available"
  ccache -s
  ;;
ccache-zero)
  command -v ccache >/dev/null || die "ccache not available"
  ccache -z
  note "ccache statistics zeroed"
  ;;
doctor)
  init
  cmd_doctor
  ;;
*) die "unknown command '$cmd' — see 'qgis-dev help'" ;;
esac
