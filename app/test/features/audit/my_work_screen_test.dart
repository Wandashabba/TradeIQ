import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/human_error.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/features/audit/presentation/my_work_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

SyncItem _item({
  required int id,
  required String entityType,
  required bool synced,
  String? lastError,
  DateTime? lastAttemptAt,
}) => SyncItem(
  id: id,
  entityType: entityType,
  queuedAt: DateTime(2026, 7, 20, 9),
  synced: synced,
  attempts: 1,
  lastError: lastError,
  lastAttemptAt: lastAttemptAt,
);

/// A queue with one of each state: a plain waiting capture (offline-normal), a
/// failed one that will never send on its own (needs-attention), and a sent one.
final _waiting = _item(id: 1, entityType: 'stock', synced: false);
final _attention = _item(
  id: 2,
  entityType: 'photo',
  synced: false,
  lastError: 'Payload rejected',
);
final _sent = _item(
  id: 3,
  entityType: 'visit',
  synced: true,
  lastAttemptAt: DateTime(2026, 7, 20, 10),
);

SyncStatus _fullQueue() => SyncStatus(
  pending: [_waiting, _attention],
  sent: [_sent],
  needsAttention: [_attention],
);

/// Pending only, nothing failed — the offline-is-normal path.
SyncStatus _waitingOnly() =>
    SyncStatus(pending: [_waiting], sent: const [], needsAttention: const []);

bool _syncNowCalled = false;

List<Override> _overrides(SyncStatus status) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return [
    localDbProvider.overrideWithValue(db),
    syncStatusProvider.overrideWith((ref) => Stream.value(status)),
    // Presentation test: the real flush touches services + the network. We only
    // need to prove the retry affordance is wired to the provider.
    syncNowProvider.overrideWithValue(() async {
      _syncNowCalled = true;
    }),
  ];
}

Widget _app(SyncStatus status, {required String name}) => routedApp(
  MyWorkScreen(key: ValueKey('my-work-$name')),
  overrides: _overrides(status),
  theme: name == 'light' ? AppTheme.light() : AppTheme.dark(),
);

/// The error branch: the sync-status stream fails. Mirrors [_overrides] but
/// makes the provider emit an error instead of a status.
List<Override> _errorOverrides(Object error) {
  final db = LocalDb(NativeDatabase.memory());
  addTearDown(db.close);
  return [
    localDbProvider.overrideWithValue(db),
    syncStatusProvider.overrideWith((ref) => Stream.error(error)),
    syncNowProvider.overrideWithValue(() async {}),
  ];
}

Widget _errorApp(Object error) => routedApp(
  const MyWorkScreen(key: ValueKey('my-work-error')),
  overrides: _errorOverrides(error),
  theme: AppTheme.dark(),
);

/// Both themes, each with the palette its assertions read against.
const _bothThemes = [('light', TiqColors.light), ('dark', TiqColors.night)];

/// The console card wrapping a sync row — a surface1 DecoratedBox behind a line
/// hairline. The state words paint over this ground. Scoped to the ancestor of a
/// known row so it never matches a StatusBanner's inner (washed) DecoratedBox.
DecoratedBox _groupCard(WidgetTester tester, {int itemId = 1}) =>
    tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(ValueKey('sync-item-$itemId')),
            matching: find.byWidgetPredicate((w) {
              if (w is! DecoratedBox) return false;
              final d = w.decoration;
              return d is BoxDecoration && d.color != null && d.border != null;
            }),
          )
          .first,
    );

