import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the theme choice across restarts. Abstracted so the controller can
/// be unit-tested with an in-memory fake — same shape as auth's TokenStore.
abstract class ThemeModeStore {
  Future<String?> read();
  Future<void> write(String mode);
}

class SecureThemeModeStore implements ThemeModeStore {
  SecureThemeModeStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'tiq.themeMode';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String mode) => _storage.write(key: _key, value: mode);
}

final themeModeStoreProvider =
    Provider<ThemeModeStore>((ref) => SecureThemeModeStore());

/// Light/dark only — no `system` (managers on desktop web; two explicit modes
/// are clearer than three). Default and every failure path: dark, the app's
/// historical appearance. Persistence is best-effort: a failed write keeps the
/// in-memory choice for this session and stays silent.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    restore();
    return ThemeMode.dark;
  }

  Future<void> restore() async {
    try {
      final stored = await ref.read(themeModeStoreProvider).read();
      if (stored == 'light') state = ThemeMode.light;
    } catch (_) {
      // Unreadable storage -> keep dark.
    }
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      await ref
          .read(themeModeStoreProvider)
          .write(state == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {
      // Best-effort persistence.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
