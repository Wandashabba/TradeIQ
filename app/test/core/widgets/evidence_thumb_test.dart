import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/evidence_thumb.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';

/// A real, decodable image: the canonical 1×1 transparent PNG.
final _pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakePhotosRepository implements PhotosRepository {
  _FakePhotosRepository({this.failThumb = false});

  final bool failThumb;
  int thumbnailCalls = 0;
  int listCalls = 0;
  String? listedVisitId;

  /// Overrides the default two-row visit when set.
  List<VisitPhoto>? photos;

  /// While set, every listPhotos call throws. Mutable and PERSISTENT rather
  /// than fail-once: Riverpod 3 auto-retries failed providers with backoff,
  /// so a one-shot failure self-heals the moment a settle advances the clock
  /// — the test flips this off itself when it wants recovery.
  bool failList = false;

  /// When set, thumbnailBytes parks on it instead of resolving — the test
  /// controls "still loading".
  Completer<Uint8List>? thumbGate;

  /// Same, for listPhotos.
  Completer<List<VisitPhoto>>? listGate;

  @override
  Future<Uint8List> thumbnailBytes(String photoId) {
    thumbnailCalls++;
    if (failThumb) return Future.error(Exception('boom'));
    return thumbGate?.future ?? Future.value(_pngBytes);
  }

  @override
  Future<List<VisitPhoto>> listPhotos(String visitId) {
    listCalls++;
    listedVisitId = visitId;
    if (failList) return Future.error(Exception('boom'));
    final override = photos;
    if (override != null) return Future.value(override);
    return listGate?.future ??
        Future.value([
          VisitPhoto(
            id: 'p-new',
            section: 'shelf',
            url: 'data:image/png;base64,${base64Encode(_pngBytes)}',
            timestamp: '2026-07-22T10:00:00.000Z',
          ),
          const VisitPhoto(
            id: 'p-old',
            section: 'shelf',
            url: 'data:image/png;base64,AQID', // not decodable — must not show
            timestamp: '2026-07-21T10:00:00.000Z',
          ),
        ]);
  }

  @override
  Future<PhotoUploadResult> uploadPhoto({
    required String visitId,
    required String section,
    required String dataUrl,
    required Map<String, dynamic> gpsTag,
    required String timestamp,
  }) async => throw UnimplementedError();

  @override
  Future<String> uploadMessageAttachment(String dataUrl) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> imageBytes(String photoId) async =>
      throw UnimplementedError();
}

Widget _app(
  _FakePhotosRepository repo, {
  Widget? child,
  ThemeData? theme,
}) => ProviderScope(
  overrides: [photosRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: child ?? const EvidenceThumb(photoId: 'p-new', visitId: 'v1'),
      ),
    ),
  ),
);

