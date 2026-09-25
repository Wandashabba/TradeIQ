import 'package:flutter/material.dart';
import 'package:tradeiq_app/core/location/location_sharing.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/sync/sync_status.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/me/data/my_record_repository.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';
import 'me_harness.dart';

/// /me — THE AGENT'S OWN RECORD.
///
/// The tests are grouped by the promise each one keeps: the proof an agent can
/// point at, the number that is theirs, the honesty about the number that
/// moved, and the law about how much of this screen is allowed to glow.

void main() {
  group('the proof of a day that was worked', () {
    testWidgets('a visit names the store, the day, the dwell and the tasks', (
      tester,
    ) async {
      await pumpMe(tester);

      final handle = tester.ensureSemantics();
      final row = find.byKey(const ValueKey<String>('my-visit-v1'));
      expect(row, findsOneWidget);
      // THE STORE, NAMED. Since the card override of 25 September 2026 a list
      // row spends its own padding before the title starts, and a
      // 17-character outlet name middle-truncates on a 360dp row in
      // `flutter_test`'s font, which has about twice Onest's advance. That is
      // the ruling's own behaviour — outlet names middle-truncate, and the
      // FULL name is what a screen reader is handed whatever the row painted
      // — so both halves are asserted rather than the painted string alone.
      expect(
        find.descendant(of: row, matching: find.textContaining('Kasi Cor')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Kasi Corner Spaza')), findsWidgets);
      handle.dispose();
      // The meta line is one string built from three localised parts.
      expect(
        find.descendant(
          of: row,
          matching: find.text('Thu 17 Sep · 41 min · 3 tasks raised'),
        ),
        findsOneWidget,
      );
      // And the evidence half: what was captured.
      expect(
        find.descendant(
          of: row,
          matching: find.text('5 of 7 sections · 2 photos'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the whole row is one screen-reader sentence', (tester) async {
      await pumpMe(tester);

      final label = tester
          .getSemantics(find.byKey(const ValueKey<String>('my-visit-v1')))
          .label;
      expect(label, contains('Kasi Corner Spaza'));
      expect(label, contains('Thu 17 Sep'));
      expect(label, contains('41 min'));
      expect(label, contains('3 tasks raised'));
      expect(label, contains('scored 71'));
    });

    testWidgets('a visit with nothing wrong carries no flag chip', (
      tester,
    ) async {
      await pumpMe(tester);
      expect(find.byType(FlagChip), findsNothing);
    });

    testWidgets(
      'a check-in outside the fence is shown to the agent as a fact, with '
      'the distance — not hidden, and not crimson',
      (tester) async {
        await pumpMe(
          tester,
          repository: FakeMyRecordRepository(
            visits: <MyVisit>[visitFixture(geofencePass: false, distance: 140)],
          ),
        );

        // The chip is one run — "Out of fence · 140 m from the door" — so the
        // word and its detail are asserted together rather than as two nodes.
        expect(find.textContaining('Out of fence'), findsOneWidget);
        expect(find.textContaining('140 m from the door'), findsOneWidget);
        // `outOfFence` is one of the six neutral flag members. The one
        // severity flag in the family is Sent back, and it is not this.
        final chip = tester.widget<FlagChip>(find.byType(FlagChip).first);
        expect(chip.kind, FlagKind.outOfFence);
      },
    );

    testWidgets(
      'a visit started by reporting the pin says so, in words, and a screen '
      'reader hears it with the fence fact',
      (tester) async {
        await pumpMe(
          tester,
          repository: FakeMyRecordRepository(
            visits: <MyVisit>[
              visitFixture(
                geofencePass: false,
                distance: 140,
                pinReported: true,
              ),
            ],
          ),
        );

        expect(find.text('You reported the pin as wrong'), findsOneWidget);
        // Their own act, not a flag on them: still exactly one chip.
        expect(find.byType(FlagChip), findsOneWidget);

        final label = tester
            .getSemantics(find.byKey(const ValueKey<String>('my-visit-v1')))
            .label;
        expect(label, contains('Out of fence, 140 m from the door'));
        expect(label, contains('You reported the pin as wrong'));
        expect(label, contains('5 of 7 sections'));
      },
    );

    testWidgets('a visit with no pin report says nothing about the pin', (
      tester,
    ) async {
      await pumpMe(tester);
      expect(find.textContaining('reported the pin'), findsNothing);
    });

    testWidgets('a reviewed visit says so, because it is their record', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          visits: <MyVisit>[visitFixture(reviewedVerdict: 'dismissed')],
        ),
      );
      expect(find.text('Reviewed'), findsOneWidget);
    });

    testWidgets(
      'work still held on the phone is said once at the top, not as a dash '
      'beside every row',
      (tester) async {
        await pumpMe(
          tester,
          sync: SyncStatus(
            pending: <SyncItem>[
              SyncItem(
                id: 1,
                entityType: 'visit',
                queuedAt: DateTime(2026, 9, 18),
                synced: false,
                attempts: 0,
              ),
              SyncItem(
                id: 2,
                entityType: 'photo',
                queuedAt: DateTime(2026, 9, 18),
                synced: false,
                attempts: 0,
              ),
            ],
            sent: const <SyncItem>[],
            needsAttention: const <SyncItem>[],
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('on-this-phone')),
          findsOneWidget,
        );
        expect(find.text('2 captures have not sent'), findsOneWidget);
      },
    );

    testWidgets('and nothing held means no row about it', (tester) async {
      await pumpMe(tester);
      expect(find.byKey(const ValueKey<String>('on-this-phone')), findsNothing);
    });
  });

  group('unknown is never zero', () {
    testWidgets(
      'an unscored visit reads "Waiting to be scored" — never a bare dash, '
      'and never a number the phone made up',
      (tester) async {
        await pumpMe(
          tester,
          repository: FakeMyRecordRepository(
            visits: <MyVisit>[visitFixture(score: null)],
          ),
        );

        expect(find.text('Waiting to be scored'), findsWidgets);
        expect(find.text('71'), findsNothing);
        // unify §1.20: the agent app never shows a provisional score, so the
        // console's marker must never reach this route.
        expect(find.byType(ProvisionalMarker), findsNothing);
      },
    );

    testWidgets('an unsubmitted visit says it is still open on this phone', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          visits: <MyVisit>[
            visitFixture(
              status: 'in_progress',
              score: null,
              dwellMinutes: null,
            ),
          ],
        ),
      );
      expect(find.text('Still open on this phone'), findsOneWidget);
      expect(find.textContaining('time not recorded'), findsOneWidget);
    });

    testWidgets('an unmeasured distance is said in words, not as 0 m', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          visits: <MyVisit>[visitFixture(geofencePass: false, distance: null)],
        ),
      );
      expect(find.textContaining('distance not measured'), findsOneWidget);
      expect(find.textContaining('0 m from the door'), findsNothing);
    });

    testWidgets('a measured zero is printed, and said', (tester) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          visits: <MyVisit>[visitFixture(tasksRaised: 0, photos: 0)],
        ),
      );
      // An agent who raised nothing raised nothing, and that is a fact about
      // a shop in good order — not a gap in the record.
      expect(find.textContaining('no tasks raised'), findsOneWidget);
      expect(find.textContaining('no photos'), findsOneWidget);
    });

    testWidgets(
      'a caller who is not on the board gets the em dash AND the sentence — '
      'never a place computed from a list they are not in',
      (tester) async {
        // `rank: null` is what `/gamification/me` answers for a manager, and
        // /me is open to managers on purpose. It used to answer
        // `leaderboard.length + 1`: a manager on a board of three field agents
        // read "RANK 4", printed through StatTile as a plain measured figure
        // with no caveat, while this sentence could never render at all.
        await pumpMe(
          tester,
          repository: FakeMyRecordRepository(
            earnings: earningsFixture(rank: null),
          ),
        );
        expect(
          find.text(
            'Only field agents are ranked, so you do not have a place on '
            'this board.',
          ),
          findsOneWidget,
        );
        // And no invented figure anywhere near the tile.
        expect(find.text('4'), findsNothing);
        expect(find.text('1'), findsNothing);
      },
    );

    testWidgets('a real place is still printed as a figure', (tester) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(earnings: earningsFixture(rank: 4)),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('Only field agents are ranked'), findsNothing);
    });

    testWidgets('and a record with no points prints 0, with its sentence', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          earnings: earningsFixture(points: 0),
        ),
      );
      expect(find.textContaining('No points yet'), findsOneWidget);
    });

    // ── The period, named ────────────────────────────────────────────────
    //
    // `/gamification/me` is read with no window, so every figure on this
    // screen is the agent's whole record. The screen used to print the bare
    // month name in the header and say "this month" in three more places, so
    // an agent in their fourth month read a career total as September's.
    testWidgets('no figure here is labelled as a month\'s', (tester) async {
      await pumpMe(tester, repository: FakeMyRecordRepository());

      expect(find.text('All time'), findsOneWidget);
      expect(find.text('POINTS ALL TIME'), findsOneWidget);
      // The header's fact used to be `formatMonthHeading(DateTime.now())`.
      for (final month in <String>[
        'January', 'February', 'March', 'April', 'May', 'June', 'July',
        'August', 'September', 'October', 'November', 'December',
      ]) {
        expect(
          find.textContaining(month),
          findsNothing,
          reason: '"$month" labels a lifetime figure as one month of it.',
        );
      }
      expect(find.textContaining('this month'), findsNothing);
    });
  });

  group('the honest score story', () {
    testWidgets(
      'a score that moved after the agent read it says so, in the agent\'s '
      'own voice',
      (tester) async {
        await pumpMe(
          tester,
          repository: FakeMyRecordRepository(
            visits: <MyVisit>[visitFixture(score: 71, seen: 84)],
          ),
        );

        final line = find.byKey(const ValueKey<String>('reconciled-v1'));
        expect(line, findsOneWidget);
        final label = tester.getSemantics(line).label;
        expect(label, contains('Now scored 71'));
        expect(label, contains('It was 84 when you saw it'));
        // And on the glass, not only in the screen reader: a sighted agent
        // is owed the why, or "it was 84" is a riddle about when.
        expect(
          find.text('It was scored again after you saw it.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a score that agreed with what they saw says nothing', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          visits: <MyVisit>[visitFixture(score: 71, seen: 71.4)],
        ),
      );
      // Rounded first: the screen prints whole points, and "71 became 71" is
      // noise dressed as honesty.
      expect(find.byType(ReconciliationLine), findsNothing);
    });

    testWidgets('a visit the agent never saw scored has nothing to reconcile', (
      tester,
    ) async {
      await pumpMe(tester);
      expect(find.byType(ReconciliationLine), findsNothing);
    });

    testWidgets('the points honesty line is on the screen and is read', (
      tester,
    ) async {
      await pumpMe(tester);
      expect(
        find.text(
          'Points are worked out on the server. They can change if a visit '
          'is reviewed.',
        ),
        findsOneWidget,
      );
    });
  });

  group('what I have earned', () {
    testWidgets('the reward is named at the end of the bar', (tester) async {
      await pumpMe(tester);

      final bar = find.byKey(const ValueKey<String>('reward-bar'));
      expect(bar, findsOneWidget);
      final label = tester
          .getSemantics(
            find.ancestor(of: bar, matching: find.byType(Semantics)).first,
          )
          .label;
      expect(label, contains('14'));
      expect(label, contains('20'));
      expect(label, contains('R 250 airtime'));
    });

    testWidgets(
      'no scheme running means no bar at all — an empty bar would read as '
      'zero progress, which is a different and false statement',
      (tester) async {
        await pumpMe(
          tester,
          repository: FakeMyRecordRepository(
            earnings: earningsFixture(schemes: const <IncentiveScheme>[]),
          ),
        );
        expect(find.byType(TorchProgressBar), findsNothing);
        expect(find.text('No reward is running.'), findsOneWidget);
      },
    );

    testWidgets('a cleared threshold says the reward is reached, quietly', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          earnings: earningsFixture(visitsSubmitted: 22),
        ),
      );
      expect(
        find.textContaining('Reward reached — R 250 airtime'),
        findsWidgets,
      );
    });

    testWidgets('a reversal is a word, not only a triangle', (tester) async {
      await pumpMe(tester);

      final label = tester
          .getSemantics(find.byKey(const ValueKey<String>('ledger-p2')))
          .label;
      expect(label, contains('minus 5 points'));
    });

    testWidgets('and a grant is a word too', (tester) async {
      await pumpMe(tester);
      final label = tester
          .getSemantics(find.byKey(const ValueKey<String>('ledger-p1')))
          .label;
      expect(label, contains('plus 5 points'));
    });

    // ── A SCORECARD CONTRIBUTED A SCORE, NOT POINTS ────────────────────────
    //
    // Every `scorecard` ledger row carries `points: 0` and a `score`, because
    // the board adds the AVERAGE of the scores rather than the rows. Drawn
    // through the same Delta as a grant, each one rendered a rising triangle
    // in the palette's `good` ink beside "0" and said "plus 0 points" aloud —
    // a movement that did not happen, in the colour reserved for good news —
    // while the 85 that actually fed the average never reached the screen.
    testWidgets(
      'a scorecard row shows the score it fed in, and never a rising +0',
      (tester) async {
        await pumpMe(tester);

        final row = find.byKey(const ValueKey<String>('ledger-p3'));
        expect(row, findsOneWidget);
        // The figure it contributed, through FigureSlot like every other
        // number on this screen.
        expect(
          find.descendant(of: row, matching: find.byType(FigureSlot)),
          findsOneWidget,
        );
        expect(find.descendant(of: row, matching: find.text('85')), findsOneWidget);
        // And no delta at all: a delta never stands beside nothing.
        expect(
          find.descendant(of: row, matching: find.byType(Delta)),
          findsNothing,
        );
      },
    );

    testWidgets('and a screen reader hears the score, not "plus 0 points"', (
      tester,
    ) async {
      await pumpMe(tester);
      final label = tester
          .getSemantics(find.byKey(const ValueKey<String>('ledger-p3')))
          .label;
      expect(label, contains('Scorecard'));
      expect(label, contains('85'));
      expect(label, isNot(contains('plus 0 points')));
      expect(label, isNot(contains('plus 0')));
    });

    // ── A DEACTIVATED SCHEME IS NOT A PROMISE ──────────────────────────────
    //
    // `GET /incentives` returns every scheme the manager has ever written,
    // running or ended, because a manager has to see a paused one to start it
    // again. The payout read considers `active: true` alone. A bar driven by
    // an ended scheme tells an agent over the threshold that R 250 of airtime
    // is theirs, for airtime nobody will send.
    testWidgets('an ended scheme does not promise a reward', (tester) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          earnings: earningsFixture(
            visitsSubmitted: 22,
            schemes: const <IncentiveScheme>[
              IncentiveScheme(
                id: 'ended',
                name: 'Twenty stores',
                metric: 'visits',
                threshold: 20,
                rewardPoints: 250,
                rewardDetail: 'R 250 airtime',
                active: false,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(TorchProgressBar), findsNothing);
      expect(find.textContaining('R 250 airtime'), findsNothing);
      expect(find.textContaining('Reward reached'), findsNothing);
      expect(find.text('No reward is running.'), findsOneWidget);
    });

    testWidgets('while a running one beside it still does', (tester) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          earnings: earningsFixture(
            schemes: const <IncentiveScheme>[
              IncentiveScheme(
                id: 'ended',
                name: 'Ten stores',
                metric: 'visits',
                threshold: 10,
                rewardPoints: 100,
                rewardDetail: 'R 100 airtime',
                active: false,
              ),
              IncentiveScheme(
                id: 'running',
                name: 'Twenty stores',
                metric: 'visits',
                threshold: 20,
                rewardPoints: 250,
                rewardDetail: 'R 250 airtime',
              ),
            ],
          ),
        ),
      );

      // The ended scheme is the nearer threshold and already cleared, so it
      // would have won the focus outright.
      expect(find.byKey(const ValueKey<String>('reward-bar')), findsOneWidget);
      expect(find.textContaining('R 250 airtime'), findsWidgets);
      expect(find.textContaining('R 100 airtime'), findsNothing);
    });
  });

  group('the states', () {
    testWidgets('loading is the real geometry, not a spinner', (tester) async {
      await pumpMe(
        tester,
        settle: false,
        repository: FakeMyRecordRepository(hang: true),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(SkeletonShell), findsWidgets);
    });

    testWidgets('no visits yet is a sentence, not an empty list', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(visits: <MyVisit>[]),
      );
      expect(find.text('No visits yet'), findsOneWidget);
    });

    testWidgets(
      'a failed visits read keeps the earnings on screen — two reads, two '
      'regions',
      (tester) async {
        await pumpMe(
          tester,
          repository: FakeMyRecordRepository(visitsThrow: true),
        );
        expect(find.text('Your visits did not load'), findsOneWidget);
        // The bar survived it.
        expect(
          find.byKey(const ValueKey<String>('reward-bar')),
          findsOneWidget,
        );
      },
    );

    testWidgets('and a failed earnings read keeps the visits', (tester) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(earningsThrow: true),
      );
      expect(find.text('Your points did not load'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('my-visit-v1')), findsOneWidget);
    });

    testWidgets('the error never leaks the exception into the frame', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(visitsThrow: true),
      );
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.textContaining('no signal'), findsNothing);
    });

    testWidgets('at 2.0× nothing overflows', (tester) async {
      await pumpMe(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and in Afrikaans at 2.0× nothing overflows either', (
      tester,
    ) async {
      await pumpMe(tester, textScale: 2.0, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
    });

    // ── THE LEDGER SPEAKS THE SCREEN'S LANGUAGE ────────────────────────────
    //
    // `PointsEntry.reasonLabel` is a Dart switch returning English literals —
    // right for the manager console, which is English-only, and wrong here.
    // Every other string on this screen was translated, and these rows drew
    // "Visit submitted" inside an Afrikaans page and read it aloud inside an
    // Afrikaans sentence. It also meant the overflow test above was measuring
    // English widths for the rows it claims to measure Afrikaans ones for.
    testWidgets('the ledger reasons are in the agent\'s language', (
      tester,
    ) async {
      await pumpMe(tester, locale: const Locale('af'));

      expect(find.text('Besoek ingedien'), findsWidgets);
      expect(find.text('Telkaart'), findsWidgets);
      expect(find.text('Visit submitted'), findsNothing);
      expect(find.text('Scorecard'), findsNothing);
    });

    testWidgets('and a screen reader hears one language, not two', (
      tester,
    ) async {
      await pumpMe(tester, locale: const Locale('af'));
      final label = tester
          .getSemantics(find.byKey(const ValueKey<String>('ledger-p1')))
          .label;
      expect(label, contains('Besoek ingedien'));
      expect(label, contains('punte'));
      expect(label, isNot(contains('Visit submitted')));
    });
  });

  // Contests held the nav's fourth slot until Me took it back. The capability
  // moved here rather than vanishing — the agent's Contests entry has
  // vanished once before in this project and only a test caught it — so the
  // same three promises the slot kept are asserted on the row that replaced
  // it: it opens the standings, it wears the running count, and the count is
  // a sentence.
  group('the way to Contests', () {
    testWidgets('a row opens the agent\'s standings, and back returns here', (
      tester,
    ) async {
      await pumpMe(tester);
      final row = find.byKey(const ValueKey<String>('me-contests'));
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Contests view'), findsOneWidget);
      // Pushed, not gone: the agent came from their record, and back is
      // their record.
      final router = GoRouter.of(tester.element(find.text('Contests view')));
      expect(router.canPop(), isTrue);
    });

    testWidgets('it wears the running count, in words', (tester) async {
      await pumpMe(tester, runningContests: 2);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('me-contests')),
          matching: find.text('2 contests running'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nothing running: the row stays, without a count', (
      tester,
    ) async {
      await pumpMe(tester);
      expect(find.text('See where you stand'), findsOneWidget);
      expect(find.textContaining('running'), findsNothing);
    });

    testWidgets('and the Me slot carries the badge Contests used to', (
      tester,
    ) async {
      await pumpMe(tester, runningContests: 2);
      final slot = tester
          .widget<TorchNavPill>(find.byType(TorchNavPill))
          .slots[TodayFrame.meSlot];
      expect(slot.badgeCount, 2);
      expect(slot.semanticLabel, '2 contests running');
    });

    testWidgets('and it survives a failed points read', (tester) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(earningsThrow: true),
      );
      expect(find.byKey(const ValueKey<String>('me-contests')), findsOneWidget);
    });
  });

  group('the frame', () {
    testWidgets('it is a tab root: a nav pill and no thumb zone', (
      tester,
    ) async {
      await pumpMe(tester);
      expect(find.byType(TorchNavPill), findsOneWidget);
      expect(find.byType(TorchThumbZone), findsNothing);
      // Four slots, the maximum — Me is back.
      final pill = tester.widget<TorchNavPill>(find.byType(TorchNavPill));
      expect(pill.slots.length, 4);
      expect(pill.activeIndex, 3);
      expect(pill.slots.last.label, 'Me');
      // Every slot keeps its sentence whether or not the bar shows labels.
      expect(find.bySemanticsLabel(RegExp(r'^Me')), findsWidgets);
    });

    testWidgets('the skin cycle is the header\'s one trailing button', (
      tester,
    ) async {
      await pumpMe(tester);
      final header = tester.widget<TorchAppHeader>(find.byType(TorchAppHeader));
      expect(header.trailing, isNotNull);
      expect(header.title, 'Me');
    });

    testWidgets('there is no primary and no nav circle on this route', (
      tester,
    ) async {
      await pumpMe(tester);
      expect(find.byType(TorchPrimaryButton), findsNothing);
      expect(find.byType(TorchNavCircle), findsNothing);
    });

    testWidgets('a tab takes the agent to its destination', (tester) async {
      await pumpMe(tester);
      // By semantics, not by the visible label: four slots at 360dp send the
      // whole bar icon-only, and each slot keeps its "Today, tab 1 of 4"
      // sentence when it does. Icon-only is a layout decision and never an
      // accessibility one, and this is the assertion that holds it to that.
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Today')).first);
      await tester.pumpAndSettle();
      expect(find.text('Today screen'), findsOneWidget);
    });
  });

  group('the amber census, per phase and per skin', () {
    // Night: 1 — the nav's active tab, and nothing else. The content claims
    // nothing, which is unify's ruling for a screen that is read rather than
    // acted on. Day and Veld: 0, because on a light ground the ladder's one
    // rung is the primary commit block and there is no primary here.
    const Map<SkinMode, int> expected = <SkinMode, int>{
      SkinMode.night: 1,
      SkinMode.day: 0,
      SkinMode.veld: 0,
    };

    for (final mode in agentSkinModes) {
      testWidgets('${mode.name} · loaded lights ${expected[mode]}', (
        tester,
      ) async {
        await pumpMe(tester, skin: mode, size: mePhone);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'me',
          phase: 'loaded',
        );
        expect(census.objectCount, expected[mode], reason: census.describe());
      });

      testWidgets('${mode.name} · loading lights ${expected[mode]}', (
        tester,
      ) async {
        // `hang: true`, and it is load-bearing. The default fake answers from
        // a plain `async` body, which resolves in a microtask, and `pump()`
        // flushes microtasks — so this row used to measure the LOADED frame
        // and file it under `phase: 'loading'`. `expectWithinAmberBudget`
        // reads `phase` only to build a failure message, so nothing caught it
        // and a shimmer added to the skeleton would have shipped with a green
        // census claiming to have checked it.
        await pumpMe(
          tester,
          skin: mode,
          settle: false,
          size: mePhone,
          repository: FakeMyRecordRepository(hang: true),
        );
        // The row can never silently stop being about loading.
        expect(find.byType(SkeletonShell), findsWidgets);
        expect(find.byKey(const ValueKey<String>('reward-bar')), findsNothing);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'me',
          phase: 'loading',
        );
        expect(census.objectCount, expected[mode], reason: census.describe());
      });

      testWidgets('${mode.name} · error lights ${expected[mode]}', (
        tester,
      ) async {
        await pumpMe(
          tester,
          skin: mode,
          size: mePhone,
          repository: FakeMyRecordRepository(
            visitsThrow: true,
            earningsThrow: true,
          ),
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'me',
          phase: 'error',
        );
        expect(census.objectCount, expected[mode], reason: census.describe());
      });

      testWidgets('${mode.name} · empty lights ${expected[mode]}', (
        tester,
      ) async {
        await pumpMe(
          tester,
          skin: mode,
          size: mePhone,
          repository: FakeMyRecordRepository(
            visits: <MyVisit>[],
            earnings: earningsFixture(schemes: const <IncentiveScheme>[]),
          ),
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'me',
          phase: 'empty',
        );
        expect(census.objectCount, expected[mode], reason: census.describe());
      });
    }

    testWidgets('the reward bar is never the thing that is lit', (
      tester,
    ) async {
      // A bar at 95% of its threshold is the single most tempting object in
      // the product to light, and unify §1.18 deletes the near-reward
      // exception in so many words.
      await pumpMe(
        tester,
        size: mePhone,
        repository: FakeMyRecordRepository(
          earnings: earningsFixture(visitsSubmitted: 19),
        ),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('the route declares no content claim at all', (tester) async {
      await pumpMe(tester);
      final scope = TorchScope.maybeOf(
        tester.element(find.byType(TorchNavPill)),
      );
      expect(scope, isNotNull);
      // The nav's active tab is added by TorchScope itself, so no route can
      // forget to count the chrome it did not draw.
      expect(scope!.allocation.isLit(TorchScope.navActiveTabId), isTrue);
    });
  });

  group('location sharing has an answer here too (#153, POPIA)', () {
    // Me is an agent tab root like the other three: the controllers behind
    // the banners only start when something watches them, so a tab without
    // them drops the notice, the indicator and the pings.
    testWidgets('sharing on: the standing indicator', (tester) async {
      await pumpMe(
        tester,
        extraOverrides: <Override>[
          locationSharingControllerProvider.overrideWith(
            () => _Location(LocationConsent.acknowledged),
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey<String>('location-sharing-indicator')),
        findsOneWidget,
      );
    });

    testWidgets('not asked yet: the notice, whose yes never lights here', (
      tester,
    ) async {
      await pumpMe(
        tester,
        extraOverrides: <Override>[
          locationSharingControllerProvider.overrideWith(() => _Location(null)),
        ],
      );
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
            'its ink form and Night stays at the nav tab alone.',
      );
    });
  });
}

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
