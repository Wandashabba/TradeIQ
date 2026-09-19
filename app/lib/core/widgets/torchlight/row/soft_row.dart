import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import 'soft_row_spec.dart';

export 'soft_row_spec.dart';

/// THE SOFT ROW — the single most-used object in the product.
///
/// Every list on all sixty screens is a stack of these, and the four things
/// this file exists to settle are the four things every one of those lists was
/// getting differently:
///
/// **1. What identifies a row.** Not a fill. `#141D27` on `#0B1017` is 1.12:1
/// — one quantisation level on a 6-bit panel at 40% backlight, which is the
/// panel a field agent actually has — so a list of rows identified by their
/// fill is a page of floating text with no tap affordance. Unify §1.3 rules:
/// a **list row** is flush, radius 0, and separated by a 1px rule inset to the
/// text edge; a **standalone row** is radius 14 on a `surface` fill with a 1px
/// `edgeStructure` outline. The rule's colour is not a parameter — it is
/// `edgeStructure` (3.73:1) between tappable rows because 1.4.11 wants a
/// perceivable boundary around a UI component, and `hairline` between
/// non-tappable ones because there it is decoration.
///
/// **2. Where content starts.** At a fixed inset, whether or not a severity
/// bar is drawn. The bar's lane is reserved either way, so a list where three
/// rows out of eleven are critical still reads as one column.
///
/// **3. What a press looks like.** Fill steps to `lifted` **and** the row's
/// rule or outline steps to 2px `edgeControl`, plus scale 0.98 and
/// `HapticFeedback.selectionClick`. The fill step alone is 1.49:1 — the
/// channel that carries the press on a cheap screen is the edge, and the fill
/// is support. Under reduce-motion the scale drops and the other three stay.
///
/// **4. What it costs.** No `BackdropFilter`, no `saveLayer`, no shadow, no
/// gradient, no `Material` ripple travelling 300dp. A row is a `DecoratedBox`,
/// a `Padding`, a layout and some text. Rows appear in `ListView.builder` and
/// that is the budget that matters.
///
/// **A row never emits light.** It declares no `TorchClaim` and paints no
/// flame token in any state, including stuck, critical and sending. This is
/// the rule that kills the amber-dot-on-every-row failure, and
/// `row_amber_test.dart` counts the pixels rather than trusting the sentence.
///
/// **5. What a row's own verbs cost.** The row is one semantics node: the
/// label is composed here and everything inside it is excluded, because a
/// worklist that announces four nodes per row is a worklist nobody can hear.
/// That exclusion is also how a screen-reader user loses a button — a
/// `TorchTertiaryButton` dropped into [meta] paints fine and is announced
/// nowhere. So a row's verbs have two declared homes, and neither of them is
/// [meta]: [actions], the ghost buttons that sit beneath the text column (the
/// manager spec's "at 2.0× they stack beneath the reason"), and a
/// [trailing] marked [trailingIsControl] for a single trailing toggle. Both
/// keep their own nodes beneath the row's, which is what `Semantics.onTap`
/// on the row does for the row's own tap — a `GestureDetector` under an
/// `excludeSemantics` node carries no tap action, so before this the row's
/// `onTap` was invisible to TalkBack too.
///
/// ```dart
/// SoftRow(
///   density: SoftRowDensity.standard,
///   title: outlet.name,
///   titleTruncation: SoftRowTruncation.middle,
///   subtitle: l10n.metresAway(outlet.distance),
///   severity: SoftRowSeverity.critical,
///   severityLabel: l10n.severityCritical,
///   trailing: const SoftRowChevron(),
///   onTap: () => context.push(outlet.route),
/// )
/// ```
class SoftRow extends StatefulWidget {
  const SoftRow({
    super.key,
    required this.title,
    this.form = SoftRowForm.list,
    this.density = SoftRowDensity.standard,
    this.titleTruncation = SoftRowTruncation.end,
    this.subtitle,
    this.meta,
    this.leading,
    this.trailing,
    this.trailingIsControl = false,
    this.actions,
    this.severity = SoftRowSeverity.none,
    this.severityLabel,
    this.onTap,
    this.onLongPress,
    this.separator = SoftRowSeparator.auto,
    this.enabled = true,
    this.semanticsLabel,
  }) : assert(
         severity == SoftRowSeverity.none || severityLabel != null,
         'SoftRow: a severity-bearing row needs a severityLabel. The hue is '
         'the same crimson at both levels; the word is the channel that '
         'survives greyscale, deuteranopia, glare and a screen reader, and it '
         'is announced first.',
       ),
       assert(
         !trailingIsControl || trailing != null,
         'SoftRow: trailingIsControl describes the trailing widget, and there '
         'is none.',
       );

