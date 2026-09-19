import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../design/motion_budget.dart';
import '../../../design/torch_scope.dart';
import '../../../theme/torchlight/tiq_skin.dart';
import '../button/torch_press.dart';
import 'sheet_spec.dart';

/// THE ONE MODAL CONTAINER.
///
/// There is no dialog. Unify §1.7 deleted it outright: a non-dismissible
/// bottom sheet covers every blocking case a dialog covered, and two modal
/// containers is two sets of insets, two dismissal rules, two scrims and two
/// answers to "what happens to the amber underneath".
///
/// ```dart
/// final answer = await showTorchSheet<bool>(
///   context,
///   title: 'Discard this count?',
///   builder: (context) => ConfirmSheet(…),
/// );
/// ```
///
/// ## Four rules, all of them load-bearing
///
/// **72% scrim, no blur.** Not 88%: #380 wants the held work visible behind
/// the session-ended sheet, and `BackdropFilter` is banned outright (unify §4
/// — zero `saveLayer` in this product).
///
/// **The screen beneath goes dark.** While any sheet is up, every amber on the
/// route underneath is extinguished — the nav's active tab drops to its ink
/// form, the plate's strip light goes out — so the sheet's own `TorchScope`
/// genuinely owns the frame without a heavier scrim hiding the thing the sheet
/// is about. See [TorchSheets] and [TorchScope.beneathSheet].
///
/// **No stacking.** A sheet that needs a sheet cross-fades its own content;
/// see [TorchSheetSwap]. Opening a second sheet over a first asserts in debug
/// and, in release, does the only sane thing left — it opens anyway rather
/// than dropping the user's action on the floor.
///
/// **Veld has no sheets.** The same call renders a full-screen white route
/// with a 2px border and a 56dp Close row, because a translucent wash outdoors
/// dims nothing and obscures everything.
class TorchSheet extends StatelessWidget {
  const TorchSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.dismissible = true,
    this.onDismiss,
    this.claims = const <TorchClaim>[],
    this.semanticsLabel,
    this.closeLabel = 'Close',
    this.scrollable = true,
  });

  /// The sheet's body, below the grabber and the optional title.
  final Widget child;

  /// `title.l`, ink-1, wrapping. A sheet without a title is legal — a
  /// skip-reason picker leads with its question — but a sheet without either a
  /// title or a heading inside [child] is a modal nobody can name.
  final String? title;

  /// One `body` ink-2 line under the title.
  final String? subtitle;

  /// False for a blocking sheet: the session-ended sheet on first appearance,
  /// and a decision sheet whose work would be lost. A non-dismissible sheet
  /// swallows the scrim tap and the system back gesture, and it must therefore
  /// carry at least one action that closes it — asserted by [DecisionSheet].
  final bool dismissible;

  /// Called when the sheet is dismissed by the scrim, the back gesture or the
  /// Veld Close row. Not called when an action pops the route itself.
  final VoidCallback? onDismiss;

  /// The sheet's own amber claims. A sheet is an **untabbed** route, so Night
  /// gives it two content grants and Day and Veld give it one — see
  /// [TorchScope]. Most sheets declare exactly one: their primary action.
  final List<TorchClaim> claims;

  final String? semanticsLabel;

  /// The word on the Veld Close row. Localised by the caller.
  final String closeLabel;

  /// Whether the body scrolls when it outgrows 88% of the viewport. True
  /// almost always; a decision sheet with two thumb-height actions sets it
  /// false for the action block so the actions cannot scroll off.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final media = MediaQuery.of(context);
    final spec = TorchSheetSpec.resolve(
      skin: skin,
      bottomSafeArea: media.padding.bottom,
    );
    final veld = spec.form == TorchSheetForm.fullScreen;

    final header = <Widget>[
      if (title != null)
        Text(
          title!,
          style: spec.titleStyle.style(color: spec.titleInk),
          // Every label wraps at every size. Nothing here is pinned.
        ),
      if (subtitle != null) ...<Widget>[
        const SizedBox(height: TiqSpace.s2),
        Text(subtitle!, style: spec.bodyStyle.style(color: spec.bodyInk)),
      ],
      if (title != null || subtitle != null)
        const SizedBox(height: TiqSpace.s4),
    ];

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[...header, child],
    );

    // THE HORIZONTAL PADDING IS INSIDE THE SCROLL, and the `Flexible` is a
    // direct child of the one Column. Both matter: a `Flexible` nested inside
    // a second min-size Column takes the full remaining height and then the
    // grabber above it pushes the pair past the ceiling, which is an overflow
    // that only appears at 2.0× on a 320dp phone — the one place nobody
    // screenshots. Flat, once, measured by the test that found it.
    final padded = Padding(
      padding: EdgeInsets.symmetric(horizontal: spec.horizontalPadding),
      child: inner,
    );

    final body = scrollable
        ? Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: spec.bottomPadding),
              child: padded,
            ),
          )
        : Padding(
            padding: EdgeInsets.only(bottom: spec.bottomPadding),
            child: padded,
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (veld)
          _VeldCloseRow(
            label: closeLabel,
            height: spec.closeRowHeight,
            onClose: () => _dismiss(context),
          )
        else
          _Grabber(spec: spec),
        SizedBox(height: veld ? TiqSpace.s5 : spec.belowGrabber),
        body,
      ],
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: semanticsLabel != null || title != null,
      label: semanticsLabel ?? title,
      explicitChildNodes: true,
      child: TorchScope(
        skin: skin,
        phase: 'sheet',
        // A sheet is never a tab root: the nav is behind it and its active tab
        // has just been put out. Two content grants in Night, one on a light
        // ground.
        claims: claims,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: spec.fill,
            borderRadius: spec.radius,
            border: veld
                ? Border.all(color: spec.outline, width: spec.outlineWidth)
                : Border(
                    top: BorderSide(
                      color: spec.outline,
                      width: spec.outlineWidth,
                    ),
                    left: BorderSide(
                      color: spec.outline,
                      width: spec.outlineWidth,
                    ),
                    right: BorderSide(
                      color: spec.outline,
                      width: spec.outlineWidth,
                    ),
                  ),
          ),
          child: content,
        ),
      ),
    );
  }

  void _dismiss(BuildContext context) {
    onDismiss?.call();
    Navigator.of(context).maybePop();
  }
}

