import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/clients/data/clients_repository.dart';
import 'package:tradeiq_app/features/clients/data/iana_time_zones.dart';
import 'package:tradeiq_app/features/clients/presentation/client_config_screen.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';

const ClientConfig _config = ClientConfig(
  name: 'Acme Beverages',
  scorecardWeights: <String, double>{'availability': 0.3, 'visibility': 0.2},
  // Deliberately partial: only `green` is stored. The other three keys must
  // fall back to what the engine already uses, not to zero.
  kpiThresholds: <String, double>{'green': 80.0},
);

/// A `StateError`, never a bare `Exception`: Riverpod 3 retries anything that
/// is not an `Error`, so a widget test with an `Exception` fixture sits on the
/// loading skeleton and never reaches the error branch.
StateError offline() => StateError('SocketException: api.tradeiq.co.za');

class _FakeClientsRepository implements ClientsRepository {
  _FakeClientsRepository({
    this.timezone = defaultClientTimeZone,
    this.config = _config,
    this.loadFailure,
    this.loadPending = false,
    this.saveFailure,
  });

  /// The stored config, so a test can hand the screen a dropped dimension.
  final ClientConfig config;

  Map<String, double>? savedWeights;
  Map<String, double>? savedThresholds;
  String? savedTimezone;
  ({String start, String end, List<int> days})? savedWorkingHours;

  /// What the server currently holds; a save moves it, so a re-read shows it.
  String timezone;
  String workHoursStart = defaultWorkHoursStart;
  String workHoursEnd = defaultWorkHoursEnd;
  List<int> workDays = defaultWorkDays;

  final Object? loadFailure;
  final bool loadPending;

  /// Loads fine, refuses to save — what an admin-only endpoint returns to a
  /// caller who is not one.
  final Object? saveFailure;

  @override
  Future<ClientConfig> getConfig() async {
    if (loadFailure != null) throw loadFailure!;
    if (loadPending) return Completer<ClientConfig>().future;
    return ClientConfig(
      name: config.name,
      scorecardWeights: config.scorecardWeights,
      kpiThresholds: config.kpiThresholds,
      timezone: timezone,
      workHoursStart: workHoursStart,
      workHoursEnd: workHoursEnd,
      workDays: workDays,
    );
  }

  @override
  Future<ClientConfig> updateWorkingHours({
    required String start,
    required String end,
    required List<int> days,
  }) async {
    if (saveFailure != null) throw saveFailure!;
    savedWorkingHours = (start: start, end: end, days: days);
    workHoursStart = start;
    workHoursEnd = end;
    workDays = days;
    return getConfig();
  }

  @override
  Future<ClientConfig> updateTimezone(String timezone) async {
    if (saveFailure != null) throw saveFailure!;
    savedTimezone = timezone;
    this.timezone = timezone;
    return getConfig();
  }

  @override
  Future<ClientConfig> updateWeights(Map<String, double> weights) async {
    if (saveFailure != null) throw saveFailure!;
    savedWeights = weights;
    return getConfig();
  }

  @override
  Future<ClientConfig> updateThresholds(
    Map<String, double> thresholds,
  ) async {
    if (saveFailure != null) throw saveFailure!;
    savedThresholds = thresholds;
    return getConfig();
  }
}

DioException _status(int code, {String? message}) => DioException(
  requestOptions: RequestOptions(path: '/clients/me'),
  response: Response<Object?>(
    requestOptions: RequestOptions(path: '/clients/me'),
    statusCode: code,
    data: message == null ? null : <String, Object?>{'error': message},
  ),
);

Future<_FakeClientsRepository> _pump(
  WidgetTester tester, {
  _FakeClientsRepository? repo,
  String role = 'admin',
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  bool settle = true,
}) async {
  final fake = repo ?? _FakeClientsRepository();
  await pumpConsole(
    tester,
    const ClientConfigScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: settle,
    path: '/client-config',
    overrides: <Override>[
      clientsRepositoryProvider.overrideWithValue(fake),
      sessionAs(role),
    ],
  );
  return fake;
}

