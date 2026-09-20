import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/camera/photo_exposure.dart';
import 'package:tradeiq_app/core/theme/torchlight/agent_skin.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/guided_capture_screen.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';

import '../design/amber_golden.dart';
import '../../features/agent_harness.dart';

/// PHOTO CAPTURE — PHASE 1, on Torchlight.
///
/// The screen is a launch wrapper: a framing card, the OS camera through the
/// same `ImagePickerGateway` seam the service tests fake, and a review step.
/// The review step is what this file is mostly about, because it is where a
/// dark frame stops being silently kept or silently dropped.

class _Gateway implements ImagePickerGateway {
  _Gateway({this.file, this.throwErr = false});

  final XFile? file;
  final bool throwErr;
  ImageSource? requested;
  int calls = 0;

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async {
    calls++;
    requested = source;
    if (throwErr) throw Exception('camera denied');
    return file;
  }
}

/// On the VM `XFile` derives `name` from `path`, so the path carries the
/// extension the service maps to a MIME type.
XFile _xfile(Uint8List bytes, {String name = 'shelf.png'}) =>
    XFile.fromData(bytes, name: name, path: name);

/// Bytes standing in for a frame. The exposure is *scripted* through
/// [photoExposureProvider] rather than measured here: decoding an image inside
/// a widget test does not complete on `FakeAsync`'s clock, so a test that
/// really decoded would hang with no output. `photo_exposure_test.dart`
/// measures the real thing inside `tester.runAsync`.
final _bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

/// An aisle with the lights off.
const double _dark = 0.08;

/// A lit bay.
const double _lit = 0.62;

Future<void> _pump(
  WidgetTester tester, {
  required ImagePickerGateway gateway,
  double? luma,
  SkinMode skin = SkinMode.night,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  void Function(CapturedPhoto?)? onResult,
  bool allowGallery = true,
}) async {
  final db = agentTestDb();
  await pumpAgentScreen(
    tester,
    _Host(onResult: onResult, allowGallery: allowGallery),
    path: '/capture',
    overrides: <Override>[
      ...agentBaseOverrides(db: db, skin: skin),
      photoCaptureServiceProvider.overrideWithValue(
        PhotoCaptureService(gateway: gateway),
      ),
      photoExposureProvider.overrideWithValue((String dataUrl) async => luma),
    ],
    textScale: textScale,
    locale: locale,
  );
}

/// A host with a button that pushes the capture route onto a real Navigator,
/// so the route can pop a value back the way the field awaits it.
class _Host extends StatelessWidget {
  const _Host({this.onResult, this.allowGallery = true});

  final void Function(CapturedPhoto?)? onResult;

  /// Mirrors [GuidedCaptureScreen.allowGallery] so a test can open the one
  /// capture where the gallery is not an option.
  final bool allowGallery;

  static const String hint = 'Shoot the whole shelf, edge to edge';

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      key: const ValueKey<String>('open'),
      onTap: () async {
        final photo = await Navigator.of(context).push<CapturedPhoto>(
          MaterialPageRoute<CapturedPhoto>(
            builder: (_) => GuidedCaptureScreen(
              label: 'Shelf photo',
              hint: hint,
              allowGallery: allowGallery,
            ),
          ),
        );
        onResult?.call(photo);
      },
      child: const Text('open'),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open')));
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('guided-capture')));
  await tester.pumpAndSettle();
}

