SUPPORTED_OS:= linux darwin windows
SUPPORTED_LINUX_DISTROS:= alpine centos

ifndef TARGETOS
	$(error TARGETOS is required)
endif

ifndef TARGETARCH
	$(error TARGETARCH is required)
endif

ifndef ENVOY_TAG
	$(error ENVOY_TAG (vX.Y.Z) is required)
endif

ifneq ($(TARGETOS), $(filter $(TARGETOS), $(SUPPORTED_OS)))
	$(error TARGETOS must be one of $(SUPPORTED_OS)) 
endif
		
ifeq ($(TARGETOS), linux)
	ifndef DISTRO
		$(error DISTRO is required. One of:$(SUPPORTED_LINUX_DISTROS))
	endif
	ifeq ($(DISTRO), $(filter $(DISTRO),$(SUPPORTED_LINUX_DISTROS)))
		ifeq ($(DISTRO), alpine)
			ENVOY_BUILD_TOOLS_BASE_FLAVOUR=ubuntu
		else
			ENVOY_BUILD_TOOLS_BASE_FLAVOUR=centos
		endif
	endif
else
	DISTRO=$(TARGETOS)
	ENVOY_BUILD_TOOLS_BASE_FLAVOUR=$(TARGETOS)
endif

WORK_DIR?= $(shell pwd)
# Envoy buils tools image is not provided for darwin. Needs to be overriden for darwin
ENVOY_BUILD_TOOLS_IMAGE?=envoyproxy/envoy-build-${ENVOY_BUILD_TOOLS_BASE_FLAVOUR}
ENVOY_BUILD_TOOLS_DIR?=${WORK_DIR}/tools/envoy
VERSION_CMD="curl --fail --location --silent https://raw.githubusercontent.com/envoyproxy/envoy/$(ENVOY_TAG)/.bazelrc | grep envoyproxy/envoy-build-ubuntu | sed -e 's\#.*envoyproxy/envoy-build-ubuntu:\(.*\)\#\1\#' | uniq"
ENVOY_BUILD_TOOLS_TAG=$(shell eval ${VERSION_CMD})
ENVOY_VERSION_TRIMMED=$(shell $(ENVOY_BUILD_TOOLS_DIR)/scripts/version.sh ${ENVOY_TAG})
BUILD_ENVOY_FROM_SOURCES?=false
ifndef TMPDIR
	ENVOY_SOURCE_DIR=/tmp/envoy
else
	ENVOY_SOURCE_DIR=${TMPDIR}envoy
endif

REGISTRY?=local
REPO?=envoy-builds
IMAGENAME=$(REGISTRY)/$(REPO) 
IMAGE=$(REGISTRY)/$(REPO):${ENVOY_VERSION_TRIMMED}-${TARGETOS}-${TARGETARCH}

# DOCKER_BUILD_EXTRA_OPTIONS=${DOCKER_BUILD_EXTRA_OPTIONS:-""}
# read -ra DOCKER_BUILD_EXTRA_OPTIONS <<< "${DOCKER_BUILD_EXTRA_OPTIONS}"
# export DOCKER_BUILD_EXTRA_OPTIONS=("${DOCKER_BUILD_EXTRA_OPTIONS[@]+"${DOCKER_BUILD_EXTRA_OPTIONS[@]}"}")


#BUILD_ENVOY_DEPS_SCRIPT:=$(WORK_DIR)/tools/envoy/build_deps.sh


# Target 'build/envoy' allows to put Envoy binary under the build/artifacts-$TARGETOS-$TARGETARCH/envoy directory.
# Depending on the flag BUILD_ENVOY_FROM_SOURCES this target either fetches Envoy from binary registry or
# builds from sources. It's possible to build binaries for darwin, linux and centos by specifying TARGETOS
# and ENVOY_DISTRO variables. Envoy version could be specified by ENVOY_TAG that accepts git tag or commit
# hash values.

.PHONY: inspect
inspect:
	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
	ENVOY_SOURCE_DIR=$(ENVOY_SOURCE_DIR) \
	BUILD_ENVOY_FROM_SOURCES=$(BUILD_ENVOY_FROM_SOURCES) \
	ENVOY_TAG="${ENVOY_TAG}" \
	ENVOY_VERSION_TRIMMED=$(ENVOY_VERSION_TRIMMED) \
	DISTRO=$(DISTRO) \
	FLAVOUR=$(FLAVOUR) \
	DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	$(ENVOY_BUILD_TOOLS_DIR)/scripts/inspect.sh