void main() {
  testWidgets('while loading it is a neutral surface2 box — no spinner, no '
      'broken-image icon', (tester) async {
    final repo = _FakePhotosRepository()..thumbGate = Completer();
    await tester.pumpWidget(_app(repo));
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(EvidenceThumb),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, TiqColors.dark.surface2);
    expect(decoration.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('renders the fetched bytes as a 44×44 cover Image.memory', (
    tester,
  ) async {
    final repo = _FakePhotosRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(EvidenceThumb),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<MemoryImage>());
    expect(image.width, 44);
    expect(image.height, 44);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('a failed fetch degrades to the neutral box, never a broken '
      'icon', (tester) async {
    final repo = _FakePhotosRepository(failThumb: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.broken_image), findsNothing);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(EvidenceThumb),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, TiqColors.dark.surface2);
  });

  group('Lumen Glass (light)', () {
    testWidgets('the empty slot is a rimmed surface3 box — still no spinner', (
      tester,
    ) async {
      final repo = _FakePhotosRepository()..thumbGate = Completer();
      await tester.pumpWidget(_app(repo, theme: AppTheme.light()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(EvidenceThumb),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, TiqColors.light.surface3);
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(
        (decoration.border! as Border).top.color,
        LumenPalette.light.tileRim,
      );
    });

    testWidgets('the photo is clipped to the chip radius under a rim, '
        'untinted', (tester) async {
      await tester.pumpWidget(
        _app(_FakePhotosRepository(), theme: AppTheme.light()),
      );
      await tester.pumpAndSettle();

      final thumb = find.byType(EvidenceThumb);
      final clip = tester.widget<ClipRRect>(
        find.descendant(of: thumb, matching: find.byType(ClipRRect)),
      );
      expect(clip.borderRadius, BorderRadius.circular(8));

      final rim = tester.widget<DecoratedBox>(
        find.descendant(of: thumb, matching: find.byType(DecoratedBox)),
      );
      expect(rim.position, DecorationPosition.foreground);
      final decoration = rim.decoration as BoxDecoration;
      expect(decoration.color, isNull);
      expect(
        (decoration.border! as Border).top.color,
        LumenPalette.light.tileRim,
      );
      // The evidence itself is unchanged: the same 44×44 cover image.
      final image = tester.widget<Image>(
        find.descendant(of: thumb, matching: find.byType(Image)),
      );
      expect(image.width, 44);
      expect(image.fit, BoxFit.cover);
    });
  });

  testWidgets('carries the "Shelf photo evidence" image semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_FakePhotosRepository()));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(EvidenceThumb)),
      matchesSemantics(
        label: 'Shelf photo evidence',
        isImage: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('two thumbs of the same photo cost one repository fetch', (
    tester,
  ) async {
    final repo = _FakePhotosRepository();
    await tester.pumpWidget(
      _app(
        repo,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EvidenceThumb(photoId: 'p-new', visitId: 'v1'),
            EvidenceThumb(photoId: 'p-new', visitId: 'v1'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.thumbnailCalls, 1);
  });

  testWidgets('tap opens the full-photo dialog, fetched lazily on open', (
    tester,
  ) async {
    final repo = _FakePhotosRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Lazy means lazy: rendering the thumb must not fetch the full photo.
    expect(repo.listCalls, 0);

    await tester.tap(find.byKey(const ValueKey('evidence-thumb-p-new')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('evidence-dialog')), findsOneWidget);
    expect(repo.listCalls, 1);
    expect(repo.listedVisitId, 'v1');
    // The newest photo's bytes, decoded from its data URL, inside the dialog.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('evidence-dialog')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('evidence-dialog-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('evidence-dialog')), findsNothing);
  });

  testWidgets('the dialog shows a spinner while the photo is in flight', (
    tester,
  ) async {
    final repo = _FakePhotosRepository()..listGate = Completer();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('evidence-thumb-p-new')));
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('evidence-dialog')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a failed dialog fetch offers Retry, and Retry really refetches',
    (tester) async {
      // The worklist rule applies in dialogs too: a dead-end error state is a
      // bug. The fetch dies, the manager taps Retry, the photo arrives.
      final repo = _FakePhotosRepository()..failList = true;
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('evidence-thumb-p-new')));
      // Settling is safe ONLY because visitPhotosProvider opts out of
      // Riverpod 3's auto-retry — with the default, the failure would hide
      // inside AsyncLoading through the backoff and this settle would either
      // hang on retry timers or self-heal a transient fake.
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load photo.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('evidence-dialog')),
          matching: find.byType(Image),
        ),
        findsNothing,
      );

      // Recovery is the BUTTON's doing: the backend comes back, and the very
      // next fetch is the one the tap triggers — no pumps in between, so no
      // framework retry can claim the credit.
      repo.failList = false;
      final callsBefore = repo.listCalls;
      await tester.tap(find.byKey(const ValueKey('evidence-dialog-retry')));
      await tester.pump();
      expect(repo.listCalls, callsBefore + 1);

      await tester.pumpAndSettle();
      expect(find.textContaining('Failed to load photo.'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('evidence-dialog')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a photoless visit says so — no image, no broken state', (
    tester,
  ) async {
    final repo = _FakePhotosRepository()..photos = const [];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('evidence-thumb-p-new')));
    await tester.pumpAndSettle();

    expect(find.text('No photo available for this visit.'), findsOneWidget);
    // Scoped to the dialog — the 44×44 thumb behind it is still an Image.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('evidence-dialog')),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
  });

  testWidgets('the dialog anchors to the photo whose thumb was tapped, not '
      'blindly to the newest', (tester) async {
    final repo = _FakePhotosRepository()
      ..photos = [
        // Newest row deliberately undecodable: if the dialog ignores the
        // tapped id and takes the head of the list, it renders the "no
        // photo" arm instead of the tapped photo.
        const VisitPhoto(
          id: 'p-new',
          section: 'shelf',
          url: 'data:image/png;base64,AQID',
          timestamp: '2026-07-22T10:00:00.000Z',
        ),
        VisitPhoto(
          id: 'p-tapped',
          section: 'shelf',
          url: 'data:image/png;base64,${base64Encode(_pngBytes)}',
          timestamp: '2026-07-21T10:00:00.000Z',
        ),
      ];
    await tester.pumpWidget(
      _app(
        repo,
        child: const EvidenceThumb(photoId: 'p-tapped', visitId: 'v1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('evidence-thumb-p-tapped')));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('evidence-dialog')),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as MemoryImage).bytes, _pngBytes);
  });
}
