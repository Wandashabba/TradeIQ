import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/photo_geotagger.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';

import '../../core/design/amber_golden.dart';
import '../agent_harness.dart';

/// THE SECTION HARNESS — one way to stand up any of the nine capture sections.
///
/// A section is a whole route now: `SectionForm` carries the header, the thumb
/// zone, the skin cycle and its own `TorchScope`, so a test pumps it exactly
/// as the hub pushes it, in a pinned skin, inside the census boundary. The old
/// tests wrapped a section in a `Scaffold` and a `SingleChildScrollView`; that
/// frame no longer exists anywhere in the app.
Future<void> pumpSection(
  WidgetTester tester,
  Widget section, {
  List<Override> overrides = const <Override>[],
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  Size size = const Size(360, 640),
  bool settle = true,
}) async {
  final db = agentTestDb();
  await pumpAgentScreen(
    tester,
    section,
    overrides: <Override>[
      ...agentBaseOverrides(db: db, skin: skin),
      ...overrides,
    ],
    path: '/visit/section',
    size: size,
    textScale: textScale,
    locale: locale,
    settle: settle,
  );
}

/// Scroll to [finder] and tap it.
Future<void> tapInSection(WidgetTester tester, Finder finder) async {
  await scrollAgentTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scroll to a field and type into its editable text.
Future<void> typeInSection(
  WidgetTester tester,
  Finder field,
  String text,
) async {
  await scrollAgentTo(tester, field);
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(EditableText)),
    text,
  );
  await tester.pumpAndSettle();
}

/// The inline Save — the only thing in a section that persists.
Finder get sectionSave => find.byKey(const ValueKey<String>('section-save'));

/// Press the inline Save and let it land.
Future<void> saveSection(WidgetTester tester) =>
    tapInSection(tester, sectionSave);

/// Count what the frame actually painted, and hold it to [expected] objects —
/// and to the skin's budget, which is the law's ceiling.
Future<void> expectAmber(
  WidgetTester tester, {
  required SkinMode skin,
  required String route,
  required String phase,
  required int expected,
}) async {
  // Settle the scroll back to the top so the census frame is the one a
  // person meets on arrival; a Save scrolled into view is counted either way.
  final census = await amberCensus(tester);
  expectWithinAmberBudget(
    census,
    agentSkinFor(skin),
    route: route,
    phase: phase,
  );
  expect(
    census.objectCount,
    expected,
    reason: '$route [$phase, ${skin.name}]\n${census.describe()}',
  );
}

// ── Photo fakes ────────────────────────────────────────────────────────────

/// Records every queued photo.
class SpyQueuedPhotos implements QueuedPhotosRepository {
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> queuePhoto({
    required String visitDraftId,
    required String section,
    required String dataUrl,
    Map<String, dynamic> gpsTag = const <String, dynamic>{},
    DateTime? capturedAt,
  }) async => calls.add(<String, Object?>{
    'visitDraftId': visitDraftId,
    'section': section,
    'dataUrl': dataUrl,
    'gpsTag': gpsTag,
    'capturedAt': capturedAt,
  });
}

/// A picker that hands back three bytes, and says which source was asked.
class FakePhotoGateway implements ImagePickerGateway {
  final sources = <ImageSource>[];

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async {
    sources.add(source);
    return XFile.fromData(
      Uint8List.fromList(<int>[1, 2, 3]),
      path: 'shelf.jpg',
    );
  }
}

class GrantedLocation extends LocationService {
  @override
  Future<LocationResult> getPositionIfPermitted() async =>
      LocationGranted(-26.2041, 28.0473, accuracy: 7);
}

/// A capture service that always succeeds, geotagged, at [shutter].
PhotoCaptureService fakeCapture({
  FakePhotoGateway? gateway,
  DateTime? shutter,
}) => PhotoCaptureService(
  gateway: gateway ?? FakePhotoGateway(),
  geotagger: PhotoGeotagger(location: GrantedLocation()),
  clock: () => shutter ?? DateTime.utc(2026, 9, 15, 10, 4, 5),
);
