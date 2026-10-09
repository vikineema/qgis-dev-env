#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
#
# bootstrap.sh — overlay the qgis-dev-env sidecar onto a QGIS checkout.
#
#   ./bootstrap.sh [--force] <path-to-qgis-checkout>   install / refresh
#   ./bootstrap.sh --remove <path-to-qgis-checkout>    restore pristine checkout
#
# Idempotent (SRS FR-I2): symlinks overlay files into the checkout and keeps a
# managed block in .git/info/exclude so upstream git never sees them (FR-I3).
# Never modifies a tracked upstream file.
set -euo pipefail

die() {
  printf 'bootstrap: error: %s\n' "$*" >&2
  exit 1
}
note() { printf '▸ %s\n' "$*" >&2; }

SIDECAR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARK_BEGIN="# >>> qgis-dev-env (managed block — do not edit by hand) >>>"
MARK_END="# <<< qgis-dev-env <<<"

# link-name-in-checkout : source-path-in-sidecar
LINKS=(
  ".envrc:overlay/envrc"
  ".nvim.lua:overlay/nvim.lua"
  ".exrc:overlay/exrc"
  ".clangd:overlay/clangd.yaml"
  "pyrightconfig.json:overlay/pyrightconfig.json"
  ".luarc.json:overlay/luarc.json"
  "CMakePresets.json:overlay/CMakePresets.json"
)

# everything upstream git must locally ignore (FR-I3)
EXCLUDES=(
  ".envrc"
  ".nvim.lua"
  ".exrc"
  ".clangd"
  "pyrightconfig.json"
  ".luarc.json"
  "CMakePresets.json"
  "CMakeUserPresets.json" # CMake's own personal-override file, never ours
  "CMakeLists.txt.user" # Qt Creator per-project IDE state (FR-K3)
  "CMakeLists.txt.user.*"
  "SRS-qgis-dev-env.md" # legacy symlink from pre-0.2 bootstraps
  "PROMPT.log"
  ".dev-env/"
  ".direnv/"
  ".claude/"
  ".cache/" # clangd background index (.cache/clangd), pyright, etc.
  "result"
  "*.pre-qgis-dev-env"
  "qgis-dev-env/" # the sidecar itself, embedded in the checkout (not a submodule)
)

MODE=install
FORCE=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
  --remove) MODE=remove ;;
  --force) FORCE=1 ;;
  -h | --help)
    sed -n '5,12p' "${BASH_SOURCE[0]}"
    exit 0
    ;;
  *) TARGET="$arg" ;;
  esac
done
[[ -n "$TARGET" ]] || die "usage: bootstrap.sh [--remove|--force] <path-to-qgis-checkout>"
TARGET="$(readlink -f "$TARGET")"
[[ -f "$TARGET/CMakeLists.txt" && -d "$TARGET/src/core" ]] ||
  die "'$TARGET' does not look like a QGIS checkout"
git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 || die "'$TARGET' is not a git repository"
COMMON="$(cd "$TARGET" && readlink -f "$(git rev-parse --git-common-dir)")"

write_exclude_block() { # $1 = install|remove
  local file="$COMMON/info/exclude" tmp
  mkdir -p "$COMMON/info"
  touch "$file"
  tmp="$(mktemp)"
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }' "$file" >"$tmp"
  if [[ "$1" == install ]]; then
    {
      echo "$MARK_BEGIN"
      printf '%s\n' "${EXCLUDES[@]}"
      echo "$MARK_END"
    } >>"$tmp"
  fi
  mv "$tmp" "$file"
}