void main() {
  group('the framing card', () {
    testWidgets('names what to shoot, draws the bay, and reminds about the '
        'torch', (tester) async {
      await _pump(tester, gateway: _Gateway());
      await _open(tester);

      expect(find.text('Shelf photo'), findsOneWidget);
      expect(find.text(_Host.hint), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('framing-card')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('framing-brackets')),
        findsOneWidget,
      );
      // TORCH is never an amber block — calling a torch control a light source
      // is a pun, not a rule. A square glyph and a sentence.
      final torch = find.byKey(const ValueKey<String>('torch-hint'));
      expect(torch, findsOneWidget);
      expect(
        find.descendant(of: torch, matching: find.byType(RowMarkTile)),
        findsOneWidget,
      );
      expect(
        find.textContaining('Switch your phone torch on'),
        findsOneWidget,
      );
      // The geotag is stated up front, not discovered afterwards.
      expect(
        find.text('Your photo is stamped with the time and where you are.'),
        findsOneWidget,
      );
    });

    testWidgets('it is a Torchlight route with a thumb zone and a skin cycle', (
      tester,
    ) async {
      await _pump(tester, gateway: _Gateway());
      await _open(tester);
      expect(find.byType(TorchShell), findsOneWidget);
      expect(find.byType(TorchThumbZone), findsOneWidget);
      // Never a screen without the skin cycle: the one control that gets a
      // person out of a skin they cannot read.
      expect(find.byType(TorchSkinCycle), findsOneWidget);
      expect(find.byType(TorchNavPill), findsNothing);
    });

    testWidgets('the primary names what it does, for a reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, gateway: _Gateway());
      await _open(tester);
      expect(
        find.bySemanticsLabel('Open the camera to photograph the shelf'),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('the handoff', () {
    testWidgets('Open camera drives capture(camera)', (tester) async {
      final gateway = _Gateway(file: _xfile(_bytes));
      await _pump(tester, gateway: gateway, luma: _lit);
      await _open(tester);
      await _capture(tester);

      expect(gateway.requested, ImageSource.camera);
    });

    testWidgets('the gallery is still reachable — a cracked camera in a dark '
        'aisle still has to file evidence', (tester) async {
      final gateway = _Gateway(file: _xfile(_bytes));
      await _pump(tester, gateway: gateway, luma: _lit);
      await _open(tester);

      await tester.tap(find.byKey(const ValueKey<String>('guided-gallery')));
      await tester.pumpAndSettle();
      expect(gateway.requested, ImageSource.gallery);
    });

    testWidgets('a capture that refuses the gallery does not offer it at all', (
      tester,
    ) async {
      final gateway = _Gateway(file: _xfile(_bytes));
      await _pump(tester, gateway: gateway, luma: _lit, allowGallery: false);
      await _open(tester);

      // The wrong-pin report's storefront photo (#386). A gallery image is
      // stamped with the moment it was PICKED and the position at that moment,
      // so a Street View screenshot chosen at home arrives with a fresh time
      // and a home tag that agree with the claim perfectly. The server refuses
      // one for that section; the button is gone so nobody spends the work
      // first and is told afterwards.
      expect(
        find.byKey(const ValueKey<String>('guided-gallery'), skipOffstage: false),
        findsNothing,
      );
      // The camera is still there — this narrows one capture, it does not
      // break capture.
      await _capture(tester);
      expect(gateway.requested, ImageSource.camera);
    });

    testWidgets('a capture records which source it came from', (tester) async {
      CapturedPhoto? result;
      await _pump(
        tester,
        gateway: _Gateway(file: _xfile(_bytes)),
        luma: _lit,
        onResult: (photo) => result = photo,
      );
      await _open(tester);
      await _capture(tester);
      await tester.tap(find.byKey(const ValueKey<String>('guided-use-it')));
      await tester.pumpAndSettle();

      // Without this the upload cannot say where the image came from, and the
      // server cannot tell storefront evidence from a picture of a storefront.
      expect(result, isNotNull);
      expect(result!.source, PhotoSource.camera);
    });

    testWidgets('a cancelled picker leaves the card up — not an error', (
      tester,
    ) async {
      var popped = false;
      await _pump(
        tester,
        gateway: _Gateway(),
        onResult: (_) => popped = true,
      );
      await _open(tester);
      await _capture(tester);

      expect(find.byType(GuidedCaptureScreen), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('guided-error')), findsNothing);
      expect(popped, isFalse);
    });

    testWidgets('a denied permission says so inline, and does not pop', (
      tester,
    ) async {
      await _pump(tester, gateway: _Gateway(throwErr: true));
      await _open(tester);
      await _capture(tester);

      // An agent who thinks the button is broken will stop filing evidence.
      expect(find.byType(GuidedCaptureScreen), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('guided-error')), findsOneWidget);
    });

    testWidgets('there is no in-app viewfinder, and the screen does not '
        'pretend', (tester) async {
      await _pump(tester, gateway: _Gateway());
      await _open(tester);
      // Phase 2 is #405 and is out of scope. What is here is a card and a
      // handoff, and that is what it looks like.
      expect(find.byType(Image), findsNothing);
    });
  });

  group('the review step', () {
    testWidgets('a captured frame comes back to be looked at, not straight to '
        'the caller', (tester) async {
      var popped = false;
      await _pump(
        tester,
        gateway: _Gateway(file: _xfile(_bytes)),
        luma: _lit,
        onResult: (_) => popped = true,
      );
      await _open(tester);
      await _capture(tester);

      expect(find.text('Check the photo'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('photo-preview')), findsOneWidget);
      expect(popped, isFalse, reason: 'the review step owns the pop');
    });

    testWidgets('a DARK frame is marked for retake — never kept silently, '
        'never dropped', (tester) async {
      await _pump(
        tester,
        // 8% mean luma: an aisle with the lights off.
        gateway: _Gateway(file: _xfile(_bytes)),
        luma: _dark,
      );
      await _open(tester);
      await _capture(tester);

      expect(find.byKey(const ValueKey<String>('photo-dark')), findsOneWidget);
      expect(find.text('Dark — retake?'), findsOneWidget);
      // Never auto-rejected: during Stage 6 it may be the only obtainable
      // evidence, so the frame is still there and "Use it" still works.
      expect(find.byKey(const ValueKey<String>('photo-preview')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('guided-use-it')), findsOneWidget);
    });

    testWidgets('a lit frame is not accused of being dark', (tester) async {
      await _pump(
        tester,
        gateway: _Gateway(file: _xfile(_bytes)),
        luma: _lit,
      );
      await _open(tester);
      await _capture(tester);

      expect(find.byKey(const ValueKey<String>('photo-dark')), findsNothing);
    });

    testWidgets('a frame nobody can decode is not called dark either', (
      tester,
    ) async {
      await _pump(
        tester,
        // null: the frame could not be decoded, so nothing was measured.
        gateway: _Gateway(file: _xfile(_bytes)),
      );
      await _open(tester);
      await _capture(tester);

      // Unmeasured is not "bright" and it is not "dark": the app does not
      // accuse a capture it could not read.
      expect(find.byKey(const ValueKey<String>('photo-dark')), findsNothing);
    });

    testWidgets('"Use it" pops the photo, carrying what was measured', (
      tester,
    ) async {
      CapturedPhoto? result;
      await _pump(
        tester,
        gateway: _Gateway(file: _xfile(_bytes)),
        luma: _dark,
        onResult: (p) => result = p,
      );
      await _open(tester);
      await _capture(tester);

      await tester.tap(find.byKey(const ValueKey<String>('guided-use-it')));
      await tester.pumpAndSettle();

      expect(find.byType(GuidedCaptureScreen), findsNothing);
      expect(result, isNotNull);
      expect(result!.dataUrl, startsWith('data:image/png;base64,'));
      // The fact travels with the evidence rather than being forgotten when
      // the capture route pops.
      expect(result!.isUnderexposed, isTrue);
      // Not asked to geotag, so it never looked for a location.
      expect(result!.gpsTag, isEmpty);
    });

    testWidgets('"Retake" re-opens the camera and keeps the frame until a new '
        'one lands', (tester) async {
      final gateway = _Gateway(file: _xfile(_bytes));
      await _pump(tester, gateway: gateway, luma: _dark);
      await _open(tester);
      await _capture(tester);
      expect(gateway.calls, 1);

      await tester.tap(find.byKey(const ValueKey<String>('guided-retake')));
      await tester.pumpAndSettle();

      expect(gateway.calls, 2);
      expect(find.byKey(const ValueKey<String>('photo-preview')), findsOneWidget);
    });

    testWidgets('the meta line states the geotag, present or absent', (
      tester,
    ) async {
      await _pump(
        tester,
        gateway: _Gateway(file: _xfile(_bytes)),
        luma: _lit,
      );
      await _open(tester);
      await _capture(tester);

      // An absent geotag is stated, not hidden: the geotag is what places a
      // stock count for the fraud module.
      expect(
        find.textContaining('no location on this photo'),
        findsOneWidget,
      );
    });
  });

  group('the amber census', () {
    for (final mode in agentSkinModes) {
      testWidgets('${mode.name}: framing lights one object — "Open camera"', (
        tester,
      ) async {
        await _pump(tester, gateway: _Gateway(), skin: mode);
        await _open(tester);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'guided-capture',
          phase: 'framing',
        );
        expect(census.objectCount, 1, reason: census.describe());
      });

      testWidgets('${mode.name}: review lights one object — "Use it"', (
        tester,
      ) async {
        await _pump(
          tester,
          gateway: _Gateway(file: _xfile(_bytes)),
          luma: _dark,
          skin: mode,
        );
        await _open(tester);
        await _capture(tester);
        final census = await amberCensus(tester);
        expectWithinAmberBudget(
          census,
          agentSkinFor(mode),
          route: 'guided-capture',
          phase: 'review-dark',
        );
        expect(
          census.objectCount,
          1,
          reason:
              'The dark frame\'s edge is the comparison series, never amber '
              'and never a severity.\n\n${census.describe()}',
        );
      });
    }
  });

  group('2.0× and Afrikaans', () {
    testWidgets('the framing card lays out at 2.0× in Afrikaans', (
      tester,
    ) async {
      await _pump(
        tester,
        gateway: _Gateway(),
        textScale: 2.0,
        locale: const Locale('af'),
      );
      await _open(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the review step lays out at 2.0× in Afrikaans', (
      tester,
    ) async {
      await _pump(
        tester,
        gateway: _Gateway(file: _xfile(_bytes)),
        luma: _dark,
        textScale: 2.0,
        locale: const Locale('af'),
      );
      await _open(tester);
      await _capture(tester);
      // At 2.0× the caption is below the fold on a 360×640 phone, which is the
      // geometry a real agent has — so the test scrolls rather than pumping a
      // viewport nobody owns.
      await scrollAgentTo(
        tester,
        find.byKey(const ValueKey<String>('photo-dark'), skipOffstage: false),
      );
      expect(find.text('Donker — neem weer?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
