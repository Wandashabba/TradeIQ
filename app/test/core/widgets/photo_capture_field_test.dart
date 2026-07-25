import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/photo_capture_field.dart';

// PhotoCaptureField.build never touches the service — only _capture does — but
// the provider is overridden anyway so the widget pumps in full isolation.
class _FakeGateway implements ImagePickerGateway {
  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async => null;
}

const _hint = 'Shoot the whole shelf, edge to edge';

Widget _app(ThemeMode mode) => ProviderScope(
  overrides: [
    photoCaptureServiceProvider.overrideWithValue(
      PhotoCaptureService(gateway: _FakeGateway()),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: mode,
    home: const Scaffold(
      body: PhotoCaptureField(
        label: 'Shelf photo',
        helperText: _hint,
        onCaptured: _noop,
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
}
