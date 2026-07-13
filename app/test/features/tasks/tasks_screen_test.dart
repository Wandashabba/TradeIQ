import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
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
  Future<List<TaskItem>> listTasks({
    String? status,
    String? priority,
    String? outletId,
  }) async =>
      const [_openTask, _closedTask];

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
    return const PhotoUploadResult(
      id: 'photo-1',
      url: 'https://cdn.example.com/photo-1.png',
    );
  }
}

Widget _app(
  _FakeTasksAdminRepository tasksRepo,
  _RecordingPhotosRepository photosRepo,
) =>
    routedApp(
      const TasksScreen(),
      overrides: [
        tasksAdminRepositoryProvider.overrideWithValue(tasksRepo),
        photosRepositoryProvider.overrideWithValue(photosRepo),
      ],
    );

void main() {
  testWidgets('renders task finding types once loaded', (tester) async {
    await tester.pumpWidget(_app(
      _FakeTasksAdminRepository(),
      _RecordingPhotosRepository(),
    ));
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

    expect(photosRepo.uploadCount, 1);
    expect(photosRepo.uploadedSection, 'task_closure');
    expect(photosRepo.uploadedVisitId, 'v1');
    expect(tasksRepo.closedId, 't-open');
    expect(tasksRepo.closedPhotoUrl, 'https://cdn.example.com/photo-1.png');
  });

  testWidgets('verifying a closed task calls verifyTask', (tester) async {
    final tasksRepo = _FakeTasksAdminRepository();
    final photosRepo = _RecordingPhotosRepository();
    await tester.pumpWidget(_app(tasksRepo, photosRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('verify-t-closed')));
    await tester.pumpAndSettle();

    expect(tasksRepo.verifiedId, 't-closed');
  });
}
