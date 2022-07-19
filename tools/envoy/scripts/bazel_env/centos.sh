#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

set -x

export ENVOY_BUILD_TOOLS_BASE_FLAVOUR=$DISTRO

BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS:-""}
read -ra BAZEL_BUILD_EXTRA_OPTIONS <<< "${BAZEL_BUILD_EXTRA_OPTIONS}"

export BAZEL_BUILD_OPTIONS=(
    "--config=libc++"
    "--verbose_failures"
    "${BAZEL_BUILD_EXTRA_OPTIONS[@]+"${BAZEL_BUILD_EXTRA_OPTIONS[@]}"}")

# Refer https://docs.bazel.build/versions/main/user-manual.html#flag--compilation_mode
# Stripping is based on compilation mode
export BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE:-"opt"}