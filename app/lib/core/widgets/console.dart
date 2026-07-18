import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show reduceMotion;

/// Shared building blocks for the manager console.
///
/// Two rules run through all of them:
///
/// * **State is never colour alone.** A [StatusChip] is a mark *and* a word; a
///   [DeltaText] carries an arrow *and* a sign. Both survive greyscale and
///   colour-vision deficiency.
/// * **Figures are proportional, columns are tabular.** Large standalone
///   numbers use proportional digits; only values that must align vertically
///   (table rows, ledger columns) use [FontFeature.tabularFigures].

/// Severity/state of a row. The colour is looked up from the reserved status
/// palette — these are never used as series colours.
enum StatusLevel { critical, warning, good, neutral }

extension StatusLevelColor on StatusLevel {
  /// Dark-constant lookup. Kept for the agent-pinned flow and for tests that
  /// assert the reserved dark hues directly; theme-following widgets use
  /// [colorOf].
  Color get color => switch (this) {
        StatusLevel.critical => AppColors.crit,
        StatusLevel.warning => AppColors.warn,
        StatusLevel.good => AppColors.good,
        StatusLevel.neutral => AppColors.ink3,
      };

  /// Theme-aware lookup — resolves against the ambient [TiqColors].
  Color colorOf(TiqColors c) => switch (this) {
        StatusLevel.critical => c.crit,
        StatusLevel.warning => c.warn,
        StatusLevel.good => c.good,
        StatusLevel.neutral => c.ink3,
      };
}

/// A small uppercase label that heads a section or a column.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.9,
        color: color ?? colors.ink3,
      ),
    );
  }
}

/// A bordered panel with an optional titled header — the console's only
/// container. Replaces the old rounded Card-per-number grid.
///
/// Elevation: a barely-there rest shadow (0 1px 2px) that lifts to 0 4px 12px
/// on hover over 150ms. The colour is [TiqColors.shadow] — transparent in
/// dark, so dark renders exactly as before; only light gains elevation.
class PanelCard extends StatefulWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padded = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  /// Set false when the child draws its own edge-to-edge rows (lists, tables).
  final bool padded;

  @override
  State<PanelCard> createState() => _PanelCardState();
}

class _PanelCardState extends State<PanelCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final trailing = widget.trailing;
    final padded = widget.padded;
    final child = widget.child;
    final head = title == null
        ? null
        : Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.ink1,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: colors.ink3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                ?trailing,
              ],
            ),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration:
            reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(AppColors.radiusPanel),
          // Transparent in dark — both states render invisibly there.
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: _hovered ? 12 : 2,
              offset: _hovered ? const Offset(0, 4) : const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ?head,
            if (padded) Padding(padding: const EdgeInsets.all(14), child: child) else child,
          ],
        ),
      ),
    );
  }
}

/// A signed, arrowed delta. Colour reinforces the sign; it never replaces it.
class DeltaText extends StatelessWidget {
  const DeltaText(this.value, {super.key, this.suffix, this.fontSize = 11.5});

  final double value;
  final String? suffix;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (glyph, color) = switch (value) {
      > 0 => ('▲', colors.good),
      < 0 => ('▼', colors.crit),
      _ => ('–', colors.ink3),
    };
    final magnitude = value.abs().toStringAsFixed(1);
    return Text(
      '$glyph $magnitude${suffix ?? ''}',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// A square mark plus a word. Never the mark alone.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.level});

  final String label;
  final StatusLevel level;

  @override
  Widget build(BuildContext context) {
    final color = level.colorOf(context.colors);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Neutral reads as a hollow square, so state survives greyscale.
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: level == StatusLevel.neutral ? Colors.transparent : color,
            border: level == StatusLevel.neutral
                ? Border.all(color: color)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        // Flexible, not fixed: a long word ("ACKNOWLEDGED") in a narrow column
        // must ellipsize rather than overflow its row.
        Flexible(
          child: Text(
            label.toUpperCase(),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// One cell of the KPI strip: label, figure, delta, optional footnote and a
/// trailing trend cue (a sparkline). The tile carries the value — the
/// sparkline only carries the shape.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.note,
    this.spark,
  });

  final String label;
  final String value;
  final double? delta;
  final String? note;
  final Widget? spark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.ink2),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: colors.ink1,
                  ),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(width: 7),
                DeltaText(delta!),
              ],
            ],
          ),
          if (spark != null) ...[const SizedBox(height: 7), spark!],
          if (note != null) ...[
            const SizedBox(height: 5),
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable "needs attention" row: a count, what it is, and what it means.
class AttentionRow extends StatelessWidget {
  const AttentionRow({
    super.key,
    required this.count,
    required this.title,
    required this.meta,
    required this.level,
    this.onTap,
    this.showDivider = true,
  });

  final int count;
  final String title;
  final String meta;
  final StatusLevel level;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: colors.line))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: level.colorOf(colors),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colors.ink1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 11, color: colors.ink3),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 14, color: colors.ink3),
          ],
        ),
      ),
    );
  }
}
