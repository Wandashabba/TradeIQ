import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/audit/presentation/my_work_screen.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/contests/data/contests_repository.dart';

import 'package:tradeiq_app/l10n/l10n.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

SyncItem _item(
  int id,
  String entityType, {
  bool synced = false,
  String? lastError,
  int? payloadBytes,
  int attempts = 1,
}) => SyncItem(
  id: id,
  entityType: entityType,
  queuedAt: DateTime(2026, 7, 20, 7, 58),
  synced: synced,
  attempts: attempts,
  lastError: lastError,
  lastAttemptAt: synced || lastError != null
      ? DateTime(2026, 7, 20, 14, 20)
      : null,
  payloadBytes: payloadBytes,
);

SyncStatus _status(List<SyncItem> items) {
  final pending = items.where((i) => !i.synced).toList();
  return SyncStatus(
    pending: pending,
    sent: items.where((i) => i.synced).toList(),
    needsAttention: pending.where((i) => i.needsAttention).toList(),
  );
}

/// Held, and only held: the normal Tuesday.
final _held = _status(<SyncItem>[
  _item(1, 'stock', payloadBytes: 300 * 1024),
  _item(2, 'photo', lastError: 'sync:noConnection', payloadBytes: 1468006),
  _item(3, 'visit', synced: true, payloadBytes: 2048),
]);

/// One capture the server refused. The rest are fine.
final _stuck = _status(<SyncItem>[
  _item(1, 'stock', payloadBytes: 300 * 1024),
  _item(4, 'pricing', lastError: 'sync:rejected:422', payloadBytes: 900),
  _item(3, 'visit', synced: true),
]);

/// The session ended under the queue.
final _signedOut = _status(<SyncItem>[
  _item(5, 'photo', lastError: 'sync:signedOut'),
  _item(1, 'stock'),
]);

final _allSent = _status(<SyncItem>[_item(3, 'visit', synced: true)]);

/// Signed out, beside a capture the server genuinely refused.
final _signedOutAndStuck = _status(<SyncItem>[
  _item(5, 'photo', lastError: 'sync:signedOut'),
  _item(4, 'pricing', lastError: 'sync:rejected:422', payloadBytes: 900),
  _item(1, 'stock'),
]);

/// A field agent whose location answer is [consent] (null: not yet asked).
class _Location extends LocationSharingController {
  _Location(this.consent);

  final LocationConsent? consent;

  @override
  LocationSharingState build() => LocationSharingState(
    isAgent: true,
    settings: LocationSettings(intervalSeconds: 120, noticeVersion: 'v1')
        .withDecision(
          consent == null
              ? null
              : LocationDecision(
                  consent: consent!,
                  noticeVersion: 'v1',
                  decidedAt: DateTime(2026, 9, 15),
                ),
        ),
    running: consent == LocationConsent.acknowledged,
  );
}

class _Syncing extends SyncingNotifier {
  @override
  bool build() => true;
}

