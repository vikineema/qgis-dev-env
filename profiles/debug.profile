# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
# shellcheck shell=bash disable=SC2148,SC2034
#
# debug — the default everyday profile (SRS FR-B3/B6): full feature set,
# fast links (mold + split dwarf + gdb-index for quick debugger startup).
CMAKE_ARGS+=(
  -DCMAKE_BUILD_TYPE=Debug
  -DWITH_3D=ON
  -DWITH_PDAL=ON
  -DWITH_QTWEBENGINE=ON
  -DENABLE_TESTS=ON
  -DCMAKE_LINKER_TYPE=MOLD
  -DCMAKE_CXX_FLAGS_DEBUG="-g -gsplit-dwarf"
  -DCMAKE_C_FLAGS_DEBUG="-g -gsplit-dwarf"
  -DCMAKE_EXE_LINKER_FLAGS=-Wl,--gdb-index
  -DCMAKE_SHARED_LINKER_FLAGS=-Wl,--gdb-index
)
