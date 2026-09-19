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

      final row = find.byKey(const ValueKey<String>('my-visit-v1'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('Kasi Corner Spaza')),
        findsOneWidget,
      );
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

    testWidgets('an unranked agent gets the em dash AND the sentence', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(earnings: earningsFixture(rank: 0)),
      );
      expect(
        find.text('Not ranked yet — too few agents have points this month.'),
        findsOneWidget,
      );
    });

    testWidgets('and a zero-point month prints 0, with its sentence', (
      tester,
    ) async {
      await pumpMe(
        tester,
        repository: FakeMyRecordRepository(
          earnings: earningsFixture(points: 0),
        ),
      );
      expect(find.textContaining('No points yet this month'), findsOneWidget);
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
        expect(find.text('No reward is running this month.'), findsOneWidget);
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
        await pumpMe(tester, skin: mode, settle: false, size: mePhone);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'me',
          phase: 'loading',
        );
        expect(census.objectCount, expected[mode], reason: census.describe());
        await tester.pumpAndSettle();
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