/// The 4dp bar at the top of a sheet. Never a control — see
/// [TorchSheetSpec.grabber].
class _Grabber extends StatelessWidget {
  const _Grabber({required this.spec});

  final TorchSheetSpec spec;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: spec.grabberTopInset),
    child: Center(
      child: ExcludeSemantics(
        child: Container(
          width: spec.grabberWidth,
          height: spec.grabberHeight,
          decoration: BoxDecoration(
            color: spec.grabberColour,
            borderRadius: BorderRadius.circular(spec.grabberHeight / 2),
          ),
        ),
      ),
    ),
  );
}

/// Veld's 56dp Close row, with a 2px rule beneath it.
///
/// It is a row and not an icon in a corner because outdoors a 24dp glyph at
/// arm's length in glare is a smudge, and because the whole point of the Veld
/// form is that there is no scrim to tap.
class _VeldCloseRow extends StatelessWidget {
  const _VeldCloseRow({
    required this.label,
    required this.height,
    required this.onClose,
  });

  final String label;
  final double height;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final press = torchPressSurface(skin);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: TorchPressable(
        onPressed: onClose,
        pressScale: 1,
        builder: (context, pressed) => Container(
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            color: pressed ? press.fill : null,
            border: Border(
              bottom: BorderSide(
                color: skin.palette.edgeStructure,
                width: skin.depth.borderWidth,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: skin.space.gutter),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: skin.text.titleM.style(
              color: pressed ? press.ink : skin.palette.ink1,
            ),
          ),
        ),
      ),
    );
  }
}

/// HOW MANY SHEETS ARE UP, AND WHO NEEDS TO KNOW.
///
/// One number, published as a [ValueListenable], because two different parts
/// of the app need it and neither can see the other: the shell, which has to
/// tell its route's [TorchScope] that every amber beneath the sheet is out,
/// and [showTorchSheet], which has to refuse to stack.
///
/// It is a global rather than an `InheritedWidget` on purpose. The thing that
/// has to react is *above* the sheet's route in the tree and *below* the
/// navigator that owns it, so no inherited widget the sheet can publish is
/// visible from there.
class TorchSheets {
  TorchSheets._();

  static final ValueNotifier<int> openCount = ValueNotifier<int>(0);

  static bool get anyOpen => openCount.value > 0;

  /// Reset, for a test. A leaked count from a previous test would extinguish
  /// the next one's amber and the failure would name the wrong component.
  @visibleForTesting
  static void resetForTest() => openCount.value = 0;
}

/// Wrap a route's body in this and it darkens itself while a sheet is up.
///
/// ```dart
/// TorchSheetAware(
///   builder: (context, beneathSheet) => TorchScope(
///     skin: context.skin,
///     phase: 'loaded',
///     navRenders: true,
///     tabbedRoute: true,
///     beneathSheet: beneathSheet,
///     claims: claims,
///     child: body,
///   ),
/// )
/// ```
///
/// The shell does this once so no screen has to remember to. A screen that
/// builds its own `TorchScope` outside a shell wires it itself — the amber
/// census fails loudly if it does not, which is the point.
class TorchSheetAware extends StatelessWidget {
  const TorchSheetAware({super.key, required this.builder});

  final Widget Function(BuildContext context, bool beneathSheet) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: TorchSheets.openCount,
    builder: (context, count, _) => builder(context, count > 0),
  );
}

/// The route [showTorchSheet] pushes. Exposed so a test can find it and a
/// shell can decide whether the thing on top is a sheet.
class TorchSheetRoute<T> extends PopupRoute<T> {
  TorchSheetRoute({
    required this.builder,
    required this.skin,
    required this.dismissible,
    super.settings,
  });

  final WidgetBuilder builder;
  final TiqSkin skin;
  final bool dismissible;

