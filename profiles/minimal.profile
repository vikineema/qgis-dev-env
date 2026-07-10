# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
# shellcheck shell=bash disable=SC2148,SC2034
#
# minimal — fastest possible iteration on core C++ (SRS FR-B6): 3D,
# WebEngine, PDAL, tests and Python bindings all off. Not for PyQGIS work.
CMAKE_ARGS+=(
  -DCMAKE_BUILD_TYPE=Debug
  -DWITH_3D=OFF
  -DWITH_PDAL=OFF
  -DWITH_QTWEBENGINE=OFF
  -DWITH_BINDINGS=OFF
  -DENABLE_TESTS=OFF
  -DCMAKE_LINKER_TYPE=MOLD
  -DCMAKE_CXX_FLAGS_DEBUG="-g -gsplit-dwarf -UGDAL_DEBUG"
  -DCMAKE_C_FLAGS_DEBUG="-g -gsplit-dwarf -UGDAL_DEBUG"
  -DCMAKE_EXE_LINKER_FLAGS=-Wl,--gdb-index
  -DCMAKE_SHARED_LINKER_FLAGS=-Wl,--gdb-index
)
