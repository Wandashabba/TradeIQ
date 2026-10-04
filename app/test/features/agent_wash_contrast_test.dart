import 'dart:io' show Directory;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/geo/geofence.dart' show Coordinates;
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_contrast.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/agent_wash.dart';
import 'package:tradeiq_app/features/agent_map/data/agent_map.dart';
import 'package:tradeiq_app/features/agent_map/presentation/agent_map_screen.dart';
import 'package:tradeiq_app/features/audit/presentation/my_work_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import 'agent_harness.dart';
import 'me/me_harness.dart';

/// ── EVERY TEXT RUN AND EVERY OUTLINE, ON THE *WASHED* GROUND ───────────
///
/// The back shade is a wash and a wash changes the backdrop every word on the
/// screen is read against. `floor_dawn.dart` bounded The Floor's by naming the
/// pairings its bottom third actually carries; this file does the same job for
/// the agent's four tab roots and does it by **walking the frame** rather than
/// by naming anything, because top-anchoring moves the wash onto the header —
/// which is where the title, the fact line and the sync chip are.
///
/// ## WHY THE NAIVE INSTRUMENT IS WRONG, AND IT IS WORTH SAYING
///
/// The first version of this measurement took the wash's **peak pixel** and
/// ran it against every ink and edge token in the palette. At The Floor's own
/// alphas that fails, and the numbers look alarming — on Night
/// `edgeStructure` reads 1.93:1 against a floor of 3.0 — so it is worth being
/// exact about what that instrument was measuring: *a pairing that does not
/// exist on the screen*. `navInkInactive` is the nav bar's inactive ink and
/// the nav bar is at the **bottom**, where a top-anchored wash is provably
/// zero; `edgeStructure` is a 1px structural outline and no agent tab root
/// paints one in its top third at rest.
///
/// Bounding a wash by pairings nobody draws is how a feature gets cut by its
/// own test. So the instrument is the one `console_wash_test.dart` arrived at
/// the hard way: find the runs that are really there, find the backdrop really
/// under each one, and measure that.
///
/// ## HOW A BACKDROP IS CLASSIFIED HERE, AND WHY IT IS EXACT
///
/// `console_wash_test.dart` has to accept a candidate within 1.6:1 of the bare
/// falloff, because the console's ground is a four-stop gradient and the two
/// desk washes overlap. **The agent profile has none of that.** Its ground is
/// a flat `palette.ground` (`torchGroundAt` returns the token unchanged with
/// no falloff) and there is exactly one wash over it, so the set of colours a
/// *ground* pixel can possibly be is a closed family: the clay at some alpha
/// in `[0, peak]` over the ground, and on Night over the `flame900` hot breath
/// at some alpha in `[0, 0.09]` first.
///
/// That family is enumerated — 129 × 129 on Night, 129 on Day — and
/// membership is exact to within the ±2 levels of ordered dither
/// `floor_band_seam_test.dart` measured on this very gradient. A sampled pixel
/// that is not in the family is **not** the ground and is reported by name
/// rather than measured as though it were: it is a card, a glyph, a chip or a
/// mark, and a wash cannot have moved it because the wash is strictly under
/// every opaque fill.
void main() {
  // flutter_map 8 asks path_provider for the OS cache directory the first
  // time a tile layer is built, and a widget test has no plugin to answer. The
  // map's own test file says the same thing at length; the mock makes the
  // order of these tests irrelevant.
  late final Directory tiles;
  setUpAll(() {
    tiles = Directory.systemTemp.createTempSync('agent-wash-tiles');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tiles.path,
        );
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  const sizes = <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
  ];

  // DAY FIRST. It is the agent's default — `AgentSkinController.build()`
  // returns it because *"they start outdoors at 06:30"* — and it is the
  // harder case: on a light ground the wash DEEPENS the backdrop, so every
  // ratio over it falls, and Day's own tightest declared pairings (`ink3` at
  // 5.15:1 on the ground, `edgeStructure` at 3.41:1) have less margin to
  // spend than Night's.
  const skinOrder = <(String, SkinMode)>[
    ('day', SkinMode.day),
    ('night', SkinMode.night),
  ];

  // ───────────────────────────── THE INSTRUMENT ────────────────────────────

  /// Every colour a GROUND pixel can be under this wash, quantised.
  ///
  /// Two layers on Night and one on Day. The alphas are swept rather than
  /// derived from a y, because the two layers' ellipses are different shapes
  /// and their alphas at one pixel are not a function of each other — the
  /// honest closure is the product of the two ranges.
  Set<int> groundFamily(TiqSkin skin) {
    final family = <int>{};
    final ground = skin.palette.ground;
    final clay = skin.palette.comparison;
    final hot = skin.palette.flame900;
    final clayPeak = skin.amberIsInk ? 0.22 : 0.30;
    final hotPeak = skin.amberIsInk ? 0.0 : 0.09;
    int q(double v) => (v * 255).round().clamp(0, 255);
    int pack(int r, int g, int b) => (r << 16) | (g << 8) | b;
    double over(double fg, double a, double bg) => fg * a + bg * (1 - a);
    for (var hi = 0; hi <= 128; hi++) {
      final ha = hotPeak == 0 ? 0.0 : hotPeak * hi / 128;
      final baseR = over(hot.r, ha, ground.r);
      final baseG = over(hot.g, ha, ground.g);
      final baseB = over(hot.b, ha, ground.b);
      for (var ci = 0; ci <= 128; ci++) {
        final ca = clayPeak * ci / 128;
        family.add(
          pack(
            q(over(clay.r, ca, baseR)),
            q(over(clay.g, ca, baseG)),
            q(over(clay.b, ca, baseB)),
          ),
        );
      }
      if (hotPeak == 0) break;
    }
    return family;
  }

  /// THE DECLARED OPAQUE MATERIALS, WHICH ARE NOT THE GROUND.
  ///
  /// The family above is a cloud — two layers at independent alphas on Night —
  /// and a cloud that wide eventually touches a real material. It did:
  /// Night's `surface` is `#171C22` and the hot breath at α 0.049 under the
  /// clay at α 0.006 composites to `#181C21`, one level away. A run on a card
  /// was therefore being measured as a run on the washed ground.
  ///
  /// That is the same defect `console_wash_test.dart` was corrected for on
  /// 4 October 2026 — *"a backdrop that is neither the ground nor a declared
  /// opaque material now fails by name"* — and the same fix applies: a
  /// candidate that matches any palette token OTHER than `ground` exactly is
  /// a material, not a wash, and the wash is strictly under it. Exact, to
  /// within one level of rounding: one level away from `surface` is not
  /// `surface`.
  Set<int> materials(TiqSkin skin) {
    final p = skin.palette;
    int pack(Color c) =>
        ((c.r * 255).round() << 16) |
        ((c.g * 255).round() << 8) |
        (c.b * 255).round();
    return <Color>[
      p.well,
      p.surface,
      p.raised,
      p.lifted,
      p.hairline,
      p.flame600,
      p.flame700,
      p.goodSolid,
      p.badSolid,
    ].map(pack).toSet();
  }

  bool isMaterial(Color c, Set<int> opaque) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    for (var dr = -1; dr <= 1; dr++) {
      for (var dg = -1; dg <= 1; dg++) {
        for (var db = -1; db <= 1; db++) {
          final key =
              ((r + dr).clamp(0, 255) << 16) |
              ((g + dg).clamp(0, 255) << 8) |
              (b + db).clamp(0, 255);
          if (opaque.contains(key)) return true;
        }
      }
    }
    return false;
  }

  /// Whether [c] is a ground pixel, to within the dither.
  ///
  /// ±2 levels per channel: `floor_band_seam_test.dart` measured a regular
  /// period-2 ordered pattern of that amplitude on this gradient. It is a
  /// tolerance on the *instrument*, not on the finding.
  bool isGround(Color c, Set<int> family) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    for (var dr = -2; dr <= 2; dr++) {
      for (var dg = -2; dg <= 2; dg++) {
        for (var db = -2; db <= 2; db++) {
          final key =
              ((r + dr).clamp(0, 255) << 16) |
              ((g + dg).clamp(0, 255) << 8) |
              (b + db).clamp(0, 255);
          if (family.contains(key)) return true;
        }
      }
    }
    return false;
  }

  /// A frame's pixels, read back off the harness's census boundary.
  Future<(Uint8List, int, int)> frame(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(agentBoundaryKey),
    );
    final out = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      image.dispose();
      return (data!.buffer.asUint8List(), w, h);
    });
    return out!;
  }

  Color at(Uint8List rgba, int w, int h, int x, int y) {
    final px = x.clamp(0, w - 1);
    final py = y.clamp(0, h - 1);
    final o = (py * w + px) * 4;
    return Color.fromARGB(rgba[o + 3], rgba[o], rgba[o + 1], rgba[o + 2]);
  }

  /// One measured run.
  ({String ink, double ratio, Offset where, Color backdrop})? probeRun(
    Uint8List rgba,
    int w,
    int h,
    Rect box,
    Color ink,
    Set<int> family,
    Set<int> opaque,
  ) {
    // A RING, NOT THE BOX. Sampling inside the run's own rect lands on its
    // glyphs and their antialiasing; the backdrop a run is read against is
    // the material immediately around it. 3dp out, which is inside the
    // smallest gap this layout has between a run and its neighbour.
    const ring = 3.0;
    Color? worst;
    var worstRatio = double.infinity;
    Offset where = box.center;
    for (final p in <Offset>[
      Offset(box.left - ring, box.center.dy),
      Offset(box.right + ring, box.center.dy),
      Offset(box.center.dx, box.top - ring),
      Offset(box.center.dx, box.bottom + ring),
      Offset(box.left - ring, box.top - ring),
      Offset(box.right + ring, box.top - ring),
      Offset(box.left - ring, box.bottom + ring),
      Offset(box.right + ring, box.bottom + ring),
    ]) {
      if (p.dx < 0 || p.dy < 0 || p.dx >= w || p.dy >= h) continue;
      final c = at(rgba, w, h, p.dx.round(), p.dy.round());
      // Materials first: the family is the wider test and a material inside
      // it must lose to the name.
      if (isMaterial(c, opaque)) continue;
      if (!isGround(c, family)) continue;
      final r = contrastRatio(ink, c);
      if (r < worstRatio) {
        worstRatio = r;
        worst = c;
        where = p;
      }
    }
    if (worst == null) return null;
    return (
      ink: '#${(ink.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      ratio: worstRatio,
      where: where,
      backdrop: worst,
    );
  }

  /// Walk every paragraph in the tree and measure it against the ground under
  /// it. Returns the worst reading and a printable table.
  Future<
    ({
      double worst,
      double worstOutline,
      String table,
      int measured,
      int skipped,
      int edges,
    })
  >
  measureFrame(
    WidgetTester tester, {
    required TiqSkin skin,
    required String label,
  }) async {
    final (rgba, w, h) = await frame(tester);
    final family = groundFamily(skin);
    final opaque = materials(skin);
    final rows = <String>[];
    var worst = double.infinity;
    var worstLine = '';
    var measured = 0;
    var skipped = 0;

    // ── THE OUTLINES, AT 3.0 (WCAG 1.4.11) ────────────────────────────
    //
    // A structural or control edge is what makes a control look like a
    // control, and a wash sits underneath every one of them. Walked the same
    // way as the runs: the border's own colour against the ground just
    // outside the box it draws.
    var edges = 0;
    var worstEdge = double.infinity;
    var worstEdgeLine = '';

    void walkEdges(RenderObject object) {
      if (object is RenderDecoratedBox) {
        final decoration = object.decoration;
        if (decoration is BoxDecoration) {
          final border = decoration.border;
          if (border is Border && border.top.width > 0) {
            final ink = border.top.color;
            if (ink.a > 0) {
              final offset = object.localToGlobal(Offset.zero);
              final box = Rect.fromLTWH(
                offset.dx,
                offset.dy,
                object.size.width,
                object.size.height,
              );
              final probe = probeRun(rgba, w, h, box, ink, family, opaque);
              if (probe != null) {
                edges++;
                final line =
                    '    ${probe.ratio.toStringAsFixed(2)}:1  edge '
                    '${probe.ink}  on '
                    '${probe.backdrop.toARGB32().toRadixString(16).substring(2).toUpperCase()} '
                    'at ${probe.where.dx.round()},${probe.where.dy.round()}';
                if (probe.ratio < worstEdge) {
                  worstEdge = probe.ratio;
                  worstEdgeLine = line;
                }
              }
            }
          }
        }
      }
      object.visitChildren(walkEdges);
    }

    void walk(RenderObject object) {
      if (object is RenderParagraph) {
        final span = object.text;
        final colour = span is TextSpan ? span.style?.color : null;
        final text = span.toPlainText(
          includeSemanticsLabels: false,
          includePlaceholders: false,
        );
        if (colour != null && text.trim().isNotEmpty) {
          final offset = object.localToGlobal(Offset.zero);
          final box = Rect.fromLTWH(
            offset.dx,
            offset.dy,
            object.size.width,
            object.size.height,
          );
          final probe = probeRun(rgba, w, h, box, colour, family, opaque);
          if (probe == null) {
            // Not a defect: a run inside a card, a chip or a filled block has
            // no ground around it, and the wash is under those fills and
            // cannot have moved the reading. Counted so "nothing was
            // measured" cannot pass as "everything cleared".
            skipped++;
          } else {
            measured++;
            final line =
                '    ${probe.ratio.toStringAsFixed(2)}:1  ink ${probe.ink}  '
                'on ${probe.backdrop.toARGB32().toRadixString(16).substring(2).toUpperCase()} '
                'at ${probe.where.dx.round()},${probe.where.dy.round()}  '
                '"${text.length > 28 ? '${text.substring(0, 28)}…' : text}"';
            if (probe.ratio < worst) {
              worst = probe.ratio;
              worstLine = line;
            }
            rows.add(line);
          }
        }
      }
      object.visitChildren(walk);
    }

    walk(tester.binding.rootElement!.renderObject!);
    walkEdges(tester.binding.rootElement!.renderObject!);

    final table = StringBuffer()
      ..writeln(
        '$label — $measured run(s) and $edges outline(s) on the washed '
        'ground, $skipped run(s) on an opaque fill:',
      )
      ..writeln('  worst run:')
      ..writeln(worstLine);
    if (edges > 0) {
      table
        ..writeln('  worst outline:')
        ..writeln(worstEdgeLine);
    }
    return (
      worst: worst == double.infinity ? 21.0 : worst,
      worstOutline: worstEdge == double.infinity ? 21.0 : worstEdge,
      table: table.toString(),
      measured: measured,
      skipped: skipped,
      edges: edges,
    );
  }

  // ───────────────────────────── THE FIXTURES ──────────────────────────────

  const khumalo = Outlet(
    id: 'o1',
    name: 'Khumalo Superette',
    code: 'KS-014',
    lat: -26.2,
    lng: 28.0,
  );

  final route = TodayRoute(
    planName: 'Tembisa run',
    hasLocation: true,
    stops: <RouteStop>[
      const RouteStop(
        sequence: 1,
        outlet: khumalo,
        visited: true,
        distanceMeters: 1200,
      ),
      const RouteStop(
        sequence: 2,
        outlet: khumalo,
        visited: false,
        distanceMeters: 420,
      ),
    ],
  );

  AgentMapView mapView() => const AgentMapView(
    pins: <MapOutlet>[
      MapOutlet(
        outlet: khumalo,
        state: MapPinState.nextUp,
        sequence: 3,
        distanceMeters: 1200,
      ),
    ],
    here: Coordinates(lat: -26.24, lng: 27.86),
    problem: null,
    planName: 'Tembisa run',
  );

  // ──────────────────────────── THE MEASUREMENT ────────────────────────────

  for (final (sizeName, size) in sizes) {
    for (final (skinName, mode) in skinOrder) {
      final skin = agentSkinFor(mode);

      testWidgets('$skinName $sizeName — Today', (tester) async {
        await pumpAgentScreen(
          tester,
          const TodayScreen(),
          size: size,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            todayRouteProvider.overrideWith((ref) async => route),
          ],
        );
        final r = await measureFrame(
          tester,
          skin: skin,
          label: 'Today · $skinName · $sizeName',
        );
        // ignore: avoid_print
        print(r.table);
        expect(
          r.measured,
          greaterThan(0),
          reason: 'an instrument that measured nothing cannot fail',
        );
        expect(
          r.worst,
          greaterThanOrEqualTo(4.5),
          reason: 'every text run on the washed ground. ${r.table}',
        );
        expect(
          r.worstOutline,
          greaterThanOrEqualTo(3.0),
          reason:
              'every outline against the washed ground, WCAG 1.4.11. '
              '${r.table}',
        );
      });

      testWidgets('$skinName $sizeName — My work', (tester) async {
        await pumpAgentScreen(
          tester,
          const MyWorkScreen(),
          path: '/my-work',
          size: size,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
          ],
        );
        final r = await measureFrame(
          tester,
          skin: skin,
          label: 'My work · $skinName · $sizeName',
        );
        // ignore: avoid_print
        print(r.table);
        expect(r.measured, greaterThan(0));
        expect(
          r.worst,
          greaterThanOrEqualTo(4.5),
          reason: 'every text run on the washed ground. ${r.table}',
        );
        expect(
          r.worstOutline,
          greaterThanOrEqualTo(3.0),
          reason:
              'every outline against the washed ground, WCAG 1.4.11. '
              '${r.table}',
        );
      });

      testWidgets('$skinName $sizeName — Map', (tester) async {
        await pumpAgentScreen(
          tester,
          const AgentMapScreen(),
          path: '/map',
          size: size,
          settle: false,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: mode),
            agentMapProvider.overrideWith((ref) async => mapView()),
          ],
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final r = await measureFrame(
          tester,
          skin: skin,
          label: 'Map · $skinName · $sizeName',
        );
        // ignore: avoid_print
        print(r.table);
        expect(r.measured, greaterThan(0));
        expect(
          r.worst,
          greaterThanOrEqualTo(4.5),
          reason: 'every text run on the washed ground. ${r.table}',
        );
        expect(
          r.worstOutline,
          greaterThanOrEqualTo(3.0),
          reason:
              'every outline against the washed ground, WCAG 1.4.11. '
              '${r.table}',
        );
      });

      testWidgets('$skinName $sizeName — Me', (tester) async {
        await pumpMe(tester, skin: mode, size: size);
        final r = await measureFrame(
          tester,
          skin: skin,
          label: 'Me · $skinName · $sizeName',
        );
        // ignore: avoid_print
        print(r.table);
        expect(r.measured, greaterThan(0));
        expect(
          r.worst,
          greaterThanOrEqualTo(4.5),
          reason: 'every text run on the washed ground. ${r.table}',
        );
        expect(
          r.worstOutline,
          greaterThanOrEqualTo(3.0),
          reason:
              'every outline against the washed ground, WCAG 1.4.11. '
              '${r.table}',
        );
      });
    }
  }

  // ── AND IT STILL BITES, which is the half that matters after an
  // instrument made of exclusions. A synthetic faint ink on the real washed
  // ground must FAIL, and `ink1` on the same ground must pass. An instrument
  // that cannot fail is decoration, and this repository is right to refuse
  // those.
  for (final (skinName, mode) in skinOrder) {
    testWidgets('$skinName: the probe fails a faint run and passes ink-1', (
      tester,
    ) async {
      final skin = agentSkinFor(mode);
      // `inkMute` is the disabled ink — 2.84:1 on the Day ground and 2.79:1
      // on Night — so a run painted in it on the bare ground is already under
      // 4.5 before any wash. Nothing in the product prints a sentence in it;
      // it is here as a known-bad reading.
      await pumpAgentScreen(
        tester,
        _FaintOnWash(skin: skin, ink: skin.palette.inkMute),
        size: const Size(390, 844),
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
        ],
      );
      final faint = await measureFrame(
        tester,
        skin: skin,
        label: 'synthetic faint · $skinName',
      );
      // ignore: avoid_print
      print(faint.table);
      expect(
        faint.measured,
        greaterThan(0),
        reason: 'the faint run has to be CLASSIFIED as on the ground, or '
            'this proves nothing',
      );
      expect(
        faint.worst,
        lessThan(4.5),
        reason: 'the probe has to be able to report a failure. ${faint.table}',
      );

      await pumpAgentScreen(
        tester,
        _FaintOnWash(skin: skin, ink: skin.palette.ink1),
        size: const Size(390, 844),
        overrides: <Override>[
          ...agentBaseOverrides(db: agentTestDb(), skin: mode),
        ],
      );
      final strong = await measureFrame(
        tester,
        skin: skin,
        label: 'synthetic ink-1 · $skinName',
      );
      // ignore: avoid_print
      print(strong.table);
      expect(
        strong.worst,
        greaterThanOrEqualTo(4.5),
        reason:
            'and it has to pass the same run in ink-1 on the same ground, or '
            'it is an instrument that fails everything. ${strong.table}',
      );
    });
  }
}

/// A run in a chosen ink, on the real washed ground, at the wash's strongest
/// on-screen band — the top of the screen.
class _FaintOnWash extends StatelessWidget {
  const _FaintOnWash({required this.skin, required this.ink});

  final TiqSkin skin;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: skin.palette.ground),
      child: Stack(
        children: <Widget>[
          for (final decoration in agentDawnWash(skin))
            Positioned.fill(child: DecoratedBox(decoration: decoration)),
          Positioned(
            left: 40,
            top: 24,
            child: Text(
              'a sentence on the washed ground',
              style: skin.text.body.style(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
