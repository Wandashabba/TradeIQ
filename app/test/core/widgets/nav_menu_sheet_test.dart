import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/brand_media.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/lumen_palette.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/nav_destinations.dart';
import 'package:tradeiq_app/core/widgets/nav_menu_sheet.dart';

import '../theme/tiq_colors_test.dart' show contrastRatio;

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

/// The other failure mode: BrandMedia.menuHeader set without its pubspec
/// asset entry. The load throws, and the band must degrade to nothing.
class _MissingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => key.endsWith('.png')
      ? throw StateError('missing asset: $key')
      : rootBundle.load(key);
}

/// The sheet is normally shown by [showNavMenuSheet]; here it is pumped
/// directly to test its own contract. The ProviderScope exists for the
/// theme-toggle and sign-out rows, which are riverpod Consumers.
Widget _app(Widget sheet, {ThemeData? theme}) => ProviderScope(
  child: MaterialApp(
    theme: theme ?? AppTheme.light(),
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

  testWidgets(
    'a missing header asset degrades to nothing — no error box, no exception',
    (tester) async {
      // The failure mode: BrandMedia.menuHeader set but the file never
      // added to pubspec. The sheet must still stand, band collapsed.
      await tester.pumpWidget(
        _app(
          DefaultAssetBundle(
            bundle: _MissingAssetBundle(),
            child: const NavMenuSheet(
              headerImage: 'assets/images/brand/menu-header.png',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('OPERATE'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      // The Image element collapses to zero size: nothing rendered.
      expect(tester.getSize(find.byType(Image)), Size.zero);
    },
  );

  group('Lumen Glass', () {
    for (final (name, theme, colors, lumen) in [
      ('light', AppTheme.light(), TiqColors.light, LumenPalette.light),
      ('dark: night', AppTheme.dark(), TiqColors.night, LumenPalette.dark),
    ]) {
      testWidgets(
        '$name glass destination tiles, glass housekeeping pills, mono kickers',
        (tester) async {
          await tester.pumpWidget(_app(const NavMenuSheet(), theme: theme));

          final route = destinationsIn(NavGroup.values.first).first.route;
          final tile = tester.widget<GlassPane>(
            find.ancestor(
              of: find.byKey(ValueKey('nav-sheet-$route')),
              matching: find.byType(GlassPane),
            ),
          );
          expect(tile.kind, GlassKind.tile);
          // Twelve-plus tiles in one sheet: none may blur.
          expect(tile.blur, isFalse);

          final signOut = tester.widget<GlassPane>(
            find.ancestor(
              of: find.text('Sign out'),
              matching: find.byType(GlassPane),
            ),
          );
          expect(signOut.kind, GlassKind.pill);

          final heading = tester.widget<Text>(find.text('OPERATE'));
          expect(heading.style?.fontFamily, LumenGlass.mono);
          expect(heading.style?.color, lumen.kicker);
          final ratio = contrastRatio(heading.style!.color!, colors.surface1);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: 'kicker $ratio:1');

          // The sheet itself: opaque surface1 under the palette's panel rim.
          final sheet = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(NavMenuSheet),
                  matching: find.byType(Container),
                )
                .first,
          );
          final deco = sheet.decoration! as BoxDecoration;
          expect(deco.color, colors.surface1);
          expect((deco.border! as Border).top.color, lumen.panelRim);
        },
      );
    }
  });
}
