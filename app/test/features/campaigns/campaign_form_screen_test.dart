import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';
import 'package:tradeiq_app/features/campaigns/presentation/campaign_form_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

import '../../core/design/amber_golden.dart';
import '../clientadmin_harness.dart';
import 'campaigns_fakes.dart';

const List<Outlet> _outlets = <Outlet>[
  Outlet(id: 'o1', name: 'Kasi Corner Spaza', code: 'KCS', lat: 0, lng: 0),
  Outlet(id: 'o2', name: 'Shoprite Klipspruit', code: 'SKM', lat: 0, lng: 0),
];

Future<void> _pump(
  WidgetTester tester, {
  required FakeCampaignsRepository repo,
  Campaign? campaign,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  List<Outlet> outlets = _outlets,
  Object? outletsFailure,
}) => pumpPushedConsole(
  tester,
  CampaignFormScreen(campaign: campaign),
  skin: skin,
  textScale: textScale,
  locale: locale,
  path: '/campaigns',
  overrides: <Override>[
    campaignsRepositoryProvider.overrideWithValue(repo),
    sessionAs('manager'),
    outletsListProvider.overrideWith(
      (ref) async => outletsFailure != null
          ? throw outletsFailure
          : PaginatedResponse<Outlet>(data: outlets, nextCursor: null).data,
    ),
  ],
);

