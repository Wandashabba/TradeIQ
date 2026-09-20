import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';
import 'package:tradeiq_app/features/campaigns/presentation/campaign_return_view.dart';
import 'package:tradeiq_app/features/campaigns/presentation/campaigns_screen.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _campaignA = Campaign(
  id: 'c1',
  name: 'Summer Push',
  status: 'active',
  startDate: '2026-06-01',
  endDate: '2026-08-31',
  outletCount: 12,
  objective: 'visibility',
  budget: 15000,
);

const _campaignB = Campaign(
  id: 'c2',
  name: 'Winter Push',
  status: 'draft',
  startDate: '2026-01-01',
  endDate: '2026-03-31',
  outletCount: 0,
);

const _compliance = CampaignCompliance(
  outletsTotal: 12,
  outletsVisited: 9,
  visitCoverageRate: 75,
  avgPlanogramCompliancePct: 88.5,
  avgAbsPriceDeviationPct: 3.2,
  promoComplianceRate: 91,
);

CampaignRoi _roi({
  double attributed = 42550.5,
  double baseline = 30000,
  double? spend = 10000,
  double? roiPct = 25.5,
  String? unmeasurable,
}) => CampaignRoi.fromJson({
  'campaignId': 'c1',
  'outletsTotal': 12,
  'window': {
    'from': '2026-06-01T00:00:00.000Z',
    'to': '2026-07-01T00:00:00.000Z',
  },
  'baselineWindow': {
    'from': '2026-05-02T00:00:00.000Z',
    'to': '2026-06-01T00:00:00.000Z',
  },
  'orderCount': {'attributed': 40, 'baseline': 31},
  'attributedRevenue': attributed,
  'baselineRevenue': baseline,
  'incrementalRevenue': attributed - baseline,
  'spend': spend,
  'roiPct': roiPct,
  'unmeasurable': unmeasurable,
});

class _FakeCampaignsRepository implements CampaignsRepository {
  _FakeCampaignsRepository({CampaignRoi? roi, this.roiFails = false})
    : roi = roi ?? _roi();

  final CampaignRoi roi;
  final bool roiFails;

  @override
  Future<PaginatedResponse<Campaign>> listCampaigns() async =>
      const PaginatedResponse(data: [_campaignA, _campaignB], nextCursor: null);

  @override
  Future<CampaignCompliance> getCompliance(String id) async => _compliance;

  @override
  Future<CampaignRoi> getRoi(String id) async =>
      roiFails ? throw Exception('roi down') : roi;

  @override
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  }) async => _campaignA;

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async => _campaignA;
}

class _ThrowingCampaignsRepository implements CampaignsRepository {
  @override
  Future<PaginatedResponse<Campaign>> listCampaigns() async =>
      throw Exception('boom');

  @override
  Future<CampaignCompliance> getCompliance(String id) async =>
      throw Exception('boom');

  @override
  Future<CampaignRoi> getRoi(String id) async => throw Exception('boom');

  @override
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  }) async => throw Exception('boom');

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async => throw Exception('boom');
}

Widget _app(CampaignsRepository repo, {ThemeData? theme}) => routedApp(
  const CampaignsScreen(),
  theme: theme,
  overrides: [campaignsRepositoryProvider.overrideWithValue(repo)],
);

