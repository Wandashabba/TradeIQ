import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/tasks/presentation/tasks_screen.dart';

import '../../helpers/routed_app.dart';

const _openTask = TaskItem(
  id: 't-open',
  findingType: 'out_of_stock',
  requiredFix: 'Restock SKU 42',
  priority: 'critical',
  status: 'open',
  closureVerified: false,
  outletId: 'o1',
  visitId: 'v1',
);

const _closedTask = TaskItem(
  id: 't-closed',
  findingType: 'price_wrong',
  requiredFix: 'Correct shelf price',
  priority: 'normal',
  status: 'closed',
  closurePhotoUrl: 'https://cdn.example.com/old.png',
  closureVerified: false,
  outletId: 'o2',
  visitId: 'v2',
);

class _FakeTasksAdminRepository implements TasksAdminRepository {
  String? closedId;
  String? closedPhotoUrl;
  String? verifiedId;

  @override
  Future<PaginatedResponse<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async =>
      const PaginatedResponse(data: [_openTask, _closedTask], nextCursor: null);

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
    );
  }
}

class _RecordingPhotosRepository implements PhotosRepository {
  int uploadCount = 0;
  String? uploadedSection;
  String? uploadedVisitId;
  String? uploadedDataUrl;

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
}) =>
    routedApp(
      const TasksScreen(),
      overrides: [
        tasksAdminRepositoryProvider.overrideWithValue(tasksRepo),
        photosRepositoryProvider.overrideWithValue(photosRepo),
        photoCaptureServiceProvider.overrideWithValue(
          PhotoCaptureService(gateway: _FakeGateway(cancels: cameraCancels)),
        ),
      ],
    );

void main() {
  testWidgets('opens on the still-open tasks', (tester) async {
    await tester.pumpWidget(_app(
      _FakeTasksAdminRepository(),
      _RecordingPhotosRepository(),
    ));
    await tester.pumpAndSettle();

    // The worklist defaults to Open — a closed task is one tab away, not gone.
    expect(find.text('out_of_stock'), findsOneWidget);
    expect(find.text('price_wrong'), findsNothing);
  });

  testWidgets('the All tab reveals closed tasks', (tester) async {
    await tester.pumpWidget(_app(
      _FakeTasksAdminRepository(),
      _RecordingPhotosRepository(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-_Tab.all')));
    await tester.pumpAndSettle();

    expect(find.text('out_of_stock'), findsOneWidget);
    expect(find.text('price_wrong'), findsOneWidget);
  });

  testWidgets('closing an open task uploads a photo and closes with its url',
      (tester) async {
    final tasksRepo = _FakeTasksAdminRepository();
    final photosRepo = _RecordingPhotosRepository();
    await tester.pumpWidget(_app(tasksRepo, photosRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('close-t-open')));
    await tester.pumpAndSettle();

    // Closure is gated on evidence: until a photo exists, the button is dead.
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
  });

  testWidgets('the closure photo is a real capture, not a placeholder', (
    tester,
  ) async {
    // The whole point of #41: "photo-verified closure" verified nothing while
    // the app uploaded a 1×1 transparent PNG.
    final photosRepo = _RecordingPhotosRepository();
    await tester.pumpWidget(_app(_FakeTasksAdminRepository(), photosRepo));
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(
      _app(tasksRepo, photosRepo, cameraCancels: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('close-t-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-camera')));
    await tester.pumpAndSettle();

    // No photo captured → the confirm stays disabled and nothing was closed.
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('confirm-closure')))
          .onPressed,
      isNull,
    );
    expect(photosRepo.uploadCount, 0);
    expect(tasksRepo.closedId, isNull);
  });

  testWidgets('verifying a closed task calls verifyTask', (tester) async {
    final tasksRepo = _FakeTasksAdminRepository();
    final photosRepo = _RecordingPhotosRepository();
    await tester.pumpWidget(_app(tasksRepo, photosRepo));
    await tester.pumpAndSettle();

    // Verification lives on the closed list, which is where a manager goes to
    // sign work off.
    await tester.tap(find.byKey(const ValueKey('tab-_Tab.closed')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('verify-t-closed')));
    await tester.pumpAndSettle();

    expect(tasksRepo.verifiedId, 't-closed');
  });
}
