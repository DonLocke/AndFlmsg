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

: "${HOME:?HOME must be set}"

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${ANDFLMSG_BUILD_IMAGE:-localhost/andflmsg-build:latest}"
CONTAINERFILE="${ROOT_DIR}/container/Containerfile"
IMAGE_STAMP_LABEL="dev.andflmsg.containerfile-sha256"

hash_stream() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        cksum | awk '{print $1 "-" $2}'
    fi
}

# Hash the image inputs: the Containerfile plus any other files in the build
# context (excluding the human-readable README). The current context has no
# extra files, so this is the same hash as the Containerfile alone, but future
# COPY instructions cannot silently leave a stale image behind.
CONTAINERFILE_HASH="$(
    cd "${ROOT_DIR}/container" || exit 1
    {
        cat Containerfile
        find . -type f ! -name 'Containerfile' ! -name 'README.md' -print \
            | LC_ALL=C sort \
            | while IFS= read -r context_file; do
                  printf '== %s ==\n' "${context_file}"
                  cat "${context_file}"
              done
    } | hash_stream
)"

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

# Rootless Docker already maps container root to the invoking host user, so it
# must not be given an explicit --user (that would map to a subuid and make the
# bind mounts unwritable).
is_rootless_docker() {
    [ "$(basename "${ENGINE}")" = "docker" ] || return 1
    local security_options
    security_options="$("${ENGINE}" info --format '{{.SecurityOptions}}' 2>/dev/null)" || return 1
    case "${security_options}" in
        *rootless*) return 0 ;;
        *) return 1 ;;
    esac
}

# Rebuild when the image is missing or was built from different inputs.
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

mkdir -p "${HOME}/.gradle" "${HOME}/.android"

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
    -e HOME=/tmp
    -e JAVA_TOOL_OPTIONS=-Duser.home=/tmp
    -e ANDROID_USER_HOME=/tmp/.android
    -e ANDROID_SDK_HOME=/tmp
    -e GRADLE_USER_HOME=/gradle-cache
    -v "${ROOT_DIR}:/workspace${VOLUME_SUFFIX}"
    -v "${HOME}/.gradle:/gradle-cache${VOLUME_SUFFIX}"
    # Persist the Android user home so the debug keystore stays stable across
    # debug builds. Release signing is handled by CI.
    -v "${HOME}/.android:/tmp/.android${VOLUME_SUFFIX}"
    -w /workspace
)

# Rootful Docker runs as the invoking UID/GID. Rootless Docker is handled by
# is_rootless_docker() above.
if ! is_rootless_docker; then
    RUN_ARGS+=(--user "$(id -u):$(id -g)")
fi

# Rootless Podman needs keep-id so the container UID maps back to the invoking
# user on the host.
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