void main() {
  testWidgets('renders campaign names once loaded', (tester) async {
    await tester.pumpWidget(_app(_FakeCampaignsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Summer Push'), findsOneWidget);
    expect(find.text('Winter Push'), findsOneWidget);
  });

  testWidgets('tapping a campaign shows its compliance rollup', (tester) async {
    await tester.pumpWidget(_app(_FakeCampaignsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('campaign-c1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('compliance-c1')), findsOneWidget);
  });

  testWidgets('shows an error message when loading fails', (tester) async {
    await tester.pumpWidget(_app(_ThrowingCampaignsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load campaigns'), findsOneWidget);
  });

  testWidgets('light: rows are glass tiles; the rollup lines up mono figures', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeCampaignsRepository(), theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<GlassPane>(
            find
                .ancestor(
                  of: find.text('Summer Push'),
                  matching: find.byType(GlassPane),
                )
                .first,
          )
          .kind,
      GlassKind.tile,
    );

    await tester.tap(find.byKey(const ValueKey<String>('campaign-c1')));
    await tester.pumpAndSettle();

    final rollup = find.byKey(const ValueKey<String>('compliance-c1'));
    expect(rollup, findsOneWidget);
    final coverage = tester.widget<Text>(
      find.descendant(of: rollup, matching: find.text('75.0%')),
    );
    expect(coverage.style?.fontFamily, 'JetBrains Mono');
    expect(find.text('Promo compliance'), findsOneWidget);
  });

  group('return (ROI)', () {
    Future<void> openReturn(
      WidgetTester tester,
      CampaignsRepository repo, {
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(_app(repo, theme: theme ?? AppTheme.light()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('campaign-c1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('roi-c1')), findsOneWidget);
    }

    String pillWord(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('roi-status')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    testWidgets('positive: a mono headline, a good status with its word, and '
        'the figures that make it', (tester) async {
      await openReturn(tester, _FakeCampaignsRepository());

      final headline = tester.widget<Text>(
        find.byKey(const ValueKey<String>('roi-headline')),
      );
      expect(headline.data, '+25.5%');
      expect(headline.style?.fontFamily, LumenGlass.mono);
      expect(
        tester
            .widget<LumenStatusPill>(
              find.byKey(const ValueKey<String>('roi-status')),
            )
            .status,
        LumenStatus.good,
      );
      expect(pillWord(tester), 'POSITIVE RETURN');

      expect(find.text('R 42550.50'), findsOneWidget); // sell-in
      expect(find.text('R 30000.00'), findsOneWidget); // baseline
      expect(find.text('+R 12550.50'), findsOneWidget); // incremental
      expect(find.text('R 10000.00'), findsOneWidget); // spend
      expect(
        find.textContaining('Baseline, prior 30 days', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sell-in during campaign', findRichText: true),
        findsOneWidget,
      );
      // Never relabelled as consumer sales.
      expect(
        find.textContaining(
          RegExp('consumer sales|Revenue', caseSensitive: false),
          findRichText: true,
        ),
        findsNothing,
      );
    });

    testWidgets('negative: a minus headline and a crit status with its word', (
      tester,
    ) async {
      await openReturn(
        tester,
        _FakeCampaignsRepository(
          roi: _roi(attributed: 1000, baseline: 2500, spend: 500, roiPct: -400),
        ),
      );

      expect(find.text('−400.0%'), findsOneWidget);
      expect(
        tester
            .widget<LumenStatusPill>(
              find.byKey(const ValueKey<String>('roi-status')),
            )
            .status,
        LumenStatus.crit,
      );
      expect(pillWord(tester), 'NEGATIVE RETURN');
      expect(find.text('−R 1500.00'), findsOneWidget);
    });

    testWidgets('no budget: the reason, never 0% or infinity', (tester) async {
      await openReturn(
        tester,
        _FakeCampaignsRepository(
          roi: _roi(spend: null, roiPct: null, unmeasurable: 'no_budget'),
        ),
      );

      expect(find.byKey(const ValueKey<String>('roi-headline')), findsNothing);
      expect(
        find.text("No budget set — return can't be measured."),
        findsOneWidget,
      );
      expect(pillWord(tester), 'NOT MEASURED');
      expect(find.text('Not set'), findsOneWidget);
      final roiTexts = find.descendant(
        of: find.byKey(const ValueKey<String>('roi-c1')),
        matching: find.textContaining(RegExp(r'0\.0%|∞|Infinity|NaN')),
      );
      expect(roiTexts, findsNothing);
      // The sell-in figures still show: only the percentage is unmeasurable.
      expect(find.text('R 42550.50'), findsOneWidget);
    });

    testWidgets('zero budget names its own reason', (tester) async {
      await openReturn(
        tester,
        _FakeCampaignsRepository(
          roi: _roi(spend: 0, roiPct: null, unmeasurable: 'zero_budget'),
        ),
      );

      expect(
        find.text("Budget is zero — return can't be measured."),
        findsOneWidget,
      );
      expect(pillWord(tester), 'NOT MEASURED');
    });

    testWidgets('the sell-in and overlap caveat is always on screen', (
      tester,
    ) async {
      for (final roi in [
        _roi(),
        _roi(spend: null, roiPct: null, unmeasurable: 'no_budget'),
      ]) {
        await openReturn(tester, _FakeCampaignsRepository(roi: roi));
        final caveat = find.descendant(
          of: find.byKey(const ValueKey<String>('roi-caveat')),
          matching: find.text(campaignReturnCaveat),
        );
        expect(caveat, findsOneWidget);
        expect(campaignReturnCaveat, contains('not what shoppers bought'));
        expect(campaignReturnCaveat, contains('one campaign only'));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a failed return does not hide the compliance rollup', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_FakeCampaignsRepository(roiFails: true), theme: AppTheme.light()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('campaign-c1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('compliance-c1')),
        findsOneWidget,
      );
      expect(find.textContaining('Failed to load return'), findsOneWidget);
    });

    for (final (name, theme, palette) in [
      ('light', AppTheme.light(), TiqColors.light),
      ('dark', AppTheme.dark(), TiqColors.night),
    ]) {
      testWidgets('$name: glass dialog; every return status word clears AA', (
        tester,
      ) async {
        for (final (roi, status) in [
          (_roi(), LumenStatus.good),
          (_roi(roiPct: -12), LumenStatus.crit),
          (_roi(roiPct: 0), LumenStatus.warn),
          (
            _roi(spend: null, roiPct: null, unmeasurable: 'no_budget'),
            LumenStatus.none,
          ),
        ]) {
          await openReturn(
            tester,
            _FakeCampaignsRepository(roi: roi),
            theme: theme,
          );
          final view = find.byKey(const ValueKey<String>('roi-c1'));
          final ctx = tester.element(view);
          expect(ctx.colors.glass, isTrue, reason: '$name is glass');
          expect(
            ctx.colors.surface1,
            palette.surface1,
            reason: '$name palette',
          );
          expect(ctx.colors.isNight, name == 'dark', reason: '$name night');
          expect(
            tester
                .widget<AlertDialog>(find.byType(AlertDialog))
                .backgroundColor,
            palette.surface1,
          );

          final pillFinder = find.byKey(const ValueKey<String>('roi-status'));
          expect(tester.widget<LumenStatusPill>(pillFinder).status, status);
          final box = tester.widget<Container>(
            find.descendant(of: pillFinder, matching: find.byType(Container)),
          );
          final wash = (box.decoration! as BoxDecoration).color!;
          final word = tester.widget<Text>(
            find.descendant(of: pillFinder, matching: find.byType(Text)),
          );
          expect(word.data, isNotEmpty, reason: '$name $status carries a word');
          final ratio = contrastRatio(
            word.style!.color!,
            Color.alphaBlend(wash, palette.surface1),
          );
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name $status pill is $ratio:1',
          );

          // The figures are mono, in the theme's own ink.
          final spend = tester.widget<Text>(
            find.descendant(of: view, matching: find.text('R 42550.50')),
          );
          expect(spend.style?.fontFamily, LumenGlass.mono);
          expect(spend.style?.color, palette.ink1);
          // Caveat ink clears AA on the dialog ground.
          expect(
            contrastRatio(palette.ink3, palette.surface1),
            greaterThanOrEqualTo(4.5),
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  });
}