  /// The primary line, `title.m` in ink-1. Wraps to two lines at every text
  /// scale, then gives up according to [titleTruncation].
  final String title;

  final SoftRowForm form;
  final SoftRowDensity density;
  final SoftRowTruncation titleTruncation;

  /// The reason line, `body` in ink-2. Up to two lines.
  final String? subtitle;

  /// The second meta line, in `meta`/ink-3 by default — a `Text` passed here
  /// inherits that role, and a `FigureSlot` passed here keeps its own, which
  /// is how "1,4 MB · queued 14:03" gets mono digits and prose words in one
  /// line.
  final Widget? meta;

  /// A glyph, a state tile or an initials tile, in a box that grows with the
  /// text and stops at 48. Never a photograph — see [PersonRow].
  final Widget? leading;

  /// A figure, a state word or a [SoftRowChevron]. At 2.0× it drops beneath
  /// the text column rather than squeezing the title, and that decision is
  /// made by measuring the laid-out trailing, not by looking at the text
  /// scale.
  final Widget? trailing;

  /// True when [trailing] is a control a person operates — the alert rules
  /// toggle is the one in the product — rather than a figure, a state word or
  /// a chevron. A control keeps its own semantics node beneath the row's, so
  /// "Turn Out of stock alert off" is reachable; everything else in the row
  /// stays excluded, so the row is still one utterance plus its verbs.
  final bool trailingIsControl;

  /// The row's own verbs, beneath the text column and inset to it: "Close
  /// with photo", "Verify", "Acknowledge". They keep their semantics nodes
  /// (see [trailingIsControl]), they stack themselves at 2.0× if they are a
  /// `Wrap`, and they are never the row's only route to the verb where a
  /// sheet can carry it too.
  final Widget? actions;

  final SoftRowSeverity severity;

  /// The severity in words. Required whenever [severity] is not
  /// [SoftRowSeverity.none], and announced before the title.
  final String? severityLabel;

  final VoidCallback? onTap;

  /// Only where the row has a genuine second verb, and then it opens a sheet.
  final VoidCallback? onLongPress;

  /// [SoftRowSeparator.none] for the last row in a group. Standalone rows
  /// never draw one — they carry an outline instead.
  final SoftRowSeparator separator;

  /// A disabled row keeps its fill, drops to ink-mute, loses its chevron and
  /// takes no press feedback. It must also carry a [meta] line saying why: a
  /// dead row with no explanation is a phone call to a manager.
  final bool enabled;

  /// Overrides the composed label. The default is
  /// `'<severity>. <title>. <subtitle>'`, severity first — [meta] is a widget
  /// and is not read back, so a row whose meta line carries meaning (a size, a
  /// next-attempt time, an identifier) passes the whole sentence here. The
  /// configurations in this directory all do.
  final String? semanticsLabel;

  bool get _tappable => enabled && onTap != null;

  @override
  State<SoftRow> createState() => _SoftRowState();
}

