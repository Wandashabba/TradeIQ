import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlet_detail_screen.dart';

import '../../helpers/routed_app.dart';

/// The repair screen for a wrongly pinned outlet (#386).
///
/// The point of the screen is that a number which was previously unchangeable
/// can be changed — and that what reaches the wire says honestly where the new
/// number came from.

// Kwik Spar Soweto, and the depot 8.4 km away the outlet is wrongly pinned to.
const _shopLat = -26.2678;
const _shopLng = 27.8586;
const _depotLat = -26.2041;
const _depotLng = 27.9073;

/// Records what the screen actually sent, which is the whole question.
class _RecordingAdmin implements OutletAdminRepository {
  _RecordingAdmin(this.detail);

  final OutletDetail detail;
  Map<String, Object?>? sent;

  @override
  Future<OutletDetail> getOutlet(String id) async => detail;

  @override
  Future<Outlet> updateOutlet({
    required String id,
    String? name,
    double? lat,
    double? lng,
    String? status,
    String? fromAttemptId,
    String? disputeId,
    String? resolutionNote,
  }) async {
    sent = {
      'name': name,
      'lat': lat,
      'lng': lng,
      'status': status,
      'fromAttemptId': fromAttemptId,
      'disputeId': disputeId,
    };
    return detail.outlet;
  }

