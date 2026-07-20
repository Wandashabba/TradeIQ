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

**Back up the keystore and its password.** Store the `.jks` somewhere durable
that is not this repo, and the password in a password manager. Recording the
certificate's SHA-256 fingerprint is worth it too — some Google services ask for
it during setup, and it is how you prove a build came from your key.

How bad losing it is depends on which signing scheme the app uses:

- **Play App Signing** (the default for apps first published since August 2021):
  Google holds the real app signing key, and yours is only an *upload* key. Lose
  it and you request an upload-key reset from Google — disruptive, but
  recoverable.
- **Legacy self-signed:** the key *is* the app's identity. Lose it and you can
  never ship an update under that application id. Not recoverable.

TradeIQ has not been published yet, so it will land on Play App Signing. Treat
the key as precious anyway — the recovery path is a support round-trip you would
rather not spend a release on.

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
