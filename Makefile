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

ENVOY_OUT_DIR?=${WORK_DIR}/build/artifacts-$(TARGETOS)-$(TARGETARCH)/envoy
ENVOY_OUT_BIN=envoy-$(DISTRO)
BUILD_TOOLS_SHA?=$$(git rev-parse --short HEAD)

# TODO: Use local registry instead of remote dockerhub
REGISTRY_PORT=5002
#localhost:$(REGISTRY_PORT)
REGISTRY?=kong
REPO=envoy-builds
IMAGE_NAME=$(REGISTRY)/$(REPO)
TAG_METADATA=$(BUILD_TOOLS_SHA)-$(ENVOY_TAG)

BAZEL_BUILD_EXTRA_OPTIONS?=""

# DOCKER_BUILD_EXTRA_OPTIONS=${DOCKER_BUILD_EXTRA_OPTIONS:-""}
# read -ra DOCKER_BUILD_EXTRA_OPTIONS <<< "${DOCKER_BUILD_EXTRA_OPTIONS}"
# export DOCKER_BUILD_EXTRA_OPTIONS=("${DOCKER_BUILD_EXTRA_OPTIONS[@]+"${DOCKER_BUILD_EXTRA_OPTIONS[@]}"}")


# Target 'build/envoy' allows to put Envoy binary under the build/artifacts-$TARGETOS-$TARGETARCH/envoy directory.
# Depending on the flag BUILD_ENVOY_FROM_SOURCES this target either fetches Envoy from binary registry or
# builds from sources. It's possible to build binaries for darwin, linux and centos by specifying TARGETOS
# and ENVOY_DISTRO variables. Envoy version could be specified by ENVOY_TAG that accepts git tag or commit
# hash values.

.PHONY: envoy_registry
envoy_registry:
	REGISTRY_PORT=$(REGISTRY_PORT) \
	docker run -d -p $(REGISTRY_PORT):5000 --restart=always --name registry registry:2

.PHONY: envoy_buildx_setup
envoy_buildx_setup:
	docker run --privileged --rm tonistiigi/binfmt --install all
	docker buildx create --name envoy-builder --bootstrap --use

# TODO: Use local registry cache instead of remote
.PHONY: envoy_deps
envoy_deps:
	docker buildx build \
		-f Dockerfile \
		--push \
		--build-arg DISTRO=${DISTRO} \
		--build-arg ENVOY_BUILD_TOOLS_TAG=${ENVOY_BUILD_TOOLS_TAG} \
		--build-arg ENVOY_TAG=${ENVOY_TAG} \
		--build-arg ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT=${ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT} \
		--build-arg BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
		--cache-to=type=registry,mode=max,ref=${IMAGE_NAME}:envoy-deps-${TAG_METADATA} \
		--cache-from=type=registry,ref=${IMAGE_NAME}:envoy-deps-${TAG_METADATA} \
		--target=envoy-deps \
		-t ${IMAGE_NAME}:envoy-deps-${TAG_METADATA} .

.PHONY: envoy_image

# Figure out a way to pass DOCKER_BUILD_EXTRA_OPTIONS to buildkit
# --add-host # network #s3 cache container
# Figure out a way to pass BAZEL_COMPILATION_MODE to buildkit
# BAZEL_BUILD_EXTRA_OPTIONS

# TODO: Use local registry cache instead of remote
envoy_build: envoy_deps
	ENVOY_BUILD_TOOLS_TAG="${ENVOY_BUILD_TOOLS_TAG}" \
	ENVOY_TAG="${ENVOY_TAG}" \
	TARGET="${TARGET}" \
	DISTRO="${DISTRO}" \
	TAG_METADATA="${TAG_METADATA}" \
	ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT="${ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT}" \
	docker buildx build \
		-f Dockerfile \
		--push \
		--build-arg DISTRO=${DISTRO} \
		--build-arg ENVOY_BUILD_TOOLS_TAG=${ENVOY_BUILD_TOOLS_TAG} \
		--build-arg ENVOY_TAG=${ENVOY_TAG} \
		--build-arg ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT=${ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT} \
		--build-arg BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
		--cache-to=type=registry,mode=max,ref=${IMAGE_NAME}:envoy-build-${TAG_METADATA}-${DISTRO} \
		--cache-from=type=registry,ref=${IMAGE_NAME}:envoy-deps-${TAG_METADATA} \
		--cache-from=type=registry,ref=${IMAGE_NAME}:envoy-build-${TAG_METADATA}-${DISTRO} \
		--platform=${TARGETOS}/${TARGETARCH} \
		--target=envoy-build \
		-t ${IMAGE_NAME}:envoy-build-${TAG_METADATA}-${DISTRO} .

.PHONY: inspect_envoy_image
inspect_envoy_image: envoy_build
	docker image inspect "${IMAGE_NAME}:envoy-build-${TAG_METADATA}-${DISTRO}"
	
.PHONY: envoy_bin
envoy_bin:
	DISTRO="${DISTRO}" \
	ENVOY_TAG="${ENVOY_TAG}" \
	mkdir -p ${ENVOY_OUT_DIR}
	id=$$(docker create ${IMAGE_NAME}:envoy-build-${TAG_METADATA}-${DISTRO}) \
	docker cp $id:/app/envoy/bazel-bin/contrib/exe/envoy-static ${ENVOY_OUT_DIR}/${ENVOY_OUT}


.PHONY: clean_envoy
envoy_clean:
	ENVOY_OUT=$(ENVOY_OUT_DIR) \
	rm -rf ${ENVOY_OUT_DIR}
	rm -rf ${ENVOY_BAZEL_OUTPUT_BASE_DIR}
	docker buildx stop envoy-builder
	docker buildx rm envoy-builder
#docker system prune
#docker rm -v $id
