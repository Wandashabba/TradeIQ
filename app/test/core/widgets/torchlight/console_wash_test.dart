import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/design/ambient_wash.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/console_desk.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart'
    show torchGroundAt;
import 'package:tradeiq_app/core/widgets/torchlight/console_wash.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/assistant/answer/composer.dart'
    show QuestionComposer;
import 'package:tradeiq_app/features/webhooks/presentation/webhooks_screen.dart';

import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/trends/presentation/trends_screen.dart';

import '../../../features/assistant/ask_harness.dart';
import '../../../features/dashboard/floor_harness.dart';
import '../../design/amber_golden.dart';
import 'console_desk_harness.dart';
import 'torch_harness.dart' show TorchPixels, torchPixels;

/// ── THE TWO LIGHTS, MEASURED ───────────────────────────────────────────
///
/// `console_wash.dart` makes four claims and this file is all four of them:
///
/// 1. **outline contrast** against the washed ground at the worst point, for
///    `edgeStructure` and `edgeControl`, both skins, against the declared 3.0;
/// 2. **text contrast** at the worst point of the gradient under each run —
///    not the average, not an endpoint — against 4.5 for prose and 3.0 for a
///    graphic;
/// 3. the **amber census** on every desk screen in both skins, before and
///    after, with counts AND region bounds;
/// 4. **banding where the two washes overlap**, by the 4-pixel box mean
///    `floor_band_seam_test.dart` uses, so a dither does not read as a step.
///
/// The hazard the brief named is real and is why (1) exists: blue-grey is
/// already this product's outline colour, so a cool ambient light sits under
/// every outlined control in the rail and the list. The numbers are printed
/// whether they pass or not.
void main() {
  final night = TiqSkin.night();
  final day = TiqSkin.day();
  const size = Size(1440, 900);

  setUpAll(loadDeskFonts);

  /// ── EVERY SHAPE THE DESK HAS, NOT JUST THE THREE-PANE ONE ───────────
  ///
  /// This file used to measure Exceptions alone, which was honest while
  /// Exceptions was the only screen with three panes and The Floor and Ask had
  /// no desk at all. Both of those changed on 3 October 2026: the two routes
  /// that build their own shell now stand on the console's two lights for the
  /// first time, and *"contrast at the worst point of each wash under every
  /// text run"* is a measurement that has to be taken where the text actually
  /// is.
  ///
  /// So the two contrast probes and the census run over four frames:
  ///
  /// | frame | why it is in the set |
  /// |---|---|
  /// | exceptions, a record open | three panes, outlined controls in all three |
  /// | exceptions, the rail's foot open | the ONE outline the rail has ever painted |
  /// | the floor | a photographic plate and a composer, on the washes |
  /// | ask | a transcript column, nothing but ink on the ground |
  /// | trends | one column that fills, charts rather than rows |
  ///
  /// Webhooks is no longer the one-column case — it got its third pane in this
  /// change — so Trends replaces it. See `console_desk_harness.dart`.
  ///
  /// ## THE FIFTH FRAME, AND WHY IT IS NOT A DUPLICATE — 4 October 2026
  ///
  /// `console_wash.dart` rests Night's thinnest margin partly on a claim about
  /// the rail: *"the rail paints no `edgeStructure` and no `edgeControl` at
  /// all — its rows are flat on the ground and its markers are kickers."* The
  /// rail grew a **foot** on 4 October (`ConsoleRailFooter`), and at rest that
  /// claim is still exactly true: the account row is a `MenuFlatRow`, flat on
  /// the ground like the 24 above it, and the marker over it is a kicker.
  ///
  /// Open, it is not. Sign out is a `TorchSecondaryButton` and that is an
  /// `edgeControl` rim — the first outline the rail has ever painted — at the
  /// bottom-left corner, where the cool wash has fallen off and Dawn has not
  /// arrived. The arithmetic says it is the safe token to spend there
  /// (`edgeControl` crosses 3:1 at alpha 0.379 against a washed vignette and
  /// the wash ships at 0.10), but the brief for that change said to measure it
  /// rather than assume it, so this frame exists to put a number on the real
  /// pixels.
  final frames = <(String, Future<void> Function(WidgetTester, TiqSkin))>[
    (
      'exceptions (three panes)',
      (tester, skin) async {
        await pumpDesk(
          tester,
          const AlertsScreen(),
          size: size,
          skin: skin,
          path: '/alerts',
          overrides: deskAlertOverrides(),
          users: deskPeople(),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('console-record-a2')),
        );
        await tester.pumpAndSettle();
      },
    ),
    (
      // THE FOOT OPEN. `deskSession` is what puts somebody in the account row
      // — without it the real `SessionController` finds no keychain under
      // `flutter_test` and the row renders its signed-out form, which is a
      // state the product does not reach and the wrong thing to measure.
      "exceptions, the rail's foot open",
      (tester, skin) async {
        await pumpDesk(
          tester,
          const AlertsScreen(),
          size: size,
          skin: skin,
          path: '/alerts',
          overrides: <Override>[...deskAlertOverrides(), ...deskSession()],
          users: deskPeople(),
        );
        await tester.tap(find.byKey(const ValueKey<String>('rail-account')));
        await tester.pumpAndSettle();
      },
    ),
    (
      'the floor (plate and composer)',
      (tester, skin) async {
        await pumpFloor(
          tester,
          const TheFloorScreen(),
          size: size,
          skin: skin,
          path: '/dashboard',
          current: kpis(osa: 61, execution: 73, priceCompliance: 74),
          previous: kpis(osa: 64, execution: 92),
          outlets: <Outlet>[outlet('o1', 'SaveMor Glenwood')],
          plateImage: await SyncImage.fromFile(
            tester,
            '../backend/assets/places/ALL.jpg',
          ),
        );
      },
    ),
    (
      'ask (one transcript column)',
      (tester, skin) async => pumpAsk(tester, size: size, skin: skin),
    ),
    (
      'trends (one column)',
      (tester, skin) async => pumpDesk(
        tester,
        const TrendsScreen(),
        size: size,
        skin: skin,
        path: '/trends',
        overrides: deskTrendOverrides(),
      ),
    ),
  ];

  String hex(Color c) =>
      '#'
              '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  // ── THE SHAPE OF THE THING, before any pixel is read ─────────────────
  group('the wash is a wash', () {
    test('a skin that refuses gradients gets no wash at all', () {
      // The honest flat fallback for a falloff is NO falloff: a two-centre
      // ambient has no single-colour form, and the shell's own ground is
      // already the right picture without it. Both shipping skins allow
      // gradients, so this changes no pixel today — it is pinned so the guard
      // cannot go quiet.
      for (final skin in <TiqSkin>[night, day]) {
        expect(consoleDeskWash(skin), isNotEmpty);
      }
      final flat = TiqSkin.night().copyWith(
        depth: const TiqDepth(
          shadows: <BoxShadow>[],
          litRim: Color(0x00000000),
          allowsGradients: false,
          borderWidth: 1,
        ),
      );
      expect(consoleDeskWash(flat), isEmpty);
    });

    test('three decorations on Night, two on Day, and all of them gradients', () {
      // Night: the cool one, Dawn's hot breath, Dawn's clay. Day has no hot
      // breath — `floor_dawn.dart` dropped it there because it is what puts
      // the warm wash inside the census box on Palladian.
      expect(consoleDeskWash(night), hasLength(3));
      expect(consoleDeskWash(day), hasLength(2));
      for (final skin in <TiqSkin>[night, day]) {
        for (final decoration in consoleDeskWash(skin)) {
          final box = decoration as BoxDecoration;
          expect(box.gradient, isA<RadialGradient>());
          expect(
            (box.gradient! as RadialGradient).transform,
            isA<AmbientEllipse>(),
            reason:
                'A wash is an ellipse, not a circle. Flutter\'s RadialGradient '
                'radius is one number against the shortest side; the ellipse '
                'is what CSS states and what floor_dawn.dart proved.',
          );
          // THE PAINT BUDGET, as a property of the decoration rather than a
          // promise in a comment.
          expect(box.boxShadow ?? const <BoxShadow>[], isEmpty);
          expect(box.color, isNull);
          expect(box.image, isNull);
        }
      }
    });

    test('the cool wash is the only new colour, and it is a palette token', () {
      for (final skin in <TiqSkin>[night, day]) {
        final cool =
            (consoleDeskWash(skin).first as BoxDecoration).gradient!
                as RadialGradient;
        for (final stop in cool.colors) {
          expect(
            Color.fromARGB(
              255,
              (stop.r * 255).round(),
              (stop.g * 255).round(),
              (stop.b * 255).round(),
            ),
            skin.palette.ambientCool,
            reason:
                'A wash is one token at falling alpha. A second colour here '
                'is a literal at a call site, which is the thing TiqPalette '
                'exists to stop.',
          );
        }
      }
    });
  });

  /// ── THE OPAQUE MATERIALS A DESK SCREEN MAY PRINT ON ────────────────────
  ///
  /// A sampled backdrop that matches one EXACTLY has nothing composited over
  /// it — the wash is under the fill and cannot have moved the reading.
  ///
  /// `lifted` is also `torchAbyssal`, the fill of a selected tab, so the four
  /// surfaces cover every opaque *panel*. The three solid entries are the
  /// opaque **blocks** a desk screen prints words on — the two status fills
  /// and the amber commit — which the panels did not cover. They are listed so
  /// that a probe landing on one is excluded *by name* rather than falling
  /// through to the unclassified branch; none of them is the ground.
  ///
  /// Naming them is not a widened tolerance: the match is EXACT, and one
  /// 8-bit level away a candidate is not this material.
  Map<String, Color> materialsFor(TiqSkin skin) => <String, Color>{
    'surface': skin.palette.surface,
    'raised': skin.palette.raised,
    // Also `torchAbyssal(skin)`: the selected tab's block.
    'lifted': skin.palette.lifted,
    'well': skin.palette.well,
    'goodSolid': skin.palette.goodSolid,
    'badSolid': skin.palette.badSolid,
    'flame600': skin.palette.flame600,
  };

  /// The modal colour of the 3×3 box centred on a point.
  ///
  /// [ringAround]'s sibling, and the difference is the radius and why. A ring
  /// at 2–3dp is right when the point itself is the thing being classified
  /// (a pixel *of* a token, with the backdrop out at the ring). It is wrong
  /// for a probe placed 2dp outside a text run's rect, because a 3dp ring
  /// reaches back **into** the run and the mode picks up its ink.
  ///
  /// Nine samples at radius 1 keeps the box clear of the rect and is still
  /// enough to outvote antialiasing, which is one or two pixels wide at a
  /// glyph's edge. That is the whole reason this exists: the single pixel this
  /// replaced is what let a neighbour's antialiasing be reported as a
  /// backdrop.
  Color modeAround(TorchPixels px, double cx, double cy) {
    final counts = <int, int>{};
    for (var dy = -1.0; dy <= 1.0; dy += 1.0) {
      for (var dx = -1.0; dx <= 1.0; dx += 1.0) {
        final x = cx + dx;
        final y = cy + dy;
        if (x < 0 || y < 0 || x >= px.width || y >= px.height) continue;
        final c = px.at(x, y);
        final key =
            ((c.r * 255).round() << 16) |
            ((c.g * 255).round() << 8) |
            (c.b * 255).round();
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    var best = 0;
    var bestCount = -1;
    for (final e in counts.entries) {
      if (e.value > bestCount) {
        bestCount = e.value;
        best = e.key;
      }
    }
    return Color.fromARGB(
      255,
      (best >> 16) & 0xFF,
      (best >> 8) & 0xFF,
      best & 0xFF,
    );
  }

  /// The modal colour of the 2dp ring around a point — `floor_dawn_test.dart`'s
  /// own classifier, and here for its reason: a ring crosses a sibling now and
  /// then, and one stray pixel of antialiasing would misclassify the probe.
  Color ringAround(TorchPixels px, double cx, double cy) {
    final counts = <int, int>{};
    for (var d = 2.0; d <= 3.0; d += 1.0) {
      for (var t = -d; t <= d; t += 1) {
        for (final p in <Offset>[
          Offset(cx + t, cy - d),
          Offset(cx + t, cy + d),
          Offset(cx - d, cy + t),
          Offset(cx + d, cy + t),
        ]) {
          if (p.dx < 0 || p.dy < 0 || p.dx >= px.width || p.dy >= px.height) {
            continue;
          }
          final c = px.at(p.dx, p.dy);
          final key =
              ((c.r * 255).round() << 16) |
              ((c.g * 255).round() << 8) |
              (c.b * 255).round();
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    var best = 0;
    var bestCount = -1;
    for (final e in counts.entries) {
      if (e.value > bestCount) {
        bestCount = e.value;
        best = e.key;
      }
    }
    return Color.fromARGB(
      255,
      (best >> 16) & 0xFF,
      (best >> 8) & 0xFF,
      best & 0xFF,
    );
  }

  // ── (1) AND (2): WHAT THE WASHES MOVED, ON THE REAL FRAME ────────────
  group('what the washes moved, measured', () {
    /// The WORST point of the two gradients under [rect] — **and it must be
    /// the ground**.
    ///
    /// Unlike The Floor's single bottom-centred dome there are **two** centres
    /// here — cool at `(0.04w, -0.04h)` and Dawn at `(0.76w, 1.04h)` — so the
    /// strongest wash inside a rectangle is at whichever of its corners is
    /// nearest to either centre. There is still no search to do over the whole
    /// rect: alpha is monotone in the elliptical distance to a centre, so the
    /// extreme over a convex box is on its boundary, and the boundary point
    /// closest to a centre is a corner or the foot of the perpendicular. Both
    /// are covered by walking the four corners and the four edge midpoints,
    /// and taking whichever reading has the **lowest contrast** against the
    /// ink — which is the measurement the floor is about.
    ///
    /// ## IT CLASSIFIES ITS BACKDROP NOW, AND THAT IS THE WHOLE FIX
    ///
    /// The first version of this took the single pixel at each of the eight
    /// points and returned whichever had the lowest contrast against the ink,
    /// with **no test that the pixel was the ground at all**. Everything
    /// downstream then treated that colour as a backdrop, and on merged `main`
    /// that shipped two false failures. Both are the **same** artefact, and it
    /// is worth naming precisely because the colours look like two different
    /// problems:
    ///
    /// | | run's ink | "backdrop" | what that colour actually is |
    /// |---|---|---|---|
    /// | Day | `#4A4437` `ink2` | `#1B2632` | Day **`ink1`** |
    /// | Night | `#C9C1B1` `ink2` | `#EEE9DF` | Night **`ink1`** |
    ///
    /// Neither is a material and neither is a backdrop: in both skins the
    /// probe sampled **a neighbouring glyph's `ink1`** and reported ink-on-ink
    /// as a wash finding — 1.59:1 on Day, 1.48:1 on Night. `#1B2632` reads as
    /// "a dark block in a Day render" and `#EEE9DF` as "a near-white block in
    /// a Night render", which is what made this look like two unnamed fills
    /// rather than one geometry bug.
    ///
    /// It was not caused by the wash. #519 and #520 each passed alone; #520
    /// widened every filter chip by about 22dp and #519 moved controls onto
    /// those rows, so the sample point came to rest on a neighbour.
    ///
    /// So a candidate is now **positively classified before it is measured**,
    /// in the order below, and the criterion is the one this file's own comment
    /// on the outline probe already declared and never implemented — *"a pixel
    /// only counts when its backdrop **is the ground**: within 1.6:1 of what
    /// the bare falloff reads at that y"*. 1.6 is not a tolerance that was
    /// widened until the test went quiet; it is wider than anything either
    /// wash can do to the ground (the worst is Dawn's own peak at 1.52:1) and
    /// far narrower than the step to any material or any ink.
    ///
    /// The ink test the outline probe uses — reject within 1.2:1 of the token —
    /// is deliberately **not** carried over here. There it is sound, because
    /// that probe is hunting for pixels *of* the token and a ring of the same
    /// colour means it never left the glyph. Here the ink is known and the
    /// candidate is outside the run's own rect, so the same test would throw
    /// away a genuine low-contrast reading — which is the one thing this
    /// instrument exists to catch.
    ///
    /// Returns the worst **ground** candidate. With no ground candidate it
    /// returns what it did find, labelled, and the caller decides: a material
    /// is an exclusion with a reason, and an unclassifiable backdrop is a
    /// failure that names the colour rather than inventing a reading from it.
    (Color, Offset, String) worstGroundUnder(
      TorchPixels pixels,
      Rect rect,
      Color ink,
      TiqSkin skin,
      Map<String, Color> materials,
    ) {
      bool exact(Color a, Color b) =>
          (a.r * 255).round() == (b.r * 255).round() &&
          (a.g * 255).round() == (b.g * 255).round() &&
          (a.b * 255).round() == (b.b * 255).round();

      final probes = <Offset>[
        Offset(rect.left - 2, rect.top - 2),
        Offset(rect.right + 2, rect.top - 2),
        Offset(rect.left - 2, rect.bottom + 2),
        Offset(rect.right + 2, rect.bottom + 2),
        Offset(rect.center.dx, rect.top - 2),
        Offset(rect.center.dx, rect.bottom + 2),
        Offset(rect.left - 2, rect.center.dy),
        Offset(rect.right + 2, rect.center.dy),
      ];
      var worst = double.infinity;
      var at = Offset.zero;
      var colour = const Color(0xFF000000);
      String? material;
      Color? unknown;
      var unknownAt = Offset.zero;
      for (final probe in probes) {
        if (probe.dx < 0 ||
            probe.dy < 0 ||
            probe.dx >= pixels.width ||
            probe.dy >= pixels.height) {
          continue;
        }
        // THE MODE OF A 3x3 BOX, not the single pixel. A glyph's antialiasing
        // is one or two pixels wide, so it cannot be the mode of nine; and a
        // box of radius 1 around a point already 2dp clear of the run's rect
        // never reaches back into the run itself, which a wider ring would.
        final c = modeAround(pixels, probe.dx, probe.dy);
        final bare = torchGroundAt(
          skin,
          falloff: true,
          height: size.height,
          y: probe.dy,
        );
        if (contrastRatio(c, bare) <= 1.6) {
          final r = contrastRatio(ink, c);
          if (r < worst) {
            worst = r;
            at = probe;
            colour = c;
          }
          continue;
        }
        final m = materials.entries
            .where((e) => exact(c, e.value))
            .map((e) => e.key)
            .firstOrNull;
        if (m != null) {
          material ??= m;
          continue;
        }
        unknown ??= c;
        unknownAt = probe;
      }
      if (worst.isFinite) return (colour, at, 'ground');
      if (material != null) return (materials[material]!, Offset.zero, material);
      if (unknown != null) return (unknown, unknownAt, 'unclassified');
      return (const Color(0xFF000000), Offset.zero, 'off-frame');
    }

    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      for (final (frame, pump) in frames) {
        testWidgets('$skinName, $frame: every outlined control, against the '
            'washed ground', (tester) async {
          await pump(tester, skin);
          final pixels = await torchPixels(tester);

          // The outlined things on a desk screen, by the key that finds them,
          // and which edge token each one wears. There is no list of "every
          // outlined control" in the product, so this is the set this screen
          // actually paints — named rather than discovered, so a reviewer can
          // see what was and was not measured.
          final controls = <String, (Finder, Color, String)>{
            // THE SAME CONTROL UNDER THREE KEYS, and all three are here
            // because the three routes that draw it key it differently:
            // `ConsoleAskBar` on the 27 framed screens, Ask's own composer,
            // and The Floor's. A map with only the first measured nothing at
            // all on Ask and The Floor and printed `+Infinity` for its
            // tightest margin, which is a probe reporting that it looked in
            // the wrong place.
            'the ask bar\'s grid key': (
              find.byKey(const ValueKey<String>('console-destinations')),
              skin.palette.edgeControl,
              'edgeControl',
            ),
            'Ask\'s grid key': (
              find.byKey(const ValueKey<String>('ask-destinations')),
              skin.palette.edgeControl,
              'edgeControl',
            ),
            'The Floor\'s grid key': (
              find.byKey(const ValueKey<String>('floor-destinations')),
              skin.palette.edgeControl,
              'edgeControl',
            ),
            'the selected record\'s ring': (
              find.byKey(const ValueKey<String>('console-record-a2')),
              skin.palette.edgeControl,
              'edgeControl',
            ),
            'a filter chip': (
              find.byKey(const ValueKey<String>('tab-acknowledged')),
              skin.palette.edgeControl,
              'edgeControl',
            ),
            // ── THE RAIL'S ONE OUTLINE ───────────────────────────────────
            //
            // Present only in the fifth frame, which is why the loop above
            // skips a finder it cannot find rather than failing on one. See
            // the `frames` comment: the rail is otherwise flat all the way
            // down, and `console_wash.dart`'s Night margin is argued partly
            // from that.
            'the rail\'s foot: Sign out': (
              find.byKey(const ValueKey<String>('rail-sign-out')),
              skin.palette.edgeControl,
              'edgeControl',
            ),
          };

          final table = StringBuffer(
            'OUTLINES ON THE WASHED GROUND — 1440x900 $skinName\n'
            '| control | edge token | worst backdrop, and where | before | '
            'after | floor | margin | |\n'
            '|---|---|---|---|---|---|---|---|\n',
          );
          var tightest = double.infinity;
          var tightestWhat = '';

          final notOnGround = <String>[];
          for (final entry in controls.entries) {
            final (finder, ink, token) = entry.value;
            if (tester.widgetList(finder).isEmpty) continue;
            final rect = tester.getRect(finder);
            final (backdrop, at, kind) = worstGroundUnder(
              pixels,
              rect,
              ink,
              skin,
              materialsFor(skin),
            );
            // A CONTROL WHOSE SURROUND IS NOT THE GROUND IS NOT A WASH
            // FINDING. The same classification the text probe uses, and here
            // for the same reason: measuring an edge token against a
            // neighbouring glyph or an opaque block is a number about neither
            // the edge nor the wash. It is recorded rather than dropped, so a
            // control that stops being measurable says so.
            if (kind != 'ground') {
              notOnGround.add('${entry.key} ($kind ${hex(backdrop)})');
              continue;
            }
            final after = contrastRatio(ink, backdrop);
            // The "before" is the bare falloff at the same y, which is what the
            // ground would be with no wash on it. `torchGroundAt` is the shell's
            // own function, so this is not an estimate of the before — it is
            // the before.
            final before = contrastRatio(
              ink,
              torchGroundAt(skin, falloff: true, height: size.height, y: at.dy),
            );
            const floor = 3.0;
            if (after - floor < tightest) {
              tightest = after - floor;
              tightestWhat = '${entry.key} at ${after.toStringAsFixed(2)}:1';
            }
            table.writeln(
              '| ${entry.key} | $token ${hex(ink)} | ${hex(backdrop)} at '
              '(${at.dx.toInt()},${at.dy.toInt()}) | '
              '${before.toStringAsFixed(2)}:1 | ${after.toStringAsFixed(2)}:1 | '
              '3.0:1 | ${after - floor >= 0 ? '+' : ''}'
              '${(after - floor).toStringAsFixed(2)} | '
              '${after >= floor ? 'pass' : 'FAIL'} |',
            );
          }

          // ── AND THE HYPOTHETICAL EDGE, which is a GUARD, not a floor ────
          //
          // `floor_dawn_test.dart` established this distinction and it applies
          // here unchanged: **`edgeStructure` does not survive a wash at
          // Dawn's alpha, in either skin, and never did.** That file records
          // the Day figure — 3.14:1 on the bare ground, crossing 3:1 at clay
          // alpha 0.038 — and says The Floor is safe because it paints no
          // outline on the bare ground down there: every container is a
          // `TorchCard`, which has no outline in any skin.
          //
          // The console's ground is a different ground with different things on
          // it, so the guard has to be re-established rather than inherited.
          // What is asserted is therefore **absence**: no fragile token is
          // painted on the washed ground where its backdrop is under its floor.
          // The number it would read if one were is printed either way, so a
          // reviewer sees what the guard is guarding.
          final fragile = <String, (Color, double)>{
            'edgeStructure': (skin.palette.edgeStructure, 3.0),
            if (skin.amberIsInk) 'ink3': (skin.palette.ink3, 4.5),
          };
          bool same(Color a, Color b) =>
              (a.r * 255).round() == (b.r * 255).round() &&
              (a.g * 255).round() == (b.g * 255).round() &&
              (a.b * 255).round() == (b.b * 255).round();

          // ── WHAT COUNTS AS "ON THE WASHED GROUND" ────────────────────────
          //
          // The first draft of this probe sampled 4dp below each found pixel and
          // it reported two things that are not findings, which is worth writing
          // down because both are the shape of mistake this instrument invites:
          //
          // * `edgeStructure` at (941,201) with a backdrop of `#E2DBCC`, which
          //   is Day's **`well`** exactly. 2.99:1 there is a pairing
          //   `tiq_palette.dart` already declares and bans — *"except the Day
          //   well, where it is banned (2.99:1)"* — and it is unmoved by the
          //   wash, because the wash is under an opaque fill.
          // * `ink3` with backdrops of `#70695B` and `#696255`, which are within
          //   a few levels of `ink3` itself: the probe had landed on the
          //   antialiased edge of another glyph.
          //
          // So a pixel only counts when its backdrop **is the ground**: within
          // 1.6:1 of what the bare falloff reads at that y, which is wider than
          // anything either wash can do to it (the worst is Dawn's own peak at
          // 1.52:1) and far narrower than the step to any material or any ink.
          // The two rejected classes are counted and printed, so "nothing was
          // found" cannot quietly mean "nothing was looked at".
          final opaque = <String, Color>{
            'surface': skin.palette.surface,
            'raised': skin.palette.raised,
            'lifted': skin.palette.lifted,
            'well': skin.palette.well,
          };
          var onMaterial = 0;
          var onInk = 0;
          final hypothetical = <String>[];
          for (final entry in fragile.entries) {
            final token = entry.value.$1;
            final floor = entry.value.$2;
            final found = <String>[];
            for (var y = 0; y < pixels.height; y++) {
              for (var x = 0; x < pixels.width; x++) {
                if (!same(pixels.at(x + 0.5, y + 0.5), token)) continue;
                final backdrop = ringAround(pixels, x + 0.5, y + 0.5);
                final material = opaque.entries
                    .where((e) => same(backdrop, e.value))
                    .map((e) => e.key)
                    .firstOrNull;
                if (material != null) {
                  onMaterial++;
                  break;
                }
                // ── THE THIRD REJECTION: THE PROBE NEVER LEFT THE GLYPH ──
                //
                // Added 3 October 2026, when this probe was extended from
                // Exceptions alone to Trends, Ask and The Floor. On a chart
                // panel the ring around an `ink3` pixel is often **`ink3`
                // itself** — a solid run of small type, or the fill of a
                // plotted mark — and the probe duly reported `1.00:1`, which
                // is not a finding about a wash. It is the same class of
                // artefact the comment above records for an antialiased glyph
                // edge, seen from the inside rather than the side.
                //
                // 1.2:1 is deliberately generous: nothing the console paints
                // on the ground is within 1.2 of a fragile token except that
                // token, and the two washes at their peak move the ground by
                // at most 1.52:1 (Dawn's own), so no real reading can hide
                // under it. The rejects are counted and printed, so "nothing
                // was found" still cannot mean "nothing was looked at".
                if (contrastRatio(token, backdrop) < 1.2) {
                  onInk++;
                  break;
                }
                if (contrastRatio(token, backdrop) < floor) {
                  found.add(
                    '$x,$y (backdrop ${hex(backdrop)}, '
                    '${contrastRatio(token, backdrop).toStringAsFixed(2)}:1)',
                  );
                }
                break;
              }
              if (found.length > 3) break;
            }
            if (found.isNotEmpty) {
              hypothetical.add('${entry.key} at ${found.join(' ')}');
            }
          }

          table.writeln(
            '\nTHE HYPOTHETICAL EDGE — what a fragile token WOULD '
            'read on the washed ground, at four points nothing paints one:',
          );
          for (final (name, probe) in <(String, Offset)>[
            ('the cool peak, behind the rail', const Offset(20, 20)),
            ('the rail\'s foot', Offset(20, size.height - 20)),
            ('where the two washes overlap', Offset(size.width * 0.35, 870)),
            (
              'Dawn\'s peak, under the detail pane',
              Offset(size.width * 0.76, 898),
            ),
          ]) {
            final c = pixels.at(probe.dx, probe.dy);
            final bare = torchGroundAt(
              skin,
              falloff: true,
              height: size.height,
              y: probe.dy,
            );
            for (final entry in fragile.entries) {
              final token = entry.value.$1;
              final floor = entry.value.$2;
              final after = contrastRatio(token, c);
              table.writeln(
                '| $name | ${entry.key} ${hex(token)} | ${hex(c)} at '
                '(${probe.dx.toInt()},${probe.dy.toInt()}) | '
                '${contrastRatio(token, bare).toStringAsFixed(2)}:1 | '
                '${after.toStringAsFixed(2)}:1 | ${floor.toStringAsFixed(1)}:1 | '
                '${after - floor >= 0 ? '+' : ''}'
                '${(after - floor).toStringAsFixed(2)} | '
                '${after >= floor ? 'would pass' : 'WOULD FAIL — guarded by '
                          'absence'} |',
              );
            }
          }
          table.writeln(
            '\n${hypothetical.isEmpty ? 'Nothing paints a fragile token on this '
                      'ground' : 'A fragile token IS on this ground'}: every container '
            'on a console screen is a `TorchCard` or a `SoftRow`, which have no '
            'outline in any skin, and the rail\'s rows are flat on the ground '
            'with no edge at all. $onInk pixel row(s) were rejected because '
            'the ring around the probe read within 1.2:1 of the token itself '
            '— the probe was inside a glyph, not on the ground. '
            '$onMaterial pixel row(s) carrying a fragile '
            'token were found with an opaque material around them and are not '
            'on the ground: the wash is under the fill and cannot have moved '
            'those. The Day `well` case is one of them, and it is a pairing '
            '`tiq_palette.dart` already declares and bans at 2.99:1 — '
            'pre-existing, and unmoved.',
          );

          table.writeln(
            '\n${notOnGround.isEmpty ? 'Every named control was measured '
                      'against the ground' : 'Not measured, surround is not the '
                      'ground: ${notOnGround.join('; ')}'}',
          );

          table.writeln(
            '\nTightest margin among PAINTED outlines: '
            '+${tightest.toStringAsFixed(2)} — $tightestWhat',
          );
          // ignore: avoid_print
          print(table);

          expect(
            tightest,
            greaterThanOrEqualTo(0),
            reason:
                'A PAINTED outline fell under 3.0:1 on the washed ground.\n'
                '$table\n'
                'The declared floor for a structural edge is 3.0 and it is not '
                'negotiable: a wash that takes the separation out of an outline '
                'takes away the thing that makes a control look like a control. '
                'Back the alpha off, or ship Dawn alone. Do not lower a floor.',
          );
          expect(
            hypothetical,
            isEmpty,
            reason:
                'A fragile token landed on the washed ground under its floor. '
                'The fix is NOT a lower alpha and it is certainly not a lower '
                'floor: it is that the object wants the grammar the console '
                'already uses — a card on `surface` with no outline, or an '
                'opaque fill under the ink.\n${hypothetical.join('\n')}\n$table',
          );
        });

        testWidgets('$skinName, $frame: every text run on the washed ground', (
          tester,
        ) async {
          await pump(tester, skin);
          final pixels = await torchPixels(tester);

          // See [materialsFor]: the opaque fills the wash sits under.
          final materials = materialsFor(skin);

          final table = StringBuffer(
            'EVERY TEXT RUN ON THE WASHED GROUND — 1440x900 $skinName, '
            '$frame\n'
            '| run | ink | worst backdrop under it | before | after | floor | '
            'margin | |\n|---|---|---|---|---|---|---|---|\n',
          );
          var tightest = double.infinity;
          var tightestWhat = '';
          var onGround = 0;
          var onMaterial = 0;
          var offFrame = 0;
          // A run whose backdrop the probe could not classify. Not a contrast
          // finding and NOT a pass: the instrument saying it does not know
          // what it is looking at, which is the one thing the version this
          // replaced could not say.
          final unclassified = <String>[];

          for (final element in find.byType(Text).evaluate()) {
            final widget = element.widget as Text;
            final ink = widget.style?.color;
            final text = widget.data;
            if (ink == null || text == null || text.trim().isEmpty) continue;
            final Rect rect;
            try {
              rect = tester.getRect(find.byWidget(widget));
            } on StateError {
              continue;
            }
            if (rect.isEmpty) continue;
            // ── AND A RUN THAT IS NOT ON THE RENDERED FRAME ──────────────
            //
            // Added 3 October 2026, with Trends. A `ListView` builds a child
            // slightly past the viewport and a `Wrap` inside a horizontal rail
            // lays one out off the right edge; `getRect` reports where it
            // *would* be, the pixel buffer has nothing there, and
            // `worstGroundUnder` dutifully returns `#000000 at (0,0)` — which
            // then reads as a 3.37:1 failure against a backdrop the frame does
            // not contain. A run nobody can see is not a contrast finding; it
            // is a run nobody can see.
            final frame = Rect.fromLTWH(
              0,
              0,
              pixels.width.toDouble(),
              pixels.height.toDouble(),
            );
            if (!rect.overlaps(frame)) {
              offFrame++;
              continue;
            }

            final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
            // AN ICON IS NOT A WORD — `floor_dawn_test.dart`'s rule: a single
            // rune in the Unicode private-use area is a Material glyph, and WCAG
            // puts a graphical object at 1.4.11's 3:1 rather than 1.4.3's 4.5:1.
            final glyph =
                flat.runes.length == 1 &&
                flat.runes.first >= 0xE000 &&
                flat.runes.first <= 0xF8FF;
            final floor = glyph ? 3.0 : 4.5;
            final label = glyph
                ? 'an icon glyph, U+'
                      '${flat.runes.first.toRadixString(16).toUpperCase()}'
                : (flat.length <= 30 ? flat : '${flat.substring(0, 28)}…');

            final (backdrop, at, kind) = worstGroundUnder(
              pixels,
              rect,
              ink,
              skin,
              materials,
            );
            if (kind == 'off-frame') {
              offFrame++;
              continue;
            }
            if (kind == 'unclassified') {
              unclassified.add(
                '"$label" ${hex(ink)}: ${hex(backdrop)} at '
                '(${at.dx.toInt()},${at.dy.toInt()}) is neither the ground at '
                'that y nor any declared opaque material',
              );
              continue;
            }
            if (kind != 'ground') {
              onMaterial++;
              final ratio = contrastRatio(ink, backdrop);
              expect(
                ratio,
                greaterThanOrEqualTo(floor),
                reason:
                    '"$label" on $kind is ${ratio.toStringAsFixed(2)}:1, '
                    'which is a pre-existing reading and not this change: the '
                    'wash is under an opaque fill.',
              );
              continue;
            }

            onGround++;
            final after = contrastRatio(ink, backdrop);
            final before = contrastRatio(
              ink,
              torchGroundAt(skin, falloff: true, height: size.height, y: at.dy),
            );
            if (after - floor < tightest) {
              tightest = after - floor;
              tightestWhat =
                  '"$label" at ${after.toStringAsFixed(2)}:1 '
                  'against ${floor.toStringAsFixed(1)}:1';
            }
            table.writeln(
              '| $label | ${hex(ink)} | ${hex(backdrop)} at '
              '(${at.dx.toInt()},${at.dy.toInt()}) | '
              '${before.toStringAsFixed(2)}:1 | ${after.toStringAsFixed(2)}:1 | '
              '${floor.toStringAsFixed(1)}:1 | '
              '${after - floor >= 0 ? '+' : ''}'
              '${(after - floor).toStringAsFixed(2)} | '
              '${after >= floor ? 'pass' : 'FAIL'} |',
            );
          }

          table.writeln(
            '\n$offFrame run(s) off the rendered frame, '
            '$onGround run(s) on the bare washed ground, $onMaterial on an '
            'opaque material, ${unclassified.length} unclassified. '
            'Tightest margin on the ground: '
            '${tightest.isFinite ? '+${tightest.toStringAsFixed(2)} — $tightestWhat' : 'none'}',
          );
          for (final u in unclassified) {
            table.writeln('UNCLASSIFIED | $u');
          }
          // ignore: avoid_print
          print(table);

          expect(
            onGround,
            greaterThan(0),
            reason:
                'No text run was classified as sitting on the washed ground, so '
                'this test proved nothing. The rail\'s labels and the route\'s '
                'header are on it; if the classifier stopped finding them, fix '
                'the classifier.',
          );
          // ── THE INSTRUMENT MUST NOT GUESS ────────────────────────────────
          //
          // A backdrop that is neither the ground at that y nor one of the
          // declared opaque materials means the probe landed on something
          // nobody has named. The version this replaced measured such a pixel
          // as if it were the ground and reported 1.59:1 and 1.48:1 — two
          // false failures on merged `main`. Failing here instead is the
          // point: the answer is to NAME the material (or fix the probe), not
          // to widen a tolerance until it stops asking.
          expect(
            unclassified,
            isEmpty,
            reason:
                'The probe could not classify the backdrop under '
                '${unclassified.length} text run(s).\n'
                '${unclassified.join('\n')}\n$table\n'
                'Each line is a pixel the instrument refuses to measure '
                'because it cannot say what it is. If the colour is a declared '
                'opaque fill, add it to `materials` by name. If it is a '
                'glyph\'s antialiasing, the probe geometry is wrong and '
                '`modeAround` is where that lives. Do NOT relax the 1.6:1 '
                'ground window to make this pass — that window is what makes '
                'every other number in the table mean something.',
          );
          expect(
            tightest,
            greaterThanOrEqualTo(0),
            reason:
                'Ink on the washed ground fell under its floor.\n$table\n'
                'A wash moves the ground the WRONG WAY in both skins — it '
                'lightens a dark ground under light ink and darkens a light one '
                'under dark ink — which is exactly the failure a wash passes by '
                'eye and fails by ratio. The number is the finding.',
          );
        });
      }
    }

    // ── AND IT STILL BITES ────────────────────────────────────────────────
    //
    // A probe that was taught to reject candidates is a probe that can be
    // taught to reject everything, and the four false failures this commit
    // fixes were fixed by *narrowing* what counts as a reading. So the
    // instrument is pointed at a run that genuinely fails, on the real washed
    // ground, and has to catch it.
    //
    // The fixture is a flat `vignette` panel with the real `consoleDeskWash`
    // over it. That is not an approximation of the ground: the shell's falloff
    // is `ground → vignette → vignette → ground`, so between the two 96dp
    // ramps `torchGroundAt` returns `vignette` exactly, which is the colour
    // the classifier compares a candidate against at those y values.
    //
    // Both directions are asserted, because "it fails" is only half the proof
    // — an instrument that failed everything would also pass that half:
    //
    //  * a synthetic ink near the ground must classify as `ground` AND read
    //    under 4.5:1;
    //  * `ink1` must classify as `ground` and read well over 4.5:1.
    //
    // The faint inks are synthetic and that is deliberate: a real token here
    // would read as a product defect, and the claim being made is about the
    // probe, not the palette.
    for (final (skinName, skin, faint) in <(String, TiqSkin, Color)>[
      ('night', night, const Color(0xFF3A4450)),
      ('day', day, const Color(0xFFC8C2B5)),
    ]) {
      testWidgets('$skinName: the probe still catches a real low-contrast run', (
        tester,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        Widget run(Color ink, String label) =>
            Text(label, style: TextStyle(color: ink, fontSize: 16));

        var ground = Container(
          width: size.width,
          height: size.height,
          color: skin.palette.vignette,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              run(faint, 'a faint run on the washed ground'),
              const SizedBox(height: 40),
              run(skin.palette.ink1, 'a legible run beside it'),
            ],
          ),
        );
        // The real wash, in the real paint order the shell uses.
        for (final d in consoleDeskWash(skin).reversed) {
          ground = Container(decoration: d, child: ground);
        }

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size, devicePixelRatio: 1.0),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Theme(
                data: ThemeData(extensions: <ThemeExtension<dynamic>>[skin]),
                child: RepaintBoundary(
                  key: const ValueKey<String>('amber-golden-boundary'),
                  child: ground,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final pixels = await torchPixels(tester);
        final materials = materialsFor(skin);

        (String, double) read(String label, Color ink) {
          final rect = tester.getRect(find.text(label));
          final (backdrop, _, kind) = worstGroundUnder(
            pixels,
            rect,
            ink,
            skin,
            materials,
          );
          return (kind, contrastRatio(ink, backdrop));
        }

        final (badKind, badRatio) = read(
          'a faint run on the washed ground',
          faint,
        );
        final (goodKind, goodRatio) = read(
          'a legible run beside it',
          skin.palette.ink1,
        );

        // ignore: avoid_print
        print(
          'STILL BITES — $skinName: faint ${hex(faint)} classified '
          '"$badKind" at ${badRatio.toStringAsFixed(2)}:1 (floor 4.5); '
          'ink1 ${hex(skin.palette.ink1)} classified "$goodKind" at '
          '${goodRatio.toStringAsFixed(2)}:1',
        );

        expect(
          badKind,
          'ground',
          reason:
              'The classifier did not recognise the washed vignette as the '
              'ground, so the probe would have skipped a real finding. That is '
              'the failure mode the 1.6:1 window has to avoid.',
        );
        expect(
          badRatio,
          lessThan(4.5),
          reason:
              'A run at ${badRatio.toStringAsFixed(2)}:1 on the washed ground '
              'is under 1.4.3\'s floor and the probe has to read it as such. '
              'If this passes, the instrument has gone quiet.',
        );
        expect(
          goodKind,
          'ground',
          reason: 'The legible run is on the same ground as the faint one.',
        );
        expect(
          goodRatio,
          greaterThan(4.5),
          reason:
              'ink1 on the washed ground must still read as legible — an '
              'instrument that fails everything is no more use than one that '
              'passes everything.',
        );
      });
    }
  });

  // ── (3): THE AMBER CENSUS, BEFORE AND AFTER ──────────────────────────
  //
  // Before is not a different build: `TorchShell.backdrop` is a list, and an
  // empty one adds no render object at all, so the "before" frame is the one
  // commit 1 shipped. The two censuses are taken on the same tree with the
  // wash on and off.
  group('the amber census, before and after the lights', () {
    for (final (skinName, skin, budget) in <(String, TiqSkin, int)>[
      ('night', night, 2),
      ('day', day, 1),
    ]) {
      // THE SAME FOUR FRAMES THE CONTRAST PROBES USE, plus Webhooks, which
      // was the one-column example here and is a three-pane screen as of this
      // change. It stays in the census — a screen that grew a detail pane is
      // exactly a screen whose amber count could have moved.
      for (final (route, pump)
          in <(String, Future<void> Function(WidgetTester, TiqSkin))>[
            ...frames,
            (
              'webhooks (three panes)',
              (tester, skin) async => pumpDesk(
                tester,
                const WebhooksScreen(),
                size: size,
                skin: skin,
                path: '/webhooks',
                overrides: deskWebhookOverrides(),
              ),
            ),
          ]) {
        // TWO TESTS, NOT TWO PUMPS. Pumping the same tester twice and reading
        // the boundary after each was the obvious shape and it lied: the
        // second census came back with **zero lit pixels on a frame that
        // plainly has a Send disc in it**, because the repaint boundary's
        // `toImage` was handed a layer tree the second `pumpWidget` had
        // already torn down. One pump per test, and the two numbers are
        // compared through a variable the group owns.
        testWidgets('$route, $skinName — BEFORE, no wash', (tester) async {
          // `allowsGradients: false` is the honest "before": `consoleDeskWash`
          // returns an empty list there, and `TorchShell.backdrop` with an
          // empty list adds no render object at all — byte-identical to the
          // frame commit 1 shipped. It also flattens the amber fill ramp, so
          // the Send disc is a flat `flame600`: still one region, in the same
          // box, which is the only property this census is about.
          await pump(tester, skin.copyWith(depth: _noGradients(skin)));
          final census = await amberCensus(tester);
          _before['$route/$skinName'] = census;
          // ignore: avoid_print
          print(
            'AMBER CENSUS — $route, $skinName, budget $budget\n'
            '  BEFORE (no wash): ${census.describe()}',
          );
          expectWithinAmberBudget(
            census,
            skin,
            route: '$route (desk, unwashed)',
            phase: 'loaded',
          );
        });

        testWidgets('$route, $skinName — AFTER, two lights', (tester) async {
          await pump(tester, skin);
          final census = await amberCensus(tester);
          final before = _before['$route/$skinName'];
          // ignore: avoid_print
          print(
            'AMBER CENSUS — $route, $skinName, budget $budget\n'
            '  AFTER (two lights): ${census.describe()}',
          );
          expectWithinAmberBudget(
            census,
            skin,
            route: '$route (desk, washed)',
            phase: 'loaded',
          );
          expect(
            census.objectCount,
            before?.objectCount,
            reason:
                'The lights changed the number of amber objects on $route in '
                '$skinName, from ${before?.objectCount} to '
                '${census.objectCount}. A wash emits nothing: it is strictly '
                'under every object on the screen and the only thing beneath '
                'it is the ground.\n\n'
                'BEFORE\n${before?.describe()}\nAFTER\n${census.describe()}',
          );
        });
      }
    }
  });

  // ── (4): BANDING WHERE THE TWO WASHES OVERLAP ────────────────────────
  //
  // `floor_band_seam_test.dart`'s instrument, unchanged and for its reason: a
  // 4-pixel box mean on each side of a boundary cancels Flutter's period-2
  // ordered dither exactly, a real edge survives it at full height, and a
  // gradient's own travel across the 8 pixels the pair spans is under two
  // levels. A test that forbade the dither would be a test against
  // anti-banding.
  group('where the two washes overlap, there is no band', () {
    const window = 4;
    const tolerance = 3.0;

    List<double> mean(
      TorchPixels px,
      int from,
      bool horizontal, {
      required double fixed,
    }) {
      var r = 0.0, g = 0.0, b = 0.0;
      for (var i = 0; i < window; i++) {
        final at = (from + i).toDouble();
        final c = horizontal ? px.at(at, fixed) : px.at(fixed, at + 0.5);
        r += c.r * 255;
        g += c.g * 255;
        b += c.b * 255;
      }
      return <double>[r / window, g / window, b / window];
    }

    double gap(List<double> a, List<double> b) {
      var m = 0.0;
      for (var i = 0; i < 3; i++) {
        final d = (a[i] - b[i]).abs();
        if (d > m) m = d;
      }
      return m;
    }

    String show(List<double> m) =>
        '#'
                '${m[0].round().toRadixString(16).padLeft(2, '0')}'
                '${m[1].round().toRadixString(16).padLeft(2, '0')}'
                '${m[2].round().toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();

    for (final (skinName, skin) in <(String, TiqSkin)>[
      ('night', night),
      ('day', day),
    ]) {
      testWidgets('$skinName: the overlap is smooth in both axes', (
        tester,
      ) async {
        await pumpDesk(
          tester,
          const AlertsScreen(),
          size: size,
          skin: skin,
          path: '/alerts',
          overrides: deskAlertOverrides(),
          users: deskPeople(),
        );
        final pixels = await torchPixels(tester);

        // ── THE WINDOW, AND WHY IT IS NAMED RATHER THAN SEARCHED ────────
        //
        // The cool centre is at x = 0.04w and Dawn's at x = 0.76w, so the two
        // tails cross in the lower-middle of the frame. The first draft of
        // this probe walked whole rows and reported 191 and 223 levels — it
        // had found the Send disc and the route's title, which is the
        // instrument working correctly on the wrong pixels.
        //
        // So the window is the rectangle of this screen that is **bare
        // ground**: below the last record card, above the ask bar, and right
        // of the rail. Its bounds are read off the real widgets rather than
        // guessed, and the test fails loudly if the rectangle it computes is
        // not actually empty — a probe that silently moved onto a card would
        // report a card's edge as banding.
        final lastCard = tester.getRect(
          find.byKey(const ValueKey<String>('console-record-a2')),
        );
        final bar = tester.getRect(find.byType(QuestionComposer));
        final rail = tester.getRect(
          find.byKey(const ValueKey<String>('console-rail')),
        );
        final top = lastCard.bottom + 8;
        final bottom = bar.top - 8;
        final left = rail.right + 8;
        final right = pixels.width - 8;
        expect(
          bottom - top,
          greaterThan(40),
          reason:
              'The bare-ground window between the last record (y='
              '${lastCard.bottom}) and the ask bar (y=${bar.top}) is too '
              'short to measure a gradient in. The instrument needs somewhere '
              'the two washes meet with nothing painted over them.',
        );

        var worstRow = 0.0;
        var worstRowAt = 0;
        var worstRowY = 0.0;
        for (var y = top; y <= bottom; y += 12) {
          for (var x = left.round() + window; x + window <= right; x++) {
            final here = gap(
              mean(pixels, x - window, true, fixed: y),
              mean(pixels, x, true, fixed: y),
            );
            if (here > worstRow) {
              worstRow = here;
              worstRowAt = x;
              worstRowY = y;
            }
          }
        }

        // And down the columns the two washes share: a radial pair bands in
        // rings, not only in rows.
        var worstCol = 0.0;
        var worstColAt = 0;
        var worstColX = 0.0;
        for (var x = left + 20; x < right - 20; x += 60) {
          for (var y = top.round() + window; y + window <= bottom; y++) {
            final here = gap(
              mean(pixels, y - window, false, fixed: x + 0.5),
              mean(pixels, y, false, fixed: x + 0.5),
            );
            if (here > worstCol) {
              worstCol = here;
              worstColAt = y;
              worstColX = x;
            }
          }
        }

        // The composite at the two ends of the window, so a reader can see
        // that the two washes really are both present where this measured.
        final leftEnd = pixels.at(left + 2, (top + bottom) / 2);
        final rightEnd = pixels.at(right - 2, (top + bottom) / 2);

        // ignore: avoid_print
        print(
          'BANDING WHERE THE TWO WASHES OVERLAP — 1440x900 $skinName\n'
          '  window: x ${left.toInt()}..${right.toInt()}, '
          'y ${top.toInt()}..${bottom.toInt()} — bare ground between the last '
          'record and the ask bar\n'
          '  across it the composite runs ${hex(leftEnd)} (cool end) to '
          '${hex(rightEnd)} (Dawn end)\n'
          '  instrument: $window-pixel box mean, which cancels Flutter\'s '
          'period-2 ordered dither exactly\n'
          '  worst horizontal step: ${worstRow.toStringAsFixed(2)} levels at '
          'x=$worstRowAt on y=${worstRowY.toInt()} — '
          '${show(mean(pixels, worstRowAt - window, true, fixed: worstRowY))} '
          'against '
          '${show(mean(pixels, worstRowAt, true, fixed: worstRowY))}\n'
          '  worst vertical step:   ${worstCol.toStringAsFixed(2)} levels at '
          'y=$worstColAt on x=${worstColX.toInt()} — '
          '${show(mean(pixels, worstColAt - window, false, fixed: worstColX + 0.5))} '
          'against '
          '${show(mean(pixels, worstColAt, false, fixed: worstColX + 0.5))}\n'
          '  tolerance: $tolerance levels',
        );

        expect(
          worstRow,
          lessThanOrEqualTo(tolerance),
          reason:
              'The two washes band horizontally: at y=${worstRowY.toInt()} the '
              '$window-pixel means either side of x=$worstRowAt differ by '
              '${worstRow.toStringAsFixed(2)} levels. Two gradients '
              'composited over each other is where a third stop stops being '
              'optional.',
        );
        expect(
          worstCol,
          lessThanOrEqualTo(tolerance),
          reason:
              'The two washes band vertically: at x=${worstColX.toInt()} the '
              '$window-row means either side of y=$worstColAt differ by '
              '${worstCol.toStringAsFixed(2)} levels.',
        );
      });
    }
  });

  // ── AND BELOW THE THRESHOLD, NO WASH AT ALL ──────────────────────────
  testWidgets('the phone gets no console wash', (tester) async {
    for (final skin in <TiqSkin>[night, day]) {
      await pumpDesk(
        tester,
        const AlertsScreen(),
        size: const Size(390, 844),
        skin: skin,
        path: '/alerts',
        overrides: deskAlertOverrides(),
        users: deskPeople(),
      );
      expect(ConsoleDesk.isDesk(skin, const Size(390, 844)), isFalse);
      // The frame only computes `consoleDeskWash` on the desk arm, so this is
      // a statement about the tree and not about the function.
      expect(find.byType(ConsoleRail), findsNothing);
    }
  });
}

/// The unwashed census per route × skin, filled by the BEFORE test and read by
/// the AFTER one. A map rather than two pumps in one test — see the comment at
/// the call site.
final Map<String, AmberCensus> _before = <String, AmberCensus>{};

/// A depth with gradients refused, for the "before" census and for the flat
/// fallback. Every other field is the skin's own.
TiqDepth _noGradients(TiqSkin skin) => TiqDepth(
  shadows: skin.depth.shadows,
  litRim: skin.depth.litRim,
  allowsGradients: false,
  borderWidth: skin.depth.borderWidth,
);
