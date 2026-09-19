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

  final ScrollController? scrollController;

  /// A band that stays at the top of the viewport while the body scrolls
  /// beneath it — the stock counter's summary rule is the one user. The header
  /// scrolls away above it as usual, so the band is the only fixed chrome at
  /// the top. It sits on the ground colour, with no shadow and no blur (the
  /// paint budget), and is gutter-padded like the body.
  ///
  /// ## The band is capped at 40%, for the same reason the header is
  ///
  /// It used to be sized by its child with no ceiling. Measured on a 360×640
  /// phone, the stock summary's rect after the header scrolled away was 187dp
  /// at 1.0×, **296dp at 1.4×** — past unify §4's 40% — and **543dp at 2.0×**,
  /// 85% of the screen, leaving under 100dp for the shelf it is a summary of.
  /// Worse, an uncapped band plus a header is taller than the fold, so on
  /// arrival the sliver got no paint extent at all: at 2.0× in Afrikaans an
  /// agent opening Stock saw the header and nothing else, and the "only fixed
  /// chrome on a 60-SKU shelf" was not in the frame.
  ///
  /// So the shell caps it at [pinnedBandFraction] of the screen. Like the
  /// header's 40%, the cap is **not** meant to be reached: a band is expected
  /// to fit by construction — the stock rule collapses to its one counted line
  /// above 1.3× and hands the sentence and the jump to the body — and the cap
  /// is the backstop that keeps a band from swallowing the screen it belongs
  /// to, and what will not fit scrolls inside the cap rather than being
  /// clipped away. No clip layer, no `saveLayer`, nothing new on the paint
  /// budget.
  ///
  /// The band stays **below** the header rather than above the scroll view.
  /// Hoisting it would put a status line above the route's title and its back
  /// arrow, which is not chrome — it is a lid over the way out. What makes the
  /// band chrome on arrival is the arithmetic of the two caps: a header at 40%
  /// and a band at 40% fit on any fold together.
  final Widget? pinned;

  /// The share of the screen a [pinned] band may take. unify §4's header rule,
  /// applied to the one other thing that holds a place at the top.
  static const double pinnedBandFraction = 0.4;

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
    final band = pinned;
    if (band == null) {
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
          // Sized by its child so the band is as tall as its words at 2.0×
          // rather than a token height that clips them — and capped at 40% of
          // the screen so those words never take the screen instead. See the
          // [pinned] doc for the measurements that put the cap here.
          PinnedHeaderSliver(
            child: ColoredBox(
              key: const ValueKey<String>('torch-shell-pinned'),
              color: skin.palette.ground,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * pinnedBandFraction,
                ),
                // A band that still does not fit scrolls inside its own cap
                // rather than clipping what it could not draw. The inner
                // scrollable takes a drag only when it actually has somewhere
                // to go — `ScrollPhysics.shouldAcceptUserOffset` is false when
                // min and max extent are equal — so on every screen where the
                // band fits, a drag on it still scrolls the shelf beneath.
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: band,
                ),
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

    // A Torchlight route has no Scaffold or Material above it, so without this
    // every Text inherits the framework's debug fallback — a red-on-yellow
    // double underline, merged into the skin's token styles because they all
    // inherit. It is not decoration a reader should ever see, and the census
    // counted it as light wherever it crossed a crimson or Oatmeal word.
    // Replacing (not merging) the ambient style gives the tokens a clean base.
    return _Ground(
      skin: skin,
      falloff: falloff,
      child: DefaultTextStyle(
        style: skin.text.body.style(color: skin.palette.ink1),
        child: Column(
          children: <Widget>[
            Expanded(child: body),
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
