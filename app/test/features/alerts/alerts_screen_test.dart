import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/evidence_thumb.dart';
import 'package:tradeiq_app/core/widgets/worklist.dart';
import 'package:tradeiq_app/features/alerts/data/alerts_repository.dart';
import 'package:tradeiq_app/features/alerts/presentation/alerts_screen.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;
import '../../helpers/routed_app.dart';

const _unacknowledged = AlertItem(
  id: 'a-open',
  metric: 'stock',
  message: 'SKU 42 out of stock',
  severity: 'critical',
  acknowledged: false,
  outletId: 'o1',
);

const _acknowledged = AlertItem(
  id: 'a-done',
  metric: 'price',
  message: 'Shelf price mismatch',
  severity: 'warning',
  acknowledged: true,
  outletId: 'o2',
);

/// Unacked, with a linked visit that has a shelf photo — the thumb case.
const _evidenced = AlertItem(
  id: 'a-photo',
  metric: 'stock',
  message: 'Shelf gap on aisle 3',
  severity: 'warning',
  acknowledged: false,
  outletId: 'o3',
  visitId: 'v1',
  evidencePhotoId: 'p1',
);

/// A real, decodable image for the evidence thumb (1×1 transparent PNG).
final _pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

AlertItem _acked(AlertItem a) => AlertItem(
  id: a.id,
  metric: a.metric,
  message: a.message,
  severity: a.severity,
  acknowledged: true,
  visitId: a.visitId,
  outletId: a.outletId,
  evidencePhotoId: a.evidencePhotoId,
);

/// Stateful fake: acknowledging mutates the list the next fetch returns, so
/// the screen's invalidate-after-ack round trip is observable. [ackDelay]
/// keeps the acknowledge future in flight — the collapse animation must win
/// the race against it.
class _FakeAlertsRepository implements AlertsRepository {
  _FakeAlertsRepository({
    List<AlertItem>? alerts,
    this.ackDelay = Duration.zero,
  }) : _alerts = List.of(alerts ?? const [_unacknowledged, _acknowledged]);

  final Duration ackDelay;
  final List<AlertItem> _alerts;
  String? acknowledgedId;

  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async => PaginatedResponse(data: List.of(_alerts), nextCursor: null);

  @override
  Future<AlertItem> acknowledge(String id) async {
    if (ackDelay > Duration.zero) {
      await Future<void>.delayed(ackDelay);
    }
    acknowledgedId = id;
    final i = _alerts.indexWhere((a) => a.id == id);
    final updated = _acked(_alerts[i]);
    _alerts[i] = updated;
    return updated;
  }
}

class _ThrowingAlertsRepository implements AlertsRepository {
  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async => throw Exception('boom');

  @override
  Future<AlertItem> acknowledge(String id) async => throw Exception('boom');
}

/// The list loads, but acknowledging fails — the honesty path: the row must
/// come back, never silently vanish while still unacknowledged server-side.
class _AckFailsRepository implements AlertsRepository {
  @override
  Future<PaginatedResponse<AlertItem>> listAlerts({
    bool? acknowledged,
    String? severity,
  }) async => const PaginatedResponse(
    data: [_unacknowledged, _acknowledged],
    nextCursor: null,
  );

  @override
  Future<AlertItem> acknowledge(String id) async =>
      throw Exception('ack rejected');
}

class _FakePhotosRepository implements PhotosRepository {
  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async =>
      const PhotoUploadResult(id: 'photo-1', url: 'data:image/png;base64,');

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async => _pngBytes;

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async => const [];
}

Widget _app(AlertsRepository repo) => routedApp(
  const AlertsScreen(),
  overrides: [
    alertsRepositoryProvider.overrideWithValue(repo),
    photosRepositoryProvider.overrideWithValue(_FakePhotosRepository()),
  ],
);

