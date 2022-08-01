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
ENVOY_BUILDS_VERSION:=$$(git rev-parse --short HEAD)

# ENVOYPROXY/ENVOY REPO
ENVOY_SOURCE_DIR?=${TMPDIR}/envoyproxy/envoy
ifndef TMPDIR
	ENVOY_SOURCE_DIR?=/tmp/envoyproxy/envoy
endif
ENVOY_VERSION_TRIMMED=$(shell $(ENVOY_BUILDS_SCRIPT_DIR)/scripts/version.sh ${ENVOY_TAG})
ENVOY_BUILD_FROM_SOURCES?=false

# BAZEL OPTIONS
# Defaults are set within the build scripts
BAZEL_DEPS_BASE_DIR=${ENVOY_SOURCE_DIR}/bazel/prefetch
BAZEL_COMPILATION_MODE?=opt
BAZEL_BUILD_EXTRA_OPTIONS?=''
# ENVOY BUILD ARTIFACTS
ENVOY_BUILDS_OUT_DIR?=${WORK_DIR}/build/artifacts
ENVOY_BUILDS_OUT_BIN=envoy-$(ENVOY_VERSION_TRIMMED)-${ENVOY_TARGET_ARTIFACT_DISTRO}-$(ENVOY_TARGET_ARTIFACT_ARCH)
# Binary metadata when built from sources
ENVOY_BUILDS_OUT_METADATA=${BAZEL_COMPILATION_MODE}
ifneq ($(BAZEL_BUILD_EXTRA_OPTIONS), '')
	ENVOY_BUILDS_OUT_METADATA:=$(ENVOY_BUILDS_OUT_METADATA)-extended
endif

# Dockerhub registry cache for KONG/ENVOY-BUILDS
REGISTRY?=kong
ARTIFACT_REPO=envoy-builds
CACHE_REPO=envoy-builds-cache

CACHE_IMAGE_NAME=$(REGISTRY)/$(CACHE_REPO)
ARTIFACT_IMAGE_NAME=$(REGISTRY)/$(ARTIFACT_REPO)
CACHE_TAG=$(ENVOY_BUILDS_VERSION)-$(ENVOY_VERSION_TRIMMED)
ARTIFACT_TAG=$(ENVOY_BUILDS_VERSION)-$(ENVOY_VERSION_TRIMMED)-$(ENVOY_BUILDS_OUT_METADATA)

#####################################################################

# Target 'build/envoy' allows to put Envoy binary under the build/artifacts-$TARGETOS-$TARGETARCH/envoy directory.
# Depending on the flag BUILD_ENVOY_FROM_SOURCES this target either fetches Envoy from binary registry or
# builds from sources. It's possible to build binaries for darwin, linux and centos by specifying TARGETOS
# and ENVOY_DISTRO variables. Envoy version could be specified by ENVOY_TAG that accepts git tag or commit
# hash values.

define local_envoy_env
$(1): export ENVOY_TAG=${ENVOY_TAG}
$(1): export ENVOY_TARGET_ARTIFACT_OS=${ENVOY_TARGET_ARTIFACT_OS}
$(1): export ENVOY_TARGET_ARTIFACT_ARCH=${ENVOY_TARGET_ARTIFACT_ARCH}
$(1): export ENVOY_TARGET_ARTIFACT_DISTRO=${ENVOY_TARGET_ARTIFACT_DISTRO}
$(1): export BAZEL_DEPS_BASE_DIR=${BAZEL_DEPS_BASE_DIR}
$(1): export BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS}
$(1): export BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE}
$(1): export ENVOY_BUILDS_SCRIPT_DIR=${ENVOY_BUILDS_SCRIPT_DIR}
$(1): export ENVOY_SOURCE_DIR=${ENVOY_SOURCE_DIR}
$(1): export ENVOY_BUILDS_OUT_DIR=${ENVOY_BUILDS_OUT_DIR}	
$(1): export ENVOY_BUILDS_OUT_BIN=${ENVOY_BUILDS_OUT_BIN}
$(1): export ENVOY_BUILDS_OUT_METADATA=${ENVOY_BUILDS_OUT_METADATA}
$(1): export ENVOY_VERSION_TRIMMED=${ENVOY_VERSION_TRIMMED}
$(1): export BINARY_PATH=${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN}-${ENVOY_BUILDS_OUT_METADATA}
endef

