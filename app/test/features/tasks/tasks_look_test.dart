import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/camera/photo_exposure.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/outlets/data/outlets_repository.dart';
import 'package:tradeiq_app/features/tasks/data/tasks_admin_repository.dart';
import 'package:tradeiq_app/features/tasks/presentation/tasks_screen.dart';
import 'package:tradeiq_app/features/users/data/users_repository.dart';

import '../agent_harness.dart';
import '../worklist_harness.dart';

/// TASKS, RENDERED, SO SOMEBODY CAN LOOK AT IT.
///
/// Every other test in this folder asserts a number. This one produces the
/// eight images the owner and the reviewer look at: four states of the screen
/// in **both** skins, at 390×844, with Schibsted Grotesk and JetBrains Mono loaded. The
/// test font is wider than Schibsted Grotesk, so a screen rendered in it wraps sooner and
/// measures taller — a picture of the wrong screen.
///
/// The four states are chosen because each one is a different claim the page
/// makes about what it knows:
///
/// | state | what it has to get right |
/// |---|---|
/// | `overdue` | the account's real figures over a cut page — 1,122 overdue of 32,368, which is the shape that used to render as `Open 0 · Overdue 0 · Done 50` |
/// | `clear` | a **measured zero**: `0`, full size, with the on-target mark and a sentence — never an em dash, and never a hidden tile |
/// | `filtered-empty` | a filter with nothing in it saying what IS there, in counted figures |
/// | `empty` | an account with no tasks: a designed screen, not a lead card reading `OVERDUE 0` over four zeroed chips |
///
/// Day is not a courtesy. The skin gained semantic green and crimson on
/// figures on 28 September 2026, and this screen puts one of each on the head
/// of the page — the `clear` pair is where that has to be looked at.
///
/// ## Why it does not run in CI
///
/// The reason `floor_look_test.dart` and `colour_look_test.dart` give: CI
/// rasterises anti-aliased Schibsted Grotesk on `ubuntu-latest` and this repository is
/// developed on macOS, so a pixel comparison fails on the day it lands and
/// gets skipped within a week. The images are an artefact to *look at*; the
/// pins are the measurements in `tasks_screen_test.dart` and
/// `tasks_view_test.dart`, which do run everywhere.
///
/// ```sh
/// TASKS_LOOK=1 TASKS_LOOK_DIR=/somewhere/ flutter test \
///   test/features/tasks/tasks_look_test.dart --update-goldens
/// ```
///
/// **`TASKS_LOOK_SIZE=360x640`** shoots the same screens on the cheap-Android
/// width. The default stays 390×844, so the committed goldens are byte-for-byte
/// what they were; the size travels into the filename, so the two sets never
/// overwrite one another.
/// **`TASKS_LOOK_SCALE=1.3`** shoots the same screens at the text scale a
/// cheap Android ships with the accessibility slider nudged once. The default
/// stays 1.0, so the committed goldens are byte-for-byte what they were, and
/// the scale travels into the filename so the two sets never collide. It is
/// the frame that decides whether the ask bar still fits a 640dp fold.
void main() {
  final looking = Platform.environment['TASKS_LOOK'] == '1';
  final dir = Platform.environment['TASKS_LOOK_DIR'] ?? 'goldens/';
  final scale = _scaleFromEnv();
  final sfx = _scaleTag(scale);
  final phone = _sizeFromEnv() ?? const Size(390, 844);
  final tag = '${phone.width.toInt()}x${phone.height.toInt()}';

  setUpAll(() async {
    await loadAgentFonts();
    await _loadIcons();
  });

  /// Wednesday 2026-07-22, midday. The screen takes its clock as an input, so
  /// every deadline in these pictures is read at one instant.
  final now = DateTime(2026, 7, 22, 12);

  final outlets = <Outlet>[
    outlet('o1', 'Kasi Corner Spaza'),
    outlet('o2', 'Shoprite Klipspruit Mall'),
    outlet('o3', 'SaveMor Glenwood'),
    outlet('o4', 'Pick n Pay Rosebank'),
    outlet('o5', 'Corner Express Parkhurst'),
    outlet('o6', 'Boxer Superstore Tembisa'),
  ];

  final roster = <AppUser>[
    person('u-1', 'thandi@acme.test', name: 'Thandi Mokoena'),
    person('u-2', 'sipho@acme.test', name: 'Sipho Dlamini'),
    person('u-3', 'naledi@acme.test', name: 'Naledi Khumalo'),
  ];

  TaskItem task({
    required String id,
    required String findingType,
    required String fix,
    required String outletId,
    required String priority,
    required Duration due,
    String status = 'open',
    bool verified = false,
    String? ownerId,
    String? photoId,
  }) => TaskItem(
    id: id,
    findingType: findingType,
    requiredFix: fix,
    priority: priority,
    status: status,
    closureVerified: verified,
    outletId: outletId,
    visitId: 'v-$id',
    evidencePhotoId: photoId,
    slaDueAt: now.add(due),
    createdAt: now.subtract(const Duration(days: 9)),
    ownerId: ownerId,
  );

  /// A real account: work past its deadline, at the top of a cut page.
  final overdueWork = <TaskItem>[
    task(
      id: 't1',
      findingType: 'out_of_stock',
      fix: 'Restock the 2L cola facings on the main aisle',
      outletId: 'o1',
      priority: 'critical',
      due: const Duration(days: -4),
      ownerId: 'u-1',
      photoId: 'p1',
    ),
    task(
      id: 't2',
      findingType: 'shelf_talker_missing',
      fix: 'Replace the shelf talker on the promotional end cap',
      outletId: 'o2',
      priority: 'critical',
      due: const Duration(days: -2),
      ownerId: 'u-2',
    ),
    task(
      id: 't3',
      findingType: 'price_deviation',
      fix: 'Correct the shelf price against the published band',
      outletId: 'o3',
      priority: 'high',
      due: const Duration(days: -1),
      ownerId: 'u-3',
      photoId: 'p2',
    ),
    task(
      id: 't4',
      findingType: 'planogram_breach',
      fix: 'Rebuild the planogram on bay 4',
      outletId: 'o4',
      priority: 'high',
      due: const Duration(hours: 6),
      ownerId: 'u-1',
    ),
    task(
      id: 't5',
      findingType: 'competitor_encroachment',
      fix: 'Reclaim the two facings lost to the competitor',
      outletId: 'o5',
      priority: 'normal',
      due: const Duration(days: 3),
      ownerId: 'u-2',
    ),
  ];

  /// The same account a fortnight later: everything open, nothing late.
  final clearWork = <TaskItem>[
    task(
      id: 'c1',
      findingType: 'out_of_stock',
      fix: 'Restock the 2L cola facings on the main aisle',
      outletId: 'o1',
      priority: 'high',
      due: const Duration(hours: 20),
      ownerId: 'u-1',
      photoId: 'p1',
    ),
    task(
      id: 'c2',
      findingType: 'shelf_talker_missing',
      fix: 'Replace the shelf talker on the promotional end cap',
      outletId: 'o2',
      priority: 'normal',
      due: const Duration(days: 2),
      ownerId: 'u-2',
    ),
    task(
      id: 'c3',
      findingType: 'price_deviation',
      fix: 'Correct the shelf price against the published band',
      outletId: 'o6',
      priority: 'normal',
      due: const Duration(days: 4),
      ownerId: 'u-3',
    ),
    task(
      id: 'c4',
      findingType: 'planogram_breach',
      fix: 'Rebuild the planogram on bay 4',
      outletId: 'o4',
      priority: 'normal',
      due: const Duration(days: 5),
      ownerId: 'u-1',
    ),
  ];

  Future<FakeTasksRepository> pump(
    WidgetTester tester, {
    required TiqSkin skin,
    required List<TaskItem> tasks,
    required TaskCounts? counts,
    String? nextCursor,
    int? total,
    double textScale = 1.0,
  }) async {
    final repo = FakeTasksRepository(
      tasks: tasks,
      counts: counts,
      nextCursor: nextCursor,
      total: total,
      clock: () => now,
    );
    await pumpWorklist(
      tester,
      TasksScreen(clock: () => now),
      skin: skin,
      size: phone,
      textScale: textScale,
      users: roster,
      banner: false,
      overrides: <Override>[
        tasksAdminRepositoryProvider.overrideWithValue(repo),
        outletsRepositoryProvider.overrideWithValue(
          FakeOutletsRepository(outlets),
        ),
        photosRepositoryProvider.overrideWithValue(
          FakePhotosRepository(bytes: pngBytes),
        ),
        // Decoding an image never completes on FakeAsync's clock. No screen in
        // this file opens the capture path, but the override is cheap and its
        // absence is a ten-minute hang rather than a failure.
        photoExposureProvider.overrideWithValue((String dataUrl) async => null),
      ],
    );
    return repo;
  }

  const skins = <(String, SkinMode)>[
    ('night', SkinMode.night),
    ('day', SkinMode.day),
  ];

  TiqSkin console(SkinMode mode) => mode == SkinMode.night
      ? TiqSkin.night(density: TiqDensity.console)
      : TiqSkin.day(density: TiqDensity.console);

  for (final (name, mode) in skins) {
    // ── 0. MID-SCROLL, WHICH IS THE PICTURE THE BAR WAS CHANGED FOR ─────
    //
    // The owner's screenshot of this screen showed a task sentence cut
    // mid-word at the bottom of the list. It is not an overlap — the bottom
    // region and the band are both siblings of the scroll view, and
    // `torch_shell_band_test.dart` counts zero body pixels inside the band's
    // box — it is the `ListView`'s own hard clip at its viewport's bottom
    // edge, and at rest you cannot see it because the body's bottom padding
    // is empty. **You have to drag the list to photograph the defect.**
    //
    // So this frame is dragged. It is the one image in the set where
    // `TorchShell.bandScrimExtent` has anything to do, and the thing to look
    // at is the last partially-visible row: it should go out, not stop.
    testWidgets('Tasks — mid-scroll, the clip under the bar, $name', (
      tester,
    ) async {
      await pump(
        tester,
        textScale: scale,
        skin: console(mode),
        tasks: overdueWork,
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
      // Half a row, so the clip falls through a line of prose rather than
      // between two cards.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}tasks_$tag-midscroll-$name$sfx.png'),
      );
    }, skip: !looking);

    // ── 1. Populated, with overdue work ──────────────────────────────────
    //
    // The account the defect was found on, to the figure: 32,368 tasks, 1,190
    // of them open and 1,122 of those past their deadline. The page is cut, so
    // the footer says which slice these five rows are a page of.
    testWidgets('Tasks — overdue work, $name', (tester) async {
      await pump(
        tester,
        textScale: scale,
        skin: console(mode),
        tasks: overdueWork,
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

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}tasks_$tag-overdue-$name$sfx.png'),
      );
    }, skip: !looking);

    // ── 2. Populated, nothing overdue ────────────────────────────────────
    //
    // The measured zero, at full size, with the on-target mark and a sentence.
    // This is the picture that proves the lead figure is not simply "crimson
    // or absent" — a nought that has been counted is a fact worth reading.
    testWidgets('Tasks — nothing overdue, $name', (tester) async {
      await pump(
        tester,
        textScale: scale,
        skin: console(mode),
        tasks: clearWork,
        counts: const TaskCounts(
          all: 214,
          open: 4,
          overdue: 0,
          done: 210,
          awaitingVerification: 2,
        ),
      );

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}tasks_$tag-clear-$name$sfx.png'),
      );
    }, skip: !looking);

    // ── 3. A filter with nothing in it ───────────────────────────────────
    //
    // Reached the way a manager reaches it: by pressing Overdue on an account
    // where nothing is. The body is the counted figure, not "Clear the filter
    // to see the rest", and the way back is a ghost link.
    testWidgets('Tasks — the filter found nothing, $name', (tester) async {
      await pump(
        tester,
        textScale: scale,
        skin: console(mode),
        tasks: clearWork,
        counts: const TaskCounts(
          all: 214,
          open: 4,
          overdue: 0,
          done: 210,
          awaitingVerification: 2,
        ),
      );
      await scrollRailTo(
        tester,
        find.byKey(const ValueKey<String>('filter-overdue')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('filter-overdue')));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}tasks_$tag-filtered-empty-$name$sfx.png'),
      );
    }, skip: !looking);

    // ── 4. An account with no tasks at all ───────────────────────────────
    testWidgets('Tasks — nothing filed at all, $name', (tester) async {
      await pump(
        tester,
        textScale: scale,
        skin: console(mode),
        tasks: const <TaskItem>[],
        counts: const TaskCounts(
          all: 0,
          open: 0,
          overdue: 0,
          done: 0,
          awaitingVerification: 0,
        ),
      );

      await expectLater(
        find.byKey(const ValueKey<String>('amber-golden-boundary')),
        matchesGoldenFile('${dir}tasks_$tag-empty-$name$sfx.png'),
      );
    }, skip: !looking);
  }
}