void main() {
  testWidgets('opens on the triage list — what is still open', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    // The worklist defaults to Open: a manager lands on what still needs doing,
    // not on a mixed pile. The acknowledged alert is one tab away, not gone.
    expect(find.text('SKU 42 out of stock'), findsOneWidget);
    expect(find.text('Shelf price mismatch'), findsNothing);
  });

  testWidgets('the All tab reveals acknowledged alerts', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
    await tester.pumpAndSettle();

    expect(find.text('SKU 42 out of stock'), findsOneWidget);
    expect(find.text('Shelf price mismatch'), findsOneWidget);
  });

  testWidgets('triage counts summarise the list before you read it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('triage-critical')), findsOneWidget);
    expect(find.byKey(const ValueKey('triage-warning')), findsOneWidget);
    expect(find.byKey(const ValueKey('triage-acknowledged')), findsOneWidget);
  });

  testWidgets('shows an error message when the list fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ThrowingAlertsRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load alerts'), findsOneWidget);
  });

  group('acked rows', () {
    testWidgets('wear the muted ✓ ACKED pill — words, never colour alone', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_FakeAlertsRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
      await tester.pumpAndSettle();

      // Exactly one pill — on the acked row, not the open one.
      expect(find.text('✓ ACKED'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('alert-a-done')),
          matching: find.text('✓ ACKED'),
        ),
        findsOneWidget,
      );

      // The muted wash: surface2 under ink2 — the SlaPill "chrome" family,
      // never a status colour (acked is a state, not a verdict).
      final pill = tester.widget<Container>(
        find.byKey(const ValueKey('acked-pill')),
      );
      expect(
        (pill.decoration! as BoxDecoration).color,
        TiqColors.dark.surface2,
      );
      final label = tester.widget<Text>(find.text('✓ ACKED'));
      expect(label.style!.color, TiqColors.dark.ink2);
    });

    testWidgets('fade back, but the title still clears 4.5:1 on the card', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_FakeAlertsRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
      await tester.pumpAndSettle();

      // The acked row IS faded (WorklistRow's resolved dim), the open row not.
      final ackedGate = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Shelf price mismatch'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      final openGate = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('SKU 42 out of stock'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(ackedGate.opacity, lessThan(1));
      expect(openGate.opacity, 1);

      // Honesty maths, both palettes: the Opacity wraps the WHOLE card, and
      // the card (surface1) sits on a PanelCard that is also surface1 — so
      // the composited ground stays surface1 and the composited title is
      // ink1 blended toward surface1 by the fade. That blend must still
      // read: ≥4.5:1. (At the shipped 0.6 this is ~6.2:1 dark, ~4.7:1
      // light — which is why 0.6 was kept rather than raised.)
      for (final t in [TiqColors.dark, TiqColors.light]) {
        final compositedTitle = Color.lerp(
          t.surface1,
          t.ink1,
          ackedGate.opacity,
        )!;
        expect(
          contrastRatio(compositedTitle, t.surface1),
          greaterThanOrEqualTo(4.5),
          reason:
              'faded acked title must stay readable on ${t == TiqColors.dark ? 'dark' : 'light'}',
        );
      }
    });

    testWidgets('offer no actions; open rows offer only Acknowledge', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_FakeAlertsRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('ack-a-open')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('ack-a-done')), findsNothing);

      // Ruling (2026-07-25): NO "View visit" action. The manager console has
      // no visit-detail route — the agent trail takes a day/agent context,
      // not a visit id — and a dead link would be dishonest chrome. If a
      // visit-detail screen ever lands, this is the test to loosen.
      expect(find.text('View visit'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('alert-a-open')),
          matching: find.byType(RowAction),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('alert-a-done')),
          matching: find.byType(RowAction),
        ),
        findsNothing,
      );
    });
  });

  group('ack-collapse', () {
    testWidgets('acknowledging calls acknowledge with the row id', (
      tester,
    ) async {
      final repo = _FakeAlertsRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('ack-a-open')));
      await tester.pumpAndSettle();

      expect(repo.acknowledgedId, 'a-open');
    });

    testWidgets('the row animates closed BEFORE the ack lands, then the '
        'refresh omits it', (tester) async {
      // The acknowledge round trip takes 300ms; the collapse takes ~200ms.
      // The row must be visually gone while the request is still in flight —
      // the animation is the receipt, not the refresh.
      final repo = _FakeAlertsRepository(
        ackDelay: const Duration(milliseconds: 300),
      );
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      final collapse = find.byKey(const ValueKey('collapse-a-open'));
      final full = tester.getSize(collapse).height;
      expect(full, greaterThan(0));

      await tester.tap(find.byKey(const ValueKey<String>('ack-a-open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Mid-flight: genuinely animating, not snapping.
      final mid = tester.getSize(collapse).height;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(full));

      await tester.pump(const Duration(milliseconds: 150));
      // t≈250ms: collapsed to nothing while acknowledge is still pending.
      expect(tester.getSize(collapse).height, 0);
      expect(repo.acknowledgedId, isNull);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(repo.acknowledgedId, 'a-open');
      // The refreshed Open list omits the row for real.
      expect(find.text('SKU 42 out of stock'), findsNothing);
    });

    testWidgets('reduced motion: the row is removed instantly, no animation '
        'frames', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final repo = _FakeAlertsRepository(
        ackDelay: const Duration(milliseconds: 300),
      );
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('ack-a-open')));
      await tester.pump();

      // Gone on the very next frame: a 200ms tween would still be at ~full
      // height here, so instant zero IS the proof of no animation frames.
      // (No global hasRunningAnimations check — the tapped button's own ink
      // ripple is a Material animation outside this widget's control.)
      expect(
        tester.getSize(find.byKey(const ValueKey('collapse-a-open'))).height,
        0,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.getSize(find.byKey(const ValueKey('collapse-a-open'))).height,
        0,
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('SKU 42 out of stock'), findsNothing);
    });

    testWidgets('a failed acknowledge brings the row back and says so', (
      tester,
    ) async {
      // Honesty rule: an alert that is still unacknowledged server-side must
      // never silently vanish from the worklist.
      await tester.pumpWidget(_app(_AckFailsRepository()));
      await tester.pumpAndSettle();

      final collapse = find.byKey(const ValueKey('collapse-a-open'));
      final full = tester.getSize(collapse).height;

      await tester.tap(find.byKey(const ValueKey<String>('ack-a-open')));
      await tester.pumpAndSettle();

      // The row is back at full height, still actionable — and the failure
      // has a face.
      expect(find.text('SKU 42 out of stock'), findsOneWidget);
      expect(tester.getSize(collapse).height, full);
      expect(find.byKey(const ValueKey<String>('ack-a-open')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to acknowledge'), findsOneWidget);

      // Let the SnackBar's dismiss timer run out so the test ends clean.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('evidence thumbnails', () {
    testWidgets('an alert with evidence shows the thumb in the worklist slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_FakeAlertsRepository(alerts: const [_evidenced, _acknowledged])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('evidence-thumb-p1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('worklist-thumb')),
          matching: find.byType(EvidenceThumb),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no evidencePhotoId → no thumb, nothing reserved', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_FakeAlertsRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
      await tester.pumpAndSettle();

      // Both rows on screen, zero thumb slots: absence, not placeholder.
      expect(find.text('SKU 42 out of stock'), findsOneWidget);
      expect(find.text('Shelf price mismatch'), findsOneWidget);
      expect(find.byKey(const ValueKey('worklist-thumb')), findsNothing);
      expect(find.byType(EvidenceThumb), findsNothing);
    });
  });

  testWidgets('rows enter through the worklist cascade', (tester) async {
    await tester.pumpWidget(_app(_FakeAlertsRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
    await tester.pumpAndSettle();

    expect(find.byType(WorklistCascade), findsNWidgets(2));
  });
}
