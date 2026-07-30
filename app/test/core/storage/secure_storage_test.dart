import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/storage/secure_storage.dart';

void main() {
  test('macOS keychain access is pinned to the file-based keychain', () {
    // The plugin's default (`usesDataProtectionKeychain: true`) needs the
    // binary to carry a signed application-identifier. `flutter run -d macos`
    // signs ad-hoc, so every write fails with errSecMissingEntitlement
    // (-34018) — including the one that generates the local database's
    // encryption key, which stops a check-in from saving anything at all.
    final options = appSecureStorage.mOptions;

    expect(options, isA<MacOsOptions>());
    expect((options as MacOsOptions).usesDataProtectionKeychain, isFalse);
  });

  test('nothing else builds its own FlutterSecureStorage', () {
    // A `FlutterSecureStorage()` constructed inline anywhere silently takes
    // the failing default back for whatever secret it holds — and it would
    // fail only on macOS, only at runtime, with a -34018 nobody reads as a
    // configuration mistake. One instance, checked here, is the guarantee.
    const allowed = 'lib/core/storage/secure_storage.dart';

    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('secure_storage.dart'))
        .where((f) => f.readAsStringSync().contains('FlutterSecureStorage('))
        .map((f) => f.path)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'These construct their own secure storage instead of using '
          "appSecureStorage from '$allowed'.",
    );
  });
}
