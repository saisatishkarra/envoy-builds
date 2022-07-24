#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

set -x

## Needs envoy to be checked out

source ${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel_env/init.sh

BAZEL_BUILD_OPTIONS=(
    "--config=clang"
    "--verbose_failures"
    "${BAZEL_BUILD_EXTRA_OPTIONS[@]+"${BAZEL_BUILD_EXTRA_OPTIONS[@]}"}")

pushd "${ENVOY_SOURCE_DIR}"
# Append contrib to build_target in build_cmd
CONTRIB_ENABLED_ARGS=$(python3 "${CONTRIB_ENABLED_MATRIX_SCRIPT}")
# Bazel build commandl Fix and Append: ${CONTRIB_ENABLED_ARGS}
BUILD_CMD=${BUILD_CMD:-"bazel build ${BAZEL_BUILD_OPTIONS[@]} -c ${BAZEL_COMPILATION_MODE} ${BUILD_TARGET} ${CONTRIB_ENABLED_ARGS}"}
echo "Build cmd: $BUILD_CMD"
eval $BUILD_CMD
popd