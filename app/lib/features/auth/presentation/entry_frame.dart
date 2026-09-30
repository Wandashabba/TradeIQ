import 'package:flutter/widgets.dart';

import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';

/// THE WAY IN, AT EVERY WIDTH — the one frame `/login`, `/forgot-password`,
/// `/account/password` and `/update-required` are laid out by.
///
/// > *"Thats not good please fix spacing"* — the owner, 30 September 2026,
/// > looking at the redesigned sign-in screen in a desktop browser.
///
/// #494 redesigned these screens and was rendered at 390×844 and 360×640 and
/// nowhere else. At 1280dp the same screen has four defects and they are one
/// defect: **nothing in the product caps a width.** The two fields ran
/// 1240dp — `TorchShell`'s agent profile spends a flat 20dp gutter at every
/// width and never even reaches `TiqSpace.gutterFor` — the mark sat on the
/// top edge, two thirds of the viewport was empty ground, and the commit bar
/// was pinned to the bottom edge hundreds of pixels from the form it commits.
///
/// ## Two shapes, and the viewport chooses
///
/// **The phone screen.** Below [pageMinWidth] or [pageMinHeight] this is
/// `TorchShell` exactly as #494 shipped it: the body scrolls, the commit bar
/// is a [TorchThumbZone] pinned at the bottom edge, and the skin cycle is at
/// its leading end. That bar is in the thumb zone, which is the whole of why
/// it is there, and **at 360×640 the form already runs past the fold** — the
/// "Forgot password?" link is clipped by the bar in the render #494 shipped.
/// There is not one spare pixel on that screen to spend on top padding or on
/// centring, and nothing below the thresholds moves.
///
/// **The page.** At or above both thresholds the screen becomes a page: one
/// column, capped at [TiqSpace.readingWidth], centred horizontally **and
/// vertically**, with the header (where there is one) at the top of that
/// column and the commit row at the foot of it. The shell renders no bottom
/// region at all.
///
/// ### Why the commit bar joins the column instead of staying pinned
///
/// A thumb zone is an argument about a hand, not about a screen: the bottom
/// edge is where the thumb rests on a device that is *held*. A desktop
/// browser is not held, and on a 1280×1800 window the argument inverts — the
/// bar is not in reach of anything, it is 1200dp below the password field,
/// and the sentence that says *why* it is disabled ("Email is required") is
/// that far from the field that is empty. So above the thresholds the same
/// row — skin cycle, 12dp, primary — moves to the foot of the column it
/// belongs to. **The composition does not change; its address does.** The
/// skin cycle stays beside the button for the same reason it is there on a
/// phone: it is the control that gets somebody out of a skin they cannot
/// read, and the way in is the one screen a person can be stuck on before
/// they have an account to remember a preference against.
///
/// It keeps the thumb zone's gap ([TiqSpace.s3]) and loses the zone's
/// hairline rule and its 20dp inset: a rule inside a column is a section
/// divider, and the column already has a gutter. The separation is
/// `blockGap`, which is what separates two blocks everywhere else.
///
/// ### Why vertical centring, and why only here
///
/// The dead band the owner is pointing at is not fixed by moving the bar —
/// that only moves the emptiness below the button instead of above it. A
/// short form on a tall page is centred; that is what every sign-in page on
/// the web does, and it is the only arrangement in which *the screen is the
/// form* rather than a strip of content with a lot of ground under it.
///
/// It is not applied below the thresholds because there it would be a
/// regression, not a fix: on 390×844 the form is about 500dp in a 750dp body,
/// so centring would push the mark ~120dp down the screen and take the
/// bottom of the form further under the bar. #494's phone layout is good and
/// nobody has complained about it.
///
/// ### The two thresholds
///
/// [pageMinWidth] is derived: `readingWidth + 2 × gutterWide`, the narrowest
/// viewport that holds the column with the wide gutter on both sides. There
/// is no separate number to keep in step.
///
/// [pageMinHeight] is not derived and cannot be, because it is a claim about
/// a viewport being taller than its content. **A phone in landscape is wide
/// and is still a phone** — 852×393 clears the width test and a commit bar
/// at the end of a scroll there is strictly worse than one pinned in reach.
/// The sign-in column measures about 500dp at 1.0× and its commit row about
/// 70dp; under 900dp of viewport the two are more than two thirds of the
/// screen, the bar reads as the foot of the form, and pinning it is still
/// right. Over it, the bar is marooned — which is the complaint.
///
/// **Amber: none.** This frame is a layout and paints nothing. The route's
/// claims are unchanged by which shape it is in: the primary is the same
/// widget, declared the same way, in both.
class EntryFrame extends StatelessWidget {
  const EntryFrame({
    super.key,
    required this.children,
    required this.primary,
    required this.skinCycle,
    this.header,
  });

