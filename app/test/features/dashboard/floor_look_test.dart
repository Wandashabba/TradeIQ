import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/dashboard/presentation/the_floor_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/trends/data/trends_repository.dart';

import '../agent_harness.dart';
import 'floor_harness.dart';

/// THE FLOOR, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// Every other test in this folder asserts a number. This one produces the
/// two images the owner and the reviewer compare against the mockup: a
/// 390×844 phone and a 360×640 one, populated, with the seeded rainbow shelf
/// fixture on the plate and **Onest and JetBrains Mono loaded**. The test
/// font is wider than Onest, so a screen rendered in it wraps sooner and
/// measures taller — a picture of the wrong screen.
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
void main() {
  final looking = Platform.environment['FLOOR_LOOK'] == '1';

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

  for (final (name, size) in <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
  ]) {
    testWidgets('The Floor at $name, populated, Night x Console', (
      tester,
    ) async {
      await pumpFloor(
        tester,
        const TheFloorScreen(),
        size: size,
        plateImage: await SyncImage.seededShelf(tester),
        // The owner's figures: health 73 against 92, availability 61.
        current: kpis(osa: 61, execution: 73, priceCompliance: 74),
        previous: kpis(osa: 64, execution: 92),
        alerts: decisions,
        outlets: outlets,
        extraOverrides: <Override>[
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
        matchesGoldenFile('goldens/floor_$name.png'),
      );
    }, skip: !looking);
  }
}
