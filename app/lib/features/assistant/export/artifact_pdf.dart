import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/design/tiq_number.dart';
import '../view_specs/artifact_table.dart';

/// The print mode of an artifact — paginated, controls stripped.
///
/// **Hybrid fidelity, on purpose.** Text, the header and the data table are
/// *vector*: crisp at any zoom, selectable, searchable, and greppable by
/// whoever receives the file. The chart is a **raster** captured from the live
/// widget at ≥2× device pixel ratio. Vector-only would mean reimplementing
/// every `CustomPainter` against a second drawing API — two chart engines to
/// keep in step, which is exactly the kind of duplication that drifts.
/// Raster-only would give a blurry report whose numbers cannot be copied.
///
/// **Everything here is data, not widgets.** No `BuildContext`, no
/// `rootBundle`, no plugins — a background isolate has none of them. The caller
/// gathers what is needed on the UI isolate and ships this object across.

/// What the document needs, in a form that survives an isolate boundary.
class ArtifactPdfRequest {
  const ArtifactPdfRequest({
    required this.title,
    required this.filters,
    required this.tenant,
    required this.generatedAt,
    required this.fonts,
    this.subtitle,
    this.chartPng,
    this.table,
    this.compress = true,
  });

  /// What the view is, in the manager's words — "Execution score".
  final String title;

  /// "By day · vs the month before this one", or null.
  final String? subtitle;

  /// The applied filters spelled out. **Load-bearing**: a chart with no visible
  /// date range is a support ticket waiting to happen, and a PDF travels far
  /// from the conversation that produced it.
  final String filters;

  /// Whose data this is. A report with no tenant on it is one nobody can file.
  final String tenant;

  final DateTime generatedAt;

  /// The chart as PNG bytes, or null when the artifact has no chart (or the
  /// capture failed — a report without the picture still carries every figure,
  /// which is a better outcome than no report).
  final Uint8List? chartPng;

  /// The same table the screen shows, derived once in [artifactTableFor].
  final ArtifactTable? table;

  /// Onest, as bundled with the app. Passed in rather than loaded here because
  /// `rootBundle` does not exist in a background isolate.
  final ArtifactPdfFonts fonts;

  /// Off only in tests, where an uncompressed document can be read as text.
  final bool compress;
}

class ArtifactPdfFonts {
  const ArtifactPdfFonts({
    required this.regular,
    required this.medium,
    required this.bold,
    required this.fallback,
  });

  final Uint8List regular;
  final Uint8List medium;
  final Uint8List bold;

  /// JetBrains Mono, carried purely as a glyph fallback.
  ///
  /// Onest has no geometric shapes — U+25B2/25BC, the solid up and down
  /// triangles the delta marker draws, are simply not in the face (Inter had
  /// them). `package:pdf` does not tofu a missing glyph, it drops it and logs,
  /// so without this the sign of every delta in an exported report would
  /// vanish silently. JetBrains Mono ships in the app already and has all four
  /// shapes.
  final Uint8List fallback;
}