  late final TorchSheetSpec _spec = TorchSheetSpec.resolve(skin: skin);

  @override
  Color? get barrierColor =>
      _spec.form == TorchSheetForm.fullScreen ? null : _spec.scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => dismissible ? 'Dismiss' : null;

  /// Veld's form is a full-screen opaque route; the sheet form is not.
  @override
  bool get opaque => _spec.form == TorchSheetForm.fullScreen;

  @override
  Duration get transitionDuration => skin.motion.resolve(TiqMotion.reveal);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // A sheet is its own route, above the shell's text style: without this
    // every word in it inherits MaterialApp's yellow-underlined error style.
    return DefaultTextStyle(
      style: skin.text.body.style(color: skin.palette.ink1),
      child: _page(context),
    );
  }

  Widget _page(BuildContext context) {
    final media = MediaQuery.of(context);
    // A sheet route has no Material above it, so without this every Text in
    // it inherits the framework's debug fallback — the red-on-yellow double
    // underline — merged into the skin's token styles, which all inherit.
    // Replacing (not merging) the ambient style gives the tokens a clean base.
    final page = _spec.form == TorchSheetForm.fullScreen
        ? SafeArea(child: builder(context))
        : _anchored(context, media);
    return DefaultTextStyle(
      style: skin.text.body.style(color: skin.palette.ink1),
      child: page,
    );
  }

  Widget _anchored(BuildContext context, MediaQueryData media) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: _spec.maxHeightFor(media.size.height),
        ),
        // A sheet never resizes under a thumb (unify §4): the keyboard inset
        // is padding at the bottom, so the sheet slides up whole instead of
        // re-laying-out its own content while a finger is on it.
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: builder(context),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final still = MotionBudget.of(context).still;
    if (still || !skin.motion.enabled) return child;
    if (_spec.form == TorchSheetForm.fullScreen) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: animation, curve: TiqMotion.enterCurve),
          ),
      child: child,
    );
  }
}

/// Open the one modal container.
///
/// Returns whatever the sheet pops with, or null when it was dismissed.
///
/// [dismissible] false makes the sheet blocking: the scrim swallows taps and
/// the system back gesture is refused. Use it for the session-ended sheet's
/// first appearance and nowhere else without a reason in the PR.
Future<T?> showTorchSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  RouteSettings? settings,
}) {
  assert(() {
    if (TorchSheets.anyOpen) {
      throw FlutterError(
        'A second Torchlight sheet was opened over an existing one.\n\n'
        'Sheets do not stack (unify §1.10). A sheet that needs a sheet '
        'cross-fades its own content — see TorchSheetSwap — because two '
        'scrims is two dimmings of the same screen, the second modal is 44dp '
        'shorter than the first for no reason a reader can name, and the back '
        'gesture stops meaning anything.\n\n'
        'If the second sheet really is a different subject, pop the first.',
      );
    }
    return true;
  }());

  final skin = context.skin;
  TorchSheets.openCount.value += 1;
  return Navigator.of(context, rootNavigator: true)
      .push(
        TorchSheetRoute<T>(
          builder: builder,
          skin: skin,
          dismissible: dismissible,
          settings: settings,
        ),
      )
      .whenComplete(() {
        TorchSheets.openCount.value -= 1;
      });
}

/// THE ANSWER TO "THIS SHEET NEEDS A SHEET".
///
/// A cross-fade between two panes of the **same** sheet, at the reveal
/// duration, held at the taller pane's height so the sheet does not jump under
/// a thumb that is already on it. Under [MotionBudget.still] the swap is
/// instant and the pane simply changes — still one sheet, still one back
/// gesture, no motion.
///
/// This is how the decision sheet's two-step destructive confirm works
/// (unify §1.21): the proof block cross-fades to "Delete and start over",
/// bad-outlined, and never to a second modal.
class TorchSheetSwap extends StatelessWidget {
  const TorchSheetSwap({super.key, required this.paneKey, required this.child});

  /// Changes when the pane changes. A `String` name reads better in a test
  /// failure than an index.
  final String paneKey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final still = MotionBudget.of(context).still;
    final duration = skin.motion.resolve(TiqMotion.reveal);
    // UNDER REDUCE-MOTION THE SWAP IS THE PANE CHANGING, and nothing else —
    // not a zero-duration animation, which is a different thing wearing the
    // same clothes. `AnimatedSize` at zero duration still re-dirties itself
    // inside its own `performLayout` when a pane arrives at a new height,
    // which is an assertion in debug and a dropped frame in release. The
    // reader who asked for no motion gets no animator at all.
    if (still || duration == Duration.zero) {
      return KeyedSubtree(key: ValueKey<String>(paneKey), child: child);
    }
    return AnimatedSize(
      duration: duration,
      curve: TiqMotion.stateCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: TiqMotion.enterCurve,
        switchOutCurve: TiqMotion.exitCurve,
        // Both panes are laid out at the top: a cross-fade that centres its
        // children makes the words move sideways as they change, which reads
        // as a glitch rather than a transition.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey<String>(paneKey), child: child),
      ),
    );
  }
}
