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

- Eclipse Temurin JDK 21 (base image pinned by digest)
- Android command-line tools `16111833` (SHA-256 verified)
- Platform `android-36` (compileSdk 36, targetSdk 33)
- Build tools `36.0.0`
- Platform tools `37.0.3` (SHA-256 verified)
- NDK `21.4.7075529` (r21e)

The Gradle wrapper pins Gradle `9.9.2` and Android Gradle Plugin `9.5.2`.
`compileSdk` and `ndkVersion` are set in `andFlmsg/build.gradle`; the platform,
build-tools and platform-tools versions are pinned in the Containerfile. AGP
9.5 uses build-tools `36.0.0` by default, which matches the image. Platform
tools is installed by the Containerfile rather than `sdkmanager`, so the pinned
version cannot be silently replaced. Bump the versions in the appropriate place
and rebuild the image.

Building without the container requires JDK 21. AGP 9.5 requires JDK 17 or
newer; the container and CI use JDK 21.

The NDK is intentionally pinned to r21e and `targetSdk` remains 33 while the
native sources and the Kotlin UI rewrite are pending. Do not bump either as
part of a routine toolchain update.

## Local vs release builds

Use `:andFlmsg:assembleDebug` locally. Release APKs are built by the `Release`
GitHub Actions workflow with a keystore that exists only in repository secrets.
Release tasks fail closed when the signing environment variables are missing;
they are never debug-signed.

See [docs/RELEASING.md](../docs/RELEASING.md) for the key, secret, and tagging
procedure.

## CI and release builds

CI and release builds run directly on GitHub-hosted runners with
`actions/setup-java`, `android-actions/setup-android`, and
`gradle/actions/setup-gradle`. The container image is kept for local development
so you can build with the same pinned toolchain without installing the SDK.

## Engine notes

The wrapper arranges the run so build outputs and the Gradle cache stay owned
by you:

- **Podman:** uses `--userns=keep-id`, which maps the invoking user to the
  same UID/GID inside the container. Rootful Podman (running the wrapper as
  root) is not supported.
- **Docker:** uses `--user "$(id -u):$(id -g)"` for a rootful daemon; for
  rootless Docker the wrapper omits it because container root already maps to
  the invoking user. This path can be exercised locally with
  `CONTAINER_ENGINE=docker`.

The host Gradle cache and `~/.android` are mounted so dependencies and the
debug keystore persist between runs.
