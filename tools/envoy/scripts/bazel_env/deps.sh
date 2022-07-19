#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -x


SOURCE_DIR="${SOURCE_DIR}" "${WORK_DIR:-.}/tools/envoy/fetch_sources.sh"

BAZEL_STARTUP_OPTIONS=(
  "--output_base=${OUT_DIR}"
)

BAZEL_BUILD_OPTIONS=(
  "--experimental_repository_resolved_file=${OUT_DIR}/resolved.bzl"
)

BUILD_CMD="bazel ${BAZEL_STARTUP_OPTIONS[@]} sync ${BAZEL_BUILD_OPTIONS[@]}"

ENVOY_BUILD_SHA=$(curl --fail --location --silent https://raw.githubusercontent.com/envoyproxy/envoy/"${ENVOY_TAG}"/.bazelrc | grep envoyproxy/envoy-build-ubuntu | sed -e 's#.*envoyproxy/envoy-build-ubuntu:\(.*\)#\1#'| uniq)
ENVOY_BUILD_IMAGE="envoyproxy/envoy-build-ubuntu:${ENVOY_BUILD_SHA}"
LOCAL_BUILD_IMAGE="kong/envoy-builds-deps:${ENVOY_TAG}"

echo "SOURCE_DIR=${SOURCE_DIR}"
echo "OUT_DIR=${OUT_DIR}"
echo "BAZEL_OPTIONS:${BAZEL_BUILD_OPTIONS[@]}"
echo "BAZEL_BUILD_CMD=${BUILD_CMD}"

docker build \
  -t "${LOCAL_BUILD_IMAGE}" \
  --progress=plain \
  --build-arg BUILD_CMD="${BUILD_CMD}" \
  --build-arg ENVOY_BUILD_IMAGE="${ENVOY_BUILD_IMAGE}" \
  -f "${WORK_DIR:-.}/tools/envoy/Dockerfile.build-deps" "${SOURCE_DIR}"

docker image inspect "${LOCAL_BUILD_IMAGE}"

# # copy out the binary
# id=$(docker create "${LOCAL_BUILD_IMAGE}")
# docker cp "$id":/envoy-sources/bazel-bin/contrib/exe/envoy-static "${BINARY_PATH}"
# docker cp "$id":/tmp/profile.gz "${OUT_DIR}/profile.gz"
# docker rm -v "$id"
