import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/core/camera/photo_capture_service.dart';
import 'package:tradeiq_app/core/network/paginated_response.dart';
import 'package:tradeiq_app/core/theme/torchlight/tiq_skin.dart';
import 'package:tradeiq_app/core/widgets/torchlight/button/buttons.dart';
import 'package:tradeiq_app/core/widgets/torchlight/chrome/chrome.dart';
import 'package:tradeiq_app/features/audit/data/photos_repository.dart';
import 'package:tradeiq_app/features/audit/data/skus_repository.dart';
import 'package:tradeiq_app/features/audit/data/stock_repository.dart';
import 'package:tradeiq_app/features/audit/presentation/sections/s2_stock_screen.dart';
import 'package:image_picker/image_picker.dart';

import '../agent_harness.dart';
import 'section_harness.dart';

const _cola = Sku(
  id: 's1',
  name: 'Test Cola',
  category: 'Beverages',
  minFacingsStandard: 4,
  rrp: 19.99,
  daysOutOfStock: 0,
  velocityAvg: 4.2,
  effectivePrice: 19.99,
);

const _chips = Sku(
  id: 's2',
  name: 'Salt Crisps 125g',
  category: 'Snacks',
  minFacingsStandard: 2,
  rrp: 12.5,
  daysOutOfStock: 0,
  velocityAvg: 1.5,
  effectivePrice: 12.5,
);

/// One prior in-stock reading: `daysOutOfStock` needs one history point,
/// `velocityAvg` needs two — so a rate of zero beside a nonzero out-of-stock
/// count is a legitimate state, not a contradiction.
const _noHistory = Sku(
  id: 's1',
  name: 'Test Cola',
  category: 'Beverages',
  minFacingsStandard: 4,
  rrp: 19.99,
  daysOutOfStock: 5,
  velocityAvg: 0,
  effectivePrice: 19.99,
);

class _Skus implements SkusRepository {
  _Skus([this.skus = const <Sku>[_cola]]);

  final List<Sku> skus;

  @override
  Future<PaginatedResponse<Sku>> listSkus({
    required String outletId,
    int? limit,
    String? cursor,
  }) async => PaginatedResponse<Sku>(data: skus, nextCursor: null);
}

class _SpyStock implements StockRepository {
  String? visitDraftId;
  List<StockEntry>? entries;
  int saves = 0;

  @override
  Future<void> saveStock({
    required String visitDraftId,
    required List<StockEntry> entries,
  }) async {
    saves++;
    this.visitDraftId = visitDraftId;
    this.entries = entries;
  }
}

List<Override> _overrides({
  required StockRepository stock,
  List<Sku> skus = const <Sku>[_cola],
  QueuedPhotosRepository? photos,
  PhotoCaptureService? capture,
  double? luma = 0.5,
}) => <Override>[
  scriptedExposure(luma),
  skusRepositoryProvider.overrideWithValue(_Skus(skus)),
  stockRepositoryProvider.overrideWithValue(stock),
  if (photos != null) queuedPhotosRepositoryProvider.overrideWithValue(photos),
  if (capture != null) photoCaptureServiceProvider.overrideWithValue(capture),
];

const _screen = S2StockScreen(visitDraftId: 'v1', outletId: 'o1');

Finder _stepper(String skuId) => find.byKey(ValueKey<String>('units-$skuId'));

Finder _step(String skuId, String label) => find.descendant(
  of: _stepper(skuId),
  matching: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  ),
);

/// Open the number sheet by tapping the figure, type, and Set.
Future<void> _typeCount(WidgetTester tester, String skuId, String text) async {
  await tapInSection(tester, _step(skuId, 'Type a count'));
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey<String>('count-sheet-input')),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('count-sheet-set')));
  await tester.pumpAndSettle();
}

