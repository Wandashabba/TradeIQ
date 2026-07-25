import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/human_error.dart';
import '../theme/app_colors.dart';
import '../theme/tiq_colors.dart';
import 'agent_motion.dart' show Motion, reduceMotion;
import 'console.dart';

/// The shared list/worklist pattern for the manager console.
///
/// Every manager screen is some variant of *triage a list*: see how bad it is,
/// narrow it, act on a row. These are the pieces that make all of them behave
/// the same way — so learning Alerts teaches you Tasks, Orders and Users.

/// Wraps an [AsyncValue] in the console's loading / error / empty states.
///
/// The error copy is deliberately `Failed to load <label>. <human reason>` —
/// the `Failed to load <label>` prefix is asserted across the screen tests, and
/// the reason comes from [humanErrorMessage], never from the exception itself:
/// every console screen inherits this widget, so one raw `$err` here would put
/// a DioException dump on ~20 screens at once. Always offer the retry: a
/// dead-end error state is a bug.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.label,
    required this.onRetry,
    required this.builder,
    this.skipLoadingOnReload = false,
  });

  final AsyncValue<T> value;

  /// Lowercase plural noun, e.g. `alerts` — reads as "Failed to load alerts".
  final String label;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  /// When true, a provider rebuild triggered by one of its OWN dependencies
  /// changing (e.g. a filter) keeps rendering the last [data] instead of
  /// flashing this whole section back to the loading spinner. Off by
  /// default — every other caller still wants the spinner on every reload,
  /// so this is opt-in per call site.
  ///
  /// `AgentActivityPanel` turns this on: without it, `dashboardFilterProvider`
  /// changing tears the map down to a spinner and rebuilds it fresh once the
  /// new page arrives, which would make the map's camera-easing (#153) a
  /// snap in practice even though the animation code is correct — there
  /// would be nothing continuously mounted left to animate.
  final bool skipLoadingOnReload;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return value.when(
      skipLoadingOnReload: skipLoadingOnReload,
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
              'Failed to load $label. ${humanErrorMessage(err)}',
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
  const EmptyState({
    super.key,
    required this.message,
    this.hint,
    this.illustration,
  });

  final String message;
  final String? hint;

  /// Optional bundled illustration (a `BrandMedia` slot path) rendered above
  /// the message. Null — the norm until a human curates art — renders
  /// exactly the text-only state, no reserved space. Decorative only: the
  /// image carries an empty semantic label so screen readers stay on
  /// [message], and it is capped at 160 so it can never dominate the panel.
  final String? illustration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustration != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: Image.asset(illustration!, semanticLabel: ''),
            ),
            const SizedBox(height: 14),
          ],
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
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(14, 11, 14, 11), child: child);
}

