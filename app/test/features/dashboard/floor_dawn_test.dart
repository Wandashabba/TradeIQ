import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/assistant/data/assistant_events.dart';
import 'package:tradeiq_app/features/dashboard/presentation/floor_dawn.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../../core/widgets/torchlight/torch_harness.dart'
    show TorchPixels, torchPixels;
import '../agent_harness.dart';
import '../assistant/ask_harness.dart' show ScriptedRepository, rankedTurn;
import 'floor_harness.dart';

/// DAWN, MEASURED — the wash, its headroom under the amber census, and the
/// one ratio it moves.
///
/// > *"Lets ship in C. Dawn — the plate's own sky"* — the owner.
///
/// `floor_dawn.dart` makes three claims and every one of them is a number, so
/// all three are measured here rather than argued:
///
/// 1. **It is not amber.** The census counts connected regions of emitted
///    light inside a flame-hue box at **value ≥ 0.90**. This file runs the
///    real census over nine phases in both skins, prints the counts and the
///    regions, and separately reports the **brightest flame-hued pixel in the
///    frame** so the headroom is a figure and not a hope.
/// 2. **It is Night only.** The Day render is pinned against the ground
///    token: every pixel of a column where nothing is drawn is the falloff
///    exactly, which it cannot be if anything washed over it.
/// 3. **It costs two gradients.** Two decorations, no layer, and none of the
///    six banned paint operations anywhere in the frame.
///
/// And the fourth thing, which is the one the owner asked to be told about
/// rather than tuned away: **what the wash does to the ink above it.** The
/// wash lightens the ground under the bottom third of the screen, and on
/// Night that is *light* ink on a *dark* ground — so lightening it lowers the
/// ratio, exactly as lightening it under dark ink would. The table is in
/// `the wash moves one ratio, and here it is`.
void main() {
  setUpAll(loadAgentFonts);

  final outlets = <Outlet>[
    outlet('o1', 'SaveMor Glenwood'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
  ];

  final decisions = <AlertItem>[
    alert(
      id: 'a1',
      outletId: 'o1',
      photoId: 'p1',
      message: 'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
      createdAt: DateTime.utc(2026, 9, 16, 9, 6),
    ),
  ];

  final TiqSkin night = TiqSkin.night();
  final TiqSkin day = TiqSkin.day(density: TiqDensity.console);

  String hex(Color c) =>
      '#'
              '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  /// Stand the screen up at rest, with a photograph on the plate.
  Future<void> floor(
    WidgetTester tester, {
    TiqSkin? skin,
    Size size = const Size(390, 844),
    bool photograph = true,
    bool online = true,
    bool measured = true,
    double textScale = 1.0,
  }) async {
    await pumpFloor(
      tester,
      const TheFloorScreen(),
      size: size,
      skin: skin,
      textScale: textScale,
      online: online,
      plateImage: photograph ? await SyncImage.solid(tester) : null,
      current: measured
          ? kpis(osa: 61, execution: 73, priceCompliance: 74)
          : emptyWindowKpis(),
      previous: measured ? kpis(osa: 64, execution: 92) : null,
      alerts: decisions,
      outlets: outlets,
    );
  }

  /// The same screen through the router harness, with a question typed and —
  /// unless [settle] is false — answered. Typing needs an `Overlay`, which
  /// `pumpFloor` deliberately has none of.
  Future<void> asked(
    WidgetTester tester, {
    TiqSkin? skin,
    Size size = const Size(390, 844),
    bool settle = true,
    bool send = true,
    List<AssistantEvent>? script,
  }) async {
    await pumpFloorRoute(
      tester,
      size: size,
      skin: skin,
      plateImage: await SyncImage.solid(tester),
      current: kpis(osa: 61, execution: 73, priceCompliance: 74),
      previous: kpis(osa: 64, execution: 92),
      alerts: decisions,
      outlets: outlets,
      assistant: ScriptedRepository(script ?? rankedTurn()),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('ask-composer-field')),
      'Why is 73 down?',
    );
    await tester.pump();
    if (!send) return;
    await tester.testTextInput.receiveAction(TextInputAction.send);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  // ── 1. THE WASH IS THERE, AND IT IS THE CSS THE ARTIFACT DREW ────────
  group('the wash', () {
    test('Day asks for nothing at all', () {
      expect(
        floorDawnWash(day),
        isEmpty,
        reason:
            'A glow is emitted light and there is none on a page lit by the '
            'sun. The gate is `skin.amberIsInk`, the same token the send '
            'block and the nav circle read.',
      );
      expect(
        floorDawnWash(TiqSkin.day(density: TiqDensity.field)),
        isEmpty,
        reason: 'The gate is the skin, not the density.',
      );
    });

    test('Night asks for exactly two decorations, in paint order', () {
      final wash = floorDawnWash(night);
      expect(
        wash,
        hasLength(2),
        reason:
            'A BoxDecoration carries one gradient, so two gradients is two '
            'decorations. If this grows, the cost note in floor_dawn.dart is '
            'wrong.',
      );
      final hot = wash.first as BoxDecoration;
      final clay = wash.last as BoxDecoration;
      // The clay is on top, which is the CSS order: a background list paints
      // back to front and the clay is listed first.
      expect((clay.gradient! as RadialGradient).colors.first.a, closeTo(0.30, 0.001));
      expect((hot.gradient! as RadialGradient).colors.first.a, closeTo(0.09, 0.001));
      // The tokens, not two hexes.
      expect(
        (clay.gradient! as RadialGradient).colors.first.withValues(alpha: 1),
        night.palette.comparison,
        reason: 'Truffle — the palette comparison ink, 15.7 degrees off flame.',
      );
      expect(
        (hot.gradient! as RadialGradient).colors.first.withValues(alpha: 1),
        night.palette.flame900,
        reason: 'The white-hot core stop, at nine percent.',
      );
      for (final decoration in wash) {
        expect(
          (decoration as BoxDecoration).boxShadow ?? const <BoxShadow>[],
          isEmpty,
          reason: 'Glow is never a shadow.',
        );
      }
    });
  });

  // ── 2. THE AMBER CENSUS, PER PHASE PER SKIN, PRINTED ─────────────────
  //
  // The real risk and the reason this file exists. Clay is an orange hue:
  // `comparison` sits at 15.7 degrees, which is three degrees outside the
  // census's 20–48 box, but a composite of clay over a navy ground is not
  // clay — it lands wherever the arithmetic puts it, and the census does not
  // care what token a pixel came from. So the counts are run, not assumed.
  group('the amber census', () {
    /// The brightest flame-hued pixel in the frame, and how far it is from the
    /// census's value floor. A pixel over 0.90 would be counted; this is the
    /// margin, measured, on the frame itself.
    (double value, int x, int y) brightestWarm(TorchPixels pixels) {
      var best = 0.0;
      var bx = -1;
      var by = -1;
      for (var y = 0; y < pixels.height; y++) {
        for (var x = 0; x < pixels.width; x++) {
          final c = pixels.at(x + 0.5, y + 0.5);
          final r = (c.r * 255).round();
          final g = (c.g * 255).round();
          final b = (c.b * 255).round();
          final max = math.max(r, math.max(g, b));
          final min = math.min(r, math.min(g, b));
          if (max == 0) continue;
          final saturation = (max - min) / max;
          if (saturation < 0.12) continue;
          final delta = (max - min).toDouble();
          if (delta == 0) continue;
          double hue;
          if (max == r) {
            hue = 60 * (((g - b) / delta) % 6);
          } else if (max == g) {
            hue = 60 * ((b - r) / delta + 2);
          } else {
            hue = 60 * ((r - g) / delta + 4);
          }
          if (hue < 0) hue += 360;
          if (hue < 20 || hue > 48) continue;
          final value = max / 255.0;
          if (value > best) {
            best = value;
            bx = x;
            by = y;
          }
        }
      }
      return (best, bx, by);
    }

    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      for (final phase
          in const <String>[
            'loading',
            'at rest',
            'window-empty',
            'no-picture',
            'offline',
            'typing',
            'answering',
            'answered',
            'answered, scrolled',
          ]) {
        testWidgets('$skinName / $phase', (tester) async {
          switch (phase) {
            case 'loading':
              // The skeleton: no plate photograph, no composer.
              await pumpFloor(
                tester,
                const TheFloorScreen(),
                size: const Size(390, 844),
                skin: skin,
                current: null,
                alerts: decisions,
                outlets: outlets,
              );
            case 'at rest':
              await floor(tester, skin: skin);
            case 'window-empty':
              await floor(tester, skin: skin, measured: false);
            case 'no-picture':
              await floor(tester, skin: skin, photograph: false);
            case 'offline':
              await floor(tester, skin: skin, online: false);
            case 'typing':
              await asked(tester, skin: skin, send: false);
            case 'answering':
              await asked(tester, skin: skin, settle: false);
            case 'answered':
              await asked(tester, skin: skin);
            case 'answered, scrolled':
              await asked(tester, skin: skin);
              await scrollFloorToTail(tester);
          }

          final census = await amberCensus(tester);
          final pixels = await torchPixels(tester);
          final (value, bx, by) = brightestWarm(pixels);

          // ignore: avoid_print
          print(
            'CENSUS $skinName / $phase: ${census.objectCount} object(s), '
            '${census.litPixels} lit px '
            '(${(census.litFraction * 100).toStringAsFixed(3)}%)\n'
            '  regions: ${census.regions.isEmpty ? 'none' : census.regions.join('; ')}\n'
            '  brightest flame-hued pixel: value '
            '${value.toStringAsFixed(3)} at $bx,$by '
            '(${bx < 0 ? 'none' : hex(pixels.at(bx + 0.5, by + 0.5))}) '
            '— the census floor is 0.900',
          );

          expectWithinAmberBudget(
            census,
            skin,
            route: 'the-floor',
            phase: phase,
          );
        });
      }
    }
  });

  // ── 3. DARK SKIN ONLY, PINNED ON THE RENDER ──────────────────────────
  group('Day has no wash', () {
    /// `TorchShell`'s console ground: `ground` at the two edges, `vignette`
    /// across the middle, over a 96dp ramp at each end. Re-derived here so
    /// "what the ground would have been" is a value and not a second render,
    /// and validated against the real frame at every y the wash cannot reach
    /// before it is used anywhere the wash can.
    Color unwashed(TiqSkin skin, double y, double height) {
      final band = height <= 400 ? 0.25 : 96 / height;
      final t = y / height;
      final ground = skin.palette.ground;
      final vignette = skin.palette.vignette;
      if (t <= band) return Color.lerp(ground, vignette, t / band)!;
      if (t >= 1 - band) {
        return Color.lerp(vignette, ground, (t - (1 - band)) / band)!;
      }
      return vignette;
    }

    bool near(Color a, Color b, {int tolerance = 2}) =>
        ((a.r - b.r).abs() * 255).round() <= tolerance &&
        ((a.g - b.g).abs() * 255).round() <= tolerance &&
        ((a.b - b.b).abs() * 255).round() <= tolerance;

    for (final (name, size) in const <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('$name: every bare pixel is the falloff, to the last row', (
        tester,
      ) async {
        await floor(tester, skin: day, size: size);
        final pixels = await torchPixels(tester);
        // x=2 is outside the 20dp gutter, so nothing is drawn on it at any y:
        // the whole column is the shell's ground and nothing else.
        final moved = <String>[];
        for (var y = 0; y < size.height; y++) {
          final got = pixels.at(2, y + 0.5);
          final want = unwashed(day, y + 0.5, size.height);
          if (!near(got, want)) {
            moved.add('y=$y got ${hex(got)} want ${hex(want)}');
          }
        }
        expect(
          moved,
          isEmpty,
          reason:
              'A glow is emitted light and Day has none — the same reason the '
              'plate\'s strip light goes out on paper. '
              '${moved.length} row(s) moved:\n${moved.take(12).join('\n')}',
        );
      });
    }

    testWidgets('390x844 Night: the same column is warmer, and only below', (
      tester,
    ) async {
      await floor(tester, skin: night);
      final pixels = await torchPixels(tester);
      final table = StringBuffer(
        'NIGHT x=2, the bare column: the falloff against what was painted\n',
      );
      var firstMove = -1;
      for (var y = 0; y < 844; y += 1) {
        final got = pixels.at(2, y + 0.5);
        final want = unwashed(night, y + 0.5, 844);
        final moved = !near(got, want);
        if (moved && firstMove < 0) firstMove = y;
        if (y % 60 == 0 || y == 843) {
          table.writeln(
            '  y=${y.toString().padLeft(3)} ground ${hex(want)} '
            'painted ${hex(got)}${moved ? '  <- washed' : ''}',
          );
        }
      }
      table.writeln('  first washed row at x=2: y=$firstMove');
      // ignore: avoid_print
      print(table);

      // THE TOP OF THE SCREEN IS UNTOUCHED, which is what makes this the
      // plate's sky continued rather than a tint over the whole app. The clay
      // ellipse's tail leaves at 76% of a radius of 48% of the height, about a
      // centre 4% below the bottom edge: 67.5% of the screen, and at x=2 the
      // horizontal distance pushes it lower still.
      expect(
        firstMove,
        greaterThan(844 * 0.5),
        reason:
            'The wash reached the top half of the screen. It is a wash rising '
            'from the bottom edge, not a tint.',
      );
      for (final y in const <double>[0.5, 120.5, 300.5, 500.5]) {
        expect(
          near(pixels.at(2, y), unwashed(night, y, 844)),
          isTrue,
          reason: 'y=$y is above the wash and must be the bare falloff.',
        );
      }
      // And it IS there at the bottom.
      expect(
        near(pixels.at(2, 843.5), unwashed(night, 843.5, 844)),
        isFalse,
        reason:
            'The last row of the Night render is the ground untouched, which '
            'means nothing painted. Dawn is the point of this change.',
      );
    });
  });

  // ── 4. THE PAINT BUDGET ──────────────────────────────────────────────
  testWidgets('no blur, no mask, no filter, no shadow', (tester) async {
    await floor(tester, skin: night);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(ColorFiltered), findsNothing);
    for (final box in tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    )) {
      final decoration = box.decoration;
      if (decoration is! BoxDecoration) continue;
      expect(
        decoration.boxShadow ?? const <BoxShadow>[],
        isEmpty,
        reason: 'Night casts no drop shadows and a glow is never a shadow.',
      );
    }
  });

  // ── 5. THE RATIO THE WASH MOVES ──────────────────────────────────────
  //
  // The wash sits under the composer and the lower cards, so it changes the
  // ground their ink is measured against. Everything with an opaque material
  // of its own is unaffected by construction — the briefing cards are a
  // `surface` fill, the suggestion chips are a filled pill, the composer's
  // trough is a well — and the wash is strictly UNDER all of them. What is
  // left is the ink and the edges that sit on the bare ground, and there are
  // three of them.
  group('the wash moves one ratio, and here it is', () {
    Color unwashed(TiqSkin skin, double y, double height) {
      final band = height <= 400 ? 0.25 : 96 / height;
      final t = y / height;
      if (t <= band) {
        return Color.lerp(skin.palette.ground, skin.palette.vignette, t / band)!;
      }
      if (t >= 1 - band) {
        return Color.lerp(
          skin.palette.vignette,
          skin.palette.ground,
          (t - (1 - band)) / band,
        )!;
      }
      return skin.palette.vignette;
    }

    testWidgets('390x844 Night, at rest and answered', (tester) async {
      final rows = <List<String>>[];
      double worstText = double.infinity;
      double worstEdge = double.infinity;

      void row({
        required String what,
        required Color ink,
        required Color before,
        required Color after,
        required double floor,
      }) {
        final was = contrastRatio(ink, before);
        final now = contrastRatio(ink, after);
        rows.add(<String>[
          what,
          hex(ink),
          '${hex(before)} ${was.toStringAsFixed(2)}:1',
          '${hex(after)} ${now.toStringAsFixed(2)}:1',
          '${floor.toStringAsFixed(1)}:1',
          now >= floor ? 'pass' : 'FAIL',
        ]);
        if (floor >= 4.5) {
          worstText = math.min(worstText, now);
        } else {
          worstEdge = math.min(worstEdge, now);
        }
      }

      // ── at rest: the composer's standing label is the one text run on the
      //    bare ground anywhere near the wash.
      await floor(tester, skin: night);
      var pixels = await torchPixels(tester);
      final label = tester.getRect(find.text('Ask a question'));
      // The brightest row the glyphs occupy, at the horizontal centre of the
      // wash — the worst pixel, not an average, which is the rule the plate's
      // own contrast test already uses.
      row(
        what: 'composer label "Ask a question" (label 13/500)',
        ink: night.palette.ink2,
        before: unwashed(night, label.bottom - 0.5, 844),
        after: pixels.at(195, label.bottom - 0.5),
        floor: 4.5,
      );

      // The trough's own outline is a CONTROL edge and it sits on the ground.
      final trough = tester.getRect(
        find.byKey(const ValueKey<String>('ask-composer-field')),
      );
      row(
        what: 'composer trough outline, edgeControl, on the ground beside it',
        ink: night.palette.edgeControl,
        before: unwashed(night, trough.bottom - 0.5, 844),
        after: pixels.at(trough.left - 2, trough.bottom - 0.5),
        floor: 3.0,
      );

      // ── answered and dragged to the tail: the LOWEST a container edge can
      //    be put. The body is a scroll view and it clips to its own viewport,
      //    whose last row is the band's top edge — so this is the brightest
      //    ground any panel outline on this screen can ever land on.
      await asked(tester, skin: night);
      await scrollFloorToTail(tester);
      pixels = await torchPixels(tester);
      final band = tester.getRect(
        find.byKey(const ValueKey<String>('floor-band')),
      );
      row(
        what: 'a container edge scrolled to the viewport floor (y=${band.top - 1})',
        ink: night.palette.edgeStructure,
        before: unwashed(night, band.top - 0.5, 844),
        after: pixels.at(195, band.top - 0.5),
        floor: 3.0,
      );

      final table = StringBuffer('WHAT THE WASH MOVED, 390x844 Night\n')
        ..writeln(
          '| what | ink | before | after | floor | |',
        )
        ..writeln('|---|---|---|---|---|---|');
      for (final r in rows) {
        table.writeln('| ${r.join(' | ')} |');
      }
      // ignore: avoid_print
      print(table);

      expect(
        worstText,
        greaterThanOrEqualTo(4.5),
        reason:
            'Text on the washed ground fell under 4.5:1.\n$table\n'
            'Lightening the ground under ink is exactly the failure a glow '
            'passes by eye and fails by ratio. Do not tune the opacity until '
            'the test goes quiet — the number is the finding.',
      );
      expect(
        worstEdge,
        greaterThanOrEqualTo(3.0),
        reason:
            'A compliant edge on the washed ground fell under WCAG 1.4.11\'s '
            '3:1.\n$table',
      );
    });

    testWidgets('390x844 Night at 2.0x: the band grows and the wash recedes', (
      tester,
    ) async {
      await floor(tester, skin: night, textScale: 2.0);
      final pixels = await torchPixels(tester);
      final label = tester.getRect(find.text('Ask a question'));
      final ratio = contrastRatio(
        night.palette.ink2,
        pixels.at(195, label.bottom - 0.5),
      );
      // ignore: avoid_print
      print(
        'AT 2.0x: the composer label\'s bottom row is y=${label.bottom}, '
        'ground ${hex(pixels.at(195, label.bottom - 0.5))}, '
        'ink-2 at ${ratio.toStringAsFixed(2)}:1',
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    testWidgets('360x640 Night: the shorter phone, measured too', (
      tester,
    ) async {
      await floor(tester, skin: night, size: const Size(360, 640));
      final pixels = await torchPixels(tester);
      final label = tester.getRect(find.text('Ask a question'));
      final ratio = contrastRatio(
        night.palette.ink2,
        pixels.at(180, label.bottom - 0.5),
      );
      // ignore: avoid_print
      print(
        'AT 360x640: the composer label\'s bottom row is y=${label.bottom}, '
        'ground ${hex(pixels.at(180, label.bottom - 0.5))}, '
        'ink-2 at ${ratio.toStringAsFixed(2)}:1',
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });

  // ── 6. THE BAND'S SEAM SURVIVES IT ───────────────────────────────────
  //
  // `fix/band-seam` took a flat fill off this screen's band because the band
  // paints nothing and relies on the shell's ground showing through. A wash
  // added at the wrong layer breaks that in one of two ways: inside the
  // scroll view it stops at the viewport's floor and the band's top edge
  // becomes a step; over the content it covers the band's children. This is
  // the same assertion that PR made, re-run with the wash on.
  group('the band is still not an edge', () {
    bool near(Color a, Color b, {int tolerance = 2}) =>
        ((a.r - b.r).abs() * 255).round() <= tolerance &&
        ((a.g - b.g).abs() * 255).round() <= tolerance &&
        ((a.b - b.b).abs() * 255).round() <= tolerance;

    for (final (name, size) in const <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('$name Night: a row through the band is one colour', (
        tester,
      ) async {
        await floor(tester, skin: night, size: size);
        final pixels = await torchPixels(tester);
        final band = tester.getRect(
          find.byKey(const ValueKey<String>('floor-band')),
        );
        // 2dp inside the band's top edge, where the band itself draws nothing:
        // the row reads the backdrop and nothing else.
        final y = band.top + 2.5;
        final reference = pixels.at(size.width / 2, y);
        final steps = <String>[];
        for (final x in <double>[0.5, 19.5, 20.5, size.width - 20.5, size.width - 1.5]) {
          final got = pixels.at(x, y);
          if (!near(got, reference)) {
            steps.add('x=$x ${hex(got)} against ${hex(reference)}');
          }
        }
        // And across the top edge itself.
        for (final probe in <double>[band.top - 2.5, band.top - 0.5, band.top + 0.5]) {
          final got = pixels.at(2, probe);
          final want = pixels.at(2, y);
          if (!near(got, want, tolerance: 3)) {
            steps.add('y=$probe ${hex(got)} against ${hex(want)}');
          }
        }
        expect(
          steps,
          isEmpty,
          reason:
              'The band grew an edge. The wash must be in the shell\'s ground '
              'layer, which the band, the body and the bottom region all '
              'share — not in the scroll view, which clips at the band\'s '
              'top.\n${steps.join('\n')}',
        );
      });
    }
  });
}
