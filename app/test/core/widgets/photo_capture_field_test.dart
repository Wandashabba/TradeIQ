import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/photo_geotagger.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/guided_capture_screen.dart';
import 'package:tradeiq_app/core/widgets/photo_capture_field.dart';

// The empty tile no longer calls the service — it pushes the guided screen,
// which owns the capture. The gateway is faked so that when the guided screen
// IS driven (Capture/Retake), a file with bytes stands in for a taken photo and
// null is a cancel.
class _FakeGateway implements ImagePickerGateway {
  _FakeGateway({this.file});

  final XFile? file;

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async => file;
}

XFile _xfile(Uint8List bytes, {String name = 'shelf.jpg'}) =>
    XFile.fromData(bytes, name: name, path: name);

const _hint = 'Shoot the whole shelf, edge to edge';

Widget _app(
  ThemeMode mode, {
  XFile? file,
  void Function(String?)? onCaptured,
}) => ProviderScope(
  overrides: [
    photoCaptureServiceProvider.overrideWithValue(
      PhotoCaptureService(gateway: _FakeGateway(file: file)),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: mode,
    home: Scaffold(
      body: PhotoCaptureField(
        label: 'Shelf photo',
        helperText: _hint,
        onCaptured: onCaptured ?? _noop,
      ),
    ),
  ),
);

void _noop(String? _) {}

/// The filled, rimmed decoration a [GlassPane] paints under [pane].
BoxDecoration _paneGround(WidgetTester tester, Finder pane) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: pane, matching: find.byType(DecoratedBox)),
    )
    .map((b) => b.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.color != null && d.border != null);

Color _hintColor(WidgetTester tester) =>
    tester.widget<Text>(find.text(_hint)).style!.color!;

