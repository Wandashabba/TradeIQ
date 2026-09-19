import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/agent_scaffold.dart';
import 'package:tradeiq_app/core/widgets/location_sharing_banner.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../helpers/routed_app.dart';

/// #153 T1 — the location notice and the always-visible sharing indicator.
final _base = LocationSettings(intervalSeconds: 120, noticeVersion: 'v1');

LocationSharingState _state({LocationConsent? consent, bool isAgent = true, bool noFix = false}) =>
    LocationSharingState(
      isAgent: isAgent,
      settings: _base.withDecision(
        consent == null
            ? null
            : LocationDecision(consent: consent, noticeVersion: 'v1', decidedAt: DateTime(2026, 9, 15)),
      ),
      running: consent == LocationConsent.acknowledged,
      noFix: noFix,
    );

class _FakeController extends LocationSharingController {
  _FakeController(this.initial);
  final LocationSharingState initial;
  int acknowledges = 0;
  int declines = 0;

  @override
  LocationSharingState build() => initial;

  @override
  Future<void> acknowledge() async {
    acknowledges++;
    state = _state(consent: LocationConsent.acknowledged);
  }

  @override
  Future<void> decline() async {
    declines++;
    state = _state(consent: LocationConsent.declined);
  }

  @override
  void reconsider() => state = LocationSharingState(
    isAgent: true,
    settings: state.settings,
    reconsidering: true,
  );
}

Widget _banner(_FakeController controller, {Locale? locale, ThemeData? theme}) => ProviderScope(
  overrides: [locationSharingControllerProvider.overrideWith(() => controller)],
  child: MaterialApp(
    theme: theme,
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    localeListResolutionCallback: resolveAppLocale,
    home: const Scaffold(body: SingleChildScrollView(child: LocationSharingBanner())),
  ),
);

