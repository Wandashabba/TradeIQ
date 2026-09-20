import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/torch_scope.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';

import 'amber_fixtures.dart';
import 'amber_golden.dart';

/// The amber budget, counted in pixels rather than in promises.
void main() {
  group('the classifier knows amber from everything beside it', () {
    // If this drifts, every count below is meaningless — so it is checked
    // against the real tokens before anything is rendered.
    bool flame(Color c) => isFlameHued(
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
    );

    test('every emitted amber token is counted', () {
      final p = TiqSkin.night().palette;
      for (final MapEntry(key: name, value: token) in <String, Color>{
        'flame500': p.flame500,
        'flame600': p.flame600,
        'flame700': p.flame700,
        'flame900 (the bloom core)': p.flame900,
      }.entries) {
        expect(
          flame(token),
          isTrue,
          reason: '$name is emitted amber and the census must see it.',
        );
      }
    });

    test('no warm neutral and no surface is counted', () {
      for (final skin in <TiqSkin>[
        TiqSkin.night(),
        TiqSkin.day(),
        TiqSkin.veld(),
      ]) {
        final p = skin.palette;
        for (final MapEntry(key: name, value: token) in <String, Color>{
          'ground': p.ground,
          'vignette': p.vignette,
          'well': p.well,
          'surface': p.surface,
          'raised': p.raised,
          'lifted': p.lifted,
          'ink1': p.ink1,
          'ink2 (Oatmeal)': p.ink2,
          'ink3': p.ink3,
          'chartNeutral': p.chartNeutral,
          'comparison (Truffle)': p.comparison,
          'good': p.good,
          'bad': p.bad,
          'edgeStructure': p.edgeStructure,
          'edgeControl': p.edgeControl,
          // Amber, but ink rather than light: it is the one amber legal as
          // text on a light ground, and a word is not a light source.
          'flame300': p.flame300,
        }.entries) {
          expect(
            flame(token),
            isFalse,
            reason:
                '${skin.mode.name}.$name is inside the flame box. Oatmeal in '
                'particular sits one hundredth of a saturation point outside '
                'it — Burning Flame and Oatmeal have identical relative '
                'luminance, which is the collision chart-neutral exists to '
                'fix. If a token moved, this census has started counting text '
                'as light.',
          );
        }
      }
    });
  });

  group('the connected-components count itself', () {
    // The pixel arithmetic, over a buffer built by hand. A harness whose own
    // counting is never checked reports whatever it feels like.
    Uint8List canvas(int w, int h, Color ground) {
      final bytes = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        bytes[i * 4] = (ground.r * 255).round();
        bytes[i * 4 + 1] = (ground.g * 255).round();
        bytes[i * 4 + 2] = (ground.b * 255).round();
        bytes[i * 4 + 3] = 255;
      }
      return bytes;
    }

    void paint(Uint8List b, int w, Rect r, Color c) {
      for (var y = r.top.toInt(); y < r.bottom; y++) {
        for (var x = r.left.toInt(); x < r.right; x++) {
          final i = (y * w + x) * 4;
          b[i] = (c.r * 255).round();
          b[i + 1] = (c.g * 255).round();
          b[i + 2] = (c.b * 255).round();
          b[i + 3] = 255;
        }
      }
    }

    final p = TiqSkin.night().palette;

    test('an empty frame has no objects', () {
      final census = censusOfPixels(
        canvas(40, 40, p.ground),
        width: 40,
        height: 40,
      );
      expect(census.objectCount, 0);
      expect(census.litPixels, 0);
    });

    test('two separated blocks are two objects', () {
      final b = canvas(60, 60, p.ground);
      paint(b, 60, const Rect.fromLTRB(2, 2, 12, 12), p.flame600);
      paint(b, 60, const Rect.fromLTRB(40, 40, 50, 50), p.flame600);
      expect(censusOfPixels(b, width: 60, height: 60).objectCount, 2);
    });

    test('two touching blocks are one object', () {
      final b = canvas(60, 60, p.ground);
      paint(b, 60, const Rect.fromLTRB(2, 2, 12, 12), p.flame600);
      paint(b, 60, const Rect.fromLTRB(12, 2, 22, 12), p.flame500);
      expect(
        censusOfPixels(b, width: 60, height: 60).objectCount,
        1,
        reason:
            'A rim and the fill it rims are one lit object, not two. The '
            'budget counts objects, and a block with a hot edge is a block.',
      );
    });

    test('a diagonal 1px rim is one object, not a staircase', () {
      final b = canvas(60, 60, p.ground);
      for (var i = 2; i < 40; i++) {
        paint(
          b,
          60,
          Rect.fromLTWH(i.toDouble(), i.toDouble(), 1, 1),
          p.flame600,
        );
      }
      expect(
        censusOfPixels(b, width: 60, height: 60, minimumArea: 4).objectCount,
        1,
        reason: 'Eight-connectivity is what makes a diagonal a line.',
      );
    });

    test('a hole in a lit block is not a second light', () {
      // The nav's active tab: a solid amber pill with dark ink on it. Every
      // counter of every `o`, and the inside of every outlined glyph, is an
      // island of amber with a ring of ink around it — eight-connected, over
      // the minimum area, and not a light. Before this rule a tab whose slot
      // said "Today" counted as four.
      final b = canvas(60, 60, p.ground);
      paint(b, 60, const Rect.fromLTRB(4, 4, 56, 40), p.flame600);
      // A ring of ink, enclosing a smaller square of the block's own fill.
      paint(b, 60, const Rect.fromLTRB(20, 14, 40, 30), p.onAmber);
      paint(b, 60, const Rect.fromLTRB(24, 18, 36, 26), p.flame600);

      final census = censusOfPixels(b, width: 60, height: 60);
      expect(
        census.objectCount,
        1,
        reason:
            'a lit object is not enclosed by another lit object\n'
            '${census.describe()}',
      );
      expect(
        census.litPixels,
        greaterThan(0),
        reason: 'the pixels are still counted; they are simply not a light',
      );
    });

    test('two lights that merely overlap are still two', () {
      // The containment test is on the bounds and it is strict on purpose: a
      // rim whose box overlaps a circle's box is two lights, not one.
      final b = canvas(60, 60, p.ground);
      paint(b, 60, const Rect.fromLTRB(2, 2, 30, 30), p.flame600);
      paint(b, 60, const Rect.fromLTRB(20, 34, 50, 50), p.flame500);
      expect(censusOfPixels(b, width: 60, height: 60).objectCount, 2);
    });

    test('a speck under the minimum area is not an object', () {
      final b = canvas(60, 60, p.ground);
      paint(b, 60, const Rect.fromLTRB(2, 2, 4, 4), p.flame600); // 4 px
      final census = censusOfPixels(b, width: 60, height: 60);
      expect(census.objectCount, 0);
      expect(
        census.litPixels,
        4,
        reason:
            'The pixels are still reported; they are just not a light. An '
            'anti-aliased corner is not an object and a harness that said it '
            'was would be switched off within a week.',
      );
    });
  });

  group('fixture routes stay inside the budget', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets('${skin.mode.name} — dashboard, loaded', (tester) async {
        await pumpAmberRoute(
          tester,
          skin: skin,
          child: const AmberDashboardFixture(),
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'dashboard',
          phase: 'loaded',
        );
        // …and the count is the one the ladder predicted, not merely under it.
        // "Under budget" passes for a screen that lost its light entirely.
        final expected = skin.amberIsInk
            ? 1 // the primary commit block, and nothing else
            : 2; // the nav's active tab, and the primary's amber fill
        expect(
          census.objectCount,
          expected,
          reason:
              '${skin.mode.name} dashboard painted ${census.objectCount} '
              'amber objects; the ladder grants $expected.\n'
              '${census.describe()}',
        );
      });

      testWidgets('${skin.mode.name} — visit, in-visit', (tester) async {
        await pumpAmberRoute(
          tester,
          skin: skin,
          child: const AmberVisitFixture(),
        );
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'visit',
          phase: 'in-visit',
        );
        expect(
          census.objectCount,
          // Untabbed and dark: two content grants, the plate's strip light and
          // the live pulse. On a light ground nothing here is a commit action,
          // so nothing is armed and there is no amber at all.
          skin.amberIsInk ? 0 : 2,
          reason: '${skin.mode.name} visit route:\n${census.describe()}',
        );
      });
    }

    testWidgets('a sheet extinguishes the amber beneath it', (tester) async {
      final night = TiqSkin.night();
      await pumpAmberRoute(
        tester,
        skin: night,
        child: TorchScope(
          skin: night,
          phase: 'sheet-open',
          navRenders: true,
          tabbedRoute: true,
          beneathSheet: true,
          claims: <TorchClaim>[TorchClaim.primaryCommit('commit')],
          child: const _SheetLitBlock(claimId: 'commit'),
        ),
      );
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        0,
        reason:
            'While a sheet is up the nav tab drops to its ink form and the '
            "plate's light goes off, so the sheet's own scope genuinely owns "
            'the screen — which is how the 72% scrim keeps the held work '
            'visible behind it instead of hiding it under 88%.\n'
            '${census.describe()}',
      );

      final allocation = TorchScope.resolve(
        skin: night,
        claims: <TorchClaim>[
          TorchClaim.primaryCommit('commit'),
          TorchClaim.plateStripLight('plate'),
        ],
        navRenders: true,
        tabbedRoute: true,
        beneathSheet: true,
      );
      expect(allocation.granted, isEmpty);
      expect(
        allocation.denied.values,
        everyElement(TorchDenial.extinguishedBySheet),
      );
    });
  });

  group('the harness catches a violation', () {
    // The whole point. A budget check that has never failed is a budget check
    // nobody has run.
    testWidgets('four painted ambers are counted as four', (tester) async {
      final night = TiqSkin.night();
      await pumpAmberRoute(
        tester,
        skin: night,
        child: const AmberOverLitFixture(),
      );
      final census = await amberCensus(tester);
      expect(
        census.objectCount,
        4,
        reason:
            'The deliberately-broken fixture paints four amber blocks and the '
            'census must see all four:\n${census.describe()}',
      );
      expect(census.objectCount, greaterThan(TorchScope.budgetFor(night)));
    });

    testWidgets('and the budget assertion fails on it', (tester) async {
      final night = TiqSkin.night();
      await pumpAmberRoute(
        tester,
        skin: night,
        child: const AmberOverLitFixture(),
      );
      final census = await amberCensus(tester);
      expect(
        () => expectWithinAmberBudget(
          census,
          night,
          route: 'over-lit fixture',
          phase: 'loaded',
        ),
        throwsA(isA<TestFailure>()),
        reason:
            'A harness that cannot fail is not a harness. This is the proof '
            'that it can.',
      );
    });

    testWidgets('one amber too many on a light ground fails too', (
      tester,
    ) async {
      final day = TiqSkin.day();
      await pumpAmberRoute(
        tester,
        skin: day,
        child: const AmberOverLitFixture(),
      );
      final census = await amberCensus(tester);
      expect(census.objectCount, greaterThan(TorchScope.budgetFor(day)));
      expect(
        () => expectWithinAmberBudget(
          census,
          day,
          route: 'over-lit fixture',
          phase: 'loaded',
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}

/// A block that is amber only while its scope says so. Used to prove the
/// sheet rule in pixels rather than in the allocator alone.
class _SheetLitBlock extends StatelessWidget {
  const _SheetLitBlock({required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Center(
      child: Container(
        width: 200,
        height: 56,
        color: TorchScope.lit(context, claimId)
            ? skin.palette.flame600
            : skin.palette.well,
      ),
    );
  }
}
