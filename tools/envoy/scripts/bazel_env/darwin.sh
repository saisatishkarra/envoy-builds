#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

set -x

# Build ubuntu variant for alpine
export ENVOY_BUILD_TOOLS_BASE_FLAVOUR="ubuntu"

# Specify BAZEL_BUILD_EXTRA_OPTIONS
BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS:-""}
read -ra BAZEL_BUILD_EXTRA_OPTIONS <<< "${BAZEL_BUILD_EXTRA_OPTIONS}"

export BAZEL_BUILD_OPTIONS=(
    "--curses=no"
    "--verbose_failures"
    "--//contrib/vcl/source:enabled=false"
    "${BAZEL_BUILD_EXTRA_OPTIONS[@]+"${BAZEL_BUILD_EXTRA_OPTIONS[@]}"}")

# Refer https://docs.bazel.build/versions/main/user-manual.html#flag--compilation_mode
# Stripping is based on compilation mode
export BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE:-"opt"}