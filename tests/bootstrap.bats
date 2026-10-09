#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
#
# Tests for bootstrap idempotency, isolation and the anti-leak guard
# (SRS FR-T1, verifying FR-I2..I6). Uses a minimal QGIS-shaped fixture.

setup() {
  TDIR="$(mktemp -d)"
  export TDIR
  SIDECAR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SIDECAR
  export XDG_STATE_HOME="$TDIR/state"
  QGIS="$TDIR/QGIS"
  export QGIS
  mkdir -p "$QGIS/src/core"
  echo "project(qgis)" >"$QGIS/CMakeLists.txt"
  git -C "$QGIS" init -q -b master
  git -C "$QGIS" -c user.email=t@t -c user.name=t add -A
  git -C "$QGIS" -c user.email=t@t -c user.name=t commit -qm init
}

teardown() {
  rm -rf "$TDIR"
}

@test "bootstrap links the overlay and git status stays clean" {
  run "$SIDECAR/bootstrap.sh" "$QGIS"
  [ "$status" -eq 0 ]
  [ -L "$QGIS/.envrc" ]
  [ -L "$QGIS/.nvim.lua" ]
  [ -L "$QGIS/.clangd" ]
  [ -L "$QGIS/pyrightconfig.json" ]
  [ -L "$QGIS/CMakePresets.json" ]
  [ -f "$QGIS/PROMPT.log" ]
  [ -f "$QGIS/.dev-env/sidecar" ]
  run git -C "$QGIS" status --porcelain
  [ -z "$output" ]
}

@test "bootstrap is idempotent — exactly one managed exclude block" {
  "$SIDECAR/bootstrap.sh" "$QGIS"
  "$SIDECAR/bootstrap.sh" "$QGIS"
  count="$(grep -c '>>> qgis-dev-env' "$QGIS/.git/info/exclude")"
  [ "$count" -eq 1 ]
}

@test "bootstrap refuses to clobber an existing user file without --force" {
  echo "precious" >"$QGIS/.envrc"
  run "$SIDECAR/bootstrap.sh" "$QGIS"
  [ "$status" -ne 0 ]
  [ "$(cat "$QGIS/.envrc")" = "precious" ]
  run "$SIDECAR/bootstrap.sh" --force "$QGIS"
  [ "$status" -eq 0 ]
  [ -L "$QGIS/.envrc" ]
  [ "$(cat "$QGIS/.envrc.pre-qgis-dev-env")" = "precious" ]
}

@test "remove restores a pristine checkout and preserves PROMPT.log" {
  "$SIDECAR/bootstrap.sh" "$QGIS"
  echo "a prompt" >>"$QGIS/PROMPT.log"
  run "$SIDECAR/bootstrap.sh" --remove "$QGIS"
  [ "$status" -eq 0 ]
  [ ! -e "$QGIS/.envrc" ]
  [ ! -e "$QGIS/.nvim.lua" ]
  [ ! -e "$QGIS/PROMPT.log" ]
  [ ! -e "$QGIS/.dev-env" ]
  ! grep -q 'qgis-dev-env' "$QGIS/.git/info/exclude"
  run git -C "$QGIS" status --porcelain
  [ -z "$output" ]
  # prompt archive preserved outside the checkout
  found="$(find "$XDG_STATE_HOME/qgis-dev-env" -name PROMPT.log | head -1)"
  grep -q "a prompt" "$found"
}

@test "pre-push guard blocks a forced overlay leak" {
  "$SIDECAR/bootstrap.sh" "$QGIS"
  git init -q --bare "$TDIR/remote.git"
  git -C "$QGIS" remote add origin "$TDIR/remote.git"
  git -C "$QGIS" add -f .envrc
  git -C "$QGIS" -c user.email=t@t -c user.name=t commit -qm "leak attempt"
  run git -C "$QGIS" push origin master
  [ "$status" -ne 0 ]
  [[ "$output" == *BLOCKED* ]]
}

@test "pre-push guard allows a clean push" {
  "$SIDECAR/bootstrap.sh" "$QGIS"
  git init -q --bare "$TDIR/remote.git"
  git -C "$QGIS" remote add origin "$TDIR/remote.git"
  echo "// fix" >>"$QGIS/CMakeLists.txt"
  git -C "$QGIS" add CMakeLists.txt
  git -C "$QGIS" -c user.email=t@t -c user.name=t commit -qm "legit change"
  run git -C "$QGIS" push origin master
  [ "$status" -eq 0 ]
}

@test "doctor detects a planted isolation leak" {
  "$SIDECAR/bootstrap.sh" "$QGIS"
  git -C "$QGIS" add -f .nvim.lua
  run env QGIS_DEV_SIDECAR="$SIDECAR" bash -c "cd '$QGIS' && bash '$SIDECAR/lib/tasks.sh' doctor"
  [ "$status" -ne 0 ]
  [[ "$output" == *VISIBLE* ]]
}

@test "embedded sidecar gets relative symlinks and stays invisible to git" {
  cp -r "$SIDECAR" "$QGIS/qgis-dev-env"
  rm -rf "$QGIS/qgis-dev-env/.git"
  run "$QGIS/qgis-dev-env/bootstrap.sh" "$QGIS"
  [ "$status" -eq 0 ]
  target="$(readlink "$QGIS/.envrc")"
  [ "${target:0:1}" != "/" ]
  [ "$target" = "qgis-dev-env/overlay/envrc" ]
  run git -C "$QGIS" status --porcelain
  [ -z "$output" ]
}

@test "doctor passes isolation checks on a clean bootstrap" {
  "$SIDECAR/bootstrap.sh" "$QGIS"
  run env QGIS_DEV_SIDECAR="$SIDECAR" bash -c "cd '$QGIS' && bash '$SIDECAR/lib/tasks.sh' doctor"
  [[ "$output" == *"isolation intact"* ]]
  [[ "$output" != *VISIBLE* ]]
}
