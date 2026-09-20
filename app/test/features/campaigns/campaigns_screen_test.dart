import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';
import 'package:tradeiq_app/features/campaigns/presentation/campaign_return_view.dart';
import 'package:tradeiq_app/features/campaigns/presentation/campaigns_screen.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';
import 'campaigns_fakes.dart';

Future<FakeCampaignsRepository> _pump(
  WidgetTester tester, {
  FakeCampaignsRepository? repo,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeCampaignsRepository();
  await pumpConsole(
    tester,
    const CampaignsScreen(),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: settle,
    path: '/campaigns',
    overrides: <Override>[
      campaignsRepositoryProvider.overrideWithValue(fake),
      sessionAs('manager'),
    ],
  );
  return fake;
}

void main() {
  group('the list', () {
    testWidgets('a row names the campaign and carries its id in mono', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Summer Push'), findsOneWidget);
      expect(find.text('12 outlets · 2026-06-01 → 2026-08-31'), findsOneWidget);
      // The id is machine-facing and lives on the meta line; it is never the
      // title of a row.
      expect(find.text('c1'), findsOneWidget);
      final row = tester.widget<SoftRow>(keyed('campaign-c1'));
      expect(row.title, 'Summer Push');
    });

    testWidgets('a status is a word and a silhouette', (tester) async {
      await _pump(tester);
      final chips = tester
          .widgetList<StatusChip>(find.byType(StatusChip))
          .toList();
      expect(chips.map((c) => c.label), containsAll(<String>['Active', 'Draft']));
      // Neither is a severity: running normally is not a verdict.
      expect(
        chips.every((c) => c.level == StatusLevel.held),
        isTrue,
        reason: 'levels were ${chips.map((c) => c.level)}',
      );
    });

    testWidgets('a paused campaign wants a decision; a cancelled one is a '
        'finding', (tester) async {
      await _pump(
        tester,
        repo: FakeCampaignsRepository(
          campaigns: const <Campaign>[
            Campaign(
              id: 'p',
              name: 'Paused',
              status: 'paused',
              startDate: '2026-01-01',
              endDate: '2026-02-01',
              outletCount: 1,
            ),
            Campaign(
              id: 'x',
              name: 'Scrapped',
              status: 'cancelled',
              startDate: '2026-01-01',
              endDate: '2026-02-01',
              outletCount: 1,
            ),
          ],
        ),
      );
      expect(campaignLevel('paused'), StatusLevel.watch);
      expect(campaignLevel('cancelled'), StatusLevel.critical);
      expect(find.text('Paused'), findsWidgets);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('the row verbs are nodes, not only pixels', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(find.bySemanticsLabel('Edit'), findsWidgets);
      handle.dispose();
    });

    testWidgets('New campaign opens the form', (tester) async {
      await _pump(tester);
      await scrollConsoleTo(tester, keyed('campaign-create'));
      await tester.tap(keyed('campaign-create'));
      await tester.pumpAndSettle();
      expect(find.text('New campaign'), findsWidgets);
    });
  });

  group('the rollup sheet', () {
    testWidgets('a row opens coverage, compliance and return', (tester) async {
      final repo = await _pump(tester);
      await tester.tap(find.text('Summer Push'));
      await tester.pumpAndSettle();

      expect(find.byType(TorchSheet), findsOneWidget);
      expect(repo.calls, containsAll(<String>['compliance:c1', 'roi:c1']));
      expect(find.text('Coverage'), findsOneWidget);
      expect(find.text('Compliance'), findsOneWidget);

      // Figures through the one formatter: a percent sign, never a
      // `toStringAsFixed` and never an en_US group mark.
      expect(find.textContaining('75.0', findRichText: true), findsOneWidget);
      expect(find.textContaining('88.5', findRichText: true), findsOneWidget);

      await scrollSheetTo(tester, find.byType(CampaignReturnView));
      expect(find.text('Return'), findsOneWidget);
      expect(find.byType(CampaignReturnView), findsOneWidget);
    });

    testWidgets('a failed return does not hide the compliance rollup', (
      tester,
    ) async {
      await _pump(tester, repo: FakeCampaignsRepository(roiFailure: offline()));
      await tester.tap(find.text('Summer Push'));
      await tester.pumpAndSettle();

      expect(find.text('Coverage'), findsOneWidget);
      expect(keyed('return-error'), findsOneWidget);
      // Sanitised: the exception's own text never reaches a screenshot.
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });

    testWidgets('a failed compliance does not hide the return', (tester) async {
      await _pump(
        tester,
        repo: FakeCampaignsRepository(complianceFailure: offline()),
      );
      await tester.tap(find.text('Summer Push'));
      await tester.pumpAndSettle();

      expect(keyed('compliance-error'), findsOneWidget);
      await scrollSheetTo(tester, find.byType(CampaignReturnView));
      expect(find.byType(CampaignReturnView), findsOneWidget);
    });

    testWidgets('each region loads on its own', (tester) async {
      await _pump(tester, repo: FakeCampaignsRepository(roiPending: true));
      await tester.tap(find.text('Summer Push'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Coverage'), findsOneWidget);
      expect(keyed('return-loading'), findsOneWidget);
    });
  });

  group('the return: unmeasurable is not zero', () {
    Future<void> openReturn(WidgetTester tester, CampaignRoi roi) async {
      await _pump(tester, repo: FakeCampaignsRepository(roi: roi));
      await tester.tap(find.text('Summer Push'));
      await tester.pumpAndSettle();
      await scrollSheetTo(tester, find.byType(CampaignReturnView));
    }

    testWidgets('a positive return is a figure and a word', (tester) async {
      await openReturn(tester, roiOf());
      expect(keyed('roi-headline'), findsOneWidget);
      expect(find.textContaining('+25.5', findRichText: true), findsOneWidget);
      expect(find.text('Positive return'), findsOneWidget);
    });

    testWidgets('a negative return carries a minus and the word', (
      tester,
    ) async {
      await openReturn(tester, roiOf(roiPct: -12.5, attributed: 20000));
      expect(find.textContaining('−12.5', findRichText: true), findsOneWidget);
      expect(find.text('Negative return'), findsOneWidget);
    });

    testWidgets('no budget names its reason and shows no chip at all', (
      tester,
    ) async {
      await openReturn(
        tester,
        roiOf(spend: null, roiPct: null, unmeasurable: 'no_budget'),
      );
      expect(keyed('roi-unmeasurable'), findsOneWidget);
      expect(find.text("No budget set — return can't be measured."),
          findsOneWidget);
      // Never 0%, never ∞, and never a grey "Unknown" chip — a chip is a
      // claim that the system looked and decided.
      expect(keyed('roi-headline'), findsNothing);
      expect(keyed('roi-status'), findsNothing);
      // A spend that was never recorded is an em dash, not a zero.
      expect(find.textContaining(emDash, findRichText: true), findsWidgets);
    });

    testWidgets('a zero budget names its own reason', (tester) async {
      await openReturn(
        tester,
        roiOf(spend: 0, roiPct: null, unmeasurable: 'zero_budget'),
      );
      expect(find.text("Budget is zero — return can't be measured."),
          findsOneWidget);
    });

    testWidgets('the sell-in caveat is always on screen', (tester) async {
      await openReturn(tester, roiOf());
      expect(keyed('roi-caveat'), findsOneWidget);
      expect(find.textContaining('Sell-in, not shopper sales'), findsOneWidget);
    });
  });

  group('the states', () {
    testWidgets('empty is a designed state, not a centred "No data"', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeCampaignsRepository(campaigns: const <Campaign>[]),
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No campaigns yet.'), findsOneWidget);
      expect(find.byType(SectionRule), findsOneWidget);
      expect(find.byType(SoftRow), findsNothing);
    });

    testWidgets('loading is a skeleton, and nothing before 600ms', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeCampaignsRepository(listPending: true),
        settle: false,
      );
      expect(find.byType(SkeletonRows), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await _pump(tester, repo: FakeCampaignsRepository(listFailure: offline()));
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(keyed('campaigns-retry'), findsOneWidget);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final lit = skin.mode == SkinMode.night ? 1 : 0;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(t, skin: skin),
        'empty': (t) => _pump(
          t,
          skin: skin,
          repo: FakeCampaignsRepository(campaigns: const <Campaign>[]),
        ),
        'loading': (t) async {
          await _pump(
            t,
            skin: skin,
            repo: FakeCampaignsRepository(listPending: true),
            settle: false,
          );
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          repo: FakeCampaignsRepository(listFailure: offline()),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'campaigns',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }

      testWidgets('${skin.mode.name}, the rollup sheet: 0', (tester) async {
        await _pump(tester, skin: skin);
        await tester.tap(find.text('Summer Push'));
        await tester.pumpAndSettle();
        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'while a sheet is up every amber on the route beneath goes '
              'out, and the sheet itself has no commit.\n${census.describe()}',
        );
      });
    }
  });

  group('2.0x text and Afrikaans lengths', () {
    testWidgets('the list survives and nothing overflows', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('campaign-c2'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rollup sheet survives at 2.0x', (tester) async {
      await _pump(tester, textScale: 2.0, locale: const Locale('af'));
      await tester.tap(find.text('Summer Push'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollSheetTo(tester, find.byType(CampaignReturnView));
      expect(tester.takeException(), isNull);
    });
  });
}
