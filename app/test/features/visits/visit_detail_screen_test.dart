import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/evidence_thumb.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart' show torchSkins;
import 'visit_harness.dart';

/// THE MANAGER'S VISIT REVIEW, on Torchlight.
///
/// Every status is a word beside its mark; no finding rides on colour alone.
/// Unknown is never zero. A deep link keeps its way out.

/// The one photograph in the fixture. Its wall-clock rendering depends on the
/// reader's zone, so every assertion about it is computed from this.
final DateTime _photoTakenAt = DateTime.utc(2026, 9, 14, 7, 5);

void main() {
  group('the frame', () {
    testWidgets('names the outlet, the visit and the agent', (tester) async {
      await pumpVisit(tester, detail: submittedVisit());

      expect(find.text('Spar Rosebank'), findsOneWidget);
      expect(
        find.textContaining('Visit review'),
        findsWidgets,
        reason: 'the header facts say what this screen is',
      );
      expect(find.textContaining('SPR-001'), findsWidgets);
      expect(find.textContaining('thandi@acme.test'), findsWidgets);
    });

    testWidgets('a push from a list goes back to that list', (tester) async {
      await pumpVisit(tester, detail: submittedVisit(), pushed: true);
      expect(find.text('Spar Rosebank'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('visit-detail-back')));
      await tester.pumpAndSettle();
      expect(find.text('the alerts list'), findsOneWidget);
    });

    // A deep link has nothing to pop to. Losing this escape strands a
    // reviewer on a screen with no exit, which is why it is a test and not a
    // convention.
    testWidgets('a deep link goes to the console instead', (tester) async {
      await pumpVisit(tester, detail: submittedVisit());

      final back = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('visit-detail-back')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(back.properties.label, 'Back to The Floor');

      await tester.tap(find.byKey(const ValueKey<String>('visit-detail-back')));
      await tester.pumpAndSettle();
      expect(find.text('the floor'), findsOneWidget);
    });

    testWidgets('a failed fetch offers a retry, not a raw exception', (
      tester,
    ) async {
      await pumpVisit(tester, failure: Exception('network down'));
      expect(
        find.byKey(const ValueKey<String>('visit-detail-retry')),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('a visit that is not there says so, with a way on', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        failure: const VisitNotFoundException('v-missing'),
        visitId: 'v-missing',
      );

      expect(find.byKey(const ValueKey<String>('visit-not-found')), findsOneWidget);
      expect(find.text('This visit is not here'), findsOneWidget);
      // The id is readable back to support, in the identifier face.
      expect(find.text('v-missing'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('visit-not-found-alerts')),
        findsOneWidget,
      );
    });

    testWidgets('a pending fetch is a skeleton, never a stale screen', (
      tester,
    ) async {
      await pumpVisit(tester, pending: true);
      expect(find.byType(Skeleton), findsOneWidget);
      expect(find.text('Spar Rosebank'), findsNothing);
    });
  });

  group('the visit itself', () {
    testWidgets('check-in, submit and the time on site', (tester) async {
      await pumpVisit(tester, detail: submittedVisit());

      final checkedIn = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-checked-in')),
      );
      expect(checkedIn.semanticsLabel, contains('14 Sep 2026'));
      expect(checkedIn.subtitle, "From the phone's own clock");

      final submitted = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-submitted')),
      );
      expect(submitted.subtitle, '14 minutes on site');
    });

    testWidgets('a draft says not yet, and carries no dwell', (tester) async {
      await pumpVisit(tester, detail: draftVisit());

      final submitted = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-submitted')),
      );
      expect(submitted.semanticsLabel, contains('Not yet'));
      expect(submitted.subtitle, isNull);
      expect(
        find.byKey(const ValueKey<String>('visit-flag-unfinished')),
        findsOneWidget,
      );
    });

    testWidgets('inside the fence is a distance and a word', (tester) async {
      await pumpVisit(tester, detail: submittedVisit());

      final geofence = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-geofence')),
      );
      expect(geofence.subtitle, 'Inside the fence');
      expect(geofence.semanticsLabel, contains('44'));
      expect(
        find.byKey(const ValueKey<String>('visit-flag-out-of-fence')),
        findsNothing,
      );
    });

    testWidgets('outside the fence is a flag chip carrying the distance', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(geofencePass: false, distanceM: 61),
      );

      final chip = tester.widget<FlagChip>(
        find.byKey(const ValueKey<String>('visit-flag-out-of-fence')),
      );
      // Out of fence is a measurement, not a verdict: the neutral treatment,
      // with the measured distance hung off the word.
      expect(chip.kind, FlagKind.outOfFence);
      expect(chip.detail, contains('61'));
    });

    // A nought here would read as a perfect check-in.
    testWidgets('a missing distance is words, never 0 m', (tester) async {
      await pumpVisit(tester, detail: submittedVisit(distanceM: null));

      final geofence = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-geofence')),
      );
      expect(geofence.subtitle, 'No distance was recorded');
      expect(geofence.semanticsLabel, contains('—'));
      expect(geofence.semanticsLabel, isNot(contains('0')));
    });

    // Outside the fence BECAUSE the agent said the pin is wrong (#386).
    // Without this a reviewer cannot tell a depot-pinned outlet from a faked
    // visit, and that is the whole difference.
    testWidgets('a disputed pin is stated, with who answered it', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(
          geofencePass: false,
          distanceM: 900,
          pinDispute: const VisitPinDispute(
            id: 'd1',
            distanceM: 900,
            status: 'applied',
            note: 'The pin is on the depot',
            resolvedByLabel: 'Nomsa D.',
          ),
        ),
      );

      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-pin-dispute')),
      );
      expect(row.subtitle, contains('The pin was moved by Nomsa D.'));
      expect(row.subtitle, contains('The pin is on the depot'));
      expect(find.byKey(const ValueKey<String>('visit-flag-pin')), findsOneWidget);
    });

    testWidgets('an ordinary out-of-fence visit carries no pin claim', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit(geofencePass: false));
      expect(find.byKey(const ValueKey<String>('visit-flag-pin')), findsNothing);
    });
  });

  group('the score', () {
    testWidgets('the figure, the band as a mark and a word, and the meter', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      expect(
        find.byKey(const ValueKey<String>('visit-score-figure')),
        findsOneWidget,
      );
      expect(find.text('Gap'), findsOneWidget);
      // The hero is ink-1 at every band: a severity-coded figure at 72px is a
      // hue doing a number's job.
      final hero = tester.widget<FigureSlot>(
        find.byKey(const ValueKey<String>('visit-score-figure')),
      );
      expect(hero.color, TiqSkin.night().palette.ink1);
      expect(hero.value, 55);
      // And the mark beside the word, so the band survives greyscale.
      expect(find.byType(SeverityMark), findsWidgets);
    });

    testWidgets('a band this build does not know is not guessed at', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(
          score: const VisitScore(
            weightedTotal: 61,
            ratingBand: 'chartreuse',
            target: 85,
            dimensions: <ScoreDimension>[],
          ),
        ),
      );

      expect(find.text('Unbanded'), findsOneWidget);
      expect(find.text('Gap'), findsNothing);
    });

    testWidgets('a draft says the score comes on submit', (tester) async {
      await pumpVisit(tester, detail: draftVisit());
      expect(find.text('Not scored'), findsOneWidget);
      expect(
        find.text('The score is calculated when the visit is submitted.'),
        findsOneWidget,
      );
    });

    // A different fact from a draft, and the reviewer needs to know which.
    testWidgets('a submitted visit with no scorecard says that instead', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit(score: null));
      expect(
        find.text('No scorecard has been generated for this visit.'),
        findsOneWidget,
      );
    });

    testWidgets('a measured dimension carries its figure, meter and word', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      final availability = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-dimension-availability')),
      );
      expect(availability.title, 'Availability');
      expect(availability.subtitle, 'On target');
      expect(availability.semanticsLabel, contains('90 out of 100'));

      final pricing = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-dimension-pricing')),
      );
      expect(pricing.subtitle, 'Below target');
    });

    // #93: absent is not nought. A zero would read as "you scored nothing on
    // this" for something nobody was given a chance to do.
    testWidgets('an unmeasured dimension is a dash, a hatch and a reason', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      expect(
        find.byKey(const ValueKey<String>('visit-unmeasured-competitive')),
        findsOneWidget,
      );
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-dimension-competitive')),
      );
      expect(row.subtitle, 'Not measured');
      expect(row.semanticsLabel, contains('not measured'));
      expect(row.trailing, isNull);
    });
  });

  group('what was captured', () {
    testWidgets('each section keeps its glyph, its word and its findings', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      final stock = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-section-stock')),
      );
      // The section's name is the agent's own — the manager and the agent
      // call a capture section the same thing, which is what reusing the key
      // is for.
      expect(stock.title, 'Stock & availability');
      expect(stock.subtitle, contains('1 flagged'));
      expect(stock.subtitle, contains('2 captured'));
      expect(stock.severity, SoftRowSeverity.watch);
      expect(stock.severityLabel, 'Watch');
      // `meta` is inside the row's excluded label, so the findings have to be
      // said in the label or they are painted and announced nowhere.
      expect(stock.semanticsLabel, contains('1 of 2 SKUs out of stock'));
      expect(stock.semanticsLabel, contains('Cola 330ml'));
    });

    // A flagged risk is an in-store hazard; an execution gap is not.
    testWidgets('a flagged risk is critical, everything else is watch', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      final risks = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-section-risks')),
      );
      expect(risks.severity, SoftRowSeverity.critical);
      expect(risks.severityLabel, 'Critical');
    });

    testWidgets('a section nobody opened says so and carries no severity', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      final competitive = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-section-competitive')),
      );
      expect(competitive.subtitle, contains('Not captured'));
      expect(competitive.severity, SoftRowSeverity.none);
      expect(
        competitive.semanticsLabel,
        contains('Nothing was recorded in this section.'),
      );
    });

    testWidgets('a cut findings list says it was cut', (tester) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(
          sections: const <VisitSectionSummary>[
            VisitSectionSummary(
              key: 'stock',
              count: 900,
              flagged: 4,
              findings: <String>['4 of 900 SKUs out of stock'],
              truncated: true,
            ),
          ],
        ),
      );
      expect(
        find.text('Findings drawn from the first 500 rows.'),
        findsOneWidget,
      );
    });
  });

  group('photos', () {
    testWidgets('a thumbnail per photo, each labelled with what it is of', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      expect(find.byKey(const ValueKey<String>('visit-photo-p1')), findsOneWidget);
      final thumb = tester.widget<TorchEvidenceThumb>(
        find.byType(TorchEvidenceThumb),
      );
      // Computed, never pinned: the screen renders the photo's time in the
      // reader's own zone, and a hardcoded '09:05' is a test that passes in
      // Johannesburg and fails on a UTC runner.
      expect(
        thumb.semanticLabel,
        'Spar Rosebank, visibility, ${clockOf(_photoTakenAt.toLocal())}',
      );
    });

    testWidgets('no photos is said in words — on a review it is a signal', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(
          photoTotal: 0,
          photos: const <VisitPhotoRef>[],
        ),
      );
      expect(
        find.text('No photos were captured on this visit.'),
        findsOneWidget,
      );
      expect(find.byType(TorchEvidenceThumb), findsNothing);
    });

    testWidgets('a cut photo list never reads as everything captured', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit(photoTotal: 9));
      expect(find.text('Showing 1 of 9'), findsOneWidget);
    });

    // unify §4: Veld renders no thumbnails. The figure list that replaces
    // them is what a screen reader has always been given.
    testWidgets('Veld draws the figure list instead of thumbnails', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(),
        skin: TiqSkin.veld(),
      );

      expect(find.byType(TorchEvidenceThumb), findsNothing);
      await scrollVisitTo(
        tester,
        find.byKey(const ValueKey<String>('visit-photo-p1')),
      );
      expect(find.byKey(const ValueKey<String>('visit-photo-p1')), findsOneWidget);
      expect(find.text(clockOf(_photoTakenAt.toLocal())), findsOneWidget);
    });
  });

  group('fraud signals', () {
    testWidgets('the risk figure, its band and one row per signal', (
      tester,
    ) async {
      await pumpVisit(tester, detail: submittedVisit());

      final figure = tester.widget<FigureSlot>(
        find.byKey(const ValueKey<String>('visit-risk-figure')),
      );
      expect(figure.value, 72);
      // ink-1, like the score: the mark and the word beside it carry the band.
      expect(figure.color, TiqSkin.night().palette.ink1);
      expect(find.text('High risk'), findsOneWidget);

      final signal = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('visit-signal-photo_gps_divergence')),
      );
      expect(signal.title, contains('GPS tag is 500m'));
      expect(signal.semanticsLabel, contains('photo_gps_divergence'));
    });

    testWidgets('a visit with no signals carries no fraud section', (
      tester,
    ) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(signals: const <FraudSignal>[]),
      );
      expect(find.byKey(const ValueKey<String>('visit-fraud')), findsNothing);
    });

    testWidgets('a draft carries no fraud section either', (tester) async {
      await pumpVisit(tester, detail: draftVisit());
      expect(find.byKey(const ValueKey<String>('visit-fraud')), findsNothing);
    });
  });

  group('every control is operable by a screen reader', () {
    testWidgets('the back control and the retry', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpVisit(tester, detail: submittedVisit());
      expectEveryButtonActivatable(tester);

      await pumpVisit(tester, failure: Exception('boom'));
      expectEveryButtonActivatable(tester);

      await pumpVisit(
        tester,
        failure: const VisitNotFoundException('v-missing'),
        visitId: 'v-missing',
      );
      expectEveryButtonActivatable(tester);
      handle.dispose();
    });
  });

  group('the amber census, per phase × skin', () {
    for (final skin in torchSkins) {
      for (final phase in const <String>[
        'submitted',
        'draft',
        'not-found',
        'error',
      ]) {
        testWidgets('${skin.mode.name} · $phase', (tester) async {
          await pumpVisit(
            tester,
            skin: skin,
            size: const Size(400, 900),
            detail: switch (phase) {
              'draft' => draftVisit(),
              'submitted' => submittedVisit(),
              _ => null,
            },
            failure: switch (phase) {
              'not-found' => const VisitNotFoundException('v-missing'),
              'error' => Exception('boom'),
              _ => null,
            },
          );

          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'visit-review',
            phase: phase,
          );
          // A review records no decision, so nothing on the route is armed —
          // and with no nav there is no chrome grant either.
          expect(census.objectCount, 0, reason: census.describe());
        });
      }
    }
  });

  group('2.0× text and Afrikaans', () {
    testWidgets('nothing overflows at 2.0× on a 320dp phone', (tester) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(
          geofencePass: false,
          pinDispute: const VisitPinDispute(
            id: 'd1',
            distanceM: 900,
            status: 'pending',
            note: 'The pin is on the depot round the back',
          ),
        ),
        textScale: 2.0,
        size: const Size(320, 5000),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the review reads in Afrikaans', (tester) async {
      await pumpVisit(
        tester,
        detail: submittedVisit(),
        locale: const Locale('af'),
      );

      expect(find.textContaining('Besoekhersiening'), findsWidgets);
      expect(find.text('Die besoek'), findsOneWidget);
      expect(find.text('Aangemeld'), findsOneWidget);
      expect(find.text('Perfekte-winkel telling'), findsOneWidget);
      expect(find.text('Hoe dit bepunt is'), findsOneWidget);
      expect(find.text('Wat vasgelê is'), findsOneWidget);
      expect(find.text('Bedrogseine'), findsOneWidget);
      // And none of the English it replaced.
      expect(find.text('The visit'), findsNothing);
      expect(find.text('Perfect store score'), findsNothing);
    });
  });
}
