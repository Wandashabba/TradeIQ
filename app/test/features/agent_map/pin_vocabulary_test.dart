import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/agent_map/data/agent_map.dart';
import 'package:tradeiq_app/features/agent_map/presentation/agent_map_screen.dart'
    show mapStateWord;
import 'package:tradeiq_app/features/agent_map/presentation/outlet_map.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/presentation/territory_map_screen.dart'
    show OutletVisitGlyph;
import 'package:tradeiq_app/l10n/l10n.dart';

import '../agent_harness.dart' show loadAgentFonts;

/// THE PIN VOCABULARY, ASSERTED AND PHOTOGRAPHED.
///
/// The agent map draws four states, the manager's territory map draws two, and
/// two of the four are the same fact about the same shop: *this one is done*
/// and *this one is still to do*. On 29 September 2026 the owner said of the
/// agent map:
///
/// > "This is not it, the map is not good. there's still a lot of rectangular
/// > and not matching with the manager side"
///
/// with the earlier instruction still standing:
///
/// > "make them align and don't change the manager side, it looks perfect"
///
/// So the alignment is a **test** rather than a claim. Two of the agent's four
/// marks are now rendered to the same pixels as the manager's two, and no mark
/// in the set draws a rectangle at all. The manager's `_VisitPinPainter` is the
/// source of truth and did not move; it is the agent's painter that came to it.
///
/// The gated half of the file draws the whole vocabulary — both skins, on the
/// map's dark ground and on a row's surface, beside the manager's — as one
/// sheet somebody can look at:
///
/// ```sh
/// PIN_LOOK=1 PIN_LOOK_DIR=/somewhere/ flutter test \
///   test/features/agent_map/pin_vocabulary_test.dart --update-goldens
/// ```
///
/// **The trailing slash is load-bearing**, as it is in every look test here.
/// It does not run in CI for the reason `floor_look_test.dart` gives: CI
/// rasterises anti-aliased Onest differently to macOS, so a pixel comparison
/// on the image fails within a week. The assertions above it run everywhere.
void main() {
  final looking = Platform.environment['PIN_LOOK'] == '1';
  final dir = Platform.environment['PIN_LOOK_DIR'] ?? 'goldens/';

  setUpAll(loadAgentFonts);

  // ─────────────────────────────────────────── the same mark, both sides ──

  for (final (skinName, skin) in _skins) {
    for (final onDarkGround in <bool>[true, false]) {
      final where = onDarkGround ? 'on the map' : 'in a row';

      testWidgets(
        '$skinName, $where: "visited today" is the manager\'s "visited", '
        'to the pixel',
        (tester) async {
          final agent = await _shootGlyph(
            tester,
            skin: skin,
            child: MapPinGlyph(
              pin: _pin(MapPinState.doneToday),
              size: _size,
              onDarkGround: onDarkGround,
            ),
          );
          final manager = await _shootGlyph(
            tester,
            skin: skin,
            child: OutletVisitGlyph(
              visited: true,
              size: _size,
              onDarkGround: onDarkGround,
            ),
          );
          expect(agent, manager);
        },
      );

      testWidgets(
        '$skinName, $where: "on today\'s route" is the manager\'s '
        '"outstanding", to the pixel',
        (tester) async {
          final agent = await _shootGlyph(
            tester,
            skin: skin,
            child: MapPinGlyph(
              pin: _pin(MapPinState.plannedAhead),
              size: _size,
              onDarkGround: onDarkGround,
            ),
          );
          final manager = await _shootGlyph(
            tester,
            skin: skin,
            child: OutletVisitGlyph(
              visited: false,
              size: _size,
              onDarkGround: onDarkGround,
            ),
          );
          expect(agent, manager);
        },
      );
    }
  }

  // ──────────────────────────────────────────────── and nothing squared ──

  // The owner's complaint, as an assertion. "In your patch" was a square
  // outline and it is the most numerous pin on the screen — about thirty of
  // them over a patch — which made it the largest single source of rectangle
  // left in the app. No state may bring one back, and the barred "under
  // review" form of each state may not either.
  for (final state in MapPinState.values) {
    for (final disputed in <bool>[false, true]) {
      testWidgets(
        'the ${state.name} pin draws no rectangle'
        '${disputed ? ', barred' : ''}',
        (tester) async {
          await _pumpOne(
            tester,
            skin: TiqSkin.night(),
            child: MapPinGlyph(
              pin: _pin(state, disputed: disputed),
              size: _size,
              onDarkGround: true,
            ),
          );
          expect(
            find.byType(MapPinGlyph),
            paintsExactlyCountTimes(#drawRect, 0),
          );
          expect(
            find.byType(MapPinGlyph),
            paintsExactlyCountTimes(#drawRRect, 0),
          );
        },
      );
    }
  }

  // ───────────────────────────────────────────────────────── the sheet ──

  testWidgets('the vocabulary sheet', (tester) async {
    tester.view
      ..physicalSize = _sheet
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.torchlight(TiqSkin.night()),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: _boundary,
          child: SizedBox.fromSize(
            size: _sheet,
            child: Row(
              children: <Widget>[
                for (final (name, skin) in _skins)
                  Expanded(child: _SkinColumn(name: name, skin: skin)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(_boundary),
      matchesGoldenFile('${dir}pin_vocabulary.png'),
    );
  }, skip: !looking);
}

/// The size every mark in this file is drawn at: the 24dp a map marker and a
/// list row both use at 1.0× text.
const double _size = 24;

const Size _sheet = Size(780, 844);

final _boundary = GlobalKey();

List<(String, TiqSkin)> get _skins => <(String, TiqSkin)>[
  ('Night', TiqSkin.night()),
  ('Day', TiqSkin.day()),
];

const _shop = Outlet(
  id: 'o1',
  name: 'Kasi Corner Spaza',
  code: 'KC-0412',
  lat: -26.24,
  lng: 27.858,
);

MapOutlet _pin(MapPinState state, {bool disputed = false}) =>
    MapOutlet(outlet: _shop, state: state, disputed: disputed);

/// Stand one glyph up, alone, on nothing.
///
/// `Colors.transparent` rather than the skin's ground on purpose: two marks
/// are only "the same" if their haloes are the same too, and a ground-coloured
/// halo drawn on a ground-coloured card is invisible to a pixel comparison.
Future<void> _pumpOne(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.torchlight(skin),
      debugShowCheckedModeBanner: false,
      home: Material(
        color: const Color(0x00000000),
        child: Center(
          child: RepaintBoundary(
            key: _one,
            child: SizedBox.square(dimension: _size + 8, child: Center(child: child)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _one = GlobalKey();

/// The PNG of one glyph, for comparing against another one.
Future<Uint8List> _shootGlyph(
  WidgetTester tester, {
  required TiqSkin skin,
  required Widget child,
}) async {
  await _pumpOne(tester, skin: skin, child: child);
  final boundary =
      _one.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 4);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// One skin's half of the sheet.
class _SkinColumn extends StatelessWidget {
  const _SkinColumn({required this.name, required this.skin});

  final String name;
  final TiqSkin skin;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.torchlight(skin),
      child: Builder(
        builder: (context) {
          final l10n = context.l10n;
          final p = skin.palette;
          return Material(
            color: p.ground,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: skin.text.titleM.style(color: p.ink1)),
                  const SizedBox(height: 12),
                  _Block(
                    skin: skin,
                    heading: 'On the map',
                    fill: p.ground,
                    onDarkGround: true,
                    l10n: l10n,
                  ),
                  const SizedBox(height: 16),
                  _Block(
                    skin: skin,
                    heading: 'In a row',
                    fill: p.surface,
                    onDarkGround: false,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The whole vocabulary once, on one ground.
class _Block extends StatelessWidget {
  const _Block({
    required this.skin,
    required this.heading,
    required this.fill,
    required this.onDarkGround,
    required this.l10n,
  });

  final TiqSkin skin;
  final String heading;
  final Color fill;
  final bool onDarkGround;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final p = skin.palette;
    Widget line(Widget glyph, String word) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          SizedBox.square(dimension: 28, child: Center(child: glyph)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(word, style: skin.text.meta.style(color: p.ink2)),
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(skin.radii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              heading.toUpperCase(),
              style: skin.text.eyebrow.style(color: p.ink3),
            ),
            const SizedBox(height: 10),
            for (final state in MapPinState.values)
              line(
                MapPinGlyph(
                  pin: _pin(state),
                  size: _size,
                  onDarkGround: onDarkGround,
                ),
                mapStateWord(l10n, state),
              ),
            line(
              MapPinGlyph(
                pin: _pin(MapPinState.territory, disputed: true),
                size: _size,
                onDarkGround: onDarkGround,
              ),
              l10n.mapStateDisputed,
            ),
            const SizedBox(height: 6),
            Text(
              'MANAGER',
              style: skin.text.eyebrow.style(color: p.ink3),
            ),
            const SizedBox(height: 10),
            line(
              OutletVisitGlyph(
                visited: true,
                size: _size,
                onDarkGround: onDarkGround,
              ),
              l10n.territoryOutletVisited,
            ),
            line(
              OutletVisitGlyph(
                visited: false,
                size: _size,
                onDarkGround: onDarkGround,
              ),
              l10n.territoryOutletNotVisited,
            ),
          ],
        ),
      ),
    );
  }
}
