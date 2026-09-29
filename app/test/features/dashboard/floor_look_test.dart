import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/data/dashboard_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';

import '../agent_harness.dart';
import 'floor_harness.dart';

/// THE FLOOR, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// Every other test in this folder asserts a number. This one produces the
/// images the owner and the reviewer compare against the mockup: populated,
/// with a **real committed place image** on the plate and **Onest and
/// JetBrains Mono loaded**. The test font is wider than Onest, so a screen
/// rendered in it wraps sooner and measures taller — a picture of the wrong
/// screen.
///
/// The scoped one is not a luxury: the scope chip wears a heavier name and an
/// `ink1` edge when a territory is chosen, and the picture behind it is of a
/// different place. Both of those are things somebody has to look at.
///
/// ## Day is in the set now, and it should have been from the start
///
/// This harness was Night-only, and the plate's tone was one `#474747`
/// ceiling applied to both skins. The two facts are connected: on paper that
/// ceiling put dark ink over a dark picture at 2.63:1, it was measured and
/// recorded as an open defect in §9g, and **nobody had an image of it to
/// look at**. The tone is per skin as of 29 September 2026 and so is this
/// set.
///
/// Two supplied photographs are rendered beside the generated `ALL`, because
/// a tone is a claim about photographs and the generated ones are the easy
/// case: `FS` is the Bloemfontein townscape and `EC-NMB` is one of the two
/// map composites — a pale near-white polygon with printed town names on it,
/// which is the hardest thing the plate carries.
///
/// ## Why it does not run in CI
///
/// For the reason `soft_row_golden_test.dart` gives for not being a PNG at
/// all: CI rasterises anti-aliased Onest on `ubuntu-latest` and this
/// repository is developed on macOS, so a pixel comparison fails on the day
/// it lands and gets skipped within a week. The images are an artefact to
/// *look at*, not a regression pin — the pins are the measurements in
/// `floor_proportion_test.dart`, which do run everywhere.
///
/// Regenerate them with:
///
/// ```sh
/// FLOOR_LOOK=1 flutter test \
///   test/features/dashboard/floor_look_test.dart --update-goldens
/// ```
///
/// `FLOOR_LOOK_DIR` redirects them somewhere else — a scratch folder to send
/// somebody, without touching the committed set. Same switch
/// `overview_look_test.dart` and `colour_look_test.dart` already carry.
void main() {
  final looking = Platform.environment['FLOOR_LOOK'] == '1';
  final dir = Platform.environment['FLOOR_LOOK_DIR'] ?? 'goldens/';

  setUpAll(loadAgentFonts);

  final outlets = <Outlet>[
    outlet('o1', 'SaveMor Glenwood'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
    outlet('o3', 'Kasi Corner Spaza'),
    outlet('o4', 'Pick n Pay Rosebank'),
    outlet('o5', 'Corner Express Parkhurst'),
  ];

  /// Real messages, including the one the owner quoted: the server writes the
  /// outlet into the sentence and the row prints it as the title, so the
  /// reason has to lose it.
  final decisions = <AlertItem>[
    alert(
      id: 'a1',
      outletId: 'o1',
      photoId: 'p1',
      message: 'Kalahari Cola 2L out of stock at SaveMor Glenwood (6 days)',
      createdAt: DateTime.utc(2026, 9, 16, 9, 6),
    ),
    alert(
      id: 'a2',
      severity: 'warning',
      outletId: 'o2',
      message: 'Price above the published band for the third week running',
      createdAt: DateTime.utc(2026, 9, 16, 12),
    ),
    alert(
      id: 'a3',
      outletId: 'o3',
      message: 'Planogram compliance under 50 percent on the main aisle',
      createdAt: DateTime.utc(2026, 9, 17, 6),
    ),
    alert(
      id: 'a4',
      severity: 'warning',
      outletId: 'o4',
      message: 'Competitor facings doubled since the last visit',
      createdAt: DateTime.utc(2026, 9, 17, 14),
    ),
    alert(
      id: 'a5',
      severity: 'warning',
      outletId: 'o5',
      message: 'Shelf talker missing on the promotional end cap',
      createdAt: DateTime.utc(2026, 9, 18, 8),
    ),
  ];

  // The seed's own generated place images, read off disk. `ALL.jpg` is the
  // whole-footprint view The Floor opens in; `GP-TSH.jpg` is Tshwane, which is
  // what a manager sees after choosing that territory.
  const places = '../backend/assets/places';

  for (final (name, size, place, territory, skin)
      in <(String, Size, String, String?, TiqSkin?)>[
        ('390x844', Size(390, 844), '$places/ALL.jpg', null, null),
        ('360x640', Size(360, 640), '$places/ALL.jpg', null, null),
        ('390x844-scoped', Size(390, 844), '$places/GP-TSH.jpg', 't-gp-tsh', null),
        // ── The same phone in Day, and over the owner's own photographs ──
        ('390x844-day', Size(390, 844), '$places/ALL.jpg', null, _day),
        ('390x844-supplied', Size(390, 844), '$places/FS.jpg', null, null),
        ('390x844-supplied-day', Size(390, 844), '$places/FS.jpg', null, _day),
        ('390x844-map', Size(390, 844), '$places/EC-NMB.jpg', null, null),
        ('390x844-map-day', Size(390, 844), '$places/EC-NMB.jpg', null, _day),
      ]) {
    testWidgets('The Floor at $name, populated', (tester) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        size: size,
        skin: skin,
        territories: territory == null
            ? const <Territory>[]
            : <Territory>[
                Territory(
                  id: territory,
                  name: 'Gauteng North (Tshwane)',
                  code: 'GP-TSH',
                ),
              ],
        coverage: territory == null
            ? const <String, List<Outlet>>{}
            : <String, List<Outlet>>{territory: outlets},
        plateImage: await SyncImage.fromFile(tester, place),
        // The owner's figures: health 73 against 92, availability 61.
        current: kpis(osa: 61, execution: 73, priceCompliance: 74),
        previous: kpis(osa: 64, execution: 92),
        alerts: decisions,
        outlets: outlets,
        extraOverrides: <Override>[
          // The scope is set on the filter rather than by tapping the chip:
          // `pumpFloor` stands the screen up with no Navigator over it, so the
          // scope sheet has nowhere to open. What is being looked at here is
          // the scoped SCREEN — the chip's filtered edge, the Clear beside the
          // health line, and a different place behind them.
          if (territory != null)
            dashboardFilterProvider.overrideWith(
              () => _ScopedFilter(territory),
            ),
          availabilityTrendProvider.overrideWith(
            (ref) async => const <TrendPoint>[
              TrendPoint(period: '2026-W33', value: 71),
              TrendPoint(period: '2026-W34', value: 68),
              TrendPoint(period: '2026-W35', value: 72),
              TrendPoint(period: '2026-W36', value: 66),
              TrendPoint(period: '2026-W37', value: 64),
              TrendPoint(period: '2026-W38', value: 61),
            ],
          ),
        ],
      );

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}floor_$name.png'),
      );
    }, skip: !looking);
  }
}