/// Build the document. Pure: same request in, same document out — bar the two
/// fields the library stamps itself (see `artifact_pdf_test.dart`).
///
/// Runs under `compute()` on mobile and desktop, so a long table never blocks
/// the frame. **On web there is no second isolate** and `compute` runs inline;
/// that is a platform limit rather than a decision, and it is why the caller
/// still shows a progress state rather than assuming the work is off-thread.
Future<Uint8List> buildArtifactPdf(ArtifactPdfRequest request) async {
  final regular = pw.Font.ttf(request.fonts.regular.buffer.asByteData());
  final medium = pw.Font.ttf(request.fonts.medium.buffer.asByteData());
  final bold = pw.Font.ttf(request.fonts.bold.buffer.asByteData());
  final fallback = pw.Font.ttf(request.fonts.fallback.buffer.asByteData());

  final document = pw.Document(
    compress: request.compress,
    title: request.title,
    producer: 'TradeIQ',
    subject: request.filters,
    theme: pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      fontFallback: <pw.Font>[fallback],
    ),
  );

  final ink1 = PdfColor.fromInt(0xFF14161C);
  final ink2 = PdfColor.fromInt(0xFF4C5560);
  final ink3 = PdfColor.fromInt(0xFF5F6875);
  final line = PdfColor.fromInt(0xFFE3E5EA);
  // The light palette, always — a dark-themed report wastes toner and reads
  // badly on paper, which is the one medium this mode exists for.
  final good = PdfColor.fromInt(0xFF0B7A0B);
  final crit = PdfColor.fromInt(0xFFB32E2E);

  final table = request.table;
  final chart = request.chartPng;

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 32),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          // Repeated on continuation pages only: page one carries the full
          // header, and a table that spills should still say what it is.
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                '${request.title} — ${request.filters}',
                style: pw.TextStyle(fontSize: 8, color: ink3),
              ),
            ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: ink3),
        ),
      ),
      build: (context) => [
        pw.Text(
          request.tenant,
          style: pw.TextStyle(fontSize: 9, color: ink3, letterSpacing: 0.6),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          request.title,
          style: pw.TextStyle(fontSize: 20, font: bold, color: ink1),
        ),
        if (request.subtitle != null && request.subtitle!.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            request.subtitle!,
            style: pw.TextStyle(fontSize: 11, font: medium, color: ink2),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: line),
              bottom: pw.BorderSide(color: line),
            ),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  request.filters,
                  style: pw.TextStyle(fontSize: 9.5, color: ink2),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                _stamp(request.generatedAt),
                style: pw.TextStyle(fontSize: 9.5, color: ink3),
              ),
            ],
          ),
        ),
        if (chart != null) ...[
          pw.SizedBox(height: 14),
          // Width-fitted, height free: the capture's own aspect ratio decides,
          // so a tall chart is not squashed into a letterbox.
          pw.Image(pw.MemoryImage(chart), fit: pw.BoxFit.fitWidth),
        ],
        if (table != null && !table.isEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Figures',
            style: pw.TextStyle(fontSize: 11, font: bold, color: ink1),
          ),
          pw.SizedBox(height: 6),
          _table(table, bold: bold, ink1: ink1, ink2: ink2, ink3: ink3, line: line, good: good, crit: crit),
        ],
        pw.SizedBox(height: 14),
        pw.Text(
          // Says where the numbers came from and when, because a figure in a
          // shared file outlives the session that produced it.
          'Generated by TradeIQ from live data at the time shown. Re-open the '
          'view in TradeIQ for current figures.',
          style: pw.TextStyle(fontSize: 8, color: ink3),
        ),
      ],
    ),
  );

  // `save()` is async in the widget layer but resolves synchronously here —
  // there is no I/O in it, only serialisation — so the isolate boundary stays a
  // plain value in, plain value out.
  return document.save();
}

pw.Widget _table(
  ArtifactTable table, {
  required pw.Font bold,
  required PdfColor ink1,
  required PdfColor ink2,
  required PdfColor ink3,
  required PdfColor line,
  required PdfColor good,
  required PdfColor crit,
}) {
  return pw.Table(
    border: pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.5)),
    columnWidths: {
      for (var i = 0; i < table.columns.length; i++)
        i: pw.FlexColumnWidth(i == 0 ? 3 : 2),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: ink3, width: 0.7)),
        ),
        children: [
          for (final column in table.columns)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text(
                column.toUpperCase(),
                style: pw.TextStyle(fontSize: 7.5, font: bold, color: ink3, letterSpacing: 0.5),
              ),
            ),
        ],
      ),
      for (final row in table.rows)
        pw.TableRow(
          children: [
            for (var i = 0; i < table.columns.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: i < row.cells.length
                    ? pw.Text(
                        row.cells[i],
                        style: pw.TextStyle(
                          fontSize: 9,
                          font: i == 1 ? bold : null,
                          color: i == 0 ? ink2 : (i == 1 ? ink1 : ink3),
                        ),
                      )
                    // The Change column, last. The sign is a character — `+`
                    // or a true minus — so direction survives greyscale,
                    // photocopying and colour-vision deficiency — colour only
                    // reinforces it.
                    : pw.Text(
                        _changeText(row),
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: row.delta == null
                              ? ink3
                              : (row.delta! < 0 ? crit : good),
                        ),
                      ),
              ),
          ],
        ),
    ],
  );
}

String _changeText(ArtifactTableRow row) {
  final delta = row.delta;
  if (delta == null) return '—';
  // Signed, not arrowed: U+25B2/U+25BC are not in the PDF's base font and
  // drew as nothing (#401). A true minus survives greyscale printing too.
  final amount = TiqNumber.en.format(delta, signed: true);
  final pct = row.deltaPct;
  // No percentage is invented from a zero baseline: the bracket is dropped.
  return pct == null ? amount : '$amount  (${formatChangePct(pct)})';
}

String _stamp(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
}
