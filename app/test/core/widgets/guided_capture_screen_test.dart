import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/guided_capture_screen.dart';

// The guided screen is a launch wrapper: it drives the real PhotoCaptureService
// through the same ImagePickerGateway seam the service tests fake. A file with
// bytes stands in for a taken photo; null is a cancel; throwErr is a denied
// permission.
class _Gateway implements ImagePickerGateway {
  _Gateway({this.file, this.throwErr = false});

  final XFile? file;
  final bool throwErr;
  ImageSource? requested;

  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async {
    requested = source;
    if (throwErr) throw Exception('camera denied');
    return file;
  }
}

// On the VM XFile derives `name` from `path`, so the path carries the extension.
XFile _xfile(Uint8List bytes, {String name = 'shelf.jpg'}) =>
    XFile.fromData(bytes, name: name, path: name);

const _hint = 'Shoot the whole shelf, edge to edge';

// A host with a button that pushes the guided screen onto a real Navigator, so
// the route can pop a value back the way the field awaits it.
Widget _host(
  ThemeMode mode, {
  required ImagePickerGateway gateway,
  void Function(String?)? onResult,
}) => ProviderScope(
  overrides: [
    photoCaptureServiceProvider.overrideWithValue(
      PhotoCaptureService(gateway: gateway),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: mode,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () async {
              final r = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const GuidedCaptureScreen(
                    label: 'Shelf photo',
                    hint: _hint,
                  ),
                ),
              );
              onResult?.call(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

double _relLum(Color c) {
  double chan(double v) {
    v /= 255.0;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * chan((c.r * 255).roundToDouble()) +
      0.7152 * chan((c.g * 255).roundToDouble()) +
      0.0722 * chan((c.b * 255).roundToDouble());
}

double _contrast(Color a, Color b) {
  final la = _relLum(a);
  final lb = _relLum(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('GuidedCaptureScreen renders full-screen, both themes', () {
    for (final (name, mode, palette) in [
      ('light', ThemeMode.light, TiqColors.light),
      ('dark', ThemeMode.dark, TiqColors.night),
    ]) {
      testWidgets('$name: label, hint, brackets, both buttons', (tester) async {
        await tester.pumpWidget(_host(mode, gateway: _Gateway()));
        await _open(tester);

        expect(find.text('Shelf photo'), findsOneWidget);
        expect(find.text(_hint), findsOneWidget);
        expect(find.byKey(const ValueKey('framing-brackets')), findsOneWidget);
        expect(find.byKey(const ValueKey('guided-capture')), findsOneWidget);
        expect(find.byKey(const ValueKey('guided-gallery')), findsOneWidget);
      });

      testWidgets('$name: the hint text clears 4.5:1 on its ground', (
        tester,
      ) async {
        await tester.pumpWidget(_host(mode, gateway: _Gateway()));
        await _open(tester);

        final hint = tester.widget<Text>(find.text(_hint));
        expect(_contrast(hint.style!.color!, palette.plane), greaterThan(4.5));
      });
    }
  });

  // The title is ink on the lit ground: by day a dark ink, measured on the
  // ground's darker foot; at night a light ink, measured where the ground is
  // brightest — its top under the violet bloom.
  for (final (name, mode, ground) in [
    (
      'light',
      ThemeMode.light,
      LumenPalette.light.groundBottom,
    ),
    (
      'dark: night',
      ThemeMode.dark,
      Color.alphaBlend(
        LumenPalette.dark.bloomViolet,
        LumenPalette.dark.groundTop,
      ),
    ),
  ]) {
    testWidgets('$name glass: lit ground, a glass close chip, the guide in a '
        'glass panel', (tester) async {
      await tester.pumpWidget(_host(mode, gateway: _Gateway()));
      await _open(tester);

      expect(
        find.descendant(
          of: find.byType(GuidedCaptureScreen),
          matching: find.byType(LitGround),
        ),
        findsOneWidget,
      );

      final frame = tester.widget<GlassPane>(
        find.ancestor(
          of: find.byKey(const ValueKey('framing-brackets')),
          matching: find.byType(GlassPane),
        ),
      );
      expect(frame.kind, GlassKind.panel);

      // Still the same Cancel control — key, tooltip and tap unchanged.
      final close = find.byKey(const ValueKey('guided-close'));
      expect(tester.widget<IconButton>(close).tooltip, 'Cancel');
      final chip = tester.widget<GlassPane>(
        find.descendant(of: close, matching: find.byType(GlassPane)),
      );
      expect(chip.kind, GlassKind.pill);

      final title = tester.widget<Text>(find.text('Shelf photo'));
      expect(_contrast(title.style!.color!, ground), greaterThan(4.5));
    });
  }

  testWidgets('Capture drives capture(camera) and pops with the dataUrl', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final gateway = _Gateway(file: _xfile(bytes));
    String? result;
    var called = false;
    await tester.pumpWidget(
      _host(
        ThemeMode.light,
        gateway: gateway,
        onResult: (r) {
          called = true;
          result = r;
        },
      ),
    );
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('guided-capture')));
    await tester.pumpAndSettle();

    expect(gateway.requested, ImageSource.camera);
    // A non-null capture pops the route with the encoded data URL.
    expect(find.byType(GuidedCaptureScreen), findsNothing);
    expect(called, isTrue);
    expect(result, startsWith('data:image/jpeg;base64,'));
  });

  testWidgets('Choose from gallery drives capture(gallery)', (tester) async {
    final gateway = _Gateway(file: _xfile(Uint8List.fromList([9])));
    await tester.pumpWidget(_host(ThemeMode.light, gateway: gateway));
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('guided-gallery')));
    await tester.pumpAndSettle();

    expect(gateway.requested, ImageSource.gallery);
  });

  testWidgets('a cancelled picker leaves the guide up — not an error', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      _host(
        ThemeMode.light,
        gateway: _Gateway(),
        onResult: (_) => called = true,
      ),
    );
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('guided-capture')));
    await tester.pumpAndSettle();

    // Backing out of the camera is normal: the screen stays, nothing pops.
    expect(find.byType(GuidedCaptureScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('guided-error')), findsNothing);
    expect(called, isFalse);
  });

  testWidgets('a capture error renders inline without crashing or popping', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(ThemeMode.light, gateway: _Gateway(throwErr: true)),
    );
    await _open(tester);

    await tester.tap(find.byKey(const ValueKey('guided-capture')));
    await tester.pumpAndSettle();

    expect(find.byType(GuidedCaptureScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('guided-error')), findsOneWidget);
  });

  testWidgets('primary Capture is an AgentButton', (tester) async {
    await tester.pumpWidget(_host(ThemeMode.light, gateway: _Gateway()));
    await _open(tester);

    expect(
      tester.widget<AgentButton>(find.byKey(const ValueKey('guided-capture'))),
      isA<AgentButton>(),
    );
  });
}
