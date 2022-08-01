SUPPORTED_OS:= linux darwin windows
SUPPORTED_ARCH:= amd64 arm64
SUPPORTED_LINUX_DISTROS = alpine centos
DOCKERFILE_TARGET?=envoy-build

ifndef ENVOY_TAG
	$(error ENVOY_TAG (vX.Y.Z) is required)
endif

ifndef ENVOY_TARGET_ARTIFACT_OS
	$(error ENVOY_TARGET_ARTIFACT_OS is required)
endif

ifneq ($(ENVOY_TARGET_ARTIFACT_OS), $(filter $(ENVOY_TARGET_ARTIFACT_OS), $(SUPPORTED_OS)))
	$(error ENVOY_TARGET_ARTIFACT_OS must be one of $(SUPPORTED_OS)) 
endif

ifndef ENVOY_TARGET_ARTIFACT_ARCH
	$(error ENVOY_TARGET_ARTIFACT_ARCH is required)
endif

ifneq ($(ENVOY_TARGET_ARTIFACT_ARCH), $(filter $(ENVOY_TARGET_ARTIFACT_ARCH), $(SUPPORTED_ARCH)))
	$(error ENVOY_TARGET_ARTIFACT_ARCH must be one of $(SUPPORTED_ARCH)) 
endif

ifeq ($(ENVOY_TARGET_ARTIFACT_OS), linux)
	ENVOY_TARGET_ARTIFACT_DISTRO?=alpine
	ifneq ($(ENVOY_TARGET_ARTIFACT_DISTRO), $(filter $(ENVOY_TARGET_ARTIFACT_DISTRO),$(SUPPORTED_LINUX_DISTROS)))
		$(error ENVOY_TARGET_ARTIFACT_DISTRO must be one of $(SUPPORTED_LINUX_DISTROS)) 
	endif
else
	ENVOY_TARGET_ARTIFACT_DISTRO=$(ENVOY_TARGET_ARTIFACT_OS)
endif

# Set WORK_DIR when running with docker
WORK_DIR?=$(shell pwd)

# ENVOYPROXY/ENVOY-BUILD-TOOLS REPOS
envoy_build_tools_version_cmd="curl --fail --location --silent https://raw.githubusercontent.com/envoyproxy/envoy/$(ENVOY_TAG)/.bazelrc | grep envoyproxy/envoy-build-ubuntu | sed -e 's\#.*envoyproxy/envoy-build-ubuntu:\(.*\)\#\1\#' | uniq"
ENVOY_BUILD_TOOLS_VERSION=$(shell eval ${envoy_build_tools_version_cmd})

# KONG/ENVOY-BUILDS REPO
ENVOY_BUILDS_SCRIPT_DIR?=${WORK_DIR}/tools/envoy
ENVOY_BUILDS_VERSION=$$(git rev-parse --short HEAD)	

# ENVOYPROXY/ENVOY REPO
ENVOY_SOURCE_DIR?=${TMPDIR}/envoyproxy/envoy
ifndef TMPDIR
	ENVOY_SOURCE_DIR ?= /tmp/envoyproxy/envoy
endif
ENVOY_VERSION_TRIMMED=$(shell $(ENVOY_BUILDS_SCRIPT_DIR)/scripts/version.sh ${ENVOY_TAG})
ENVOY_BUILD_FROM_SOURCES?=false

# BAZEL OPTIONS
# Defaults are set within the build scripts
BAZEL_DEPS_BASE_DIR=${ENVOY_SOURCE_DIR}/bazel/prefetch
BAZEL_BUILD_EXTRA_OPTIONS?=""
BAZEL_COMPILATION_MODE?=opt

# ENVOY BUILD ARTIFACTS
ENVOY_BUILDS_OUT_DIR?=${WORK_DIR}/build/artifacts
ENVOY_BUILDS_OUT_BIN=envoy-$(ENVOY_VERSION_TRIMMED)-$(ENVOY_TARGET_ARTIFACT_OS)-$(ENVOY_TARGET_ARTIFACT_ARCH)
# Binary metadata when built from sources
ENVOY_BUILDS_OUT_METADATA=${ENVOY_TARGET_ARTIFACT_DISTRO}-${BAZEL_COMPILATION_MODE}
ifneq ($(BAZEL_BUILD_EXTRA_OPTIONS), "")
	ENVOY_BUILDS_OUT_METADATA=${ENVOY_BUILDS_OUT_METADATA}-extended
endif

# Dockerhub registry cache for KONG/ENVOY-BUILDS
REGISTRY?=kong
ARTIFACT_REPO=envoy-builds
CACHE_REPO=envoy-builds-cache