define docker_envoy_env
$(1): $(eval $(call local_envoy_env, $(1)))
$(1): export ENVOY_BUILD_TOOLS_VERSION=${ENVOY_BUILD_TOOLS_VERSION}
$(1): export CACHE_IMAGE_NAME=${CACHE_IMAGE_NAME}
$(1): export ARTIFACT_IMAGE_NAME=${ARTIFACT_IMAGE_NAME}
$(1): export CACHE_TAG=${CACHE_TAG}
$(1): export ARTIFACT_TAG=${ARTIFACT_TAG}
endef

define docker_envoy_cmd
$(1): $(eval $(call docker_envoy_env, $(1)))
	docker buildx build \
		-f Dockerfile.linux \
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
		--target=$(2) \
		--platform=${ENVOY_TARGET_ARTIFACT_OS}/${ENVOY_TARGET_ARTIFACT_ARCH} \
		-t $($(3)_IMAGE_NAME):$(2)-$$($(3)_TAG) .
endef

#################################################################
# Build Envoy using on host (Only supports linux, darwin runners for now)
.PHONY: clone/envoy
clone/envoy: $(eval $(call local_envoy_env,clone/envoy))
	${ENVOY_BUILDS_SCRIPT_DIR}/scripts/clone.sh

.PHONY: prefetch/envoy
prefetch/envoy: $(eval $(call local_envoy_env,prefetch/envoy))
	$(MAKE) clone/envoy
	${ENVOY_BUILDS_SCRIPT_DIR}/scripts/bazel/prefetch.sh

.PHONY: build/envoy
build/envoy: $(eval $(call local_envoy_env,build/envoy)) 
ifeq ($(ENVOY_BUILD_FROM_SOURCES), true)
	$(MAKE) prefetch/envoy
	${ENVOY_BUILDS_SCRIPT_DIR}/scripts/bazel/${ENVOY_TARGET_ARTIFACT_DISTRO}.sh
	$(MAKE) ${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN}-${ENVOY_BUILDS_OUT_METADATA}
else
	BINARY_PATH=${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN} \
	ENVOY_VERSION_TRIMMED=${ENVOY_VERSION_TRIMMED} \
	ENVOY_TARGET_ARTIFACT_ARCH=${ENVOY_TARGET_ARTIFACT_ARCH} \
	ENVOY_TARGET_ARTIFACT_DISTRO=${ENVOY_TARGET_ARTIFACT_DISTRO} \
	${ENVOY_BUILDS_SCRIPT_DIR}/scripts/fetch_prebuilt_binary.sh
endif

${ENVOY_BUILDS_OUT_DIR}/${ENVOY_BUILDS_OUT_BIN}-${ENVOY_BUILDS_OUT_METADATA}:
	cp ${ENVOY_SOURCE_DIR}/bazel-bin/contrib/exe/envoy-static $@

#################################################################
# Build Envoy using Docker Buildx (Only supports linux os for now)

.PHONY: setup/buildx
setup/buildx:
	docker buildx stop envoy-builder
	docker buildx rm envoy-builder
	docker run --privileged --rm tonistiigi/binfmt --install all
	docker buildx create --name envoy-builder --bootstrap --use

.PHONY: docker/envoy-deps
docker/envoy-deps: setup/buildx \
	$(eval $(call docker_envoy_cmd,docker/envoy-deps,envoy-deps,ARTIFACT))

.PHONY: inspect/envoy-image
inspect/envoy-image: $(eval $(call local_envoy_env, build/envoy))
	docker image inspect ${ARTIFACT_IMAGE_NAME}:envoy-build-${ARTIFACT_TAG}
	
.PHONY: extract/envoy-binary
extract/envoy-binary: $(eval $(call local_envoy_env, build/envoy))
	mkdir -p ${ENVOY_OUT_DIR}
	id=$$(docker create ${ARTIFACT_IMAGE_NAME}:envoy-build-${TAG_METADATA}) \
	docker cp ${id}:${ENVOY_SOURCE_DIR}/bazel-bin/contrib/exe/envoy-static ${BINARY_PATH}


# TODO: Implement local registry cache instead of remote caching locally 
# Note: Use buildx and build-push action in CI with remote caching enabled
.PHONY: docker/envoy-build
docker/envoy-build: $(MAKE) docker/envoy-deps \
	$(eval $(call docker_envoy_cmd,docker/envoy-build,envoy-build,ARTIFACT)) \
	$(MAKE) inspect/envoy-image \
	$(MAKE) extract/envoy-binary

.PHONY: clean/envoy
clean/envoy:
	ENVOY_BUILDS_OUT_DIR=${ENVOY_BUILDS_OUT_DIR} \
	ENVOY_SOURCE_DIR=${ENVOY_SOURCE_DIR} \
	rm -rf ${ENVOY_BUILDS_OUT_DIR}
	sudo rm -rf ${ENVOY_SOURCE_DIR}