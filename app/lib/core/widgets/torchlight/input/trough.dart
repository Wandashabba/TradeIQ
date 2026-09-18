import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';

/// Which state a trough is in. Ordered by precedence: the last one that
/// applies wins, so a disabled field with an error reads as disabled.
enum TroughState {
  /// Nothing typed. A trough is *visibly empty* — no ghost text pretending to
  /// be a value.
  empty,

  /// Something typed, not focused.
  filled,

  /// The caret is in it.
  focused,

  /// The value was refused, and it is **kept** — a field that clears itself on
  /// an error has thrown away the thing the user has to fix.
  error,

  /// A zero that raises a task (a stock count of none). The whole control
  /// takes it, not just the digit.
  finding,

  /// Not editable, with the reason beside the label.
  disabled,

  /// Reviewing a submitted visit. No rule, no outline, no fill — it stops
  /// looking like a field, because it is not one any more.
  readOnly,
}

/// THE TROUGH — the one input shape.
///
/// Radius 10 at the **bottom** corners and 0 at the top. That is not a
/// stylistic preference: a trough holds at the bottom, and the shape says so
/// before a single word is read. Every typed value in this product sits in
/// one, so it is resolved once here rather than decorated forty-one times.
///
/// ## What identifies it, and why it is not the fill
///
/// Night's `well` on Night's `ground` is **1.12:1** — one quantisation level on
/// a 6-bit budget LCD at 40% backlight, which is to say nothing at all. A field
/// identified only by that fill and a single bottom rule is a floating line on
/// black. So the trough carries a real edge on all four sides at
/// `edgeControl` (the control edge, 5.37:1 on the Night well) with a bottom
/// rule that **thickens** on focus rather than only changing hue.
///
/// ## The focus rule is not amber in this component
///
/// Unify §1.1 keeps a 2px flame-700 rule under a focused field and counts it
/// against the route's budget. This Phase 2 component does not paint it: no
/// component in `sheet/`, `state/` or `input/` emits light, the amber lint's
/// allowlist is pinned at ten emitter files, and a field that lit itself would
/// be lit on every route including the ones already holding two lights.
///
/// What ships instead clears the same accessibility bar by the channel the
/// ruling actually names — *"the focus indicator is 2px minimum and never
/// colour-only — the rule thickens 1px→2px"* — with ink-1 as the hue. When the
/// amber form lands it is one token, in one place: a `focusClaimId` on the
/// field, an allowlist entry, and a `TorchClaim.textFieldFocus` declared by
/// the route. Nothing else moves.
@immutable
class TroughSpec {
  const TroughSpec({
    required this.state,
    required this.minHeight,
    required this.radius,
    required this.fill,
    required this.outline,
    required this.outlineWidth,
    required this.bottomRule,
    required this.bottomRuleWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.labelGap,
    required this.helpGap,
    required this.ink,
    required this.hintInk,
    required this.labelStyle,
    required this.labelInk,
    required this.helpStyle,
    required this.helpInk,
    required this.errorInk,
    required this.affixStyle,
    required this.affixInk,
    required this.counterStyle,
    required this.minNumericWidth,
  });

  /// The flattened wash a finding takes in Night. A **declared hex**, because
  /// opacity is banned as a state channel: `bad` at 12% over `well` is a
  /// different grey on every surface it lands on, and this one is a value
  /// somebody can measure. `#302933` — the kit's `wash-bad-night`.
  static const Color findingWashNight = Color(0xFF302933);

  /// The Day equivalent, composited once and declared: `bad` at 8% over the
  /// Day well.
  static const Color findingWashDay = Color(0xFFE8D6D2);

  /// The counter appears at 80% of the cap and never a character sooner — a
  /// counter that is always on is a scold.
  static const double counterThreshold = 0.8;

  factory TroughSpec.resolve({
    required TiqSkin skin,
    TroughState state = TroughState.empty,
    bool numeric = false,
  }) {
    final p = skin.palette;
    final veld = skin.density == TiqDensity.veld;
    final border = skin.depth.borderWidth;

    final minHeight = switch (skin.density) {
      TiqDensity.console => 44.0,
      TiqDensity.field => TiqSpace.s9,
      TiqDensity.veld => 64.0,
    };

    // READ-ONLY stops looking like a field entirely: no fill, no edge, no
    // rule, ink-1 text. The previous draft dimmed it to 0.8, which is a state
    // the contrast walk cannot see.
    if (state == TroughState.readOnly) {
      return TroughSpec._common(
        skin: skin,
        state: state,
        minHeight: minHeight,
        fill: null,
        outline: null,
        outlineWidth: 0,
        bottomRule: null,
        bottomRuleWidth: 0,
        ink: p.ink1,
        numeric: numeric,
      );
    }

    final disabled = state == TroughState.disabled;
    final error = state == TroughState.error;
    final finding = state == TroughState.finding;
    final focused = state == TroughState.focused;

    final Color fill;
    if (disabled) {
      // A disabled trough drops to the ground: it is not a container any more,
      // because there is nothing to put in it.
      fill = p.ground;
    } else if (finding) {
      fill = veld
          ? p.ground
          : (skin.brightness == Brightness.dark
                ? findingWashNight
                : findingWashDay);
    } else {
      fill = p.well;
    }

    final Color outline = disabled
        ? p.inkMute
        : (error || finding ? p.bad : p.edgeControl);

    final Color bottomRule = disabled
        ? p.inkMute
        : error || finding
        ? p.bad
        : focused
        ? p.ink1
        : p.edgeControl;

    // THICKNESS IS THE FIRST CHANNEL. Rest 1px (2 in Veld), focus and error
    // 2px (4 in Veld). A reader who cannot separate ink-1 from edge-control
    // still sees the rule double.
    final bottomRuleWidth = (focused || error || finding) ? border * 2 : border;

    return TroughSpec._common(
      skin: skin,
      state: state,
      minHeight: minHeight,
      fill: fill,
      outline: outline,
      // A finding outlines the WHOLE control, not just its floor: the point is
      // that it reads from arm's length in a dark aisle.
      outlineWidth: (finding || error) ? border * 2 : border,
      bottomRule: bottomRule,
      bottomRuleWidth: bottomRuleWidth,
      ink: disabled
          ? p.inkMute
          : finding
          ? p.bad
          : p.ink1,
      numeric: numeric,
    );
  }

