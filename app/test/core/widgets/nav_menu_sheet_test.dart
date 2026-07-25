import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/brand_media.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/widgets/nav_menu_sheet.dart';

/// A real, decodable image (1×1 transparent PNG) for the header band.
final _pngBytes = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Serves [_pngBytes] for any .png key — the brand header asset is not
/// committed yet (curation is a human step), so the test brings its own
/// bundle.
class _BrandAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => key.endsWith('.png')
      ? ByteData.sublistView(_pngBytes)
      : rootBundle.load(key);
}

/// The sheet is normally shown by [showNavMenuSheet]; here it is pumped
/// directly to test its own contract. The ProviderScope exists for the
/// theme-toggle and sign-out rows, which are riverpod Consumers.
Widget _app(Widget sheet) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: sheet),
  ),
);

void main() {
  testWidgets(
    'default sheet carries no header image while BrandMedia.menuHeader is '
    'null',
    (tester) async {
      // The default header slot IS the BrandMedia constant: until a human
      // curates an image (tool/generate_brand_media/README.md) the sheet
      // must render exactly today's imageless layout.
      expect(BrandMedia.menuHeader, isNull);

      await tester.pumpWidget(_app(const NavMenuSheet()));

      expect(find.text('OPERATE'), findsOneWidget);
      expect(find.text('INSIGHT'), findsOneWidget);
      expect(find.text('CONFIGURE'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'a curated header image renders as a decorative band above the groups',
    (tester) async {
      await tester.pumpWidget(
        _app(
          DefaultAssetBundle(
            bundle: _BrandAssetBundle(),
            child: const NavMenuSheet(
              headerImage: 'assets/images/brand/menu-header.png',
            ),
          ),
        ),
      );
      await tester.pump();

      final image = find.byType(Image);
      expect(image, findsOneWidget);
      // Decorative: an empty semantic label keeps screen readers on the
      // destinations, which carry the actual meaning.
      expect(tester.widget<Image>(image).semanticLabel, '');
      // A header, not an interleaved band: above the first group heading.
      expect(
        tester.getCenter(image).dy < tester.getCenter(find.text('OPERATE')).dy,
        isTrue,
      );
      // The destinations are all still there beneath it.
      expect(find.text('Sign out'), findsOneWidget);
    },
  );
}
