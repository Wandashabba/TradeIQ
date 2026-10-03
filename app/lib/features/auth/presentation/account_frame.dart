import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import 'entry_frame.dart';
import 'entry_plate.dart';

/// The frame the account screens wear — forgot password, change password and
/// update the app (#400). One frame so the three are one kind of screen.
///
/// It lays out through [EntryFrame] rather than [TorchShell] directly, which
/// is what caps the column at a reading width and, on a viewport that is not
/// a phone, centres it and brings the commit row up to the foot of the form.
/// See that class for the two shapes and the thresholds between them.
///
/// **This frame is worn by a manager screen too** — `/users/:id/password`,
/// where a manager sets somebody else's password — so the cap reaches one
/// console route. It is invisible at every width the manager renders are
/// taken at, and at a browser width it is the same repair.
///
/// ## THE PLATE, AND WHY THESE SCREENS WERE NOT PLAIN BY CHOICE
///
/// > *"Lets fix the change password page, it's outdated from the app"* — the
/// > owner, 3 October 2026, with a screenshot of it.
///
/// This frame's doc said, until that report: *"These are deliberately plain:
/// a header, a column of words and fields, and the one action in the thumb
/// zone. Nothing here is designed beyond what the Torchlight kit already
/// decides."* That was an accurate description of the screens and it had
/// stopped being a defensible one, because #494 redesigned the fourth screen
/// on this same [EntryFrame] and left these three where they were. Side by
/// side, sign-in had a photographic plate, a display headline and an
/// amber-outlined commit, and these had a 96dp header row with a back arrow
/// in it, a `titleM` heading and a commit that was disabled on arrival. Not
/// two treatments of one product — two products.
///
/// So [onThePlate] screens open with [EntryPlate] instead of a
/// [TorchAppHeader], and the plate's three parts answer the three complaints
/// in turn:
///
/// | was | is |
/// |---|---|
/// | `TorchAppHeader(title:)`, `titleM`, 96dp before a word | the plate's `TorchDisplayHeadline`, on the picture |
/// | a bare back arrow on its own row | the arrow in the plate's top slot, beside the mark |
/// | a dead commit under "Enter your email first" | a live commit that validates on press |
///
/// **No copy was written or renamed for this.** [title] is the same string
/// that was the header's title and is now the plate's headline — "Change
/// password", "Reset your password", "Update TradeIQ", and the two done
/// states' own titles. The headline moved up a type role; it did not change
/// its words.
///
/// The one screen that keeps the header is the console guest: a manager
/// resetting somebody else's password is inside the console, under a
/// different shell, and a photograph of a trade route at first light is not
/// what that screen is about. It passes [onThePlate] false and is otherwise
/// untouched.
///
/// ## THE COMMIT IS LIVE FROM THE FIRST FRAME
///
/// [primaryArmed] is now `!sending` on the three auth screens rather than
/// "every field is filled", which is the convention sign-in landed on and
/// `entry_amber_census_test.dart` argues at length: a disabled button wearing
/// the route's one light is a lie, and a dead button that has already told
/// you off before you typed anything is worse than either. Press it empty and
/// it names what is missing, in the same `TorchBarNote` the disabled form
/// used to carry — but only once the person has actually pressed.
///
/// ## Which skin
///
/// Two of the three — `/forgot-password` and `/update-required` — are reached
/// with nobody signed in, so they wear the entry skin; `/account/password`
/// needs a session and stays on the agent skin. The frame does not choose:
/// each screen's own route wrapper does, and the tests pin both so a screen
/// reading the wrong provider is caught.
///
/// ## Amber, counted
///
/// Not a tab root and no nav, so Night has two content grants and Day has
/// one. The only claim is the primary. It is now granted on arrival rather
/// than once the form fills, so **an untouched form carries one object where
/// it carried none** — one in every skin, against a budget of two and one.
/// Nothing else on these screens asks: the plate's strip light is declared by
/// no route and draws its unlit 2px `ink1` form, exactly as on the door
/// (`entry_plate.dart` §2), and these screens have no "Forgot password?"
/// underline, so Night's second grant is never spent.
class AccountFrame extends StatelessWidget {
  const AccountFrame({
    super.key,
    required this.phase,
    required this.title,
    required this.children,
    required this.primary,
    required this.primaryArmed,
    this.onThePlate = false,
    this.reserve,
    this.back,
  }) : assert(
         !onThePlate || reserve != null,
         'A screen with a plate declares its own reserve. There is no sane '
         'default: the three differ by 89dp at 1.0x and by 228 at 2.0x, and '
         'lending one screen another one\'s number costs it its photograph '
         'on a short phone. See EntryPlateReserve.changePassword.',
       );

