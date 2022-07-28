#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

set -x

# Expose Distro specific Bazel Build Options
#source "${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel_env/${DISTRO}.sh"

export BUILD_TARGET=${BUILD_TARGET:-"//contrib/exe:envoy-static"}

export CONTRIB_ENABLED_MATRIX_SCRIPT="${ENVOY_BUILD_TOOLS_DIR}/util/extensions.py"

# Refer https://docs.bazel.build/versions/main/user-manual.html#flag--compilation_mode
# Stripping is based on compilation mode
export BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE:-"opt"}

# # Specify BAZEL_BUILD_EXTRA_OPTIONS
export BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS:-""}
# read -ra BAZEL_BUILD_EXTRA_OPTIONS <<< "${BAZEL_BUILD_EXTRA_OPTIONS}"

# echo "BAZEL_BUILD_EXTRA_OPTIONS: ${BAZEL_BUILD_EXTRA_OPTIONS}"
