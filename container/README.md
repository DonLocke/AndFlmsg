# Containerized build environment

This directory contains the Podman image used to build AndFlmsg without
installing a JDK, Android SDK, or NDK on the host.

## Requirements

- Podman
- Network access for the first image build

## Build the image

```bash
podman build -t localhost/andflmsg-build:latest -f container/Containerfile container/
```

The image is based on Eclipse Temurin JDK 17 and pins:

- Android command-line tools `15859902`
- Platform `android-35`
- Build tools `35.0.0`
- NDK `25.2.9519653`

## Run Gradle

Use the wrapper script:

```bash
./scripts/podman-build.sh :andFlmsg:assembleDebug
./scripts/podman-build.sh :andFlmsg:assembleRelease
```

The repository is mounted at `/workspace`, and the host Gradle cache is
mounted at `/root/.gradle` so dependencies are reused between runs.

For an interactive shell:

```bash
./scripts/podman-build.sh bash
```

## Verify the toolchain

```bash
./scripts/podman-build.sh java -version
./scripts/podman-build.sh sdkmanager --version
./scripts/podman-build.sh ndk-build --version
```

The image is built once and cached by Podman. Rebuild it with `podman build`
after changing the versions in `Containerfile`.
