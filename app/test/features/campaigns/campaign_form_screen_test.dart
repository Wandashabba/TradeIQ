import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/lumen_kit.dart';
import 'package:tradeiq_app/features/campaigns/data/campaigns_repository.dart';
import 'package:tradeiq_app/features/campaigns/presentation/campaign_form_screen.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';

const _existing = Campaign(
  id: 'c1',
  name: 'Summer Push',
  status: 'draft',
  startDate: '2026-06-01',
  endDate: '2026-08-31',
  outletCount: 3,
  objective: 'visibility',
  budget: 15000,
);

class _RecordingCampaignsRepository implements CampaignsRepository {
  Map<String, dynamic>? createdArgs;
  Map<String, dynamic>? updatedArgs;

  @override
  Future<PaginatedResponse<Campaign>> listCampaigns() async =>
      const PaginatedResponse(data: [], nextCursor: null);

  @override
  Future<CampaignCompliance> getCompliance(String id) async =>
      throw UnimplementedError();

  @override
  Future<CampaignRoi> getRoi(String id) async => throw UnimplementedError();

  @override
  Future<Campaign> createCampaign({
    required String name,
    required String startDate,
    required String endDate,
    String? objective,
    double? budget,
    List<String>? outletIds,
  }) async {
    createdArgs = {
      'name': name,
      'startDate': startDate,
      'endDate': endDate,
      'objective': objective,
      'budget': budget,
      'outletIds': outletIds,
    };
    return _existing;
  }

  @override
  Future<Campaign> updateCampaign(
    String id, {
    String? name,
    String? objective,
    double? budget,
    String? status,
  }) async {
    updatedArgs = {
      'id': id,
      'name': name,
      'objective': objective,
      'budget': budget,
      'status': status,
    };
    return _existing;
  }
}

class _FakeOutletsRepository implements OutletsRepository {
  @override
  Future<PaginatedResponse<Outlet>> listOutlets({
    bool mine = false,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
    data: [
      Outlet(id: 'o1', name: 'Shop One', code: 'S1', lat: 0, lng: 0),
      Outlet(id: 'o2', name: 'Shop Two', code: 'S2', lat: 0, lng: 0),
    ],
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
  }) async => throw UnimplementedError();
}

Widget _app(CampaignsRepository repo, {Campaign? campaign, ThemeData? theme}) =>
    ProviderScope(
      overrides: [
        campaignsRepositoryProvider.overrideWithValue(repo),
        outletsRepositoryProvider.overrideWithValue(_FakeOutletsRepository()),
      ],
      child: MaterialApp(
        theme: theme,
        home: CampaignFormScreen(campaign: campaign),
      ),
    );

/// The nearest glass pane around [finder].
GlassPane _paneAround(WidgetTester tester, Finder finder) =>
    tester.widget<GlassPane>(
      find.ancestor(of: finder, matching: find.byType(GlassPane)).first,
    );

void main() {
  testWidgets('create: submits name, dates and selected outlets', (
    tester,
  ) async {
    final repo = _RecordingCampaignsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('campaign-name-field')),
      'Q3 Blitz',
    );

    // Confirm the default initial date in each picker dialog.
    await tester.tap(find.byKey(const ValueKey<String>('campaign-start-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('campaign-end-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('outlet-option-o1')));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('campaign-save-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.createdArgs, isNotNull);
    expect(repo.createdArgs!['name'], 'Q3 Blitz');
    expect(repo.createdArgs!['startDate'], isNotNull);
    expect(repo.createdArgs!['endDate'], isNotNull);
    expect(repo.createdArgs!['outletIds'], contains('o1'));
    expect(repo.updatedArgs, isNull);
  });

  testWidgets('create: blocks submit when name is empty', (tester) async {
    final repo = _RecordingCampaignsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('campaign-save-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget);
    expect(repo.createdArgs, isNull);
  });

  testWidgets('create: warns when dates are missing', (tester) async {
    final repo = _RecordingCampaignsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('campaign-name-field')),
      'No Dates',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('campaign-save-button')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('dates are required'), findsOneWidget);
    expect(repo.createdArgs, isNull);
  });

  testWidgets('edit: prefills fields and patches status', (tester) async {
    final repo = _RecordingCampaignsRepository();
    await tester.pumpWidget(_app(repo, campaign: _existing));
    await tester.pumpAndSettle();

    expect(find.text('Summer Push'), findsOneWidget);
    // Date/outlet controls are not shown in edit mode.
    expect(
      find.byKey(const ValueKey<String>('campaign-start-date')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('campaign-status-field')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('campaign-save-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.updatedArgs, isNotNull);
    expect(repo.updatedArgs!['id'], 'c1');
    expect(repo.updatedArgs!['name'], 'Summer Push');
    expect(repo.updatedArgs!['status'], 'active');
    expect(repo.createdArgs, isNull);
  });

  testWidgets('light: create groups into glass panels and saves from glass', (
    tester,
  ) async {
    final repo = _RecordingCampaignsRepository();
    await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
    await tester.pumpAndSettle();

    for (final kicker in ['DETAILS', 'SCHEDULE', 'OUTLETS']) {
      expect(_paneAround(tester, find.text(kicker)).kind, GlassKind.panel);
    }
    // An unset date says so in words, never a blank.
    expect(find.text('Not set'), findsNWidgets(2));
    final save = find.byKey(const ValueKey<String>('campaign-save-button'));
    expect(tester.widget(save), isA<GlassPrimaryButton>());
    expect(find.byType(FilledButton), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('campaign-name-field')),
      'Q3 Blitz',
    );
    for (final key in ['campaign-start-date', 'campaign-end-date']) {
      final pick = find.byKey(ValueKey<String>(key));
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    final option = find.byKey(const ValueKey<String>('outlet-option-o1'));
    expect(_paneAround(tester, option).kind, GlassKind.tile);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.createdArgs!['name'], 'Q3 Blitz');
    expect(repo.createdArgs!['outletIds'], contains('o1'));
  });

  testWidgets('light: edit puts the status control in its own glass panel', (
    tester,
  ) async {
    final repo = _RecordingCampaignsRepository();
    await tester.pumpWidget(
      _app(repo, campaign: _existing, theme: AppTheme.light()),
    );
    await tester.pumpAndSettle();

    expect(_paneAround(tester, find.text('STATUS')).kind, GlassKind.panel);
    expect(find.text('SCHEDULE'), findsNothing);
    expect(find.text('Save Changes'), findsOneWidget);
  });
}
