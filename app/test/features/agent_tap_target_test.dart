/// THE FLOOR THAT DOES NOT MOVE — 44dp, on every agent row, at 1.0× and 1.3×.
///
/// The 4 October 2026 density pass brought the agent side to the manager's
/// numbers: the header's floor 96 → 72, a stat tile's inset 20 → 16 and its
/// floor 96 → 88, a chip's visual height 32 → 28, a meter's track 6 → 4, and
/// every agent list row from `SoftRowDensity.standard` (64) to `compact` (56),
/// which `held_work_row.dart` calls *"the console's list height"*.
///
/// > *"A row may come down from 85dp to the manager's 44–48dp; it may not go
/// > under 44. If tightening something would breach that, stop at 44 and say
/// > so."*
///
/// **Nothing in that pass went near 44 and this file is how that is known
/// rather than asserted.** It measures the real laid-out rect of every
/// tappable row on the agent screens that changed, at the default text size
/// and at 1.3×, and fails with the screen, the row and the number.
///
/// WHY 1.3× AND NOT ONLY 1.0×. A row's height is a floor, not a height: at
/// 1.3× the text grows and the row grows with it, so 1.3× is the *safe*
/// direction and 1.0× is where a floor breach would show. Both are measured
/// anyway, because the thing that could have broken at 1.3× is the **leading
/// lane** — `compact` reserves 28dp for a glyph tile against `standard`'s 40,
/// and `MarkScale.tile` grows 28 → 48 across the scale range. A lane that
/// stopped fitting its own tile would be an overflow, not a short row, so the
/// test pumps at both and lets the framework's own overflow detection speak.
///
/// WHAT IS DELIBERATELY NOT HERE. `torchTapTarget` holds a text or glyph
/// action at 48 on both surfaces and is untouched by this change; the chip's
/// hit box reads `skin.space.tapTarget` and never `TiqChip.visualHeight`, so
/// shrinking the pill moved no target. Those two are asserted where they live.
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/features/audit/presentation/visit_outlet_picker_screen.dart';
import 'package:tradeiq_app/features/beatplans/data/today_route.dart';
import 'package:tradeiq_app/features/beatplans/presentation/today_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import 'agent_harness.dart';
import 'audit/visit_harness.dart';

/// THE FLOOR. `TiqSpace.console.tapTarget` and `TiqSpace.field.tapTarget` are
/// both 44 and have been since 29 September 2026; it is read off the skin
/// rather than written here so that a scale change fails this file instead of
/// passing it with a stale constant.
double _floor(TiqSkin skin) => skin.space.tapTarget;

/// Every tappable [SoftRow] in the pumped frame, measured, against the floor.
///
/// A row with no `onTap` is excluded: it is a line of text, not a target, and
/// the score row on the visit hub is deliberately one of those.
///
/// [bringIntoView] is scrolled to first, and on these screens it is not
/// optional at 1.3×. **The agent body is one lazy viewport**, so a row below
/// the fold is not merely unseen, it is unmounted — and measuring an unmounted
/// row is measuring nothing. The first cut of this file asserted against
/// `find.byType(SoftRow)` at rest and passed at 1.0× while finding **zero
/// rows** at 1.3× on both the store picker and Today, which is how the
/// `measured > 0` guard below came to exist: without it, the two cases this
/// file was written for would have reported green on an empty list.
///
/// That the first row is past the fold at 1.3× on a 360×640 phone is a fact
/// about the screen and **not** something this change introduced — it is the
/// same on `origin/main`, verified. The density pass moves it closer to the
/// fold (there is 12–24dp less chrome above it) without bringing it inside.
Future<void> expectEveryRowClearsTheFloor(
  WidgetTester tester, {
  required String screen,
  required double textScale,
  required Finder bringIntoView,
}) async {
  // Mount the list before measuring it. See the doc above: a lazy viewport
  // unmounts what is past the fold, and at 1.3x that is the first row.
  await scrollAgentTo(tester, bringIntoView);
  final skin = agentSkinFor(SkinMode.day);
  final floor = _floor(skin);
  final rows = find.byType(SoftRow);
  final breaches = <String>[];
  var measured = 0;

  for (final element in rows.evaluate()) {
    final row = element.widget as SoftRow;
    if (row.onTap == null) continue;
    final height = tester.getRect(find.byWidget(row)).height;
    measured++;
    if (height < floor) {
      breaches.add('"${row.title}" is ${height.toStringAsFixed(1)}dp');
    }
  }

  expect(
    breaches,
    isEmpty,
    reason:
        '$screen at ${textScale}x: ${breaches.length} tappable row(s) under '
        'the ${floor}dp floor — ${breaches.join(', ')}. An agent works '
        'one-handed outdoors, often in sunlight; 44 is the WCAG 2.5.5 floor '
        'and the density pass is not allowed to spend it.',
  );

  // A test that measured nothing is a test that passes for the wrong reason —
  // and this one would, because `find.byType(SoftRow)` on a screen whose list
  // failed to load is an empty list.
  expect(
    measured,
    greaterThan(0),
    reason:
        '$screen at ${textScale}x: no tappable rows were found, so nothing '
        'was measured. The fixture is not rendering its list.',
  );
}

