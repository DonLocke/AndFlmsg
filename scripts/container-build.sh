#!/usr/bin/env bash
#
# Run a command inside the containerized AndFlmsg build environment.
#
# Works with Podman or Docker. The engine is auto-detected, or can be
# selected with CONTAINER_ENGINE=podman|docker.
#
# Examples:
#   ./scripts/container-build.sh :andFlmsg:assembleDebug
#   ./scripts/container-build.sh :andFlmsg:assembleRelease
#   ./scripts/container-build.sh bash
#   CONTAINER_ENGINE=docker ./scripts/container-build.sh :andFlmsg:assembleDebug
#
# A project task such as ":andFlmsg:assembleDebug" is passed to ./gradlew
# automatically. Other commands, including "bash", are run unchanged.
#
# The image is built on first use. Nothing (JDK, Android SDK, NDK) is
# installed on the host.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${ANDFLMSG_BUILD_IMAGE:-localhost/andflmsg-build:latest}"
CONTAINERFILE="${ROOT_DIR}/container/Containerfile"
IMAGE_STAMP_LABEL="dev.andflmsg.containerfile-sha256"

if command -v sha256sum >/dev/null 2>&1; then
    CONTAINERFILE_HASH="$(sha256sum "${CONTAINERFILE}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    CONTAINERFILE_HASH="$(shasum -a 256 "${CONTAINERFILE}" | awk '{print $1}')"
else
    CONTAINERFILE_HASH="$(cksum "${CONTAINERFILE}" | awk '{print $1 "-" $2}')"
fi

if [ -n "${CONTAINER_ENGINE:-}" ]; then
    ENGINE="${CONTAINER_ENGINE}"
elif command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
elif command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
else
    echo "error: neither podman nor docker is installed" >&2
    exit 1
fi

if ! command -v "${ENGINE}" >/dev/null 2>&1; then
    echo "error: ${ENGINE} is not installed" >&2
    exit 1
fi

# Rebuild when the image is missing or was built from a different Containerfile.
image_is_current() {
    local image_hash
    image_hash="$("${ENGINE}" image inspect \
        --format "{{ if .Config.Labels }}{{ index .Config.Labels \"${IMAGE_STAMP_LABEL}\" }}{{ end }}" \
        "${IMAGE}" 2>/dev/null)" || return 1
    [ "${image_hash}" = "${CONTAINERFILE_HASH}" ]
}

if ! image_is_current; then
    "${ENGINE}" build \
        --label "${IMAGE_STAMP_LABEL}=${CONTAINERFILE_HASH}" \
        -t "${IMAGE}" -f "${CONTAINERFILE}" "${ROOT_DIR}/container"
fi

mkdir -p "${HOME}/.gradle"

# Relabel bind mounts when SELinux is enforcing.
VOLUME_SUFFIX=""
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" = "Enforcing" ]; then
    VOLUME_SUFFIX=":Z"
fi

TTY_FLAGS=(-i)
if [ -t 0 ] && [ -t 1 ]; then
    TTY_FLAGS+=(-t)
fi

RUN_ARGS=(
    --rm
    "${TTY_FLAGS[@]}"
    --user "$(id -u):$(id -g)"
    -e HOME=/tmp
    -e JAVA_TOOL_OPTIONS=-Duser.home=/tmp
    -e ANDROID_USER_HOME=/tmp/.android
    -e ANDROID_SDK_HOME=/tmp
    -e GRADLE_USER_HOME=/gradle-cache
    -v "${ROOT_DIR}:/workspace${VOLUME_SUFFIX}"
    -v "${HOME}/.gradle:/gradle-cache${VOLUME_SUFFIX}"
    -w /workspace
)

# Docker supports --user directly. Rootless Podman needs keep-id so the
# container UID maps back to the invoking user on the host.
if [ "$(basename "${ENGINE}")" = "podman" ]; then
    RUN_ARGS=(--userns=keep-id "${RUN_ARGS[@]}")
fi

if [ "$#" -eq 0 ]; then
    set -- bash
fi

# Run Gradle tasks through the wrapper. Using "bash ./gradlew" keeps this
# working even when the checked-out gradlew lacks the executable bit.
case "$1" in
    gradle)
        shift
        set -- bash ./gradlew "$@"
        ;;
    :*)
        set -- bash ./gradlew "$@"
        ;;
    ./gradlew|gradlew)
        shift
        set -- bash ./gradlew "$@"
        ;;
esac

exec "${ENGINE}" run "${RUN_ARGS[@]}" "${IMAGE}" "$@"
