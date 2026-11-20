#!/usr/bin/env bash
#
# Run a command inside the containerized AndFlmsg build environment.
#
# Examples:
#   ./scripts/podman-build.sh :andFlmsg:assembleDebug
#   ./scripts/podman-build.sh :andFlmsg:assembleRelease
#   ./scripts/podman-build.sh bash
#
# The image is built on first use. Nothing (JDK, Android SDK, NDK) is
# installed on the host.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${ANDFLMSG_BUILD_IMAGE:-localhost/andflmsg-build:latest}"
CONTAINERFILE="${ROOT_DIR}/container/Containerfile"

if ! podman image exists "${IMAGE}"; then
    podman build -t "${IMAGE}" -f "${CONTAINERFILE}" "${ROOT_DIR}/container"
fi

mkdir -p "${HOME}/.gradle"

TTY_FLAGS=(-i)
if [ -t 0 ] && [ -t 1 ]; then
    TTY_FLAGS+=(-t)
fi

if [ "$#" -eq 0 ]; then
    set -- bash
fi

exec podman run --rm "${TTY_FLAGS[@]}" \
    -v "${ROOT_DIR}:/workspace:Z" \
    -v "${HOME}/.gradle:/root/.gradle:Z" \
    -w /workspace \
    "${IMAGE}" \
    "$@"
