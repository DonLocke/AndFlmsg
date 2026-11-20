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
- Platform `android-35` (compileSdk 35, targetSdk 33)
- Build tools `35.0.0`
- Platform tools `37.0.3` (SHA-256 verified)
- NDK `21.4.7075529` (r21e)

The Gradle wrapper pins Gradle `8.9` and Android Gradle Plugin `8.7.3`.
The SDK and NDK versions are also set in `andFlmsg/build.gradle` (or the
Containerfile for platform tools), and they are preinstalled in the image.
Platform tools is installed by the Containerfile rather than `sdkmanager`, so
the pinned version cannot be silently replaced. Bump the versions in both
places and rebuild the image.

Building without the container requires JDK 17; AGP 8.7 does not run on JDK 11.

## Local vs release builds

Use `:andFlmsg:assembleDebug` locally. Release APKs are built by the `Release`
GitHub Actions workflow with a keystore that exists only in repository secrets.
Release tasks fail closed when the signing environment variables are missing;
they are never debug-signed.

See [docs/RELEASING.md](../docs/RELEASING.md) for the key, secret, and tagging
procedure.

## CI image cache

CI builds the image with a GitHub Actions layer cache, then sets
`ANDFLMSG_SKIP_IMAGE_BUILD=1` so the wrapper reuses that image instead of
rebuilding it. `ANDFLMSG_EXTRA_VOLUME=HOST:CONTAINER` adds an optional bind mount;
the release workflow uses it to expose `$RUNNER_TEMP` for the keystore.

## Engine notes

The wrapper arranges the run so build outputs and the Gradle cache stay owned
by you:

- **Podman:** uses `--userns=keep-id`, which maps the invoking user to the
  same UID/GID inside the container. Rootful Podman (running the wrapper as
  root) is not supported.
- **Docker:** uses `--user "$(id -u):$(id -g)"` for a rootful daemon; for
  rootless Docker the wrapper omits it because container root already maps to
  the invoking user. CI exercises this path on every pull request.

The host Gradle cache and `~/.android` are mounted so dependencies and the
debug keystore persist between runs.
