import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/auth/session_controller.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/features/clients/data/clients_repository.dart';
import 'package:tradeiq_app/features/clients/data/iana_time_zones.dart';
import 'package:tradeiq_app/features/clients/presentation/client_config_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _config = ClientConfig(
  name: 'Acme Beverages',
  scorecardWeights: {
    'availability': 0.3,
    'visibility': 0.2,
  },
  // Deliberately partial: only `green` is stored. The other three keys must
  // fall back to what the engine already uses, not to zero.
  kpiThresholds: {'green': 80.0},
);

class _FakeClientsRepository implements ClientsRepository {
  _FakeClientsRepository({this.timezone = defaultClientTimeZone});

  Map<String, double>? savedWeights;
  Map<String, double>? savedThresholds;
  String? savedTimezone;

  /// What the server currently holds; a save moves it, so a re-read shows it.
  String timezone;

  @override
  Future<ClientConfig> getConfig() async => ClientConfig(
        name: _config.name,
        scorecardWeights: _config.scorecardWeights,
        kpiThresholds: _config.kpiThresholds,
        timezone: timezone,
      );

  @override
  Future<ClientConfig> updateTimezone(String timezone) async {
    savedTimezone = timezone;
    this.timezone = timezone;
    return getConfig();
  }

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async {
    savedWeights = weights;
    return ClientConfig(
      name: _config.name,
      scorecardWeights: weights,
      kpiThresholds: _config.kpiThresholds,
    );
  }

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async {
    savedThresholds = thresholds;
    return ClientConfig(
      name: _config.name,
      scorecardWeights: _config.scorecardWeights,
      kpiThresholds: thresholds,
    );
  }
}

/// Loads fine, refuses to save — the 403 an admin-only endpoint returns to a
/// caller who is not one.
class _RejectingClientsRepository implements ClientsRepository {
  @override
  Future<ClientConfig> getConfig() async => _config;

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async =>
      throw DioException(
        requestOptions: RequestOptions(path: '/clients/me'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/clients/me'),
          statusCode: 403,
        ),
      );

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async =>
      throw Exception('boom');

  @override
  Future<ClientConfig> updateTimezone(String timezone) async =>
      throw Exception('boom');
}

/// Loads fine; every timezone save fails with [error].
class _TimezoneFailureRepository extends _FakeClientsRepository {
  _TimezoneFailureRepository(this.error);

  final Object error;

  @override
  Future<ClientConfig> updateTimezone(String timezone) async => throw error;
}

class _ThrowingClientsRepository implements ClientsRepository {
  @override
  Future<ClientConfig> getConfig() async => throw Exception('boom');

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async =>
      throw Exception('boom');

  @override
  Future<ClientConfig> updateThresholds(Map<String, double> thresholds) async =>
      throw Exception('boom');

  @override
  Future<ClientConfig> updateTimezone(String timezone) async =>
      throw Exception('boom');
}

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._role);
  final String _role;

  @override
  Future<SessionState> build() async => SessionState(role: _role);
}

