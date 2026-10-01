import 'package:flutter/widgets.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';

/// ASK TRADEIQ'S ONE EMITTER.
///
/// Every amber pixel on this route is decided here, in one file, and nowhere
/// else — which is why this is the surface's single entry in
/// `TorchlightScanner.amberAllowlist`. The three objects that can be lit sit
/// on three different rungs of the ladder, they are drawn by three different
/// widgets, and if each of those widgets reached for `flame600` itself there
/// would be three places to get the law wrong instead of one.
///
/// **Nothing here decides that it is lit.** Each function takes the answer
/// [TorchScope] already gave and returns the granted or the denied form. The
/// route declares the claims, per phase, at construction:
///
/// ```dart
/// TorchScope(
///   skin: skin,
///   phase: 'landed-focus',
///   navRenders: TorchShell.navWillRender(context, hasNav: true),
///   tabbedRoute: true,
///   claims: <TorchClaim>[TorchClaim.chartFocus(AskLight.focusClaimId)],
///   child: …,
/// )
/// ```
///
/// ## The three objects, and why they cannot coexist
///
/// | rung | object | when |
/// |---|---|---|
/// | 1 `primaryCommit` | Send's rim (Night) / block (Day) | the manager has typed something |
/// | 3 `chartFocus` | one ranked bar, or the trend's primary series | a landed answer, trough empty |
/// | 6 `livePulse` | the running step's dot | a tool is genuinely executing |
///
/// They are mutually exclusive **by state** before the ladder ever has to
/// choose between them. While a turn streams, Send is replaced by Stop and
/// there is no primary; when the answer lands the pulse has gone out; when the
/// manager starts typing, the answer's focus object hands off. The ladder is
/// still the mechanism — it is simply never asked to arbitrate a tie.
///
/// ## The hand-off is one-way
///
/// unify §1.1 and the assistant ledger both require that a grant cannot blink.
/// When the trough goes from empty to non-empty the landed answer's focus
/// object drops its bloom and falls to ink-1 **once, permanently for that
/// turn** — see `AskPhase.handedOff`. Clearing the trough does not light it
/// again: the attention moved from reading to asking, and a bar that came back
/// alight when a manager deleted a word would be the flicker the whole
/// counted-budget mechanism exists to prevent.
///
/// ## What is never lit here, and was
///
/// The old build tinted bold runs in the headline, list bullets, follow-up
/// chip glyphs, source indices and the callout's box with the accent. Amber is
/// emitted light, never a word, never a marker, never a footnote number. None
/// of those five is on the ladder and none of them appears in this file.
class AskLight {
  const AskLight._();

  /// Send. Rung 1.
  static const String sendClaimId = 'ask-send';

  /// The answer's one focus object — a ranked bar or a trend series. Rung 3.
  static const String focusClaimId = 'ask-answer-focus';

  /// The working-steps rail's running dot. Rung 6, presence and never
  /// progress: it goes out the moment the last tool ends, even though the turn
  /// is not finished, because a breathing amber means *something is happening
  /// right now* and a model composing a sentence is not a lookup.
  static const String pulseClaimId = 'ask-working';

