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
    this.underPrimary,
    this.skinCycle,
    this.band,
    this.scrollController,
    this.pinned,
    this.bleedTop = false,
    this.backdrop = const <Decoration>[],
  }) : assert(
         !bleedTop || header == null,
         'A route with a header does not bleed its body to the top edge: the '
         'header IS the top edge. bleedTop exists for the one shape that has '
         'no header because its first child is the header — The Floor, whose '
         'plate runs full-bleed and carries the territory and the week in its '
         'own eyebrow.',
       ),
       assert(
         navPill == null || primary == null,
         'A tab root has no thumb zone and a screen with a primary commit '
         'action has no nav. The two bottom regions are alternatives, not '
         'layers — 64dp of nav plus 96dp of thumb zone plus a safe area is a '
         'quarter of a 640dp screen given to chrome.',
       ),
       assert(
         pinned == null || profile == TorchShellProfile.agent,
         'A pinned band fills itself with a flat palette.ground, which is the '
         'ground only on a profile with no falloff. The console paints its '
         'ground as a vertical gradient, and a flat fill over a gradient is a '
         'visible box — The Floor shipped exactly that on 30 September 2026 '
         'and the owner named it the next day. The one pinned band in the '
         'product is the stock counter summary, on the agent profile, where '
         'the flat fill is exact. A console route that wants one has to give '
         'the fill the SLICE of the falloff it covers: the band pins to the '
         'top of the viewport, which is y=0 in the shell itself, so the slice '
         'is [0, its height] of a gradient computed from the shell height — '
         'and the shell does not thread that height into its slivers today. '
         'Do that first, then delete this assert.',
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

  /// One quiet action directly under the commit, centred. Null everywhere but
  /// `/login`, so no existing bottom region moves. See [TorchThumbZone].
  final Widget? underPrimary;

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
  ///
  /// ## A band paints no backdrop, and must not be given one
  ///
  /// "Sibling, not an overlay" has a consequence that cost The Floor a defect
  /// the owner had to name. A band is **never** underneath the body, so the
  /// body cannot read through it: the scroll view clips to its own viewport,
  /// which ends where the band begins. Measured with a magenta body dragged
  /// under a band with no material at all, the count of body pixels inside
  /// the band's box is **zero** (`torch_shell_band_test.dart`).
  ///
  /// So the shell's own [_Ground] is the band's backdrop, and it is the only
  /// correct one: on the console that ground is a vertical falloff, so a band
  /// that fills itself with a flat `palette.ground` disagrees with the ground
  /// everywhere except the screen's last pixel row — and the shell pads the
  /// band by the gutter, so the disagreement is a rectangle inset 20dp with a
  /// hard edge. The Floor carried that fill from 30 September 2026 and the
  /// owner saw it: *"The background colour is messed up here please fix this
  /// to be seamless and not have this box blue there."* The measurements are
  /// on the band in `the_floor_screen.dart`.
  ///
  /// A band that wants a material of its own — a raised composer, say — has
  /// to be a shape *inside* the band's box with ground showing around it, not
  /// a fill of the box.
  final Widget? band;

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

  /// Drops the body's top padding so the first child starts at the top edge.
  ///
  /// Only legal on a route with no [header], and there is exactly one: The
  /// Floor, whose plate is its header. The shell's 24dp console inset is right
  /// for a body that begins with words and wrong for one that begins with a
  /// photograph — it left a 24dp band of ground above a plate the design says
  /// runs full-bleed to the top edge, which is 24dp of the fold spent on
  /// nothing and a plate that visibly is not the header it claims to be.
  final bool bleedTop;

  /// ── A ROUTE'S OWN AMBIENT WASH, OVER THE GROUND AND UNDER EVERYTHING ──
  ///
  /// Decorations painted full-bleed between the shell's [_Ground] and the
  /// shell's content, in **paint order**: `backdrop.first` goes down first and
  /// ends up at the bottom. Empty on every route but one, and an empty list
  /// paints nothing and adds no render object at all, so a route that does not
  /// ask for a wash renders exactly the pixels it did before this slot
  /// existed.
  ///
  /// **The one caller is The Floor's Dawn wash** (`floor_dawn.dart`), and the
  /// reason it is a slot *here* rather than a widget in the route's body is
  /// the band. `fix/band-seam` established that [band] paints no material of
  /// its own and relies on this ground showing through; the body above it is a
  /// scroll view that **clips to its own viewport**, which ends where the band
  /// begins. So a wash added inside [children] stops dead at the band's top
  /// edge — a hard horizontal seam, at the exact y the owner had just had a
  /// box removed from — and a wash added *behind* the shell is invisible,
  /// because the ground is opaque. The only layer that is continuous across
  /// the body, the band and the bottom region is the ground, and this is the
  /// slot immediately above it.
  ///
  /// **A backdrop is a wash, not a surface.** Every decoration here must be
  /// transparent enough to let the ground through at every pixel: an opaque
  /// one is the flat-fill-over-a-gradient defect again, one layer up, and the
  /// shell cannot assert its way out of that — a `Decoration`'s alpha is not
  /// inspectable. What it can do is keep the slot narrow: decorations, not a
  /// widget, so a backdrop cannot hit-test, cannot take a child, cannot size
  /// anything and cannot be a box.
  ///
  /// Cost: one `RenderDecoratedBox` per entry, each painting one `drawRect`
  /// into the call stream it is already in. No layer, no clip, no `saveLayer`.
  final List<Decoration> backdrop;

  /// The share of the screen a [pinned] band may take. unify §4's header rule,
  /// applied to the one other thing that holds a place at the top.
  static const double pinnedBandFraction = 0.4;

  /// ── THE SCRIM OVER THE BODY'S LAST 24dp, AND WHY IT IS NOT EVERYWHERE ──
  ///
  /// The [band] is a **sibling** of the scroll view, so nothing is ever drawn
  /// underneath it — `torch_shell_band_test.dart` counts zero body pixels
  /// inside the band's box and that is still true. The defect the owner
  /// photographed is therefore not an overlap: it is the scroll view's own
  /// **hard clip** at its viewport's bottom edge, which on a worklist falls
  /// through the middle of a sentence and reads as a printing fault. A
  /// `ListView` cuts its last partially-visible row at a pixel row, and 24dp
  /// above the chrome is where every console list does it.
  ///
  /// So the fade goes **over the body**, in the body's own last
  /// [TiqSpace.s6] — which is exactly the bottom padding every console body
  /// already carries, so **at rest the scrim lies entirely in that padding and
  /// washes no content at all**. It only ever has something to fade when
  /// something is mid-clip, which is the only moment it is for.
  ///
  /// ## It ends in the ground AT THAT y, never in `palette.ground`
  ///
  /// [torchGroundAt] is the whole of that sentence. The console paints its
  /// ground as a vertical falloff, so `palette.ground` is the ground only at
  /// the first and last pixel row of the screen; a scrim that faded to the
  /// token would be a 24dp box with a hard top edge, which is the defect
  /// `fix/band-seam` removed from this exact y. The scrim's opaque end is the
  /// one pixel row where it must match, and it is computed, not assumed.
  ///
  /// ## NOT ON A ROUTE WITH A [backdrop], and that is a real gap
  ///
  /// A wash makes the colour at that y unknowable. The Floor's Dawn is two
  /// radial ellipses centred 4% below the bottom edge — the clay layer peaks
  /// at alpha 0.30 **at the bottom of the screen**, which is precisely where
  /// this scrim would have to match it — and no linear gradient in a
  /// `BoxDecoration` reproduces a radial one. Masking the composite is what a
  /// `ShaderMask` is for and the paint budget does not have one.
  ///
  /// So the scrim is declined wherever a backdrop is painted, rather than
  /// shipped slightly wrong there. The route that loses it is The Floor, whose
  /// body is a plate, three one-line cards and a chip row — a screen designed
  /// to fit the fold and the one console route whose content does not run
  /// under the chrome. Measured, not assumed: see `one_bar_scrim_test.dart`.
  static const double bandScrimExtent = TiqSpace.s6;

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

    final bottom = _bottomRegion(context, skin: skin, showNav: showNav);

    // THE TOP INSET, AND THE SYSTEM BAR — 30 September 2026.
    //
    // `bleedTop` still means y=0: that shape exists so a plate can run under
    // the status bar, and it still does. Everything else clears it.
    //
    // This was a bare token, and it was wrong on every device the whole time.
    // Widget tests and browsers both report `padding.top == 0`, so the entire
    // design — every golden, every look render, every measurement in this
    // repository — was made on a surface with no system bar. The defect is
    // invisible in all of them and visible the moment the app is installed:
    // the owner's phone put a title behind the clock. A screen whose top inset
    // is a design token rather than the device's own is a screen designed for
    // the simulator.
    //
    // The 26-render manager proof stays byte-identical through this change,
    // for exactly the reason the bug survived: those renders have no inset to
    // add. That is the proof's blind spot, not its endorsement.
    final top =
        (bleedTop
            ? 0.0
            : profile == TorchShellProfile.console
            ? TiqSpace.s6
            : TiqSpace.s4) +
        (bleedTop ? 0.0 : MediaQuery.paddingOf(context).top);
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
          // Sized by its child so the band is as tall as its words at 2.0×
          // rather than a token height that clips them — and capped at 40% of
          // the screen so those words never take the screen instead. See the
          // [pinned] doc for the measurements that put the cap here.
          // THE FLAT FILL IS EXACT HERE, AND ONLY HERE. A pinned band really
          // does overlay scrolling slivers, so unlike [band] it has to be
          // opaque. `palette.ground` is the ground only while the profile has
          // no falloff, which is the constructor's assert: every pinned band
          // in the product is on the agent profile. It is full-bleed, which is
          // the other half — the gutter padding is INSIDE the fill, not around
          // it, so there is no vertical seam to have.
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
                  child: pinnedBand,
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
    // Two stops band on a 6-bit panel. A route that wants an actual wash gets
    // one from [backdrop], which goes immediately over this and under the
    // content — not into this gradient, which every route shares.
    final falloff = profile == TorchShellProfile.console;

    final keyboard = media.viewInsets.bottom;

    // The route's own text style, beneath everything. A Torchlight route has
    // no Scaffold or Material above it, and without this every Text inherits
    // the framework's debug fallback — a red-on-yellow double underline,
    // merged into the skin's token styles because they all inherit, and
    // counted by the census as light wherever it crossed a crimson or Oatmeal
    // word. A role style names its face, size and ink, never its decoration,
    // so replacing (not merging) the ambient style is what gives the tokens a
    // clean base.
    // See [bandScrimExtent] for both halves of this condition.
    final wantsScrim = band != null && backdrop.isEmpty;

    Widget column(double shellHeight) => Column(
      children: <Widget>[
        Expanded(
          child: !wantsScrim
              ? body
              : LayoutBuilder(
                  // The body's own height, which is where its clip is: the
                  // Column's first child starts at y=0 of the shell, so the
                  // body's bottom edge IS this constraint.
                  builder: (context, bodyConstraints) {
                    final into = torchGroundAt(
                      skin,
                      falloff: falloff,
                      height: shellHeight,
                      y: bodyConstraints.maxHeight,
                    );
                    return Stack(
                      children: <Widget>[
                        body,
                        // A fade, not a surface: no hit-testing, no layer, one
                        // `drawRect` with a two-stop shader. It is inside the
                        // body's box so it is full-bleed to both gutters — the
                        // clip it hides runs the whole width.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: bandScrimExtent,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: const ValueKey<String>('torch-band-scrim'),
                              decoration: BoxDecoration(
                                // THREE STOPS, AND THE THIRD IS WHY. A
                                // two-stop ramp reaches full opacity only at
                                // its very last pixel row, so the clip line
                                // itself — the thing being hidden — still
                                // shows through at a few percent. Measured on
                                // Day with a flat magenta body dragged under
                                // the bar, the row half a dp inside the
                                // scrim's bottom edge read 5 levels of green
                                // off the ground, which is inside the step
                                // the owner named on the band.
                                //
                                // So the fade finishes at 85% and the last
                                // [bandScrimExtent] * 0.15 — 3.6dp — is
                                // opaque ground. The cut is covered, not
                                // nearly covered. Still one `drawRect`.
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[
                                    into.withValues(alpha: 0),
                                    into,
                                    into,
                                  ],
                                  stops: const <double>[0, 0.85, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
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
    );

    return DefaultTextStyle(
      style: skin.text.body.style(color: skin.palette.ink1),
      child: _Ground(
        skin: skin,
        falloff: falloff,
        backdrop: backdrop,
        // The extra `LayoutBuilder` is taken ONLY when there is a scrim to
        // colour, so a route without a band renders the same tree it did
        // before this slot existed. `_Ground`'s own box passes its constraints
        // straight through, so this maxHeight is the same height the falloff
        // gradient was computed from — which is what makes [torchGroundAt]
        // exact rather than approximately right.
        child: !wantsScrim
            ? column(media.size.height)
            : LayoutBuilder(
                builder: (context, shellConstraints) => column(
                  shellConstraints.maxHeight.isFinite
                      ? shellConstraints.maxHeight
                      : media.size.height,
                ),
              ),
      ),
    );
  }

  Widget? _bottomRegion(
    BuildContext context, {
    required TiqSkin skin,
    required bool showNav,
  }) {
    if (showNav) {
      final pill = navPill!;
      final circle = navCircle;
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
      underPrimary: underPrimary,
    );
  }
}

/// THE FALLOFF'S RAMP, as a share of the shell's height.
///
/// `96 / height` is the ramp [_Ground] draws at each end, and 0.25 is what it
/// degrades to on a viewport short enough that two 96dp ramps would meet. It
/// is a function so [torchGroundAt] and the gradient itself cannot drift: a
/// layer that has to END in the ground has to be computed from the same number
/// the ground was.
double _falloffBand(double height) => height <= 400 ? 0.25 : 96 / height;

/// THE SHELL'S GROUND COLOUR AT ONE y.
///
/// `palette.ground` is the ground at the **first and last pixel row** of a
/// console screen and nowhere in between: [_Ground] paints the letterbox
/// falloff as `ground → vignette → vignette → ground`. Anything that has to
/// fade *into* the ground somewhere else — [TorchShell.bandScrimExtent] is the
/// only caller today — has to ask which colour that is.
///
/// This is the generalisation of a defect that shipped. The Floor's band
/// carried a flat `ColoredBox(palette.ground)` from 30 September 2026 and the
/// owner named it the next day: *"The background colour is messed up here
/// please fix this to be seamless and not have this box blue there."* The
/// measured step at the band's own y was **4, 6 and 9 levels** on Night and
/// 8, 9 and 11 on Day. A constant was the wrong tool; this is the right one.
///
/// Returns `palette.ground` unchanged on a profile with no falloff (the agent
/// phone), where the token really is the ground at every y.
Color torchGroundAt(
  TiqSkin skin, {
  required bool falloff,
  required double height,
  required double y,
}) {
  final p = skin.palette;
  if (!falloff || !height.isFinite || height <= 0) return p.ground;
  final band = _falloffBand(height);
  final t = (y / height).clamp(0.0, 1.0);
  if (t <= band) return Color.lerp(p.ground, p.vignette, t / band)!;
  if (t >= 1 - band) {
    return Color.lerp(p.vignette, p.ground, (t - (1 - band)) / band)!;
  }
  return p.vignette;
}

class _Ground extends StatelessWidget {
  const _Ground({
    required this.skin,
    required this.falloff,
    required this.child,
    this.backdrop = const <Decoration>[],
  });

  final TiqSkin skin;
  final bool falloff;

  /// See [TorchShell.backdrop]. Nested here rather than stacked: the ground is
  /// the one full-bleed layer the band, the body and the bottom region all
  /// share, so a wash belongs between it and them.
  final List<Decoration> backdrop;

  final Widget child;

  /// The route's wash, folded onto [child] in paint order. `backdrop.first` is
  /// the outermost box and therefore the first to paint — a
  /// `RenderDecoratedBox` draws its decoration and then its child, so
  /// outside-in is bottom-up.
  Widget _washed() {
    var body = child;
    for (final decoration in backdrop.reversed) {
      body = DecoratedBox(decoration: decoration, child: body);
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final body = _washed();
    if (!falloff) {
      return ColoredBox(color: skin.palette.ground, child: body);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final band = _falloffBand(height);
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
          child: body,
        );
      },
    );
  }
}