/// What the sheet and the screen's button called, so a test can see the
/// difference between "try everything" and "try this one".
class _Calls {
  int syncNow = 0;
  final List<int> sentOne = <int>[];
  final List<int> discarded = <int>[];
  int dependents = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  SyncStatus? sync,
  Object? error,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  bool sending = false,
  int dependents = 0,
  _Location? location,
}) async {
  final calls = _Calls()..dependents = dependents;
  final db = agentTestDb();
  await pumpAgentScreen(
    tester,
    const MyWorkScreen(),
    path: '/my-work',
    overrides: <Override>[
      if (error == null)
        ...agentBaseOverrides(
          db: db,
          skin: skin,
          sync: sync ?? SyncStatus.empty,
        )
      else ...<Override>[
        // The base overrides stub the outbox with a value; this one reads it
        // and fails. Same four overrides otherwise.
        localDbProvider.overrideWithValue(db),
        agentSkinProvider.overrideWith(() => PinnedAgentSkin(skin)),
        syncStatusProvider.overrideWith(
          (ref) => Stream<SyncStatus>.error(error),
        ),
        runningContestsCountProvider.overrideWith((ref) async => 0),
      ],
      if (sending) syncingProvider.overrideWith(_Syncing.new),
      if (location != null)
        locationSharingControllerProvider.overrideWith(() => location),
      syncNowProvider.overrideWithValue(() async => calls.syncNow++),
      sendOneProvider.overrideWithValue((id) async => calls.sentOne.add(id)),
      discardCaptureProvider.overrideWithValue(
        (id) async => calls.discarded.add(id),
      ),
      discardDependentsProvider.overrideWithValue(
        (id) async => calls.dependents,
      ),
    ],
    textScale: textScale,
    locale: locale,
    extraRoutes: <GoRoute>[
      GoRoute(path: '/today', builder: (c, s) => const Text('Today view')),
      GoRoute(path: '/map', builder: (c, s) => const Text('Map view')),
      GoRoute(path: '/login', builder: (c, s) => const Text('Login view')),
      GoRoute(path: '/audit', builder: (c, s) => const Text('Outlet picker')),
      GoRoute(
        path: '/leaderboard/contests',
        builder: (c, s) => const Text('Contests view'),
      ),
    ],
  );
  return calls;
}

TorchAllocation _allocation(WidgetTester tester) =>
    TorchScope.maybeOf(tester.element(find.byType(TorchNavPill)))!.allocation;

Finder _row(int id) => find.byKey(ValueKey<String>('sync-item-$id'));

OutboxRow _outboxRow(WidgetTester tester, int id) =>
    tester.widget<OutboxRow>(_row(id));

/// The body is a lazy list, so a row below the summary on a 360×640 phone is
/// genuinely not built until it is scrolled to — which is the point.
Future<OutboxRow> _see(WidgetTester tester, int id) async {
  await scrollAgentTo(tester, _row(id));
  return _outboxRow(tester, id);
}

TiqMark _summaryMark(WidgetTester tester) => tester.widget<TiqMark>(
  find
      .descendant(
        of: find.byKey(const ValueKey<String>('work-summary')),
        matching: find.byType(TiqMark),
      )
      .first,
);