  /// The composer's Send key.
  ///
  /// ## THE GRANTED FORM IS FILLED IN BOTH SKINS — 1 October 2026
  ///
  /// It was a **lit block rather than an amber one** on Night: `lifted` fill
  /// with a 2px flame-600 rim, the glyph in Palladian. That is §1.7's Night
  /// primary — *"a dark block that is lit"* — on the reading that amber on a
  /// dark ground is light rather than paint. The reading is intact and is
  /// still what every other primary in the app does.
  ///
  /// It is not what this control's mockup draws. The approved artifact's
  /// `.send` is `width:27px; height:27px; border-radius:50%;
  /// background:#FFB162` with `color:#16202B` on it — a **solid amber disc**,
  /// in the same two colours, in all three of its panels. The owner, looking
  /// at the running screen: *"the send button is amber… ours is an outlined
  /// disc, not amber."*
  ///
  /// **THIS IS NOT A NEW RULING; IT IS THE SAME ONE, A SECOND TIME.**
  /// `TorchPrimaryButton.filled` exists for exactly this, by owner decision on
  /// 29 September 2026, over Today's `Check in here`: the mockup drew that
  /// control as `background:#FFB162; color:#16202B` too, the owner's note on
  /// the outlined form was that it *"reads weak and boxy"*, and the
  /// resolution was a solid `flame600` block carrying `onAmber` at 10.65:1.
  /// The argument recorded there transfers without modification, including
  /// the part that makes it safe:
  ///
  /// > *"It changes no budget. The census counts connected flame-hued
  /// > regions, not area: a rim is one region and a filled block is one
  /// > region."*
  ///
  /// So Night and Day now differ only in the edge — Day keeps its `ink1` rule,
  /// because on paper nothing is identified by a fill alone and an amber block
  /// on Palladian is 1.6:1 against its own ground. On Night the disc carries
  /// its own contrast and needs no rule.
  ///
  /// The 2px rim and the §12.1 anti-aliasing argument it rested on go with the
  /// rim: that argument was about a **1px stroke** reading as four separate
  /// lights to the census, and a filled disc has no stroke to misread. The
  /// disc is also 36dp now rather than 48dp square — see `_sendDisc` — so the
  /// lit area is about 60% of what the rimmed block enclosed, which is the
  /// other half of why a fill here is not more light than before.
  ///
  /// The spec's 6dp amber top bleed is **cut**. An emitted gradient is
  /// indistinguishable in kind from the focus bloom, so on this surface it
  /// would be a second lit object standing permanently on the screen.
  static AskSendLook send(
    TiqSkin skin, {
    required bool lit,
    required bool pressed,
    required bool disabled,
  }) {
    final p = skin.palette;
    if (disabled) {
      // Disabled must look disabled — 1.4.3 exempts it — and it is never
      // amber, in any skin. Most states of this screen therefore carry no
      // composer amber at all.
      return AskSendLook(
        fill: p.well,
        ink: p.inkMute,
        edge: p.edgeControl,
        edgeWidth: skin.depth.borderWidth,
      );
    }
    if (pressed) {
      return AskSendLook(
        fill: p.amberPressed,
        ink: p.onAmberPressed,
        edge: skin.amberIsInk ? p.ink1 : null,
        edgeWidth: skin.depth.borderWidth,
      );
    }
    if (!lit) {
      return AskSendLook(
        fill: skin.amberIsInk ? p.well : p.lifted,
        ink: p.ink1,
        edge: p.edgeControl,
        edgeWidth: skin.depth.borderWidth,
      );
    }
    // ONE FILL, BOTH SKINS, and the edge is the only thing that differs.
    //
    // On a light ground amber stops being light and becomes a carrier of ink,
    // so Day keeps a real `ink1` edge: an amber block on Palladian is 1.6:1
    // against its own ground, and nothing in this system is identified by a
    // fill alone. On Night the disc carries its own contrast against the
    // ground and a rule on it would be a second silhouette for nothing.
    return AskSendLook(
      fill: p.flame600,
      ink: p.onAmber,
      edge: skin.amberIsInk ? p.ink1 : null,
      edgeWidth: skin.depth.borderWidth,
    );
  }

  /// The fill of the one focus object — a ranked bar, or the trend's primary
  /// series stroke.
  ///
  /// Denied, it is ink-1 and the marker and the weight carry the emphasis
  /// instead. That is not a degradation: on Day the focus is *always* ink,
  /// because amber on a light ground is a carrier of ink and the one carrier
  /// per screen is the commit action.
  static Color focusFill(TiqSkin skin, {required bool lit}) =>
      lit ? skin.palette.flame600 : skin.palette.ink1;

  /// The 12dp bloom beneath a lit bar, drawn inside the bar's own
  /// `BoxDecoration` — never a blur, never a `BoxShadow`, and never a second
  /// draw call. Null whenever the object is not lit, which includes every
  /// light ground.
  static Gradient? focusBloom(TiqSkin skin, {required bool lit}) => lit
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: TiqPalette.glowAmber,
        )
      : null;

  /// The area wash under a lit trend series: flame-600 at 12% to nothing.
  ///
  /// Capped down from the spec's 18% because that wash behind the dashed
  /// terracotta comparison is the worst case for the tightest hue pair in the
  /// system. Unlit, the fill is ink-1 at the same two stops.
  static Gradient seriesWash(TiqSkin skin, {required bool lit}) {
    final base = lit ? skin.palette.flame600 : skin.palette.ink1;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        base.withValues(alpha: 0.12),
        base.withValues(alpha: 0),
      ],
    );
  }

  /// The running step's dot.
  ///
  /// Denied — on Day, or while something else holds the route's one content
  /// grant — it is a `lifted` disc, and the rail appends the word
  /// "Live" to the step's label. The word is not a fallback: under
  /// reduce-motion it is the only channel, and the same code path serves both,
  /// so it cannot rot.
  static Color pulse(TiqSkin skin, {required bool lit}) =>
      lit ? skin.palette.flame600 : skin.palette.lifted;

  /// The radial bloom around the running dot. Null when it is not lit.
  static Gradient? pulseBloom(TiqSkin skin, {required bool lit}) => lit
      ? RadialGradient(
          colors: <Color>[
            skin.palette.flame900.withValues(alpha: 0.55),
            skin.palette.flame600.withValues(alpha: 0.30),
            skin.palette.flame600.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 1],
        )
      : null;
}

/// The resolved look of the Send key: one fill, one ink, one edge.
@immutable
class AskSendLook {
  const AskSendLook({
    required this.fill,
    required this.ink,
    required this.edge,
    required this.edgeWidth,
  });

  final Color fill;
  final Color ink;
  final Color? edge;
  final double edgeWidth;
}
