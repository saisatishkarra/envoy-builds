SUPPORTED_OS:= linux darwin windows
SUPPORTED_LINUX_DISTROS:= alpine centos
SUPPORTED_ARCH:= amd64 arm64

ifndef TARGETOS
	$(error TARGETOS is required)
endif

ifndef TARGETARCH
	$(error TARGETARCH is required)
endif

ifndef ENVOY_TAG
	$(error ENVOY_TAG (vX.Y.Z) is required)
endif

ifneq ($(TARGETARCH), $(filter $(TARGETARCH), $(SUPPORTED_ARCH)))
	$(error TARGETARCH must be one of $(SUPPORTED_ARCH)) 
endif

ifneq ($(TARGETOS), $(filter $(TARGETOS), $(SUPPORTED_OS)))
	$(error TARGETOS must be one of $(SUPPORTED_OS)) 
endif
		
ifeq ($(TARGETOS), linux)
	ifndef DISTRO
		$(error DISTRO is required. One of:$(SUPPORTED_LINUX_DISTROS))
	endif
	ifeq ($(DISTRO), $(filter $(DISTRO),$(SUPPORTED_LINUX_DISTROS)))
		ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT=$(DISTRO)
	endif
else ifeq ($(TARGETOS), darwin)
# Use alpine as envoy build tools base for cross compiling darwin	
	DISTRO=$(TARGETOS)
	ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT="alpine"
else 
# Windows
	DISTRO=$(TARGETOS)
	ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT=$(DISTRO)
endif

WORK_DIR?= $(shell pwd)
ENVOY_BUILD_TOOLS_DIR?=${WORK_DIR}/tools/envoy
# Envoy buils tools image is not provided for darwin. Needs to be overriden for darwin
VERSION_CMD="curl --fail --location --silent https://raw.githubusercontent.com/envoyproxy/envoy/$(ENVOY_TAG)/.bazelrc | grep envoyproxy/envoy-build-ubuntu | sed -e 's\#.*envoyproxy/envoy-build-ubuntu:\(.*\)\#\1\#' | uniq"
ENVOY_BUILD_TOOLS_TAG=$(shell eval ${VERSION_CMD})
ENVOY_VERSION_TRIMMED=$(shell $(ENVOY_BUILD_TOOLS_DIR)/scripts/version.sh ${ENVOY_TAG})
BUILD_ENVOY_FROM_SOURCES?=false
TARGET?="envoy-build"
ENVOY_OUT_DIR?=${WORK_DIR}/build/artifacts-$(TARGETOS)-$(TARGETARCH)/envoy
ENVOY_OUT_BIN=envoy-$(DISTRO)


REGISTRY?=local
REPO?=envoy-builds
IMAGENAME=$(REGISTRY)/$(REPO) 
IMAGE?=$(REGISTRY)/$(REPO):${ENVOY_TAG}-${DISTRO}
BAZEL_BUILD_EXTRA_OPTIONS?=""

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
	ENVOY_OUT_DIR=$(ENVOY_OUT_DIR) \
	BUILD_ENVOY_FROM_SOURCES=$(BUILD_ENVOY_FROM_SOURCES) \
	ENVOY_TAG="${ENVOY_TAG}" \
	ENVOY_VERSION_TRIMMED=$(ENVOY_VERSION_TRIMMED) \
	DISTRO=$(DISTRO) \
	FLAVOUR=$(FLAVOUR) \
	DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	$(ENVOY_BUILD_TOOLS_DIR)/scripts/inspect.sh

.PHONY: build_envoy_image

# Figure out a way to pass DOCKER_BUILD_EXTRA_OPTIONS to buildkit
# --add-host # network #s3 cache container
# Figure out a way to pass BAZEL_COMPILATION_MODE to buildkit
# Figure out a way to pass BAZEL_COMPILATION_MODE to buildkit
# BAZEL_BUILD_EXTRA_OPTIONS

build_envoy_image:
	ENVOY_BUILD_TOOLS_TAG="${ENVOY_BUILD_TOOLS_TAG}" \
	ENVOY_TAG="${ENVOY_TAG}" \
	TARGET="${TARGET}" \
	DISTRO="${DISTRO}" \
	ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT="${ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT}" \
	docker run --privileged --rm tonistiigi/binfmt --install ${TARGETARCH}
	docker buildx create --name envoy-builder --bootstrap --use --platform=${TARGETOS}/${TARGETARCH}
	docker buildx build \
		-f Dockerfile \
		--build-arg ENVOY_BUILD_TOOLS_TAG=${ENVOY_BUILD_TOOLS_TAG} \
		--build-arg ENVOY_TAG=${ENVOY_TAG} \
		--build-arg ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT=${ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT} \
		--build-arg DISTRO=${DISTRO} \
		--build-arg BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
		--platform=${TARGETOS}/${TARGETARCH} \
		--load \
		--target=${TARGET} \
		-t ${IMAGE} .

.PHONY: inspect_envoy_image
inspect_envoy_image: build_envoy_image
	docker image inspect "${IMAGE}"
	
.PHONY: envoy_bin
envoy_bin:
	- mkdir ${ENVOY_OUT_DIR}
	id=$(docker create "${IMAGE}")
	docker cp "$id":/app/envoy/bazel-bin/contrib/exe/envoy-static "${ENVOY_OUT_DIR}/${ENVOY_OUT}"
#docker cp "$id":/tmp/profile.gz "${ENVOY_OUT}/profile.gz"
	docker rm -v "$id"

.PHONY: clean_envoy
clean_envoy:
	ENVOY_OUT=$(ENVOY_OUT_DIR) \
	rm -rf ${ENVOY_OUT_DIR}
	rm -rf ${ENVOY_BAZEL_OUTPUT_BASE_DIR}
	docker buildx stop envoy-builder
	docker buildx rm envoy-builder
#docker system prune
	

# .PHONY: build_envoy
# build_envoy: inspect
# 	$(MAKE) build/envoy/artifacts/${TARGETOS}/envoy-${ENVOY_VERSION_TRIMMED}-${DISTRO}-${TARGETARCH}

# build/envoy/artifacts/${TARGETOS}/envoy-${ENVOY_VERSION_TRIMMED}-${DISTRO}-${TARGETARCH}:
# 	DISTRO=$(DISTRO) \
# 	ENVOY_OUT=$(ENVOY_OUT) \
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

# Alpine prefetch: 891 375s
# Centos prefetch: 891 379s
# prefetch is the same for any platform and only specific to a target