void main() {
  setUp(TorchSheets.resetForTest);

  group('held is the normal state', () {
    testWidgets('a square, Oatmeal and a sentence — never a severity', (
      tester,
    ) async {
      await _pump(tester, sync: _held);
      final skin = agentSkinFor(SkinMode.night);

      expect(find.text('2 items held on this phone'), findsOneWidget);
      final mark = _summaryMark(tester);
      expect(mark.shape, MarkShape.heldSquare);
      expect(mark.color, skin.palette.ink2, reason: 'Oatmeal, not crimson');
      expect(mark.color, isNot(skin.palette.bad));

      // No "Needs you" group for a queue that needs nothing.
      expect(find.text('Needs you'), findsNothing);
      expect(find.textContaining('will not send'), findsNothing);
      // And no row carries a severity.
      for (final id in <int>[1, 2]) {
        expect(
          (await _see(tester, id)).state,
          isNot(OutboxState.stuck),
          reason: 'row $id is held, not stuck',
        );
      }
    });

    testWidgets('a failed attempt that clears itself is retrying, not stuck', (
      tester,
    ) async {
      await _pump(tester, sync: _held);
      final row = await _see(tester, 2);
      expect(row.state, OutboxState.retrying);
      expect(row.stateWord, 'Retrying');
      expect(row.ageLine, 'last tried 14:20');
      expect((await _see(tester, 1)).ageLine, 'queued 07:58');
    });

    testWidgets('"Send now" is offered but not lit — the queue sends itself', (
      tester,
    ) async {
      final calls = await _pump(tester, sync: _held);
      expect(_allocation(tester).isLit(MyWorkScreen.sendNowClaimId), isFalse);

      final button = find.byKey(const ValueKey<String>('send-now'));
      expect(tester.widget<TorchPrimaryButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pump();
      expect(calls.syncNow, 1, reason: 'the button still flushes the queue');
    });

    testWidgets('sending is Oatmeal and a word, and the button is busy', (
      tester,
    ) async {
      await _pump(tester, sync: _held, sending: true, textScale: 1.0);
      expect(find.text('Sending 2 items…'), findsOneWidget);
      expect(_summaryMark(tester).shape, MarkShape.heldSquare);
      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('send-now')),
      );
      expect(button.busy, isTrue);
      expect(button.onPressed, isNull, reason: 'one flush at a time');
    });

    testWidgets('all sent is the mint circle and the last-sent time', (
      tester,
    ) async {
      await _pump(tester, sync: _allSent);
      expect(find.text('Everything is sent'), findsOneWidget);
      expect(_summaryMark(tester).shape, MarkShape.onTargetCircle);

      // A disabled primary names what is missing.
      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('send-now')),
      );
      expect(button.onPressed, isNull);
      expect(button.blockedReason, 'Nothing is waiting to send.');
    });

    testWidgets('the footer promise is on the screen', (tester) async {
      await _pump(tester, sync: _held);
      await scrollAgentTo(
        tester,
        find.textContaining('Captures send themselves when you have signal'),
      );
      expect(find.textContaining('Nothing is lost'), findsOneWidget);
    });
  });

  group('something is stuck', () {
    testWidgets('the summary names it, and it is the one thing in colour', (
      tester,
    ) async {
      await _pump(tester, sync: _stuck);
      final skin = agentSkinFor(SkinMode.night);
      expect(find.textContaining('will not send'), findsOneWidget);
      expect(find.textContaining('Everything else is safe'), findsOneWidget);
      final mark = _summaryMark(tester);
      expect(mark.shape, MarkShape.criticalTriangle);
      expect(mark.color, skin.palette.bad);

      expect(find.text('Needs you'), findsWidgets);
      final row = await _see(tester, 4);
      expect(row.state, OutboxState.stuck);
      expect(row.stuckLabel, 'Needs you', reason: 'the severity in words');
      // The waiting row beside it is still just waiting.
      expect((await _see(tester, 1)).state, OutboxState.queued);
    });

    testWidgets('"Send now" takes the grant', (tester) async {
      final calls = await _pump(tester, sync: _stuck);
      expect(_allocation(tester).isLit(MyWorkScreen.sendNowClaimId), isTrue);
      await tester.tap(find.byKey(const ValueKey<String>('send-now')));
      await tester.pump();
      expect(calls.syncNow, 1);
    });

    testWidgets('signed out: the grant moves to "Sign in"', (tester) async {
      await _pump(tester, sync: _signedOut);
      expect(
        find.text(
          'You’re signed out. Sign in and your 2 held captures will send.',
        ),
        findsOneWidget,
      );
      final allocation = _allocation(tester);
      expect(allocation.isLit(MyWorkScreen.signInClaimId), isTrue);
      expect(allocation.isLit(MyWorkScreen.sendNowClaimId), isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('Login view'), findsOneWidget);
    });

    // unify §1.13 names session-ended among the HELD states. These captures
    // send themselves the moment the agent signs in, so nothing about them is
    // a severity: this screen once drew a crimson triangle over "1 item will
    // not send · Everything else is safe", a crimson-bordered sign-in block
    // and a "Needs you" row — for work that was fine.
    testWidgets('signed out is held: Oatmeal, a square and a word', (
      tester,
    ) async {
      await _pump(tester, sync: _signedOut);
      final skin = agentSkinFor(SkinMode.night);

      final mark = _summaryMark(tester);
      expect(mark.shape, MarkShape.heldSquare);
      expect(mark.color, skin.palette.ink2);
      expect(find.text('2 items held on this phone'), findsOneWidget);
      expect(find.textContaining('will not send'), findsNothing);
      expect(find.text('Everything else is safe'), findsNothing);
      // "They will send themselves" is untrue with no session; it says why.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('work-summary')),
          matching: find.text('Held until you sign in'),
        ),
        findsOneWidget,
      );

      final block = tester.widget<Container>(
        find.byKey(const ValueKey<String>('signed-out')),
      );
      final edge = ((block.decoration! as BoxDecoration).border! as Border).top;
      expect(edge.color, skin.palette.edgeStructure);
      expect(edge.color, isNot(skin.palette.bad));

      final row = await _see(tester, 5);
      expect(row.state, isNot(OutboxState.stuck));
      expect(row.state, OutboxState.queued);
      expect(row.stuckLabel, isNull);
      expect(row.stateWord, 'Held');
      expect(row.sentence, 'Held until you sign in');
      expect(find.text('Needs you'), findsNothing);
      expect(find.text('Waiting to send'), findsOneWidget);
    });

    testWidgets('signed out while a flush runs: still held, never sending', (
      tester,
    ) async {
      await _pump(tester, sync: _signedOut, sending: true);
      expect((await _see(tester, 5)).state, OutboxState.queued);
    });

    testWidgets('signed out beside a refusal: only the refusal is crimson', (
      tester,
    ) async {
      await _pump(tester, sync: _signedOutAndStuck);
      final skin = agentSkinFor(SkinMode.night);
      final mark = _summaryMark(tester);
      expect(mark.shape, MarkShape.criticalTriangle);
      expect(mark.color, skin.palette.bad);
      // One refused capture, not two: the held one is not counted.
      expect(find.text('1 item will not send'), findsOneWidget);
      expect(_allocation(tester).isLit(MyWorkScreen.signInClaimId), isTrue);

      expect((await _see(tester, 4)).state, OutboxState.stuck);
      expect((await _see(tester, 5)).state, OutboxState.queued);
    });
  });

  group('the rows are OutboxRow, with the decoded size', () {
    testWidgets('a measured size goes through FigureSlot', (tester) async {
      await _pump(tester, sync: _held);
      expect((await _see(tester, 1)).payloadBytes, 300 * 1024);
      final slots = tester.widgetList<FigureSlot>(
        find.descendant(of: _row(1), matching: find.byType(FigureSlot)),
      );
      expect(slots, hasLength(1));
      expect(slots.single.value, 300);
    });

    testWidgets('an unmeasured row shows no size, not a zero', (tester) async {
      await _pump(tester, sync: _signedOut);
      expect((await _see(tester, 1)).payloadBytes, isNull);
      expect(
        find.descendant(of: _row(1), matching: find.byType(FigureSlot)),
        findsNothing,
      );
      expect(
        find.descendant(of: _row(1), matching: find.textContaining('0 kB')),
        findsNothing,
      );
    });

    testWidgets('a row waiting on its visit is not a fault and not tappable', (
      tester,
    ) async {
      await _pump(
        tester,
        sync: _status(<SyncItem>[
          _item(7, 'stock', lastError: 'sync:waitingForVisit'),
        ]),
      );
      final row = await _see(tester, 7);
      expect(row.state, OutboxState.waitingForVisit);
      expect(row.stuckLabel, isNull);
      expect(find.text('Needs you'), findsNothing);
    });

    testWidgets('Sent is capped, says so, and "Show older" shows more', (
      tester,
    ) async {
      await _pump(
        tester,
        sync: _status(<SyncItem>[
          for (var i = 100; i < 125; i++) _item(i, 'photo', synced: true),
        ]),
      );
      final summary = find.text('Showing the 20 most recently sent of 25');
      await scrollAgentTo(tester, summary);
      expect(summary, findsOneWidget);
      expect(_row(124), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('show-older')));
      await tester.pumpAndSettle();
      expect(summary, findsNothing, reason: 'nothing is hidden any more');
      await scrollAgentTo(tester, _row(124));
      expect(_row(124), findsOneWidget);
    });
  });

  group('the item sheet (#376)', () {
    Future<void> open(WidgetTester tester, int id) async {
      await _see(tester, id);
      await tester.tap(_row(id));
      await tester.pumpAndSettle();
    }

    testWidgets('a retrying capture offers "Send this one now" — this one', (
      tester,
    ) async {
      final calls = await _pump(tester, sync: _held);
      await open(tester, 2);
      expect(find.byType(TorchSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('outbox-discard')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('outbox-send-one')));
      await tester.pumpAndSettle();
      expect(calls.sentOne, <int>[2]);
      expect(calls.syncNow, 0, reason: 'a row never flushes the whole queue');
      expect(find.byType(TorchSheet), findsNothing);
    });

    testWidgets('a rejected capture offers no retry that would fail again', (
      tester,
    ) async {
      await _pump(tester, sync: _stuck);
      await open(tester, 4);
      expect(
        find.byKey(const ValueKey<String>('outbox-send-one')),
        findsNothing,
      );
      expect(
        find.textContaining('Nothing has been altered for you'),
        findsOneWidget,
      );
      // No sheet commit, so nothing on the sheet is lit.
      final scope = TorchScope.maybeOf(
        tester.element(find.byKey(const ValueKey<String>('outbox-discard'))),
      )!;
      expect(scope.allocation.granted, isEmpty);
    });

    testWidgets('discard states what is lost before anything happens', (
      tester,
    ) async {
      final calls = await _pump(tester, sync: _stuck);
      await open(tester, 4);
      await tester.tap(find.byKey(const ValueKey<String>('outbox-discard')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This Pricing has not reached the server. Discard it '
          'and it is gone from this phone — there is no copy anywhere else.',
        ),
        findsOneWidget,
      );
      expect(calls.discarded, isEmpty, reason: 'nothing gone yet');

      // The way out keeps it.
      await tester.tap(
        find.byKey(const ValueKey<String>('outbox-discard-keep')),
      );
      await tester.pumpAndSettle();
      expect(calls.discarded, isEmpty);

      await tester.tap(find.byKey(const ValueKey<String>('outbox-discard')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('outbox-discard-confirm')),
      );
      await tester.pumpAndSettle();
      expect(calls.discarded, <int>[4]);
      expect(find.byType(TorchSheet), findsNothing);
    });

    testWidgets('a visit says what goes with it', (tester) async {
      await _pump(
        tester,
        sync: _status(<SyncItem>[
          _item(9, 'visit', lastError: 'sync:rejected:422'),
        ]),
        dependents: 3,
      );
      await open(tester, 9);
      await tester.tap(find.byKey(const ValueKey<String>('outbox-discard')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '3 captures from this visit go with it, because they cannot send '
          'without the visit.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a signed-out capture offers Sign in and no discard', (
      tester,
    ) async {
      await _pump(tester, sync: _signedOut);
      await open(tester, 5);
      expect(find.byKey(const ValueKey<String>('outbox-sign-in')), findsOne);
      expect(
        find.byKey(const ValueKey<String>('outbox-discard')),
        findsNothing,
      );
    });

    testWidgets('a sent capture has nothing to do', (tester) async {
      await _pump(tester, sync: _allSent);
      await open(tester, 3);
      expect(find.text('Nothing to do — the server has it.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('outbox-send-one')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('outbox-discard')),
        findsNothing,
      );
    });
  });

  group('the states that are not a queue', () {
    testWidgets('empty says what the screen is for', (tester) async {
      await _pump(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(
        find.text(
          'Everything you capture in a store shows up here until the server '
          'has it.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('work-summary')), findsNothing);
    });

    testWidgets(
      'a failed read says the work is safe, and never the raw error',
      (tester) async {
        await _pump(tester, error: StateError('boom'));
        expect(find.text('Could not read your work'), findsOneWidget);
        expect(
          find.text('Your work is still on this phone. Nothing is lost.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('retry-work')),
          findsOneWidget,
        );
        expect(find.textContaining('boom'), findsNothing);
        expect(find.textContaining('Bad state'), findsNothing);
      },
    );
  });

  group('the chrome', () {
    testWidgets('a tab root: My work is the active slot, no back, no chip', (
      tester,
    ) async {
      await _pump(tester, sync: _held);
      final pill = tester.widget<TorchNavPill>(find.byType(TorchNavPill));
      expect(pill.activeIndex, TodayFrame.myWorkSlot);
      // The bar is Today's, read from one place — a My work that kept its own
      // `case 2:` sent the Map tab to Contests the day Map arrived.
      expect(
        pill.slots.map((s) => s.label),
        TodayFrame.slotsIn(englishLocalizations).map((s) => s.label),
      );
      final header = tester.widget<TorchAppHeader>(find.byType(TorchAppHeader));
      expect(header.title, 'My work');
      expect(header.back, isNull);
      expect(header.flagChips, isEmpty, reason: 'a chip linking to itself');
      expect(header.trailing, isNotNull, reason: 'the skin cycle');
      expect(find.byType(TorchThumbZone), findsNothing);
    });

    testWidgets('every other slot leaves the screen, to its own place', (
      tester,
    ) async {
      for (final (slot, landing) in <(int, String)>[
        (TodayFrame.todaySlot, 'Today view'),
        (TodayFrame.mapSlot, 'Map view'),
        (TodayFrame.contestsSlot, 'Contests view'),
      ]) {
        await _pump(tester, sync: _held);
        tester.widget<TorchNavPill>(find.byType(TorchNavPill)).onSelect(slot);
        await tester.pumpAndSettle();
        expect(find.text(landing), findsOneWidget, reason: 'slot $slot');
      }
    });
  });

  group('location sharing has an answer here too (#153, POPIA)', () {
    // The legacy scaffold carried these banners and the controllers behind
    // them only start when something watches them. A tab root without them
    // drops the notice, the indicator and the pings.
    testWidgets('sharing on: the standing indicator', (tester) async {
      await _pump(
        tester,
        sync: _held,
        location: _Location(LocationConsent.acknowledged),
      );
      expect(
        find.byKey(const ValueKey<String>('location-sharing-indicator')),
        findsOneWidget,
      );
    });

    testWidgets('not asked yet: the notice, whose yes never lights here', (
      tester,
    ) async {
      await _pump(tester, sync: _held, location: _Location(null));
      expect(
        find.byKey(const ValueKey<String>('location-notice')),
        findsOneWidget,
      );
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        1,
        reason:
            'The route does not declare the consent claim, so its yes takes '
            'the ink form and Night keeps only the nav tab.\n\n'
            '${census.describe()}',
      );
    });
  });

  group('sync errors and item labels follow the agent’s language', () {
    final queue = _status(<SyncItem>[
      _item(13, 'stock', lastError: 'sync:noConnection'),
      _item(11, 'photo', lastError: 'sync:tooLarge'),
      _item(12, 'visibility', lastError: 'Rejected by the server (422)'),
    ]);

    Future<List<String>> rowText(WidgetTester tester) async => <String>[
      for (final id in <int>[11, 12, 13]) ...<String>[
        (await _see(tester, id)).title,
        (await _see(tester, id)).sentence,
      ],
    ];

    testWidgets('Afrikaans', (tester) async {
      await _pump(tester, sync: queue, locale: const Locale('af'));
      final text = await rowText(tester);
      expect(text, containsAll(<String>['Foto', 'Te groot om te stuur']));
      expect(
        text,
        containsAll(<String>[
          'Sigbaarheid & uitstalling',
          'Deur die bediener geweier (422)',
          'Voorraadtelling',
        ]),
      );
      expect(text, isNot(contains('Photo')));
      expect(text.join(), isNot(contains('sync:')));
      expect(find.textContaining('sync:'), findsNothing);
    });

    testWidgets('English', (tester) async {
      await _pump(tester, sync: queue);
      final text = await rowText(tester);
      expect(
        text,
        containsAll(<String>[
          'Photo',
          'Too large to send',
          'Visibility & display',
          'Rejected by the server (422)',
          'Stock count',
        ]),
      );
      expect(find.textContaining('sync:'), findsNothing);
    });
  });

  group('2.0× text', () {
    for (final locale in <Locale>[const Locale('en'), const Locale('af')]) {
      testWidgets('${locale.languageCode}: nothing overflows', (tester) async {
        await _pump(tester, sync: _stuck, textScale: 2.0, locale: locale);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey<String>('work-summary')), findsOne);
        await scrollAgentTo(tester, _row(3));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Veld is built, not declared', () {
    testWidgets('the summary is a 2px rectangle with no shadow', (
      tester,
    ) async {
      await _pump(tester, sync: _held, skin: SkinMode.veld);
      final box = tester.widget<Container>(
        find.byKey(const ValueKey<String>('work-summary')),
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.borderRadius, BorderRadius.circular(0));
      expect((deco.border! as Border).top.width, 2);
      expect(deco.boxShadow ?? const <BoxShadow>[], isEmpty);
      expect(deco.gradient, isNull);
      expect(deco.color, const Color(0xFFFFFFFF));
      final button = tester.getSize(
        find.byKey(const ValueKey<String>('send-now')),
      );
      expect(button.height, greaterThanOrEqualTo(56));
    });
  });

  group('the amber census', () {
    Future<void> showSummary(WidgetTester tester) async {
      // The summary block, with "Send now" in it, is at the top of the scroll
      // view on a 360×640 phone; nothing to scroll.
      expect(find.byKey(const ValueKey<String>('send-now')), findsOneWidget);
    }

    final cases = <(String, SyncStatus?, Object?, Map<SkinMode, int>)>[
      // Held: nothing is the expected next move. Night keeps the nav tab.
      (
        'held',
        _held,
        null,
        {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      ),
      // Stuck: "Send now" takes the one content grant.
      (
        'stuck',
        _stuck,
        null,
        {SkinMode.night: 2, SkinMode.day: 1, SkinMode.veld: 1},
      ),
      // Signed out: "Sign in" takes it instead.
      (
        'signed-out',
        _signedOut,
        null,
        {SkinMode.night: 2, SkinMode.day: 1, SkinMode.veld: 1},
      ),
      (
        'all-sent',
        _allSent,
        null,
        {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      ),
      (
        'empty',
        SyncStatus.empty,
        null,
        {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      ),
      (
        'error',
        null,
        StateError('boom'),
        {SkinMode.night: 1, SkinMode.day: 0, SkinMode.veld: 0},
      ),
    ];

    for (final (phase, sync, error, expected) in cases) {
      for (final skin in agentSkinModes) {
        testWidgets('$phase · ${skin.name}: ${expected[skin]}', (tester) async {
          await _pump(tester, sync: sync, error: error, skin: skin);
          if (phase != 'empty' && phase != 'error') await showSummary(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            agentSkinFor(skin),
            route: 'my-work',
            phase: phase,
          );
          expect(census.objectCount, expected[skin], reason: census.describe());
        });
      }
    }

    testWidgets('at 2.0× the count does not change', (tester) async {
      await _pump(tester, sync: _stuck, textScale: 2.0);
      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        agentSkinFor(SkinMode.night),
        route: 'my-work',
        phase: 'stuck @2.0x',
      );
      expect(census.objectCount, 2, reason: census.describe());
    });

    testWidgets('a sheet puts out the screen beneath it and spends its own', (
      tester,
    ) async {
      await _pump(tester, sync: _held, skin: SkinMode.day);
      await _see(tester, 2);
      await tester.tap(_row(2));
      await tester.pumpAndSettle();
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        1,
        reason:
            'Day: the sheet\'s "Send this one now" is the one block; nothing '
            'beneath a modal sheet stays lit.\n\n${census.describe()}',
      );
    });
  });
}
