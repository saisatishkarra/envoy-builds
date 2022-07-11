#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -x

echo "Building Envoy for CentOS 7"

mkdir -p "$(dirname "${BINARY_PATH}")"

SOURCE_DIR="${SOURCE_DIR}" "${WORK_DIR:-.}/tools/envoy/fetch_sources.sh"
CONTRIB_ENABLED_MATRIX_SCRIPT=$(realpath "${WORK_DIR:-.}/tools/envoy/contrib_enabled_matrix.py")

# Refer https://docs.bazel.build/versions/main/user-manual.html#flag--compilation_mode
# Stripping is based on compilation mode
BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE:-"opt"}
BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS:-""}
read -ra BAZEL_BUILD_EXTRA_OPTIONS <<< "${BAZEL_BUILD_EXTRA_OPTIONS}"
BAZEL_BUILD_OPTIONS=(
    "--config=libc++"
    "--verbose_failures"
    "${BAZEL_BUILD_EXTRA_OPTIONS[@]+"${BAZEL_BUILD_EXTRA_OPTIONS[@]}"}")
BUILD_TARGET=${BUILD_TARGET:-"//contrib/exe:envoy-static"}

pushd "${SOURCE_DIR}"
CONTRIB_ENABLED_ARGS=$(python "${CONTRIB_ENABLED_MATRIX_SCRIPT}")
popd

BUILD_CMD=${BUILD_CMD:-"bazel build ${BAZEL_BUILD_OPTIONS[@]} -c ${BAZEL_COMPILATION_MODE} ${BUILD_TARGET} ${CONTRIB_ENABLED_ARGS} --//source/extensions/transport_sockets/tcp_stats:enabled=false"}

ENVOY_BUILD_SHA=$(curl --fail --location --silent https://raw.githubusercontent.com/envoyproxy/envoy/"${ENVOY_TAG}"/.bazelrc | grep envoyproxy/envoy-build-ubuntu | sed -e 's#.*envoyproxy/envoy-build-ubuntu:\(.*\)#\1#'| uniq)
ENVOY_BUILD_IMAGE="envoyproxy/envoy-build-centos:${ENVOY_BUILD_SHA}"
LOCAL_BUILD_IMAGE="envoy-builder:${ENVOY_TAG}"

DOCKER_BUILD_EXTRA_OPTIONS=${DOCKER_BUILD_EXTRA_OPTIONS:-""}
read -ra DOCKER_BUILD_EXTRA_OPTIONS <<< "${DOCKER_BUILD_EXTRA_OPTIONS}"
DOCKER_BUILD_OPTIONS=(
  "${DOCKER_BUILD_EXTRA_OPTIONS[@]+"${DOCKER_BUILD_EXTRA_OPTIONS[@]}"}"
)

echo "SOURCE_DIR=${SOURCE_DIR}"
echo "BINARY_PATH=${BINARY_PATH}"
echo "BAZEL_OPTIONS:${BAZEL_BUILD_OPTIONS[@]}"
echo "BAZEL_BUILD_CMD=${BUILD_CMD}"
echo "DOCKER_BUILD_OPTIONS:${DOCKER_BUILD_OPTIONS[@]}"

docker build "${DOCKER_BUILD_EXTRA_OPTIONS[@]}" \
  -t "${LOCAL_BUILD_IMAGE}" \
  --progress=plain \
  --build-arg BUILD_CMD="${BUILD_CMD}" \
  --build-arg ENVOY_BUILD_IMAGE="${ENVOY_BUILD_IMAGE}" \
  -f "${WORK_DIR:-.}/tools/envoy/Dockerfile.build-centos" "${SOURCE_DIR}"

docker image inspect "${LOCAL_BUILD_IMAGE}"

# copy out the binary
id=$(docker create "${LOCAL_BUILD_IMAGE}")
docker cp "$id":/envoy-sources/bazel-bin/contrib/exe/envoy-static "${BINARY_PATH}"
docker rm -v "$id"
