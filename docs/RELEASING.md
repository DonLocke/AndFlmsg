# Releasing AndFlmsg

Releases are built only by the `Release` GitHub Actions workflow. No signing
key, keystore password, or release APK needs to exist on a workstation.

## Version source

`version.properties` in the repository root is the single source of truth:

```properties
versionCode=5
versionName=1.8.0.0-rc.2
versionDate=20261121
```

Both Gradle and the release workflow read it. The Android manifest intentionally
does not contain `android:versionCode` or `android:versionName`. A release tag
must be exactly `v<versionName>` (for example `v1.8.0.0-rc.2`), and the workflow
fails if the tag and file disagree. Increment `versionCode` for every published
build, including release candidates.

## Release keystore

Generate the key on an offline machine, not on a build host or workstation that
will later run CI. Use a long validity period so Obtainium users do not have to
reinstall when the certificate expires.

```bash
export STORE_PASS='<strong store password>'
export KEY_PASS='<strong key password>'

keytool -genkeypair -v \
  -keystore andflmsg-release.p12 \
  -storetype PKCS12 \
  -alias andflmsg \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=AndFlmsg Release, O=AndFlmsg, C=AU"
```

Make an encrypted offline backup of `andflmsg-release.p12` and store the alias
and both passwords separately from the key. Losing this key means existing
installations cannot receive updates signed with the same identity.

Create the secret payload without writing it into the repository:

```bash
base64 -w0 andflmsg-release.p12 > andflmsg-release.p12.b64
```

Never commit `andflmsg-release.p12`, its base64 form, `keystore.properties`, or
the passwords. `.gitignore` already excludes PKCS12/JKS keystores and their
base64 forms, plus `keystore.properties`.

## GitHub Actions secrets

Set these repository secrets (`Settings -> Secrets and variables -> Actions`, or
with `gh secret set`):

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the release keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias, for example `andflmsg` |
| `ANDROID_KEY_PASSWORD` | Key password |

Example (run from the directory containing the files, on a trusted machine):

```bash
gh secret set ANDROID_KEYSTORE_BASE64 < andflmsg-release.p12.b64
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD
```

The release workflow decodes the keystore into `$RUNNER_TEMP`, builds, verifies,
and deletes it at the end. It is never added to the workspace or uploaded.

Gradle also accepts `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` for a local release build, but
the intended path is CI. Release packaging fails closed if all four are not set,
so an unsigned or debug-signed APK cannot be published by mistake.

## Tagging a release

1. Update `version.properties` (versionCode is monotonic; versionName is the
   user-visible version; update `versionDate`).
2. Open a pull request and wait for the required `build` check to pass.
3. Merge to `master`.
4. Create an annotated tag matching the version:

   ```bash
   git checkout master
   git pull --ff-only
   git tag -a v1.8.0.0-rc.2 -m "AndFlmsg 1.8.0.0-rc.2"
   git push origin v1.8.0.0-rc.2
   ```

Release-candidate tags such as `v1.8.0.0-rc.2` use the same workflow. The
workflow creates a normal GitHub Release (not a GitHub prerelease) so Obtainium
picks it up without requiring prerelease support to be enabled. Bump
`versionCode` again before the final `1.8.0.0` release.

The tag push starts `.github/workflows/release.yml`. The workflow:

- asserts that `v<versionName>` equals the pushed tag;
- installs JDK 21 and the pinned Android SDK/NDK on the GitHub-hosted runner;
- builds `:andFlmsg:assembleRelease`;
- verifies the APK with `apksigner verify` and checks the version code/name;
- writes a SHA-256 checksum;
- creates the GitHub Release with the APK and `.sha256` file.

The container image is still available for local builds but is no longer used by
CI or the release workflow.

## Dry run

The workflow can be dispatched manually without creating a release. It still
needs the four signing secrets, and the result is uploaded as a workflow
artifact:

```bash
gh workflow run release.yml --ref <branch> -f tag=v1.8.0.0-rc.2
gh run watch
```

Leave `tag` empty to skip the tag comparison; pass it to exercise the comparison.
A dispatch never publishes a GitHub Release.

## Obtainium

Obtainium can track this repository directly:

- Add `https://github.com/DonLocke/AndFlmsg` as an app source.
- Use GitHub Releases as the source and filter APK assets with
  `andFlmsg-.*\.apk`.
- Obtainium can use the release tag or the APK version name for the displayed
  version. The APK's `versionCode` is authoritative for update ordering.
- Release candidates are published as normal releases by this workflow, so
  Obtainium sees them without changing its prerelease settings. The tag still
  sorts below the eventual final `v1.8.0.0`; users on an RC can update to the
  final build because its `versionCode` is higher.

### Uninstall the upstream build once

The upstream AndFlmsg APK is signed with a different key. Android refuses to
update an installed app when the signing certificate changes. Before installing
the first release from this repository, **uninstall the upstream build once**.
Uninstalling removes app data, so export anything you need first. After that,
updates from this repository install normally because every release uses the
same release key.

Builds from this repository before `1.8.0.0-rc.2` used the `com.AndFlmsg`
package. From `1.8.0.0-rc.2` onward the package is `com.donlocke.andflmsg`, so
Android treats the two as separate apps: an existing `com.AndFlmsg` install
will not update in place and both will appear in the launcher. Export any data
from the old install before uninstalling it.

Do not publish a release signed with a debug key or a different keystore: users
would have to uninstall again. Keep the offline keystore backup safe for the
lifetime of the app.
