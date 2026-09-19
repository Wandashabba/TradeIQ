import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s1_outlet_info_screen.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

void main() {
  testWidgets('confirms the check-in, read-only: the time, the geofence pass '
      'as a glyph and a word, and no Save', (tester) async {
    await pumpSection(
      tester,
      S1OutletInfoScreen(checkinTs: DateTime(2026, 9, 19, 7, 58)),
    );
    expect(find.text('Confirmed at check-in'), findsOneWidget);
    expect(find.text('2026-09-19 07:58'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.byType(SectionStateGlyph), findsOneWidget);
    // Nothing to commit, so nothing offers to commit it.
    expect(sectionSave, findsNothing);
    await disposeAgentScreen(tester);
  });

  testWidgets('degrades honestly when no check-in timestamp is present', (
    tester,
  ) async {
    await pumpSection(tester, const S1OutletInfoScreen());
    expect(find.text('Not recorded'), findsOneWidget);
    await disposeAgentScreen(tester);
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('nothing is armed, so nothing is lit — ${skin.name}', (
        tester,
      ) async {
        await pumpSection(
          tester,
          S1OutletInfoScreen(checkinTs: DateTime(2026, 9, 19, 7, 58)),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'outlet info',
          phase: 'read-only',
          expected: 0,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
