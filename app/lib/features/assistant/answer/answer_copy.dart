import 'package:flutter/widgets.dart';

import '../../../core/design/tiq_number.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import '../view_specs/instrument_panel.dart';
import '../view_specs/rich_figures.dart';
import '../view_specs/trend_chart_card.dart';
import 'answer_markdown.dart';
import 'answer_notes.dart';

/// THE ANSWER AS PLAIN TEXT, FOR SOMEWHERE THIS APP DOES NOT CONTROL.
///
/// A manager pastes an answer into WhatsApp, into an email to a supplier, into
/// the notes field of a meeting invitation. What she pastes has to carry the
/// same figures the screen showed her, in her own locale's separators, and it
/// has to keep the two distinctions the screen spends its whole design budget
/// making:
///
/// - **Unknown is not zero.** A missing figure is an em dash and a sentence,
///   exactly as it is drawn.
/// - **Outside data stays outside.** Figures from the open web are written in
///   their own section, each carrying the source it came from, so a figure
///   that was never ours cannot be pasted into a column of ours.
///
/// Markdown markers are stripped: a copy that pastes `**Sell-in**` into a
/// WhatsApp message is a copy that pasted the app's internals.
String answerPlainText(
  BuildContext context, {
  required ChatMessage message,
  String? question,
}) {
  final l10n = context.l10n;
  final number = TiqNumber.of(context);
  final parsed = parseAnswer(message.text, streaming: false);
  final figures = AnswerFigures.of(message);
  final lines = <String>[];

  if (question != null && question.trim().isNotEmpty) {
    lines
      ..add('${l10n.askYourQuestion}: ${question.trim()}')
      ..add('');
  }

  for (final block in parsed.blocks) {
    switch (block.kind) {
      case AnswerBlockKind.bullets:
        for (final item in block.items) {
          lines.add('- ${_plain(item)}');
        }
      case AnswerBlockKind.numbered:
        for (var i = 0; i < block.items.length; i++) {
          lines.add('${i + 1}. ${_plain(block.items[i])}');
        }
      case AnswerBlockKind.quote:
        // The callout keeps its kicker, because the kicker is what says this
        // sentence is the cause rather than another paragraph.
        final kicker = block.kicker;
        lines.add(
          kicker == null
              ? _plain(block.text)
              : '$kicker: ${_plain(block.text)}',
        );
      case AnswerBlockKind.heading:
      case AnswerBlockKind.paragraph:
      case AnswerBlockKind.code:
        lines.add(_plain(block.text));
    }
    lines.add('');
  }

  final internal = _figureLines(l10n, number, figures.internal);
  if (internal.isNotEmpty) {
    lines
      ..add('${l10n.askFigures}:')
      ..addAll(internal)
      ..add('');
  }

  // Outside figures are bracketed with the index of the source they came
  // from, so the reference survives the paste.
  final outside = <String>[];
  for (final artifact in figures.outside) {
    final provenance = FigureProvenance.from(artifact.data);
    final index = _sourceIndex(message, provenance);
    for (final line in _figureLines(l10n, number, <ChatArtifact>[artifact])) {
      outside.add(index == null ? line : '$line [$index]');
    }
  }
  if (outside.isNotEmpty) {
    lines
      ..add('${l10n.askOutsideData}:')
      ..addAll(outside)
      ..add('');
  }

  final notice = message.notice;
  if (notice != null) {
    lines
      ..add(AnswerNotice.reasonFor(l10n, notice.code))
      ..add('');
  }

  if (message.sources.isNotEmpty) {
    lines.add('${l10n.askSources}:');
    for (var i = 0; i < message.sources.length; i++) {
      final source = message.sources[i];
      lines.add('${i + 1}. ${source.domain} — ${source.title} — ${source.url}');
    }
    lines.add('');
  }

  return lines.join('\n').trimRight();
}

/// Inline markdown, removed — through the screen's own parser, so what is
/// copied is exactly the words that were drawn. A second regex here would be
/// a second definition of what a marker is, and the two would drift.
String _plain(String text) =>
    parseInline(text, streaming: false).map((run) => run.text).join().trim();

/// One line per figure, with its unit and — where there is one — its movement
/// and what it was measured against.
List<String> _figureLines(
  AppLocalizations l10n,
  TiqNumber number,
  List<ChatArtifact> artifacts,
) {
  final lines = <String>[];
  for (final artifact in artifacts) {
    switch (artifact.type) {
      case 'stat_tiles':
        for (final tile in StatTileData.listFrom(artifact.data)) {
          final parts = <String>[
            '${tile.label}: ${tile.value == null ? emDash : tile.formatted(number: number)}',
          ];
          if (tile.value == null) {
            parts.add('(${l10n.askTileNoData})');
          } else {
            final delta = tile.delta;
            if (delta != null) parts.add(delta.text(number: number));
            final against = tile.comparedTo;
            if (against != null) parts.add(against);
          }
          lines.add('- ${parts.join(' ')}');
        }
      case 'ranked_bars':
        final data = RankedBarsData.from(artifact.data);
        if (data.title != null) lines.add('- ${data.title}');
        for (final item in data.items) {
          lines.add(
            '  - ${item.label}: ${data.label(item.value, number: number)}',
          );
        }
      case 'trend_chart':
        final data = artifact.data;
        if (data is! Map) break;
        final metric = data['metric'];
        final title = TrendChartCard.metricLabel(
          l10n,
          metric is String ? metric : null,
        );
        // A chart cannot be pasted, so what the plot said is: where it
        // started and where it ended, in the reader's own separators.
        final points = <(String, num)>[
          for (final row
              in (data['points'] is List
                  ? data['points'] as List
                  : const <dynamic>[]))
            if (row is Map &&
                row['value'] is num &&
                (row['value'] as num).isFinite)
              (
                row['period'] is String ? row['period'] as String : '',
                row['value'] as num,
              ),
        ];
        final unit = TrendChartCard.percentMetrics.contains(metric)
            ? TiqUnit.percent
            : TiqUnit.none;
        lines.add(
          points.length < 2
              ? '- $title'
              : '- $title: '
                    '${points.first.$1} ${number.format(points.first.$2, unit: unit, decimals: 1)} '
                    '$emDash '
                    '${points.last.$1} ${number.format(points.last.$2, unit: unit, decimals: 1)}',
        );
      default:
        break;
    }
  }
  return lines;
}

/// Which cited source an outside figure came from, 1-based, or null when the
/// turn cited nothing that matches.
int? _sourceIndex(ChatMessage message, FigureProvenance provenance) {
  final publisher = provenance.publisher;
  if (publisher == null) return null;
  for (var i = 0; i < message.sources.length; i++) {
    final source = message.sources[i];
    if (source.domain == publisher || source.title == publisher) return i + 1;
  }
  return null;
}