void main() {
  // A sheet that a failing test left open would make the NEXT test's
  // `showTorchSheet` trip the no-stacking assert, and the failure would name
  // the wrong component. The counter is static, so it is reset per test.
  setUp(TorchSheets.resetForTest);

  const notice = ValueKey('location-notice');
  const indicator = ValueKey('location-sharing-indicator');
  const off = ValueKey('location-sharing-off');

  testWidgets('shows the notice before anything is shared, and acknowledging turns on the indicator', (tester) async {
    final controller = _FakeController(_state());
    await tester.pumpWidget(_banner(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(notice), findsOneWidget);
    expect(find.byKey(indicator), findsNothing);
    expect(find.text('Your location is shared with your manager'), findsOneWidget);
    expect(find.textContaining('every 2 minutes'), findsOneWidget);
    expect(find.textContaining('Nothing is sent in the background'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('location-notice-acknowledge')));
    await tester.pumpAndSettle();

    expect(controller.acknowledges, 1);
    expect(find.byKey(notice), findsNothing);
    expect(find.byKey(indicator), findsOneWidget);
    expect(find.text('Sharing your location with your manager'), findsOneWidget);
  });

  testWidgets('declining the notice shows a quiet "not shared" line that reopens it', (tester) async {
    final controller = _FakeController(_state());
    await tester.pumpWidget(_banner(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('location-notice-decline')));
    await tester.pumpAndSettle();
    expect(controller.declines, 1);
    expect(find.byKey(off), findsOneWidget);

    await tester.tap(find.byKey(off));
    await tester.pumpAndSettle();
    expect(find.byKey(notice), findsOneWidget);
  });

  testWidgets('the indicator offers to stop sharing, and confirming declines', (tester) async {
    final controller = _FakeController(_state(consent: LocationConsent.acknowledged));
    await tester.pumpWidget(_banner(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(indicator));
    await tester.pumpAndSettle();
    // The AlertDialog is gone: unify §1.7 deleted the dialog and a
    // non-dismissible bottom sheet covers every blocking case it covered. The
    // confirming press is the sheet's own destructive button, so it is found
    // by the word on it rather than by a key this file used to own.
    expect(find.byKey(const ValueKey('location-stop-dialog')), findsOneWidget);
    expect(find.text('Stop sharing your location?'), findsOneWidget);
    expect(
      find.text(
        'Your manager will no longer see where you are. '
        'You can turn it back on later.',
      ),
      findsOneWidget,
      reason: 'the POPIA consequence is stated before anything stops',
    );

    await tester.tap(find.text('Stop sharing'));
    await tester.pumpAndSettle();
    expect(controller.declines, 1);
    expect(find.byKey(indicator), findsNothing);
    expect(find.byKey(off), findsOneWidget);
  });

  testWidgets('says so when sharing is on but the phone gives no location', (tester) async {
    await tester.pumpWidget(_banner(_FakeController(_state(consent: LocationConsent.acknowledged, noFix: true))));
    await tester.pumpAndSettle();
    expect(find.byKey(indicator), findsOneWidget);
    expect(find.text('Sharing is on, but this phone isn’t giving TradeIQ a location'), findsOneWidget);
  });

  testWidgets('renders nothing for someone who is not a field agent', (tester) async {
    await tester.pumpWidget(_banner(_FakeController(_state(isAgent: false))));
    await tester.pumpAndSettle();
    expect(find.byKey(notice), findsNothing);
    expect(find.byKey(indicator), findsNothing);
    expect(find.byKey(off), findsNothing);
  });

  group('Afrikaans', () {
    testWidgets('the notice reads in Afrikaans', (tester) async {
      await tester.pumpWidget(_banner(_FakeController(_state()), locale: const Locale('af')));
      await tester.pumpAndSettle();
      expect(find.text('Jou ligging word met jou bestuurder gedeel'), findsOneWidget);
      expect(find.textContaining('elke 2 minute'), findsOneWidget);
      expect(find.text('Ek verstaan, deel my ligging'), findsOneWidget);
      expect(find.text('Moenie deel nie'), findsOneWidget);
    });

    testWidgets('the indicator and the stop dialog read in Afrikaans', (tester) async {
      await tester.pumpWidget(
        _banner(_FakeController(_state(consent: LocationConsent.acknowledged)), locale: const Locale('af')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Net terwyl TradeIQ oop is · tik om te stop'), findsOneWidget);

      await tester.tap(find.byKey(indicator));
      await tester.pumpAndSettle();
      expect(find.text('Hou op om jou ligging te deel?'), findsOneWidget);
      expect(find.text('Hou op deel'), findsOneWidget);
      expect(find.text('Bly deel'), findsOneWidget);
    });

    testWidgets('a one-minute interval uses the singular', (tester) async {
      final one = LocationSharingState(
        isAgent: true,
        settings: LocationSettings(intervalSeconds: 60, noticeVersion: 'v1'),
      );
      await tester.pumpWidget(_banner(_FakeController(one), locale: const Locale('af')));
      await tester.pumpAndSettle();
      expect(find.textContaining('elke minuut'), findsOneWidget);
    });
  });

  for (final (name, theme) in [('light', AppTheme.light()), ('night', AppTheme.dark())]) {
    testWidgets('notice and indicator render in the $name theme', (tester) async {
      final controller = _FakeController(_state());
      await tester.pumpWidget(_banner(controller, theme: theme));
      await tester.pumpAndSettle();
      expect(find.byKey(notice), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('location-notice-acknowledge')));
      await tester.pumpAndSettle();
      expect(find.byKey(indicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the indicator is visible in the agent shell', (tester) async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      routedApp(
        const AgentScaffold(title: 'Today', body: SizedBox.shrink(), showSyncChip: false),
        overrides: [
          localDbProvider.overrideWithValue(db),
          locationSharingControllerProvider.overrideWith(
            () => _FakeController(_state(consent: LocationConsent.acknowledged)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(indicator), findsOneWidget);
  });
}