void main() {
  group('creating', () {
    testWidgets('submits the name, the dates and the ticked outlets', (
      tester,
    ) async {
      final repo = FakeCampaignsRepository();
      await _pump(tester, repo: repo);

      await tester.enterText(keyed('campaign-name-field'), '  Spring Reset ');
      await tester.pumpAndSettle();

      await scrollConsoleTo(tester, keyed('campaign-start-date'));
      await tester.tap(keyed('campaign-start-date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await scrollConsoleTo(tester, keyed('campaign-end-date'));
      await tester.tap(keyed('campaign-end-date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await scrollConsoleTo(tester, keyed('outlet-option-o1'));
      await tester.tap(keyed('outlet-option-o1'));
      await tester.pumpAndSettle();

      await tester.tap(keyed('campaign-save-button'));
      await tester.pumpAndSettle();

      expect(repo.created!['name'], 'Spring Reset');
      expect(repo.created!['outletIds'], <String>['o1']);
      expect(repo.created!['startDate'], '2026-01-01');
      expect(repo.created!['endDate'], '2026-01-01');
    });

    testWidgets('a name is required, and the trough says so', (tester) async {
      final repo = FakeCampaignsRepository();
      await _pump(tester, repo: repo);

      await tester.tap(keyed('campaign-save-button'));
      await tester.pumpAndSettle();

      expect(find.text('A campaign needs a name.'), findsOneWidget);
      expect(repo.created, isNull);

      await tester.enterText(keyed('campaign-name-field'), 'Spring Reset');
      await tester.pumpAndSettle();
      expect(find.text('A campaign needs a name.'), findsNothing);
    });

    testWidgets('missing dates are named, not shrugged at', (tester) async {
      final repo = FakeCampaignsRepository();
      await _pump(tester, repo: repo);

      await tester.enterText(keyed('campaign-name-field'), 'Spring Reset');
      await tester.pumpAndSettle();
      await tester.tap(keyed('campaign-save-button'));
      await tester.pumpAndSettle();

      await scrollConsoleTo(tester, keyed('campaign-date-error'));
      expect(
        find.text('A campaign needs a start date and an end date.'),
        findsOneWidget,
      );
      expect(repo.created, isNull);
      // "Not set" in words, never a blank a manager reads as "loading".
      expect(find.text('Not set'), findsNWidgets(2));
    });

    testWidgets('nothing ticked says what that means', (tester) async {
      await _pump(tester, repo: FakeCampaignsRepository());
      await scrollConsoleTo(tester, keyed('campaign-outlets-note'));
      expect(find.text('Nothing ticked covers every outlet.'), findsOneWidget);

      await tester.tap(keyed('outlet-option-o2'));
      await tester.pumpAndSettle();
      expect(find.text('Covers the ticked outlets only.'), findsOneWidget);
    });

    testWidgets('an outlet list that will not load names the failure', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: FakeCampaignsRepository(),
        outletsFailure: offline(),
      );
      await scrollConsoleTo(tester, keyed('campaign-outlets-error'));
      expect(find.byType(ErrorState), findsWidgets);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(keyed('campaign-outlets-retry'), findsOneWidget);
    });

    testWidgets('a failed save keeps everything typed and says why', (
      tester,
    ) async {
      final repo = FakeCampaignsRepository(saveFailure: offline());
      await _pump(tester, repo: repo);

      await tester.enterText(keyed('campaign-name-field'), 'Spring Reset');
      await tester.pumpAndSettle();
      await scrollConsoleTo(tester, keyed('campaign-start-date'));
      await tester.tap(keyed('campaign-start-date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await scrollConsoleTo(tester, keyed('campaign-end-date'));
      await tester.tap(keyed('campaign-end-date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(keyed('campaign-save-button'));
      await tester.pumpAndSettle();

      await scrollConsoleTo(tester, keyed('campaign-save-error'));
      expect(find.byType(ErrorState), findsWidgets);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('editing', () {
    testWidgets('prefills, patches the status, and offers no date control', (
      tester,
    ) async {
      final repo = FakeCampaignsRepository();
      await _pump(tester, repo: repo, campaign: campaignA);

      expect(find.text('Summer Push'), findsWidgets);
      // `PATCH /campaigns/:id` accepts neither, so neither is offered — a
      // control the server will refuse is a trap, and the screen says so.
      expect(keyed('campaign-start-date'), findsNothing);
      expect(keyed('outlet-option-o1'), findsNothing);

      await scrollConsoleTo(tester, keyed('campaign-edit-note'));
      expect(
        find.textContaining('Dates and outlets are fixed'),
        findsOneWidget,
      );

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      await tester.tap(keyed('campaign-save-button'));
      await tester.pumpAndSettle();

      expect(repo.updated!['id'], 'c1');
      expect(repo.updated!['name'], 'Summer Push');
      expect(repo.updated!['status'], 'completed');
      expect(repo.updated!['budget'], 15000.0);
    });

    testWidgets('a budget cannot be typed as a word at all', (tester) async {
      final repo = FakeCampaignsRepository();
      await _pump(tester, repo: repo, campaign: campaignA);

      await scrollConsoleTo(tester, keyed('campaign-budget-field'));
      await tester.enterText(keyed('campaign-budget-field'), 'lots');
      await tester.pumpAndSettle();

      // The trough refuses the letters rather than accepting them and
      // complaining afterwards: the numeric field allows digits, the two
      // decimal marks, a minus and a space, and nothing else.
      final field = tester.widget<TorchNumericField>(
        keyed('campaign-budget-field'),
      );
      expect(field.controller!.text, isEmpty);

      // And an emptied budget is null, not nought — the return then says it
      // cannot be measured rather than dividing by zero.
      await tester.tap(keyed('campaign-save-button'));
      await tester.pumpAndSettle();
      expect(repo.updated!['budget'], isNull);
    });
  });

  group('the amber census, every phase in every skin', () {
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      testWidgets('${skin.mode.name}, editing: the save block, and only it', (
        tester,
      ) async {
        await _pump(tester, repo: FakeCampaignsRepository(), skin: skin);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          skin,
          route: 'campaign form',
          phase: 'editing',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('${skin.mode.name}, saving: nothing is armed', (
        tester,
      ) async {
        await _pump(
          tester,
          repo: FakeCampaignsRepository(savePending: true),
          campaign: campaignA,
          skin: skin,
        );
        await tester.tap(keyed('campaign-save-button'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final census = await amberCensus(tester);
        expect(census.objectCount, 0, reason: census.describe());
      });
    }
  });

  group('2.0x text and Afrikaans lengths', () {
    testWidgets('the form survives and nothing overflows', (tester) async {
      await _pump(
        tester,
        repo: FakeCampaignsRepository(),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('campaign-outlets-note'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the edit form survives at 2.0x', (tester) async {
      await _pump(
        tester,
        repo: FakeCampaignsRepository(),
        campaign: campaignA,
        textScale: 2.0,
        locale: const Locale('af'),
      );
      expect(tester.takeException(), isNull);
      await scrollConsoleTo(tester, keyed('campaign-edit-note'));
      expect(tester.takeException(), isNull);
    });
  });

  group('the numeric field', () {
    testWidgets('a budget is mono, and its unit is the locale’s', (
      tester,
    ) async {
      await _pump(tester, repo: FakeCampaignsRepository(), campaign: campaignA);
      await scrollConsoleTo(tester, keyed('campaign-budget-field'));
      final field = tester.widget<TorchNumericField>(
        keyed('campaign-budget-field'),
      );
      expect(field.controller!.text, '15000.0');
      expect(field.decimals, 2);
    });
  });
}
