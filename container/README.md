# Containerized build environment

This directory contains the OCI container image used to build AndFlmsg without
installing a JDK, Android SDK, or NDK on the host. It works with either Podman
or Docker.

## Requirements

- Podman **or** Docker
- Network access for the first image build

## Build the image

Use either engine:

```bash
podman build -t localhost/andflmsg-build:latest -f container/Containerfile container/
```

```bash
docker build -t localhost/andflmsg-build:latest -f container/Containerfile container/
```

The image is based on Eclipse Temurin JDK 17 and pins:

- Android command-line tools `15859902`
- Platform `android-35`
- Build tools `35.0.0`
- NDK `25.2.9519653`

## Run Gradle

The wrapper auto-detects `podman` first, then `docker`:

```bash
./scripts/container-build.sh :andFlmsg:assembleDebug
./scripts/container-build.sh :andFlmsg:assembleRelease
```

Select an engine explicitly:

```bash
CONTAINER_ENGINE=podman ./scripts/container-build.sh :andFlmsg:assembleDebug
CONTAINER_ENGINE=docker ./scripts/container-build.sh :andFlmsg:assembleDebug
```

The repository is mounted at `/workspace`, and the host Gradle cache is
mounted into the container so dependencies are reused between runs.

For an interactive shell:

```bash
./scripts/container-build.sh bash
```

## Verify the toolchain

```bash
./scripts/container-build.sh java -version
./scripts/container-build.sh sdkmanager --version
./scripts/container-build.sh ndk-build --version
```

## Engine notes

Both engines run the container as your UID/GID, so build outputs and the
Gradle cache stay owned by you:

- **Podman:** uses `--userns=keep-id`.
- **Docker:** uses `--user "$(id -u):$(id -g)"`.
- **SELinux:** the wrapper adds `:Z` to bind mounts automatically when
  `getenforce` reports `Enforcing`.

The image is built once and cached by the engine. Rebuild it after changing
the versions in `Containerfile`.
