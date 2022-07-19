#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

set -x

source ${ENVOY_BUILD_TOOLS_DIR}/scripts/init.sh

# Make Output Binary path
OUT_DIR=$(dirname "${BINARY_PATH}")
mkdir -p "${OUT_DIR}"

# docker buildx bazel external deps
# Populate external preeftch depedency cache only from CI using $ENVOY_BUILD_DEPS_IMAGE
# Local builds should use remote cache if exists

# TODO: Add if-else for darwin and other distros to build locally vs docker. Hopefully docker image works
# pushd "${ENVOY_SOURCE_DIR}"
# eval "$BUILD_CMD"
#cp "./bazel-bin/contrib/exe/envoy-static "${BINARY_PATH}"
#cp /tmp/profile.gz "${OUT_DIR}/profile.gz"
# popd

# Initiate buildx builder
docker buildx create --name envoy-builder --use

# docker buildx 
docker buildx build "${DOCKER_BUILD_EXTRA_OPTIONS[@]}" \
  --tag "${LOCAL_BUILD_IMAGE}" \
  --cache-from="type=registry,ref=kongcloud/envoy-builds-deps:${ENVOY_VERSION_TRIMMED}" \
  --cache-to="type=local,dest=/tmp/.buildx-cache,mode=max" \
  --progress=plain \
  --build-arg BUILD_TARGET="${BUILD_TARGET}" \
  --build-arg BUILD_CMD="${BUILD_CMD}" \
  --build-arg ENVOY_BUILD_IMAGE="${ENVOY_BUILD_IMAGE}" \
  --push=false \
  --file "${DOCKERFILE}" "${ENVOY_SOURCE_DIR}"
  

docker image inspect "${LOCAL_BUILD_IMAGE}"

# copy out the binary
id=$(docker create "${LOCAL_BUILD_IMAGE}")
docker cp "$id":/envoy-sources/bazel-bin/contrib/exe/envoy-static "${BINARY_PATH}"
docker cp "$id":/tmp/profile.gz "${OUT_DIR}/profile.gz"
docker rm -v "$id"
