# SPDX-FileCopyrightText: 2026 Kartoza (Pty) Ltd <tim@kartoza.com>
# SPDX-License-Identifier: MIT
# shellcheck shell=bash disable=SC2148,SC2034
#
# asan-ubsan — AddressSanitizer + UndefinedBehaviorSanitizer (SRS FR-G3).
# The default tool for memory bugs: ~2x slowdown vs valgrind's 20-50x.
# 3D/WebEngine off to keep instrumented rebuilds quick. qgis-dev separates
# these objects from other profiles via CCACHE_NAMESPACE.
CMAKE_ARGS+=(
  -DCMAKE_BUILD_TYPE=Debug
  -DWITH_3D=OFF
  -DWITH_PDAL=OFF
  -DWITH_QTWEBENGINE=OFF
  -DENABLE_TESTS=ON
  -DCMAKE_LINKER_TYPE=MOLD
  -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g -UGDAL_DEBUG"
  -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer -g -UGDAL_DEBUG"
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
  -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,undefined"
)
