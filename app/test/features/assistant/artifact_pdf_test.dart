import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradeiq_app/features/assistant/data/artifact_repository.dart';
import 'package:tradeiq_app/features/assistant/export/artifact_exporter.dart';
import 'package:tradeiq_app/features/assistant/export/artifact_pdf.dart';
import 'package:tradeiq_app/features/assistant/view_specs/artifact_table.dart';

/// The golden lives beside the test rather than in `goldens/`, which in this
/// repo holds rendered images.
final _goldenPath = 'test/features/assistant/goldens/artifact_report.pdf';

/// Two fields cannot be pinned, and it is worth being precise about which.
///
/// `pdf` stamps `/CreationDate` from `DateTime.now()` and derives the document
/// `/ID` from a `Random.secure()` hash — both inside the library, neither
/// injectable. A byte-for-byte golden would therefore fail on every run, so
/// they are normalised out and *everything else* — every glyph, every layout
/// coordinate, the whole table — is compared exactly.
Uint8List _normalise(Uint8List bytes) {
  var text = String.fromCharCodes(bytes);
  text = text.replaceAll(RegExp(r'/CreationDate\(D:[^)]*\)'), '/CreationDate(D:FIXED)');
  text = text.replaceAll(
    RegExp(r'/ID\[<[0-9a-fA-F]*><[0-9a-fA-F]*>\]'),
    '/ID[<FIXED><FIXED>]',
  );
  return Uint8List.fromList(text.codeUnits);
}

ArtifactDetail _trendArtifact() => const ArtifactDetail(
  id: '2b3f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e',
  type: 'trend_chart',
  toolName: 'getMetricTrend',
  params: {
    'metric': 'availability',
    'period': {'kind': 'mtd'},
    'interval': 'day',
    'compareTo': {'kind': 'previous_period'},
  },
  data: {
    'metric': 'availability',
    'interval': 'day',
    'points': [
      {'period': '2026-08-01', 'value': 91.0},
      {'period': '2026-08-02', 'value': 93.5},
      {'period': '2026-08-03', 'value': 88.0},
    ],
    'comparison': {
      'label': 'the month to date before this one',
      'basis': {'kind': 'previous_period'},
      'points': [
        {'period': '2026-07-01', 'value': 90.0},
        {'period': '2026-07-02', 'value': 89.0},
        {'period': '2026-07-03', 'value': 0.0},
      ],
    },
  },
  canUndo: false,
);

Future<ArtifactPdfFonts> _fonts() async {
  Future<Uint8List> load(String name) async =>
      (await rootBundle.load('assets/fonts/$name')).buffer.asUint8List();
  return ArtifactPdfFonts(
    regular: await load('Inter-Regular.ttf'),
    medium: await load('Inter-Medium.ttf'),
    bold: await load('Inter-Bold.ttf'),
  );
}

