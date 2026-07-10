# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
# shellcheck shell=bash disable=SC2148,SC2034,SC2054
#
# release — optimised build with symbols, for performance work and
# profiling sessions where Debug timings would mislead (SRS FR-B6).
CMAKE_ARGS+=(
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DWITH_3D=ON
  -DWITH_PDAL=ON
  -DWITH_QTWEBENGINE=ON
  -DENABLE_TESTS=ON
  -DCMAKE_LINKER_TYPE=MOLD
)
