# Release builds & signing

How to produce an installable build for a real device, and how release signing
works in this repo.

## Release signing

Release credentials live in `app/android/key.properties`, which is **gitignored
and must never be committed** — along with the `.jks` it points at.

### One-time setup

```bash
keytool -genkey -v -keystore ~/tradeiq-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `app/android/key.properties.example` to `app/android/key.properties`
and fill in the four values.

**Keep the keystore and its password safe permanently.** Once an app is
published under an application id, losing the key means you can never ship an
update to it — Google will not re-key it for you. Back it up somewhere durable
that is not this repo.

### What happens if it's missing

The build still works: `app/android/app/build.gradle.kts` falls back to the
**debug** keystore so local release testing isn't blocked, and prints a loud
warning at configure time.

That fallback is convenience only. Debug keys are publicly known, so anyone can
sign a malicious update matching the package id. **A debug-signed APK is fine on
your own device and must not be distributed** — not to the Play Store, not to
testers you don't control.

The fallback is announced rather than silent on purpose: a *silent* debug
fallback is exactly what let #137 sit undetected, since debug and profile builds
behaved fine and only release was broken.

### Verifying which key signed an APK

```bash
$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

`CN=Android Debug` means the fallback was used. A real upload key shows the
distinguished name you entered during `keytool -genkey`.

## Building for a device

The API base URL is compiled in, so point the build at a backend the phone can
actually reach — `localhost` is the phone itself, not your machine:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend
```

See #149 for making the backend reachable (LAN IP, tunnel, or a real deploy).

Note that `--dart-define` values are embedded in the binary and are trivially
extractable. A base URL is fine; never pass a secret this way.

### Verifying the built APK

Permissions are merged at build time from several manifests, so check the
artifact rather than the source:

```bash
$ANDROID_HOME/build-tools/<version>/aapt2 dump permissions \
  build/app/outputs/flutter-apk/app-release.apk
```

`android.permission.INTERNET` must be present. If it is missing, the app will
install and run and every API call will fail — the failure mode #137 describes.