void main() {
  setUp(() => _syncNowCalled = false);

  testWidgets('groups render as console cards on the ambient palette', (
    tester,
  ) async {
    for (final (name, palette) in _bothThemes) {
      await tester.pumpWidget(_app(_fullQueue(), name: name));
      await tester.pumpAndSettle();

      if (palette.glass) {
        // Lumen Glass: each group is a pane of glass — no blur, it scrolls.
        final pane = tester.widget<GlassPane>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('sync-item-1')),
                matching: find.byType(GlassPane),
              )
              .first,
        );
        expect(pane.blur, isFalse, reason: '$name group never blurs');
      } else {
        final deco = _groupCard(tester).decoration as BoxDecoration;
        expect(deco.color, palette.surface1, reason: '$name group surface');
        expect(
          (deco.border! as Border).top.color,
          palette.line,
          reason: '$name group hairline',
        );
        expect(
          deco.borderRadius,
          BorderRadius.circular(12),
          reason: '$name group radius (radiusPanel)',
        );
      }

      // No raw Material scaffolding leaked in.
      expect(find.byType(Card), findsNothing, reason: '$name no raw Card');
      expect(
        find.byType(ListTile),
        findsNothing,
        reason: '$name no raw ListTile',
      );
      expect(
        find.byType(ElevatedButton),
        findsNothing,
        reason: '$name no raw ElevatedButton',
      );
    }
  });

  testWidgets(
    'state indicators carry a word + glyph, and coloured text clears AA both '
    'themes (rendered pair)',
    (tester) async {
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(_app(_fullQueue(), name: name));
        await tester.pumpAndSettle();

        // Words, never colour alone — scoped to each row so the "SENT" state
        // word is not confused with the "Sent" group heading.
        Finder stateWord(int itemId, String word) => find.descendant(
          of: find.byKey(ValueKey('sync-item-$itemId')),
          matching: find.text(word),
        );
        final sent = stateWord(3, 'SENT');
        final waiting = stateWord(1, 'WAITING');
        final failed = stateWord(2, 'FAILED');
        expect(sent, findsOneWidget, reason: '$name sent word');
        expect(waiting, findsOneWidget, reason: '$name waiting word');
        expect(failed, findsOneWidget, reason: '$name failed word');

        // Glyphs pair each word.
        expect(
          find.byIcon(Icons.check),
          findsWidgets,
          reason: '$name sent glyph',
        );
        expect(
          find.byIcon(Icons.schedule),
          findsWidgets,
          reason: '$name waiting glyph',
        );
        expect(
          find.byIcon(Icons.warning_amber_outlined),
          findsWidgets,
          reason: '$name failed glyph',
        );

        // The rows paint over the surface1 group card. Each coloured state word
        // must clear 4.5:1 there — sent→good, waiting→warn, failed→critText
        // (raw crit fails AA in dark, the recurring lesson).
        // Glass: by day a no-blur pane composites LIGHTER than surface1 under
        // dark ink; at night it composites DARKER than surface1 under light
        // ink. Either way surface1 is the conservative ground to measure
        // against.
        final bg = palette.glass
            ? palette.surface1
            : (_groupCard(tester).decoration as BoxDecoration).color!;

        final sentFg = tester.widget<Text>(sent).style!.color!;
        expect(sentFg, palette.good, reason: '$name sent text token');
        expect(
          contrastRatio(sentFg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$name sent AA',
        );

        final waitingFg = tester.widget<Text>(waiting).style!.color!;
        expect(waitingFg, palette.warn, reason: '$name waiting text token');
        expect(
          contrastRatio(waitingFg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$name waiting AA',
        );

        final failedFg = tester.widget<Text>(failed).style!.color!;
        expect(failedFg, palette.critText, reason: '$name failed text token');
        expect(
          contrastRatio(failedFg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$name failed AA (rendered pair)',
        );

        // The failure reason on the needs-attention row is coloured status text
        // too — same AA bar.
        final reason = tester.widget<Text>(find.text('Payload rejected'));
        expect(
          reason.style!.color,
          palette.critText,
          reason: '$name reason text',
        );
        expect(
          contrastRatio(reason.style!.color!, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$name reason AA',
        );
      }
    },
  );

  testWidgets('the retry affordance is an AgentButton wired to syncNow', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_fullQueue(), name: 'dark'));
    await tester.pumpAndSettle();

    final retry = find.byKey(const ValueKey('sync-now'));
    expect(
      tester.widget(retry),
      isA<AgentButton>(),
      reason: 'retry is a kit button',
    );

    await tester.tap(retry);
    await tester.pump();
    expect(_syncNowCalled, isTrue, reason: 'retry flushes the queue');
  });

  testWidgets('the offline-is-normal copy and the needs-attention distinction '
      'both survive', (tester) async {
    for (final (name, _) in _bothThemes) {
      await tester.pumpWidget(_app(_fullQueue(), name: name));
      await tester.pumpAndSettle();

      // Keys the rest of the app (and these tests) rely on.
      expect(find.byKey(const ValueKey('work-summary')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-item-2')), findsOneWidget);

      // The alarming state is distinct and named — a failed item won't self-send.
      // _Heading uppercases its label.
      expect(
        find.text('NEEDS YOU'),
        findsOneWidget,
        reason: '$name attention heading',
      );
      expect(
        find.textContaining('will not send'),
        findsOneWidget,
        reason: '$name summary names the failure',
      );
      expect(find.textContaining('Everything else is safe'), findsOneWidget);

      // Offline held-on-phone is a receipt, not an error: the reassurance copy
      // is verbatim.
      expect(
        find.textContaining('Captures send themselves when you have signal'),
        findsOneWidget,
        reason: '$name reassurance copy',
      );
      expect(find.textContaining('Nothing here is ever lost'), findsOneWidget);
    }
  });

  testWidgets(
    'pending-only reads as normal — held on this phone, not an alarm',
    (tester) async {
      await tester.pumpWidget(_app(_waitingOnly(), name: 'dark'));
      await tester.pumpAndSettle();

      // No failure, so no "Needs you" heading and the summary is the reassuring
      // warn-level receipt, not the bad-level alarm.
      expect(find.text('NEEDS YOU'), findsNothing);
      expect(find.textContaining('held on this phone'), findsOneWidget);
      expect(find.textContaining('will not send'), findsNothing);
    },
  );

  testWidgets(
    'the error branch speaks the console voice — humanErrorMessage, never the '
    'raw exception',
    (tester) async {
      // A non-connectivity failure (parsing bug / programmer error): its raw
      // toString would leak "Bad state: boom", but the whole console must route
      // through humanErrorMessage so every surface speaks with one voice.
      final err = StateError('boom');
      await tester.pumpWidget(_errorApp(err));
      await tester.pumpAndSettle();

      // The alarm title still names the surface.
      expect(find.text('Could not read your work'), findsOneWidget);

      // The subtitle is the humane line, verbatim — not the exception.
      expect(find.text(humanErrorMessage(err)), findsOneWidget);

      // And the raw dump is nowhere on screen.
      expect(
        find.textContaining('boom'),
        findsNothing,
        reason: 'no raw message',
      );
      expect(
        find.textContaining('Bad state'),
        findsNothing,
        reason: 'no raw exception type',
      );
      expect(
        find.textContaining('Instance of'),
        findsNothing,
        reason: 'no toString dump',
      );
    },
  );

  group('sync errors and item labels follow the agent’s language', () {
    // What the outbox actually holds now: codes, plus one row written by an
    // older build that stored the English line itself.
    final coded = _item(
      id: 11,
      entityType: 'photo',
      synced: false,
      lastError: 'sync:tooLarge',
    );
    final legacy = _item(
      id: 12,
      entityType: 'visibility',
      synced: false,
      lastError: 'Rejected by the server (422)',
    );
    final waiting = _item(
      id: 13,
      entityType: 'stock',
      synced: false,
      lastError: 'sync:noConnection',
    );
    SyncStatus queue() => SyncStatus(
      pending: [waiting, coded, legacy],
      sent: const [],
      needsAttention: [coded, legacy],
    );

    Widget app(Locale locale) => routedApp(
      const MyWorkScreen(),
      overrides: _overrides(queue()),
      locale: locale,
    );

    testWidgets('Afrikaans', (tester) async {
      await tester.pumpWidget(app(const Locale('af')));
      await tester.pumpAndSettle();

      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('Te groot om te stuur'), findsOneWidget);
      expect(find.text('Sigbaarheid & uitstalling'), findsOneWidget);
      expect(find.text('Deur die bediener geweier (422)'), findsOneWidget);
      expect(find.text('Voorraadtelling'), findsOneWidget);

      expect(find.text('Photo'), findsNothing);
      expect(find.text('Too large to send'), findsNothing);
      expect(find.text('Stock count'), findsNothing);
      expect(find.textContaining('Rejected by the server'), findsNothing);
      expect(find.textContaining('sync:'), findsNothing, reason: 'no codes');
    });

    testWidgets('English reads exactly as before', (tester) async {
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Too large to send'), findsOneWidget);
      expect(find.text('Visibility & display'), findsOneWidget);
      expect(find.text('Rejected by the server (422)'), findsOneWidget);
      expect(find.text('Stock count'), findsOneWidget);
      expect(find.textContaining('sync:'), findsNothing, reason: 'no codes');
    });
  });

  test('no non-geometry AppColors. remain in the my-work source', () {
    final src = File(
      'lib/features/audit/presentation/my_work_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
