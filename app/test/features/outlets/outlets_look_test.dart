import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlets_list_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../agent_harness.dart' show loadAgentFonts;
import '../operations_harness.dart';

/// STORES, RENDERED, SO SOMEBODY CAN LOOK AT THE TERRITORY CHIP.
///
/// Every other test in this folder asserts a number. This one produces the
/// six images the owner and the reviewer compare: three states in **both**
/// skins at 390×844, with Onest and JetBrains Mono loaded. The test font is
/// wider than Onest, so a screen rendered in it wraps sooner and measures
/// taller — a picture of the wrong screen.
///
/// The three states are the three answers the chip can give:
///
/// | state | what it has to get right |
/// |---|---|
/// | `unscoped` | the chip reading "All territories", unselected, above the list it does not narrow — and the pin report note with nothing added to it |
/// | `scoped` | the chip wearing a territory's NAME and the selected treatment, the shorter list beneath it, and the queue saying in words that it is not narrowed |
/// | `scoped-empty` | a territory with no stores: the silhouette, the territory named in the headline, and "Show all territories" as the way out — never "No stores yet" over an account that has plenty |
///
/// The third is the one that has to be looked at rather than measured. It is
/// the state the owner's complaint produces once the filter works, and a
/// filtered-to-nothing list that reads as an empty account is how a manager
/// concludes the product lost their data.
///
/// Day is not a courtesy. The selected chip is a fill step plus a tick, and a
/// fill step on a pale ground is a different amount of evidence than one on a
/// near-black one — §1.6's four channels have to survive both.
///
/// ## Why it does not run in CI
///
/// The reason `floor_look_test.dart` and `tasks_look_test.dart` give: CI
/// rasterises anti-aliased Onest on `ubuntu-latest` and this repository is
/// developed on macOS, so a pixel comparison fails on the day it lands and is
/// skipped within a week. The images are an artefact to *look at*; the pins
/// are the assertions in `outlets_list_screen_test.dart`, which do run
/// everywhere.
///
/// ```sh
/// OUTLETS_LOOK=1 OUTLETS_LOOK_DIR=/somewhere/ flutter test \
///   test/features/outlets/outlets_look_test.dart --update-goldens
/// ```
///
/// `OUTLETS_LOOK_DIR` needs its trailing slash: the path is written
/// `${dir}name.png`, with no separator of its own.
void main() {
  final looking = Platform.environment['OUTLETS_LOOK'] == '1';
  final dir = Platform.environment['OUTLETS_LOOK_DIR'] ?? 'goldens/';

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
  });

  const territories = <Territory>[
    Territory(
      id: 't-gp-tsh',
      name: 'Gauteng North (Tshwane)',
      code: 'GP-TSH',
      region: 'Gauteng',
    ),
    Territory(id: 't-wc-cpt', name: 'Western Cape', code: 'WC-CPT'),
    Territory(id: 't-kzn', name: 'KwaZulu-Natal Coastal', code: 'KZN-DBN'),
  ];

  /// The whole account. One of them has no coordinates, because the figure at
  /// the head of this screen exists to count exactly that.
  final everywhere = <Outlet>[
    opsOutlet('o1', 'Shoprite Klipspruit Mall', code: 'SKM-001'),
    opsOutlet('o2', 'Kasi Corner Spaza', code: 'KCS-014', lat: 0, lng: 0),
    opsOutlet('o3', 'Pick n Pay Rosebank', code: 'PNP-207'),
    opsOutlet('o4', 'SaveMor Glenwood', code: 'SMG-042'),
    opsOutlet('o5', 'Corner Express Parkhurst', code: 'CEP-118'),
    opsOutlet('o6', 'Boxer Superstore Tembisa', code: 'BST-330'),
  ];

  /// Tshwane's three — the answer to "only show the store on that territory".
  final tshwane = <Outlet>[
    opsOutlet('o1', 'Shoprite Klipspruit Mall', code: 'SKM-001'),
    opsOutlet('o2', 'Kasi Corner Spaza', code: 'KCS-014', lat: 0, lng: 0),
    opsOutlet('o3', 'Pick n Pay Rosebank', code: 'PNP-207'),
  ];

  final dispute = PinDispute(
    id: 'd1',
    outletId: 'o2',
    outletName: 'Kasi Corner Spaza',
    outletCode: 'KCS-014',
    visitId: 'v1',
    agentLabel: 'Thandi Mokoena',
    lat: -26.2114,
    lng: 28.0493,
    distanceM: 8400,
    outletLat: 0,
    outletLng: 0,
    note: null,
    status: 'open',
    resolvedByLabel: null,
    resolvedAt: null,
    accuracyM: 12,
    isMocked: false,
    createdAt: DateTime.utc(2026, 9, 18, 7),
    agentIsOnlyVisitor: false,
    photos: const <PinDisputePhoto>[],
  );

  Future<void> pump(
    WidgetTester tester, {
    required TiqSkin skin,
    required List<Outlet> outlets,
    Map<String, List<Outlet>> byTerritory = const <String, List<Outlet>>{},
    String? territoryId,
  }) => pumpOperations(
    tester,
    const OutletsListScreen(),
    skin: skin,
    size: const Size(390, 844),
    overrides: <Override>[
      outletsRepositoryProvider.overrideWithValue(
        FakeOpsOutletsRepository(outlets: outlets, byTerritory: byTerritory),
      ),
      outletAdminRepositoryProvider.overrideWithValue(
        FakeOutletAdminRepository(disputes: <PinDispute>[dispute]),
      ),
      territoriesListProvider.overrideWith((ref) async => territories),
      dashboardFilterProvider.overrideWith(() => _ScopedFilter(territoryId)),
    ],
  );

  const skins = <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ];

  TiqSkin console(SkinMode mode) => mode == SkinMode.night
      ? TiqSkin.night(density: TiqDensity.console)
      : TiqSkin.day(density: TiqDensity.console);

  for (final (name, mode) in skins) {
    // ── 1. Nothing chosen ────────────────────────────────────────────────
    testWidgets('Stores — every territory, $name', (tester) async {
      await pump(tester, skin: console(mode), outlets: everywhere);

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}outlets_390x844-unscoped-$name.png'),
      );
    }, skip: !looking);

    // ── 2. One territory, with stores in it ──────────────────────────────
    //
    // The owner's sentence, as a picture: the chip names Tshwane and wears
    // the selected treatment, and the list under it is Tshwane's three rather
    // than the account's six.
    testWidgets('Stores — one territory, $name', (tester) async {
      await pump(
        tester,
        skin: console(mode),
        outlets: everywhere,
        byTerritory: <String, List<Outlet>>{'t-gp-tsh': tshwane},
        territoryId: 't-gp-tsh',
      );

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}outlets_390x844-scoped-$name.png'),
      );
    }, skip: !looking);

    // ── 3. One territory, with nothing in it ─────────────────────────────
    //
    // A DESIGNED state, not a blank screen. The account still has six stores;
    // this territory has none, and the difference has to be legible at a
    // glance or the manager reads it as lost data.
    testWidgets('Stores — a territory with none, $name', (tester) async {
      await pump(
        tester,
        skin: console(mode),
        outlets: everywhere,
        territoryId: 't-wc-cpt',
      );

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}outlets_390x844-scoped-empty-$name.png'),
      );
    }, skip: !looking);

    // ── 3b. The same state, at its foot ──────────────────────────────────
    //
    // `EmptyState` is left-aligned and top-anchored so that it grows DOWNWARD
    // into the scroll that already exists (rather than pushing its own action
    // off the bottom, which is what a centred block does at 2.0×). On a
    // 390×844 handset, under the chip, the lead figure and the pin report
    // queue, that puts the sentence and the way out just past the fold. This
    // is the half a reader scrolls to, and the half that has to say something
    // useful — so it gets looked at rather than assumed.
    testWidgets('Stores — a territory with none, scrolled, $name', (
      tester,
    ) async {
      await pump(
        tester,
        skin: console(mode),
        outlets: everywhere,
        territoryId: 't-wc-cpt',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('outlets-clear-territory')),
        120,
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}outlets_390x844-scoped-empty-foot-$name.png'),
      );
    }, skip: !looking);
  }
}

/// The scope, already narrowed. `pumpOperations` stands the screen up without
/// tapping anything, so the state is set rather than chosen — what is being
/// looked at is the scoped SCREEN, not the gesture that scoped it.
class _ScopedFilter extends DashboardFilterNotifier {
  _ScopedFilter(this.territoryId);

  final String? territoryId;

  @override
  DashboardFilter build() => DashboardFilter(territoryId: territoryId);
}

/// Material's icon font, so the refresh glyph in the header is a glyph and not
/// a tofu box. Same loader `tasks_look_test.dart` carries.
Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader('MaterialIcons')
        ..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer))))
      .load();
}