install_links() {
  local spec name src dst linksrc
  for spec in "${LINKS[@]}"; do
    name="${spec%%:*}"
    src="$SIDECAR/${spec#*:}"
    dst="$TARGET/$name"
    [[ -e "$src" ]] || die "sidecar file missing: $src"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      if [[ "$FORCE" -eq 1 ]]; then
        mv "$dst" "$dst.pre-qgis-dev-env"
        note "backed up existing $name → $name.pre-qgis-dev-env"
      else
        die "refusing to overwrite existing $dst (inspect it, then re-run with --force)"
      fi
    fi
    # Embedded sidecar (inside the checkout): relative links, so the whole
    # tree can be moved as one unit. External sidecar: absolute links.
    if [[ "$SIDECAR" == "$TARGET"/* ]]; then
      linksrc="$(realpath --relative-to="$TARGET" "$src")"
    else
      linksrc="$src"
    fi
    ln -sfn "$linksrc" "$dst"
  done
}

remove_links() {
  local spec name dst
  for spec in "${LINKS[@]}"; do
    name="${spec%%:*}"
    dst="$TARGET/$name"
    if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$SIDECAR"* ]]; then
      rm -f "$dst"
    fi
    if [[ -e "$dst.pre-qgis-dev-env" ]]; then
      mv "$dst.pre-qgis-dev-env" "$dst"
      note "restored original $name"
    fi
  done
}

install_hooks() {
  local hooks="$COMMON/hooks" guard="$SIDECAR/overlay/hooks/pre-push"
  mkdir -p "$hooks"
  if [[ -e "$hooks/pre-push" && ! -L "$hooks/pre-push" ]]; then
    note "existing pre-push hook found — anti-leak guard NOT installed (chain it manually, see README)"
  else
    ln -sfn "$guard" "$hooks/pre-push"
  fi
  if command -v pre-commit >/dev/null 2>&1; then
    if (cd "$TARGET" && pre-commit install >/dev/null); then
      note "pre-commit hooks installed"
    else
      note "pre-commit install failed — run it manually inside the devshell"
    fi
  else
    note "pre-commit not on PATH yet — run 'pre-commit install' once inside the devshell (doctor will remind you)"
  fi
}

remove_hooks() {
  local hooks="$COMMON/hooks"
  if [[ -L "$hooks/pre-push" ]] && [[ "$(readlink -f "$hooks/pre-push")" == "$SIDECAR"* ]]; then
    rm -f "$hooks/pre-push"
  fi
}

case "$MODE" in
install)
  note "overlaying qgis-dev-env ($SIDECAR)"
  note "onto QGIS checkout        ($TARGET)"
  write_exclude_block install
  install_links
  install_hooks
  mkdir -p "$TARGET/.dev-env"
  printf '%s\n' "$SIDECAR" >"$TARGET/.dev-env/sidecar"
  touch "$TARGET/PROMPT.log"
  git -C "$TARGET" config blame.ignoreRevsFile .git-blame-ignore-revs
  # Verify isolation immediately (FR-I4)
  if git -C "$TARGET" status --porcelain | grep -qE '\.envrc|\.nvim\.lua|\.exrc|\.clangd|pyrightconfig|\.luarc|CMakePresets\.json|PROMPT\.log|\.dev-env|qgis-dev-env'; then
    die "overlay files are visible to git — isolation FAILED, investigate before continuing"
  fi
  note "done. Next: cd '$TARGET' && direnv allow   (then 'qgis-dev build' or <leader>pb in Neovim)"
  ;;
remove)
  note "removing qgis-dev-env overlay from $TARGET"
  keep="${XDG_STATE_HOME:-$HOME/.local/state}/qgis-dev-env/removed-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$keep"
  [[ -s "$TARGET/PROMPT.log" ]] && mv "$TARGET/PROMPT.log" "$keep/PROMPT.log"
  rm -f "$TARGET/PROMPT.log"
  [[ -d "$TARGET/.dev-env" ]] && mv "$TARGET/.dev-env" "$keep/dev-env"
  remove_links
  remove_hooks
  write_exclude_block remove
  git -C "$TARGET" config --unset blame.ignoreRevsFile 2>/dev/null || true
  note "prompt log and state preserved in $keep"
  note "checkout restored — 'git status' should be pristine"
  ;;
esac
