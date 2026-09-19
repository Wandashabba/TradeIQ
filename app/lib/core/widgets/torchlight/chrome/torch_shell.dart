import 'package:flutter/widgets.dart';

import '../../../theme/torchlight/tiq_skin.dart';
import 'nav_circle.dart';
import 'nav_pill.dart';
import 'thumb_zone.dart';

/// Which shell a route is wearing.
enum TorchShellProfile {
  /// The field agent's phone. Field density, no letterbox falloff, a skin
  /// cycle in every bottom region.
  agent,

  /// The manager console. Console density, the letterbox falloff, a wider
  /// gutter past 1080dp.
  console,
}

/// THE FRAME. Gutter, header, scroll, and the bottom region.
///
/// It replaces `Scaffold` + `AppBar` for every Torchlight route. One scrollable,
/// one semantics order, no horizontal page scroll at any width.
///
/// ```dart
/// TorchScope(
///   skin: context.skin,
///   phase: 'loaded',
///   navRenders: TorchShell.navWillRender(context, hasNav: true),
///   tabbedRoute: true,
///   claims: <TorchClaim>[TorchPrimaryButton.claim('raise-task')],
///   child: TorchShell(
///     profile: TorchShellProfile.console,
///     header: TorchAppHeader(title: 'The Floor', trailing: skinCycle),
///     navPill: TorchNavPill(slots: managerSlots, activeIndex: 0, onSelect: go),
///     navCircle: TorchNavCircle(claimId: 'raise-task', …),
///     children: <Widget>[ … ],
///   ),
/// )
/// ```
///
/// ## The bottom region: three shapes, one always applies
///
/// 1. **Tab root** — no thumb zone. A floating 64dp row, inset 16 from both
///    gutters, 20dp above the safe area: the nav pill, a 12dp gap, the 64dp
///    circle. **Veld docks the bar** instead: full-bleed, 72dp, a 2px top
///    border, radius 0, and the circle floats above its trailing end.
/// 2. **A screen with a primary action** — a [TorchThumbZone] at 96dp with the
///    skin cycle at the leading gutter.
/// 3. **A screen with neither** — a 76dp zone holding the skin cycle alone.
///    Never a screen without the skin cycle: the one control that gets a person
///    out of a skin they cannot read belongs on every screen they can reach.
///
/// The body's bottom padding reserves the region's height, the 20dp float, the
/// safe area and a block gap, so nothing is ever underneath the chrome.
///
/// ## The keyboard takes the nav away, and gives its amber back
///
/// When the software keyboard is up the nav does not render. That is not only a
/// layout decision: the nav's active tab is **slot 1** of Night's two amber
/// grants, so a route with the keyboard open has two content grants instead of
/// one — which is exactly what makes "a focused field plus a lit primary" fit
/// inside the budget. A route must tell its [TorchScope] the same thing it
/// tells the shell, and [TorchShell.navWillRender] is the single answer both
/// read.
///
/// **Amber: none.** The shell is the unlit room. It hosts its screen's amber
/// and paints none of its own.
class TorchShell extends StatelessWidget {
  const TorchShell({
    super.key,
    required this.profile,
    required this.children,
    this.header,
    this.navPill,
    this.navCircle,
    this.primary,
    this.secondary,
    this.skinCycle,
    this.band,
    this.scrollController,
    this.pinned,
  }) : assert(
         navPill == null || primary == null,
         'A tab root has no thumb zone and a screen with a primary commit '
         'action has no nav. The two bottom regions are alternatives, not '
         'layers — 64dp of nav plus 96dp of thumb zone plus a safe area is a '
         'quarter of a 640dp screen given to chrome.',
       );

  final TorchShellProfile profile;

  /// The body. Gutter-padded by the shell; block gaps are the caller's.
  final List<Widget> children;

  /// A [TorchAppHeader], or nothing on a route that has no title.
  final Widget? header;

  /// Present on a tab root, absent everywhere else.
  final TorchNavPill? navPill;

  /// The role's standing action, beside the pill.
  final TorchNavCircle? navCircle;

  /// The route's one commit action, in the thumb zone.
  final Widget? primary;

  /// A ghost alternative above the primary.
  final Widget? secondary;

  /// The skin cycle. On a tab root it belongs in the header's single trailing
  /// slot, not here; on every other screen it goes at the leading end of the
  /// thumb zone.
  final Widget? skinCycle;

  /// A pinned region between the scroll view and the bottom region: the Ask
  /// route's composer, and nothing else so far.
  ///
  /// It is **not** a thumb zone and it does not carry a commit action of the
  /// thumb zone's kind — a composer is where a question is written, and it has
  /// to stay on screen with the keyboard up, which is exactly when the nav is
  /// not there. Like the bottom region it is a **sibling** of the scroll view
  /// rather than an overlay, so its height is whatever its content measures at
  /// 2.0× and nothing is ever underneath it.
  ///
  /// The band is gutter-padded by the shell and clears the software keyboard
  /// itself: without a `Scaffold` nothing else reads `viewInsets`, and a
  /// composer behind a keyboard is a composer nobody can see themselves
  /// typing into.
  final Widget? band;

  final ScrollController? scrollController;

  /// A band that stays at the top of the viewport while the body scrolls
  /// beneath it — the stock counter's summary rule is the one user. The header
  /// scrolls away above it as usual, so the band is the only fixed chrome at
  /// the top. It sits on the ground colour, with no shadow and no blur (the
  /// paint budget), and is gutter-padded like the body.
  final Widget? pinned;

