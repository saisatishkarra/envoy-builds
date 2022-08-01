#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

source ${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel/init.sh

BAZEL_STARTUP_OPTIONS=(
  "--output_base=${BAZEL_DEPS_BASE_DIR}"
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
echo "Bazel Dependencies output: ${BAZEL_DEPS_BASE_DIR}"