  @override
  Future<PaginatedResponse<PinDispute>> listPinDisputes({
    String? status,
    String? outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(data: [], nextCursor: null);
}

OutletDetail _detail({
  List<CheckInAttemptEvidence> attempts = const [],
  List<PinDispute> disputes = const [],
  List<OutletChange> changes = const [],
}) => OutletDetail(
      outlet: const Outlet(
        id: 'o1',
        name: 'Kwik Spar Soweto',
        code: 'KS-001',
        lat: _depotLat,
        lng: _depotLng,
        channelType: 'convenience',
      ),
      failedAttempts: attempts,
      disputes: disputes,
      changes: changes,
    );

CheckInAttemptEvidence _attempt({String id = 'a1'}) => CheckInAttemptEvidence(
      id: id,
      agentLabel: 'Nomsa Dlamini',
      lat: _shopLat,
      lng: _shopLng,
      distanceM: 8400,
      createdAt: DateTime.utc(2026, 9, 15, 8, 30),
    );

PinDispute _dispute({
  String status = 'open',
  double? accuracyM,
  bool? isMocked,
  bool agentIsOnlyVisitor = false,
  List<PinDisputePhoto>? photos,
}) => PinDispute(
      id: 'd1',
      outletId: 'o1',
      outletName: 'Kwik Spar Soweto',
      outletCode: 'KS-001',
      visitId: 'v1',
      agentLabel: 'Nomsa Dlamini',
      lat: _shopLat,
      lng: _shopLng,
      distanceM: 8400,
      outletLat: _depotLat,
      outletLng: _depotLng,
      note: 'I am standing at the till.',
      status: status,
      resolvedByLabel: status == 'open' ? null : 'Thandi Mokoena',
      resolvedAt: status == 'open' ? null : DateTime.utc(2026, 9, 16),
      createdAt: DateTime.utc(2026, 9, 15, 8, 30),
      accuracyM: accuracyM,
      isMocked: isMocked,
      agentIsOnlyVisitor: agentIsOnlyVisitor,
      photos: photos ?? [_storefrontPhoto()],
    );

/// One storefront photo, taken with the camera and received a minute later —
/// the shape honest evidence has.
PinDisputePhoto _storefrontPhoto({
  String source = 'camera',
  DateTime? timestamp,
  DateTime? receivedAt,
}) => PinDisputePhoto(
      id: 'p1',
      timestamp: timestamp ?? DateTime.utc(2026, 9, 15, 8, 30),
      receivedAt: receivedAt ?? DateTime.utc(2026, 9, 15, 8, 31),
      source: source,
    );

void main() {
  /// Tap something that may be below the fold on this screen — the evidence
  /// list and the save button are both further down than an 800x600 viewport.
  Future<void> tapAt(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<_RecordingAdmin> pump(WidgetTester tester, OutletDetail detail) async {
    final admin = _RecordingAdmin(detail);
    await tester.pumpWidget(
      routedApp(
        const OutletDetailScreen(outletId: 'o1'),
        overrides: [outletAdminRepositoryProvider.overrideWithValue(admin)],
      ),
    );
    await tester.pumpAndSettle();
    return admin;
  }

  testWidgets('the coordinates are editable at all', (tester) async {
    // The whole issue in one assertion: before this screen existed there was
    // nowhere in the product an outlet's pin could be corrected.
    await pump(tester, _detail());
    expect(find.byKey(const ValueKey('outlet-lat')), findsOneWidget);
    expect(find.byKey(const ValueKey('outlet-lng')), findsOneWidget);
  });

  testWidgets('sends typed coordinates as a manual correction', (tester) async {
    final admin = await pump(tester, _detail());

    await tester.enterText(
      find.byKey(const ValueKey('outlet-lat')),
      _shopLat.toString(),
    );
    await tester.enterText(
      find.byKey(const ValueKey('outlet-lng')),
      _shopLng.toString(),
    );
    await tapAt(tester, find.byKey(const ValueKey('save-outlet')));

    expect(admin.sent!['lat'], _shopLat);
    expect(admin.sent!['lng'], _shopLng);
    // No attempt id: these numbers were typed, and the ledger must not claim
    // they came from where an agent stood.
    expect(admin.sent!['fromAttemptId'], isNull);
  });

  testWidgets('sends the attempt id, not the numbers, when adopting a position',
      (tester) async {
    // The backend reads the coordinates out of the attempt row itself, so a
    // body carrying both could make the audit trail say "the agent's recorded
    // position" beside numbers that were never any agent's position. The
    // screen must therefore send one or the other, never both.
    final admin = await pump(tester, _detail(attempts: [_attempt()]));

    await tapAt(tester, find.byKey(const ValueKey('use-attempt-a1')));
    await tapAt(tester, find.byKey(const ValueKey('save-outlet')));

    expect(admin.sent!['fromAttemptId'], 'a1');
    expect(admin.sent!['lat'], isNull);
    expect(admin.sent!['lng'], isNull);
  });

  testWidgets('typing over an adopted position makes it a manual correction',
      (tester) async {
    final admin = await pump(tester, _detail(attempts: [_attempt()]));

    await tapAt(tester, find.byKey(const ValueKey('use-attempt-a1')));
    await tester.enterText(find.byKey(const ValueKey('outlet-lat')), '-26.3');
    await tester.pumpAndSettle();
    await tapAt(tester, find.byKey(const ValueKey('save-outlet')));

    expect(admin.sent!['fromAttemptId'], isNull);
    expect(admin.sent!['lat'], -26.3);
  });

  testWidgets('will not save an off-globe coordinate', (tester) async {
    final admin = await pump(tester, _detail());

    await tester.enterText(find.byKey(const ValueKey('outlet-lat')), '91');
    await tapAt(tester, find.byKey(const ValueKey('save-outlet')));

    expect(admin.sent, isNull);
    expect(find.textContaining('between -90 and 90'), findsOneWidget);
  });

  testWidgets('will not save a coordinate that is not a number', (tester) async {
    final admin = await pump(tester, _detail());

    // The field filters letters out as they are typed, so an empty result is
    // what "-" or a pasted word actually leaves behind.
    await tester.enterText(find.byKey(const ValueKey('outlet-lat')), '');
    await tapAt(tester, find.byKey(const ValueKey('save-outlet')));

    expect(admin.sent, isNull);
  });

  testWidgets('shows where agents actually stood as the evidence', (tester) async {
    await pump(tester, _detail(attempts: [_attempt()]));

    expect(find.byKey(const ValueKey('attempt-a1')), findsOneWidget);
    expect(find.textContaining('Nomsa Dlamini'), findsWidgets);
    // Distance in the unit a person reads at that scale.
    expect(find.textContaining('8.4 km'), findsWidgets);
  });

  testWidgets('shows an open report with the pin as it read at the time',
      (tester) async {
    await pump(tester, _detail(attempts: [_attempt()], disputes: [_dispute()]));

    expect(find.textContaining('reported this pin as wrong'), findsOneWidget);
    expect(find.textContaining('I am standing at the till.'), findsOneWidget);
    // The frozen pin: a report read after the correction must still show what
    // the agent was arguing with.
    expect(
      find.textContaining(_depotLat.toStringAsFixed(5)),
      findsWidgets,
    );
    // The storefront evidence itself, with BOTH accounts of it: what the
    // phone said, and when this server actually took delivery. A count of
    // photos ("1 storefront photo attached.") was what this used to show, and
    // a manager cannot judge a pin from a number.
    expect(find.byKey(const ValueKey('dispute-photo-p1')), findsOneWidget);
    expect(find.text('Taken with the camera'), findsOneWidget);
    expect(find.textContaining('Received 2026-09-15'), findsOneWidget);
  });

  testWidgets('answering a report sends its id alongside the correction',
      (tester) async {
    final admin =
        await pump(tester, _detail(attempts: [_attempt()], disputes: [_dispute()]));

    await tapAt(tester, find.byKey(const ValueKey('adopt-d1')));
    await tapAt(tester, find.byKey(const ValueKey('save-outlet')));

    expect(admin.sent!['disputeId'], 'd1');
    expect(admin.sent!['fromAttemptId'], 'a1');
  });

  testWidgets('a resolved report says who resolved it', (tester) async {
    await pump(tester, _detail(disputes: [_dispute(status: 'applied')]));
    expect(find.textContaining('Applied by Thandi Mokoena'), findsOneWidget);
    // And it is not counted as still waiting on anybody.
    expect(find.textContaining('reported this pin as wrong'), findsNothing);
  });

  testWidgets('says what a pin move was and what it was before', (tester) async {
    await pump(
      tester,
      _detail(changes: [
        OutletChange(
          id: 'c1',
          userLabel: 'Thandi Mokoena',
          before: const {'lat': _depotLat, 'lng': _depotLng},
          after: const {'lat': _shopLat, 'lng': _shopLng},
          pinSource: 'agent_position',
          createdAt: DateTime.utc(2026, 9, 16, 9),
        ),
      ]),
    );

    expect(find.textContaining('Pin moved from'), findsOneWidget);
    expect(find.textContaining("agent's recorded position"), findsOneWidget);
    expect(find.textContaining('Thandi Mokoena'), findsWidgets);
  });

  testWidgets('closing an outlet is offered, and says it does not block check-in',
      (tester) async {
    await pump(tester, _detail());
    expect(find.byKey(const ValueKey('outlet-status')), findsOneWidget);
    // The rule that matters: an agent standing at the door of a store the
    // office believes is closed must still be able to work.
    expect(find.textContaining('does not block check-in'), findsOneWidget);
  });
}