/// Defaults to an admin: PATCH /clients/me is admin-only, so that is the role
/// the editing tests are about.
Widget _app(
  ClientsRepository repo, {
  String role = 'admin',
  ThemeData? theme,
}) => routedApp(
      const ClientConfigScreen(),
      theme: theme,
      overrides: [
        clientsRepositoryProvider.overrideWithValue(repo),
        sessionControllerProvider.overrideWith(
          () => _FixedSessionController(role),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('light: the read-only notice is opaque and rimmed; shares are mono',
      (tester) async {
    await _pump(
      tester,
      _app(_FakeClientsRepository(), role: 'manager', theme: AppTheme.light()),
    );

    const t = TiqColors.light;
    final notice = tester.widget<Container>(
      find.byKey(const ValueKey<String>('read-only-notice')).first,
    );
    final deco = notice.decoration! as BoxDecoration;
    // An opaque ground, so its words measure against the colour on screen.
    expect(deco.color, t.surface2);
    expect(deco.color!.a, 1.0);
    expect((deco.border! as Border).top.color, LumenPalette.light.panelRim);
    expect(contrastRatio(t.ink3, t.surface2), greaterThanOrEqualTo(4.5));

    expect(
      tester.widget<Text>(find.text('60.0%')).style!.fontFamily,
      LumenGlass.mono,
    );
  });

  testWidgets('dark: the share figure keeps its flat style', (tester) async {
    await _pump(tester, _app(_FakeClientsRepository()));

    expect(tester.widget<Text>(find.text('60.0%')).style!.fontFamily, isNull);
  });

  testWidgets('renders a weight field for each scorecard weight', (tester) async {
    await _pump(tester, _app(_FakeClientsRepository()));

    expect(find.byKey(const ValueKey<String>('weight-availability')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('weight-visibility')),
        findsOneWidget);
  });

  testWidgets('saving submits the parsed weights map', (tester) async {
    final repo = _FakeClientsRepository();
    await _pump(tester, _app(repo));

    await tester.enterText(
      find.byKey(const ValueKey<String>('weight-availability')),
      '0.5',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-config')));
    await tester.pumpAndSettle();

    expect(repo.savedWeights, {'availability': 0.5, 'visibility': 0.2});
  });

  testWidgets('exposes exactly the four thresholds the engine reads', (
    tester,
  ) async {
    // The seed used to write excellent/good/needsImprovement, which no code path
    // reads — a UI over those keys would have been controls that do nothing.
    await _pump(tester, _app(_FakeClientsRepository()));

    for (final key in const [
      'green',
      'amber',
      'stockoutUnits',
      'priceDeviationPct',
    ]) {
      expect(
        find.byKey(ValueKey<String>('threshold-$key')),
        findsOneWidget,
        reason: 'missing threshold $key',
      );
    }
  });

  testWidgets('an absent threshold shows the engine default, not zero', (
    tester,
  ) async {
    final repo = _FakeClientsRepository();
    await _pump(tester, _app(repo));

    // Only `green` is stored. Saving must send the engine's real fallbacks for
    // the rest — sending 0 would turn "price deviation over 10%" into "over 0%"
    // and open a task on every single price row.
    await tester.tap(find.byKey(const ValueKey<String>('save-thresholds')));
    await tester.pumpAndSettle();

    expect(repo.savedThresholds, {
      'green': 80.0,
      'amber': 60.0,
      'stockoutUnits': 0.0,
      'priceDeviationPct': 10.0,
    });
  });

  testWidgets('saving submits an edited threshold', (tester) async {
    final repo = _FakeClientsRepository();
    await _pump(tester, _app(repo));

    await tester.enterText(
      find.byKey(const ValueKey<String>('threshold-priceDeviationPct')),
      '5',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-thresholds')));
    await tester.pumpAndSettle();

    expect(repo.savedThresholds?['priceDeviationPct'], 5.0);
  });

  testWidgets('shows an error message when the config fails to load',
      (tester) async {
    await _pump(tester, _app(_ThrowingClientsRepository()));

    expect(find.textContaining('Failed to load config'), findsOneWidget);
  });

  testWidgets('a manager sees the config, but cannot save it', (tester) async {
    // PATCH /clients/me is admin-only. Showing a manager an editable form and a
    // Save button meant they filled it in and got a 403 — which arrived as an
    // UNHANDLED exception and crashed the screen.
    await _pump(tester, _app(_FakeClientsRepository(), role: 'manager'));

    expect(find.byKey(const ValueKey<String>('read-only-notice')), findsWidgets);
    expect(find.byKey(const ValueKey<String>('save-config')), findsNothing);
    expect(find.byKey(const ValueKey<String>('save-thresholds')), findsNothing);

    // And the fields they cannot save are not typeable either.
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('weight-availability')),
    );
    expect(field.enabled, isFalse);
  });

  testWidgets('a 403 is reported in words, not thrown as an exception', (
    tester,
  ) async {
    await _pump(tester, _app(_RejectingClientsRepository()));

    // Before, this escaped as an unhandled DioException and crashed the screen.
    await tester.tap(find.byKey(const ValueKey<String>('save-config')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Only an administrator can change scoring config.'),
      findsOneWidget,
    );
  });

  group('timezone (#309)', () {
    Finder option(String zone) =>
        find.byKey(ValueKey<String>('timezone-option-$zone'));
    String shownZone(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey<String>('timezone-value')))
        .data!;

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey<String>('change-timezone')));
      await tester.pumpAndSettle();
    }

    Future<void> pickBySearch(
      WidgetTester tester,
      String query,
      String zone,
    ) async {
      await openPicker(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('timezone-search')),
        query,
      );
      await tester.pumpAndSettle();
      await tester.tap(option(zone));
      await tester.pumpAndSettle();
    }

    group('timezoneOptions', () {
      test('offers Johannesburg first, then everything else exactly once', () {
        final options = timezoneOptions('', current: 'Africa/Johannesburg');
        expect(options.suggested, ['Africa/Johannesburg']);
        expect(options.all, isNot(contains('Africa/Johannesburg')));
        expect(options.all.length, ianaTimeZones.length - 1);
      });

      test('keeps the current zone beside the suggestion', () {
        final options = timezoneOptions('', current: 'Europe/London');
        expect(options.suggested, ['Africa/Johannesburg', 'Europe/London']);
        expect(options.all, isNot(contains('Europe/London')));
      });

      test('matches case-insensitively, reading a space as an underscore', () {
        expect(
          timezoneOptions('new york', current: 'UTC').all,
          ['America/New_York'],
        );
        final johann = timezoneOptions('JOHANN', current: 'UTC');
        expect(johann.suggested, isEmpty);
        expect(johann.all.first, 'Africa/Johannesburg');
        expect(timezoneOptions('Atlantis', current: 'UTC').all, isEmpty);
      });

      test('offers only names the server accepts', () {
        // Canonical IANA names plus UTC — never an offset or an abbreviation.
        expect(ianaTimeZones, contains('Africa/Johannesburg'));
        expect(ianaTimeZones, contains('UTC'));
        expect(ianaTimeZones.where((z) => z.startsWith('+')), isEmpty);
        expect(ianaTimeZones, isNot(contains('SAST')));
      });
    });

    for (final (name, theme, ink, rim) in [
      ('light', AppTheme.light(), TiqColors.light, LumenPalette.light.panelRim),
      ('night', AppTheme.dark(), TiqColors.night, LumenPalette.dark.panelRim),
    ]) {
      testWidgets('$name: loads the zone on an opaque, rimmed ground', (
        tester,
      ) async {
        await _pump(
          tester,
          _app(
            _FakeClientsRepository(timezone: 'America/New_York'),
            role: 'manager',
            theme: theme,
          ),
        );

        expect(shownZone(tester), 'America/New_York');
        final ground = tester.widget<Container>(
          find.byKey(const ValueKey<String>('timezone-current')),
        );
        final deco = ground.decoration! as BoxDecoration;
        expect(deco.color, ink.surface2);
        expect(deco.color!.a, 1.0);
        expect((deco.border! as Border).top.color, rim);
        expect(contrastRatio(ink.ink1, ink.surface2), greaterThanOrEqualTo(4.5));

        // The picker opens in the same theme, with the current zone ticked.
        await openPicker(tester);
        expect(
          find.byKey(const ValueKey<String>('timezone-search')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: option('America/New_York'),
            matching: find.byKey(const ValueKey<String>('timezone-selected')),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('a manager finds a zone by searching, and it is saved', (
      tester,
    ) async {
      final repo = _FakeClientsRepository();
      await _pump(tester, _app(repo, role: 'manager'));
      expect(shownZone(tester), 'Africa/Johannesburg');

      await pickBySearch(tester, 'new york', 'America/New_York');

      expect(repo.savedTimezone, 'America/New_York');
      expect(find.text('Timezone set to America/New_York'), findsOneWidget);
      expect(shownZone(tester), 'America/New_York');
    });

    testWidgets('lists Johannesburg first, ahead of the current zone and the rest',
        (tester) async {
      await _pump(
        tester,
        _app(_FakeClientsRepository(timezone: 'Europe/London')),
      );
      await openPicker(tester);

      final johannesburg = tester.getTopLeft(option('Africa/Johannesburg')).dy;
      final london = tester.getTopLeft(option('Europe/London')).dy;
      final firstOfAll = tester.getTopLeft(option('Africa/Abidjan')).dy;
      expect(johannesburg, lessThan(london));
      expect(london, lessThan(firstOfAll));
    });

    testWidgets('says so when nothing matches, and cancelling saves nothing', (
      tester,
    ) async {
      final repo = _FakeClientsRepository();
      await _pump(tester, _app(repo));
      await openPicker(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('timezone-search')),
        'Atlantis',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('timezone-no-match')),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.savedTimezone, isNull);
      expect(shownZone(tester), 'Africa/Johannesburg');
    });

    testWidgets("a rejected zone is reported in the server's words", (
      tester,
    ) async {
      const message =
          'timezone must be an IANA timezone name, e.g. Africa/Johannesburg';
      await _pump(
        tester,
        _app(
          _TimezoneFailureRepository(
            DioException(
              requestOptions: RequestOptions(path: '/clients/me'),
              response: Response<dynamic>(
                requestOptions: RequestOptions(path: '/clients/me'),
                statusCode: 400,
                data: {'error': message},
              ),
            ),
          ),
          role: 'manager',
        ),
      );

      await pickBySearch(tester, 'tokyo', 'Asia/Tokyo');

      expect(tester.takeException(), isNull);
      expect(find.text(message), findsOneWidget);
      expect(shownZone(tester), 'Africa/Johannesburg');
      // Usable again, not stuck on "Saving…".
      final change = tester.widget<TextButton>(
        find.byKey(const ValueKey<String>('change-timezone')),
      );
      expect(change.onPressed, isNotNull);
    });

    testWidgets('an unexpected failure is reported, not thrown', (tester) async {
      await _pump(
        tester,
        _app(_TimezoneFailureRepository(Exception('network down'))),
      );

      await pickBySearch(tester, 'tokyo', 'Asia/Tokyo');

      expect(tester.takeException(), isNull);
      expect(find.text('Could not save: Exception: network down'), findsOneWidget);
    });

    testWidgets('a field agent sees the zone but cannot change it', (
      tester,
    ) async {
      await _pump(tester, _app(_FakeClientsRepository(), role: 'field_agent'));

      expect(shownZone(tester), 'Africa/Johannesburg');
      expect(
        find.byKey(const ValueKey<String>('change-timezone')),
        findsNothing,
      );
    });
  });
}
