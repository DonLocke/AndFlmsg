# Containerized build environment

Build AndFlmsg without installing a JDK, Android SDK, or NDK on the host.

## Requirements

- Podman or Docker
- Network access for the first image build

## Build and run

The wrapper builds the image (using the engine cache) and runs the command
inside it:

```bash
./scripts/container-build.sh :andFlmsg:assembleDebug
```

The debug APK is written to `andFlmsg/build/outputs/apk/debug/`.

Task names must be fully qualified: the leading `:` (or a `gradle` prefix) is
what tells the wrapper to run the command through `./gradlew`. A bare task such
as `assembleDebug` is treated as a container command and fails.

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
- Gradle `8.9` / Android Gradle Plugin `8.7.3`
- Platform `android-35` (compileSdk 35, targetSdk 33)
- Build tools `35.0.0`
- NDK `21.4.7075529` (r21e)

The SDK and NDK versions are also set in `andFlmsg/build.gradle`, and they are
preinstalled in the image. Bump them in both places and rebuild the image.

## Local vs release builds

Use `:andFlmsg:assembleDebug` locally. The local `:andFlmsg:assembleRelease`
target currently uses the debug signing config and is only for build testing;
do not distribute it.

There is no CI release workflow yet; publishable release APKs will be built in
CI with a dedicated release keystore once that workflow exists.

## Engine notes

The wrapper arranges the run so build outputs and the Gradle cache stay owned
by you:

- **Podman:** uses `--userns=keep-id`, which maps the invoking user to the
  same UID/GID inside the container. Rootful Podman (running the wrapper as
  root) is not supported.
- **Docker:** uses `--user "$(id -u):$(id -g)"` for a rootful daemon; for
  rootless Docker the wrapper omits it because container root already maps to
  the invoking user. This path is implemented but has not been exercised yet.

The host Gradle cache and `~/.android` are mounted so dependencies and the
debug keystore persist between runs.