.PHONY: clone
clone:
	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
	ENVOY_SOURCE_DIR="${ENVOY_SOURCE_DIR}" \
	ENVOY_TAG="${ENVOY_TAG}" \
	"${ENVOY_BUILD_TOOLS_DIR}/scripts/clone.sh"

# .PHONY: init
# init: clone 
# 	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
# 	ENVOY_SOURCE_DIR="${ENVOY_SOURCE_DIR}" \
# 	"${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel/init.sh"

.PHONY: fetch_envoy_deps
fetch_envoy_deps: clone
	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
	ENVOY_SOURCE_DIR=${ENVOY_SOURCE_DIR} \
	ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output \
	${ENVOY_BUILD_TOOLS_DIR}/scripts/bazel/prefetch.sh

.PHONY: clean_envoy
clean_envoy: ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output
clean_envoy:
	ENVOY_SOURCE_DIR=$(ENVOY_SOURCE_DIR) \
	rm -rf ${ENVOY_SOURCE_DIR}
	rm -rf build/envoy
	rm -rf ${ENVOY_BAZEL_OUTPUT_BASE_DIR}
	docker system prune

.PHONY: envoy_image

# Figure out a way to pass DOCKER_BUILD_EXTRA_OPTIONS to buildkit
# --add-host # network #s3 cache container
# Figure out a way to pass BAZEL_COMPILATION_MODE to buildkit
# Figure out a way to pass BAZEL_COMPILATION_MODE to buildkit
# BAZEL_BUILD_EXTRA_OPTIONS

envoy_image:
	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
	ENVOY_SOURCE_DIR="${ENVOY_SOURCE_DIR}" \
	ENVOY_BUILD_TOOLS_TAG="${ENVOY_BUILD_TOOLS_TAG}" \
	ENVOY_BUILD_TOOLS_IMAGE="${ENVOY_BUILD_TOOLS_IMAGE}" \
	ENVOY_VERSION_TRIMMED="${ENVOY_VERSION_TRIMMED}" \
	ENVOY_TAG="${ENVOY_TAG}" \
	docker buildx build \
		-f Dockerfile \
		--build-arg ENVOY_BUILD_TOOLS_DIR=${ENVOY_BUILD_TOOLS_DIR} \
		--build-arg ENVOY_SOURCE_DIR=${ENVOY_SOURCE_DIR} \
		--build-arg ENVOY_BUILD_TOOLS_IMAGE=${ENVOY_BUILD_TOOLS_IMAGE} \
		--build-arg ENVOY_BUILD_TOOLS_TAG=${ENVOY_BUILD_TOOLS_TAG} \
		--build-arg ENVOY_TAG=${ENVOY_TAG} \
		--platform=${TARGETOS}/${TARGETARCH} \
		--no-cache \
		--load \
		-t ${IMAGE} .

envoy_container: envoy_image
	docker image inspect "${IMAGE}"
	docker run -t "${IMAGE}" bash -c "xx-info env && uname -a"



# docker cp "$id":/envoy-sources/bazel-bin/contrib/exe/envoy-static "${BINARY_PATH}"
# docker cp "$id":/tmp/profile.gz "${OUT_DIR}/profile.gz"
# docker rm -v "$id"



# .PHONY: build_envoy
# build_envoy: inspect
# 	$(MAKE) build/envoy/artifacts/${TARGETOS}/envoy-${ENVOY_VERSION_TRIMMED}-${DISTRO}-${TARGETARCH}

# build/envoy/artifacts/${TARGETOS}/envoy-${ENVOY_VERSION_TRIMMED}-${DISTRO}-${TARGETARCH}:
# 	DISTRO=$(DISTRO) \
# 	ENVOY_SOURCE_DIR=$(ENVOY_SOURCE_DIR) \
# 	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
# 	BUILD_ENVOY_FROM_SOURCES=$(BUILD_ENVOY_FROM_SOURCES) \
# 	ENVOY_VERSION_TRIMMED=$(ENVOY_VERSION_TRIMMED) \
# 	DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
# 	ifeq ($(BUILD_ENVOY_FROM_SOURCES),true)
# 		$(MAKE) fetch_envoy_deps
# 	else
# 		BINARY_PATH=$@ $(ENVOY_BUILD_TOOLS_DIR)/scripts/fetch_prebuilt_binary.sh
# 	endif



#
# docker image inspect "${LOCAL_BUILD_IMAGE}"

# # copy out the binary
# id=$(docker create "${LOCAL_BUILD_IMAGE}")
# docker cp "$id":/envoy-sources/bazel-bin/contrib/exe/envoy-static "${BINARY_PATH}"
# docker cp "$id":/tmp/profile.gz "${OUT_DIR}/profile.gz"
# docker rm -v "$id"