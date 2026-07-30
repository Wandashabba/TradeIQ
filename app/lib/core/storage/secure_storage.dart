import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The app's single [FlutterSecureStorage] configuration.
///
/// Everything that keeps a secret — the auth session, the local database's
/// encryption key, the theme preference — goes through this one instance so
/// the platform options cannot drift between them. Three separate
/// `FlutterSecureStorage()` constructions is how one of them ends up
/// misconfigured and nobody notices until a device fails.
///
/// **macOS is pinned to the file-based keychain.** The plugin defaults to the
/// data protection keychain (`kSecUseDataProtectionKeychain = true`), which
/// requires the binary to carry a signed `application-identifier`. Debug
/// builds cannot: `flutter run -d macos` signs ad-hoc
/// (`CODE_SIGN_IDENTITY = "-"`). Every write then fails with
/// `errSecMissingEntitlement (-34018)` — including the write that generates
/// the local database's encryption key, so the database never opens and a
/// check-in cannot save. That failure was measured on a real machine, and so
/// was the remedy: the same write succeeds against the file-based keychain,
/// still sandboxed, with no entitlement changes.
///
/// Two alternatives were tried and rejected against the same probe:
/// declaring `keychain-access-groups` (the entitlement the plugin's README
/// asks for) makes the build fail outright without a development certificate,
/// and dropping the sandbox does not help, because the data protection
/// keychain wants a signing identity rather than a sandbox exception.
///
/// This is deliberately *not* debug-only. A macOS build that works under
/// `flutter run` and fails once signed is a worse trap than using the older
/// keychain on a platform that is not a shipping target. If macOS ever does
/// ship, give the target a real signing identity and revisit this in one
/// place — which is the point of it being one place.
const appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