void main() {
  group('the page reads, and only reads', () {
    testWidgets('the calendar, the window, the weights and the thresholds', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Africa/Johannesburg'), findsOneWidget);
      await scrollConsoleTo(tester, keyed('working-hours-current'));
      expect(find.text('07:00 – 17:00'), findsOneWidget);
      expect(find.text('Monday to Friday'), findsOneWidget);

      await scrollConsoleTo(tester, keyed('weight-availability'));
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Visibility'), findsOneWidget);

      await scrollConsoleTo(tester, keyed('threshold-green'));
      expect(find.text('Healthy band'), findsOneWidget);
      await scrollConsoleTo(tester, keyed('threshold-priceDeviationPct'));
      expect(find.text('Price deviation over'), findsOneWidget);
    });

    testWidgets('a share is a figure; a dropped dimension is a word', (
      tester,
    ) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('weight-availability'));
      // 0.3 of 0.5 is 60%.
      expect(find.textContaining('60.0', findRichText: true), findsOneWidget);
      expect(find.textContaining('40.0', findRichText: true), findsOneWidget);
      // Nothing is excluded here, so no chip claims one is.
      expect(find.byType(StatusChip), findsNothing);
    });

    testWidgets('a weight of nought is Excluded, in a word and a square', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeClientsRepository(
          config: const ClientConfig(
            name: 'Acme Beverages',
            scorecardWeights: <String, double>{
              'availability': 1,
              'visibility': 0,
            },
            kpiThresholds: <String, double>{'green': 80.0},
          ),
        ),
      );
      await scrollConsoleTo(tester, keyed('weight-visibility'));
      final chip = tester.widget<StatusChip>(find.byType(StatusChip));
      expect(chip.label, 'Excluded');
      // Oatmeal and a square: a dimension somebody chose to drop is a
      // decision, not a fault.
      expect(chip.level, StatusLevel.held);
    });

    testWidgets('a zone the client already holds is the one that renders', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeClientsRepository(timezone: 'America/New_York'),
      );
      expect(find.text('America/New_York'), findsOneWidget);
      expect(find.text('Africa/Johannesburg'), findsNothing);
    });

    testWidgets('an absent threshold shows the engine default, not zero', (
      tester,
    ) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('threshold-amber'));
      // `amber` is not in the stored map; the engine's own 60 is what is true.
      expect(find.textContaining('60', findRichText: true), findsWidgets);
      expect(
        find.text('Not set — the engine uses this default'),
        findsWidgets,
      );
    });

    testWidgets('the four keys the engine reads, and no fifth', (tester) async {
      await _pump(tester);
      for (final key in <String>[
        'green',
        'amber',
        'stockoutUnits',
        'priceDeviationPct',
      ]) {
        await scrollConsoleTo(tester, keyed('threshold-$key'));
        expect(keyed('threshold-$key'), findsOneWidget);
      }
    });
  });

  group('role gating', () {
    testWidgets('an admin may change everything', (tester) async {
      await _pump(tester, role: 'admin');
      expect(
        tester.widget<SoftRow>(keyed('timezone-current')).onTap,
        isNotNull,
      );
      await scrollConsoleTo(tester, keyed('edit-weights'));
      expect(keyed('edit-weights'), findsOneWidget);
      await scrollConsoleTo(tester, keyed('edit-thresholds'));
      expect(keyed('edit-thresholds'), findsOneWidget);
    });

    testWidgets('a manager may change the calendar but not the policy', (
      tester,
    ) async {
      await _pump(tester, role: 'manager');
      // #309: PATCH /clients/me accepts a timezone from a manager.
      expect(
        tester.widget<SoftRow>(keyed('timezone-current')).onTap,
        isNotNull,
      );
      expect(
        tester.widget<SoftRow>(keyed('working-hours-current')).onTap,
        isNotNull,
      );
      // Weights and thresholds stay admin-only, so the control is not
      // offered at all — a field you can type into but never save is worse
      // than one you cannot type into.
      await scrollConsoleTo(tester, find.byType(ReadOnlyNotice).first);
      expect(find.byType(ReadOnlyNotice), findsNWidgets(2));
      expect(keyed('edit-weights'), findsNothing);
      expect(keyed('edit-thresholds'), findsNothing);
    });

    testWidgets('a field agent may read the zone and not change it', (
      tester,
    ) async {
      await _pump(tester, role: 'field_agent');
      expect(find.text('Africa/Johannesburg'), findsOneWidget);
      expect(tester.widget<SoftRow>(keyed('timezone-current')).onTap, isNull);
      expect(find.byType(SoftRowChevron), findsNothing);
    });
  });

  group('the weights sheet', () {
    Future<void> open(WidgetTester tester) async {
      await scrollConsoleTo(tester, keyed('edit-weights'));
      await tester.tap(keyed('edit-weights'));
      await tester.pumpAndSettle();
    }

    testWidgets('submits the parsed weights map', (tester) async {
      final repo = await _pump(tester);
      await open(tester);

      await tester.enterText(keyed('weight-field-availability'), '2');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('save-config'));
      await tester.tap(keyed('save-config'));
      await tester.pumpAndSettle();

      expect(repo.savedWeights, <String, double>{
        'availability': 2,
        'visibility': 0.2,
      });
      await settleToasts(tester);
    });

    testWidgets('a weight of nought says Excluded, never 0% of the score', (
      tester,
    ) async {
      await _pump(tester);
      await open(tester);

      // Mono, right-aligned, and locale-aware: a weight is a figure.
      expect(
        tester.widget<TorchNumericField>(keyed('weight-field-availability')),
        isA<TorchNumericField>(),
      );

      await tester.enterText(keyed('weight-field-visibility'), '0');
      await tester.pumpAndSettle();
      expect(find.text('Excluded from the score entirely.'), findsOneWidget);
      expect(find.text('0.0% of the score.'), findsNothing);
    });

    testWidgets('a 403 is reported in words, not thrown', (tester) async {
      await _pump(
        tester,
        repo: _FakeClientsRepository(saveFailure: _status(403)),
      );
      await open(tester);
      await scrollSheetTo(tester, keyed('save-config'));
      await tester.tap(keyed('save-config'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(keyed('weights-error'), findsOneWidget);
      expect(
        find.text('Only an administrator can change scoring config.'),
        findsOneWidget,
      );
    });
  });

  group('the thresholds sheet', () {
    testWidgets('submits an edited threshold and keeps the defaults', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await scrollConsoleTo(tester, keyed('edit-thresholds'));
      await tester.tap(keyed('edit-thresholds'));
      await tester.pumpAndSettle();

      await tester.enterText(keyed('threshold-green'), '85');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('save-thresholds'));
      await tester.tap(keyed('save-thresholds'));
      await tester.pumpAndSettle();

      expect(repo.savedThresholds!['green'], 85);
      // A blank box must not silently become 0 — "leave it alone" is not
      // "never trigger".
      expect(repo.savedThresholds!['amber'], 60);
      expect(repo.savedThresholds!['stockoutUnits'], 0);
      expect(repo.savedThresholds!['priceDeviationPct'], 10);
      await settleToasts(tester);
    });
  });

  group('the timezone sheet (#309)', () {
    Future<void> open(WidgetTester tester) async {
      await tester.tap(keyed('timezone-current'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists Johannesburg first, ahead of the rest', (tester) async {
      await _pump(tester);
      await open(tester);
      expect(keyed('timezone-option-Africa/Johannesburg'), findsOneWidget);
      expect(find.text('Suggested'.toUpperCase()), findsOneWidget);
    });

    testWidgets('a manager finds a zone by searching, and it is saved', (
      tester,
    ) async {
      final repo = await _pump(tester, role: 'manager');
      await open(tester);

      await tester.enterText(keyed('timezone-search'), 'new york');
      await tester.pumpAndSettle();
      await tester.tap(keyed('timezone-option-America/New_York'));
      await tester.pumpAndSettle();

      expect(repo.savedTimezone, 'America/New_York');
      expect(find.byType(TorchSheet), findsNothing);
      expect(find.text('America/New_York'), findsOneWidget);
      await settleToasts(tester);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await _pump(tester);
      await open(tester);
      await tester.enterText(keyed('timezone-search'), 'zzzz');
      await tester.pumpAndSettle();
      expect(keyed('timezone-no-match'), findsOneWidget);
    });

    testWidgets("a rejected zone is reported in the server's words", (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeClientsRepository(
          saveFailure: _status(400, message: 'Unknown timezone.'),
        ),
      );
      await open(tester);
      await tester.enterText(keyed('timezone-search'), 'new york');
      await tester.pumpAndSettle();
      await tester.tap(keyed('timezone-option-America/New_York'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(keyed('timezone-error'), findsOneWidget);
      expect(find.text('Unknown timezone.'), findsOneWidget);
    });

    testWidgets('a 403 names who may change it', (tester) async {
      await _pump(
        tester,
        repo: _FakeClientsRepository(saveFailure: _status(403)),
      );
      await open(tester);
      await tester.tap(keyed('timezone-option-Africa/Johannesburg'));
      await tester.pumpAndSettle();
      // The same zone: no request, and the sheet just closes.
      expect(find.byType(TorchSheet), findsNothing);

      await tester.tap(keyed('timezone-current'));
      await tester.pumpAndSettle();
      await tester.enterText(keyed('timezone-search'), 'new york');
      await tester.pumpAndSettle();
      await tester.tap(keyed('timezone-option-America/New_York'));
      await tester.pumpAndSettle();
      expect(
        find.text('Only a manager or administrator can change the timezone.'),
        findsOneWidget,
      );
    });
  });

  group('the working-hours sheet (#153 T2)', () {
    Future<void> open(WidgetTester tester) async {
      await scrollConsoleTo(tester, keyed('working-hours-current'));
      await tester.tap(keyed('working-hours-current'));
      await tester.pumpAndSettle();
    }

    testWidgets('saves a window and the days that go with it', (tester) async {
      final repo = await _pump(tester);
      await open(tester);

      await tester.enterText(keyed('work-hours-start'), '08:00');
      await tester.enterText(keyed('work-hours-end'), '16:30');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('work-day-6'));
      await tester.tap(keyed('work-day-6'));
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('save-working-hours'));
      await tester.tap(keyed('save-working-hours'));
      await tester.pumpAndSettle();

      expect(repo.savedWorkingHours!.start, '08:00');
      expect(repo.savedWorkingHours!.end, '16:30');
      expect(repo.savedWorkingHours!.days, <int>[1, 2, 3, 4, 5, 6]);
      await settleToasts(tester);
    });

    testWidgets('the server\'s own rules are checked before the round trip', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await open(tester);

      await tester.enterText(keyed('work-hours-start'), '7:00');
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, keyed('save-working-hours'));
      await tester.tap(keyed('save-working-hours'));
      await tester.pumpAndSettle();

      expect(
        find.text('Start must be a 24-hour time like 07:00.'),
        findsOneWidget,
      );
      expect(repo.savedWorkingHours, isNull);
    });

    testWidgets('no day at all is refused, on the group and not the boxes', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await open(tester);

      for (var day = 1; day <= 5; day++) {
        await scrollSheetTo(tester, keyed('work-day-$day'));
        await tester.tap(keyed('work-day-$day'));
        await tester.pumpAndSettle();
      }
      await scrollSheetTo(tester, keyed('save-working-hours'));
      await tester.tap(keyed('save-working-hours'));
      await tester.pumpAndSettle();

      expect(find.text('Pick at least one working day.'), findsOneWidget);
      expect(repo.savedWorkingHours, isNull);
    });
  });

  group('the rules themselves', () {
    test('timezoneOptions offers Johannesburg first, then the rest once', () {
      final options = timezoneOptions('', current: defaultClientTimeZone);
      expect(options.suggested, <String>[defaultClientTimeZone]);
      expect(options.all.contains(defaultClientTimeZone), isFalse);
      expect(options.all.toSet().length, options.all.length);
    });

    test('keeps the current zone beside the suggestion', () {
      final options = timezoneOptions('', current: 'America/New_York');
      expect(options.suggested, <String>[
        defaultClientTimeZone,
        'America/New_York',
      ]);
    });

    test('matches case-insensitively, reading a space as an underscore', () {
      expect(
        timezoneOptions('new york', current: defaultClientTimeZone).all,
        contains('America/New_York'),
      );
    });

    test('offers only names the server accepts', () {
      final options = timezoneOptions('', current: defaultClientTimeZone);
      for (final zone in <String>[...options.suggested, ...options.all]) {
        expect(ianaTimeZones, contains(zone));
      }
    });

    test('describeWorkDays reads a run as a range', () {
      expect(describeWorkDays(<int>[1, 2, 3, 4, 5]), 'Monday to Friday');
      expect(describeWorkDays(<int>[1, 3]), 'Monday, Wednesday');
      expect(describeWorkDays(<int>[]), 'No days');
      expect(describeWorkDays(<int>[1, 2, 3, 4, 5, 6, 7]), 'Every day');
    });

    test('parseWallClock mirrors the server exactly', () {
      expect(parseWallClock('07:00'), 420);
      expect(parseWallClock('7:00'), isNull);
      expect(parseWallClock('07:00:00'), isNull);
      expect(parseWallClock('24:00'), isNull);
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton, and nothing before 600ms', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeClientsRepository(loadPending: true),
        settle: false,
      );
      expect(find.byType(SkeletonRows), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('a failed load is sanitised and offers one retry', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _FakeClientsRepository(loadFailure: offline()),
      );
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(keyed('config-retry'), findsOneWidget);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin),
        'read-only': (t) => _pump(t, skin: skin, role: 'manager'),
        'loading': (t) async {
          await _pump(
            t,
            skin: skin,
            repo: _FakeClientsRepository(loadPending: true),
            settle: false,
          );
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          repo: _FakeClientsRepository(loadFailure: offline()),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'scoring config',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }

      testWidgets('${skin.mode.name}, the weights sheet: one commit', (
        tester,
      ) async {
        await _pump(tester, skin: skin);
        await scrollConsoleTo(tester, keyed('edit-weights'));
        await tester.tap(keyed('edit-weights'));
        await tester.pumpAndSettle();
        await scrollSheetTo(tester, keyed('save-config'));

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'scoring config',
          phase: 'weights sheet',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'the sheet extinguishes the nav tab beneath it and carries one '
              'commit of its own.\n${census.describe()}',
        );
      });

      testWidgets('${skin.mode.name}, the timezone sheet: 0', (tester) async {
        await _pump(tester, skin: skin);
        await tester.tap(keyed('timezone-current'));
        await tester.pumpAndSettle();
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'choosing from a list is not a commit: the tap IS the save, so '
              'there is no armed block.\n${census.describe()}',
        );
      });
    }
  });

  group('2.0x text and Afrikaans lengths', () {
    testWidgets('the page survives and nothing overflows', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('threshold-priceDeviationPct'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the weights sheet survives at 2.0x', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      await scrollConsoleTo(tester, keyed('edit-weights'));
      await tester.tap(keyed('edit-weights'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollSheetTo(tester, keyed('save-config'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the timezone sheet survives at 2.0x', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      await tester.tap(keyed('timezone-current'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