/// One row of a worklist, rendered as a card.
///
/// Severity rides on three channels at once — a coloured bar down the left
/// edge, the [StatusChip]'s mark, and its word — so the row still reads in
/// greyscale, in print, and under colour-vision deficiency.
///
/// A tappable row answers the pointer with a wash — [TiqColors.surface2] on
/// hover, [TiqColors.surface3] while pressed, 150ms — behind the content.
/// The wash is feedback, not meaning: the severity channels above are never
/// touched by it.
///
/// **Card geometry (premium restyle).** The row wears the panel language —
/// surface1 ground, `line` hairline, [AppColors.radiusPanel] corners — but
/// deliberately NOT the Stripe shadow: every consumer today renders these
/// rows inside a [PanelCard], which already carries the console's one static
/// shadow, and shadow-in-shadow reads as smudge, not depth. The card is the
/// flat-in-panel variant: margin + hairline + radius only. Spacing between
/// rows (8px) is achieved here with a symmetric 4px vertical margin — plus
/// an 8px horizontal inset so the row's hairline never sits flush on its
/// panel's own border — so no consumer has to change its zero-spacing
/// Column. Everything inside the card (edge bar, wash) sits under a rounded
/// clip so nothing square pokes out of the corners.
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
    this.thumb,
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

  /// Optional leading evidence slot — 44×44, rounded-8 clip, deliberately
  /// centre-aligned with the text block (the row centres its content; a
  /// top-aligned thumb would read as a fourth severity channel). Built for
  /// the captured-shelf-photo thumbnails (spec: "the thumbnail *is* the
  /// evidence"); when null the row renders exactly as before, no reserved
  /// space, no placeholder. Never put generated art here.
  final Widget? thumb;

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
      decoration: BoxDecoration(color: interactive ? wash : null),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Channel 1: the edge bar.
            Container(
              width: 3,
              color: resolved
                  ? colors.lineStrong
                  : widget.level.colorOf(colors),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.thumb != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 10),
                        child: ClipRRect(
                          key: const ValueKey('worklist-thumb'),
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: widget.thumb,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: resolved
                                  ? FontWeight.w400
                                  : FontWeight.w500,
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
                          style: TextStyle(fontSize: 11.5, color: colors.ink3),
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

    final body = !interactive
        ? row
        : InkWell(
            onTap: widget.onTap,
            // Explicit state feedback: a row is a target, and it should say
            // so. The wash lives in the row's own decoration (above), so it
            // cannot be buried under an opaque panel surface.
            onHover: (hovered) => setState(() => _hovered = hovered),
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: row,
          );

    return Opacity(
      opacity: resolved ? 0.6 : 1,
      child: Container(
        // 4+4 between neighbours = the 8px card gap, delivered here so the
        // ~20 consumers' zero-spacing Columns need no changes; 8px sideways
        // keeps this hairline off the enclosing panel's border.
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(AppColors.radiusPanel),
          // No boxShadow — see the class doc: rows live inside a PanelCard
          // that already owns the Stripe shadow.
        ),
        child: ClipRRect(
          // The `- 1` IS the hairline: Border.all above paints at its default
          // 1px width, so the clip radius steps in by exactly that width and
          // the clipped edge bar and wash never overlap the border itself.
          // If the border width ever changes, change this with it.
          borderRadius: BorderRadius.circular(AppColors.radiusPanel - 1),
          child: body,
        ),
      ),
    );
  }
}

/// Staggered one-shot entrance for a worklist — wrap each row at the call
/// site: `WorklistCascade(index: i, child: WorklistRow(...))`.
///
/// A wrapper, not an `entranceIndex:` param on [WorklistRow], for the same
/// reason [OneShotEntrance] documents: motion is opted into at the CALL
/// SITE, the shared row widget itself stays motion-free — and the cascade
/// then works for any row shape, not just [WorklistRow].
///
/// Behaviour:
/// * Row `index` fades in after `Motion.stagger * index`.
/// * Capped at [cap] rows: row 13+ renders instantly — no delay and no
///   fade. Below-the-fold rows arriving in a wave nobody sees would only
///   delay the screen feeling ready.
/// * One-shot: the latch lives in [OneShotEntrance]'s State, so list
///   rebuilds do not replay the entrance.
/// * Under reduced motion [OneShotEntrance] returns the child bare — rows
///   are static from the first frame.
///
/// The [OneShotEntrance] is mounted for EVERY row, capped ones included —
/// the cap is applied through its `enabled` latch, never by swapping the
/// subtree between bare child and entrance. A structural swap would change
/// the element type when a row's index crosses the cap boundary on a later
/// rebuild (rows removed above it, say), remounting the State and latching
/// a fresh — and unwanted — late entrance. With the latch, a row that
/// mounted beyond the cap has spent its entrance moment for good.
class WorklistCascade extends StatelessWidget {
  const WorklistCascade({
    super.key,
    required this.index,
    required this.child,
    this.enabled = true,
  });

  /// Rows at this index and beyond skip the entrance entirely.
  static const int cap = 12;

  /// Position in the list, 0-based — sets this row's share of the stagger.
  final int index;

  final Widget child;

  /// Latched by [OneShotEntrance] at mount — flipping it after the first
  /// build of a mounted row has no effect, by design.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OneShotEntrance(
      enabled: enabled && index < cap,
      delay: Motion.stagger * index,
      child: child,
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
          foregroundColor: tone == StatusLevel.neutral
              ? colors.ink1
              : tone.colorOf(colors),
          textStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
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
