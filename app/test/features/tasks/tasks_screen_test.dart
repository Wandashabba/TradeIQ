import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/photo_geotagger.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/marks.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/state.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/tasks/presentation/tasks_screen.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

import '../../core/design/amber_golden.dart';
import '../worklist_harness.dart';

/// Wednesday 2026-07-22, midday. The screen takes its clock as an input, so
/// the tests own time.
final DateTime _now = DateTime(2026, 7, 22, 12);

/// The device clock at the shutter. Deliberately a LOCAL time, so the upload
/// has to convert it to UTC.
final DateTime _shutter = DateTime(2026, 7, 22, 12, 30, 15);

TaskItem _task({
  String id = 't-open',
  String findingType = 'out_of_stock',
  String fix = 'Restock SKU 42',
  String priority = 'critical',
  String status = 'open',
  bool verified = false,
  String outletId = 'o1',
  String? visitId = 'v1',
  String? photoId,
  DateTime? due,
  String? ownerId,
}) => TaskItem(
  id: id,
  findingType: findingType,
  requiredFix: fix,
  priority: priority,
  status: status,
  closureVerified: verified,
  outletId: outletId,
  visitId: visitId,
  evidencePhotoId: photoId,
  slaDueAt: due ?? _now.add(const Duration(days: 1)),
  ownerId: ownerId,
);

final List<Outlet> _outlets = <Outlet>[
  outlet('o1', 'Kasi Corner Spaza'),
  outlet('o2', 'Shoprite Klipspruit Mall'),
];

/// A camera that always returns the same four-byte "photo". The closure goes
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
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      name: 'closure.jpg',
      mimeType: 'image/jpeg',
    );
  }
}

/// Where the device is, as `getPositionIfPermitted` reports it — never
/// prompting, like the real no-prompt path.
class _FakeLocation extends LocationService {
  _FakeLocation(this.result);

  final LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> getPositionIfPermitted() async {
    calls++;
    return result;
  }
}

class _Harness {
  _Harness({
    List<TaskItem> tasks = const <TaskItem>[],
    String? nextCursor,
    int? total,
    Object? listFailure,
    Object? closeFailure,
    bool listPending = false,
  }) : tasks = FakeTasksRepository(
         tasks: tasks,
         nextCursor: nextCursor,
         total: total,
         listFailure: listFailure,
         closeFailure: closeFailure,
         listPending: listPending,
       );

  final FakeTasksRepository tasks;
  final FakePhotosRepository photos = FakePhotosRepository(bytes: pngBytes);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<TaskItem> tasks = const <TaskItem>[],
  List<Outlet> outlets = const <Outlet>[],
  List<AppUser> users = const <AppUser>[],
  String? nextCursor,
  int? total,
  Object? listFailure,
  Object? closeFailure,
  bool listPending = false,
  bool cameraCancels = false,
  LocationService? location,
  TiqSkin? skin,
  double textScale = 1.0,
}) async {
  final harness = _Harness(
    tasks: tasks,
    nextCursor: nextCursor,
    total: total,
    listFailure: listFailure,
    closeFailure: closeFailure,
    listPending: listPending,
  );
  await pumpWorklist(
    tester,
    TasksScreen(clock: () => _now),
    skin: skin,
    textScale: textScale,
    settle: !listPending,
    users: users,
    overrides: <Override>[
      tasksAdminRepositoryProvider.overrideWithValue(harness.tasks),
      photosRepositoryProvider.overrideWithValue(harness.photos),
      outletsRepositoryProvider.overrideWithValue(
        FakeOutletsRepository(outlets),
      ),
      photoCaptureServiceProvider.overrideWithValue(
        PhotoCaptureService(
          gateway: _FakeGateway(cancels: cameraCancels),
          geotagger: location == null
              ? null
              : PhotoGeotagger(location: location),
          clock: () => _shutter,
        ),
      ),
    ],
  );
  return harness;
}

