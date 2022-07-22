#!/bin/bash

# This script fetches Envoy source code to $SOURCE_DIR
#
# Requires:
# - $SOURCE_DIR, a directory where sources will be placed
# - $ENVOY_TAG, git tag to reference specific revision

set -o errexit
set -o pipefail
set -o nounset

echo $ENVOY_SOURCE_DIR
# clone Envoy repo if not exists
if [[ ! -d "${ENVOY_SOURCE_DIR}" ]]; then
  mkdir -p "${ENVOY_SOURCE_DIR}"
  (
    cd "${ENVOY_SOURCE_DIR}"
    git init .
    git remote add origin https://github.com/envoyproxy/envoy.git
  )
else
  echo "Envoy source directory already exists, just fetching"
  pushd "${ENVOY_SOURCE_DIR}" && git fetch --all && popd
fi

pushd "${ENVOY_SOURCE_DIR}"

git fetch origin --depth=1 "${ENVOY_TAG}"
git reset --hard FETCH_HEAD
rm -f .dockerignore
echo "ENVOY_TAG=${ENVOY_TAG}"

popd
