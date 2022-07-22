ARG ENVOY_BUILD_TOOLS_IMAGE
ARG ENVOY_BUILD_TOOLS_TAG
ARG ENVOY_TAG

FROM --platform=$BUILDPLATFORM tonistiigi/xx:1.1.2 AS xx

FROM --platform=$BUILDPLATFORM alpine:3.15.5 as bazel-alpine
RUN wget -O /usr/local/bin/bazel \
    https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-$([ $(uname -m) = "aarch64" ] && echo "arm64" || echo "amd64") \
    && chmod +x /usr/local/bin/bazel 

FROM --platform=$BUILDPLATFORM centos:centos7 as bazel-centos
RUN wget -O /usr/local/bin/bazel \
    https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-$([ $(uname -m) = "aarch64" ] && echo "arm64" || echo "amd64") \
    && chmod +x /usr/local/bin/bazel
    
FROM --platform=$BUILDPLATFORM envoyproxy/envoy-build-ubuntu:$ENVOY_BUILD_TOOLS_TAG as envoy-build-base-alpine
ENV ENVOY_TAG=$ENVOY_TAG
WORKDIR /app
COPY --from=xx / /
COPY --from=bazel-alpine /usr/local/bin/bazel /usr/local/bin/bazel
ENV ENVOY_BUILD_TOOLS_DIR=./envoy-builds/tools/envoy
ENV ENVOY_SOURCE_DIR=./envoy
ADD tools/envoy $ENVOY_BUILD_TOOLS_DIR
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/clone.sh

#Pre fetch bazel depedencies for envoy target
FROM --platform=$BUILDPLATFORM envoy-build-base-alpine as envoy-build-deps-alpine
WORKDIR /app/envoy
ENV ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/bazel/prefetch.sh

FROM --platform=$BUILDPLATFORM envoyproxy/envoy-build-centos:$ENVOY_BUILD_TOOLS_TAG as envoy-build-base-centos
ENV ENVOY_TAG=$ENVOY_TAG
WORKDIR /app
COPY --from=xx / /
COPY --from=bazel-alpine /usr/local/bin/bazel /usr/local/bin/bazel
ENV ENVOY_BUILD_TOOLS_DIR=./envoy-builds/tools/envoy
ENV ENVOY_SOURCE_DIR=./envoy
ADD tools/envoy $ENVOY_BUILD_TOOLS_DIR
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/clone.sh

#Pre fetch bazel depedencies for envoy target
FROM --platform=$BUILDPLATFORM envoy-build-base-centos as envoy-build-deps-centos
WORKDIR /app/envoy
ENV ENVOY_BAZEL_OUTPUT_BASE_DIR=/tmp/envoy/bazel/output
RUN $ENVOY_BUILD_TOOLS_DIR/scripts/bazel/prefetch.sh

# Cross compiling envoyproxy darwin from ubuntu base variant
FROM --platform=$BUILDPLATFORM envoy-build-base-alpine as envoy-build-alpine-osxcross
ARG TARGETPLATFORM
COPY --from=crazymax/osxcross:latest /osxcross /osxcross
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib:$LD_LIBRARY_PATH"
CMD ["/bin/bash"]

# Cross compiling envoyproxy darwin from centos base variant
FROM --platform=$BUILDPLATFORM envoy-build-base-centos as envoy-build-centos-osxcross
ARG TARGETPLATFORM
COPY --from=crazymax/osxcross:latest /osxcross /osxcross
ENV PATH="/osxcross/bin:$PATH"
ENV LD_LIBRARY_PATH="/osxcross/lib:$LD_LIBRARY_PATH"
CMD ["/bin/bash"]

# RUN bash -c "bazel/setup_clang.sh /opt/llvm"
# RUN bash -c "$BUILD_CMD"
