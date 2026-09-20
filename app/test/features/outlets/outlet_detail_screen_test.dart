import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/outlets/presentation/outlet_detail_screen.dart';

import '../../core/design/amber_golden.dart';
import '../operations_harness.dart';

/// THE REPAIR SCREEN for a wrongly pinned outlet (#386).
///
/// The point of the screen is that a number which was previously unchangeable
/// can be changed — and that what reaches the wire says honestly where the new
/// number came from. None of that moved when the screen was migrated, and this
/// file is the reason it could not.

// Kwik Spar Soweto, and the depot 8.4 km away the outlet is wrongly pinned to.
const _shopLat = -26.2678;
const _shopLng = 27.8586;
const _depotLat = -26.2041;
const _depotLng = 27.9073;

OutletDetail _detail({
  List<CheckInAttemptEvidence> attempts = const <CheckInAttemptEvidence>[],
  List<PinDispute> disputes = const <PinDispute>[],
  List<OutletChange> changes = const <OutletChange>[],
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

CheckInAttemptEvidence _attempt({
  String id = 'a1',
  double? accuracyM,
  bool? isMocked,
}) => CheckInAttemptEvidence(
  id: id,
  agentLabel: 'Nomsa Dlamini',
  lat: _shopLat,
  lng: _shopLng,
  distanceM: 8400,
  accuracyM: accuracyM,
  isMocked: isMocked,
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
  photos: photos ?? <PinDisputePhoto>[_storefrontPhoto()],
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

Future<FakeOutletAdminRepository> _pump(
  WidgetTester tester, {
  OutletDetail? detail,
  Object? detailFailure,
  bool detailPending = false,
  Object? updateFailure,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
  Size size = const Size(360, 720),
}) async {
  final admin = FakeOutletAdminRepository(
    detail: detail,
    detailFailure: detailFailure,
    detailPending: detailPending,
    updateFailure: updateFailure,
  );
  await pumpOperations(
    tester,
    const OutletDetailScreen(outletId: 'o1'),
    skin: skin,
    size: size,
    textScale: textScale,
    locale: locale,
    settle: !detailPending,
    overrides: <Override>[
      outletAdminRepositoryProvider.overrideWithValue(admin),
      outletsRepositoryProvider.overrideWithValue(FakeOpsOutletsRepository()),
    ],
  );
  return admin;
}

/// Build and show something below the fold. The evidence list, the reports and
/// the change ledger are all further down than a 360×720 phone, and the body
/// is a lazy `ListView` — which is the point: that is the screen a manager
/// actually has.
Future<void> _reveal(WidgetTester tester, Finder finder) =>
    scrollOpsTo(tester, finder);

/// Reveal, then tap.
Future<void> _tapAt(WidgetTester tester, Finder finder) async {
  await scrollOpsTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

TorchTertiaryButton _button(WidgetTester tester, String key) =>
    tester.widget<TorchTertiaryButton>(find.byKey(ValueKey<String>(key)));

void main() {
  group('what reaches the wire', () {
    testWidgets('the coordinates are editable at all', (tester) async {
      // The whole issue in one assertion: before this screen existed there was
      // nowhere in the product an outlet's pin could be corrected.
      await _pump(tester, detail: _detail());
      expect(find.byKey(const ValueKey<String>('outlet-lat')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('outlet-lng')), findsOneWidget);
      expect(
        tester
            .widget<TorchTextField>(
              find.byKey(const ValueKey<String>('outlet-lat')),
            )
            .readOnly,
        isFalse,
      );
    });

    testWidgets('sends typed coordinates as a manual correction', (
      tester,
    ) async {
      final admin = await _pump(tester, detail: _detail());

      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lat')),
        _shopLat.toString(),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lng')),
        _shopLng.toString(),
      );
      await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

      expect(admin.updatedLat, _shopLat);
      expect(admin.updatedLng, _shopLng);
      // No attempt id: these numbers were typed, and the ledger must not claim
      // they came from where an agent stood.
      expect(admin.updatedFromAttemptId, isNull);
      await settleOpsToasts(tester);
    });

    testWidgets(
      'sends the attempt id, not the numbers, when adopting a position',
      (tester) async {
        // The backend reads the coordinates out of the attempt row itself, so
        // a body carrying both could make the audit trail say "the agent's
        // recorded position" beside numbers that were never any agent's
        // position. The screen must send one or the other, never both.
        final admin = await _pump(
          tester,
          detail: _detail(attempts: <CheckInAttemptEvidence>[_attempt()]),
        );

        await _tapAt(
          tester,
          find.byKey(const ValueKey<String>('use-attempt-a1')),
        );
        await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

        expect(admin.updatedFromAttemptId, 'a1');
        expect(admin.updatedLat, isNull);
        expect(admin.updatedLng, isNull);
        await settleOpsToasts(tester);
      },
    );

    testWidgets('typing over an adopted position makes it manual again', (
      tester,
    ) async {
      final admin = await _pump(
        tester,
        detail: _detail(attempts: <CheckInAttemptEvidence>[_attempt()]),
      );

      await _tapAt(
        tester,
        find.byKey(const ValueKey<String>('use-attempt-a1')),
      );
      // Back up the page: the field is above the evidence list, and the body
      // is lazy.
      await scrollOpsBackTo(
        tester,
        find.byKey(const ValueKey<String>('outlet-lat')),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lat')),
        '-26.3',
      );
      await tester.pumpAndSettle();
      await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

      expect(admin.updatedFromAttemptId, isNull);
      expect(admin.updatedLat, -26.3);
      await settleOpsToasts(tester);
    });

    testWidgets('answering a report sends its id alongside the correction', (
      tester,
    ) async {
      final admin = await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute()],
        ),
      );

      await _tapAt(tester, find.byKey(const ValueKey<String>('adopt-d1')));
      await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

      expect(admin.updatedDisputeId, 'd1');
      expect(admin.updatedFromAttemptId, 'a1');
      await settleOpsToasts(tester);
    });

    testWidgets('a failed save says the store is unchanged', (tester) async {
      await _pump(
        tester,
        detail: _detail(),
        updateFailure: StateError('SocketException: api.tradeiq.co.za'),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lat')),
        _shopLat.toString(),
      );
      await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

      expect(
        find.text('That store was not saved. It is unchanged.'),
        findsOneWidget,
      );
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      await settleOpsToasts(tester);
    });
  });

  group('refusals happen before the request', () {
    testWidgets('will not save an off-globe coordinate', (tester) async {
      final admin = await _pump(tester, detail: _detail());

      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lat')),
        '91',
      );
      await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

      expect(admin.updateCount, 0);
      expect(find.text('A latitude is between -90 and 90'), findsOneWidget);
    });

    testWidgets('a coordinate that is not a number blocks the commit', (
      tester,
    ) async {
      final admin = await _pump(tester, detail: _detail());

      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lat')),
        '',
      );
      await tester.pumpAndSettle();

      // The primary is disarmed rather than lit-and-refusing, and it says why.
      final save = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('save-outlet')),
      );
      expect(save.onPressed, isNull);
      expect(save.blockedReason, isNotNull);
      expect(admin.updateCount, 0);
    });
  });

  group('the evidence', () {
    testWidgets('shows where agents actually stood', (tester) async {
      await _pump(
        tester,
        detail: _detail(attempts: <CheckInAttemptEvidence>[_attempt()]),
      );

      await _reveal(tester, find.byKey(const ValueKey<String>('attempt-a1')));
      expect(find.byKey(const ValueKey<String>('attempt-a1')), findsOneWidget);
      expect(find.textContaining('Nomsa Dlamini'), findsWidgets);
      // Distance in the unit a person reads at that scale.
      expect(find.textContaining('8.4 km'), findsWidgets);
    });

    testWidgets('says so when there is none', (tester) async {
      await _pump(tester, detail: _detail());
      await _reveal(tester, find.text('No rejected check-ins.'));
      expect(find.text('No rejected check-ins.'), findsOneWidget);
    });

    testWidgets('shows an open report with the pin as it read at the time', (
      tester,
    ) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute()],
        ),
      );

      expect(find.textContaining('reported this pin as wrong'), findsOneWidget);
      await _reveal(tester, find.textContaining('I am standing at the till.'));
      expect(find.textContaining('I am standing at the till.'), findsOneWidget);
      // The frozen pin: a report read after the correction must still show
      // what the agent was arguing with. Five places, through the formatter,
      // with the typographic minus.
      expect(find.textContaining('−26.20410'), findsWidgets);

      // The storefront evidence itself, with BOTH accounts of it: what the
      // phone said, and when this server actually took delivery. A count of
      // photos was what this used to show, and a manager cannot judge a pin
      // from a number.
      await scrollOpsTo(
        tester,
        find.byKey(const ValueKey<String>('dispute-photo-p1')),
      );
      expect(
        find.byKey(const ValueKey<String>('dispute-photo-p1')),
        findsOneWidget,
      );
      expect(find.text('Taken with the camera'), findsOneWidget);
      expect(find.textContaining('Received Tue 15 Sep'), findsOneWidget);
    });

    testWidgets('shows a gallery photo as a gallery photo', (tester) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[
            _dispute(
              photos: <PinDisputePhoto>[
                _storefrontPhoto(
                  source: 'gallery',
                  // The laundering shape: stamped with the moment it was
                  // picked, a week after the claim reached the server.
                  timestamp: DateTime.utc(2026, 9, 22, 11),
                  receivedAt: DateTime.utc(2026, 9, 22, 11, 1),
                ),
              ],
            ),
          ],
        ),
      );

      await scrollOpsTo(tester, find.text('Chosen from the gallery'));
      expect(find.text('Chosen from the gallery'), findsOneWidget);
      expect(find.textContaining('Phone said Tue 22 Sep'), findsOneWidget);
      expect(find.textContaining('Received Tue 22 Sep'), findsOneWidget);
    });

    testWidgets('a resolved report says who resolved it', (tester) async {
      await _pump(
        tester,
        detail: _detail(disputes: <PinDispute>[_dispute(status: 'applied')]),
      );
      await _reveal(tester, find.text('Applied by Thandi Mokoena'));
      expect(find.text('Applied by Thandi Mokoena'), findsOneWidget);
      // And it is not counted as still waiting on anybody.
      expect(find.textContaining('reported this pin as wrong'), findsNothing);
    });
  });

  group('deciding from evidence rather than decimals', () {
    testWidgets('will not adopt a position the device called a mock', (
      tester,
    ) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt(isMocked: true)],
          disputes: <PinDispute>[_dispute(isMocked: true)],
        ),
      );

      // Both ways in are shut, because both of them move the pin. The buttons
      // stay on screen and go dead rather than vanishing.
      await _reveal(
        tester,
        find.byKey(const ValueKey<String>('use-attempt-a1')),
      );
      expect(_button(tester, 'use-attempt-a1').onPressed, isNull);
      await _reveal(tester, find.byKey(const ValueKey<String>('adopt-d1')));
      expect(_button(tester, 'adopt-d1').onPressed, isNull);
      // And it says why, in words, rather than greying out in silence.
      expect(find.textContaining('mock location'), findsWidgets);
    });

    testWidgets('will not adopt a fix too coarse to place a shop door', (
      tester,
    ) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt(accuracyM: 600)],
          disputes: <PinDispute>[_dispute(accuracyM: 600)],
        ),
      );

      await _reveal(tester, find.byKey(const ValueKey<String>('adopt-d1')));
      expect(_button(tester, 'adopt-d1').onPressed, isNull);
      expect(find.textContaining('too coarse'), findsWidgets);
    });

    testWidgets('still adopts a good fix', (tester) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt(accuracyM: 9)],
          disputes: <PinDispute>[_dispute(accuracyM: 9)],
        ),
      );
      await _reveal(tester, find.byKey(const ValueKey<String>('adopt-d1')));
      expect(_button(tester, 'adopt-d1').onPressed, isNotNull);
      expect(find.textContaining('Accurate to about 9 m'), findsWidgets);
    });

    testWidgets('still adopts a fix that reported nothing, and says so', (
      tester,
    ) async {
      // An older handset that reports no accuracy must not lock a manager out
      // of fixing a pin — that is the bug this whole feature exists for.
      // Unknown is shown as unknown, never as fine.
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute()],
        ),
      );
      await _reveal(tester, find.byKey(const ValueKey<String>('adopt-d1')));
      expect(_button(tester, 'adopt-d1').onPressed, isNotNull);
      expect(find.textContaining('did not report how accurate'), findsWidgets);
    });

    testWidgets("warns when the reporter is the store's only visitor", (
      tester,
    ) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute(agentIsOnlyVisitor: true)],
        ),
      );
      // Nobody else's check-ins can disagree with a pin moved onto this
      // agent's position. Not a refusal: a genuinely new store has one
      // visitor too.
      await _reveal(
        tester,
        find.byKey(const ValueKey<String>('dispute-sole-d1')),
      );
      expect(
        find.byKey(const ValueKey<String>('dispute-sole-d1')),
        findsOneWidget,
      );
    });

    testWidgets('stays quiet when other agents have worked the store', (
      tester,
    ) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute()],
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('dispute-sole-d1')),
        findsNothing,
      );
    });
  });

  group('status and the ledger', () {
    testWidgets('closing is offered, and says it does not block check-in', (
      tester,
    ) async {
      await _pump(tester, detail: _detail());
      expect(
        find.byKey(const ValueKey<String>('outlet-status')),
        findsOneWidget,
      );
      // The rule that matters: an agent standing at the door of a store the
      // office believes is closed must still be able to work. It is the
      // consequence line under the option, where a manager reads it BEFORE
      // choosing.
      expect(find.textContaining('Check-in still works'), findsOneWidget);
    });

    testWidgets('says what a pin move was and what it was before', (
      tester,
    ) async {
      await _pump(
        tester,
        detail: _detail(
          changes: <OutletChange>[
            OutletChange(
              id: 'c1',
              userLabel: 'Thandi Mokoena',
              before: const <String, dynamic>{
                'lat': _depotLat,
                'lng': _depotLng,
              },
              after: const <String, dynamic>{'lat': _shopLat, 'lng': _shopLng},
              pinSource: 'agent_position',
              createdAt: DateTime.utc(2026, 9, 16, 9),
            ),
          ],
        ),
      );

      await scrollOpsTo(tester, find.text('Change history'));
      expect(find.textContaining('Pin moved from'), findsOneWidget);
      expect(
        find.textContaining("from an agent's recorded position"),
        findsOneWidget,
      );
      expect(find.textContaining('Thandi Mokoena'), findsWidgets);
    });

    testWidgets('a ledger row with a missing coordinate says so in words', (
      tester,
    ) async {
      await _pump(
        tester,
        detail: _detail(
          changes: <OutletChange>[
            OutletChange(
              id: 'c1',
              userLabel: 'Thandi Mokoena',
              // A row written before longitude was recorded. A zero here would
              // be a claim about the Gulf of Guinea.
              before: const <String, dynamic>{'lat': _depotLat},
              after: const <String, dynamic>{'lat': _shopLat},
              pinSource: null,
              fromAgentId: null,
              fromAttemptId: null,
              createdAt: DateTime.utc(2026, 9, 16, 9),
            ),
          ],
        ),
      );

      await scrollOpsTo(tester, find.text('Change history'));
      expect(find.textContaining('not recorded'), findsOneWidget);
      expect(find.textContaining('0.00000'), findsNothing);
    });
  });

  group('the states', () {
    testWidgets('loading is a skeleton', (tester) async {
      await _pump(tester, detailPending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('error sanitises and retries', (tester) async {
      await _pump(
        tester,
        detailFailure: StateError('SocketException: api.tradeiq.co.za'),
      );
      expect(find.text('This store did not load.'), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
    });
  });

  group('the notation the screen itself asks for', () {
    // The same code path as the create form's, and the same failure: the help
    // line under the field says "omtrent -26,2" and the refusal offers
    // "-26,2041", while the parser read one notation only. A manager on an
    // Afrikaans handset could not correct a wrong pin at all — the capability
    // this whole screen exists for.
    testWidgets('a comma decimal reaches the wire as a repaired pin', (
      tester,
    ) async {
      final admin = await _pump(
        tester,
        detail: _detail(),
        locale: const Locale('af'),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lat')),
        '-26,26780',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lng')),
        '27,85860',
      );
      await tester.pumpAndSettle();

      final save = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('save-outlet')),
      );
      expect(save.blockedReason, isNull);
      expect(save.onPressed, isNotNull);

      await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

      expect(admin.updatedLat, closeTo(_shopLat, 1e-9));
      expect(admin.updatedLng, closeTo(_shopLng, 1e-9));
      expect(admin.updatedFromAttemptId, isNull);
      await settleOpsToasts(tester);
    });

    testWidgets('an off-globe comma latitude is still refused', (tester) async {
      // The forgiving parser must not become a permissive one: "91,5" is
      // ninety-one and a half degrees north, and there is no such place.
      final admin = await _pump(
        tester,
        detail: _detail(),
        locale: const Locale('af'),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('outlet-lat')),
        '91,5',
      );
      await _tapAt(tester, find.byKey(const ValueKey<String>('save-outlet')));

      expect(admin.updateCount, 0);
      expect(find.text('’n Breedtegraad is tussen -90 en 90'), findsOneWidget);
    });
  });

  group('Afrikaans and 2.0x', () {
    testWidgets('Afrikaans has no English left on it', (tester) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute()],
        ),
        locale: const Locale('af'),
      );
      expect(find.text('Hierdie winkel'), findsOneWidget);
      await _reveal(tester, find.text('Afgekeurde inklokke'));
      expect(find.text('Afgekeurde inklokke'), findsOneWidget);
      expect(find.text('This store'), findsNothing);
    });

    testWidgets('2.0x does not overflow', (tester) async {
      await _pump(
        tester,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute()],
        ),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('every button is operable by a screen reader', () {
    // The kit shipped a component family that announced itself and did
    // nothing when a screen reader activated it, and `SectionRuleAction` and
    // `PaginationFooter.action` were still shipping that way when this group
    // was migrated. This is the guard, on this screen, per phase — so no
    // local `Semantics(button: true, excludeSemantics: true)` around a bare
    // GestureDetector can bring it back.
    final phases = <String, Future<void> Function(WidgetTester)>{
      'loaded': (t) => _pump(
        t,
        detail: _detail(
          attempts: <CheckInAttemptEvidence>[_attempt()],
          disputes: <PinDispute>[_dispute()],
        ),
      ),
      'error': (t) => _pump(t, detailFailure: StateError('no route to host')),
    };
    for (final phase in phases.entries) {
      testWidgets(phase.key, (tester) async {
        final handle = tester.ensureSemantics();
        await phase.value(tester);
        expectEveryButtonActivatable(tester);
        handle.dispose();
      });
    }
  });

  group('the amber census, every phase in every skin', () {
    /// Not a tab root, so the nav takes no slot and the thumb zone carries the
    /// one commit. Every skin lights exactly the same one object — the "Save"
    /// block — and nothing else, in every phase where that block exists.
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
      TiqSkin.veld(),
    ]) {
      final phases = <String, (Future<void> Function(WidgetTester), int)>{
        'loaded': (
          (t) => _pump(
            t,
            skin: skin,
            detail: _detail(
              attempts: <CheckInAttemptEvidence>[_attempt()],
              disputes: <PinDispute>[_dispute()],
            ),
          ),
          1,
        ),
        'loading': (
          (t) async {
            await _pump(t, skin: skin, detailPending: true);
            await t.pump(const Duration(milliseconds: 700));
          },
          0,
        ),
        'error': (
          (t) => _pump(
            t,
            skin: skin,
            detailFailure: StateError('SocketException: api.tradeiq.co.za'),
          ),
          0,
        ),
      };
      for (final phase in phases.entries) {
        final (pump, lit) = phase.value;
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await pump(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'outlet-detail',
            phase: phase.key,
          );
          expect(
            census.objectCount,
            lit,
            reason:
                'The one commit is the only light on this route, and a screen '
                'with nothing to save has none.\n${census.describe()}',
          );
        });
      }
    }
  });
}
