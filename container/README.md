# Containerized build environment

This directory contains the OCI container image used to build AndFlmsg without
installing a JDK, Android SDK, or NDK on the host. It works with either Podman
or Docker.

## Requirements

- Podman **or** Docker
- Network access for the first image build

## Build the image

The wrapper builds the image automatically on first use, so there is no
separate build step. To build it explicitly, run a harmless command through
the wrapper:

```bash
./scripts/container-build.sh java -version
```

If you build the image directly with `podman build` or `docker build`, pass the
same stamp label so the wrapper does not rebuild it:

```bash
STAMP="dev.andflmsg.containerfile-sha256=$(sha256sum container/Containerfile | awk '{print $1}')"
podman build --label "$STAMP" -t localhost/andflmsg-build:latest -f container/Containerfile container/
```

```bash
STAMP="dev.andflmsg.containerfile-sha256=$(sha256sum container/Containerfile | awk '{print $1}')"
docker build --label "$STAMP" -t localhost/andflmsg-build:latest -f container/Containerfile container/
```

On macOS, use `shasum -a 256` instead of `sha256sum`.

The final image uses Eclipse Temurin JDK 11, which is compatible with the
project's Gradle 7.5.1 wrapper and AGP 7.4.2. The Android SDK is installed in a
temporary JDK 17 stage because the command-line tools require JDK 17. The
image pins:

- Android command-line tools `15859902` and its SHA-256 checksum
- Platform `android-33`
- Build tools `33.0.2`
- NDK `21.4.7075529` (r21e)

`platform-tools` is installed at the latest version available when the image
is built; `sdkmanager` does not accept a version pin for that package.

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
mounted into the container so dependencies are reused between runs. The host
`~/.android` directory is also mounted at `/tmp/.android`, so debug builds keep
a stable debug keystore. Release signing will be handled by CI with a dedicated
release keystore.

For an interactive shell:

```bash
./scripts/container-build.sh bash
```

## Verify the toolchain

```bash
./scripts/container-build.sh java -version
./scripts/container-build.sh ndk-build --version
```

`sdkmanager` requires JDK 17; it is used only while building the image and is
not on the runtime `PATH`.

## Engine notes

Both engines run the container as your UID/GID, so build outputs and the
Gradle cache stay owned by you:

- **Podman:** uses `--userns=keep-id`.
- **Docker:** uses `--user "$(id -u):$(id -g)"` when the daemon is rootful.
  With rootless Docker the wrapper omits `--user`, because container root
  already maps to the invoking host user.
- **SELinux:** the wrapper adds `:Z` to bind mounts automatically when
  `getenforce` reports `Enforcing`.

The image is cached by the engine. The wrapper rebuilds it automatically when
the `Containerfile` (or another non-README file in `container/`) changes, so no
manual step is needed after updating a pin.
