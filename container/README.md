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

The final image uses Eclipse Temurin JDK 11, which is compatible with the
project's Gradle 7.5.1 wrapper and AGP 7.4.2. The Android SDK is installed in a
temporary JDK 17 stage because the command-line tools require JDK 17. The
image pins:

- Android command-line tools `15859902`
- Platform `android-33`
- Build tools `33.0.2`
- NDK `21.4.7075529` (r21e)

## Run Gradle

The wrapper auto-detects `podman` first, then `docker`:

```bash
./scripts/container-build.sh :andFlmsg:assembleDebug
./scripts/container-build.sh :andFlmsg:assembleRelease
```

Arguments that start with `:` are passed to `./gradlew` automatically. You can
also invoke it explicitly:

```bash
./scripts/container-build.sh ./gradlew :andFlmsg:assembleDebug
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
./scripts/container-build.sh ndk-build --version
```

`sdkmanager` requires JDK 17 and is only used while building the image.

## Engine notes

Both engines run the container as your UID/GID, so build outputs and the
Gradle cache stay owned by you:

- **Podman:** uses `--userns=keep-id`.
- **Docker:** uses `--user "$(id -u):$(id -g)"`. This requires rootful Docker;
  with rootless Docker the UID maps to a subuid and files may not be owned by
  you.
- **SELinux:** the wrapper adds `:Z` to bind mounts automatically when
  `getenforce` reports `Enforcing`.

The image is built once and cached by the engine. Rebuild it after changing
the versions in `Containerfile`.
