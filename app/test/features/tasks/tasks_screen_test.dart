import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/widgets/evidence_thumb.dart';
import 'package:tradeiq_app/core/widgets/sla_pill.dart';
import 'package:tradeiq_app/core/widgets/worklist.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/tasks/presentation/tasks_screen.dart';

import '../../helpers/routed_app.dart';

/// Wednesday 2026-07-22, midday — every SLA below is phrased against this.
/// The screen takes its clock as an input, so the tests own time.
final _now = DateTime(2026, 7, 22, 12);

/// A real, decodable image for the evidence thumb (1×1 transparent PNG).
final _pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Open, inside SLA (due tomorrow = Thursday), with shelf-photo evidence.
final _openTask = TaskItem(
  id: 't-open',
  findingType: 'out_of_stock',
  requiredFix: 'Restock SKU 42',
  priority: 'critical',
  status: 'open',
  closureVerified: false,
  outletId: 'o1',
  visitId: 'v1',
  slaDueAt: _now.add(const Duration(days: 1)),
  evidencePhotoId: 'p1',
);

/// Open and two days past its SLA — no photo on its visit.
final _overdueTask = TaskItem(
  id: 't-late',
  findingType: 'price_wrong',
  requiredFix: 'Correct shelf price',
  priority: 'normal',
  status: 'open',
  closureVerified: false,
  outletId: 'o2',
  visitId: 'v3',
  slaDueAt: _now.subtract(const Duration(days: 2, hours: 3)),
  evidencePhotoId: null,
);

final _closedTask = TaskItem(
  id: 't-closed',
  findingType: 'display_broken',
  requiredFix: 'Fix end-cap display',
  priority: 'normal',
  status: 'closed',
  closurePhotoUrl: 'https://cdn.example.com/old.png',
  closureVerified: false,
  outletId: 'o2',
  visitId: 'v2',
  slaDueAt: _now.subtract(const Duration(days: 1)),
  evidencePhotoId: null,
);

class _FakeTasksAdminRepository implements TasksAdminRepository {
  String? closedId;
  String? closedPhotoUrl;
  String? verifiedId;

  @override
  Future<List<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async => [_openTask, _overdueTask, _closedTask];

  @override
  Future<TaskItem> closeTask({
    required String id,
    required String closurePhotoUrl,
  }) async {
    closedId = id;
    closedPhotoUrl = closurePhotoUrl;
    return TaskItem(
      id: id,
      findingType: _openTask.findingType,
      requiredFix: _openTask.requiredFix,
      priority: _openTask.priority,
      status: 'closed',
      closurePhotoUrl: closurePhotoUrl,
      closureVerified: false,
      outletId: _openTask.outletId,
      visitId: _openTask.visitId,
      slaDueAt: _openTask.slaDueAt,
      evidencePhotoId: _openTask.evidencePhotoId,
    );
  }

  @override
  Future<TaskItem> verifyTask(String id) async {
    verifiedId = id;
    return TaskItem(
      id: id,
      findingType: _closedTask.findingType,
      requiredFix: _closedTask.requiredFix,
      priority: _closedTask.priority,
      status: 'closed',
      closurePhotoUrl: _closedTask.closurePhotoUrl,
      closureVerified: true,
      outletId: _closedTask.outletId,
      visitId: _closedTask.visitId,
      slaDueAt: _closedTask.slaDueAt,
      evidencePhotoId: _closedTask.evidencePhotoId,
    );
  }
}

class _RecordingPhotosRepository implements PhotosRepository {
  int uploadCount = 0;
  String? uploadedSection;
  String? uploadedVisitId;
  String? uploadedDataUrl;
  int thumbnailCalls = 0;

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async {
    uploadCount++;
    uploadedSection = section;
    uploadedVisitId = visitId;
    uploadedDataUrl = dataUrl;
    return const PhotoUploadResult(
      id: 'photo-1',
      url: 'https://cdn.example.com/photo-1.png',
    );
  }

  @override
  Future<Uint8List> thumbnailBytes(String photoId) async {
    thumbnailCalls++;
    return _pngBytes;
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) async => const [];
}

/// A camera that always returns the same 4-byte "photo". Closure now goes
/// through a real capture, so the test has to supply one.
class _FakeGateway implements ImagePickerGateway {
  _FakeGateway({this.cancels = false});

  final bool cancels;

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async {
    if (cancels) return null;
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      name: 'closure.jpg',
      mimeType: 'image/jpeg',
    );
  }
}