void main() {
  group('PhotoCaptureField is theme-aware, not pinned dark', () {
    testWidgets('light: the empty tile is a no-blur glass tile, hint in the '
        'light palette', (tester) async {
      await tester.pumpWidget(_app(ThemeMode.light));
      await tester.pumpAndSettle();

      final pane = tester.widget<GlassPane>(
        find.byKey(const ValueKey('photo-capture-tile')),
      );
      expect(pane.kind, GlassKind.tile);
      expect(pane.blur, isFalse);
      expect(pane.radius, LumenGlass.radiusControl);
      // The ink well sits inside the pane, so its ripple shows over the fill.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('photo-capture-tile')),
          matching: find.byKey(const ValueKey('photo-add')),
        ),
        findsOneWidget,
      );
      expect(_hintColor(tester), TiqColors.light.ink3);
    });

    testWidgets('dark: the empty tile is a no-blur night glass tile, hint in '
        'the night palette', (tester) async {
      await tester.pumpWidget(_app(ThemeMode.dark));
      await tester.pumpAndSettle();

      final tile = find.byKey(const ValueKey('photo-capture-tile'));
      final pane = tester.widget<GlassPane>(tile);
      expect(pane.kind, GlassKind.tile);
      expect(pane.blur, isFalse);
      expect(pane.radius, LumenGlass.radiusControl);
      // The rendered ground: an unblurred tile takes the night solid fill
      // under the night tile rim.
      final ground = _paneGround(tester, tile);
      expect(ground.color, LumenPalette.dark.solidFill);
      expect((ground.border! as Border).top.color, LumenPalette.dark.tileRim);
      expect(_hintColor(tester), TiqColors.night.ink3);
    });

    // The whole point: the two modes must actually differ, so a static-light
    // regression that passes light cannot also pass dark.
    test('the asserted tokens differ between the two themes', () {
      expect(LumenPalette.light.solidFill, isNot(LumenPalette.dark.solidFill));
      expect(LumenPalette.light.tileRim, isNot(LumenPalette.dark.tileRim));
      expect(TiqColors.light.ink3, isNot(TiqColors.night.ink3));
    });
  });

  group('PhotoCaptureField launches the guided screen', () {
    testWidgets('the empty tile is a single "Add photo" affordance', (
      tester,
    ) async {
      await tester.pumpWidget(_app(ThemeMode.light));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('photo-add')), findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      // The old inline two-button capture is gone.
      expect(find.byKey(const ValueKey('photo-camera')), findsNothing);
      expect(find.byKey(const ValueKey('photo-gallery')), findsNothing);
    });

    testWidgets('tapping "Add photo" pushes the GuidedCaptureScreen', (
      tester,
    ) async {
      await tester.pumpWidget(_app(ThemeMode.light));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('photo-add')));
      await tester.pumpAndSettle();

      expect(find.byType(GuidedCaptureScreen), findsOneWidget);
      // The label + helper flow through as the section name and framing hint.
      expect(find.text('Shelf photo'), findsOneWidget);
      expect(find.text(_hint), findsWidgets);
    });

    testWidgets('a returned dataUrl shows the preview and calls onCaptured', (
      tester,
    ) async {
      String? captured;
      await tester.pumpWidget(
        _app(
          ThemeMode.light,
          file: _xfile(Uint8List.fromList([1, 2, 3, 4])),
          onCaptured: (v) => captured = v,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('photo-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guided-capture')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('photo-preview')), findsOneWidget);
      expect(captured, startsWith('data:image/jpeg;base64,'));
    });

    testWidgets('light: glass frames the preview with a rim, never a wash', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(ThemeMode.light, file: _xfile(Uint8List.fromList([1, 2, 3, 4]))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guided-capture')));
      await tester.pumpAndSettle();

      final rim = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('photo-preview')),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.position == DecorationPosition.foreground,
              ),
            )
            .first,
      );
      final deco = rim.decoration as BoxDecoration;
      expect((deco.border! as Border).top.color, LumenPalette.light.tileRim);
      expect(deco.color, isNull, reason: 'the evidence is never tinted');
    });

    testWidgets('Retake re-opens the guided screen', (tester) async {
      await tester.pumpWidget(
        _app(ThemeMode.light, file: _xfile(Uint8List.fromList([1, 2, 3, 4]))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('photo-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guided-capture')));
      await tester.pumpAndSettle();

      // Now in the captured state — Retake goes back into the guide.
      await tester.tap(find.byKey(const ValueKey('photo-remove')));
      await tester.pumpAndSettle();

      expect(find.byType(GuidedCaptureScreen), findsOneWidget);
    });

    testWidgets('a cancelled guided capture leaves the empty tile up', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _app(ThemeMode.light, onCaptured: (_) => calls++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('photo-add')));
      await tester.pumpAndSettle();
      // Gateway returns null (cancel): the guided screen stays, so close it.
      await tester.tap(find.byKey(const ValueKey('guided-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('photo-capture-tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-preview')), findsNothing);
      expect(calls, 0);
    });
  });

  group('PhotoCaptureField geotags audit evidence (#310)', () {
    final shutter = DateTime.utc(2026, 9, 15, 10, 4, 5);

    Widget geoApp({
      required bool geotag,
      required ValueChanged<CapturedPhoto> onPhoto,
    }) => ProviderScope(
      overrides: [
        photoCaptureServiceProvider.overrideWithValue(
          PhotoCaptureService(
            gateway: _FakeGateway(file: _xfile(Uint8List.fromList([1, 2]))),
            geotagger: PhotoGeotagger(
              location: _GrantedLocation(),
            ),
            clock: () => shutter,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PhotoCaptureField(
            label: 'Shelf photo',
            geotag: geotag,
            onPhotoCaptured: onPhoto,
          ),
        ),
      ),
    );

    Future<void> shoot(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('photo-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guided-capture')));
      await tester.pumpAndSettle();
    }

    testWidgets('geotag: true hands on the whole capture, tagged at the '
        'shutter', (tester) async {
      CapturedPhoto? photo;
      await tester.pumpWidget(geoApp(geotag: true, onPhoto: (p) => photo = p));
      await tester.pumpAndSettle();

      await shoot(tester);

      expect(find.byKey(const ValueKey('photo-preview')), findsOneWidget);
      expect(photo!.dataUrl, startsWith('data:image/jpeg;base64,'));
      expect(photo!.gpsTag, {'lat': -26.2041, 'lng': 28.0473});
      expect(photo!.capturedAt, shutter);
    });

    testWidgets('by default the field does not geotag (task closures stay '
        'untagged)', (tester) async {
      CapturedPhoto? photo;
      await tester.pumpWidget(geoApp(geotag: false, onPhoto: (p) => photo = p));
      await tester.pumpAndSettle();

      await shoot(tester);

      expect(photo, isNotNull);
      expect(photo!.gpsTag, isEmpty);
    });
  });
}

class _GrantedLocation extends LocationService {
  @override
  Future<LocationResult> getPositionIfPermitted() async =>
      LocationGranted(-26.2041, 28.0473);
}