  /// The body. Block gaps are the caller's, as they are for [TorchShell].
  final List<Widget> children;

  /// The route's one commit action.
  final Widget primary;

  /// The skin cycle wired to the provider this route's wrapper watches.
  final Widget skinCycle;

  /// A [TorchAppHeader], or nothing on a route that has no title. `/login`
  /// has none by §1.27's ruling; the three account screens have one.
  final Widget? header;

  /// The viewport height at or above which the way in becomes a page. See
  /// the note on landscape phones above.
  static const double pageMinHeight = 900;

  /// The narrowest viewport that holds the reading column with a wide gutter
  /// on both sides.
  static double pageMinWidth(TiqSkin skin) =>
      TiqSpace.readingWidth + 2 * skin.space.gutterWide;

  /// Whether a viewport of this size gets the page shape rather than the
  /// phone shape. Exposed so the tests can state the rule rather than
  /// rediscover it from two numbers.
  static bool isPage(TiqSkin skin, Size size) =>
      size.width >= pageMinWidth(skin) && size.height >= pageMinHeight;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        if (!isPage(skin, size)) {
          // The phone shape, unchanged. The column is only wrapped when the
          // cap would actually bite, so at 390 and 360 the tree beneath the
          // shell is the one #494 shipped — a lazy `ListView` of the screen's
          // own children, and not one eagerly built child holding a Column.
          final capped =
              size.width - 2 * skin.space.gutter > TiqSpace.readingWidth;
          return TorchShell(
            profile: TorchShellProfile.agent,
            header: header,
            skinCycle: skinCycle,
            primary: primary,
            children: capped
                ? <Widget>[_ReadingColumn(children: children)]
                : children,
          );
        }

        // The page shape. The shell renders no bottom region, so the body is
        // everything the shell has minus the safe area — and the free height
        // inside it is that minus the shell's own body padding, which is
        // restated here because capping a width in `TorchShell` would change
        // screens on the manager and agent sides that the owner has already
        // approved. Being a few dp out costs a few dp of centring and
        // nothing else.
        final free =
            constraints.maxHeight -
            safeBottom -
            TiqSpace.s4 - // TorchShell's agent-profile top inset
            skin.space.blockGap; // and its body's bottom padding

        return TorchShell(
          profile: TorchShellProfile.agent,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: free < 0 ? 0 : free),
              child: _ReadingColumn(
                children: <Widget>[
                  if (header != null) ...<Widget>[
                    header!,
                    // The same 24dp the shell puts under a header, and no
                    // divider, for the same reason.
                    const SizedBox(height: TiqSpace.s6),
                  ],
                  ...children,
                  SizedBox(height: skin.space.blockGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      skinCycle,
                      const SizedBox(width: TiqSpace.s3),
                      Expanded(child: primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One column of prose and the controls that belong to it, capped at
/// [TiqSpace.readingWidth] and centred in whatever it is given.
///
/// Both axes come from the one [Center]: it shrink-wraps the axis whose
/// constraint is unbounded, so its height is `max(minHeight, the column)` —
/// the column is centred on a viewport it does not fill and top-aligned and
/// scrolling on one it overflows, with no branch to get wrong.
class _ReadingColumn extends StatelessWidget {
  const _ReadingColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: TiqSpace.readingWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    ),
  );
}