  /// The declared phase — `blocked`, `armed`, `sending`, `error`, `done`.
  final String phase;

  /// The screen's one name. The plate's headline when [onThePlate], the
  /// header's title otherwise, and the same string either way.
  final String title;

  final List<Widget> children;

  /// The thumb zone's one action.
  final Widget primary;

  /// Whether [primary] can be pressed. Decides the claim, so the light and the
  /// button can never disagree.
  final bool primaryArmed;

  /// Whether [title] is carried by an [EntryPlate] at the head of the column
  /// instead of by a [TorchAppHeader] above it.
  ///
  /// True on the three auth screens and false on the console guest. See the
  /// table above for what each one draws.
  final bool onThePlate;

  /// What this screen keeps on screen beside its plate — its own, measured,
  /// and required whenever [onThePlate]. Null on the console guest, which has
  /// no plate to budget.
  final EntryPlateReserve? reserve;

  final TorchIconButton? back;

  /// The id every account screen's primary claims under.
  static const String primaryClaimId = 'account-primary';

  /// A back button that names where it goes — never just "Back".
  static TorchIconButton backTo(String label, VoidCallback onPressed) =>
      TorchIconButton(
        icon: Icons.arrow_back,
        semanticLabel: label,
        onPressed: onPressed,
      );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return TorchScope(
      skin: skin,
      phase: phase,
      navRenders: false,
      tabbedRoute: false,
      claims: <TorchClaim>[
        if (primaryArmed) TorchPrimaryButton.claim(primaryClaimId),
      ],
      child: EntryFrame(
        header: onThePlate ? null : TorchAppHeader(title: title, back: back),
        primary: primary,
        children: <Widget>[
          if (onThePlate) ...<Widget>[
            EntryPlate(
              headline: title,
              // The arrow, in the slot the skin cycle used to have. No
              // `supporting`: see [EntryPlate.supporting] for why none of
              // these three has a second line to put on a picture.
              leading: back,
              reserve: reserve!,
            ),
            // The same gap the shell puts under a header and the door puts
            // under its plate. The plate replaced a header; the measurement
            // between it and the first thing under it did not change.
            SizedBox(height: skin.space.blockGap),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// A paragraph in the account screens' one voice.
class AccountText extends StatelessWidget {
  const AccountText(this.text, {super.key, this.muted = false});

  final String text;

  /// Secondary copy — the honest caveat under an outcome.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Text(
      text,
      style: (muted ? skin.text.meta : skin.text.body).style(
        color: muted ? skin.palette.ink3 : skin.palette.ink2,
      ),
    );
  }
}

/// A headline, announced as one.
///
/// **Not the screen's own name any more.** The three auth screens printed
/// their outcome through this and now print it through the plate's
/// [TorchDisplayHeadline], which is the role sign-in's headline has and the
/// role the owner's complaint was about. What is left for this is a heading
/// *inside* a column that already has a name at the top of it — the console
/// guest naming the person whose password is being reset.
class AccountHeadline extends StatelessWidget {
  const AccountHeadline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      header: true,
      child: Text(
        text,
        style: skin.text.titleM.style(color: skin.palette.ink1),
      ),
    );
  }
}
