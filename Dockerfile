ARG ENVOY_BUILD_TOOLS_TAG
ARG ENVOY_TAG

# Cross compile darwin against alpine base variant of eb build tools image
ARG ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT=alpine
ARG DISTRO

ARG BAZEL_BUILD_EXTRA_OPTIONS

FROM --platform=$BUILDPLATFORM alpine:3.15.5 as bazel-alpine
RUN wget -O /usr/local/bin/bazel \
    https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-$([ $(uname -m) = "aarch64" ] && echo "arm64" || echo "amd64") \
    && chmod +x /usr/local/bin/bazel 

FROM --platform=$BUILDPLATFORM centos:centos7 as bazel-centos
RUN wget -O /usr/local/bin/bazel \
    https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-$([ $(uname -m) = "aarch64" ] && echo "arm64" || echo "amd64") \
    && chmod +x /usr/local/bin/bazel

# add current context and checkout envoy proxy
FROM --platform=$BUILDPLATFORM alpine:3.15.5 as base
WORKDIR /app
ENV ENVOY_BUILD_TOOLS_DIR=./envoy-builds/tools/envoy
ENV ENVOY_SOURCE_DIR=./envoy
ENV ENVOY_TAG=$ENVOY_TAG
ADD tools/envoy $ENVOY_BUILD_TOOLS_DIR
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/clone.sh

#Pre fetch bazel depedencies for envoy target
FROM --platform=$BUILDPLATFORM base as deps 
ENV ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/bazel/prefetch.sh

FROM --platform=$BUILDPLATFORM envoyproxy/envoy-build-ubuntu:$ENVOY_BUILD_TOOLS_TAG as envoy-build-deps-alpine
WORKDIR /app/envoy
COPY --from=deps ./envoy .
COPY --from=deps /tmp/envoy/bazel/output /tmp/envoy/bazel/output
COPY --from=bazel-alpine /usr/local/bin/bazel /usr/local/bin/bazel

FROM --platform=$BUILDPLATFORM envoyproxy/envoy-build-centos:$ENVOY_BUILD_TOOLS_TAG as envoy-build-deps-centos
WORKDIR /app/envoy
COPY --from=deps ./envoy .
COPY --from=deps /tmp/envoy/bazel/output /tmp/envoy/bazel/output
COPY --from=bazel-alpine /usr/local/bin/bazel /usr/local/bin/bazel

# Base linux distro based image with prebuild envoy deps
# ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT = alpine / centos
# Cross compile base envoy build tools image variant. (Doesn't produce darwin)
FROM --platform=$BUILDPLATFORM envoy-build-deps-$ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT as envoy-build-deps-linux

# Cross compiling envoyproxy darwin from linux based image with prebuild envoy deps
FROM --platform=$BUILDPLATFORM envoy-build-deps-linux as envoy-build-deps-darwin
COPY --from=crazymax/osxcross:latest /osxcross /osxcross
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib"

# TARGETOS = linux / windows / darwin
# TARGETPLATFORM = linux/amd64, linux/arm64, darwin/amd64, darwin/arm64, windows/amd64
# bazel distro specific build flags
# DISTRO= alpine / centos for linux os, darwin for darwin os

FROM envoy-build-deps-$TARGETOS as envoy-build
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ENV DISTRO=$DISTRO
ENV ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output
ENV BAZEL_BUILD_EXTRA_OPTIONS="$BAZEL_BUILD_EXTRA_OPTIONS --distdir ${ENVOY_BAZEL_OUTPUT_BASE_DIR}"
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/bazel/$DISTRO.sh

# RUN bash -c "bazel/setup_clang.sh /opt/llvm"

