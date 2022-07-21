#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

set -x

source ${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel_env/init.sh

export BUILD_CMD=${BUILD_CMD:-"bazel build ${BAZEL_BUILD_OPTIONS[@]} -c ${BAZEL_COMPILATION_MODE} ${BUILD_TARGET} "}

export BAZEL_BUILD_OPTIONS=(
    "--curses=no"
    "--verbose_failures"
    "--//contrib/vcl/source:enabled=false"
    "${BAZEL_BUILD_EXTRA_OPTIONS[@]+"${BAZEL_BUILD_EXTRA_OPTIONS[@]}"}")

pushd "${ENVOY_SOURCE_DIR}"
# Append contrib to build_target in build_cmd
#export CONTRIB_ENABLED_ARGS=$(python3 "${CONTRIB_ENABLED_MATRIX_SCRIPT}")
eval $BUILD_CMD
popd