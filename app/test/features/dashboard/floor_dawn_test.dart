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
/// ratios it moves.
///
/// > *"Lets ship in C. Dawn — the plate's own sky"* — the owner.
///
/// `floor_dawn.dart` makes three claims and every one of them is a number, so
/// all three are measured here rather than argued:
///
/// 1. **It is not amber.** The census counts connected regions of emitted
///    light inside a flame-hue box at **value ≥ 0.90**. Clay is an *orange*
///    hue — Truffle sits at 15.7°, three degrees outside the box — so "it
///    should composite too dark to register" is a prediction, not a result.
///    This file runs the real census over **eleven phases in both skins**,
///    prints every count and every region, and separately censuses the wash
///    **on its own** so the headroom is a figure rather than a hope.
/// 2. **It is Night only.** Every pixel of a bare column of the Day render is
///    the shell's falloff exactly, which it could not be if anything washed
///    over it.
/// 3. **It costs two gradients.** Two decorations, no layer, and none of the
///    banned paint operations anywhere in the frame.
///
/// And the fourth thing, which the owner asked to be *told* about rather than
/// have tuned away: **what the wash does to the ink above it.** It lightens
/// the ground under the bottom third of the screen, and on Night that is
/// light ink on a dark ground — so lightening the ground lowers the ratio,
/// exactly as lightening it under dark ink would. See
/// `what the wash moved, measured` for the table and for the one number that
/// does not pass, which belongs to an object this screen does not paint.
///
/// The seam this change sits on top of is in `floor_band_seam_test.dart`: the
/// band paints no material and relies on the shell's ground showing through,
/// which is what put this wash in the ground layer rather than in the route's
/// body. The last group here is the positive half of that argument.
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

  bool near(Color a, Color b, {int tolerance = 2}) =>
      ((a.r - b.r).abs() * 255).round() <= tolerance &&
      ((a.g - b.g).abs() * 255).round() <= tolerance &&
      ((a.b - b.b).abs() * 255).round() <= tolerance;

  bool exactly(Color a, Color b) =>
      (a.r * 255).round() == (b.r * 255).round() &&
      (a.g * 255).round() == (b.g * 255).round() &&
      (a.b * 255).round() == (b.b * 255).round();

  /// `TorchShell`'s console ground, re-derived: `ground` at the two edges,
  /// `vignette` across the middle, over a 96dp ramp at each end.
  ///
  /// This is what the ground **would have been** without the wash, and it is
  /// the only way to state a "before" for a pixel the wash has already
  /// changed without rendering the screen twice. It is not taken on trust:
  /// every test that uses it below the wash first asserts it against the real
  /// frame at four y values the wash cannot reach.
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

  /// The first row at which the wash is visible on a bare column, measured.
  /// `height` when nothing washed at all, which is what Day returns.
  int firstWashedRow(TiqSkin skin, TorchPixels pixels) {
    for (var y = 0; y < pixels.height; y++) {
      if (!near(
        pixels.at(2, y + 0.5),
        unwashed(skin, y + 0.5, pixels.height.toDouble()),
      )) {
        return y;
      }
    }
    return pixels.height;
  }

  /// The brightest **flame-hued** pixel in a frame, by the census's own box:
  /// hue 20–48°, saturation ≥ 0.12. The value it reports is the one the
  /// census thresholds at 0.90.
  (double value, int x, int y) brightestFlameHued(TorchPixels pixels) {
    var best = 0.0;
    var bx = -1;
    var by = -1;
    for (var y = 0; y < pixels.height; y++) {
      for (var x = 0; x < pixels.width; x++) {
        final c = pixels.at(x + 0.5, y + 0.5);
        final r = (c.r * 255).round();
        final g = (c.g * 255).round();
        final b = (c.b * 255).round();
        if (!isFlameHued(r, g, b)) {
          // `isFlameHued` also applies the 0.90 value floor, so a pixel it
          // rejects may still be the brightest clay on the screen. Re-test the
          // hue and saturation alone, which is what this is measuring.
          final max = math.max(r, math.max(g, b));
          final min = math.min(r, math.min(g, b));
          if (max == 0) continue;
          if ((max - min) / max < 0.12) continue;
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
        }
        final value = math.max(r, math.max(g, b)) / 255.0;
        if (value > best) {
          best = value;
          bx = x;
          by = y;
        }
      }
    }
    return (best, bx, by);
  }

  /// Stand the screen up at rest, with a photograph on the plate.
  Future<void> floor(
    WidgetTester tester, {
    TiqSkin? skin,
    Size size = const Size(390, 844),
    bool photograph = true,
    bool online = true,
    bool measured = true,
    double textScale = 1.0,
    bool kpisPending = false,
    Object? kpisFailure,
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
      kpisPending: kpisPending,
      kpisFailure: kpisFailure,
    );
  }

  /// The same screen through the router harness, with a question typed and —
  /// unless [send] is false — sent. Typing needs an `Overlay`, which
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

  /// Every phase `_FloorFrame` can wear, by the name it gives its
  /// [TorchScope]. `loading` and `error` are the two that need a repository
  /// that never answers and one that refuses to — the fakes are at the foot
  /// of this file.
  const phases = <String>[
    'loading',
    'error',
    'at rest',
    'window-empty',
    'no-picture',
    'offline',
    'typing',
    'answering',
    'answered',
    'answered, scrolled',
    'keyboard up',
  ];

  Future<void> pumpPhase(
    WidgetTester tester,
    String phase, {
    required TiqSkin skin,
    Size size = const Size(390, 844),
  }) async {
    // A FRESH `ProviderScope` FOR EVERY PHASE. Riverpod asserts that a
    // scope's override COUNT never changes across a rebuild, and these
    // phases do not all stand the screen up the same way — `pumpFloor` and
    // `pumpFloorRoute` carry different override lists — so a second phase
    // pumped over the first trips "Tried to change the number of overrides"
    // instead of rendering. Tearing the tree down first is what makes a
    // single test able to walk every phase.
    await tester.pumpWidget(const SizedBox.shrink());
    switch (phase) {
      case 'loading':
        await floor(tester, skin: skin, size: size, kpisPending: true);
      case 'error':
        await floor(
          tester,
          skin: skin,
          size: size,
          kpisFailure: StateError('the console is down'),
        );
      case 'at rest':
        await floor(tester, skin: skin, size: size);
      case 'window-empty':
        await floor(tester, skin: skin, size: size, measured: false);
      case 'no-picture':
        await floor(tester, skin: skin, size: size, photograph: false);
      case 'offline':
        await floor(tester, skin: skin, size: size, online: false);
      case 'typing':
        await asked(tester, skin: skin, size: size, send: false);
      case 'answering':
        await asked(tester, skin: skin, size: size, settle: false);
      case 'answered':
        await asked(tester, skin: skin, size: size);
      case 'answered, scrolled':
        await asked(tester, skin: skin, size: size);
        await scrollFloorToTail(tester);
      case 'keyboard up':
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          size: size,
          skin: skin,
          keyboard: 320,
          plateImage: await SyncImage.solid(tester),
          current: kpis(osa: 61, execution: 73, priceCompliance: 74),
          previous: kpis(osa: 64, execution: 92),
          alerts: decisions,
          outlets: outlets,
        );
      default:
        fail('Unknown phase $phase.');
    }
  }

  // ── 1. WHAT THE WASH IS ──────────────────────────────────────────────
  group('the wash', () {
    test('Day asks for nothing at all', () {
      expect(
        floorDawnWash(day),
        isEmpty,
        reason:
            'A glow is emitted light and there is none on a page lit by the '
            'sun — the same reason the plate\'s strip light goes out on Day. '
            'The gate is `skin.amberIsInk`, the token the send block and the '
            'nav circle already read.',
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
            'no longer true.',
      );
      final hot = (wash.first as BoxDecoration).gradient! as RadialGradient;
      final clay = (wash.last as BoxDecoration).gradient! as RadialGradient;
      // The clay is LAST and therefore on top, which is the CSS order: a
      // background list paints back to front and the clay is listed first.
      expect(clay.colors.first.a, closeTo(0.30, 0.001));
      expect(clay.colors.last.a, 0);
      expect(clay.stops, const <double>[0, 0.44, 0.76]);
      expect(hot.colors.first.a, closeTo(0.09, 0.001));
      expect(hot.stops, const <double>[0, 0.70]);
      // The tokens, not two hexes. The style ledger is at zero and forbids a
      // raw `Color(0x…)` under lib/features/**; this is the assertion that
      // says the right token was reached for rather than a lookalike.
      expect(
        clay.colors.first.withValues(alpha: 1),
        night.palette.comparison,
        reason:
            'Truffle — the palette\'s comparison ink, 15.7 degrees off '
            'Burning Flame and nothing the amber law has a claim on.',
      );
      expect(
        hot.colors.first.withValues(alpha: 1),
        night.palette.flame900,
        reason: 'The white-hot core stop, at nine percent.',
      );
      for (final decoration in wash) {
        expect(
          (decoration as BoxDecoration).boxShadow ?? const <BoxShadow>[],
          isEmpty,
          reason: 'Glow is never a shadow, and Night casts none at all.',
        );
      }
    });
  });

  // ── 2. THE WASH ON ITS OWN IS NOT A LIGHT ────────────────────────────
  //
  // The headroom, with no content in the frame to confuse the reading: the
  // wash painted over a flat `ground`, which is the ground at exactly the
  // rows where the wash is strongest. If clay ever registers, it registers
  // here first and with nothing else to blame.
  group('the wash alone', () {
    Widget washOnly(TiqSkin skin) {
      Widget body = const SizedBox.expand();
      for (final decoration in floorDawnWash(skin).reversed) {
        body = DecoratedBox(decoration: decoration, child: body);
      }
      return body;
    }

    for (final (name, size) in const <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('$name: zero objects, and the brightest pixel printed', (
        tester,
      ) async {
        await pumpAmberRoute(
          tester,
          skin: night,
          size: size,
          child: washOnly(night),
        );
        final census = await amberCensus(tester);
        final pixels = await torchPixels(tester);
        final (value, bx, by) = brightestFlameHued(pixels);

        // The absolute brightest pixel in the frame, whatever its hue — which
        // for a frame containing only the wash IS the wash's brightest point.
        var peak = 0;
        var px = -1;
        var py = -1;
        for (var y = 0; y < pixels.height; y++) {
          for (var x = 0; x < pixels.width; x++) {
            final c = pixels.at(x + 0.5, y + 0.5);
            final v = math.max(
              (c.r * 255).round(),
              math.max((c.g * 255).round(), (c.b * 255).round()),
            );
            if (v > peak) {
              peak = v;
              px = x;
              py = y;
            }
          }
        }

        // THE HUE OF THE BRIGHTEST PIXEL, which is the stronger half of the
        // result and the sentence `floor_dawn.dart` quotes. The census boxes
        // the flame band at 20-48 degrees; clay composited over a navy-black
        // ground does not land inside it at ALL, at any value, so this is not
        // "a dark amber" — it is a different hue.
        final peakColour = pixels.at(px + 0.5, py + 0.5);
        final pr = (peakColour.r * 255).round();
        final pg = (peakColour.g * 255).round();
        final pb = (peakColour.b * 255).round();
        final hi = math.max(pr, math.max(pg, pb));
        final lo = math.min(pr, math.min(pg, pb));
        final delta = (hi - lo).toDouble();
        var peakHue = 0.0;
        if (delta != 0) {
          if (hi == pr) {
            peakHue = 60 * (((pg - pb) / delta) % 6);
          } else if (hi == pg) {
            peakHue = 60 * ((pb - pr) / delta + 2);
          } else {
            peakHue = 60 * ((pr - pg) / delta + 4);
          }
          if (peakHue < 0) peakHue += 360;
        }

        // ignore: avoid_print
        print(
          'THE WASH ALONE over `ground`, $name:\n'
          '  census: ${census.objectCount} object(s), ${census.litPixels} lit '
          'px (${(census.litFraction * 100).toStringAsFixed(3)}%)\n'
          '  brightest pixel anywhere: ${hex(peakColour)} at $px,$py — '
          'value ${(peak / 255).toStringAsFixed(3)}, '
          'saturation ${(delta / hi).toStringAsFixed(3)}, '
          'hue ${peakHue.toStringAsFixed(1)} deg\n'
          '  brightest pixel inside the flame hue box (20-48 deg, sat >= '
          '0.12): value ${value.toStringAsFixed(3)} at $bx,$by '
          '(${bx < 0 ? 'none at any value' : hex(pixels.at(bx + 0.5, by + 0.5))})\n'
          '  the census counts a flame-hued pixel at value >= 0.900',
        );

        expect(
          census.objectCount,
          0,
          reason: 'The wash registered as emitted light.\n${census.describe()}',
        );
        expect(
          bx,
          -1,
          reason:
              'The wash has a pixel inside the census\'s flame-hue box — at '
              'value ${value.toStringAsFixed(3)} against a floor of 0.900, so '
              'it does not count YET. It is two degrees of hue from counting, '
              'which is not a margin. The finding is the measurement, not a '
              'lower opacity.',
        );
        expect(
          peakHue,
          lessThan(20),
          reason:
              'The wash\'s brightest pixel is at hue '
              '${peakHue.toStringAsFixed(1)} degrees, inside or above the '
              'census\'s 20-48 band. Clay over navy composites BELOW the '
              'band, which is why this is not an amber rather than a dark '
              'one.',
        );
      });
    }
  });

  // ── 3. THE AMBER CENSUS, PER PHASE PER SKIN, PRINTED ─────────────────
  //
  // The composed frame, which is the one that ships. The counts are the pins
  // `the_floor_test.dart` already holds — Send is rung 1 and the plate's
  // strip light rung 2 — and the point of running them here is that NONE of
  // them may move.
  group('the amber census', () {
    const expected = <String, int>{
      'night/loading': 0,
      'night/error': 0,
      'night/at rest': 2,
      'night/window-empty': 2,
      'night/no-picture': 1,
      'night/offline': 1,
      'night/typing': 2,
      'night/answering': 2,
      'night/answered': 2,
      'night/answered, scrolled': 2,
      'night/keyboard up': 2,
      'day/loading': 0,
      'day/error': 0,
      'day/at rest': 1,
      'day/window-empty': 1,
      'day/no-picture': 1,
      'day/offline': 0,
      'day/typing': 1,
      'day/answering': 0,
      'day/answered': 0,
      'day/answered, scrolled': 0,
      'day/keyboard up': 1,
    };

    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      for (final phase in phases) {
        testWidgets('$skinName / $phase', (tester) async {
          await pumpPhase(tester, phase, skin: skin);

          final census = await amberCensus(tester);
          final pixels = await torchPixels(tester);
          final (value, bx, by) = brightestFlameHued(pixels);
          final washFrom = firstWashedRow(skin, pixels);

          // ignore: avoid_print
          print(
            'CENSUS $skinName / $phase: ${census.objectCount} object(s), '
            '${census.litPixels} lit px '
            '(${(census.litFraction * 100).toStringAsFixed(3)}%)\n'
            '  regions: '
            '${census.regions.isEmpty ? 'none' : census.regions.join('; ')}\n'
            '  brightest flame-hued pixel: value '
            '${value.toStringAsFixed(3)} at $bx,$by '
            '(${bx < 0 ? 'none' : hex(pixels.at(bx + 0.5, by + 0.5))})\n'
            '  the wash begins at y=$washFrom of 844 '
            '${washFrom >= pixels.height ? '(nothing washed)' : ''}',
          );

          expectWithinAmberBudget(
            census,
            skin,
            route: 'the-floor',
            phase: phase,
          );
          expect(
            census.objectCount,
            expected['$skinName/$phase'],
            reason:
                'The wash changed the count. Dawn is clay and clay is not a '
                'light; if this moved, something composited into the flame '
                'box.\n${census.describe()}',
          );
        });
      }
    }
  });

  // ── 4. DARK SKIN ONLY, PINNED ON THE RENDER ──────────────────────────
  group('Day has no wash', () {
    for (final (name, size) in const <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('$name: every bare pixel is the falloff, to the last row', (
        tester,
      ) async {
        await floor(tester, skin: day, size: size);
        final pixels = await torchPixels(tester);
        // x=2 is outside the 20dp gutter, so nothing is drawn on it at any y
        // in any phase: the whole column is the shell's ground and nothing
        // else.
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
              'A glow is emitted light and Day has none. '
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
      for (var y = 0; y <= 843; y += 60) {
        final got = pixels.at(2, y + 0.5);
        final want = unwashed(night, y + 0.5, 844);
        table.writeln(
          '  y=${y.toString().padLeft(3)} ground ${hex(want)} '
          'painted ${hex(got)}${near(got, want) ? '' : '  <- washed'}',
        );
      }
      final first = firstWashedRow(night, pixels);
      table.writeln('  first washed row at x=2: y=$first');
      // ignore: avoid_print
      print(table);

      // THE TOP OF THE SCREEN IS UNTOUCHED, which is what makes this the
      // plate's sky continued rather than a tint over the whole app. The clay
      // ellipse's tail leaves at 76% of a vertical radius of 48% of the
      // height, about a centre 4% below the bottom edge — 67.5% of the screen
      // at the horizontal centre, and lower still at x=2 where the ellipse's
      // own width has already taken most of it.
      expect(
        first,
        greaterThan(844 * 0.5),
        reason:
            'The wash reached the top half of the screen. It is a wash rising '
            'from the bottom edge, not a tint over the app.',
      );
      // The analytic falloff is checked against the real frame everywhere the
      // wash cannot reach, which is what licenses using it as the "before"
      // below the wash.
      for (final y in const <double>[0.5, 120.5, 300.5, 500.5]) {
        expect(
          near(pixels.at(2, y), unwashed(night, y, 844)),
          isTrue,
          reason: 'y=$y is above the wash and must be the bare falloff.',
        );
      }
      expect(
        near(pixels.at(2, 843.5), unwashed(night, 843.5, 844)),
        isFalse,
        reason:
            'The last row of the Night render is the ground untouched, which '
            'means nothing painted at all.',
      );
    });
  });

  // ── 5. THE PAINT BUDGET ──────────────────────────────────────────────
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

  // ── 6. WHAT THE WASH MOVED ───────────────────────────────────────────
  //
  // The wash sits under the composer and the lower cards, so it changes the
  // ground their ink is measured against. Everything with an opaque material
  // of its own is unaffected by construction, and the proof is in the pixel:
  // a sampled backdrop that reads a palette token EXACTLY is a backdrop with
  // nothing composited over it, so the wash is underneath it. What is left is
  // the ink that sits on the bare ground, and this finds every run of it
  // rather than taking a list on trust.
  group('what the wash moved, measured', () {
    /// The modal colour of the 2dp ring just outside [rect] — the backdrop a
    /// text run is printed on.
    ///
    /// Modal rather than a single probe because a ring crosses a sibling now
    /// and then (a mark, a figure, the next chip along) and one stray pixel
    /// would misclassify the run. The ring is outside the glyph box, so it
    /// never samples the ink itself.
    Color backdropAround(TorchPixels pixels, Rect rect) {
      final counts = <int, int>{};
      void take(double x, double y) {
        if (x < 0 || y < 0 || x >= pixels.width || y >= pixels.height) return;
        final c = pixels.at(x, y);
        final key =
            ((c.r * 255).round() << 16) |
            ((c.g * 255).round() << 8) |
            (c.b * 255).round();
        counts[key] = (counts[key] ?? 0) + 1;
      }

      for (var d = 1.0; d <= 2.0; d += 1.0) {
        for (var x = rect.left - d; x <= rect.right + d; x += 1) {
          take(x, rect.top - d);
          take(x, rect.bottom + d);
        }
        for (var y = rect.top - d; y <= rect.bottom + d; y += 1) {
          take(rect.left - d, y);
          take(rect.right + d, y);
        }
      }
      var best = 0;
      var bestCount = -1;
      for (final entry in counts.entries) {
        if (entry.value > bestCount) {
          bestCount = entry.value;
          best = entry.key;
        }
      }
      return Color.fromARGB(
        255,
        (best >> 16) & 0xFF,
        (best >> 8) & 0xFF,
        best & 0xFF,
      );
    }

    testWidgets('every text run on the washed ground, both phases', (
      tester,
    ) async {
      final table = StringBuffer(
        'EVERY TEXT RUN IN THE WASHED THIRD, 390x844 Night\n'
        '| phase | run | ink | backdrop | before | after | floor | |\n'
        '|---|---|---|---|---|---|---|---|\n',
      );
      // The tightest MARGIN — ratio minus the floor that run is held to —
      // because the table mixes 4.5:1 text with 3:1 icon glyphs and the
      // smallest number in a mixed column is not the closest call.
      var worst = double.infinity;
      var worstWhat = '';
      var onTheGround = 0;
      var onMaterial = 0;

      for (final phase in const <String>['at rest', 'answered, scrolled']) {
        await pumpPhase(tester, phase, skin: night);
        final pixels = await torchPixels(tester);
        final washFrom = firstWashedRow(night, pixels).toDouble();

        // The opaque materials this screen may print on. A sampled backdrop
        // that matches one EXACTLY has nothing composited over it.
        final materials = <String, Color>{
          'surface': night.palette.surface,
          'raised': night.palette.raised,
          'lifted': night.palette.lifted,
          'well': night.palette.well,
          'comparisonWash': night.palette.comparisonWash,
        };

        for (final element in find.byType(Text).evaluate()) {
          final widget = element.widget as Text;
          final ink = widget.style?.color;
          if (ink == null) continue;
          final text = widget.data;
          if (text == null || text.trim().isEmpty) continue;
          final Rect rect;
          try {
            rect = tester.getRect(find.byWidget(widget));
          } on StateError {
            continue;
          }
          if (rect.isEmpty || rect.bottom <= washFrom) continue;

          final backdrop = backdropAround(pixels, rect);
          final material = materials.entries
              .where((e) => exactly(backdrop, e.value))
              .map((e) => e.key)
              .firstOrNull;

          final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
          // AN ICON IS NOT A WORD. A `Text` whose one rune is in the Unicode
          // private-use area is a glyph out of the Material icon font — the
          // composer's Send arrow, the briefing's chevron — and WCAG puts a
          // graphical object at 1.4.11's 3:1 rather than 1.4.3's 4.5:1. It is
          // still measured, and still printed: the floor is what differs.
          final glyph =
              flat.runes.length == 1 &&
              flat.runes.first >= 0xE000 &&
              flat.runes.first <= 0xF8FF;
          final floor = glyph ? 3.0 : 4.5;
          final label = glyph
              ? 'an icon glyph, U+'
                    '${flat.runes.first.toRadixString(16).toUpperCase()}'
              : (flat.length <= 26 ? flat : '${flat.substring(0, 24)}…');
          if (material != null) {
            onMaterial++;
            final ratio = contrastRatio(ink, backdrop);
            table.writeln(
              '| $phase | $label | ${hex(ink)} | $material ${hex(backdrop)} | '
              '${ratio.toStringAsFixed(2)}:1 | same — the wash is under an '
              'opaque fill | ${floor.toStringAsFixed(1)}:1 | unmoved |',
            );
            expect(
              ratio,
              greaterThanOrEqualTo(floor),
              reason:
                  '"$label" on $material is ${ratio.toStringAsFixed(2)}:1, '
                  'which is a pre-existing reading and not this change.',
            );
            continue;
          }

          // Not a material, so it is the ground — and the ground under the
          // wash. The "before" is the falloff, validated above.
          onTheGround++;
          final before = unwashed(night, rect.center.dy, 844);
          final was = contrastRatio(ink, before);
          final now = contrastRatio(ink, backdrop);
          if (now - floor < worst) {
            worst = now - floor;
            worstWhat =
                '$phase / "$label" at ${now.toStringAsFixed(2)}:1 against '
                '${floor.toStringAsFixed(1)}:1';
          }
          table.writeln(
            '| $phase | $label | ${hex(ink)} | ground ${hex(backdrop)} | '
            '${was.toStringAsFixed(2)}:1 | ${now.toStringAsFixed(2)}:1 | '
            '${floor.toStringAsFixed(1)}:1 | '
            '${now >= floor ? 'pass' : 'FAIL'} |',
          );
        }
      }

      table.writeln(
        '\n$onTheGround run(s) on the bare washed ground, $onMaterial on an '
        'opaque material. Tightest margin on the ground: '
        '${worst.isFinite ? '+${worst.toStringAsFixed(2)} — $worstWhat' : 'none'}',
      );
      // ignore: avoid_print
      print(table);

      expect(
        onTheGround,
        greaterThan(0),
        reason:
            'No text run was classified as sitting on the washed ground, so '
            'this test proved nothing. The composer\'s standing label is on '
            'it; if the classifier stopped finding it, fix the classifier.',
      );
      expect(
        worst,
        greaterThanOrEqualTo(0),
        reason:
            'Ink on the washed ground fell under its floor.\n$table\n'
            'Lightening the ground under ink is exactly the failure a glow '
            'passes by eye and fails by ratio. The number is the finding — do '
            'not tune the opacity until the test goes quiet.',
      );
    });

    testWidgets('the composer trough is a control edge on the ground', (
      tester,
    ) async {
      await floor(tester, skin: night);
      final pixels = await torchPixels(tester);
      final trough = tester.getRect(
        find.byKey(const ValueKey<String>('ask-composer-field')),
      );
      // Just outside the trough's left edge, on its bottom row: the ground
      // the control's own outline is read against, at the warmest y the
      // composer occupies.
      final ground = pixels.at(trough.left - 3, trough.bottom - 0.5);
      final before = contrastRatio(
        night.palette.edgeControl,
        unwashed(night, trough.bottom - 0.5, 844),
      );
      final after = contrastRatio(night.palette.edgeControl, ground);
      // ignore: avoid_print
      print(
        'THE TROUGH\'S OUTLINE, 390x844 Night: edgeControl '
        '${hex(night.palette.edgeControl)} on the ground beside it at '
        'y=${trough.bottom - 0.5} — ${hex(ground)}: '
        '${before.toStringAsFixed(2)}:1 before, '
        '${after.toStringAsFixed(2)}:1 after, floor 3.0:1',
      );
      expect(
        after,
        greaterThanOrEqualTo(3.0),
        reason:
            'The composer\'s own outline fell under WCAG 1.4.11\'s 3:1 '
            'against the washed ground.',
      );
    });

    // ── THE ONE NUMBER THAT DOES NOT PASS, AND THE OBJECT IT BELONGS TO ──
    //
    // `edgeStructure` is THE compliant container edge — panel outlines, sheet
    // edges — and it is declared at 3.79:1 on the Night ground. Against the
    // washed ground at the lowest row a scrolling panel outline could reach
    // (y=761 in the answered state, the scroll view's own viewport floor) it
    // measures **2.51:1**, which is under 1.4.11's 3:1.
    //
    // THERE IS NO SUCH EDGE ON THIS SCREEN, and that is not luck — it is the
    // card override of 25 September 2026. The briefing lines, the question
    // bubble and the answer's instrument panel are all `TorchCard`: radius 22,
    // `surface` fill, **no outline, in any skin**. The only `edgeStructure` on
    // The Floor is the skeleton's block FILL and the instrument panel's
    // internal rules, and the rules are inside a `surface` card where the wash
    // cannot reach them.
    //
    // So this is a guard rather than a failure: it pins the absence, with the
    // number, for whoever puts a panel outline on the bottom third of this
    // screen next. If that happens, the answer is not a lower opacity — it is
    // that the object wants the card grammar this screen already uses.
    testWidgets('no container edge is painted on the washed ground', (
      tester,
    ) async {
      final hypothetical = <String>[];
      for (final phase in phases) {
        await pumpPhase(tester, phase, skin: night);
        final pixels = await torchPixels(tester);
        final washFrom = firstWashedRow(night, pixels);
        final edge = night.palette.edgeStructure;
        final found = <String>[];
        for (var y = washFrom; y < pixels.height; y++) {
          for (var x = 0; x < pixels.width; x++) {
            if (exactly(pixels.at(x + 0.5, y + 0.5), edge)) {
              found.add('$x,$y');
              break;
            }
          }
          if (found.length > 3) break;
        }
        if (found.isNotEmpty) {
          final y = int.parse(found.first.split(',')[1]);
          final ground = pixels.at(pixels.width / 2, y + 4.5);
          hypothetical.add(
            '$phase: edgeStructure at ${found.join(' ')} (washed from '
            'y=$washFrom); the ground 4dp below reads ${hex(ground)} at '
            '${contrastRatio(edge, ground).toStringAsFixed(2)}:1',
          );
        }
      }

      // And the number itself, printed whether or not anything was found, so
      // the reviewer sees what the guard is guarding.
      await pumpPhase(tester, 'answered, scrolled', skin: night);
      final pixels = await torchPixels(tester);
      final band = tester.getRect(
        find.byKey(const ValueKey<String>('floor-band')),
      );
      final floorRow = pixels.at(pixels.width / 2, band.top - 0.5);
      // ignore: avoid_print
      print(
        'THE HYPOTHETICAL CONTAINER EDGE, 390x844 Night: the scroll view\'s '
        'viewport floor in the answered state is y=${band.top - 1}, where the '
        'washed ground reads ${hex(floorRow)}. An `edgeStructure` outline '
        'there would measure '
        '${contrastRatio(night.palette.edgeStructure, floorRow).toStringAsFixed(2)}'
        ':1 against WCAG 1.4.11\'s 3:1 — it is '
        '${contrastRatio(night.palette.edgeStructure, unwashed(night, band.top - 0.5, 844)).toStringAsFixed(2)}'
        ':1 on the bare ground. The Floor paints no such edge: every '
        'container on it is a `TorchCard`, which has no outline in any skin.',
      );

      expect(
        hypothetical,
        isEmpty,
        reason:
            'A container edge landed on the washed ground. `edgeStructure` '
            'measures about 2.5:1 there against WCAG 1.4.11\'s 3:1, where it '
            'is 3.64:1 on the bare ground. The fix is NOT a lower opacity: it '
            'is that the object wants the card grammar this screen already '
            'uses — radius 22, `surface`, no outline.\n'
            '${hypothetical.join('\n')}',
      );
    });

    testWidgets('390x844 Night at 2.0x, and the 360x640 phone', (tester) async {
      for (final (name, size, scale) in const <(String, Size, double)>[
        ('390x844 @ 2.0x', Size(390, 844), 2.0),
        ('390x844 @ 1.3x', Size(390, 844), 1.3),
        ('360x640 @ 1.0x', Size(360, 640), 1.0),
        ('360x640 @ 1.3x', Size(360, 640), 1.3),
      ]) {
        await floor(tester, skin: night, size: size, textScale: scale);
        final pixels = await torchPixels(tester);
        final label = tester.getRect(find.text('Ask a question'));
        final ground = pixels.at(size.width / 2, label.bottom - 0.5);
        final ratio = contrastRatio(night.palette.ink2, ground);
        // ignore: avoid_print
        print(
          'THE COMPOSER LABEL at $name: bottom row y=${label.bottom}, '
          'ground ${hex(ground)}, ink-2 at ${ratio.toStringAsFixed(2)}:1 '
          '(floor 4.5:1)',
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'The composer\'s standing label at $name.',
        );
      }
    });
  });

  // ── 7. THE WASH REACHES THE BAND, WHICH IS THE LAYER ARGUMENT ────────
  //
  // `fix/band-seam` took a flat fill off this screen's band because the band
  // paints nothing and relies on the shell's ground showing through. That is
  // what forced this wash into the shell's ground layer rather than into the
  // route's body: the body is a scroll view and it CLIPS to its own viewport,
  // whose last row is the band's top edge, so a wash added there would stop
  // dead at the exact y the owner had just had a box removed from.
  //
  // This is the positive half of that argument — the wash is present inside
  // the band's own box, continuous with the body above it. The negative half
  // (that there is no step at the boundary, measured with an instrument that
  // survives the gradient's dither) is `floor_band_seam_test.dart`, which also
  // carries the proof that it still fails on the re-introduced fill.
  group('the wash reaches the band', () {
    for (final (name, size) in const <(String, Size)>[
      ('390x844', Size(390, 844)),
      ('360x640', Size(360, 640)),
    ]) {
      testWidgets('$name Night: the band\'s own rows are washed', (
        tester,
      ) async {
        await floor(tester, skin: night, size: size);
        final pixels = await torchPixels(tester);
        final band = tester.getRect(
          find.byKey(const ValueKey<String>('floor-band')),
        );
        final washFrom = firstWashedRow(night, pixels);
        // 2dp inside the band's top edge, where the band itself draws nothing.
        final y = band.top + 2.5;
        final inside = pixels.at(size.width / 2, y);
        final bare = unwashed(night, y, size.height);
        // ignore: avoid_print
        print(
          'THE BAND AT $name: its box is $band, the wash begins at '
          'y=$washFrom, and the row 2dp inside its top edge reads '
          '${hex(inside)} at the centre against a bare ground of '
          '${hex(bare)} — ${hex(pixels.at(0.5, y))} at x=0 and '
          '${hex(pixels.at(size.width - 0.5, y))} at x=${size.width - 1}.',
        );
        expect(
          washFrom,
          lessThan(band.top),
          reason:
              'The wash starts BELOW the band\'s top edge, which means it is '
              'inside the scroll view and clipped to the viewport. It belongs '
              'in the shell\'s ground, the one layer the body, the band and '
              'the bottom region share.',
        );
        expect(
          near(inside, bare),
          isFalse,
          reason:
              'The band\'s own rows are the bare falloff, so the wash is '
              'hidden by the band or stops above it.',
        );
      });
    }
  });
}
