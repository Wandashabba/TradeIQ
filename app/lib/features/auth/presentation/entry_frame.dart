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
/// `TorchShell` exactly as #494 shipped it: the body scrolls and the commit
/// bar is a [TorchThumbZone] pinned at the bottom edge. That bar is in the
/// thumb zone, which is the whole of why it is there, and **at 360×640 the
/// form already runs past the fold** — the "Forgot password?" link is clipped
/// by the bar in the render #494 shipped. There is not one spare pixel on
/// that screen to spend on top padding or on centring, and nothing below the
/// thresholds moves.
///
/// That sentence has been read as a fold budget for the whole form and it is
/// not one. **The commit bar is a sibling of the scroll view, not a row in
/// it**, so a form that runs long runs long *above* a bar that is still on
/// the bottom edge — the button cannot be pushed off a short screen by
/// anything in the column. `entry_plate.dart` §3 is the long version, and it
/// is the reason the three screens with more fields than sign-in carry the
/// same plate: what the fold actually constrains is how much has to be
/// visible *beside* the picture, which is [EntryPlateReserve].
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
/// that far from the field that is empty. So above the thresholds the commit
/// moves to the foot of the column it belongs to. **The composition does not
/// change; its address does.**
///
/// It loses the zone's hairline rule and its 20dp inset: a rule inside a
/// column is a section divider, and the column already has a gutter. The
/// separation is `blockGap`, which is what separates two blocks everywhere
/// else.
///
/// ### The skin cycle is gone from this frame, on all four routes
///
/// > *"That change of theme on the sign in we can remove it. Let's only make
/// > the change of theme only on settings."* — the owner, 1 October 2026.
///
/// This frame used to carry a `skinCycle` at the leading end of the commit
/// row — pinned on a phone, at the foot of the column on a page — and the
/// argument written here for it was that the way in is the one screen a
/// person can be stuck on before they have an account to remember a
/// preference against. The owner overruled it. It came off `/login` the same
/// day and off the other three on 3 October 2026, and the slot came off the
/// frame with them so that the next screen to wear this frame cannot quietly
/// get one back.
///
/// The standing rule it supersedes — never a screen without the cycle — was
/// written so the control could not become unreachable.
///
/// **That rule is now dead everywhere, not only here.** This paragraph read
/// *"it stays true where it was aimed: behind the door the cycle is on
/// nineteen screens"*, and on 4 October 2026 the owner asked a third time,
/// with a screenshot: *"Please remove the theme button on this page and
/// everywhere else please. everywhere on the app. I need it only on settings
/// and no where else"*. Behind the door the cycle is now on **no** screens.
/// The agent's control is the `THIS APP` row on Me; the manager's is the menu
/// sheet's `THIS APP` section.
///
/// So the cost this note recorded for `/update-required` — a gate with no way
/// to the control, because the button clears the flag and goes home — is now
/// the cost on every route that is not Me or the menu sheet. Nothing on those
/// screens is unreadable: each renders in the skin the phone was already in,
/// and the skin is only ever changed deliberately, from the one place that
/// changes it.
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
/// and is still a phone** — 852×393 clears the width test, and a commit bar
/// at the end of a scroll there is strictly worse than one pinned in reach.
/// The sign-in column measures **656dp** from the top of its plate to the
/// foot of its commit action at 1.0× (printed by `entry_width_test.dart`).
/// Under 900dp of viewport that column is most of the screen, a bar on the
/// bottom edge still reads as the foot of the form, and pinning it is right.
/// Over it, the bar is marooned — which is the complaint.
///
/// This said 566 and from the top of the *headline*, which was two errors in
/// one line: the plate is above the headline, and 566 was never a column
/// height — it was `EntryPlate`'s reserve, which had itself been measured off
/// the pinned bar below. A number that travels between two files without
/// either one owning it is the number that is wrong in both. The measurement
/// is printed by the test named above and by nothing else.
///
/// **Amber: none.** This frame is a layout and paints nothing. The route's
/// claims are unchanged by which shape it is in: the primary is the same
/// widget, declared the same way, in both.
class EntryFrame extends StatelessWidget {
  const EntryFrame({
    super.key,
    required this.children,
    required this.primary,
    this.underPrimary,
    this.header,
    this.aside,
  });

  /// The body. Block gaps are the caller's, as they are for [TorchShell].
  final List<Widget> children;

  /// The route's one commit action.
  final Widget primary;

  /// One quiet action directly under the commit, centred.
  ///
  /// The mockup the owner approved puts "Forgot password?" here and nowhere
  /// else: *"look at the Sign in and forgot password on this image and do
  /// exactly that"*, 30 September 2026. It had been left-aligned in the middle
  /// of the form, above the fields' own checkboxes, where it read as another
  /// form control rather than as the way out of the form.
  ///
  /// It sits **below** the commit on purpose. A person reaches for the button
  /// first; the escape hatch is what they look for only once the button has
  /// not worked for them, and that is the order the screen now reads in.
  final Widget? underPrimary;

  /// A [TorchAppHeader], or nothing on a route that has no title. `/login`
  /// has none by §1.27's ruling; the three account screens have one.
  final Widget? header;

  /// A full-height pane to the right of the frame, on a desk only.
  ///
  /// Null everywhere but `/login`, where it is the picture. **The caller
  /// decides when**, not this frame: `isPage` above is a reading-column rule
  /// and answers true on a tablet, while a side pane wants the desk rule
  /// (`ConsoleDesk.isDesk`) — the same threshold the console splits at. Two
  /// different questions, so the one that is not this widget's stays outside
  /// it, and the caller passes null until its own answer is yes.
  ///
  /// Everything below is untouched when it is null, which is every phone, and
  /// every other entry route at every size.
  final Widget? aside;

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
    final aside = this.aside;
    if (aside == null) return _frame(context);

    // 3 : 2. The form keeps the larger share because it is the work and it has
    // a reading column to hold; the picture takes the rest rather than a fixed
    // width, so it grows with the window instead of stranding the form in the
    // middle of it — which is the whole complaint this replaces.
    //
    // `stretch` so the picture is full-bleed top to bottom. It is the one
    // object on this screen that should touch three edges.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: 3, child: _frame(context)),
        Expanded(flex: 2, child: aside),
      ],
    );
  }

  Widget _frame(BuildContext context) {
    final skin = context.skin;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // An unbounded height is not a tall viewport, it is no viewport: the
        // page shape centres against a free height and there is none to
        // measure. Nothing in the app puts this frame in an unbounded box
        // today; the guard is here so that if something ever does, the way in
        // degrades to the phone shape rather than to an infinite constraint.
        if (!constraints.hasBoundedHeight || !isPage(skin, size)) {
          // The phone shape, unchanged. The column is only wrapped when the
          // cap would actually bite, so at 390 and 360 the tree beneath the
          // shell is the one #494 shipped — a lazy `ListView` of the screen's
          // own children, and not one eagerly built child holding a Column.
          final capped =
              size.width - 2 * skin.space.gutter > TiqSpace.readingWidth;
          return TorchShell(
            profile: TorchShellProfile.agent,
            header: header,
            primary: primary,
            underPrimary: underPrimary,
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
                  primary,
                  if (underPrimary != null) ...<Widget>[
                    SizedBox(height: skin.space.intraBlock),
                    Center(child: underPrimary),
                  ],
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