/// The icon font, out of the Flutter SDK's own cache.
///
/// It is not in the test asset bundle, so without this every glyph in these
/// pictures is a hollow box — the header's refresh control and all four nav
/// destinations. That is harmless in a test that measures something and wrong
/// in a picture somebody looks at to judge whether a screen is finished.
///
/// Its absence is **silent**. The path is derived from the dart that is
/// running this test, which is the one inside the SDK; a look test has no
/// business failing over an icon on a machine that keeps its SDK somewhere
/// else, and the pictures are still readable without it.
Future<void> _loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  final cache = root != null
      ? Directory('$root/bin/cache')
      : File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File(
    '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;
  await (FontLoader('MaterialIcons')
        ..addFont(
          font.readAsBytes().then((b) => ByteData.view(b.buffer)),
        ))
      .load();
}

/// `TASKS_LOOK_SIZE=360x640` → `Size(360, 640)`; anything else → null.
///
/// The same contract `agent_look_test.dart` carries, for the same reason: the
/// prose face and the type scale both moved on 1 October 2026 and every
/// harness had to be re-shot at the cheap-Android width as well as the
/// reference phone. Silent on a malformed value on purpose — these images are
/// an artefact to look at, and a throw here would read as a broken screen
/// rather than as a typo in a shell variable.
Size? _sizeFromEnv() {
  final raw = Platform.environment['TASKS_LOOK_SIZE'];
  if (raw == null) return null;
  final parts = raw.toLowerCase().split('x');
  if (parts.length != 2) return null;
  final w = double.tryParse(parts[0]);
  final h = double.tryParse(parts[1]);
  if (w == null || h == null || w <= 0 || h <= 0) return null;
  return Size(w, h);
}

/// `TASKS_LOOK_SCALE=1.3` -> 1.3; absent or malformed -> 1.0.
///
/// Silent on a bad value for the same reason the size switch is: these images
/// are an artefact to look at, and a typo should produce the reference frame
/// rather than a crash in a tool somebody is using to see a screen.
double _scaleFromEnv() {
  final raw = Platform.environment['TASKS_LOOK_SCALE'];
  final parsed = raw == null ? null : double.tryParse(raw);
  if (parsed == null || parsed < 1.0 || parsed > 3.0) return 1.0;
  return parsed;
}

/// The scale's mark in a golden's name. Empty at 1.0, so every committed
/// filename is unchanged.
String _scaleTag(double scale) =>
    scale == 1.0 ? '' : '-x${(scale * 10).round()}';
