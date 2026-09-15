import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/location/location_service.dart';
import 'package:tradeiq_app/core/location/photo_geotagger.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/core/theme/app_theme.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/lumen_glass.dart';
import 'package:tradeiq_app/core/theme/tiq_colors.dart';
import 'package:tradeiq_app/core/widgets/glass.dart';
import 'package:tradeiq_app/core/widgets/agent_kit.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s2_stock_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tiq_colors_test.dart' show contrastRatio;

class _FakeSkusRepository implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
    data: [
      Sku(
        id: 's1',
        name: 'Test Cola',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 19.99,
        daysOutOfStock: 0,
        velocityAvg: 4.2,
        effectivePrice: 19.99,
      ),
    ],
    nextCursor: null,
  );
}

/// A SKU with exactly one prior in-stock reading: `daysOutOfStock` only needs
/// one history point, `velocityAvg` needs two — so this combination (a rate of
/// zero alongside a nonzero out-of-stock count) is a legitimate state, not a
/// contradiction.
class _FakeSkusRepositoryNoHistory implements SkusRepository {
  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => const PaginatedResponse(
    data: [
      Sku(
        id: 's1',
        name: 'Test Cola',
        category: 'Beverages',
        minFacingsStandard: 4,
        rrp: 19.99,
        daysOutOfStock: 5,
        velocityAvg: 0,
        effectivePrice: 19.99,
      ),
    ],
    nextCursor: null,
  );
}

class _SpyStockRepository implements StockRepository {
  String? visitDraftId;
  List<StockEntry>? entries;

  @override
  Future<void> saveStock({
    required String visitDraftId,
    required List<StockEntry> entries,
  }) async {
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

class _SpyQueuedPhotos implements QueuedPhotosRepository {
  final calls = <Map<String, Object?>>[];

  @override
  Future<void> queuePhoto({
    required String visitDraftId,
    required String section,
    required String dataUrl,
    Map<String, dynamic> gpsTag = const {},
    DateTime? capturedAt,
  }) async => calls.add({
    'visitDraftId': visitDraftId,
    'section': section,
    'dataUrl': dataUrl,
    'gpsTag': gpsTag,
    'capturedAt': capturedAt,
  });
}

class _PhotoGateway implements ImagePickerGateway {
  @override
  Future<XFile?> pick({
    required ImageSource source,
    required double maxWidth,
    required int imageQuality,
  }) async =>
      XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'shelf.jpg');
}

class _GrantedLocation extends LocationService {
  @override
  Future<LocationResult> getPositionIfPermitted() async =>
      LocationGranted(-26.2041, 28.0473, accuracy: 7);
}

const _bothThemes = [('light', TiqColors.light), ('dark', TiqColors.night)];

ThemeData _themeFor(String name) =>
    name == 'light' ? AppTheme.light() : AppTheme.dark();

Widget _screen({
  required StockRepository stock,
  SkusRepository? skus,
  ThemeData? theme,
}) => ProviderScope(
  overrides: [
    skusRepositoryProvider.overrideWithValue(skus ?? _FakeSkusRepository()),
    stockRepositoryProvider.overrideWithValue(stock),
  ],
  child: MaterialApp(
    theme: theme,
    home: const Scaffold(
      body: SingleChildScrollView(
        child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1'),
      ),
    ),
  ),
);

/// The decoration of the nearest ancestor Container of [inner] that carries a
/// BoxDecoration colour — the console card the element sits on.
BoxDecoration _cardDecoration(WidgetTester tester, Finder inner) {
  final container = find
      .ancestor(
        of: inner,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color != null,
        ),
      )
      .first;
  return tester.widget<Container>(container).decoration! as BoxDecoration;
}