/// Open the closure gate, optionally with a photograph already taken.
Future<void> _openClosureSheet(
  WidgetTester tester, {
  bool capture = false,
}) async {
  await scrollWorklistTo(
    tester,
    find.byKey(const ValueKey<String>('close-t-open')),
  );
  await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
  await tester.pumpAndSettle();
  if (capture) {
    await tester.tap(find.byKey(const ValueKey<String>('take-closure-photo')));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('the worklist', () {
    testWidgets('leads with overdue and subordinates the rest', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(id: 'late', due: _now.subtract(const Duration(days: 2))),
          _task(id: 'open'),
          _task(id: 'closed', status: 'closed'),
        ],
      );

      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('2 open · 1 awaiting verification'), findsOneWidget);
    });

    testWidgets('a measured zero renders 0 and keeps its place', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, tasks: <TaskItem>[_task()]);

      expect(
        find.descendant(of: find.byType(StatTile), matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StatTile),
          matching: find.text(emDash),
        ),
        findsNothing,
      );
    });

    testWidgets('the finding is the title, in words rather than a slug', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, tasks: <TaskItem>[_task()]);

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('out_of_stock'), findsNothing);
    });

    testWidgets('a row names the outlet, never its database id', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, tasks: <TaskItem>[_task()]);

      await scrollWorklistTo(tester, find.text('Kasi Corner Spaza'));
      expect(find.text('Kasi Corner Spaza'), findsOneWidget);
      expect(find.text('o1'), findsNothing);
    });

    testWidgets('an outlet the list cannot name reads as words, not its id', (
      tester,
    ) async {
      const uuid = '5f3c9a1e-2b7d-4c1f-9e0a-7d2b1c3e4f50';
      await _pump(tester, tasks: <TaskItem>[_task(outletId: uuid)]);

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.text('Outlet name unavailable'), findsOneWidget);
      expect(find.textContaining(uuid), findsNothing);
    });

    testWidgets('a row names the person who owns the fix', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        users: <AppUser>[
          person('u-1', 'thandi@acme.test', name: 'Thandi Mokoena'),
          person('u-2', 'sipho@acme.test'),
        ],
        tasks: <TaskItem>[
          _task(ownerId: 'u-1'),
          _task(id: 't-2', ownerId: 'u-2'),
        ],
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('owner-t-open')),
      );
      expect(find.text('Assigned to Thandi Mokoena'), findsOneWidget);
      // No display name: the sign-in address, which a person can read and
      // quote, rather than the id.
      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('owner-t-2')),
      );
      expect(find.text('Assigned to sipho@acme.test'), findsOneWidget);
      final row = tester.widget<SoftRow>(
        find.byKey(const ValueKey<String>('task-t-open')),
      );
      expect(row.semanticsLabel, contains('Assigned to Thandi Mokoena'));
    });

    testWidgets('an owner the roster cannot name is left out, not an id', (
      tester,
    ) async {
      const uuid = '0a1b2c3d-4e5f-6071-8293-a4b5c6d7e8f9';
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task(ownerId: uuid)],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byKey(const ValueKey<String>('owner-t-open')), findsNothing);
      expect(find.textContaining(uuid), findsNothing);
    });

    testWidgets('the SLA is a phrase with the fix, behind a silhouette', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(
            fix: 'Replace the shelf talker',
            due: _now.subtract(const Duration(days: 2)),
          ),
        ],
      );

      await scrollWorklistTo(
        tester,
        find.text('Overdue by 2 days · Replace the shelf talker'),
      );
      expect(
        find.text('Overdue by 2 days · Replace the shelf talker'),
        findsOneWidget,
      );
      expect(find.byType(SeverityMark), findsWidgets);
    });

    testWidgets('sorted overdue, critical, high, normal, closed', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(id: 'normal', priority: 'normal', findingType: 'a_normal'),
          _task(id: 'late', due: _now.subtract(const Duration(days: 1)),
              findingType: 'b_late'),
          _task(id: 'high', priority: 'high', findingType: 'c_high'),
        ],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      final rows = tester.widgetList<SoftRow>(find.byType(SoftRow)).toList();
      expect(
        rows.map((r) => r.title).toList(),
        <String>['B late', 'C high', 'A normal'],
      );
    });
  });

  group('the filter rail', () {
    testWidgets('opens on Open, which includes overdue', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(id: 'late', due: _now.subtract(const Duration(days: 1))),
          _task(id: 'closed', status: 'closed'),
        ],
      );

      await scrollWorklistTo(tester, find.byType(SectionRule));
      final rule = tester.widget<SectionRule>(find.byType(SectionRule));
      expect(rule.name, 'Open');
      expect(rule.count, 1);
    });

    testWidgets('Done shows closed work and All shows everything', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task(), _task(id: 'closed', status: 'closed')],
      );

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-done')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-done')));
      await tester.pumpAndSettle();
      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(SoftRow), findsOneWidget);

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-all')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-all')));
      await tester.pumpAndSettle();
      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(SoftRow), findsNWidgets(2));
    });
  });

  group('closing with a photo', () {
    testWidgets('Close task is disabled until there is one, and says why', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, tasks: <TaskItem>[_task()]);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('close-t-open')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
      await tester.pumpAndSettle();

      expect(find.byType(TorchSheet), findsOneWidget);
      final button = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('confirm-closure')),
      );
      // Disabled rather than hidden, so the reason is visible.
      expect(button.onPressed, isNull);
      expect(button.blockedReason, 'A photo is required.');
      expect(find.text('A photo is required.'), findsOneWidget);
    });

    testWidgets(
      'a real capture carries the gpsTag and a UTC capture time',
      (tester) async {
        final location = _FakeLocation(
          LocationGranted(-26.2041, 28.0473, accuracy: 12),
        );
        final harness = await _pump(
          tester,
          outlets: _outlets,
          tasks: <TaskItem>[_task()],
          location: location,
        );

        await scrollWorklistTo(
          tester,
          find.byKey(const ValueKey<String>('close-t-open')),
        );
        await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('take-closure-photo')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey<String>('confirm-closure')));
        await tester.pumpAndSettle();

        expect(harness.photos.uploadCount, 1);
        expect(harness.photos.uploadedSection, 'task_closure');
        expect(harness.photos.uploadedVisitId, 'v1');
        expect(harness.photos.uploadedGpsTag!['lat'], -26.2041);
        expect(
          harness.photos.uploadedTimestamp,
          _shutter.toUtc().toIso8601String(),
        );
        expect(harness.tasks.closedId, 't-open');
        expect(
          harness.tasks.closedPhotoUrl,
          'https://cdn.example.com/photo-1.png',
        );
        await settleToasts(tester);
      },
    );

    testWidgets('with no fix the closure still goes ahead, and says so', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task()],
        location: _FakeLocation(LocationDenied()),
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('close-t-open')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('take-closure-photo')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The closure will record without one.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('confirm-closure')));
      await tester.pumpAndSettle();
      expect(harness.photos.uploadedGpsTag, isEmpty);
      expect(harness.tasks.closedId, 't-open');
      await settleToasts(tester);
    });

    testWidgets('cancelling the camera leaves the task open', (tester) async {
      final harness = await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task()],
        cameraCancels: true,
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('close-t-open')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('take-closure-photo')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('cancel-closure')));
      await tester.pumpAndSettle();

      expect(harness.photos.uploadCount, 0);
      expect(harness.tasks.closedId, isNull);
    });

    testWidgets('a task with no visit offers no closure action at all', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task(visitId: null)],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(
        find.byKey(const ValueKey<String>('close-t-open')),
        findsNothing,
      );
    });
  });

  testWidgets('verifying a closed task calls verifyTask', (tester) async {
    final harness = await _pump(
      tester,
      outlets: _outlets,
      tasks: <TaskItem>[_task(id: 't-closed', status: 'closed')],
    );

    await scrollRailTo(
      tester,
      find.byKey(const ValueKey<String>('filter-done')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('filter-done')));
    await tester.pumpAndSettle();
    await scrollWorklistTo(
      tester,
      find.byKey(const ValueKey<String>('verify-t-closed')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('verify-t-closed')));
    await tester.pumpAndSettle();

    expect(harness.tasks.verifiedId, 't-closed');
  });

  group('the settled states', () {
    testWidgets('empty is a designed state, not a centred "No data"', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      expect(find.text('Nothing outstanding.'), findsOneWidget);
      expect(find.byType(SectionRule), findsOneWidget);
    });

    testWidgets('a failure is sanitised and offers one retry', (tester) async {
      await _pump(
        tester,
        listFailure: StateError('SocketException: api.tradeiq.co.za'),
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('api.tradeiq.co.za'), findsNothing);
      expect(find.byKey(const ValueKey<String>('tasks-retry')), findsOneWidget);
    });

    testWidgets('a cut list says so, and never invents a total', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task(), _task(id: 't2', outletId: 'o2')],
        nextCursor: 'cursor-2',
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      expect(
        find.text('Showing the first 2. There are more.'),
        findsOneWidget,
      );
      expect(find.textContaining('Narrow'), findsNothing);
      expect(find.text('The counts above are of these 2.'), findsOneWidget);
    });

    testWidgets('a cut list with a server total names it, in the order used', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task(), _task(id: 't2', outletId: 'o2')],
        nextCursor: 'cursor-2',
        total: 74,
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      expect(
        find.text('Showing the 2 tasks with the earliest deadlines, of 74.'),
        findsOneWidget,
      );
    });
  });

  group('the amber census', () {
    testWidgets('Night paints exactly one lit object: the nav tab', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(id: 'late', due: _now.subtract(const Duration(days: 2))),
          _task(id: 'open'),
        ],
      );

      final census = await amberCensus(tester);
      expectWithinAmberBudget(
        census,
        TiqSkin.night(),
        route: 'tasks',
        phase: 'loaded',
      );
      expect(
        census.objectCount,
        1,
        reason:
            'The overdue lead figure and the SLA phrasing carry the urgency; '
            'the filter chip is lifted, not lit.\n${census.describe()}',
      );
    });

    testWidgets('Night, empty, still paints exactly the nav tab', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets('Night, loading, still paints exactly the nav tab', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, listPending: true);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Skeleton), findsOneWidget);
      final census = await amberCensus(tester);
      expect(census.objectCount, 1, reason: census.describe());
    });

    testWidgets(
      'an unarmed closure sheet is dark, and so is the route beneath it',
      (tester) async {
        await _pump(tester, outlets: _outlets, tasks: <TaskItem>[_task()]);
        await _openClosureSheet(tester);

        final census = await amberCensus(tester);
        expect(
          census.objectCount,
          0,
          reason:
              'Zero when nothing is armed. The commit is disabled until there '
              'is a photograph, so it takes its unlit form — and while a '
              'sheet is up every amber beneath it goes out, so the nav tab is '
              'in its ink form too.\n${census.describe()}',
        );
      },
    );

    testWidgets(
      'with a photograph the sheet spends exactly one: Close task',
      (tester) async {
        await _pump(
          tester,
          outlets: _outlets,
          tasks: <TaskItem>[_task()],
          location: _FakeLocation(LocationGranted(-26.2041, 28.0473)),
        );
        await _openClosureSheet(tester, capture: true);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          TiqSkin.night(),
          route: 'tasks/close-with-photo',
          phase: 'sheet',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'A sheet is an untabbed route with two Night grants, and it '
              'spends one — the commit. The nav tab beneath has gone '
              'out.\n${census.describe()}',
        );
      },
    );

    for (final skin in <TiqSkin>[TiqSkin.day(), TiqSkin.veld()]) {
      testWidgets('${skin.mode.name} paints no amber at all', (tester) async {
        await _pump(
          tester,
          skin: skin,
          outlets: _outlets,
          tasks: <TaskItem>[_task()],
        );

        final census = await amberCensus(tester);
        expectWithinAmberBudget(census, skin, route: 'tasks', phase: 'loaded');
        expect(census.objectCount, 0, reason: census.describe());
      });

      testWidgets('${skin.mode.name} lights the closure sheet\'s commit', (
        tester,
      ) async {
        await _pump(
          tester,
          skin: skin,
          outlets: _outlets,
          tasks: <TaskItem>[_task()],
          location: _FakeLocation(LocationGranted(-26.2041, 28.0473)),
        );
        await _openClosureSheet(tester, capture: true);

        final census = await amberCensus(tester);
        expectWithinAmberBudget(census, skin, route: 'tasks', phase: 'sheet');
        expect(
          census.objectCount,
          1,
          reason:
              'On a light ground the one amber block is the primary commit '
              'action, and here it is Close task.\n${census.describe()}',
        );
      });
    }
  });

  testWidgets('2.0x text: the structure survives and nothing overflows', (
    tester,
  ) async {
    await _pump(
      tester,
      textScale: 2.0,
      outlets: _outlets,
      tasks: <TaskItem>[
        _task(),
        _task(id: 't2', priority: 'normal', outletId: 'o2'),
      ],
    );

    expect(tester.takeException(), isNull);
    await scrollWorklistTo(tester, find.byType(SectionRule));
    await scrollWorklistTo(tester, find.byType(SoftRow).first);
    expect(find.byType(SoftRow), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
