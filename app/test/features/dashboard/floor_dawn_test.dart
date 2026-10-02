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
/// > *"Please also add that background shade on the white theme as well"* —
/// > the owner, 2 October 2026.
///
/// `floor_dawn.dart` makes four claims and every one of them is a number, so
/// all four are measured here rather than argued:
///
/// 1. **It is not amber, in either skin.** The census counts connected regions
///    of emitted light inside a flame-hue box at **value ≥ 0.90**. Clay is an
///    *orange* hue — Truffle sits at 15.7° on Night and 13.6° on Day, outside
///    the box both times — so "it should composite too dark to register" is a
///    prediction, not a result. This file runs the real census over **eleven
///    phases in both skins**, prints every count and every region, and
///    separately censuses the wash **on its own** so the headroom is a figure
///    rather than a hope.
/// 2. **On Day the headroom is an interval, and it is thin.** Palladian is
///    itself hue 40.0° at value 0.933 — inside the census box on two of its
///    three axes, out of it on saturation alone — so a warm wash on paper has
///    exactly one escape and it is the value floor. The wash must get the red
///    channel under 229.5 *before* its own chroma lifts saturation to 0.12,
///    which it does by **0.0223 of alpha** over the binding base. `the
///    forbidden alpha interval is empty` is that claim, exhaustively, over
///    every colour the Day falloff produces. It is also why Day drops the 9%
///    `flame900` under-layer: the companion test shows that layer opening the
///    interval from alpha **0.0378** up.
/// 3. **A glow on Night and a shade on Day.** One token and one ellipse:
///    Truffle is lighter than a navy-black ground and darker than Palladian,
///    so the same decoration lifts one skin's bottom third and deepens the
///    other's. `a glow on Night, a shade on Day` pins the direction rather
///    than only the presence.
/// 4. **It costs two gradients on Night and one on Day.** No layer, and none
///    of the banned paint operations anywhere in the frame.
///
/// And the fifth thing, which the owner asked to be *told* about rather than
/// have tuned away: **what the wash does to the ink above it.** It moves the
/// ground the wrong way in both skins — it lightens a dark ground under light
/// ink and darkens a light ground under dark ink — so both skins lose ratio.
/// See `what the wash moved, measured` for the table, measured at **the worst
/// point of the gradient under each specific run**, and for the numbers that
/// do not pass, which belong to objects this screen does not paint.
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
    test('Day asks for one decoration, and it has no hot breath', () {
      final wash = floorDawnWash(day);
      expect(
        wash,
        hasLength(1),
        reason:
            'Day is the clay alone. The 9 percent flame900 under-layer is '
            'worth +0.8 of a red level on Palladian and it is what puts the '
            'wash inside the census box from alpha 0.0378 up — see `the '
            'census box has no room on paper` below for the interval.',
      );
      final clay = (wash.single as BoxDecoration).gradient! as RadialGradient;
      expect(clay.colors.first.a, closeTo(0.22, 0.001));
      expect(clay.colors[1].a, closeTo(0.06, 0.001));
      expect(clay.colors.last.a, 0);
      expect(clay.stops, const <double>[0, 0.44, 0.76]);
      expect(
        clay.colors.first.withValues(alpha: 1),
        day.palette.comparison,
        reason:
            'Truffle on paper — #A35139, which is DARKER than Palladian, '
            'which is what turns the glow into a shade with no second code '
            'path for the colour.',
      );
      // THE HOT BREATH IS GONE, not reduced. Asserted on the token rather
      // than on the count, because a second decoration carrying some other
      // colour would pass a length check and fail the argument.
      for (final decoration in wash) {
        final gradient =
            (decoration as BoxDecoration).gradient! as RadialGradient;
        for (final colour in gradient.colors) {
          expect(
            colour.withValues(alpha: 1),
            isNot(day.palette.flame900),
            reason:
                'Day paints no flame token at all. Night\'s 0.09 opens a '
                'forbidden alpha band of [0.1125, 0.1311] that this '
                'gradient would cross.',
          );
        }
        expect(
          decoration.boxShadow ?? const <BoxShadow>[],
          isEmpty,
          reason: 'A glow is never a shadow, and a shade is not one either.',
        );
      }
      expect(
        floorDawnWash(TiqSkin.day(density: TiqDensity.field)),
        hasLength(1),
        reason: 'The gate is the skin, not the density.',
      );
    });

    test('a skin that refuses gradients gets no wash at all', () {
      // THE FLAT FALLBACK FOR A WASH IS NO WASH. A bottom-rising falloff has
      // no single-colour form and the shell's ground is already the right
      // picture without it.
      const flat = TiqDepth(
        shadows: <BoxShadow>[],
        litRim: Color(0x00000000),
        allowsGradients: false,
        borderWidth: 1,
      );
      expect(floorDawnWash(day.copyWith(depth: flat)), isEmpty);
      expect(floorDawnWash(night.copyWith(depth: flat)), isEmpty);
      // …and the guard changes no shipped pixel, which is the other half of
      // the claim and the half that rots silently.
      expect(day.depth.allowsGradients, isTrue);
      expect(night.depth.allowsGradients, isTrue);
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

    for (final (skinName, skin, name, size)
        in <(String, TiqSkin, String, Size)>[
          ('night', night, '390x844', const Size(390, 844)),
          ('night', night, '360x640', const Size(360, 640)),
          ('day', day, '390x844', const Size(390, 844)),
          ('day', day, '360x640', const Size(360, 640)),
        ]) {
      testWidgets('$skinName $name: zero objects, and the extreme pixel printed', (
        tester,
      ) async {
        await pumpAmberRoute(
          tester,
          skin: skin,
          size: size,
          child: washOnly(skin),
        );
        final census = await amberCensus(tester);
        final pixels = await torchPixels(tester);
        final (value, bx, by) = brightestFlameHued(pixels);

        // THE MOST EXTREME PIXEL IN THE FRAME, which is not the same thing in
        // the two skins. Night's wash lifts a navy-black ground, so its
        // extreme is the BRIGHTEST pixel; Day's deepens Palladian, so its
        // extreme is the DARKEST one. Both are "the wash at full strength",
        // and asking for the brightest on Day would report an unwashed corner.
        final bool lifts = !skin.amberIsInk;
        var peak = lifts ? 0 : 256;
        var px = -1;
        var py = -1;
        for (var y = 0; y < pixels.height; y++) {
          for (var x = 0; x < pixels.width; x++) {
            final c = pixels.at(x + 0.5, y + 0.5);
            final v = math.max(
              (c.r * 255).round(),
              math.max((c.g * 255).round(), (c.b * 255).round()),
            );
            if (lifts ? v > peak : v < peak) {
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
          'THE WASH ALONE over `ground`, $skinName $name:\n'
          '  census: ${census.objectCount} object(s), ${census.litPixels} lit '
          'px (${(census.litFraction * 100).toStringAsFixed(3)}%)\n'
          '  most extreme pixel (${lifts ? 'brightest' : 'darkest'}): '
          '${hex(peakColour)} at $px,$py — '
          'value ${(peak / 255).toStringAsFixed(3)}, '
          'saturation ${(delta / hi).toStringAsFixed(3)}, '
          'hue ${peakHue.toStringAsFixed(1)} deg\n'
          '    census box: hue 20-48 deg, saturation >= 0.12, value >= 0.900\n'
          '  brightest pixel inside the flame hue box (20-48 deg, sat >= '
          '0.12): value ${value.toStringAsFixed(3)} at $bx,$by '
          '(${bx < 0 ? 'none at any value' : hex(pixels.at(bx + 0.5, by + 0.5))})',
        );

        expect(
          census.objectCount,
          0,
          reason: 'The wash registered as emitted light.\n${census.describe()}',
        );
        if (lifts) {
          expect(
            bx,
            -1,
            reason:
                'The wash has a pixel inside the census\'s flame-hue box — at '
                'value ${value.toStringAsFixed(3)} against a floor of 0.900, '
                'so it does not count YET. It is two degrees of hue from '
                'counting, which is not a margin. The finding is the '
                'measurement, not a lower opacity.',
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
        } else {
          // ON PAPER THERE IS NO HUE RESCUE AND NO VALUE HEADROOM. The Day
          // ground is itself hue 40.0 deg at value 0.933 — inside the box on
          // two of its three axes — and only its saturation of 0.063 keeps the
          // whole screen out of the census. So the Day wash is FULL of
          // flame-hued pixels (`bx` is not -1 and will not be), and the one
          // thing standing between it and a second counted object is the value
          // floor. That is what this measures, and the margin is thin: the
          // brightest flame-hued pixel of the shipped wash sits at max channel
          // 229 against a floor of 229.5 — ONE eight-bit level.
          //
          // The level is not the whole story and the interval test below is
          // the better guard: to count, a pixel needs max >= 230 (clay alpha
          // <= 0.1067) and saturation >= 0.12 (clay alpha >= 0.1356) at the
          // same time, which is 0.029 of alpha apart. The one-level figure is
          // reported because it is what a palette move would eat first.
          expect(
            value,
            lessThan(0.90),
            reason:
                'The Day wash has a flame-hued pixel at value '
                '${value.toStringAsFixed(3)}, at or over the census\'s 0.900 '
                'floor: it is now a counted amber region on a skin whose '
                'budget is ONE object, and the send disc owns it. On paper the '
                'value floor is the only escape there is — the answer is a '
                'lower alpha, never a wider box.',
          );
          expect(
            peak / 255,
            lessThan(0.90),
            reason:
                'The Day wash\'s darkest pixel is at value '
                '${(peak / 255).toStringAsFixed(3)}, so the wash is not a '
                'shade at all and the escape it relies on is gone.',
          );
        }
      });
    }

    // ── THE CENSUS BOX HAS NO ROOM ON PAPER, AND THE ARITHMETIC THAT SAYS
    //    SO ──────────────────────────────────────────────────────────────
    //
    // The pixel census above measures the wash that SHIPS. This measures the
    // wash that could have shipped: every alpha the gradient passes through,
    // over every colour the Day falloff produces, which is the claim
    // `floor_dawn.dart` makes and the only form in which it can be held.
    //
    // A gradient is continuous. "The peak is safe" is not an argument, because
    // the ramp visits every alpha between zero and the peak and the Day danger
    // zone is in the MIDDLE of that ramp — value is still over 0.900 near the
    // tail and saturation is already over 0.120 near the head. So the claim is
    // that an interval is EMPTY, and the test is the interval.
    test('the forbidden alpha interval is empty, over the whole Day falloff', () {
      final clay = day.palette.comparison;
      // Every distinct colour `TorchShell`'s Day falloff can produce: the
      // ground, the vignette, and the integer lerps between them.
      final bases = <int, Color>{};
      for (var i = 0; i <= 1000; i++) {
        final c = Color.lerp(
          day.palette.ground,
          day.palette.vignette,
          i / 1000,
        )!;
        bases[((c.r * 255).round() << 16) |
                ((c.g * 255).round() << 8) |
                (c.b * 255).round()] =
            c;
      }

      final inside = <String>[];
      var closest = double.infinity;
      var closestAt = '';
      for (final base in bases.values) {
        for (var i = 0; i <= 4096; i++) {
          final a = i / 4096;
          final c = Color.lerp(base, clay, a)!;
          final r = (c.r * 255).round();
          final g = (c.g * 255).round();
          final b = (c.b * 255).round();
          final hi = math.max(r, math.max(g, b));
          final lo = math.min(r, math.min(g, b));
          if (hi == 0) continue;
          final sat = (hi - lo) / hi;
          final val = hi / 255;
          final delta = (hi - lo).toDouble();
          if (delta == 0) continue;
          double hue;
          if (hi == r) {
            hue = 60 * (((g - b) / delta) % 6);
          } else if (hi == g) {
            hue = 60 * ((b - r) / delta + 2);
          } else {
            hue = 60 * ((r - g) / delta + 4);
          }
          if (hue < 0) hue += 360;
          if (hue < 20 || hue > 48) continue;
          if (sat >= 0.12 && val >= 0.90) {
            inside.add(
              'base ${hex(base)} alpha ${a.toStringAsFixed(4)} -> ${hex(c)} '
              'hue ${hue.toStringAsFixed(1)} sat ${sat.toStringAsFixed(3)} '
              'value ${val.toStringAsFixed(3)}',
            );
          }
          // How far this alpha misses the box on whichever axis saves it.
          final miss = math.max(0.12 - sat, 0.90 - val);
          if (miss < closest) {
            closest = miss;
            closestAt =
                'base ${hex(base)} alpha ${a.toStringAsFixed(4)} -> ${hex(c)} '
                'hue ${hue.toStringAsFixed(2)} sat ${sat.toStringAsFixed(4)} '
                'value ${val.toStringAsFixed(4)}';
          }
        }
      }

      // The two bounds, derived rather than scanned, so the printed artefact
      // says WHY it is empty and not merely that it is.
      String bounds(Color base, String name) {
        final br = (base.r * 255);
        final bb = (base.b * 255);
        final dr = (clay.r * 255) - br;
        final db = (clay.b * 255) - bb;
        // value >= 0.90  <=>  br + a*dr >= 229.5
        final aValue = (229.5 - br) / dr;
        // sat >= 0.12  <=>  0.88*(br + a*dr) - (bb + a*db) >= 0
        final aSat = -(0.88 * br - bb) / (0.88 * dr - db);
        return '  over the $name ${hex(base)}: value >= 0.900 only while '
            'alpha <= ${aValue.toStringAsFixed(4)}; saturation >= 0.120 only '
            'once alpha >= ${aSat.toStringAsFixed(4)} — the box needs both, so '
            'the interval is empty by ${(aSat - aValue).toStringAsFixed(4)} of '
            'alpha.';
      }

      // ignore: avoid_print
      print(
        'THE DAY CENSUS INTERVAL, Truffle #A35139 over the Day falloff:\n'
        '  ${bases.length} distinct base colours x 4097 alpha steps\n'
        '${bounds(day.palette.ground, 'ground')}\n'
        '${bounds(day.palette.vignette, 'vignette')}\n'
        '  pixels inside the census box: ${inside.length}\n'
        '  closest approach: $closestAt\n'
        '    -> clears on its saving axis by ${closest.toStringAsFixed(4)}\n'
        '  the Day ground itself is hue 40.0 deg, saturation 0.063, value '
        '0.933 — inside the box on hue and on value, and out of it on '
        'saturation alone.',
      );

      expect(
        inside,
        isEmpty,
        reason:
            'A clay alpha the Day gradient passes through composites INSIDE '
            'the census box. The wash would be a second counted amber region '
            'on a skin whose budget is one, and the send disc owns it.\n'
            '${inside.take(8).join('\n')}',
      );
    });

    // AND THE REASON THE HOT BREATH DID NOT COME TO DAY, held as a test
    // rather than as a sentence. If this ever stops failing, the 9 percent
    // under-layer may return and `floor_dawn.dart`'s Day paragraph is wrong.
    test(
      'Night\'s 9% flame900 under-layer WOULD open that interval on Day',
      () {
        final clay = day.palette.comparison;
        final hot = day.palette.flame900;
        double? firstHot;
        var insideAt009 = 0;
        for (var i = 0; i <= 512; i++) {
          final h = 0.09 * i / 512;
          var hit = false;
          for (var j = 0; j <= 512; j++) {
            final cAlpha = 0.30 * j / 512;
            for (final base in <Color>[
              day.palette.ground,
              day.palette.vignette,
            ]) {
              final c = Color.lerp(Color.lerp(base, hot, h)!, clay, cAlpha)!;
              if (isFlameHued(
                (c.r * 255).round(),
                (c.g * 255).round(),
                (c.b * 255).round(),
              )) {
                hit = true;
                if ((h - 0.09).abs() < 0.09 / 512) insideAt009++;
              }
            }
          }
          if (hit) firstHot ??= h;
        }
        // ignore: avoid_print
        print(
          'THE HOT BREATH ON PAPER: the first flame900 alpha at which any '
          'rendered composite lands inside the census box is '
          '${firstHot?.toStringAsFixed(4) ?? 'none up to 0.0900'}. At Night\'s '
          'own 0.09 there are $insideAt009 (base, clay-alpha) pairs inside it. '
          'Analytically the forbidden clay interval opens at flame900 0.0492 '
          'and is [0.1125, 0.1311] wide at 0.09 — a band the gradient crosses. '
          'Day therefore ships ONE decoration, not two.',
        );
        expect(
          firstHot,
          isNotNull,
          reason:
              'The 9 percent under-layer no longer breaks the Day census, so '
              'the reason floor_dawn.dart gives for dropping it is stale. '
              'Either the palette moved or the census box did — find out which '
              'before putting the hot breath back.',
        );
        expect(
          firstHot,
          lessThan(0.09),
          reason: 'It breaks only at or above Night\'s own alpha.',
        );
      },
    );
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

  // ── 4. A GLOW ON NIGHT AND A SHADE ON DAY, PINNED ON THE RENDER ──────
  //
  // One token, one ellipse, and the direction inverts. Truffle is `#E08E71` on
  // Night and `#A35139` on Day; the first is far lighter than a navy-black
  // ground and the second is darker than Palladian, so the same decoration
  // lifts one skin's bottom third and deepens the other's. That is the whole
  // design of the Day half and it is the thing to pin, because "the wash is
  // present" and "the wash goes the right way" are different claims and only
  // the second one is interesting.
  group('a glow on Night, a shade on Day', () {
    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      for (final (name, size) in const <(String, Size)>[
        ('390x844', Size(390, 844)),
        ('360x640', Size(360, 640)),
      ]) {
        testWidgets('$skinName $name: the bare column, and which way it went', (
          tester,
        ) async {
          await floor(tester, skin: skin, size: size);
          final pixels = await torchPixels(tester);
          // x=2 is outside the 20dp gutter, so nothing is drawn on it at any y
          // in any phase: the whole column is the shell's ground and the wash.
          final table = StringBuffer(
            '$skinName x=2 at $name, the bare column: the falloff against what '
            'was painted\n',
          );
          final step = (size.height / 14).floor();
          for (var y = 0; y < size.height; y += step) {
            final got = pixels.at(2, y + 0.5);
            final want = unwashed(skin, y + 0.5, size.height);
            table.writeln(
              '  y=${y.toString().padLeft(3)} ground ${hex(want)} '
              'painted ${hex(got)}${near(got, want) ? '' : '  <- washed'}',
            );
          }
          final first = firstWashedRow(skin, pixels);
          table.writeln(
            '  first washed row at x=2: y=$first of ${size.height}',
          );

          // WHICH WAY. The last row of the BARE COLUMN — x=2, where nothing is
          // ever drawn — against the falloff it would have been. Not the
          // screen's centre: at the bottom centre the composer's own trough
          // outline is on top of the ground and the reading would be
          // `edgeControl`, which happens to lie on the right side of the
          // ground in both skins and would make this pass for the wrong
          // reason.
          final lastWashed = pixels.at(2, size.height - 0.5);
          final lastBare = unwashed(skin, size.height - 0.5, size.height);
          final lifted = contrastRatio(lastWashed, lastBare);
          table.writeln(
            '  the bottom row at x=2: bare ${hex(lastBare)} -> painted '
            '${hex(lastWashed)}, a ${lifted.toStringAsFixed(3)}:1 step, '
            '${skin.amberIsInk ? 'DARKER (a shade)' : 'LIGHTER (a glow)'}',
          );
          // ignore: avoid_print
          print(table);

          // THE TOP OF THE SCREEN IS UNTOUCHED, which is what makes this the
          // plate's sky continued rather than a tint over the whole app. The
          // clay ellipse's tail leaves at 76% of a vertical radius of 48% of
          // the height, about a centre 4% below the bottom edge — 67.5% of the
          // screen at the horizontal centre, and lower still at x=2 where the
          // ellipse's own width has already taken most of it.
          expect(
            first,
            greaterThan(size.height * 0.5),
            reason:
                'The wash reached the top half of the screen. It is a wash '
                'rising from the bottom edge, not a tint over the app.',
          );
          // The analytic falloff is checked against the real frame everywhere
          // the wash cannot reach, which is what licenses using it as the
          // "before" below the wash.
          for (final t in const <double>[0.001, 0.14, 0.35, 0.45]) {
            final y = size.height * t + 0.5;
            expect(
              near(pixels.at(2, y), unwashed(skin, y, size.height)),
              isTrue,
              reason: 'y=$y is above the wash and must be the bare falloff.',
            );
          }
          expect(
            near(pixels.at(2, size.height - 0.5), lastBare),
            isFalse,
            reason:
                'The last row of the $skinName render is the ground untouched, '
                'which means nothing painted at all.',
          );

          // AND THE DIRECTION, which is the claim worth a test. Measured on
          // the max channel rather than on luminance, because the max channel
          // is also the census's `value` axis and this is the same number the
          // amber argument turns on.
          int maxOf(Color c) => math.max(
            (c.r * 255).round(),
            math.max((c.g * 255).round(), (c.b * 255).round()),
          );
          if (skin.amberIsInk) {
            expect(
              maxOf(lastWashed),
              lessThan(maxOf(lastBare)),
              reason:
                  'The Day wash LIGHTENED the ground. On a light ground that '
                  'is both invisible — Palladian is already value 0.933 — and '
                  'a census violation, because value is the only axis the box '
                  'leaves open on paper.',
            );
            // The value floor itself is measured at the wash's PEAK, which is
            // not on this column — x=2 is at the ellipse's rim, where the
            // wash is weakest. See `the wash alone`.
          } else {
            expect(
              maxOf(lastWashed),
              greaterThan(maxOf(lastBare)),
              reason: 'The Night wash darkened the ground; it is a glow.',
            );
          }
        });
      }
    }
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

    /// The WORST point of the gradient under [rect], which is not the same
    /// thing as the average and not the same thing as an endpoint.
    ///
    /// The wash is a radial gradient about a centre at `(width/2, 1.08*height)`
    /// — below the bottom edge, on the horizontal midline — and its alpha is a
    /// monotone function of the elliptical distance to that centre. So the
    /// strongest wash inside a rectangle is at the rectangle's point *closest
    /// to that centre*: its bottom edge, at the x nearest the midline. There is
    /// no search to do; the geometry says where to look.
    ///
    /// Sampled 2dp below the glyph box so the reading is the ground and not the
    /// ink, which is the same ring the classifier uses.
    Color worstGroundUnder(TorchPixels pixels, Rect rect) {
      final cx = pixels.width / 2;
      final x = cx.clamp(rect.left, rect.right - 1);
      final y = math.min(rect.bottom + 2, pixels.height - 0.5);
      return pixels.at(x, y);
    }

    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      testWidgets('$skinName: every text run on the washed ground, both phases', (
        tester,
      ) async {
        final table = StringBuffer(
          'EVERY TEXT RUN IN THE WASHED THIRD, 390x844 $skinName\n'
          '| phase | run | ink | worst backdrop under it | before | after | '
          'floor | margin | |\n'
          '|---|---|---|---|---|---|---|---|---|\n',
        );
        // The tightest MARGIN — ratio minus the floor that run is held to —
        // because the table mixes 4.5:1 text with 3:1 icon glyphs and the
        // smallest number in a mixed column is not the closest call.
        var worst = double.infinity;
        var worstWhat = '';
        var onTheGround = 0;
        var onMaterial = 0;

        for (final phase in const <String>['at rest', 'answered, scrolled']) {
          await pumpPhase(tester, phase, skin: skin);
          final pixels = await torchPixels(tester);
          final washFrom = firstWashedRow(skin, pixels).toDouble();

          // The opaque materials this screen may print on. A sampled backdrop
          // that matches one EXACTLY has nothing composited over it.
          final materials = <String, Color>{
            'surface': skin.palette.surface,
            'raised': skin.palette.raised,
            'lifted': skin.palette.lifted,
            'well': skin.palette.well,
            'comparisonWash': skin.palette.comparisonWash,
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
            // graphical object at 1.4.11's 3:1 rather than 1.4.3's 4.5:1. It
            // is still measured, and still printed: the floor is what differs.
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
                '| $phase | $label | ${hex(ink)} | $material '
                '${hex(backdrop)} | ${ratio.toStringAsFixed(2)}:1 | same — the '
                'wash is under an opaque fill | ${floor.toStringAsFixed(1)}:1 '
                '| — | unmoved |',
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
            // wash. The "before" is the falloff, validated above, taken at the
            // same row the "after" is read at so the two are comparable.
            onTheGround++;
            final worstPoint = worstGroundUnder(pixels, rect);
            final worstY = math.min(rect.bottom + 2, pixels.height - 0.5);
            final before = unwashed(skin, worstY, pixels.height.toDouble());
            final was = contrastRatio(ink, before);
            final now = contrastRatio(ink, worstPoint);
            if (now - floor < worst) {
              worst = now - floor;
              worstWhat =
                  '$phase / "$label" at ${now.toStringAsFixed(2)}:1 against '
                  '${floor.toStringAsFixed(1)}:1';
            }
            table.writeln(
              '| $phase | $label | ${hex(ink)} | ground ${hex(worstPoint)} at '
              'y=${worstY.toInt()} | ${was.toStringAsFixed(2)}:1 | '
              '${now.toStringAsFixed(2)}:1 | ${floor.toStringAsFixed(1)}:1 | '
              '${(now - floor) >= 0 ? '+' : ''}${(now - floor).toStringAsFixed(2)} | '
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
              'The wash moves the ground the WRONG WAY in both skins — it '
              'lightens a dark ground under light ink and darkens a light '
              'ground under dark ink — which is exactly the failure a wash '
              'passes by eye and fails by ratio. The number is the finding: '
              'back the alpha off and say where you stopped. Do not lower a '
              'floor.',
        );
      });
    }

    // ── THE NUMBER THAT SET DAY'S ALPHA ──────────────────────────────────
    //
    // `edgeControl` on the washed ground is the tightest thing the Day wash
    // touches, and it is what 0.22 was chosen against: on paper it measures
    // 4.32:1 on the bare ground and crosses WCAG 1.4.11's 3:1 at clay alpha
    // **0.287**. The trough's own bottom row is not the wash's peak, so the
    // figure this prints is the one that matters and the 0.287 is the bound.
    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      testWidgets('$skinName: the composer trough is a control edge on the '
          'ground', (tester) async {
        await floor(tester, skin: skin);
        final pixels = await torchPixels(tester);
        final trough = tester.getRect(
          find.byKey(const ValueKey<String>('ask-composer-field')),
        );
        // THE WORST POINT OF THE GRADIENT AROUND THE WHOLE OUTLINE, not one
        // corner of it. The wash is strongest nearest `(width/2, 1.08*height)`,
        // so for a rounded rectangle spanning the gutters the worst reading is
        // just *below* its bottom edge at the horizontal centre — and the
        // reading beside its left edge, which is what this test used to take
        // alone, is at the ellipse's rim where the wash is weakest. Both are
        // sampled and the worse one is the number.
        var after = double.infinity;
        var ground = skin.palette.ground;
        var where = '';
        var atY = 0.0;
        void probe(String name, double x, double y) {
          if (x < 0 || y < 0 || x >= pixels.width || y >= pixels.height) return;
          final sample = pixels.at(x, y);
          // Skip the outline and the trough's own fill: this is measuring the
          // ground the edge is read against, and a sample that IS the edge
          // reads 1.00:1 and says nothing.
          if (exactly(sample, skin.palette.edgeControl)) return;
          if (exactly(sample, skin.palette.well)) return;
          final ratio = contrastRatio(skin.palette.edgeControl, sample);
          if (ratio < after) {
            after = ratio;
            ground = sample;
            where = '$name at $x,$y';
            atY = y;
          }
        }

        // The whole 4dp ring outside the trough, which is every ground pixel
        // its outline is read against. The worst of them is where the wash is
        // strongest — nearest `(width/2, 1.08*height)` — and finding it by
        // sweep rather than by one corner is what makes "the worst point of
        // the gradient under this control" a measurement.
        for (var d = 2.0; d <= 4.0; d += 1.0) {
          for (var x = trough.left - d; x <= trough.right + d; x += 1) {
            probe('above the top edge', x, trough.top - d);
            probe('below the bottom edge', x, trough.bottom + d);
          }
          for (var y = trough.top - d; y <= trough.bottom + d; y += 1) {
            probe('beside the left edge', trough.left - d, y);
            probe('beside the right edge', trough.right + d, y);
          }
        }
        final before = contrastRatio(
          skin.palette.edgeControl,
          unwashed(skin, atY, 844),
        );
        // ignore: avoid_print
        print(
          'THE TROUGH\'S OUTLINE, 390x844 $skinName: edgeControl '
          '${hex(skin.palette.edgeControl)} on the ground at its worst point '
          '($where, y=$atY) — ${hex(ground)}: '
          '${before.toStringAsFixed(2)}:1 before, '
          '${after.toStringAsFixed(2)}:1 after, floor 3.0:1, margin '
          '${after - 3.0 >= 0 ? '+' : ''}${(after - 3.0).toStringAsFixed(2)}',
        );
        expect(
          after,
          greaterThanOrEqualTo(3.0),
          reason:
              'The composer\'s own outline fell under WCAG 1.4.11\'s 3:1 '
              'against the washed ground.',
        );
      });
    }

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
    //
    // ON DAY THE SAME GUARD IS TIGHTER AND IT GUARDS TWO THINGS. `edgeStructure`
    // is 3.14:1 on the bare Day ground — 0.14 of margin — and crosses 3:1 at
    // clay alpha 0.038. `ink3` is 4.74:1 and crosses 4.5:1 at 0.045. Neither
    // appears on the bare ground in the washed third, and the meta ink that
    // might have is on `well` instead, where the wash cannot reach it: that
    // pairing is the tightest declared number in the whole Day skin at 4.52:1
    // and the table above shows it **unmoved**. Both absences are pinned here.
    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      testWidgets('$skinName: no container edge and no tertiary ink is painted '
          'on the washed ground', (tester) async {
        // The tokens whose declared reading on the bare ground does NOT
        // survive the wash, with the floor each is held to. Night has one;
        // Day has two, and the second is why this test grew.
        final fragile = <String, (Color, double)>{
          'edgeStructure': (skin.palette.edgeStructure, 3.0),
          if (skin.amberIsInk) 'ink3': (skin.palette.ink3, 4.5),
        };
        final hypothetical = <String>[];
        for (final phase in phases) {
          await pumpPhase(tester, phase, skin: skin);
          final pixels = await torchPixels(tester);
          final washFrom = firstWashedRow(skin, pixels);
          for (final entry in fragile.entries) {
            final edge = entry.value.$1;
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
              // PRESENCE IS NOT THE VIOLATION; falling under the floor is.
              // Day's `ink3` IS painted below the wash line — it is the
              // trough's standing hint, "Ask about your territories" — and it
              // sits on the `well`, an opaque fill the wash is underneath. So
              // the finding is a measurement at the backdrop beside each run,
              // and only a reading under the floor counts.
              final y = int.parse(found.first.split(',')[1]);
              final ground = pixels.at(pixels.width / 2, y + 4.5);
              final ratio = contrastRatio(edge, ground);
              if (ratio < entry.value.$2) {
                hypothetical.add(
                  '$phase: ${entry.key} at ${found.join(' ')} (washed from '
                  'y=$washFrom); the backdrop 4dp below reads ${hex(ground)} '
                  'at ${ratio.toStringAsFixed(2)}:1 against '
                  '${entry.value.$2.toStringAsFixed(1)}:1',
                );
              }
            }
          }
        }

        // And the numbers themselves, printed whether or not anything was
        // found, so the reviewer sees what the guard is guarding.
        await pumpPhase(tester, 'answered, scrolled', skin: skin);
        final pixels = await torchPixels(tester);
        final band = tester.getRect(
          find.byKey(const ValueKey<String>('floor-band')),
        );
        final floorRow = pixels.at(pixels.width / 2, band.top - 0.5);
        final bare = unwashed(skin, band.top - 0.5, 844);
        final buffer = StringBuffer(
          'THE HYPOTHETICAL EDGE, 390x844 $skinName: the scroll view\'s '
          'viewport floor in the answered state is y=${band.top - 1}, where '
          'the washed ground reads ${hex(floorRow)} against a bare '
          '${hex(bare)}.\n',
        );
        for (final entry in fragile.entries) {
          buffer.writeln(
            '  ${entry.key} ${hex(entry.value.$1)} there would measure '
            '${contrastRatio(entry.value.$1, floorRow).toStringAsFixed(2)}:1 '
            'against ${entry.value.$2.toStringAsFixed(1)}:1 — it is '
            '${contrastRatio(entry.value.$1, bare).toStringAsFixed(2)}:1 on '
            'the bare ground.',
          );
        }
        buffer.writeln(
          '  The Floor paints neither: every container on it is a `TorchCard`, '
          'which has no outline in any skin, and the tertiary ink in the '
          'washed third is on `well`.',
        );
        // ignore: avoid_print
        print(buffer);

        expect(
          hypothetical,
          isEmpty,
          reason:
              'A fragile token landed on the washed ground. The fix is NOT a '
              'lower opacity and it is certainly not a lower floor: it is '
              'that the object wants the grammar this screen already uses — a '
              'card at radius 22 on `surface` with no outline, or `well` under '
              'the meta ink.\n${hypothetical.join('\n')}',
        );
      });
    }

    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      testWidgets('$skinName: the composer label at 2.0x, and the 360x640 '
          'phone', (tester) async {
        for (final (name, size, scale) in const <(String, Size, double)>[
          ('390x844 @ 2.0x', Size(390, 844), 2.0),
          ('390x844 @ 1.3x', Size(390, 844), 1.3),
          ('360x640 @ 1.0x', Size(360, 640), 1.0),
          ('360x640 @ 1.3x', Size(360, 640), 1.3),
        ]) {
          await floor(tester, skin: skin, size: size, textScale: scale);
          final pixels = await torchPixels(tester);
          final label = tester.getRect(find.text('Ask a question'));
          // THE LABEL'S BOTTOM ROW AT THE SCREEN'S HORIZONTAL CENTRE, which is
          // the point of the label's box closest to the wash's ellipse centre
          // and therefore the worst point of the gradient under it. Not the
          // label's own centre and not an endpoint.
          final ground = pixels.at(size.width / 2, label.bottom - 0.5);
          final ratio = contrastRatio(skin.palette.ink2, ground);
          final bare = contrastRatio(
            skin.palette.ink2,
            unwashed(skin, label.bottom - 0.5, size.height),
          );
          // ignore: avoid_print
          print(
            'THE COMPOSER LABEL at $skinName $name: bottom row '
            'y=${label.bottom}, ground ${hex(ground)}, ink-2 at '
            '${bare.toStringAsFixed(2)}:1 before and '
            '${ratio.toStringAsFixed(2)}:1 after (floor 4.5:1, margin '
            '${ratio - 4.5 >= 0 ? '+' : ''}${(ratio - 4.5).toStringAsFixed(2)})',
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'The composer\'s standing label at $skinName $name.',
          );
        }
      });
    }
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
    for (final (skinName, skin, name, size)
        in <(String, TiqSkin, String, Size)>[
          ('night', night, '390x844', const Size(390, 844)),
          ('night', night, '360x640', const Size(360, 640)),
          ('day', day, '390x844', const Size(390, 844)),
          ('day', day, '360x640', const Size(360, 640)),
        ]) {
      testWidgets('$name $skinName: the band\'s own rows are washed', (
        tester,
      ) async {
        await floor(tester, skin: skin, size: size);
        final pixels = await torchPixels(tester);
        final band = tester.getRect(
          find.byKey(const ValueKey<String>('floor-band')),
        );
        final washFrom = firstWashedRow(skin, pixels);
        // 2dp inside the band's top edge, where the band itself draws nothing.
        final y = band.top + 2.5;
        final inside = pixels.at(size.width / 2, y);
        final bare = unwashed(skin, y, size.height);
        // ignore: avoid_print
        print(
          'THE BAND AT $name $skinName: its box is $band, the wash begins at '
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