void main() {
  testWidgets('a shelf photo is queued once as stock evidence, with its '
      'gpsTag and shutter time (#310)', (tester) async {
    final shutter = DateTime.utc(2026, 9, 15, 10, 4, 5);
    final photos = _SpyQueuedPhotos();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          skusRepositoryProvider.overrideWithValue(_FakeSkusRepository()),
          stockRepositoryProvider.overrideWithValue(_SpyStockRepository()),
          queuedPhotosRepositoryProvider.overrideWithValue(photos),
          photoCaptureServiceProvider.overrideWithValue(
            PhotoCaptureService(
              gateway: _PhotoGateway(),
              geotagger: PhotoGeotagger(location: _GrantedLocation()),
              clock: () => shutter,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: S2StockScreen(visitDraftId: 'v1', outletId: 'o1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('photo-add')));
    await tester.tap(find.byKey(const ValueKey('photo-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guided-capture')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(photos.calls, hasLength(1));
    final call = photos.calls.single;
    expect(call['visitDraftId'], 'v1');
    expect(call['section'], 'stock');
    expect(call['dataUrl'], startsWith('data:image/jpeg;base64,'));
    expect(call['gpsTag'], {'lat': -26.2041, 'lng': 28.0473, 'accuracy': 7.0});
    expect(call['capturedAt'], shutter);

    // Saving the counts again does not queue the same photo twice.
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();
    expect(photos.calls, hasLength(1));
  });

  testWidgets('shows read-only server context and calls saveStock on Save', (
    tester,
  ) async {
    final spy = _SpyStockRepository();

    await tester.pumpWidget(_screen(stock: spy));
    await tester.pumpAndSettle();

    expect(find.text('Selling ~4.2/day'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '20');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(spy.visitDraftId, 'v1');
    expect(spy.entries, hasLength(1));
    expect(spy.entries!.first.skuId, 's1');
    expect(spy.entries!.first.unitsAvailable, 20);
    expect(find.text('Stock saved — queued for sync'), findsOneWidget);
  });

  testWidgets('the +/- stepper adjusts the count without a keyboard', (
    tester,
  ) async {
    final spy = _SpyStockRepository();

    await tester.pumpWidget(_screen(stock: spy));
    await tester.pumpAndSettle();

    final plus = find.descendant(
      of: find.byKey(const ValueKey('units-s1')),
      matching: find.byIcon(Icons.add),
    );
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save stock'));
    await tester.tap(find.text('Save stock'));
    await tester.pumpAndSettle();

    expect(spy.entries!.first.unitsAvailable, 3);
  });

  testWidgets('a zero count is shown as the finding it is', (tester) async {
    await tester.pumpWidget(_screen(stock: _SpyStockRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('units-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('units-input-s1')), '0');
    await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Out of stock — this raises a task for the manager'),
      findsOneWidget,
    );
  });

  testWidgets(
    'with no velocity history yet, the context line stands on its own',
    (tester) async {
      await tester.pumpWidget(
        _screen(
          stock: _SpyStockRepository(),
          skus: _FakeSkusRepositoryNoHistory(),
        ),
      );
      await tester.pumpAndSettle();

      // A rate of zero does not mean "Selling no sales history yet" — it means
      // there isn't yet a rate to report, and that can still come with a known
      // out-of-stock count from a single prior reading.
      expect(
        find.text('No sales history yet · out of stock 5d'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SKU rows are console cards and the save is an AgentButton — no raw '
    'Card/ElevatedButton',
    (tester) async {
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(
          _screen(stock: _SpyStockRepository(), theme: _themeFor(name)),
        );
        await tester.pumpAndSettle();

        // The console has one container — a bordered surface1 panel. No raw
        // Material Card, and the save is the kit's AgentButton, not a raw
        // ElevatedButton.
        expect(find.byType(Card), findsNothing, reason: '$name no Card');
        expect(
          find.byType(ElevatedButton),
          findsNothing,
          reason: '$name no ElevatedButton',
        );
        expect(
          find.widgetWithText(AgentButton, 'Save stock'),
          findsOneWidget,
          reason: '$name save is AgentButton',
        );

        if (palette.glass) {
          // Lumen Glass: each SKU is a no-blur glass tile (it repeats).
          final tile = find.ancestor(
            of: find.text('Test Cola'),
            matching: find.byWidgetPredicate(
              (w) => w is GlassPane && w.kind == GlassKind.tile && !w.blur,
            ),
          );
          expect(tile, findsOneWidget, reason: '$name row is a glass tile');
        } else {
          // The SKU row is a console card: surface1 under the line hairline.
          final deco = _cardDecoration(tester, find.text('Test Cola'));
          expect(deco.color, palette.surface1, reason: '$name row surface');
          expect(
            (deco.border! as Border).top.color,
            palette.line,
            reason: '$name row hairline',
          );
        }
      }
    },
  );

  testWidgets(
    'the out-of-stock warning sets its words in critText, AA-safe on the '
    'card in both themes; the glyph keeps crit',
    (tester) async {
      const warning = 'Out of stock — this raises a task for the manager';
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(
          _screen(stock: _SpyStockRepository(), theme: _themeFor(name)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('units-s1')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('units-input-s1')),
          '0',
        );
        await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
        await tester.pumpAndSettle();

        // The word is the AA-safe crit-text tint; the icon may stay raw crit
        // (a glyph, paired with the word — not colour-alone).
        final textColor = tester.widget<Text>(find.text(warning)).style!.color;
        expect(
          textColor,
          // Glass: the handoff's crit ink on the note's own opaque crit wash.
          palette.glass
              ? LumenStatus.crit.swatchOf(palette).ink
              : palette.critText,
          reason: '$name warning words',
        );
        final iconColor = tester
            .widget<Icon>(find.byIcon(Icons.warning_amber_outlined))
            .color;
        expect(iconColor, palette.crit, reason: '$name warning glyph');

        // Measured on the rendered pair: the words over the card ground clear
        // 4.5:1. Raw crit as text would collapse this in dark and fail here.
        final ground = _cardDecoration(tester, find.text(warning)).color!;
        expect(
          contrastRatio(textColor!, ground),
          greaterThanOrEqualTo(4.5),
          reason: '$name warning AA (rendered pair)',
        );
      }
    },
  );

  testWidgets(
    'the count dialog is a console surface, not a raw AlertDialog, and keeps '
    'its keys + behaviour',
    (tester) async {
      final spy = _SpyStockRepository();
      for (final (name, palette) in _bothThemes) {
        await tester.pumpWidget(_screen(stock: spy, theme: _themeFor(name)));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('units-s1')));
        await tester.pumpAndSettle();

        // Off the raw AlertDialog onto a console Dialog on surface1; no raw
        // ElevatedButton in the actions row either.
        expect(
          find.byType(AlertDialog),
          findsNothing,
          reason: '$name no AlertDialog',
        );
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(
          dialog.backgroundColor,
          palette.surface1,
          reason: '$name dialog surface',
        );
        expect(
          find.byType(ElevatedButton),
          findsNothing,
          reason: '$name dialog no ElevatedButton',
        );

        // The keys and behaviour survive: type a count, confirm, and it lands.
        await tester.enterText(
          find.byKey(const ValueKey('units-input-s1')),
          '7',
        );
        await tester.tap(find.byKey(const ValueKey('units-confirm-s1')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Save stock'));
        await tester.tap(find.text('Save stock'));
        await tester.pumpAndSettle();
        expect(
          spy.entries!.first.unitsAvailable,
          7,
          reason: '$name dialog count lands',
        );
      }
    },
  );

  test('no non-geometry AppColors. remain in the S2 stock source', () {
    // Geometry (radii) stays on AppColors; every colour reads from the ambient
    // theme via context.colors, so both themes render.
    final src = File(
      'lib/features/audit/presentation/sections/s2_stock_screen.dart',
    ).readAsStringSync();
    final offenders = RegExp(
      r'AppColors\.(?!radiusPanel|radiusControl)\w+',
    ).allMatches(src).map((m) => m.group(0)).toSet().toList();
    expect(offenders, isEmpty, reason: 'use context.colors for: $offenders');
  });
}
