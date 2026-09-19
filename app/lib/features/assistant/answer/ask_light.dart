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
/// | 1 `primaryCommit` | Send's rim (Night) / block (Day, Veld) | the manager has typed something |
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
  /// Night's granted form is a **lit block, not an amber one**: `lifted` fill
  /// with a 2px flame-600 rim, the glyph in Palladian. The rim is 2px for the
  /// reason §12.1 gives — a 1px stroke on a radius-10 shoulder anti-aliases to
  /// about 72% value at the corners, under the census's 0.90 floor, so the
  /// census reads a 1px rim as four separate lights and a correctly built
  /// commit button fails the budget it obeys.
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
      // composer amber at all. In Veld the caller also strikes the glyph
      // through, because a colour-only disabled state is invisible at 40%
      // backlight in sun.
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
        // Veld's press is an ink block, and an ink block on white needs its
        // border as much as an amber one does.
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
    if (skin.amberIsInk) {
      // On a light ground amber stops being light and becomes a carrier of
      // ink. A solid block with a real ink-1 edge: an amber block on
      // Palladian is 1.6:1 against its own ground, and nothing in this system
      // is identified by a fill alone.
      return AskSendLook(
        fill: p.flame600,
        ink: p.onAmber,
        edge: p.ink1,
        edgeWidth: skin.depth.borderWidth,
      );
    }
    return AskSendLook(
      fill: p.lifted,
      ink: p.ink1,
      edge: p.flame600,
      edgeWidth: 2,
    );
  }

  /// The fill of the one focus object — a ranked bar, or the trend's primary
  /// series stroke.
  ///
  /// Denied, it is ink-1 and the marker and the weight carry the emphasis
  /// instead. That is not a degradation: on Day and Veld the focus is *always*
  /// ink, because amber on a light ground is a carrier of ink and the one
  /// carrier per screen is the commit action.
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
  /// Denied — on Day, in Veld, or while something else holds the route's one
  /// content grant — it is a `lifted` disc, and the rail appends the word
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
