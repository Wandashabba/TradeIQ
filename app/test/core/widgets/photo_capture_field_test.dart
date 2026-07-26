import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
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

BoxDecoration _tileDeco(WidgetTester tester) =>
    tester
            .widget<Container>(find.byKey(const ValueKey('photo-capture-tile')))
            .decoration!
        as BoxDecoration;

Color _hintColor(WidgetTester tester) =>
    tester.widget<Text>(find.text(_hint)).style!.color!;

void main() {
  group('PhotoCaptureField is theme-aware, not pinned dark', () {
    testWidgets('empty-state tile + hint resolve the light palette', (
      tester,
    ) async {
      await tester.pumpWidget(_app(ThemeMode.light));
      await tester.pumpAndSettle();

      final deco = _tileDeco(tester);
      expect(deco.color, TiqColors.light.surface2);
      expect((deco.border! as Border).top.color, TiqColors.light.line);
      expect(_hintColor(tester), TiqColors.light.ink3);
    });

    testWidgets('empty-state tile + hint resolve the dark palette', (
      tester,
    ) async {
      await tester.pumpWidget(_app(ThemeMode.dark));
      await tester.pumpAndSettle();

      final deco = _tileDeco(tester);
      expect(deco.color, TiqColors.dark.surface2);
      expect((deco.border! as Border).top.color, TiqColors.dark.line);
      expect(_hintColor(tester), TiqColors.dark.ink3);
    });

    // The whole point: the two modes must actually differ, so a static-dark
    // regression that passes dark cannot also pass light.
    test('the asserted tokens differ between the two themes', () {
      expect(TiqColors.light.surface2, isNot(TiqColors.dark.surface2));
      expect(TiqColors.light.line, isNot(TiqColors.dark.line));
      expect(TiqColors.light.ink3, isNot(TiqColors.dark.ink3));
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
}
