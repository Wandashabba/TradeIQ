import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tradeiq_app/core/location/geolocator_gateway.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/create_outlet_screen.dart';
import 'package:tradeiq_app/features/territories/data/territories_repository.dart';

import '../../helpers/routed_app.dart';

class _FixedGateway implements GeolocatorGateway {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition() async => Position(
        latitude: -26.089,
        longitude: 28.023,
        timestamp: DateTime.utc(2026, 7, 20),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

/// Records what the screen actually sent, which is the whole question here.
class _RecordingOutletsRepository implements OutletsRepository {
  String? sentTerritoryId;

  @override
  Future<List<Outlet>> listOutlets({bool mine = false}) async => const [];

  @override
  Future<Outlet> createOutlet({
    required String name,
    required String code,
    required String channelType,
    required double lat,
    required double lng,
    required String territoryId,
  }) async {
    sentTerritoryId = territoryId;
    return Outlet(id: 'o1', name: name, code: code, lat: lat, lng: lng);
  }
}

class _FakeTerritoriesRepository implements TerritoriesRepository {
  _FakeTerritoriesRepository(this.territories);

  final List<Territory> territories;

  @override
  Future<List<Territory>> listTerritories() async => territories;

  @override
  Future<TerritoryCoverage> getCoverage(String id) async =>
      const TerritoryCoverage(outletCount: 0, agentCount: 0);

  @override
  Future<Territory> createTerritory({
    required String name,
    required String code,
    String? region,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> assignAgent(String territoryId, String userId) async =>
      throw UnimplementedError();
}

void main() {
  // Deliberately unlike each other: a screen that submitted the name would
  // still look right if name and code matched.
  final territories = [
    const Territory(id: 't1', name: 'Hurlingham', code: '2773u'),
    const Territory(id: 't2', name: 'Gauteng North', code: 'gauteng-north'),
  ];

  Future<_RecordingOutletsRepository> pump(
    WidgetTester tester, {
    List<Territory>? available,
  }) async {
    final outlets = _RecordingOutletsRepository();
    await tester.pumpWidget(
      routedApp(
        const CreateOutletScreen(),
        overrides: [
          outletsRepositoryProvider.overrideWithValue(outlets),
          territoriesRepositoryProvider.overrideWithValue(
            _FakeTerritoriesRepository(available ?? territories),
          ),
          locationServiceProvider.overrideWithValue(
            LocationService(gateway: _FixedGateway()),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return outlets;
  }

  testWidgets('territory is chosen from a list, not typed', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('territory-picker')), findsOneWidget);
    // The old free-text field is gone — it is what let a name be filed as a code.
    expect(find.widgetWithText(TextFormField, 'Territory ID'), findsNothing);
  });

  testWidgets('submits the territory CODE, not the name shown', (tester) async {
    final outlets = await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store Name'),
      'Hurlingham Market',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store Code'),
      'HM-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Channel Type (e.g. supermarket)'),
      'supermarket',
    );

    await tester.tap(find.byKey(const ValueKey('territory-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hurlingham').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Store'));
    await tester.pumpAndSettle();

    // The regression this exists for: a real outlet was filed under
    // 'Hurlingham' — the territory's name — while the column wanted '2773u',
    // so it matched no territory and vanished from every scoped view.
    expect(outlets.sentTerritoryId, '2773u');
  });

  testWidgets('will not submit without a territory chosen', (tester) async {
    final outlets = await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store Name'),
      'No Territory',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Store Code'),
      'NT-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Channel Type (e.g. supermarket)'),
      'supermarket',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create Store'));
    await tester.pumpAndSettle();

    expect(outlets.sentTerritoryId, isNull);
  });

  testWidgets('says what to do when no territory exists yet', (tester) async {
    await pump(tester, available: const []);

    // An empty dropdown reads as broken; this names the missing prerequisite.
    expect(find.textContaining('No territories yet'), findsOneWidget);
  });
}