/// Day at the console density, which is what `pumpFloor` gives Night by
/// default — so the only thing that differs between a `-day` image and its
/// twin is the skin.
///
/// THE DENSITY IS NAMED, and it has to be. `TiqSkin.day()` defaults to
/// **field**, not console — the agent is the one who starts in Day, so the
/// factory's default is written for them — while `TiqSkin.night()` defaults to
/// console. A bare `TiqSkin.day()` here therefore did the opposite of what the
/// sentence above promises: it rendered The Floor, a manager screen, at field
/// density, so every `-day` image differed from its Night twin by the density
/// as well as the skin — field's 64dp rows, 48dp targets and, until
/// 29 September 2026, the field type scale. `tasks_look_test.dart` and
/// `ask_look_test.dart` both name `TiqDensity.console` and were always right;
/// this file was the odd one out. The real route is not affected — The Floor
/// is a `ConsoleTorchlightRoute` and `consoleSkinFor` names the density — so
/// this was a harness fault, and the three `-day` images it produced were of a
/// screen the product never draws.
final TiqSkin _day = TiqSkin.day(density: TiqDensity.console);

/// The filter, already narrowed to one territory. See the override above.
class _ScopedFilter extends DashboardFilterNotifier {
  _ScopedFilter(this.territoryId);

  final String territoryId;

  @override
  DashboardFilter build() => DashboardFilter(territoryId: territoryId);
}
