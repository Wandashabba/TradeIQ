import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the manager's theme choice across app restarts. Abstracted (like
/// TokenStore) so tests use an in-memory fake instead of the platform
/// keychain. Stored in the already-present flutter_secure_storage — not a
/// secret, but not worth a second storage stack.
abstract class ThemeModeStore {
  /// The persisted mode, or null when missing/unreadable — caller keeps dark.
  Future<ThemeMode?> read();

  Future<void> write(ThemeMode mode);
}

class SecureThemeModeStore implements ThemeModeStore {
  SecureThemeModeStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'tiq.themeMode';

  @override
  Future<ThemeMode?> read() async {
    try {
      return switch (await _storage.read(key: _key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => null,
      };
    } catch (_) {
      return null; // unreadable → dark, never a crash on startup
    }
  }

  @override
  Future<void> write(ThemeMode mode) async {
    try {
      await _storage.write(
        key: _key,
        value: mode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // Best-effort: an unpersisted toggle still applies for this run.
    }
  }
}

final themeModeStoreProvider =
    Provider<ThemeModeStore>((ref) => SecureThemeModeStore());

/// light/dark only — ThemeMode.system is deliberately out of scope (managers
/// on desktop web; two explicit modes are clearer than three). Default and
/// every failure path: dark, so nobody's console changes until they touch the
/// toggle.
class ThemeModeController extends Notifier<ThemeMode> {
  bool _userChose = false;

  @override
  ThemeMode build() {
    Future.microtask(_restore); // build() must return synchronously
    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    final saved = await ref.read(themeModeStoreProvider).read();
    // A toggle that raced the restore wins — it is the newer intent.
    if (saved != null && !_userChose) state = saved;
  }

  Future<void> toggle() async {
    _userChose = true;
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await ref.read(themeModeStoreProvider).write(state);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