ArtifactPdfRequest _request(ArtifactPdfFonts fonts, {Uint8List? chart}) =>
    ArtifactPdfRequest(
      title: 'On-shelf availability',
      subtitle: 'By day · vs the month to date before this one',
      filters: 'Month to date · daily buckets · compared with the period before.',
      tenant: 'Demo FMCG',
      // Fixed, so the header's stamp is part of the golden rather than a
      // reason to regenerate it daily.
      generatedAt: DateTime.utc(2026, 8, 17, 9, 30),
      table: artifactTableFor(_trendArtifact()),
      fonts: fonts,
      chartPng: chart,
      // Uncompressed: the golden is then readable, and a diff shows which
      // string moved rather than which byte of a deflate stream did.
      compress: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the report is a PDF, with its text searchable rather than drawn', () async {
    final bytes = await buildArtifactPdf(_request(await _fonts()));
    final raw = String.fromCharCodes(bytes);

    expect(raw.substring(0, 5), '%PDF-');
    expect(raw.trimRight().endsWith('%%EOF'), isTrue);
    // The title reaches the document metadata as plain text, which is what a
    // file manager and a search index read.
    expect(raw, contains('/Title(On-shelf availability)'));
    // Body text is written as glyph indices — that is how an embedded subset
    // works, and it is why these assertions do not grep for words. What makes
    // it *searchable in a reader* is the ToUnicode map beside each font, so
    // that is the thing worth asserting. Without it the report would look
    // right and copy out as gibberish.
    expect(raw, contains('/ToUnicode'));
    // Inter, embedded rather than referenced: the report has to render the
    // same on a machine that has never heard of the typeface.
    expect('/FontFile2'.allMatches(raw).length, greaterThanOrEqualTo(2));
  });

  test('a chart is embedded when one was captured, and omitted when not', () async {
    final fonts = await _fonts();
    final without = await buildArtifactPdf(_request(fonts));
    // A 1x1 PNG is enough to prove the image object reaches the document.
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    final with_ = await buildArtifactPdf(_request(fonts, chart: png));

    expect(String.fromCharCodes(without), isNot(contains('/Subtype/Image')));
    expect(String.fromCharCodes(with_), contains('/Subtype/Image'));
    // A failed capture must not cost the user the report — the figures are all
    // still there.
    expect(String.fromCharCodes(without), contains('On-shelf availability'));
  });

  test('matches the golden, bar the creation date and document id', () async {
    // Regenerate with:
    //   UPDATE_GOLDEN=1 flutter test test/features/assistant/artifact_pdf_test.dart
    // A diff here means the report's layout or wording moved. That is
    // sometimes intended — read the diff before regenerating, because this is
    // the only test that would notice the table quietly losing a column.
    final bytes = _normalise(await buildArtifactPdf(_request(await _fonts())));
    final golden = File(_goldenPath);

    if (Platform.environment['UPDATE_GOLDEN'] == '1') {
      golden.parent.createSync(recursive: true);
      golden.writeAsBytesSync(bytes);
    }

    expect(golden.existsSync(), isTrue, reason: 'golden missing — see the note above');
    expect(bytes, equals(golden.readAsBytesSync()));
  });

  test('the exporter finds the font files it names', () async {
    // The three weights are addressed by literal path, so renaming or moving
    // one breaks every export at runtime and nothing else would notice:
    // `analyze` cannot see inside a string, and the tests above load the fonts
    // themselves rather than through the code that ships. This asserts the
    // shipping path, which is the one that can be wrong.
    final fonts = await ArtifactExporter.loadFonts();

    expect(fonts.regular.lengthInBytes, greaterThan(1000));
    expect(fonts.medium.lengthInBytes, greaterThan(1000));
    expect(fonts.bold.lengthInBytes, greaterThan(1000));
  });

  test('the compressed document — what actually ships — is a valid PDF', () async {
    // Every test above sets `compress: false` so the golden is readable, which
    // leaves the default the app uses in production untested. Compression runs
    // the whole document through a deflate the golden never exercises.
    final bytes = await buildArtifactPdf(
      ArtifactPdfRequest(
        title: 'On-shelf availability',
        subtitle: 'By day · vs the month to date before this one',
        filters: 'Month to date · daily buckets · compared with the period before.',
        tenant: 'Demo FMCG',
        generatedAt: DateTime.utc(2026, 8, 17, 9, 30),
        table: artifactTableFor(_trendArtifact()),
        fonts: await _fonts(),
      ),
    );
    final raw = String.fromCharCodes(bytes);

    expect(raw.substring(0, 5), '%PDF-');
    expect(raw.trimRight().endsWith('%%EOF'), isTrue);
    // Smaller than the uncompressed twin, which is the only proof the deflate
    // ran at all rather than being silently skipped.
    expect(
      bytes.length,
      lessThan((await buildArtifactPdf(_request(await _fonts()))).length),
    );
  });

  test('the same request twice produces the same document', () async {
    // The property the golden depends on. If this fails, something in the
    // build path has picked up a clock or a random source of its own.
    final fonts = await _fonts();
    final first = _normalise(await buildArtifactPdf(_request(fonts)));
    final second = _normalise(await buildArtifactPdf(_request(fonts)));

    expect(first, equals(second));
  });

  test('stat_tiles and ranked_bars export as vector tables, without crashing',
      () async {
    // The answer design's two new cards. Their report is the same table the
    // expanded view shows — every cell pre-formatted with its unit and sign —
    // under the card captured as the picture.
    const tiles = ArtifactDetail(
      id: '3c4f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e',
      type: 'stat_tiles',
      toolName: 'getSalesPerformance',
      params: {},
      data: {
        'tiles': [
          {
            'label': 'Sell-in, units',
            'value': 48210,
            'unit': 'units',
            'delta': {'value': 12.4, 'unit': 'pct', 'direction': 'down', 'sentiment': 'bad'},
            'comparedTo': "vs 55,034 · Aug '25",
          },
          {'label': 'Target attainment', 'value': 81, 'unit': 'pct', 'meter': 81},
        ],
      },
      canUndo: false,
    );
    const bars = ArtifactDetail(
      id: '4d4f0d0e-1f2a-4c3b-9d4e-5f6a7b8c9d0e',
      type: 'ranked_bars',
      toolName: 'getTerritoryRanking',
      params: {},
      data: {
        'title': 'Change by territory',
        'comparedTo': "vs Aug '25",
        'unit': 'pct',
        'items': [
          {'label': 'Soweto', 'value': -31},
          {'label': 'Pretoria East', 'value': 7},
        ],
      },
      canUndo: false,
    );

    final tileTable = artifactTableFor(tiles)!;
    expect(tileTable.columns, ['Figure', 'Value', 'Change', 'Compared with']);
    expect(tileTable.rows.first.cells,
        ['Sell-in, units', '48,210', '▼ 12.4%', "vs 55,034 · Aug '25"]);
    expect(tileTable.rows.last.cells, ['Target attainment', '81%', '—', '—']);

    final barTable = artifactTableFor(bars)!;
    expect(barTable.rows.map((r) => r.cells),
        [['Soweto', '\u221231%'], ['Pretoria East', '+7%']]);

    final fonts = await _fonts();
    for (final (detail, table) in [(tiles, tileTable), (bars, barTable)]) {
      final bytes = await buildArtifactPdf(ArtifactPdfRequest(
        title: detail.type,
        filters: 'Month to date.',
        tenant: 'Demo FMCG',
        generatedAt: DateTime.utc(2026, 9, 1),
        table: table,
        fonts: fonts,
        compress: false,
      ));
      final raw = String.fromCharCodes(bytes);
      expect(raw.substring(0, 5), '%PDF-');
      expect(raw.trimRight().endsWith('%%EOF'), isTrue);
    }

    // Malformed data still yields a (possibly empty) table, never a throw.
    const junk = ArtifactDetail(
      id: 'x', type: 'ranked_bars', toolName: 't', params: {}, data: 'nope', canUndo: false,
    );
    expect(artifactTableFor(junk)!.isEmpty, isTrue);
  });
}
