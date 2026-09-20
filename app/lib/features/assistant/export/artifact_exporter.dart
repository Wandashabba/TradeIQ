import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../view_specs/artifact_table.dart';
import 'artifact_pdf.dart';

/// What the screen knows about the report it wants.
///
/// Deliberately free of fonts, pixels and plugins: the screen describes *what*
/// to export, and everything platform-shaped — reading the bundle, rasterising
/// the chart, spawning the isolate, opening the share sheet — lives on the far
/// side of [ArtifactExporter]. That is what lets a widget test assert the right
/// report was requested without a share sheet or a compositor in sight.
class ArtifactExportRequest {
  const ArtifactExportRequest({
    required this.title,
    required this.filters,
    required this.tenant,
    required this.captureKey,
    this.subtitle,
    this.table,
    this.devicePixelRatio = 1,
  });

  final String title;
  final String? subtitle;

  /// The applied filters as a sentence — the same one the screen shows.
  final String filters;
  final String tenant;

  /// The table twin's rows, derived by [artifactTableFor] so the report and the
  /// screen cannot disagree about a figure.
  final ArtifactTable? table;

  /// The boundary wrapping the rendered view, for the raster half.
  final GlobalKey captureKey;
  final double devicePixelRatio;
}

/// Turns what is on screen into a PDF and hands it to the platform.
///
/// Behind a provider for one reason: `Printing` is a plugin and `toImage` wants
/// a real compositor, so a widget test that tapped Export would reach for two
/// things a test binding does not have. Tests swap in a recorder; production
/// gets the share sheet.
class ArtifactExporter {
  const ArtifactExporter();

  /// How sharp the rasterised chart is.
  ///
  /// At 1× the chart is a screenshot and looks it — visibly soft the moment
  /// anyone zooms or prints. 2× is the floor; a device that already reports
  /// more gets its own ratio, because downsampling later is free and detail
  /// that was never captured is not recoverable.
  static const double minimumPixelRatio = 2;

  Future<void> export(
    ArtifactExportRequest request, {
    required String filename,
  }) async {
    final fonts = await loadFonts();
    final chart = await captureChart(
      request.captureKey,
      devicePixelRatio: request.devicePixelRatio,
    );

    // `compute` puts the layout work on a background isolate wherever one
    // exists, so a long table never drops frames. On web there is no second
    // isolate and this runs inline — a platform limit, and the reason the
    // caller shows a progress state either way.
    final bytes = await compute(
      buildArtifactPdf,
      ArtifactPdfRequest(
        title: request.title,
        subtitle: request.subtitle,
        filters: request.filters,
        tenant: request.tenant,
        generatedAt: DateTime.now(),
        chartPng: chart,
        table: request.table,
        fonts: fonts,
      ),
    );

    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// The bundled Onest weights, as bytes an isolate can carry.
  ///
  /// Bundled rather than fetched, for the same reason the theme bundles them:
  /// the report has to look like the product on a phone with no signal, and a
  /// runtime font download would leave it rendering in something else.
  ///
  /// These are the PDF-only static instances, not `Onest-Variable.ttf`:
  /// `package:pdf` reads `glyf` outlines and ignores a variable font's `gvar`
  /// deltas, so the variable file would render medium and bold at regular.
  static Future<ArtifactPdfFonts> loadFonts() async {
    Future<Uint8List> load(String name) async =>
        (await rootBundle.load('assets/fonts/$name')).buffer.asUint8List();

    // Sequential: three small reads off the same bundle, and a report is not
    // where concurrency earns anything.
    return ArtifactPdfFonts(
      regular: await load('Onest-Pdf-400.ttf'),
      medium: await load('Onest-Pdf-500.ttf'),
      bold: await load('Onest-Pdf-700.ttf'),
      // Onest has no U+25B2/25BC; without this the delta arrows disappear.
      fallback: await load('JetBrainsMono-Regular.ttf'),
    );
  }

  /// The chart as PNG bytes, captured from the live widget.
  ///
  /// Returns null rather than throwing when the boundary is not painted yet or
  /// the platform refuses: a report carrying every figure but no picture is a
  /// far better outcome than an export that fails outright, and the table twin
  /// below it holds the same values.
  static Future<Uint8List?> captureChart(
    GlobalKey key, {
    double devicePixelRatio = 1,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(
        pixelRatio: math.max(minimumPixelRatio, devicePixelRatio),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (err) {
      debugPrint(
        '[assistant] chart capture failed, exporting without it: $err',
      );
      return null;
    }
  }
}

final artifactExporterProvider = Provider<ArtifactExporter>(
  (ref) => const ArtifactExporter(),
);
