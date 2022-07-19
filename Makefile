SUPPORTED_OS:= linux darwin windows
SUPPORTED_LINUX_DISTROS:= alpine centos
WORK_DIR?= $(shell pwd)
ENVOY_BUILD_TOOLS_DIR?=${WORK_DIR}/tools/envoy
BUILD_ENVOY_FROM_SOURCES?=false
DOCKER_REGISTRY?=local



ifndef GOOS
	$(error GOOS is required)
endif
ifndef GOARCH
	$(error GOARCH is required)
endif
ifndef ENVOY_TAG
	$(error ENVOY_TAG (vX.Y.Z) is required)
endif
ifneq ($(GOOS), $(filter $(GOOS), $(SUPPORTED_OS)))
	$(error GOOS must be one of $(SUPPORTED_OS)) 
endif
ifeq ($(GOOS),linux)
ifndef DISTRO
	$(error DISTRO is required)
endif
ifneq ($(DISTRO), $(filter $(DISTRO),$(SUPPORTED_LINUX_DISTROS)))
	$(error DISTRO for $(GOOS) must be one of values: $(SUPPORTED_LINUX_DISTROS))
endif
else
	DISTRO=$(GOOS)
endif
ifndef TMPDIR
	ENVOY_SOURCE_DIR=/tmp/envoy-sources
else
	ENVOY_SOURCE_DIR=${TMPDIR}envoy-sources
endif


ENVOY_VERSION_TRIMMED=$(shell $(ENVOY_BUILD_TOOLS_DIR)/scripts/version.sh ${ENVOY_TAG})

#BUILD_ENVOY_DEPS_SCRIPT:=$(WORK_DIR)/tools/envoy/build_deps.sh


# Target 'build/envoy' allows to put Envoy binary under the build/artifacts-$GOOS-$GOARCH/envoy directory.
# Depending on the flag BUILD_ENVOY_FROM_SOURCES this target either fetches Envoy from binary registry or
# builds from sources. It's possible to build binaries for darwin, linux and centos by specifying GOOS
# and ENVOY_DISTRO variables. Envoy version could be specified by ENVOY_TAG that accepts git tag or commit
# hash values.

.PHONY: inspect
inspect:
	DISTRO=$(DISTRO) \
	ENVOY_SOURCE_DIR=$(ENVOY_SOURCE_DIR) \
	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
	BUILD_ENVOY_FROM_SOURCES=$(BUILD_ENVOY_FROM_SOURCES) \
	ENVOY_VERSION_TRIMMED=$(ENVOY_VERSION_TRIMMED) \
	DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	$(ENVOY_BUILD_TOOLS_DIR)/scripts/inspect.sh

.PHONY: build_envoy
build_envoy: inspect
	DISTRO=$(DISTRO) \
	ENVOY_SOURCE_DIR=$(ENVOY_SOURCE_DIR) \
	ENVOY_BUILD_TOOLS_DIR=$(ENVOY_BUILD_TOOLS_DIR) \
	BUILD_ENVOY_FROM_SOURCES=$(BUILD_ENVOY_FROM_SOURCES) \
	ENVOY_VERSION_TRIMMED=$(ENVOY_VERSION_TRIMMED) \
	DOCKER_REGISTRY=$(DOCKER_REGISTRY) \
	$(MAKE) build/envoy/artifacts/${GOOS}/envoy-${ENVOY_VERSION_TRIMMED}-${DISTRO}-${GOARCH}

build/envoy/artifacts/${GOOS}/envoy-${ENVOY_VERSION_TRIMMED}-${DISTRO}-${GOARCH}:
ifeq ($(BUILD_ENVOY_FROM_SOURCES),true)
	BINARY_PATH=$@ $(MAKE) build_from_source
else
	BINARY_PATH=$@ $(ENVOY_BUILD_TOOLS_DIR)/scripts/fetch_prebuilt_binary.sh
endif

.PHONY: build_from_source
build_from_source:
	$(ENVOY_BUILD_TOOLS_DIR)/scripts/build_$(DISTRO).sh
	docker buildx build \
		-f Dockerfile \
		--target distroless \
		--build-arg TAG=${TAG} \
		--build-arg COMMIT=${COMMIT} \
		--build-arg REPO_INFO=${REPO_INFO} \
		-t ${IMAGE}:${TAG} .

.PHONY: clean_envoy
clean_envoy:
	ENVOY_SOURCE_DIR=$(ENVOY_SOURCE_DIR) \
	rm -rf ${ENVOY_SOURCE_DIR}
	rm -rf build/envoy/