Widget _app(
  _FakeTasksAdminRepository tasksRepo,
  _RecordingPhotosRepository photosRepo, {
  bool cameraCancels = false,
}) => routedApp(
  TasksScreen(clock: () => _now),
  overrides: [
    tasksAdminRepositoryProvider.overrideWithValue(tasksRepo),
    photosRepositoryProvider.overrideWithValue(photosRepo),
    photoCaptureServiceProvider.overrideWithValue(
      PhotoCaptureService(gateway: _FakeGateway(cancels: cameraCancels)),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, [
  _FakeTasksAdminRepository? tasksRepo,
  _RecordingPhotosRepository? photosRepo,
]) async {
  await tester.pumpWidget(
    _app(
      tasksRepo ?? _FakeTasksAdminRepository(),
      photosRepo ?? _RecordingPhotosRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('filter chips', () {
    testWidgets('opens on Open, which includes overdue tasks', (tester) async {
      await _pump(tester);

      // Overdue is a focus subset, not a separate state: an overdue task is
      // still open work, so Open must show it.
      expect(find.text('out_of_stock'), findsOneWidget);
      expect(find.text('price_wrong'), findsOneWidget);
      expect(find.text('display_broken'), findsNothing);
    });

    testWidgets(
      'carry live counts: "Open · 2", "Overdue · 1", plain Done/All',
      (tester) async {
        await _pump(tester);

        expect(find.text('Open · 2'), findsOneWidget);
        expect(find.text('Overdue · 1'), findsOneWidget);
        // Per the spec example: Done and All are plain — no count.
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('All'), findsOneWidget);
      },
    );

    testWidgets('Overdue narrows to open tasks past their SLA', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('filter-overdue')));
      await tester.pumpAndSettle();

      expect(find.text('price_wrong'), findsOneWidget);
      expect(find.text('out_of_stock'), findsNothing);
      expect(find.text('display_broken'), findsNothing);
    });

    testWidgets('Done shows closed tasks; All shows everything', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('filter-done')));
      await tester.pumpAndSettle();
      expect(find.text('display_broken'), findsOneWidget);
      expect(find.text('out_of_stock'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('out_of_stock'), findsOneWidget);
      expect(find.text('price_wrong'), findsOneWidget);
      expect(find.text('display_broken'), findsOneWidget);
    });

    testWidgets('the active chip is a button and carries selected semantics', (
      tester,
    ) async {
      await _pump(tester);

      // The chip's own Semantics is the ancestor that declares `button` —
      // InkWell inserts an internal Semantics of its own in between.
      Semantics chipSemantics(String label) => tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(Semantics),
            ),
          )
          .firstWhere((s) => s.properties.button != null);

      expect(chipSemantics('Open · 2').properties.button, isTrue);
      expect(chipSemantics('Open · 2').properties.selected, isTrue);
      expect(chipSemantics('Done').properties.selected, isFalse);

      await tester.tap(find.byKey(const ValueKey('filter-done')));
      await tester.pumpAndSettle();
      expect(chipSemantics('Done').properties.selected, isTrue);
      expect(chipSemantics('Open · 2').properties.selected, isFalse);
    });

    testWidgets('the triage strip keeps its own axis — priority, not state', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(const ValueKey('triage-critical')), findsOneWidget);
      expect(find.byKey(const ValueKey('triage-high')), findsOneWidget);
      expect(find.byKey(const ValueKey('triage-normal')), findsOneWidget);
      expect(find.byKey(const ValueKey('triage-closed')), findsOneWidget);
    });
  });

  group('SLA pills', () {
    testWidgets('every row wears one, phrased against the screen clock', (
      tester,
    ) async {
      await _pump(tester);

      // Two open rows, two pills: due-tomorrow (Thursday) and two days over.
      expect(find.byType(SlaPill), findsNWidgets(2));
      expect(find.text('DUE THU'), findsOneWidget);
      expect(find.text('OVERDUE 2d'), findsOneWidget);
    });

    testWidgets('closed rows show the done state, never "OVERDUE"', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('filter-done')));
      await tester.pumpAndSettle();

      // The closed task is past its slaDueAt — done must win.
      expect(find.text('✓ DONE'), findsOneWidget);
      expect(find.textContaining('OVERDUE'), findsNothing);
    });
  });

  group('evidence thumbnails', () {
    testWidgets('a row with evidence shows the thumb in the worklist slot', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byKey(const ValueKey('evidence-thumb-p1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('worklist-thumb')),
          matching: find.byType(EvidenceThumb),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no photo → no thumb, not a placeholder', (tester) async {
      await _pump(tester);

      // Two rows on screen, exactly one thumb slot: the evidence-less row
      // reserves nothing and fakes nothing.
      expect(find.byKey(const ValueKey('worklist-thumb')), findsOneWidget);
      expect(find.byType(EvidenceThumb), findsOneWidget);
    });
  });

  testWidgets('rows enter through the worklist cascade', (tester) async {
    await _pump(tester);

    // The cascade wraps every visible row — first consumer of the shared
    // entrance. (Reduced-motion staticness is WorklistCascade's own tested
    // contract in worklist_test.dart.)
    expect(find.byType(WorklistCascade), findsNWidgets(2));
  });

  group('actions', () {
    testWidgets(
      'closing an open task uploads a photo and closes with its url',
      (tester) async {
        final tasksRepo = _FakeTasksAdminRepository();
        final photosRepo = _RecordingPhotosRepository();
        await _pump(tester, tasksRepo, photosRepo);

        await tester.tap(find.byKey(const ValueKey('close-t-open')));
        await tester.pumpAndSettle();

        // Closure is gated on evidence: until a photo exists, the button is
        // dead.
        final confirm = find.byKey(const ValueKey('confirm-closure'));
        expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

        await tester.tap(find.byKey(const ValueKey('photo-camera')));
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(photosRepo.uploadCount, 1);
        expect(photosRepo.uploadedSection, 'task_closure');
        expect(photosRepo.uploadedVisitId, 'v1');
        expect(tasksRepo.closedId, 't-open');
        expect(tasksRepo.closedPhotoUrl, 'https://cdn.example.com/photo-1.png');
      },
    );

    testWidgets('the closure photo is a real capture, not a placeholder', (
      tester,
    ) async {
      // The whole point of #41: "photo-verified closure" verified nothing
      // while the app uploaded a 1×1 transparent PNG.
      final photosRepo = _RecordingPhotosRepository();
      await _pump(tester, _FakeTasksAdminRepository(), photosRepo);

      await tester.tap(find.byKey(const ValueKey('close-t-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-closure')));
      await tester.pumpAndSettle();

      expect(photosRepo.uploadedDataUrl, 'data:image/jpeg;base64,AQIDBA==');
      expect(photosRepo.uploadedDataUrl, isNot(contains('iVBORw0KGgo')));
    });

    testWidgets('cancelling the camera leaves the task open', (tester) async {
      final tasksRepo = _FakeTasksAdminRepository();
      final photosRepo = _RecordingPhotosRepository();
      await tester.pumpWidget(_app(tasksRepo, photosRepo, cameraCancels: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('close-t-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();

      // No photo captured → the confirm stays disabled and nothing closed.
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('confirm-closure')),
            )
            .onPressed,
        isNull,
      );
      expect(photosRepo.uploadCount, 0);
      expect(tasksRepo.closedId, isNull);
    });

    testWidgets('verifying a closed task calls verifyTask', (tester) async {
      final tasksRepo = _FakeTasksAdminRepository();
      await _pump(tester, tasksRepo);

      // Verification lives on the Done list, which is where a manager goes
      // to sign work off.
      await tester.tap(find.byKey(const ValueKey('filter-done')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('verify-t-closed')));
      await tester.pumpAndSettle();

      expect(tasksRepo.verifiedId, 't-closed');
    });

    testWidgets('the refresh after closing never tears the list down to a '
        'spinner', (tester) async {
      // Closing invalidates tasksListProvider. Riverpod's
      // skipLoadingOnRefresh default keeps the last data on screen through
      // the refetch — this pins that: if a future provider dependency turns
      // the refresh into a fresh load, the list would flash a spinner AND
      // replay every cascade entrance, and this test fails instead.
      final tasksRepo = _FakeTasksAdminRepository();
      await _pump(tester, tasksRepo);

      await tester.tap(find.byKey(const ValueKey('close-t-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-closure')));

      // Walk the refresh frame by frame: at no point may the worklist be a
      // spinner instead of rows.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tasksRepo.closedId, 't-open');
      // The list is still standing, on data, post-refresh.
      expect(find.text('price_wrong'), findsOneWidget);
    });
  });
}
