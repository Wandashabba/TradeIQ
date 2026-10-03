import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tradeiq_app/core/auth/token_store.dart';
import 'package:tradeiq_app/core/storage/local_db.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/nav_destinations.dart';
import 'package:tradeiq_app/core/widgets/torchlight/menu_sheet.dart';
import 'package:tradeiq_app/core/widgets/torchlight/row/row.dart';
import 'package:tradeiq_app/core/widgets/torchlight/section_rule.dart';
import 'package:tradeiq_app/core/widgets/torchlight/sheet.dart';
import 'package:tradeiq_app/l10n/l10n.dart';

import '../../../features/agent_harness.dart';
import '../../../features/auth/entry_harness.dart';

/// THE SIGN-OFF RENDERS for the folding menu — the frames a human looks at.
///
/// Both phone sizes, both skins, the sheet shut / **each group open in turn**
/// / The Floor's `lead` block above it, and the whole set again at 1.3× text.
/// Written to `MENU_LOOK_OUT` (default `build/menu-look`) in the real faces,
/// because the question they answer — does a label wrap, do an open group's
/// children read as subordinate — is a question about Schibsted Grotesk and
/// not about Flutter's test font.
///
/// **Each group, not only Operate** — 3 October 2026. The groups print as
/// *Execution*, *Performance* and *Setup* now, and the longest destination
/// label in the app, *Perfect Store scorecard*, is the last row of Setup. A
/// camera that only ever opened the first group could not see the one row the
/// rename put most at risk of truncating, so an open group is also scrolled to
/// the sheet's end.
///
/// **Gated behind `MENU_LOOK=1`**, for the reason `soft_look_test.dart` gives:
/// CI rasterises anti-aliased Schibsted Grotesk on Linux and this repository
/// is developed on macOS, so a pixel assertion here would be a platform
/// assertion. These are not assertions at all — they are a camera.
///
/// ```sh
/// MENU_LOOK=1 MENU_LOOK_OUT=/tmp/renders flutter test \
///   test/core/widgets/torchlight/menu_fold_look_test.dart
/// ```
void main() {
  final looking = Platform.environment['MENU_LOOK'] == '1';
  final outDir =
      Platform.environment['MENU_LOOK_OUT'] ?? 'build/menu-look';

  setUpAll(() async {
    await loadAgentFonts();
    // The whole point of this change is that the destinations now carry their
    // icons. A render that drew them as tofu boxes would be a render of a
    // different design.
    await _loadIcons();
  });

  /// The two slots The Floor gave up, as `showFloorDestinations` passes them —
  /// with numbers on them, which is the reason that block exists and is not
  /// folded.
  List<Widget> floorLead() => <Widget>[
    const SectionRule('Where you were'),
    const SizedBox(height: TiqSpace.s3),
    SoftRow(
      key: const ValueKey<String>('floor-destination-work'),
      density: SoftRowDensity.compact,
      title: 'Work',
      subtitle: '3 things need a decision',
      trailing: const SoftRowChevron(),
      onTap: () {},
    ),
    SoftRow(
      key: const ValueKey<String>('floor-destination-overview'),
      density: SoftRowDensity.compact,
      title: 'Perfect Store',
      subtitle: '71% of today measured',
      trailing: const SoftRowChevron(),
      onTap: () {},
    ),
  ];

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required SkinMode skin,
    required double textScale,
    required String at,
    NavGroup? open,
    List<Widget> lead = const <Widget>[],
  }) async {
    TorchSheets.resetForTest();
    addTearDown(TorchSheets.resetForTest);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final resolved = switch (skin) {
      SkinMode.day => TiqSkin.day(density: TiqDensity.console),
      _ => TiqSkin.night(density: TiqDensity.console),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localDbProvider.overrideWithValue(entryTestDb()),
          tokenStoreProvider.overrideWithValue(FakeTokenStore()),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 1.0,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: MaterialApp.router(
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            theme: AppTheme.torchlight(resolved),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey<String>('look-boundary'),
              child: ColoredBox(color: resolved.palette.ground, child: child!),
            ),
            routerConfig: GoRouter(
              initialLocation: at,
              routes: <RouteBase>[
                for (final path in <String>[
                  '/here',
                  '/dashboard',
                  '/territories',
                ])
                  GoRoute(
                    path: path,
                    builder: (context, state) => Builder(
                      builder: (context) => Center(
                        child: GestureDetector(
                          onTap: () =>
                              showTorchMenuSheet(context, lead: lead),
                          child: const Text('OPEN'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    if (open != null) {
      await tester.tap(find.byKey(ValueKey<String>('menu-fold-${open.name}')));
      await tester.pumpAndSettle();
      // Setup's last row is the longest label in the app and sits below the
      // fold on the 360dp phone. A render that cannot show it cannot answer
      // the one question this change raises, so the sheet is scrolled to its
      // end whenever a group is open.
      await tester.dragUntilVisible(
        find.byKey(const ValueKey<String>('menu-sign-out')),
        find.byType(Scrollable).last,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
    }

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey<String>('look-boundary')),
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!);
  }

  for (final (label, size) in <(String, Size)>[
    ('390x844', Size(390, 844)),
    ('360x640', Size(360, 640)),
  ]) {
    for (final skin in <SkinMode>[SkinMode.night, SkinMode.day]) {
      final stem = '${label}_${skin.name}';

      testWidgets('$stem — shut', (tester) async {
        await shoot(
          tester,
          name: '${stem}_shut',
          size: size,
          skin: skin,
          textScale: 1.0,
          at: '/here',
        );
      }, skip: !looking);

      for (final group in NavGroup.values) {
        testWidgets('$stem — ${group.name} open', (tester) async {
          await shoot(
            tester,
            name: '${stem}_open_${group.name}',
            size: size,
            skin: skin,
            textScale: 1.0,
            at: '/here',
            open: group,
          );
        }, skip: !looking);
      }

      // On The Floor: the lead block above the groups, Operate already open
      // because /dashboard is in it, and The Floor row emboldened inside it.
      // One frame carrying every new state this change introduced.
      testWidgets('$stem — The Floor, lead block', (tester) async {
        await shoot(
          tester,
          name: '${stem}_floor',
          size: size,
          skin: skin,
          textScale: 1.0,
          at: '/dashboard',
          lead: floorLead(),
        );
      }, skip: !looking);

      testWidgets('$stem — shut at 1.3×', (tester) async {
        await shoot(
          tester,
          name: '${stem}_shut_1.3x',
          size: size,
          skin: skin,
          textScale: 1.3,
          at: '/here',
        );
      }, skip: !looking);

      for (final group in NavGroup.values) {
        testWidgets('$stem — ${group.name} open at 1.3×', (tester) async {
          await shoot(
            tester,
            name: '${stem}_open_${group.name}_1.3x',
            size: size,
            skin: skin,
            textScale: 1.3,
            at: '/here',
            open: group,
          );
        }, skip: !looking);
      }
    }
  }
}

/// Material's icon font, so a destination's icon is its icon and not a tofu
/// box. Silent if the SDK keeps it somewhere else — the same loader, and the
/// same caveat, as `manager_chip_look_test.dart`.
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
        ..addFont(font.readAsBytes().then((b) => ByteData.view(b.buffer))))
      .load();
}