CACHE_IMAGE_NAME=$(REGISTRY)/$(CACHE_REPO)
ARTIFACT_IMAGE_NAME=$(REGISTRY)/$(ARTIFACT_REPO)
CACHE_TAG=${ENVOY_BUILDS_VERSION}-$(ENVOY_VERSION_TRIMMED)
ARTIFACT_TAG=${ENVOY_BUILDS_VERSION}-$(ENVOY_VERSION_TRIMMED)-${ENVOY_BUILDS_OUT_METADATA}

#####################################################################

# Target 'build/envoy' allows to put Envoy binary under the build/artifacts-$TARGETOS-$TARGETARCH/envoy directory.
# Depending on the flag BUILD_ENVOY_FROM_SOURCES this target either fetches Envoy from binary registry or
# builds from sources. It's possible to build binaries for darwin, linux and centos by specifying TARGETOS
# and ENVOY_DISTRO variables. Envoy version could be specified by ENVOY_TAG that accepts git tag or commit
# hash values.

.PHONY: build/envoy
build/envoy:
	ENVOY_TAG=${ENVOY_TAG} \

	ENVOY_TARGET_ARTIFACT_OS=${ENVOY_TARGET_ARTIFACT_OS} \
	ENVOY_TARGET_ARTIFACT_ARCH=${ENVOY_TARGET_ARTIFACT_ARCH} \
	ENVOY_TARGET_ARTIFACT_DISTRO=${ENVOY_TARGET_ARTIFACT_DISTRO} \

	BAZEL_DEPS_BASE_DIR=${BAZEL_DEPS_BASE_DIR} \
	BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
	BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE} \

	ENVOY_BUILDS_SCRIPT_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
	
	ENVOY_SOURCE_DIR=${ENVOY_SOURCE_DIR} \
	ENVOY_VERSION_TRIMMED=${ENVOY_VERSION_TRIMMED} \
	ENVOY_BUILD_FROM_SOURCES=${ENVOY_BUILD_FROM_SOURCES} \

	ENVOY_BUILDS_OUT_DIR=${ENVOY_BUILDS_OUT_DIR} \
	ENVOY_BUILDS_OUT_BIN=${ENVOY_BUILDS_OUT_BIN} \
	ENVOY_BUILDS_OUT_METADATA=${ENVOY_BUILDS_OUT_METADATA} \

	ifeq ($(ENVOY_BUILD_FROM_SOURCES),true)
		BINARY_PATH=${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN}-${ENVOY_BUILDS_OUT_METADATA} \
		${ENVOY_BUILDS_SCRIPT_DIR}/scripts/clone.sh
		${ENVOY_BUILDS_SCRIPT_DIR}/scripts/bazel/${ENVOY_TARGET_ARTIFACT_DISTRO}.sh
		$(MAKE) ${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN}-${ENVOY_BUILDS_OUT_METADATA}
	else
		BINARY_PATH=${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN} \
		${ENVOY_BUILDS_SCRIPT_DIR}/scripts/fetch_prebuilt_binary.sh
	endif


${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN}-${ENVOY_BUILDS_OUT_METADATA}:
	cp ${ENVOY_SOURCE_DIR}/bazel-bin/contrib/exe/envoy-static $@

