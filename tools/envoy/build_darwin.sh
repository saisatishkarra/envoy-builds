#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

set -x

echo "Building Envoy for Darwin"

OUT_DIR="$(dirname "${BINARY_PATH}")"
mkdir -p "${OUT_DIR}"

SOURCE_DIR="${SOURCE_DIR}" "${WORK_DIR:-.}/tools/envoy/fetch_sources.sh"
CONTRIB_ENABLED_MATRIX_SCRIPT=$(realpath "${WORK_DIR:-.}/tools/envoy/contrib_enabled_matrix.py")

# Refer https://docs.bazel.build/versions/main/user-manual.html#flag--compilation_mode
# Stripping is based on compilation mode
BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE:-"opt"}
BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS:-""}
read -ra BAZEL_BUILD_EXTRA_OPTIONS <<< "${BAZEL_BUILD_EXTRA_OPTIONS}"
BAZEL_BUILD_OPTIONS=(
    "--curses=no"
    "--show_task_finish"
    "--verbose_failures"
    "--//contrib/vcl/source:enabled=false"
    "${BAZEL_BUILD_EXTRA_OPTIONS[@]+"${BAZEL_BUILD_EXTRA_OPTIONS[@]}"}")
BUILD_TARGET=${BUILD_TARGET:-"//contrib/exe:envoy-static"}

pushd "${SOURCE_DIR}"
CONTRIB_ENABLED_ARGS=$(python "${CONTRIB_ENABLED_MATRIX_SCRIPT}")
BUILD_CMD=${BUILD_CMD:-"bazel build ${BAZEL_BUILD_OPTIONS[@]} -c ${BAZEL_COMPILATION_MODE} ${BUILD_TARGET} ${CONTRIB_ENABLED_ARGS}"}

echo "SOURCE_DIR=${SOURCE_DIR}"
echo "OUT_DIR=${OUT_DIR}"
echo "BINARY_PATH=${BINARY_PATH}"
echo "BAZEL_OPTONS:${BAZEL_BUILD_OPTIONS[@]}"
echo "BAZEL_BUILD_CMD=${BUILD_CMD}"
eval "$BUILD_CMD"
popd
# shellcheck disable=SC2086


cp "${SOURCE_DIR}"/bazel-bin/contrib/exe/envoy-static "${BINARY_PATH}"
cp /tmp/profile.gz "${OUT_DIR}/profile.gz"