  /// Whether the nav will actually be on screen — the answer both the shell and
  /// the route's [TorchScope] must use.
  ///
  /// It is false while the keyboard is up, which returns the nav's amber grant
  /// to the content beneath it.
  static bool navWillRender(BuildContext context, {required bool hasNav}) =>
      hasNav && MediaQuery.viewInsetsOf(context).bottom <= 0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;
    final width = media.size.width;
    final gutter = profile == TorchShellProfile.console
        ? skin.space.gutterFor(width).left
        : skin.space.gutter;
    final showNav = navWillRender(context, hasNav: navPill != null);
    final docked = skin.mode == SkinMode.veld;

    final bottom = _bottomRegion(
      context,
      skin: skin,
      showNav: showNav,
      docked: docked,
      gutter: gutter,
    );

    final top = profile == TorchShellProfile.console
        ? TiqSpace.s6
        : TiqSpace.s4;
    final headerBlock = <Widget>[
      if (header != null) ...<Widget>[
        header!,
        // 24dp before content, and no divider. The header is separated from
        // the body by space, which is the only separator that does not also
        // claim to mean something.
        const SizedBox(height: TiqSpace.s6),
      ],
    ];

    // The bottom region is a **sibling** of the scroll view, not an overlay,
    // so the only thing the body reserves is the block gap that keeps its last
    // row off the chrome. Overlaying it would mean reserving a height computed
    // from tokens — and at 2.0× the region is taller than those tokens, which
    // is how the last row of a list ends up under a nav bar on exactly the
    // devices whose readers need it most.
    final Widget body;
    // Named for what it is: `band` is the field for the region ABOVE the
    // bottom chrome (the composer), and a local of the same name here left
    // Ask TradeIQ's composer unrendered on every frame.
    final pinnedBand = pinned;
    if (pinnedBand == null) {
      body = ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(gutter, top, gutter, skin.space.blockGap),
        children: <Widget>[...headerBlock, ...children],
      );
    } else {
      body = CustomScrollView(
        controller: scrollController,
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, top, gutter, 0),
            sliver: SliverList.list(children: headerBlock),
          ),
          // Sized by its child, so the band is as tall as its words at 2.0×
          // rather than a token height that clips them.
          PinnedHeaderSliver(
            child: ColoredBox(
              key: const ValueKey<String>('torch-shell-pinned'),
              color: skin.palette.ground,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: pinnedBand,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              0,
              gutter,
              skin.space.blockGap,
            ),
            sliver: SliverList.list(children: children),
          ),
        ],
      );
    }

    // The letterbox falloff is the shell's **ground**, not a wash over its
    // content: four stops in one draw call, painted once, beneath everything.
    // Two stops band on a 6-bit panel, and Veld has no falloff at all —
    // outdoors a gradient is a smudge.
    final falloff =
        profile == TorchShellProfile.console && skin.mode != SkinMode.veld;

    final keyboard = media.viewInsets.bottom;

    // The route's own text style, beneath everything. A Torchlight route has
    // no Scaffold or Material above it, and without this every Text inherits
    // the framework's debug fallback — a red-on-yellow double underline,
    // merged into the skin's token styles because they all inherit, and
    // counted by the census as light wherever it crossed a crimson or Oatmeal
    // word. A role style names its face, size and ink, never its decoration,
    // so replacing (not merging) the ambient style is what gives the tokens a
    // clean base.
    return DefaultTextStyle(
      style: skin.text.body.style(color: skin.palette.ink1),
      child: _Ground(
        skin: skin,
        falloff: falloff,
        child: Column(
          children: <Widget>[
            Expanded(child: body),
            if (band != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  0,
                  gutter,
                  // The band is the last thing above the keyboard, so it is the
                  // band that clears it. When the keyboard is down this is zero
                  // and the gap to the bottom region is the caller's.
                  keyboard,
                ),
                child: band,
              ),
            ?bottom,
            SizedBox(height: safeBottom),
          ],
        ),
      ),
    );
  }

  Widget? _bottomRegion(
    BuildContext context, {
    required TiqSkin skin,
    required bool showNav,
    required bool docked,
    required double gutter,
  }) {
    if (showNav) {
      final pill = navPill!;
      final circle = navCircle;
      if (docked) {
        // Docked: the bar is the bottom edge of the screen. The circle cannot
        // sit beside it any more, so it floats above the bar's trailing end —
        // still 12dp away, still outside the bar.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (circle != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(right: gutter),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: circle,
                ),
              ),
              const SizedBox(height: TorchNavCircle.gap),
            ],
            pill,
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          TiqSpace.s4,
          0,
          TiqSpace.s4,
          TiqSpace.s5,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: pill),
            if (circle != null) ...<Widget>[
              const SizedBox(width: TorchNavCircle.gap),
              circle,
            ],
          ],
        ),
      );
    }

    if (primary == null && skinCycle == null) return null;
    return TorchThumbZone(
      skinCycle: skinCycle,
      primary: primary,
      secondary: secondary,
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground({
    required this.skin,
    required this.falloff,
    required this.child,
  });

  final TiqSkin skin;
  final bool falloff;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!falloff) {
      return ColoredBox(color: skin.palette.ground, child: child);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final band = height <= 400 ? 0.25 : 96 / height;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                skin.palette.ground,
                skin.palette.vignette,
                skin.palette.vignette,
                skin.palette.ground,
              ],
              stops: <double>[0, band, 1 - band, 1],
            ),
          ),
          child: child,
        );
      },
    );
  }
}
