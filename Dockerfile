ARG ENVOY_BUILD_TOOLS_TAG
ARG BAZEL_BUILD_EXTRA_OPTIONS

# Possible values: alpine, centos, windows
# For darwin distro: Cross Compiled against alpine as default base variant unless overridden
ARG ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT=alpine
####################################################################################
# Pre Requisites Section

FROM --platform=$BUILDPLATFORM openjdk:20-slim-buster as deps
RUN apt update \
    && apt install -y git wget \
    && wget -O /usr/local/bin/bazel \
    https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-$([ $(uname -m) = "aarch64" ] && echo "arm64" || echo "amd64") \
    && chmod +x /usr/local/bin/bazel \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd -r envoy && useradd -rms /bin/bash -g envoy envoy

FROM --platform=$BUILDPLATFORM deps as base
USER envoy
WORKDIR /app
ARG ENVOY_TAG
ENV ENVOY_BUILD_TOOLS_DIR=/app/envoy-builds/tools/envoy
ENV ENVOY_SOURCE_DIR=/app/envoy
ENV ENVOY_TAG=$ENVOY_TAG
COPY --chown=envoy:envoy tools/envoy $ENVOY_BUILD_TOOLS_DIR
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/clone.sh

FROM --platform=$BUILDPLATFORM base as bazelisk-cache
RUN cd $ENVOY_SOURCE_DIR && bazel version

####################################################################################
# Builders section

FROM --platform=$BUILDPLATFORM base as builder
COPY --chown=envoy:envoy --from=bazelisk-cache /home/envoy/.cache/bazelisk /home/envoy/.cache/bazelisk

FROM --platform=$BUILDPLATFORM envoyproxy/envoy-build-ubuntu:$ENVOY_BUILD_TOOLS_TAG as envoy-alpine-builder
RUN groupadd -r envoy && useradd -rms /bin/bash -g envoy envoy
WORKDIR /app/envoy
ENV ENVOY_BUILD_TOOLS_DIR=/app/envoy-builds/tools/envoy
ENV ENVOY_SOURCE_DIR=/app/envoy
COPY --from=builder /app/envoy /app/envoy
COPY --from=builder /app/envoy-builds /app/envoy-builds
COPY --from=builder /home/envoy/.cache/bazelisk /home/envoy/.cache/bazelisk
COPY --from=builder /usr/local/bin/bazel /usr/local/bin/bazel

FROM --platform=$BUILDPLATFORM envoyproxy/envoy-build-centos:$ENVOY_BUILD_TOOLS_TAG as envoy-centos-builder
RUN groupadd -r envoy && useradd -rms /bin/bash -g envoy envoy
WORKDIR /app/envoy
ENV ENVOY_BUILD_TOOLS_DIR=/app/envoy-builds/tools/envoy
ENV ENVOY_SOURCE_DIR=/app/envoy
COPY --from=builder /app/envoy /app/envoy
COPY --from=builder /app/envoy-builds /app/envoy-builds
COPY --from=builder /home/envoy/.cache/bazelisk /home/envoy/.cache/bazelisk
COPY --from=builder /usr/local/bin/bazel /usr/local/bin/bazel

FROM --platform=$BUILDPLATFORM envoy-$ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT-builder as envoy-builder

####################################################################################

# TODO: Setup gcc libraries to prefetch bazel in base-builder
# Solve: Pre fetch OS Independent bazel depedencies for specific envoy target against default ubuntu base variant
FROM --platform=$BUILDPLATFORM envoy-alpine-builder as envoy-deps
ENV ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/bazel/prefetch.sh

####################################################################################

# For TARGETOS=linux
# ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT: alpine (default) / centos. 
FROM --platform=$BUILDPLATFORM envoy-builder as envoy-build-linux
COPY --from=envoy-deps /tmp/envoy/bazel/output /tmp/envoy/bazel/output

# For TARGETOS=darwin
# ENVOY_BUILD_TOOLS_IMAGE_BASE_VARIANT: alpine (default) / centos. 
FROM --platform=$BUILDPLATFORM envoy-build-linux as envoy-build-darwin
COPY --from=crazymax/osxcross:latest /osxcross /osxcross
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib"

####################################################################################

# TARGETOS = linux / windows / darwin
# TARGETPLATFORM = linux/amd64, linux/arm64, darwin/amd64, darwin/arm64, windows/amd64
# bazel distro specific build flags
# DISTRO= alpine / centos for linux os, darwin for darwin os

FROM envoy-build-$TARGETOS as envoy-build
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG DISTRO
ARG ENVOY_TAG
ENV DISTRO=$DISTRO
ENV ENVOY_TAG=$ENVOY_TAG
ENV ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output
ENV BAZEL_BUILD_EXTRA_OPTIONS="$BAZEL_BUILD_EXTRA_OPTIONS --distdir ${ENVOY_BAZEL_OUTPUT_BASE_DIR}"
#RUN "$ENVOY_BUILD_TOOLS_DIR/scripts/bazel/$DISTRO.sh"

# RUN bash -c "bazel/setup_clang.sh /opt/llvm"

