FROM golang:alpine AS builder

# Build-time proxy settings (leave empty for direct connection).
# Used for `apk add` and `go mod download`.
ARG HTTP_PROXY=""
ARG HTTPS_PROXY=""
ARG NO_PROXY="localhost,127.0.0.1,::1"
# Go module proxy, e.g. https://goproxy.cn,direct for mainland China.
ARG GOPROXY="https://proxy.golang.org,direct"
# Optional Alpine mirror replacement, e.g. https://mirrors.aliyun.com/alpine
ARG APK_MIRROR=""
# Optional version metadata override. Needed when building straight from a
# git URL, where the build context has no tags for `git describe` to read.
ARG VERSION=""
ARG COMMIT=""

ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    no_proxy=${NO_PROXY} \
    GOPROXY=${GOPROXY}

WORKDIR /src
COPY . /src

RUN if [ -n "${APK_MIRROR}" ]; then \
        sed -i "s|https://dl-cdn.alpinelinux.org|${APK_MIRROR}|g" /etc/apk/repositories; \
    fi \
    && apk add --update --no-cache --no-progress make git \
    && make ${VERSION:+BUILD_VERSION=${VERSION}} ${COMMIT:+BUILD_COMMIT=${COMMIT}} server

FROM alpine:latest
LABEL org.opencontainers.image.licenses=Apache-2.0
LABEL org.opencontainers.image.source="https://github.com/metatube-community/metatube-sdk-go"

ARG HTTP_PROXY=""
ARG HTTPS_PROXY=""
ARG APK_MIRROR=""

COPY --from=builder /src/build/metatube-server .

RUN if [ -n "${APK_MIRROR}" ]; then \
        sed -i "s|https://dl-cdn.alpinelinux.org|${APK_MIRROR}|g" /etc/apk/repositories; \
    fi \
    && http_proxy="${HTTP_PROXY}" https_proxy="${HTTPS_PROXY}" \
        apk add --update --no-cache --no-progress ca-certificates tzdata

ENV GIN_MODE=release
ENV PORT=8080
ENV TOKEN=""
ENV DSN=""
ENV REQUEST_TIMEOUT=""
ENV DB_MAX_IDLE_CONNS=0
ENV DB_MAX_OPEN_CONNS=0
ENV DB_PREPARED_STMT=0
ENV DB_AUTO_MIGRATE=0

# Runtime proxy settings (leave empty for direct connection).
# Go's net/http honors these automatically for provider scraping, image and
# translation requests. Override them at `docker run` / compose time:
#   -e HTTP_PROXY=http://192.168.1.10:7890 -e HTTPS_PROXY=http://192.168.1.10:7890
ENV HTTP_PROXY=""
ENV HTTPS_PROXY=""
ENV NO_PROXY="localhost,127.0.0.1,::1"

EXPOSE 8080

ENTRYPOINT ["/metatube-server"]
