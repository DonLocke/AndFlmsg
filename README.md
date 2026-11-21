AndFlmsg is a combination of Fldigi and Flmsg for portable devices running Android. 

The main objective of this development is to provide a low power highly-portable, as in mobile or backpack, Flmsg/Fldigi solution. 

The inclusion of modes like MT-63, Olivia and long interleave MFSK modes allows audio coupling to be used effectively without the need for an audio interface. 

The display and entry forms can be independently modified in order to match the screen real-estate of the target devices. 

It does basically most of what the fully featured version of FLMSG does.

Installable apk, manuals in the Releases section.

Release builds are signed in CI; see [docs/RELEASING.md](docs/RELEASING.md) for
the tagging and Obtainium procedure.

## Crash logs

Crash logs are stored locally at:

- **Android 10 and lower:** `<storage>/Android/data/com.donlocke.andflmsg/files/Documents/crash-logs/`
- **Android 11 and higher:** the same app-specific location, but system file
  managers and MTP may not expose `Android/data`. Enable Developer options →
  USB debugging and try:

  ```bash
  adb pull /sdcard/Android/data/com.donlocke.andflmsg/files/Documents/crash-logs/
  ```

  On some Android 11 builds adb may still report `Permission denied` for
  `Android/data`; on debuggable builds, use
  `adb shell run-as com.donlocke.andflmsg ls files/crash-logs` instead.

If external storage is unavailable or cannot be written, logs fall back to the
app-private files directory, which is only reachable on debuggable builds.

Crash logs are excluded from Android Auto Backup and device-to-device transfer.
They are not uploaded automatically. Only JVM uncaught exceptions are captured;
native crashes and ANRs are not recorded. On Android 6–9 (and Android 10 apps
using legacy external storage), other apps with storage permission may be able
to read the external crash logs.
