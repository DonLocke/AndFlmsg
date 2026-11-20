# Containerized build environment

Build AndFlmsg without installing a JDK, Android SDK, or NDK on the host.
Works with Podman or Docker.

## Requirements

- Podman **or** Docker
- Network access for the first image build

## Build and run

The wrapper builds the image (using the engine cache) and runs the command
inside it:

```bash
./scripts/container-build.sh :andFlmsg:assembleDebug
```

The debug APK is written to `andFlmsg/build/outputs/apk/debug/`.

Select an engine explicitly:

```bash
CONTAINER_ENGINE=podman ./scripts/container-build.sh :andFlmsg:assembleDebug
CONTAINER_ENGINE=docker ./scripts/container-build.sh :andFlmsg:assembleDebug
```

For an interactive shell:

```bash
./scripts/container-build.sh bash
```

## Toolchain

- Eclipse Temurin JDK 17 (base image pinned by digest)
- Android command-line tools `15859902` (SHA-256 verified)
- Platform `android-33`
- Build tools `33.0.2`
- NDK `21.4.7075529` (r21e)

## Local vs release builds

Use `assembleDebug` locally. The local `assembleRelease` target currently uses
the debug signing config and is only for build testing; do not distribute it.
Publishable release APKs will be built in GitHub Actions with a dedicated
release keystore.

## Engine notes

Both engines run the container as your UID/GID, so build outputs and the
Gradle cache stay owned by you:

- **Podman:** uses `--userns=keep-id`.
- **Docker:** uses `--user "$(id -u):$(id -g)"` for a rootful daemon; for
  rootless Docker the wrapper omits it because container root already maps to
  the invoking user.
- **SELinux:** the wrapper adds `:Z` to bind mounts automatically when
  `getenforce` reports `Enforcing`.

The host Gradle cache and `~/.android` are mounted so dependencies and the
debug keystore persist between runs.
