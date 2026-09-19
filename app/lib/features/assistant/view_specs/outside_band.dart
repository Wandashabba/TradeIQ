import 'package:flutter/widgets.dart';

import '../../../core/design/figure_slot.dart';
import '../../../core/design/tiq_number.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/figure/eyebrow.dart';
import '../../../core/widgets/torchlight/row/row.dart';
import '../../../l10n/l10n.dart';
import '../data/chat_controller.dart';
import 'rich_figures.dart';
import 'stat_tiles_card.dart' show askUnitFor;

/// THE OUTSIDE-DATA BAND.
///
/// Figures that came from outside TradeIQ — a retailer's website, Stats SA,
/// the weather — carried without ever letting them touch an internal total.
///
/// **Below the panel, never inside it**, and never in the panel's shape: rows,
/// not tiles, and never a grid, because the grid is the internal instrument's
/// form and borrowing it is exactly the confusion this band exists to prevent.
/// Nothing here is summed, averaged or compared against an internal figure by
/// the client, and the server refuses a run that mixes the two at all.
///
/// Three channels carry "outside": the 2dp `comparison` left rule, the word,
/// and the dashed underline beneath each value's own width.
///
/// **Amber: none, in any mode, ever.** Outside data is the category most
/// likely to be mistaken for a warning if given the brand colour; it takes
/// `comparison`, the system's declared "them, unlit" channel.
class OutsideDataBand extends StatelessWidget {
  const OutsideDataBand({
    super.key,
    required this.artifacts,
    required this.now,
  });

  final List<ChatArtifact> artifacts;

  /// For the staleness clause. Passed in rather than read from the clock, so
  /// a test can age a read date without waiting a week.
  final DateTime now;

  /// Past this, the band says how old the reading is. Staleness is a fact,
  /// never a severity — it takes no warning colour.
  static const int staleAfterDays = 7;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    final p = skin.palette;
    final veld = skin.mode == SkinMode.veld;
    if (artifacts.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    String? publisher;
    DateTime? readAt;

    for (final artifact in artifacts) {
      final tiles = StatTileData.listFrom(artifact.data);
      for (final tile in tiles) {
        publisher ??= tile.provenance.publisher;
        readAt ??= tile.provenance.readAt;
        rows.add(
          _OutsideRow(
            key: ValueKey<String>('outside-${artifact.id}-${tile.label}'),
            tile: tile,
            last: false,
          ),
        );
      }
      final bars = RankedBarsData.from(artifact.data);
      publisher ??= bars.provenance.publisher;
      readAt ??= bars.provenance.readAt;
      for (final item in bars.items) {
        rows.add(
          _OutsideRow(
            key: ValueKey<String>('outside-${artifact.id}-${item.label}'),
            tile: StatTileData(
              label: item.label,
              value: item.value,
              unit: bars.unit,
              decimals: bars.decimals,
              provenance: bars.provenance,
            ),
            last: false,
          ),
        );
      }
    }
    // A figure tagged outside with no citation is dropped, not rendered.
    if (rows.isEmpty) return const SizedBox.shrink();

    final date = readAt == null ? null : _shortDate(readAt);
    final stale = readAt != null &&
        now.difference(readAt).inDays > staleAfterDays;

    final label = <String>[
      l10n.askOutsideData,
      if (date != null) l10n.askOutsideRead(date),
      if (stale) l10n.askOutsideStale(now.difference(readAt).inDays),
    ].join(' · ');

    final sentence = publisher != null && date != null
        ? l10n.askOutsidePublisher(publisher, date)
        : l10n.askOutsideUnnamed(date ?? '—');

    return Semantics(
      container: true,
      label: sentence,
      child: Row(
        key: const ValueKey<String>('outside-data-band'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: veld ? 2 : 2,
            child: ColoredBox(color: veld ? p.ink1 : p.comparison),
          ),
          const SizedBox(width: TiqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Eyebrow(label),
                const SizedBox(height: TiqSpace.s2),
                Text(
                  // The second clause is a permanent part of the string, not
                  // a tooltip: a reader who never taps must still be told
                  // this number is not ours and is in no total above.
                  sentence,
                  style: skin.text.body.style(color: p.ink2),
                ),
                SizedBox(height: skin.space.intraBlock),
                ...rows,
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
}

class _OutsideRow extends StatelessWidget {
  const _OutsideRow({super.key, required this.tile, required this.last});

  final StatTileData tile;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final l10n = context.l10n;
    return SoftRow(
      density: SoftRowDensity.compact,
      title: tile.label,
      trailing: _DashedUnderline(
        child: FigureSlot(
          value: tile.value,
          role: skin.text.figureS,
          unit: askUnitFor(l10n, tile.unit, (tile.value ?? 0).abs()),
          decimals: tile.decimals,
          color: skin.palette.ink1,
        ),
      ),
      semanticsLabel: '${tile.label}, '
          '${tile.formatted(number: TiqNumber.of(context))}, '
          '${l10n.askOutsideFigure}',
      separator: last ? SoftRowSeparator.none : SoftRowSeparator.auto,
    );
  }
}

/// A 1dp dashed `comparison` rule under the value's own width — the third
/// channel, and never the only one.
class _DashedUnderline extends StatelessWidget {
  const _DashedUnderline({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final veld = skin.mode == SkinMode.veld;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        child,
        const SizedBox(height: 2),
        CustomPaint(
          size: Size(48, veld ? 2 : 1),
          painter: _DashPainter(
            colour: veld ? skin.palette.ink1 : skin.palette.comparison,
            thickness: veld ? 2 : 1,
          ),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.colour, required this.thickness});

  final Color colour;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + 3).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += 5;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.colour != colour;
}