class _SoftRowState extends State<SoftRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap!();
  }

  void _handleLongPress() {
    HapticFeedback.selectionClick();
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final still = MotionBudget.of(context).still;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final textScale = scaler.scale(1.0).clamp(1.0, 2.0);
    final tappable = widget._tappable;

    final spec = SoftRowSpec.resolve(
      skin: skin,
      form: widget.form,
      density: widget.density,
      severity: widget.severity,
      tappable: tappable,
      pressed: _pressed,
      separated:
          widget.form == SoftRowForm.list &&
          widget.separator == SoftRowSeparator.auto,
      textScale: textScale,
      still: still,
    );
    assert(
      spec.meetsTargetFloor(skin),
      'SoftRow: ${spec.minHeight} is under this skin\'s '
      '${skin.space.tapTarget} target floor.',
    );

    // True when something inside the row has to keep a node of its own: a
    // verb the row's label cannot carry, because a label is not a button.
    final exposes =
        widget.actions != null ||
        (widget.trailingIsControl && widget.trailing != null);

    final body = _body(context, skin, spec, exposes: exposes);

    final gesture = tappable || widget.onLongPress != null
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tappable ? _handleTap : null,
            onTapDown: tappable ? (_) => _setPressed(true) : null,
            onTapUp: tappable ? (_) => _setPressed(false) : null,
            onTapCancel: tappable ? () => _setPressed(false) : null,
            onLongPress: widget.onLongPress == null ? null : _handleLongPress,
            child: body,
          )
        : body;

    return Semantics(
      container: true,
      button: tappable,
      enabled: widget.enabled,
      label: widget.semanticsLabel ?? _label(),
      // The row's own tap, as an action and not only as a flag. A
      // `GestureDetector` beneath an excluding node contributes nothing, so a
      // `button: true` row with no `onTap` here is a row TalkBack can focus
      // and cannot activate.
      onTap: tappable ? _handleTap : null,
      onLongPress: widget.onLongPress == null ? null : _handleLongPress,
      // One node, unless the row carries verbs — then the row's node keeps the
      // sentence and each verb gets its own node beneath it.
      excludeSemantics: !exposes,
      explicitChildNodes: exposes,
      child: gesture,
    );
  }

  /// Severity first, then the title, then the reason, then the meta. A
  /// worklist read aloud has to say "Critical" before it says the store's
  /// name, or the listener sorts the list twice.
  String _label() => <String?>[
    widget.severityLabel,
    widget.title,
    widget.subtitle,
  ].whereType<String>().where((s) => s.isNotEmpty).join('. ');

  Widget _body(
    BuildContext context,
    TiqSkin skin,
    SoftRowSpec spec, {
    required bool exposes,
  }) {
    final hasLeading = widget.leading != null;
    final disabledInk = skin.palette.inkMute;

    final Widget text = _TextColumn(
      title: widget.title,
      truncation: widget.titleTruncation,
      subtitle: widget.subtitle,
      meta: widget.meta,
      spec: spec,
      titleInk: widget.enabled ? spec.titleInk : disabledInk,
      subtitleInk: widget.enabled ? spec.subtitleInk : disabledInk,
      metaInk: widget.enabled ? spec.metaInk : disabledInk,
    );

    // A disabled row loses its chevron — an affordance on a control that does
    // not respond is a lie — but keeps a trailing figure, which is still true.
    final trailing = widget.enabled
        ? widget.trailing
        : (widget.trailing is SoftRowChevron ? null : widget.trailing);

    // Where the row keeps verbs, everything that is *not* a verb is excluded
    // one level down instead of at the top, so the row still reads as one
    // sentence and the verbs are still buttons.
    final textChild = exposes ? ExcludeSemantics(child: text) : text;
    final trailingChild =
        exposes && trailing != null && !widget.trailingIsControl
        ? ExcludeSemantics(child: trailing)
        : trailing;

    final content = _SoftRowContent(
      gap: spec.gap,
      stackedGap: spec.stackedGap,
      minTextWidth: spec.minTextWidth,
      firstLineExtent:
          (MediaQuery.maybeTextScalerOf(context)?.scale(spec.titleStyle.size) ??
              spec.titleStyle.size) *
          spec.titleStyle.height,
      textDirection: Directionality.of(context),
      children: <Widget>[textChild, ?trailingChild],
    );

    final line = Row(
      children: <Widget>[
        // The lane is reserved whether or not a bar is painted. This
        // `SizedBox` is the alignment rule: content starts at the same inset
        // on every row, so eleven rows of which three are critical still
        // read as one column.
        SizedBox(
          width: spec.severityLane,
          height: spec.severity == SoftRowSeverity.none ? 0 : spec.barHeight,
          child: spec.severity == SoftRowSeverity.none
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _SeverityBar(spec: spec),
                ),
        ),
        if (hasLeading) ...<Widget>[
          SizedBox.square(
            dimension: spec.leadingExtent,
            child: exposes
                ? ExcludeSemantics(child: widget.leading)
                : widget.leading,
          ),
          SizedBox(width: spec.gap),
        ],
        Expanded(child: content),
      ],
    );

    final actions = widget.actions;
    final inner = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spec.horizontalPadding,
        vertical: spec.verticalPadding,
      ),
      child: actions == null
          ? line
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                line,
                SizedBox(height: spec.stackedGap),
                // Inset to the text column, so the verbs sit under the reason
                // they belong to rather than under the severity lane.
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start:
                        spec.textInset(hasLeading: hasLeading) -
                        spec.horizontalPadding,
                  ),
                  child: actions,
                ),
              ],
            ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: spec.fill,
        borderRadius: spec.radius == 0
            ? null
            : BorderRadius.circular(spec.radius),
        border: spec.outline == null || spec.outlineWidth == 0
            ? null
            : Border.all(color: spec.outline!, width: spec.outlineWidth),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: spec.minHeight),
        child: inner,
      ),
    );

    final scale = _pressed ? spec.pressScale : 1.0;
    final scaled = scale == 1.0
        ? decorated
        : Transform.scale(scale: scale, child: decorated);

    if (spec.separatorColour == null || spec.separatorWidth == 0) {
      return scaled;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        scaled,
        // Inset to the text edge, which is what makes a stack of these read as
        // a column of text with a fine rule under each entry rather than as a
        // table with a full-bleed border.
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: spec.textInset(hasLeading: hasLeading),
          ),
          child: SizedBox(
            height: spec.separatorWidth,
            child: ColoredBox(color: spec.separatorColour!),
          ),
        ),
      ],
    );
  }
}

