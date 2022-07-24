#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -x

source ${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel/init.sh

BAZEL_STARTUP_OPTIONS=(
  "--output_base=${ENVOY_BAZEL_OUTPUT_BASE_DIR}"
)

# Append ${BAZEL_BUILD_OPTIONS[@]} change command to "sync" for all deps
# BAZEL_BUILD_OPTIONS=(
#   "--experimental_repository_resolved_file=${BAZEL_DEPS_BASE}/resolved.bzl"
# )

BUILD_CMD="bazel ${BAZEL_STARTUP_OPTIONS[@]} fetch ${BUILD_TARGET}"

pushd "${ENVOY_SOURCE_DIR}"
eval $BUILD_CMD
popd

echo "Envoy fetched external dependencies: "
echo "Bazel output: ${ENVOY_BAZEL_OUTPUT_BASE_DIR}"