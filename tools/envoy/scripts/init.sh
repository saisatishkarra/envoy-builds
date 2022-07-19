set -o errexit
set -o pipefail
set -o nounset

set -x

echo "Building Envoy for ${DISTRO}" 

# Expose Distro specific Bazel Build Options
source "${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel_env/${DISTRO}.sh"

# Download Envoy proxy upstream into ENVOY_SOURCE_DIR
#ENVOY_SOURCE_DIR="${ENVOY_SOURCE_DIR}" "${ENVOY_BUILD_TOOLS_DIR}/scripts/fetch_sources.sh"

# Download Envoy proxy metadata
ENVOY_BUILD_SHA=$(curl --fail --location --silent https://raw.githubusercontent.com/envoyproxy/envoy/"${ENVOY_TAG}"/.bazelrc | grep envoyproxy/envoy-build-ubuntu | sed -e 's#.*envoyproxy/envoy-build-ubuntu:\(.*\)#\1#'| uniq)
# ENVOY PROXY BUILD TOOLS BASE IMAGE
export ENVOY_BUILD_TOOLS_IMAGE="envoyproxy/envoy-build-${ENVOY_BUILD_TOOLS_BASE_FLAVOUR}:${ENVOY_BUILD_SHA}"
# EXVOY PROXY PRE-SFETCH DEPENDENCY CACHE IMAGE
export ENVOY_BUILD_DEPS_IMAGE="kongcloud/envoy-builds-deps:${ENVOY_VERSION_TRIMMED}"
#ENVOY PROXY IMAGE
# TODO: add .ext if compilation options have extended aspects
export ENVOY_BUILD_IMAGE="${DOCKER_REGISTRY}/envoy-${DISTRO}-${GOARCH}-${BAZEL_COMPILATION_MODE}:${ENVOY_VERSION_TRIMMED}"


# Construct Contrib flags
CONTRIB_ENABLED_MATRIX_SCRIPT=$(realpath "${ENVOY_BUILD_TOOLS_DIR}/util/contrib_enabled_matrix.py")
pushd "${ENVOY_SOURCE_DIR}"
export CONTRIB_ENABLED_ARGS=$(python3 "${CONTRIB_ENABLED_MATRIX_SCRIPT}")
popd

# Specify build target
export BUILD_TARGET=${BUILD_TARGET:-"//contrib/exe:envoy-static"}

# Specify BuildX options
DOCKER_BUILD_EXTRA_OPTIONS=${DOCKER_BUILD_EXTRA_OPTIONS:-""}
read -ra DOCKER_BUILD_EXTRA_OPTIONS <<< "${DOCKER_BUILD_EXTRA_OPTIONS}"
export DOCKER_BUILD_EXTRA_OPTIONS=("${DOCKER_BUILD_EXTRA_OPTIONS[@]+"${DOCKER_BUILD_EXTRA_OPTIONS[@]}"}")

# Dockerfile
export DOCKERFILE="${ENVOY_BUILD_TOOLS_DIR}/Dockerfile"

# Bazel build command
export BUILD_CMD=${BUILD_CMD:-"bazel build ${BAZEL_BUILD_OPTIONS[@]} -c ${BAZEL_COMPILATION_MODE} ${BUILD_TARGET} ${CONTRIB_ENABLED_ARGS}"}


echo "DOCKER_BUILD_EXTRA_OPTIONS:${DOCKER_BUILD_EXTRA_OPTIONS[@]}"
echo "BAZEL_BUILD_CMD=${BUILD_CMD}"
