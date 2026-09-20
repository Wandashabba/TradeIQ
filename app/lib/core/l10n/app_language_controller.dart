import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/secure_storage.dart';

/// The agent's language choice (#40). [system] follows the device; the others
/// pin the UI to one supported locale regardless of the device.
enum AppLanguage {
  system(null, 'system'),
  english(Locale('en'), 'en'),
  afrikaans(Locale('af'), 'af');

  const AppLanguage(this.locale, this.storageValue);

  /// The locale handed to `MaterialApp.locale` — null means "use the device's".
  final Locale? locale;

  /// How the choice is written to storage.
  final String storageValue;
}

/// Persists the language override across restarts. Abstracted exactly like
/// [ThemeModeStore] so tests use an in-memory fake, never the keychain.
abstract class AppLanguageStore {
  /// The persisted choice, or null when missing/unreadable — caller keeps
  /// [AppLanguage.system].
  Future<AppLanguage?> read();

  Future<void> write(AppLanguage language);
}

class SecureAppLanguageStore implements AppLanguageStore {
  SecureAppLanguageStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;

  static const _key = 'tiq.language';

  @override
  Future<AppLanguage?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      for (final language in AppLanguage.values) {
        if (language.storageValue == raw) return language;
      }
      return null;
    } catch (_) {
      return null; // unreadable → follow the device, never a crash on startup
    }
  }

  @override
  Future<void> write(AppLanguage language) async {
    try {
      await _storage.write(key: _key, value: language.storageValue);
    } catch (_) {
      // Best-effort: an unpersisted choice still applies for this run.
    }
  }
}

final appLanguageStoreProvider = Provider<AppLanguageStore>(
  (ref) => SecureAppLanguageStore(),
);

/// Defaults to [AppLanguage.system] (device locale) and restores a persisted
/// override asynchronously, the same shape as the theme controller.
class AppLanguageController extends Notifier<AppLanguage> {
  bool _userChose = false;

  @override
  AppLanguage build() {
    Future.microtask(_restore); // build() must return synchronously
    return AppLanguage.system;
  }

  Future<void> _restore() async {
    final saved = await ref.read(appLanguageStoreProvider).read();
    // A choice made while the restore was in flight is the newer intent.
    if (saved != null && !_userChose) state = saved;
  }

  Future<void> select(AppLanguage language) async {
    _userChose = true;
    state = language;
    await ref.read(appLanguageStoreProvider).write(language);
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );
