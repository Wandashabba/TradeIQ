import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import '../chrome/nav_pill.dart';
import '../mark/tiq_mark.dart';

/// The four things a toast can be. Four kinds, four silhouettes — the glyph
/// carries the kind without colour.
enum ToastKind {
  /// A fact. No haptic.
  neutral,

  /// Something landed. `TorchBuzz.success`.
  success,

  /// Something did not. `TorchBuzz.warning`, and twice the dwell, because a
  /// failure needs reading.
  failure,

  /// **Held is not a failure.** "Held on this phone · sends itself" is a
  /// statement of normal South African field connectivity, and it takes the
  /// neutral treatment with an Oatmeal square — never the failure treatment,
  /// never crimson.
  held,
}

/// CONFIRMING THAT SOMETHING LANDED, WITHOUT STEALING THE SCREEN.
///
/// Replaces `SnackBar`.
///
/// ```dart
/// showTorchToast(context, message: 'Visit sent · scored 71', kind: ToastKind.success);
/// ```
///
/// It floats **above the nav pill** — the pill's height plus its 20dp standoff
/// plus the safe area — so a toast never covers the thing a thumb is reaching
/// for. On a screen with a thumb zone instead of a nav, the zone's height is
/// added the same way.
///
/// **A toast is a report, and a report is never lit.** No claim, no flame
/// token, in any kind, in any skin.
class TorchToast extends StatelessWidget {
  const TorchToast({
    super.key,
    required this.message,
    this.kind = ToastKind.neutral,
    this.action,
    this.onClose,
  });

  final String message;
  final ToastKind kind;

  /// A trailing tertiary — "Undo", "View". Its presence doubles the dwell.
  final Widget? action;

  /// A persistent toast (a failure that must be acted on) renders a close
  /// control rather than disappearing.
  final VoidCallback? onClose;

  /// The flattened success wash, declared rather than composited: `good` at
  /// 12% over the Night ground is a different grey on every surface it lands
  /// on, and opacity is banned as a state channel.
  static const Color successWashNight = Color(0xFF2A373D);

  /// Its Day counterpart.
  static const Color successWashDay = Color(0xFFDDEAE2);

  /// How long each kind stays, before the action's extension.
  static Duration dwellFor(ToastKind kind, {required bool hasAction}) {
    if (hasAction) return const Duration(seconds: 6);
    return switch (kind) {
      ToastKind.failure => const Duration(seconds: 6),
      _ => const Duration(seconds: 3),
    };
  }

  /// How far above the bottom edge a toast floats.
  ///
  /// The nav pill's own height plus its 20dp standoff plus another 20 — or, on
  /// a route with no nav, the thumb zone's height. A toast that covers the
  /// primary commit action is a toast that arrived to tell you about the thing
  /// you can no longer press.
  static double bottomOffsetFor(
    TiqSkin skin, {
    bool navRenders = true,
    double thumbZoneHeight = 0,
    double safeArea = 0,
  }) {
    final chrome = navRenders
        ? TorchNavPill.heightFor(skin) + TiqSpace.s5
        : thumbZoneHeight;
    return chrome + TiqSpace.s5 + safeArea;
  }

  MarkShape get _shape => switch (kind) {
    ToastKind.neutral => MarkShape.dot,
    ToastKind.success => MarkShape.onTargetCircle,
    ToastKind.failure => MarkShape.criticalTriangle,
    ToastKind.held => MarkShape.heldSquare,
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final p = skin.palette;
    final veld = skin.density == TiqDensity.veld;

    Color fill;
    Color ink;
    Color? border;
    switch (kind) {
      case ToastKind.success:
        if (veld) {
          // Outlines and washes do not survive glare: Veld goes solid.
          fill = p.goodSolid;
          ink = p.onGoodSolid;
          border = p.ink1;
        } else {
          fill = skin.brightness == Brightness.dark
              ? successWashNight
              : successWashDay;
          ink = p.ink1;
          border = p.good;
        }
      case ToastKind.failure:
        if (veld) {
          fill = p.badSolid;
          ink = p.onBadSolid;
          border = p.ink1;
        } else {
          fill = p.well;
          ink = p.ink1;
          // The whole outline goes crimson rather than a single leading side:
          // a `BoxDecoration` refuses a radius on a border whose sides differ
          // in colour, and a 10dp corner in `bad` is a better failure edge
          // than a straight bar interrupted by two arcs. The filled triangle
          // beside the words is the silhouette that carries it.
          border = p.badSolid;
        }
      case ToastKind.neutral:
      case ToastKind.held:
        fill = veld ? p.ground : p.well;
        ink = p.ink1;
        border = veld ? p.ink1 : p.edgeControl;
    }

    final glyphInk = switch (kind) {
      ToastKind.success => veld ? ink : p.good,
      ToastKind.failure => veld ? ink : p.bad,
      ToastKind.held => veld ? ink : p.ink2,
      ToastKind.neutral => veld ? ink : p.ink2,
    };

    // The failure bar is a child, not a border side: a `BoxDecoration` refuses
    // a radius on a border whose sides differ in colour, and a crimson edge
    // bent around a 10dp corner is a shape nobody drew. See the same note on
    // the held banner.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: BoxConstraints(minHeight: veld ? 64 : 48),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(skin.radii.control),
          border: Border.all(color: border, width: skin.depth.borderWidth),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: TiqSpace.s4,
          vertical: TiqSpace.s3,
        ),
        child: Row(
          children: <Widget>[
            TiqMark(
              shape: _shape,
              color: glyphInk,
              size: MarkScale.glyph(context, kind == ToastKind.neutral ? 8 : 16),
            ),
            const SizedBox(width: TiqSpace.s3),
            Expanded(
              child: Text(
                message,
                style: (veld ? skin.text.bodyStrong : skin.text.body).style(
                  color: ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(width: TiqSpace.s4),
              // Flexible, so at 2.0× on a 320dp phone the action gives ground
              // rather than pushing itself off the end of the bar.
              Flexible(child: action!),
            ],
            if (onClose != null) ...<Widget>[
              const SizedBox(width: TiqSpace.s3),
              Semantics(
                button: true,
                label: 'Dismiss',
                excludeSemantics: true,
                child: TorchPressable(
                  onPressed: onClose,
                  pressScale: torchPressScaleGlyph,
                  builder: (context, pressed) => SizedBox.square(
                    dimension: skin.space.tapTarget,
                    child: Center(
                      child: TiqMark(
                        shape: MarkShape.flagStruckRing,
                        color: ink,
                        size: MarkScale.glyph(context, 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one toast on screen, and how it is replaced.
///
/// A second toast **replaces** the first rather than stacking — two floating
/// bars over a nav pill is a stack of reports nobody read the first of.
class _ToastController {
  _ToastController._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

/// Show a toast over the nearest overlay.
///
/// Returns immediately. [persistent] keeps it up until it is acted on or
/// dismissed — for a failure that *must* be dealt with, and for the case where
/// the platform reports an accessibility timeout preference, where every toast
/// should be persistent with a close control.
void showTorchToast(
  BuildContext context, {
  required String message,
  ToastKind kind = ToastKind.neutral,
  Widget? action,
  bool persistent = false,
  bool navRenders = true,
  double thumbZoneHeight = 0,
}) {
  final skin = context.skin;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _ToastController.dismiss();

  switch (kind) {
    case ToastKind.success:
      TorchBuzz.success();
    case ToastKind.failure:
      TorchBuzz.warning();
    case ToastKind.neutral:
    case ToastKind.held:
      break;
  }

  final media = MediaQuery.of(context);
  final bottom = TorchToast.bottomOffsetFor(
    skin,
    navRenders: navRenders,
    thumbZoneHeight: thumbZoneHeight,
    safeArea: media.padding.bottom,
  );

  final entry = OverlayEntry(
    builder: (overlayContext) => Positioned(
      left: TiqSpace.s4,
      right: TiqSpace.s4,
      bottom: bottom,
      child: _ToastSurface(
        child: TorchToast(
          message: message,
          kind: kind,
          action: action,
          onClose: persistent ? _ToastController.dismiss : null,
        ),
      ),
    ),
  );
  _ToastController._entry = entry;
  overlay.insert(entry);

  if (persistent) return;
  final dwell = TorchToast.dwellFor(kind, hasAction: action != null);
  _ToastController._timer = Timer(dwell, _ToastController.dismiss);
}

/// The 8dp rise on entry. Dropped entirely when the frame is still.
class _ToastSurface extends StatefulWidget {
  const _ToastSurface({required this.child});

  final Widget child;

  @override
  State<_ToastSurface> createState() => _ToastSurfaceState();
}

class _ToastSurfaceState extends State<_ToastSurface> {
  bool _in = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final still = MotionBudget.of(context).still;
    if (still) return widget.child;
    return AnimatedSlide(
      offset: _in ? Offset.zero : const Offset(0, 0.2),
      duration: skin.motion.resolve(TiqMotion.enter),
      curve: TiqMotion.enterCurve,
      child: widget.child,
    );
  }
}