/// The 3px bar, at two commitment levels and never amber.
class _SeverityBar extends StatelessWidget {
  const _SeverityBar({required this.spec});

  final SoftRowSpec spec;

  @override
  Widget build(BuildContext context) {
    final solid = spec.barFill;
    return SizedBox(
      width: spec.barWidth,
      height: spec.barHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: solid,
          // Watch is a stroke around an empty channel, not the critical bar at
          // 40% opacity: opacity is banned as a state channel, and an alpha
          // step is a state the CI contrast walk cannot see.
          border: spec.barStroke == null
              ? null
              : Border.all(color: spec.barStroke!, width: spec.barStrokeWidth),
        ),
      ),
    );
  }
}

/// The trailing chevron: a 2px-stroke path in ink-3, drawn rather than set in
/// a font, and scaling with the text because it carries meaning.
class SoftRowChevron extends StatelessWidget {
  const SoftRowChevron({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final extent = math.min(20.0 * scaler.scale(1.0).clamp(1.0, 2.0), 32.0);
    return SizedBox.square(
      dimension: extent,
      child: CustomPaint(
        painter: _ChevronPainter(
          colour: color ?? skin.palette.ink3,
          stroke: skin.depth.borderWidth * 2,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({
    required this.colour,
    required this.stroke,
    required this.rtl,
  });

  final Color colour;
  final double stroke;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.3;
    final mid = size.height / 2;
    final path = Path();
    if (rtl) {
      path
        ..moveTo(size.width - inset, inset)
        ..lineTo(inset, mid)
        ..lineTo(size.width - inset, size.height - inset);
    } else {
      path
        ..moveTo(inset, inset)
        ..lineTo(size.width - inset, mid)
        ..lineTo(inset, size.height - inset);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.colour != colour || old.stroke != stroke || old.rtl != rtl;
}

class _TextColumn extends StatelessWidget {
  const _TextColumn({
    required this.title,
    required this.truncation,
    required this.subtitle,
    required this.meta,
    required this.spec,
    required this.titleInk,
    required this.subtitleInk,
    required this.metaInk,
  });

  final String title;
  final SoftRowTruncation truncation;
  final String? subtitle;
  final Widget? meta;
  final SoftRowSpec spec;
  final Color titleInk;
  final Color subtitleInk;
  final Color metaInk;

  @override
  Widget build(BuildContext context) {
    final titleStyle = spec.titleStyle.style(color: titleInk);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (truncation == SoftRowTruncation.middle)
          MiddleTruncatedText(title, style: titleStyle, maxLines: 2)
        else
          Text(
            title,
            style: titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          SizedBox(height: TiqSpace.s1),
          Text(
            subtitle!,
            style: spec.subtitleStyle.style(color: subtitleInk),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (meta != null) ...<Widget>[
          SizedBox(height: TiqSpace.s1),
          DefaultTextStyle(
            style: spec.metaStyle.style(color: metaInk),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            child: meta!,
          ),
        ],
      ],
    );
  }
}

/// A label that wraps to [maxLines] and then drops its middle rather than its
/// end.
///
/// "Shoprite Klipspruit Mall" and "Shoprite Klipfontein Mall" end-truncate to
/// the same string on a 200dp row, and so do "Nomsa Dlamini-Mkhize" and
/// "Nomsa Dlamini-Ndlovu". The branch and the surname are the discriminating
/// half, and they are at the end.
///
/// The full string is always what a screen reader gets: this widget paints a
/// shortened string and the row's `Semantics` label carries the real one.
class MiddleTruncatedText extends StatelessWidget {
  const MiddleTruncatedText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painted = _fit(text, constraints.maxWidth, scaler, direction);
        return Text(
          painted,
          style: style,
          maxLines: maxLines,
          // No ellipsis: the truncation has already happened, and a second one
          // on top of it would eat the tail this widget exists to keep.
          overflow: TextOverflow.clip,
          softWrap: true,
        );
      },
    );
  }

  bool _fits(
    String candidate,
    double maxWidth,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final overflows = painter.didExceedMaxLines;
    painter.dispose();
    return !overflows;
  }

  String _fit(
    String source,
    double maxWidth,
    TextScaler scaler,
    TextDirection direction,
  ) {
    if (!maxWidth.isFinite || source.isEmpty) return source;
    if (_fits(source, maxWidth, scaler, direction)) return source;
    // Binary search on how much of the middle to remove. At most ~6 layouts
    // for a 40-character name, and only on the rows that actually overflow.
    var low = 1;
    var high = source.length - 1;
    var best = '…';
    while (low <= high) {
      final keep = (low + high) ~/ 2;
      final head = (keep / 2).ceil();
      final tail = keep - head;
      final candidate =
          '${source.substring(0, head)}…${source.substring(source.length - tail)}';
      if (_fits(candidate, maxWidth, scaler, direction)) {
        best = candidate;
        low = keep + 1;
      } else {
        high = keep - 1;
      }
    }
    return best;
  }
}

// ── The text/trailing layout ─────────────────────────────────────────────
//
// The rule from unify §4 is that a row at 2.0× drops its trailing column
// beneath the text rather than squeezing the title, and that layout decisions
// are made on measured width, never on a text-scale guess. Those two together
// rule out both a `Row` (which squeezes) and an `if (textScale >= 1.6)` (which
// guesses, and is wrong the moment a trailing figure is "R 1 284 990" at 1.0×
// or an Afrikaans state word at 1.2×).
//
// So: lay the trailing out unconstrained, see what is left for the text, and
// stack when what is left is not enough. One layout pass, no `saveLayer`, no
// intrinsics walk.

class _SoftRowContent extends MultiChildRenderObjectWidget {
  const _SoftRowContent({
    required this.gap,
    required this.stackedGap,
    required this.minTextWidth,
    required this.firstLineExtent,
    required this.textDirection,
    required super.children,
  });

  final double gap;
  final double stackedGap;
  final double minTextWidth;

  /// The height of one title line at the live scale. A chevron is centred on
  /// the first line of the title, not on a row that may be three lines tall.
  final double firstLineExtent;

  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSoftRowContent(
        gap: gap,
        stackedGap: stackedGap,
        minTextWidth: minTextWidth,
        firstLineExtent: firstLineExtent,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSoftRowContent renderObject,
  ) {
    renderObject
      ..gap = gap
      ..stackedGap = stackedGap
      ..minTextWidth = minTextWidth
      ..firstLineExtent = firstLineExtent
      ..textDirection = textDirection;
  }
}

class _RowParentData extends ContainerBoxParentData<RenderBox> {}

// Each field below is written through a setter that calls `markNeedsLayout`,
// which is why none of them is an initialising formal: an assignment straight
// into the field would skip the invalidation on every rebuild after the first.
// ignore_for_file: prefer_initializing_formals
class _RenderSoftRowContent extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  _RenderSoftRowContent({
    required double gap,
    required double stackedGap,
    required double minTextWidth,
    required double firstLineExtent,
    required TextDirection textDirection,
  }) : _gap = gap,
       _stackedGap = stackedGap,
       _minTextWidth = minTextWidth,
       _firstLineExtent = firstLineExtent,
       _textDirection = textDirection;

  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  double _stackedGap;
  set stackedGap(double value) {
    if (_stackedGap == value) return;
    _stackedGap = value;
    markNeedsLayout();
  }

  double _minTextWidth;
  set minTextWidth(double value) {
    if (_minTextWidth == value) return;
    _minTextWidth = value;
    markNeedsLayout();
  }

  double _firstLineExtent;
  set firstLineExtent(double value) {
    if (_firstLineExtent == value) return;
    _firstLineExtent = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// True when the trailing column was pushed under the text column at the
  /// last layout. Exposed for the widget test that asserts the 2.0× behaviour
  /// without reading pixels.
  bool stacked = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  @override
  void performLayout() {
    size = _run(constraints, dry: false);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _run(constraints, dry: true);

  Size _run(BoxConstraints constraints, {required bool dry}) {
    final text = firstChild!;
    final trailing = childAfter(text);
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : _minTextWidth;

    if (trailing == null) {
      final textSize = _layoutChild(
        text,
        BoxConstraints.tightFor(width: maxWidth),
        dry: dry,
      );
      if (!dry) {
        (text.parentData! as _RowParentData).offset = Offset.zero;
        stacked = false;
      }
      return Size(maxWidth, textSize.height);
    }

    final trailingSize = _layoutChild(
      trailing,
      BoxConstraints(maxWidth: maxWidth),
      dry: dry,
    );
    final inline = maxWidth - trailingSize.width - _gap;
    final willStack = inline < _minTextWidth;

    if (willStack) {
      final textSize = _layoutChild(
        text,
        BoxConstraints.tightFor(width: maxWidth),
        dry: dry,
      );
      if (!dry) {
        stacked = true;
        (text.parentData! as _RowParentData).offset = Offset.zero;
        (trailing.parentData! as _RowParentData).offset = Offset(
          _textDirection == TextDirection.rtl
              ? 0
              : maxWidth - trailingSize.width,
          textSize.height + _stackedGap,
        );
      }
      return Size(
        maxWidth,
        textSize.height + _stackedGap + trailingSize.height,
      );
    }

    final textSize = _layoutChild(
      text,
      BoxConstraints.tightFor(width: inline),
      dry: dry,
    );
    final height = math.max(textSize.height, trailingSize.height);
    if (!dry) {
      stacked = false;
      final textX = _textDirection == TextDirection.rtl
          ? maxWidth - inline
          : 0.0;
      final trailingX = _textDirection == TextDirection.rtl
          ? 0.0
          : maxWidth - trailingSize.width;
      (text.parentData! as _RowParentData).offset = Offset(
        textX,
        (height - textSize.height) / 2,
      );
      // Centred on the first title line rather than on the row, so a chevron
      // beside a three-line Afrikaans name stays level with the name's first
      // line instead of drifting to the bottom of the block.
      final anchor = math.min(_firstLineExtent, textSize.height);
      (trailing.parentData! as _RowParentData).offset = Offset(
        trailingX,
        ((height - textSize.height) / 2 + anchor / 2 - trailingSize.height / 2)
            .clamp(0.0, math.max(0.0, height - trailingSize.height)),
      );
    }
    return Size(maxWidth, height);
  }

  Size _layoutChild(RenderBox child, BoxConstraints c, {required bool dry}) {
    if (dry) return child.getDryLayout(c);
    child.layout(c, parentUsesSize: true);
    return child.size;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _minTextWidth;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      firstChild!.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      firstChild!.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      firstChild!.getMaxIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
