import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Which build of the app this is, as sent on every request (#400).
///
/// ## Why a compile-time constant and not a plugin
///
/// `package_info_plus` would read the version off the platform at runtime, but
/// it is a federated plugin with a platform channel on every target — one more
/// thing every widget test has to fake — for a value the build already knows.
/// So the build states it: `--dart-define=APP_VERSION=1.4.0` (and
/// `APP_BUILD=37`) on a release build, and the default below otherwise.
///
/// The default is **pubspec's version**, and `app_version_test.dart` fails the
/// day the two disagree — so a build that forgets the define still reports the
/// version it was cut from, not some older number that would lock it out.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// The build number. Not compared by the server; there so support can tell two
/// builds of one version apart when a stuck outbox row is being traced.
const appBuild = String.fromEnvironment('APP_BUILD', defaultValue: '1');

/// The headers every request carries. The server records them; only
/// `X-App-Version` is compared against its floor.
const appVersionHeader = 'X-App-Version';
const appBuildHeader = 'X-App-Build';

/// The `code` a 426 carries when the server's `MIN_APP_VERSION` is above this
/// build. Matched as a constant, never as prose.
const appUpdateRequiredCode = 'app_update_required';

/// The server has refused this build as too old.
@immutable
class AppUpdateRequired {
  const AppUpdateRequired({this.minimumVersion});

  /// The oldest version the server accepts, when it said. Null when it did
  /// not — the screen then says "a newer version" without a number, rather
  /// than inventing one.
  final String? minimumVersion;

  /// Reads a 426 response. Null for anything that is not the version gate's
  /// refusal, including a 426 some proxy sent for its own reasons: the "update
  /// the app" screen is a dead end, and it must only ever be shown when the
  /// server really said so.
  static AppUpdateRequired? fromError(DioException error) {
    final response = error.response;
    if (response?.statusCode != 426) return null;
    final body = response?.data;
    if (body is! Map || body['code'] != appUpdateRequiredCode) return null;
    final minimum = body['minimumVersion'];
    return AppUpdateRequired(
      minimumVersion: minimum is String && minimum.isNotEmpty ? minimum : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUpdateRequired && other.minimumVersion == minimumVersion;

  @override
  int get hashCode => minimumVersion.hashCode;
}

/// Set by the API client when the server refuses this build; read by the
/// router, which sends every route to `/update-required` while it is set.
///
/// A plain [ValueNotifier] rather than a provider for the same reason
/// `onUnauthorized` is a hook: `api_client.dart` is Dio setup with no provider
/// container, and the router's `refreshListenable` takes a [Listenable]
/// directly. Cleared by the screen's "Try again"; the next request sets it
/// again if the build is still too old.
final appUpdateRequired = ValueNotifier<AppUpdateRequired?>(null);
