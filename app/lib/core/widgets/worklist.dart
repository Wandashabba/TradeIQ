import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show reduceMotion;
import 'console.dart';

/// The shared list/worklist pattern for the manager console.
///
/// Every manager screen is some variant of *triage a list*: see how bad it is,
/// narrow it, act on a row. These are the pieces that make all of them behave
/// the same way — so learning Alerts teaches you Tasks, Orders and Users.

/// Wraps an [AsyncValue] in the console's loading / error / empty states.
///
/// The error copy is deliberately `Failed to load <label>: <err>` — that
/// wording is asserted across the screen tests, and it is also just the clearest
/// thing to say. Always offer the retry: a dead-end error state is a bug.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.label,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;

  /// Lowercase plural noun, e.g. `alerts` — reads as "Failed to load alerts".
  final String label;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const StatusChip(label: 'Error', level: StatusLevel.critical),
            const SizedBox(height: 8),
            Text(
              'Failed to load $label: $err',
              style: TextStyle(fontSize: 12.5, color: colors.ink2),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
      data: builder,
    );
  }
}

/// What to say when there is nothing to show. An empty list is a *result*, not
/// a blank panel — say which, and why.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.hint});

  final String message;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.ink2),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: colors.ink3),
            ),
          ],
        ],
      ),
    );
  }
}

/// One cell of the triage strip: a state and how many are in it.
typedef TriageCount = ({String label, int count, StatusLevel level});

/// The counts-by-state strip that heads a worklist — read before the list.
class TriageStrip extends StatelessWidget {
  const TriageStrip({super.key, required this.counts, this.trailing});

  final List<TriageCount> counts;

  /// An optional non-count cell, e.g. "Median time to ack · 4.2 hours".
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cells = <Widget>[
      for (final c in counts)
        _TriageCell(
          key: ValueKey('triage-${c.label.toLowerCase()}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusChip(label: c.label, level: c.level),
              const SizedBox(height: 3),
              Text(
                '${c.count}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: c.count == 0 ? colors.ink3 : c.level.colorOf(colors),
                ),
              ),
            ],
          ),
        ),
      if (trailing != null) _TriageCell(child: trailing!),
    ];

    return PanelCard(
      padded: false,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: i == cells.length - 1
                            ? Colors.transparent
                            : colors.line,
                      ),
                    ),
                  ),
                  child: cells[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TriageCell extends StatelessWidget {
  const _TriageCell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: child,
      );
}

/// One row of a worklist.
///
/// Severity rides on three channels at once — a coloured bar down the left
/// edge, the [StatusChip]'s mark, and its word — so the row still reads in
/// greyscale, in print, and under colour-vision deficiency.
///
/// A tappable row answers the pointer with a wash — [TiqColors.surface2] on
/// hover, [TiqColors.surface3] while pressed, 150ms — behind the content.
/// The wash is feedback, not meaning: the severity channels above are never
/// touched by it.
class WorklistRow extends StatefulWidget {
  const WorklistRow({
    super.key,
    required this.title,
    required this.meta,
    required this.level,
    this.statusLabel,
    this.when,
    this.actions = const [],
    this.resolved = false,
    this.onTap,
  });

  final String title;

  /// The supporting line: where it happened, which rule fired, what it spawned.
  final Widget meta;
  final StatusLevel level;
  final String? statusLabel;

  /// Relative time, e.g. "2h ago".
  final String? when;
  final List<Widget> actions;

  /// Dims the row and hollows its mark — done, but still on the page.
  final bool resolved;
  final VoidCallback? onTap;

  @override
  State<WorklistRow> createState() => _WorklistRowState();
}

class _WorklistRowState extends State<WorklistRow> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final resolved = widget.resolved;
    final interactive = widget.onTap != null;
    // Pressed wins over hover; both are painted by the row itself, behind its
    // content — an ink splash on an ancestor Material would hide under the
    // panel's own surface.
    final wash = _pressed
        ? colors.surface3
        : _hovered
            ? colors.surface2
            : Colors.transparent;
    final row = AnimatedContainer(
      duration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: interactive ? wash : null,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Channel 1: the edge bar.
            Container(
              width: 3,
              color: resolved ? colors.lineStrong : widget.level.colorOf(colors),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  resolved ? FontWeight.w400 : FontWeight.w500,
                              color: colors.ink1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          DefaultTextStyle(
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.ink3,
                            ),
                            child: widget.meta,
                          ),
                        ],
                      ),
                    ),
                    // Channels 2 + 3: the mark and the word.
                    if (widget.statusLabel != null)
                      SizedBox(
                        width: 116,
                        child: StatusChip(
                          label: widget.statusLabel!,
                          level: resolved ? StatusLevel.neutral : widget.level,
                        ),
                      ),
                    if (widget.when != null)
                      SizedBox(
                        width: 92,
                        child: Text(
                          widget.when!,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.ink3,
                          ),
                        ),
                      ),
                    ...widget.actions,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!interactive) {
      return Opacity(opacity: resolved ? 0.6 : 1, child: row);
    }
    return Opacity(
      opacity: resolved ? 0.6 : 1,
      child: InkWell(
        onTap: widget.onTap,
        // Explicit state feedback: a row is a target, and it should say so.
        // The wash lives in the row's own decoration (above), so it cannot be
        // buried under an opaque panel surface.
        onHover: (hovered) => setState(() => _hovered = hovered),
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: row,
      ),
    );
  }
}

/// A monospaced token for a machine-facing value: a rule name, an ID, a URL.
/// Set in mono so it reads as *a thing the system knows*, not as prose.
class CodeToken extends StatelessWidget {
  const CodeToken(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          color: colors.ink3,
        ),
      ),
    );
  }
}

/// A compact secondary action for a worklist row.
class RowAction extends StatelessWidget {
  const RowAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = StatusLevel.neutral,
  });

  final String label;
  final VoidCallback onPressed;
  final StatusLevel tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          foregroundColor:
              tone == StatusLevel.neutral ? colors.ink1 : tone.colorOf(colors),
          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

/// The one filter row that scopes everything beneath it. Never put a filter
/// inside a panel — a per-panel filter is a lie waiting to happen, because two
/// panels can then disagree about what slice you are looking at.
class FilterRow extends StatelessWidget {
  const FilterRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppColors.radiusPanel),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: children,
      ),
    );
  }
}