void main() {
  group('the count that is not zero', () {
    testWidgets('an untouched SKU is saved as null, a typed 0 as 0 (#389)', (
      tester,
    ) async {
      // The bug: this screen used to send `_units[sku.id] ?? 0`, so a shelf the
      // agent had not walked to yet was submitted as an empty one — raising a
      // restock task and dragging on-shelf availability down for a SKU nobody
      // had looked at. Null and 0 leave here as different findings, because
      // the server (#410) treats them as different findings.
      final spy = _SpyStock();
      await pumpSection(tester, _screen, overrides: _overrides(stock: spy));

      // Nothing touched: the Save is a ghost, but it still saves.
      await saveSection(tester);
      expect(spy.entries!.single.unitsAvailable, isNull);

      await _typeCount(tester, 's1', '0');
      await saveSection(tester);
      expect(spy.entries!.single.unitsAvailable, 0);
      await disposeAgentScreen(tester);
    });

    testWidgets('a part-counted save sends null for every SKU not reached', (
      tester,
    ) async {
      final spy = _SpyStock();
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: spy, skus: const <Sku>[_cola, _chips]),
      );

      await tapInSection(tester, _step('s1', 'One more'));
      // The summary says what a Save would record before it is pressed.
      expect(find.text('1 counted · 0 out of stock · 1 to go'), findsOneWidget);
      expect(
        find.text(
          'Saving now records 1 products as not counted — never as empty.',
        ),
        findsOneWidget,
      );

      await saveSection(tester);
      final byId = {for (final e in spy.entries!) e.skuId: e.unitsAvailable};
      expect(byId, <String, int?>{'s1': 1, 's2': null});
      await disposeAgentScreen(tester);
    });

    testWidgets('from not counted, minus means "there are none" and plus '
        'means "I counted one"', (tester) async {
      final spy = _SpyStock();
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: spy, skus: const <Sku>[_cola, _chips]),
      );

      await tapInSection(tester, _step('s1', 'One fewer'));
      await tapInSection(tester, _step('s2', 'One more'));
      await tapInSection(tester, _step('s2', 'One more'));
      await tapInSection(tester, _step('s2', 'One more'));
      await saveSection(tester);

      final byId = {for (final e in spy.entries!) e.skuId: e.unitsAvailable};
      expect(byId, <String, int?>{'s1': 0, 's2': 3});
      await disposeAgentScreen(tester);
    });
  });

  group('the summary rule', () {
    List<Sku> shelf(int n) => <Sku>[
      for (var i = 1; i <= n; i++)
        Sku(
          id: 'k$i',
          name: 'Product $i',
          category: 'Beverages',
          minFacingsStandard: 2,
          rrp: 10,
          daysOutOfStock: 0,
          velocityAvg: 1,
          effectivePrice: 10,
        ),
    ];

    Finder summary() => find.byKey(const ValueKey<String>('stock-summary'));
    Finder jump() => find.byKey(const ValueKey<String>('stock-jump-uncounted'));

    testWidgets('stays on screen while the shelf scrolls beneath it', (
      tester,
    ) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock(), skus: shelf(8)),
      );
      final before = tester.getTopLeft(summary()).dy;
      await scrollAgentTo(tester, _stepper('k8'));
      // The header has scrolled away; the summary has not, and it now sits at
      // the top of the viewport as the one fixed chrome.
      expect(summary().hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(summary()).dy, lessThan(before));
      expect(find.text('0 counted · 0 out of stock · 8 to go'), findsOneWidget);
      await disposeAgentScreen(tester);
    });

    testWidgets(
      'twelve products or fewer offer no jump — one flick is enough',
      (tester) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(stock: _SpyStock(), skus: shelf(12)),
        );
        expect(jump(), findsNothing);
        await disposeAgentScreen(tester);
      },
    );

    testWidgets('past twelve, the jump lands on the first uncounted product, '
        'and goes once all are counted', (tester) async {
      final skus = shelf(14);
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock(), skus: skus),
      );
      expect(jump(), findsOneWidget);

      // Count the first three; the jump must pass over them.
      for (final id in <String>['k1', 'k2', 'k3']) {
        await tapInSection(tester, _step(id, 'One more'));
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.tap(jump());
      await tester.pumpAndSettle();
      // Visible and not hidden under the pinned band.
      expect(_step('k4', 'One more').hitTestable(), findsOneWidget);
      final band = tester.getBottomLeft(summary()).dy;
      expect(tester.getTopLeft(_stepper('k4')).dy, greaterThan(band));

      for (final sku in skus.skip(3)) {
        await tapInSection(tester, _step(sku.id, 'One more'));
      }
      expect(jump(), findsNothing);
      await disposeAgentScreen(tester);
    });

    testWidgets('a part-finished save says "Saved 1 of 2", a full one does '
        'not', (tester) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(
          stock: _SpyStock(),
          skus: const <Sku>[_cola, _chips],
        ),
      );
      await tapInSection(tester, _step('s1', 'One more'));
      await saveSection(tester);
      expect(
        find.textContaining(
          'Saved 1 of 2 — the rest are not counted, never empty',
        ),
        findsOneWidget,
      );

      await tapInSection(tester, _step('s2', 'One more'));
      await saveSection(tester);
      expect(find.textContaining('Saved 1 of 2'), findsNothing);
      expect(
        find.textContaining('Stock saved — queued for sync'),
        findsOneWidget,
      );
      await disposeAgentScreen(tester);
    });

    // THE BAND'S OWN 40%. Measured on the merged code, the band's rect after
    // the header scrolled away was 187dp at 1.0×, 296dp at 1.4× (46% of a
    // 640dp phone, past unify §4's ceiling for anything holding a place at the
    // top of a route) and 543dp at 2.0× — 85% of the screen, leaving under
    // 100dp for the shelf it is a summary of: less than one SKU block and its
    // stepper. The group above runs at 1.0× in English with "Product N" names
    // and `sections_scale_test` only asks for no exception and the amber
    // ceiling, so neither could see it.
    const double viewportHeight = 640;
    const double bandCeiling = viewportHeight * TorchShell.pinnedBandFraction;

    for (final skin in agentSkinModes) {
      for (final locale in const <Locale>[Locale('en'), Locale('af')]) {
        for (final scale in const <double>[1.0, 1.4, 2.0]) {
          final where = '${skin.name}, ${locale.languageCode}, $scale×';

          testWidgets('the band is never more than 40% of the fold — $where', (
            tester,
          ) async {
            await pumpSection(
              tester,
              _screen,
              overrides: _overrides(stock: _SpyStock(), skus: shelf(14)),
              skin: skin,
              textScale: scale,
              locale: locale,
            );
            // Offstage on arrival wherever the header takes the whole fold
            // (see the note on Veld below) — its HEIGHT is still the law.
            final band = find.byKey(
              const ValueKey<String>('torch-shell-pinned'),
              skipOffstage: false,
            );

            expect(
              tester.takeException(),
              isNull,
              reason: 'on arrival, $where',
            );
            expect(
              tester.getSize(band).height,
              lessThanOrEqualTo(bandCeiling),
              reason: 'on arrival, $where',
            );

            // And after the header has gone, which is the frame the band
            // exists for.
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -900),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'scrolled, $where');
            expect(
              tester.getSize(band).height,
              lessThanOrEqualTo(bandCeiling),
              reason: 'scrolled, $where',
            );
            expect(
              summary().hitTestable(),
              findsOneWidget,
              reason:
                  'pinned and reachable once the header is away, $where — '
                  'the whole point of a band on a 60-SKU shelf',
            );
            // The count is still the count, whichever half of the band is
            // carrying the words.
            expect(jump(), findsOneWidget, reason: where);
            await disposeAgentScreen(tester);
          });
        }
      }
    }

    // ON ARRIVAL, not one flick down. An uncapped band plus a header was
    // taller than the fold, so the sliver got no paint extent at all: at 2.0×
    // in Afrikaans an agent opening Stock saw the header and nothing else, and
    // the "only fixed chrome on a 60-SKU shelf" was not in the frame.
    //
    // Veld at 2.0× is absent from this list on purpose, and it is not the
    // band's doing. Measured there: `TorchAppHeader` is 324dp against unify
    // §4's 256dp ceiling — `chrome_scale_test` only ever asserted that ceiling
    // in Night — and the bottom region takes 323dp, which leaves the scroll
    // view 317dp of a 640dp screen. The header block alone is 364dp, so
    // nothing at the top of that route is on the fold, band or not. When that
    // arithmetic is fixed, add `2.0` to the Veld row here.
    for (final (skin, scales) in <(SkinMode, List<double>)>[
      (SkinMode.night, <double>[1.0, 1.4, 2.0]),
      (SkinMode.day, <double>[1.0, 1.4, 2.0]),
      (SkinMode.veld, <double>[1.0, 1.4]),
    ]) {
      for (final scale in scales) {
        for (final locale in const <Locale>[Locale('en'), Locale('af')]) {
          testWidgets('the band is chrome on arrival — ${skin.name}, '
              '${locale.languageCode}, $scale×', (tester) async {
            await pumpSection(
              tester,
              _screen,
              overrides: _overrides(stock: _SpyStock(), skus: shelf(14)),
              skin: skin,
              textScale: scale,
              locale: locale,
            );
            expect(
              summary().hitTestable(),
              findsOneWidget,
              reason:
                  'the agent has not scrolled yet, and the summary is what '
                  'says what a Save would record',
            );
            await disposeAgentScreen(tester);
          });
        }
      }
    }

    testWidgets('collapsed, the sentence and the jump are the first things in '
        'the body — not lost', (tester) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock(), skus: shelf(14)),
        textScale: 2.0,
      );
      final band = find.byKey(const ValueKey<String>('torch-shell-pinned'));
      // Below the fold at 2.0× — that is where a 640dp phone puts anything
      // under a header and a band — so it is found without the offstage skip
      // and then scrolled to like any other row.
      final detail = find.byKey(
        const ValueKey<String>('stock-summary-detail'),
        skipOffstage: false,
      );
      final anyJump = find.byKey(
        const ValueKey<String>('stock-jump-uncounted'),
        skipOffstage: false,
      );

      expect(detail, findsOneWidget);
      expect(
        find.descendant(of: band, matching: anyJump),
        findsNothing,
        reason: 'the jump left the band',
      );
      expect(find.descendant(of: detail, matching: anyJump), findsOneWidget);
      expect(
        find.text(
          'Saving now records 14 products as not counted — never as empty.',
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: 'the sentence went with it, word for word',
      );
      // Ahead of the first product, so it is the first thing under the band
      // rather than something to hunt for at the bottom of a 60-SKU shelf.
      expect(
        tester.getTopLeft(detail).dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(
                  const ValueKey<String>('units-k1'),
                  skipOffstage: false,
                ),
              )
              .dy,
        ),
      );
      await scrollAgentTo(tester, anyJump);
      expect(jump().hitTestable(), findsOneWidget);
      await disposeAgentScreen(tester);
    });

    for (final skin in agentSkinModes) {
      testWidgets(
        'the pinned band and its jump paint no amber — ${skin.name}',
        (tester) async {
          await pumpSection(
            tester,
            _screen,
            overrides: _overrides(stock: _SpyStock(), skus: shelf(14)),
            skin: skin,
          );
          expect(jump(), findsOneWidget);
          await expectAmber(
            tester,
            skin: skin,
            route: 'stock',
            phase: 'untouched, pinned summary',
            expected: 0,
          );
          await disposeAgentScreen(tester);
        },
      );
    }
  });

  group('the number sheet', () {
    testWidgets('typing opens a sheet titled with the product; Set lands the '
        'count', (tester) async {
      final spy = _SpyStock();
      await pumpSection(tester, _screen, overrides: _overrides(stock: spy));

      await tapInSection(tester, _step('s1', 'Type a count'));
      // The product's name is the sheet's title, so the agent can see which
      // shelf the figure is going to.
      expect(find.text('Test Cola'), findsNWidgets(2));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('count-sheet-input')),
          matching: find.byType(EditableText),
        ),
        '20',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('count-sheet-set')));
      await tester.pumpAndSettle();

      await saveSection(tester);
      expect(spy.visitDraftId, 'v1');
      expect(spy.entries!.single.unitsAvailable, 20);
      expect(
        find.textContaining('Stock saved — queued for sync'),
        findsOneWidget,
      );
      await disposeAgentScreen(tester);
    });

    testWidgets('Cancel leaves the count exactly as it was — a stray tap never '
        'replaces a count', (tester) async {
      final spy = _SpyStock();
      await pumpSection(tester, _screen, overrides: _overrides(stock: spy));

      await tapInSection(tester, _step('s1', 'One more'));
      await tapInSection(tester, _step('s1', 'One more'));

      await tapInSection(tester, _step('s1', 'Type a count'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('count-sheet-input')),
          matching: find.byType(EditableText),
        ),
        '7',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('count-sheet-cancel')),
      );
      await tester.pumpAndSettle();

      await saveSection(tester);
      expect(spy.entries!.single.unitsAvailable, 2);
      await disposeAgentScreen(tester);
    });

    testWidgets('an empty sheet cannot Set, and says what it is waiting for', (
      tester,
    ) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock()),
      );
      await tapInSection(tester, _step('s1', 'Type a count'));
      final set = tester.widget<TorchPrimaryButton>(
        find.byKey(const ValueKey<String>('count-sheet-set')),
      );
      expect(set.onPressed, isNull);
      expect(find.text('Type a count first'), findsOneWidget);
      // Close it: the open-sheet count is app-wide, and a sheet left open at
      // teardown would extinguish every amber in the tests after this one.
      await tester.tap(
        find.byKey(const ValueKey<String>('count-sheet-cancel')),
      );
      await tester.pumpAndSettle();
      await disposeAgentScreen(tester);
    });
  });

  group('zero is a finding', () {
    testWidgets('a zero shows the bar, the words, and the reason', (
      tester,
    ) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock()),
      );
      await tapInSection(tester, _step('s1', 'One fewer'));

      expect(find.byKey(const ValueKey<String>('finding-s1')), findsOneWidget);
      expect(
        find.text(
          'Out of stock — this raises a task for the manager\n'
          '70% of shoppers switch brand when the product is missing.',
        ),
        findsOneWidget,
      );
      // The word on its chip, so the finding is never carried by colour alone.
      expect(find.text('Out of stock'), findsOneWidget);
      await disposeAgentScreen(tester);
    });

    testWidgets(
      'landing on zero buzzes heavier than a step, typed or stepped',
      (tester) async {
        final buzzes = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              buzzes.add(call.arguments as String);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(
            stock: _SpyStock(),
            skus: const <Sku>[_cola, _chips],
          ),
        );
        buzzes.clear();
        await tapInSection(tester, _step('s1', 'One more'));
        expect(buzzes, isNot(contains('HapticFeedbackType.heavyImpact')));

        await tapInSection(tester, _step('s1', 'One fewer'));
        expect(buzzes.last, 'HapticFeedbackType.heavyImpact');

        buzzes.clear();
        await _typeCount(tester, 's2', '0');
        expect(buzzes, contains('HapticFeedbackType.heavyImpact'));
        await disposeAgentScreen(tester);
      },
    );
  });

  group('server context', () {
    testWidgets('velocity is read-only context, through the locale formatter', (
      tester,
    ) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock()),
      );
      expect(find.text('Selling ~4.2/day'), findsOneWidget);
      await disposeAgentScreen(tester);
    });

    testWidgets('Afrikaans reads the same velocity with a comma', (
      tester,
    ) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock()),
        locale: const Locale('af'),
      );
      expect(find.text('Verkoop ~4,2/dag'), findsOneWidget);
      await disposeAgentScreen(tester);
    });

    testWidgets('with no velocity history the context line stands on its own', (
      tester,
    ) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(
          stock: _SpyStock(),
          skus: const <Sku>[_noHistory],
        ),
      );
      // A rate of zero does not mean "Selling 0/day" — there is no rate yet,
      // and that can still come with a known out-of-stock count.
      expect(
        find.text('No sales history yet · out of stock 5d'),
        findsOneWidget,
      );
      await disposeAgentScreen(tester);
    });
  });

  group('the shelf photo', () {
    testWidgets('is queued once as stock evidence, with its gpsTag and shutter '
        'time (#310)', (tester) async {
      final shutter = DateTime.utc(2026, 9, 15, 10, 4, 5);
      final photos = SpyQueuedPhotos();
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(
          stock: _SpyStock(),
          photos: photos,
          capture: fakeCapture(shutter: shutter),
        ),
      );

      await takeSectionPhoto(tester);
      expect(
        find.byKey(const ValueKey<String>('photo-preview')),
        findsOneWidget,
      );

      await saveSection(tester);
      expect(photos.calls, hasLength(1));
      final call = photos.calls.single;
      expect(call['visitDraftId'], 'v1');
      expect(call['section'], 'stock');
      expect(call['dataUrl'], startsWith('data:image/jpeg;base64,'));
      expect(call['gpsTag'], <String, Object>{
        'lat': -26.2041,
        'lng': 28.0473,
        'accuracy': 7.0,
      });
      expect(call['capturedAt'], shutter);

      // A second Save re-sends the counts, not a duplicate photo.
      await saveSection(tester);
      expect(photos.calls, hasLength(1));
      await disposeAgentScreen(tester);
    });

    testWidgets('the gallery is still there when the camera is not', (
      tester,
    ) async {
      final gateway = FakePhotoGateway();
      final photos = SpyQueuedPhotos();
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(
          stock: _SpyStock(),
          photos: photos,
          capture: fakeCapture(gateway: gateway),
        ),
      );

      await takeSectionPhoto(tester, gallery: true);
      expect(gateway.sources, <ImageSource>[ImageSource.gallery]);
      await saveSection(tester);
      expect(photos.calls.single['section'], 'stock');
      await disposeAgentScreen(tester);
    });
  });

  testWidgets('a dark frame is questioned before it is kept, and stays marked '
      'in the section once kept', (tester) async {
    final photos = SpyQueuedPhotos();
    await pumpSection(
      tester,
      _screen,
      overrides: _overrides(
        stock: _SpyStock(),
        photos: photos,
        capture: fakeCapture(),
        luma: 0.05,
      ),
    );
    await takeSectionPhoto(tester);
    await scrollAgentTo(
      tester,
      find.byKey(const ValueKey<String>('section-photo-dark')),
    );
    expect(find.text('Dark — retake?'), findsOneWidget);
    await saveSection(tester);
    // Kept, never dropped: during Stage 6 it may be the only evidence.
    expect(photos.calls, hasLength(1));
    await disposeAgentScreen(tester);
  });

  group('no SKUs', () {
    testWidgets('is an empty state with no Save, and can be declared '
        "can't-confirm", (tester) async {
      await pumpSection(
        tester,
        _screen,
        overrides: _overrides(stock: _SpyStock(), skus: const <Sku>[]),
      );
      expect(find.text('No SKUs configured for this client.'), findsOneWidget);
      expect(sectionSave, findsNothing);
      expect(
        find.byKey(const ValueKey<String>('section-cant-confirm')),
        findsOneWidget,
      );
      await disposeAgentScreen(tester);
    });
  });

  group('the amber census', () {
    for (final skin in agentSkinModes) {
      testWidgets('untouched is zero — ${skin.name}', (tester) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(stock: _SpyStock()),
          skin: skin,
        );
        await expectAmber(
          tester,
          skin: skin,
          route: 'stock',
          phase: 'untouched',
          expected: 0,
        );
        await disposeAgentScreen(tester);
      });

      testWidgets('a zero finding with an armed Save is exactly one — '
          '${skin.name}', (tester) async {
        await pumpSection(
          tester,
          _screen,
          overrides: _overrides(stock: _SpyStock()),
          skin: skin,
        );
        await tapInSection(tester, _step('s1', 'One fewer'));
        await scrollAgentTo(tester, sectionSave);
        await expectAmber(
          tester,
          skin: skin,
          route: 'stock',
          phase: 'dirty, finding',
          expected: 1,
        );
        await disposeAgentScreen(tester);
      });
    }
  });
}
