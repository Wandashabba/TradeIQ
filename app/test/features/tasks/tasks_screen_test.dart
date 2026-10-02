import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/camera/photo_exposure.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/photo_geotagger.dart';
import 'package:tradeiq_app/core/design/tiq_number.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/input.dart';
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
    bool serverCounts = true,
    TaskCounts? counts,
  }) : tasks = FakeTasksRepository(
         tasks: tasks,
         nextCursor: nextCursor,
         total: total,
         listFailure: listFailure,
         closeFailure: closeFailure,
         listPending: listPending,
         serverCounts: serverCounts,
         counts: counts,
         // The fake's overdue and the screen's overdue are read at the same
         // instant, or a deadline is past on one side of the wire and not the
         // other.
         clock: () => _now,
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
  bool serverCounts = true,
  TaskCounts? counts,
  bool cameraCancels = false,
  double? luma,
  LocationService? location,
  TiqSkin? skin,
  double textScale = 1.0,
  Locale? locale,
}) async {
  final harness = _Harness(
    tasks: tasks,
    nextCursor: nextCursor,
    total: total,
    listFailure: listFailure,
    closeFailure: closeFailure,
    listPending: listPending,
    serverCounts: serverCounts,
    counts: counts,
  );
  await pumpWorklist(
    tester,
    TasksScreen(clock: () => _now),
    skin: skin,
    textScale: textScale,
    locale: locale,
    settle: !listPending,
    users: users,
    overrides: <Override>[
      tasksAdminRepositoryProvider.overrideWithValue(harness.tasks),
      photosRepositoryProvider.overrideWithValue(harness.photos),
      outletsRepositoryProvider.overrideWithValue(
        FakeOutletsRepository(outlets),
      ),
      // The guided capture measures the frame's exposure, and decoding an
      // image does not complete on FakeAsync's clock — see
      // `photo_exposure_test.dart`, which measures the real thing inside
      // `tester.runAsync`. Null is "nobody measured", never "bright".
      photoExposureProvider.overrideWithValue((String dataUrl) async => luma),
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

/// Take the closure photograph through the guided capture: the sheet's
/// "Take a photo" opens it, [source] is the camera or the gallery, and the
/// review step's "Use it" hands the frame back to the sheet.
Future<void> _takePhoto(
  WidgetTester tester, {
  String source = 'guided-capture',
  bool accept = true,
}) async {
  await tester.tap(find.byKey(const ValueKey<String>('take-closure-photo')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey<String>(source)));
  await tester.pumpAndSettle();
  if (accept) {
    await tester.tap(find.byKey(const ValueKey<String>('guided-use-it')));
    await tester.pumpAndSettle();
  }
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
  if (capture) await _takePhoto(tester);
}

/// The one hero figure in the lead card. Named, because the two subordinate
/// figures beside it are also numbers and a bare `find.text('0')` inside the
/// card matches whichever of the three happens to be nought.
final Finder _overdueFigure = find.byKey(
  const ValueKey<String>('tasks-overdue-figure'),
);

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

      // The label, the figure, and the two subordinates as FIGURES rather
      // than as a run-on sentence in a caption. `1 open · 1 awaiting
      // verification` was one string a reader had to parse; these are three
      // numbers on three baselines.
      final lead = find.byKey(const ValueKey<String>('tasks-lead'));
      expect(lead, findsOneWidget);
      expect(find.descendant(of: lead, matching: find.text('OVERDUE')),
          findsOneWidget);
      expect(
        find.descendant(of: _overdueFigure, matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.descendant(of: lead, matching: find.text('OPEN')),
          findsOneWidget);
      expect(
        find.descendant(
          of: lead,
          matching: find.text('AWAITING VERIFICATION'),
        ),
        findsOneWidget,
      );
      expect(find.text('Past the deadline and still open.'), findsOneWidget);
    });

    testWidgets('the figures are the account\'s, not the page\'s', (
      tester,
    ) async {
      // THE DEFECT, IN ONE TEST. The page holds two rows; the account holds
      // 32,368 tasks. Every figure above the list is the account's.
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(id: 'late', due: _now.subtract(const Duration(days: 2))),
          _task(id: 'open'),
        ],
        nextCursor: 'cursor-2',
        total: 1190,
        counts: const TaskCounts(
          all: 32368,
          open: 1190,
          overdue: 1122,
          done: 31178,
          awaitingVerification: 43,
        ),
      );

      final numbers = TiqNumber.en;
      final lead = find.byKey(const ValueKey<String>('tasks-lead'));
      expect(
        find.descendant(
          of: _overdueFigure,
          matching: find.text(numbers.format(1122)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lead, matching: find.text(numbers.format(1190))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lead, matching: find.text('43')),
        findsOneWidget,
      );
      // No em dash and no not-measured mark: the count was made.
      expect(
        find.descendant(of: lead, matching: find.text(emDash)),
        findsNothing,
      );
      expect(
        tester
            .widgetList<SeverityMark>(find.descendant(
              of: lead,
              matching: find.byType(SeverityMark),
            ))
            .single
            .kind,
        SeverityMarkKind.critical,
      );
    });

    testWidgets('every chip counts the whole account', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task()],
        nextCursor: 'cursor-2',
        counts: const TaskCounts(
          all: 32368,
          open: 1190,
          overdue: 1122,
          done: 31178,
          awaitingVerification: 43,
        ),
      );

      int countOn(String key) => tester
          .widget<TorchFilterChip>(find.byKey(ValueKey<String>('filter-$key')))
          .count!;
      expect(countOn('open'), 1190);
      expect(countOn('overdue'), 1122);
      // `Open 0 · Overdue 0 · Done 50 · All 50` is what this rail printed
      // over that account.
      await scrollRailTo(tester, find.byKey(const ValueKey<String>('filter-all')));
      expect(countOn('done'), 31178);
      expect(countOn('all'), 32368);
    });

    testWidgets('a chip fetches its own slice rather than filtering the page', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(),
          _task(id: 'closed', status: 'closed', outletId: 'o2'),
        ],
      );

      expect(harness.tasks.requestedStates.toSet(), <TaskState>{
        TaskState.open,
      });
      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-done')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-done')));
      await tester.pumpAndSettle();
      // The server was asked. Filtering the page in hand is what made `Open`
      // an empty list on an account with 1,190 open tasks: the page is the
      // oldest deadlines, and those are the closed ones.
      expect(harness.tasks.requestedStates.toSet(), <TaskState>{
        TaskState.open,
        TaskState.done,
      });
      expect(harness.tasks.requestedStates.last, TaskState.done);
    });

    testWidgets('a measured zero renders 0 and keeps its place', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets, tasks: <TaskItem>[_task()]);

      expect(
        find.descendant(of: _overdueFigure, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _overdueFigure, matching: find.text(emDash)),
        findsNothing,
      );
      expect(find.text('Nothing is past its deadline.'), findsOneWidget);
    });

    testWidgets('a High task and a Normal task can be told apart', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(
            id: 't-high',
            priority: 'high',
            due: _now.add(const Duration(days: 4)),
          ),
          _task(
            id: 't-normal',
            priority: 'normal',
            outletId: 'o2',
            due: _now.add(const Duration(days: 4)),
          ),
        ],
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('priority-t-normal')),
      );
      // The bar is the SLA: both rows are `watch`, so without the word the
      // axis the list is sorted by is invisible.
      final rows = tester.widgetList<SoftRow>(find.byType(SoftRow)).toList();
      expect(
        rows.every((r) => r.severity == SoftRowSeverity.watch),
        isTrue,
        reason: 'the premise: the bar cannot tell these two apart',
      );
      expect(find.text('High priority'), findsOneWidget);
      expect(find.text('Normal priority'), findsOneWidget);
    });

    testWidgets('a closed task drops the priority line, not the row', (
      tester,
    ) async {
      await _pump(
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
      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(
        find.byKey(const ValueKey<String>('priority-t-closed')),
        findsNothing,
        reason: 'a closed task has no priority left to act on',
      );
      expect(find.text('Critical priority'), findsNothing);
    });

    testWidgets('the row\'s verbs reach the semantics tree', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(),
          _task(id: 't-closed', status: 'closed', outletId: 'o2'),
        ],
      );

      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-all')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-all')));
      await tester.pumpAndSettle();
      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('verify-t-closed')),
      );

      // A button inside the row's excluded label paints and is announced
      // nowhere: a TalkBack manager hears the task and cannot close it.
      expect(
        find.bySemanticsLabel('Close with photo'),
        findsOneWidget,
        reason: 'the closure verb has to be a node, not only pixels',
      );
      expect(find.bySemanticsLabel('Verify'), findsOneWidget);
      handle.dispose();
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
          _task(
            id: 'late',
            due: _now.subtract(const Duration(days: 1)),
            findingType: 'b_late',
          ),
          _task(id: 'high', priority: 'high', findingType: 'c_high'),
        ],
      );

      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      final rows = tester.widgetList<SoftRow>(find.byType(SoftRow)).toList();
      // MOVED 26 September 2026: the row's first line is the store now, and
      // the finding is its second — a manager works a worklist by store, and
      // three rows all titled "Stockout" is a column of one repeated word.
      // The order this test is named for is unchanged and is read off the
      // line that still carries the finding.
      expect(rows.map((r) => r.subtitle).toList(), <String>[
        'B late',
        'C high',
        'A normal',
      ]);
    });
  });

  group('the filter rail', () {
    testWidgets('opens on Open, which includes overdue', (tester) async {
      final harness = await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(id: 'late', due: _now.subtract(const Duration(days: 1))),
          _task(id: 'closed', status: 'closed'),
        ],
      );

      // The rail IS the section marker now: the selected chip names the slice
      // and counts it, and the `SectionRule` that used to sit 20dp beneath it
      // printing the same word and a different number is gone.
      expect(find.byType(SectionRule), findsNothing);
      final chip = tester.widget<TorchFilterChip>(
        find.byKey(const ValueKey<String>('filter-open')),
      );
      expect(chip.selected, isTrue);
      expect(chip.label, 'Open');
      expect(chip.count, 1);
      expect(harness.tasks.requestedStates.toSet(), <TaskState>{
        TaskState.open,
      });
      await scrollWorklistTo(tester, find.byType(SoftRow).first);
      expect(find.byType(SoftRow), findsOneWidget);
    });

    testWidgets('Done shows closed work and All shows everything', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(),
          _task(id: 'closed', status: 'closed'),
        ],
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

    testWidgets('a real capture carries the gpsTag and a UTC capture time', (
      tester,
    ) async {
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
      await _takePhoto(tester);
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
    });

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
      await _takePhoto(tester);

      expect(find.text('The closure will record without one.'), findsOneWidget);

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
      await _takePhoto(tester, accept: false);
      // A cancelled camera never reaches the review step: there is nothing to
      // review. Closing the guided screen lands back on the gate, still
      // blocked, with no photo.
      expect(find.byKey(const ValueKey<String>('guided-use-it')), findsNothing);
      await tester.tap(find.byKey(const ValueKey<String>('guided-close')));
      await tester.pumpAndSettle();
      expect(find.text('A photo is required.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('cancel-closure')));
      await tester.pumpAndSettle();

      expect(harness.photos.uploadCount, 0);
      expect(harness.tasks.closedId, isNull);
    });

    testWidgets('the gallery is still a way to file the evidence', (
      tester,
    ) async {
      // A cracked camera in a dark aisle still has to be able to close a
      // task. The closure dialog this sheet replaced offered the gallery
      // through the guided capture, and the migration must not drop it.
      final harness = await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task()],
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('close-t-open')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
      await tester.pumpAndSettle();
      await _takePhoto(tester, source: 'guided-gallery');
      await tester.tap(find.byKey(const ValueKey<String>('confirm-closure')));
      await tester.pumpAndSettle();

      expect(harness.photos.uploadCount, 1);
      expect(harness.tasks.closedId, 't-open');
      await settleToasts(tester);
    });

    testWidgets('a dark frame the manager keeps says so on the gate', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task()],
        luma: 0.11,
      );

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('close-t-open')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
      await tester.pumpAndSettle();
      await _takePhoto(tester);

      expect(
        find.byKey(const ValueKey<String>('closure-dark')),
        findsOneWidget,
      );
      expect(find.text('Dark frame — mean brightness 11%'), findsOneWidget);
      // Kept, not refused: a dark photo may be the only evidence there is.
      final confirm = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('confirm-closure')),
      );
      expect(confirm.onPressed, isNotNull);
    });

    testWidgets('an unmeasured frame is never called dark', (tester) async {
      await _pump(tester, outlets: _outlets, tasks: <TaskItem>[_task()]);

      await scrollWorklistTo(
        tester,
        find.byKey(const ValueKey<String>('close-t-open')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('close-t-open')));
      await tester.pumpAndSettle();
      await _takePhoto(tester);

      expect(find.byKey(const ValueKey<String>('closure-dark')), findsNothing);
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
      expect(find.byKey(const ValueKey<String>('close-t-open')), findsNothing);
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
    testWidgets('nothing at all is a designed screen, not a wall of noughts', (
      tester,
    ) async {
      await _pump(tester, outlets: _outlets);

      // An account with no tasks under `OVERDUE 0` and four chips reading
      // zero is the scoreboard of noughts The Floor refuses with its
      // first-run board. The whole-screen empty state — the drawing, the
      // display headline and where tasks come from — is what the rest of this
      // app does with an empty route.
      final empty = tester.widget<EmptyState>(
        find.byKey(const ValueKey<String>('tasks-empty')),
      );
      expect(empty.scope, EmptyScope.wholeScreen);
      expect(empty.drawing, EmptyDrawing.shelf);
      expect(find.text('No tasks yet.'), findsOneWidget);
      expect(find.byType(EmptyStateDrawing), findsOneWidget);
      // No lead figure, no rail, no section marker.
      expect(find.byKey(const ValueKey<String>('tasks-lead')), findsNothing);
      expect(find.byType(TorchFilterRail), findsNothing);
      expect(find.byType(SectionRule), findsNothing);
    });

    testWidgets('a filter with nothing in it says what IS there', (
      tester,
    ) async {
      final harness = await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task(id: 't-closed', status: 'closed')],
        counts: const TaskCounts(
          all: 1190,
          open: 1190,
          overdue: 0,
          done: 0,
          awaitingVerification: 0,
        ),
      );
      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-overdue')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-overdue')));
      await tester.pumpAndSettle();

      expect(find.text('Nothing is overdue.'), findsOneWidget);
      // The counted figure, not "Clear the filter to see the rest."
      expect(
        find.text('1,190 tasks are open and inside their deadline.'),
        findsOneWidget,
      );
      // A ghost link, not a full-width outlined block — the treatment The
      // Floor uses for the one-tap way out of a scope that found nothing.
      expect(
        find.byKey(const ValueKey<String>('clear-filters')),
        findsOneWidget,
      );
      expect(
        tester.widgetList<TorchSecondaryButton>(
          find.byType(TorchSecondaryButton),
        ),
        isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey<String>('clear-filters')));
      await tester.pumpAndSettle();
      // The way back is one tap and it really re-asks: `All` is a slice of the
      // server's, not a `where` over the page already in hand.
      expect(harness.tasks.requestedStates.last, TaskState.all);
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
        tasks: <TaskItem>[
          _task(),
          _task(id: 't2', outletId: 'o2'),
        ],
        nextCursor: 'cursor-2',
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      expect(find.text('Showing the first 2. There are more.'), findsOneWidget);
      expect(find.textContaining('Narrow'), findsNothing);
      // THE LINE THAT WENT. The figures above the list are the account's now,
      // so scoping them to the page would be false.
      expect(find.textContaining('figures above are of these'), findsNothing);
      expect(find.textContaining('counts above are of these'), findsNothing);
    });

    testWidgets('a server that does not count keeps the scope sentence', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(),
          _task(id: 't2', outletId: 'o2'),
        ],
        nextCursor: 'cursor-2',
        serverCounts: false,
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      expect(find.text('The figures above are of these 2.'), findsOneWidget);
    });

    testWidgets('a cut list withholds the overdue verdict instead of '
        'painting a green zero', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        // Two open tasks, neither of them overdue ON THIS PAGE — and a server
        // that holds 74 and counts nothing. The page is ordered by deadline,
        // so overdue work can sit unloaded on page 2 and a zero here says
        // nothing about it.
        tasks: <TaskItem>[
          _task(id: 't1'),
          _task(id: 't2', outletId: 'o2'),
        ],
        nextCursor: 'cursor-2',
        total: 74,
        // The server this machinery exists for: one that answers a page and a
        // total and counts nothing.
        serverCounts: false,
      );

      final tile = _overdueFigure;
      // Not a measured nought: an em dash and the reason, because zero
      // overdue among the loaded rows says nothing about the rest.
      expect(
        find.descendant(of: tile, matching: find.text('0')),
        findsNothing,
        reason: 'a count over a cut page is not a count of the list',
      );
      expect(
        find.descendant(of: tile, matching: find.text(emDash)),
        findsOneWidget,
      );
      expect(
        find.textContaining('None among the 2 tasks loaded'),
        findsOneWidget,
      );
      // And no on-target circle over it: green is a verdict nobody measured.
      expect(
        tester
            .widgetList<SeverityMark>(find.byType(SeverityMark))
            .where((m) => m.kind == SeverityMarkKind.onTarget),
        isEmpty,
      );
      expect(
        tester
            .widgetList<SeverityMark>(find.byType(SeverityMark))
            .where((m) => m.kind == SeverityMarkKind.notMeasured)
            .length,
        1,
      );
    });

    testWidgets('a whole list still renders its measured zero', (tester) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[_task(id: 't1', status: 'closed')],
      );

      // The other half of the law: a measured zero keeps its place and its
      // on-target mark. Withholding it everywhere would be the same lie in
      // the other direction.
      expect(
        find.descendant(of: _overdueFigure, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<SeverityMark>(find.byType(SeverityMark))
            .where((m) => m.kind == SeverityMarkKind.onTarget)
            .length,
        1,
      );
    });

    testWidgets('a cut list with overdue work says how far the count goes', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(id: 'late', due: _now.subtract(const Duration(days: 2))),
        ],
        nextCursor: 'cursor-2',
        total: 74,
        serverCounts: false,
      );

      expect(
        find.descendant(of: _overdueFigure, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.textContaining('At least this many'),
        findsOneWidget,
        reason: 'a lower bound is not a total, and has to say so',
      );
    });

    testWidgets('a cut list with a server total names it, in the order used', (
      tester,
    ) async {
      await _pump(
        tester,
        outlets: _outlets,
        tasks: <TaskItem>[
          _task(),
          _task(id: 't2', outletId: 'o2'),
        ],
        nextCursor: 'cursor-2',
        total: 74,
      );

      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      // The slice is named, because the server applied it: these are a page
      // of the OPEN tasks, not of everything.
      expect(
        find.text(
          'Showing the 2 open tasks with the earliest deadlines, of 74.',
        ),
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

    testWidgets('with a photograph the sheet spends exactly one: Close task', (
      tester,
    ) async {
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
    });

    for (final skin in <TiqSkin>[TiqSkin.day()]) {
      testWidgets('${skin.mode.name}: the Send disc, alone', (tester) async {
        await _pump(
          tester,
          skin: skin,
          outlets: _outlets,
          tasks: <TaskItem>[_task()],
        );

        final census = await amberCensus(tester);
        expectWithinAmberBudget(census, skin, route: 'tasks', phase: 'loaded');
        // DAY PAINTS ONE SINCE MODEL 1. The pill's active tab was an
        // Abyssal block on a light ground and was never counted here; the
        // ask bar's Send is a `primaryCommit`, which is the one object
        // Day allows to be amber. Inside the budget of one. See
        // `ConsoleFrame`.
        expect(census.objectCount, 1, reason: census.describe());
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
    await scrollWorklistTo(
      tester,
      find.byKey(const ValueKey<String>('tasks-lead')),
    );
    // ── BY KEY, NOT BY `find.byType(SoftRow).first` — 2 October 2026 ─────
    //
    // `.first` is evaluated **eagerly** as an argument, so it throws
    // `Bad state: No element` whenever no row has been built yet rather than
    // scrolling until one is. That became reachable the day the ask bar
    // replaced the nav pill: the bar is taller than the 64dp pill at 2.0x, so
    // the lazy `ListView`'s viewport is shorter and on a 360x720 phone it
    // builds the rail and the lead and **no rows at all** on arrival. The
    // screen is correct and scrollable; the instrument was the thing that
    // could not survive one fewer built child.
    await scrollWorklistTo(
      tester,
      find.byKey(const ValueKey<String>('task-row-t-open')),
    );
    expect(find.byType(SoftRow), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('the amber census, every phase in every skin', () {
    /// Every phase this route can settle in, in every skin, counted.
    ///
    /// The worklists nominate no content amber, so the arithmetic is the same
    /// everywhere: Night paints the nav's active tab and nothing else; Day
    /// paints nothing, because its one rung is the primary commit block
    /// and a worklist has none armed.
    for (final skin in <TiqSkin>[
      TiqSkin.night(),
      TiqSkin.day(),
    ]) {
      // ── ONE IN BOTH SKINS SINCE MODEL 1 — 2 October 2026 ───────────
      //
      // It was `night ? 1 : 0`, and the 1 was the **nav pill's active tab**:
      // amber on Night, and on a light ground an Abyssal block rather than
      // amber, which is why Day counted zero. The pill is retired and the
      // bottom of every console screen is the ask bar, whose Send is a
      // `primaryCommit` — the one object Day permits to be amber.
      //
      // So Night's count does not move (the grant changed hands from chrome
      // to a control that commits something) and **Day goes 0 to 1**. That is
      // an honest increase, it is inside Day's budget of one, and it is the
      // first amber this route has ever painted on paper. See `ConsoleFrame`.
      const lit = 1;
      final phases = <String, Future<void> Function(WidgetTester)>{
        'loaded': (t) => _pump(
          t,
          skin: skin,
          outlets: _outlets,
          tasks: <TaskItem>[
            _task(due: _now.subtract(const Duration(days: 2))),
            _task(id: 't2', outletId: 'o2'),
          ],
          nextCursor: 'cursor-2',
          total: 74,
        ),
        'empty': (t) => _pump(t, skin: skin, outlets: _outlets),
        'filtered-empty': (t) async {
          await _pump(
            t,
            skin: skin,
            outlets: _outlets,
            tasks: <TaskItem>[_task(status: 'closed')],
          );
        },
        'loading': (t) async {
          await _pump(t, skin: skin, outlets: _outlets, listPending: true);
          await t.pump(const Duration(milliseconds: 700));
        },
        'error': (t) => _pump(
          t,
          skin: skin,
          listFailure: StateError('SocketException: api.tradeiq.co.za'),
        ),
      };
      for (final phase in phases.entries) {
        testWidgets('${skin.mode.name}, ${phase.key}: $lit', (tester) async {
          await phase.value(tester);
          final census = await amberCensus(tester);
          expectWithinAmberBudget(
            census,
            skin,
            route: 'tasks',
            phase: phase.key,
          );
          expect(census.objectCount, lit, reason: census.describe());
        });
      }
    }
  });

  group('Afrikaans', () {
    testWidgets('the footer groups its figures the way the locale does, '
        'and a long row survives 2.0x', (tester) async {
      await _pump(
        tester,
        locale: const Locale('af'),
        textScale: 2.0,
        outlets: <Outlet>[
          outlet('o1', 'Kwik Spar Bloemfontein-Noord Winkelsentrum'),
        ],
        tasks: <TaskItem>[
          _task(fix: 'Vervang die rakprysetiket en herstel die promosiebord'),
          _task(id: 't2'),
        ],
        nextCursor: 'cursor-2',
        total: 1284,
      );

      expect(tester.takeException(), isNull);
      await scrollWorklistTo(tester, find.byType(PaginationFooter));
      final total = TiqNumber.af.format(1284);
      expect(total, isNot(contains(',')));
      expect(
        find.text(
          'Showing the 2 open tasks with the earliest deadlines, of $total.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