  factory TroughSpec._common({
    required TiqSkin skin,
    required TroughState state,
    required double minHeight,
    required Color? fill,
    required Color? outline,
    required double outlineWidth,
    required Color? bottomRule,
    required double bottomRuleWidth,
    required Color ink,
    required bool numeric,
  }) {
    final p = skin.palette;
    final veld = skin.density == TiqDensity.veld;
    return TroughSpec(
      state: state,
      minHeight: minHeight,
      // The one shape rule of this whole folder.
      radius: skin.radii.input,
      fill: fill,
      outline: outline,
      outlineWidth: outlineWidth,
      bottomRule: bottomRule,
      bottomRuleWidth: bottomRuleWidth,
      horizontalPadding: veld ? TiqSpace.s4 : 14,
      verticalPadding: TiqSpace.s4,
      labelGap: TiqSpace.s2,
      helpGap: 6,
      ink: ink,
      // A hint restates the unit or the format. It never repeats the label,
      // and it is never a value.
      hintInk: p.ink3,
      labelStyle: skin.text.label,
      labelInk: state == TroughState.disabled ? p.inkMute : p.ink2,
      helpStyle: skin.text.meta,
      helpInk: p.ink3,
      errorInk: p.bad,
      affixStyle: skin.text.label,
      affixInk: p.ink3,
      counterStyle: skin.text.axisLabel,
      // Below this a numeric trough in a two-field row stops being able to
      // hold a formatted rand value at all, and the row breaks to a column.
      minNumericWidth: 120,
    );
  }

  final TroughState state;
  final double minHeight;
  final BorderRadius radius;
  final Color? fill;
  final Color? outline;
  final double outlineWidth;
  final Color? bottomRule;
  final double bottomRuleWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final double labelGap;
  final double helpGap;
  final Color ink;
  final Color hintInk;
  final TiqTypeToken labelStyle;
  final Color labelInk;
  final TiqTypeToken helpStyle;
  final Color helpInk;
  final Color errorInk;
  final TiqTypeToken affixStyle;
  final Color affixInk;
  final TiqTypeToken counterStyle;
  final double minNumericWidth;

  /// The box the trough paints. The bottom rule is drawn as a thicker bottom
  /// border rather than as a separate child, so it follows the radius.
  BoxDecoration decoration() {
    final o = outline;
    final r = bottomRule;
    if (o == null && r == null) {
      return BoxDecoration(color: fill, borderRadius: radius);
    }
    return BoxDecoration(
      color: fill,
      borderRadius: radius,
      border: Border(
        top: o == null
            ? BorderSide.none
            : BorderSide(color: o, width: outlineWidth),
        left: o == null
            ? BorderSide.none
            : BorderSide(color: o, width: outlineWidth),
        right: o == null
            ? BorderSide.none
            : BorderSide(color: o, width: outlineWidth),
        bottom: r == null
            ? BorderSide.none
            : BorderSide(color: r, width: bottomRuleWidth),
      ),
    );
  }

  String describe() {
    String hex(Color? c) => c == null
        ? '—'
        : '#${(c.toARGB32() & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';
    return <String>[
      'state=${state.name}',
      'minHeight=${minHeight.toStringAsFixed(1)}',
      'radius=${radius.bottomLeft.x.toStringAsFixed(0)}'
          '/${radius.topLeft.x.toStringAsFixed(0)}',
      'fill=${hex(fill)}',
      'outline=${hex(outline)}@${outlineWidth.toStringAsFixed(1)}',
      'rule=${hex(bottomRule)}@${bottomRuleWidth.toStringAsFixed(1)}',
      'pad=${horizontalPadding.toStringAsFixed(1)}/${verticalPadding.toStringAsFixed(1)}',
      'ink=${hex(ink)}',
      'label=${labelStyle.name}/${hex(labelInk)}',
      'help=${helpStyle.name}/${hex(helpInk)}',
    ].join('  ');
  }
}