# TODO: Implement local registry cache instead of remote caching locally 
# Note: Use buildx and build-push action in CI with remote caching enabled
.PHONY: docker/envoy-build
docker/envoy-build:

	WORK_DIR=${WORK_DIR} \

	ENVOY_BUILD_TOOLS_VERSION="${ENVOY_BUILD_TOOLS_VERSION}" \

	ENVOY_TAG=${ENVOY_TAG} \

	ENVOY_TARGET_ARTIFACT_OS=${ENVOY_TARGET_ARTIFACT_OS} \
	ENVOY_TARGET_ARTIFACT_ARCH=${ENVOY_TARGET_ARTIFACT_ARCH} \
	ENVOY_TARGET_ARTIFACT_DISTRO=${ENVOY_TARGET_ARTIFACT_DISTRO} \

	BAZEL_DEPS_BASE_DIR=${BAZEL_DEPS_BASE_DIR} \
	BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
	BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE} \

	ENVOY_BUILDS_SCRIPT_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
	
	ENVOY_SOURCE_DIR=${ENVOY_SOURCE_DIR} \

	CACHE_IMAGE_NAME=${CACHE_IMAGE_NAME} \
	ARTIFACT_IMAGE_NAME=${ARTIFACT_IMAGE_NAME} \

	CACHE_TAG=${CACHE_TAG} \
	ARTIFACT_TAG=${ARTIFACT_TAG} \

	$(MAKE) setup/buildx

	$(MAKE) docker/envoy-deps

	docker buildx build \
		-f $(DOCKERFILE) \
		--load \
		--build-arg WORKDIR=${WORKDIR} \
		--build-arg ENVOY_BUILD_TOOLS_VERSION=${ENVOY_BUILD_TOOLS_VERSION} \
		--build-arg ENVOY_TAG=${ENVOY_TAG} \
		--build-arg ENVOY_TARGET_ARTIFACT_OS=${ENVOY_TARGET_ARTIFACT_OS} \
		--build-arg ENVOY_TARGET_ARTIFACT_ARCH=${ENVOY_TARGET_ARTIFACT_ARCH} \
		--build-arg ENVOY_TARGET_ARTIFACT_DISTRO=${ENVOY_TARGET_ARTIFACT_DISTRO} \
		--build-arg BAZEL_DEPS_BASE_DIR=${BAZEL_DEPS_BASE_DIR} \
		--build-arg BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
		--build-arg BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE} \
		--build-arg ENVOY_BUILDS_SCRIPT_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
		--build-arg ENVOY_SOURCE_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
		--build-arg ENVOY_BUILD_TOOLS_VERSION=${ENVOY_BUILD_TOOLS_VERSION} \
		--target=envoy-build \
		-t ${ARTIFACT_IMAGE_NAME}:envoy-build-${ARTIFACT_TAG} .

	$(MAKE) inspect/envoy-image

	$(MAKE) extract/envoy-binary

.PHONY: docker/envoy-deps
docker/envoy-deps: 
	docker buildx build \
		-f $(DOCKERFILE) \
		--load \
		--build-arg WORKDIR=${WORKDIR} \
		--build-arg ENVOY_BUILD_TOOLS_VERSION=${ENVOY_BUILD_TOOLS_VERSION} \
		--build-arg ENVOY_TAG=${ENVOY_TAG} \
		--build-arg ENVOY_TARGET_ARTIFACT_OS=${ENVOY_TARGET_ARTIFACT_OS} \
		--build-arg ENVOY_TARGET_ARTIFACT_ARCH=${ENVOY_TARGET_ARTIFACT_ARCH} \
		--build-arg ENVOY_TARGET_ARTIFACT_DISTRO=${ENVOY_TARGET_ARTIFACT_DISTRO} \
		--build-arg BAZEL_DEPS_BASE_DIR=${BAZEL_DEPS_BASE_DIR} \
		--build-arg BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
		--build-arg BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE} \
		--build-arg ENVOY_BUILDS_SCRIPT_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
		--build-arg ENVOY_SOURCE_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
		--build-arg ENVOY_BUILD_TOOLS_VERSION=${ENVOY_BUILD_TOOLS_VERSION} \
		--target=envoy-deps\
		-t ${CACHE_IMAGE_NAME}:envoy-deps-${CACHE_TAG} .

.PHONY: setup/buildx
envoy_buildx_setup:
	docker run --privileged --rm tonistiigi/binfmt --install all
	docker buildx create --name envoy-builder --bootstrap --use

.PHONY: inspect/envoy-image
inspect/envoy-image:
	docker image inspect ${ARTIFACT_IMAGE_NAME}:envoy-build-${ARTIFACT_TAG}
	
.PHONY: extract/envoy-binary
extract/envoy-binary:

	ENVOY_BUILDS_OUT_DIR=${ENVOY_BUILDS_OUT_DIR} \
	ENVOY_BUILDS_OUT_BIN=${ENVOY_BUILDS_OUT_BIN} \
	ENVOY_BUILDS_OUT_METADATA=${ENVOY_BUILDS_OUT_METADATA} \
	mkdir -p ${ENVOY_OUT_DIR}
	id=$$(docker create ${ARTIFACT_IMAGE_NAME}:envoy-build-${TAG_METADATA}) \
	docker cp ${id}:${ENVOY_SOURCE_DIR}/bazel-bin/contrib/exe/envoy-static ${ENVOY_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN}-${ENVOY_BUILDS_OUT_METADATA}

.PHONY: clean/envoy
clean/envoy:
	ENVOY_BUILDS_OUT_DIR=${ENVOY_BUILDS_OUT_DIR} \
	ENVOY_SOURCE_DIR=${ENVOY_SOURCE_DIR} \
	rm -rf ${ENVOY_BUILDS_OUT_DIR}
	rm -rf ${ENVOY_SOURCE_DIR}
	docker buildx stop envoy-builder
	docker buildx rm envoy-builder