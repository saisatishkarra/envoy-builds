# Tools for Envoy

The current directory contains tools for building, publishing and fetching Envoy binaries.

There is a new Makefile target `build/envoy` that places an `envoy` binary in `build/artifacts-$GOOS-$GOARCH/envoy` directory.
The default behaviour of that target – fetching binaries from [download.konghq.com](download.konghq.com) since it makes more sense for
overwhelming majority of users. However, there is a variable `BUILD_ENVOY_FROM_SOURCES` that allows to build Envoy from 
source code. 

### Usage

Download the latest supported Envoy binary for your host OS: 
```shell
$ make build/envoy
```

Download the latest supported Envoy binary for specified system:
```shell
$ GOOS=linux make build/envoy # supported OS: linux, centos and darwin
```

Download the specific Envoy tag:
```shell
$ ENVOY_TAG=v1.18.4 make build/envoy
```

Download the specific Envoy commit hash (if it exists in [download.konghq.com](download.konghq.com)):
```shell
$ ENVOY_TAG=bef18019d8fc33a4ed6aca3679aff2100241ac5e make build/envoy
```

If desired commit hash doesn't exist, it could be built from sources:
```shell
$ ENVOY_TAG=bef18019d8fc33a4ed6aca3679aff2100241ac5e BUILD_ENVOY_FROM_SOURCES=true make build/envoy
```

When building from sources its still possible to specify OS:
```shell
$ GOOS=linux ENVOY_TAG=bef18019d8fc33a4ed6aca3679aff2100241ac5e BUILD_ENVOY_FROM_SOURCES=true make build/envoy
```

When building from sources using dockerfile:
```shell
$ TARGETOS=linux TARGETARCH=amd64 DISTRO=centos ENVOY_TAG=v1.22.0 TARGET=envoy-build BUILD_ENVOY_FROM_SOURCES=true make inspect_envoy_image
```



#   docker buildx build \
# 	-f Dockerfile.linux \
# 	--load \
# 	--build-arg WORKDIR=${WORKDIR} \
# 	--build-arg ENVOY_BUILD_TOOLS_VERSION=${ENVOY_BUILD_TOOLS_VERSION} \
# 	--build-arg ENVOY_TAG=${ENVOY_TAG} \
# 	--build-arg ENVOY_TARGET_ARTIFACT_OS=${ENVOY_TARGET_ARTIFACT_OS} \
# 	--build-arg ENVOY_TARGET_ARTIFACT_ARCH=${ENVOY_TARGET_ARTIFACT_ARCH} \
# 	--build-arg ENVOY_TARGET_ARTIFACT_DISTRO=${ENVOY_TARGET_ARTIFACT_DISTRO} \
# 	--build-arg BAZEL_DEPS_BASE_DIR=${BAZEL_DEPS_BASE_DIR} \
# 	--build-arg BAZEL_BUILD_EXTRA_OPTIONS=${BAZEL_BUILD_EXTRA_OPTIONS} \
# 	--build-arg BAZEL_COMPILATION_MODE=${BAZEL_COMPILATION_MODE} \
# 	--build-arg ENVOY_BUILDS_SCRIPT_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
# 	--build-arg ENVOY_SOURCE_DIR=${ENVOY_BUILDS_SCRIPT_DIR} \
# 	--build-arg ENVOY_BUILD_TOOLS_VERSION=${ENVOY_BUILD_TOOLS_VERSION} \
# 	--target=$(1) \
# 	-t ${$(2)_IMAGE_NAME}:$(1)-${$(2)_TAG} .