const _khumalo = Outlet(
  id: 'o1',
  name: 'Khumalo Superette',
  code: 'KS-014',
  lat: -26.2,
  lng: 28.0,
);
const _sunrise = Outlet(
  id: 'o2',
  name: 'Sunrise Spaza',
  code: 'SS-221',
  lat: -26.3,
  lng: 28.1,
);

final _route = TodayRoute(
  planName: 'Naledi · Soweto East',
  hasLocation: true,
  stops: <RouteStop>[
    const RouteStop(
      sequence: 1,
      outlet: _khumalo,
      visited: true,
      distanceMeters: 1200,
    ),
    const RouteStop(
      sequence: 2,
      outlet: _sunrise,
      visited: false,
      distanceMeters: 420,
    ),
  ],
);

class _TwoStores implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    String? territoryId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse<Outlet>(
    data: <Outlet>[_khumalo, _sunrise],
    nextCursor: null,
  );

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) => throw UnimplementedError();
}

void main() {
  // Day first — it is the agent's default. The floor is a geometry fact and
  // does not differ by skin, so one skin is measured and the other is
  // asserted equal by `agent_density_table_test.dart`'s declared table.
  for (final scale in <double>[1.0, 1.3]) {
    group('${scale}x', () {
      testWidgets('Today: every stop row clears the floor', (tester) async {
        final db = agentTestDb();
        await pumpAgentScreen(
          tester,
          const TodayScreen(),
          textScale: scale,
          overrides: <Override>[
            ...agentBaseOverrides(db: db, skin: SkinMode.day),
            todayRouteProvider.overrideWith((ref) async => _route),
          ],
        );
        await expectEveryRowClearsTheFloor(
          tester,
          screen: 'Today',
          textScale: scale,
          bringIntoView: find.text('Sunrise Spaza'),
        );
      });

      testWidgets('the store picker: every store row clears the floor', (
        tester,
      ) async {
        await pumpAgentScreen(
          tester,
          const VisitOutletPickerScreen(),
          path: '/audit',
          textScale: scale,
          overrides: <Override>[
            ...agentBaseOverrides(db: agentTestDb(), skin: SkinMode.day),
            outletsRepositoryProvider.overrideWithValue(_TwoStores()),
          ],
        );
        await expectEveryRowClearsTheFloor(
          tester,
          screen: 'the store picker',
          textScale: scale,
          bringIntoView: find.text('Sunrise Spaza'),
        );
      });

      testWidgets('the visit hub: every section rung clears the floor', (
        tester,
      ) async {
        await pumpVisit(
          tester,
          visits: ScriptedVisits.succeeds(),
          progress: readyToSubmit,
          skin: SkinMode.day,
          textScale: scale,
        );
        await expectEveryRowClearsTheFloor(
          tester,
          screen: 'the visit hub',
          textScale: scale,
          bringIntoView: find.byType(SoftRow).last,
        );
      });
    });
  }

  // THE NUMBER, PRINTED. The assertion above says "nothing breached"; this
  // says what the margin actually is, because "it clears 44" and "it clears 44
  // by 30dp" are different facts about how much room the next density pass
  // has. It is a print beside an assertion, never instead of one.
  testWidgets('the margin above the floor, measured and printed', (
    tester,
  ) async {
    await pumpAgentScreen(
      tester,
      const VisitOutletPickerScreen(),
      path: '/audit',
      overrides: <Override>[
        ...agentBaseOverrides(db: agentTestDb(), skin: SkinMode.day),
        outletsRepositoryProvider.overrideWithValue(_TwoStores()),
      ],
    );
    await scrollAgentTo(tester, find.text('Sunrise Spaza'));
    final skin = agentSkinFor(SkinMode.day);
    final heights = find
        .byType(SoftRow)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).height)
        .toList();
    final shortest = heights.reduce((a, b) => a < b ? a : b);
    // ignore: avoid_print
    print(
      'STORE PICKER ROWS: ${heights.map((h) => h.toStringAsFixed(0)).join(' ')}'
      ' — shortest ${shortest.toStringAsFixed(0)}dp against a '
      '${skin.space.tapTarget}dp floor '
      '(${(shortest - skin.space.tapTarget).toStringAsFixed(0)}dp of margin)',
    );
    expect(shortest, greaterThanOrEqualTo(skin.space.tapTarget));
  });
}
