import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';

/// The frame the account screens wear — forgot password, change password and
/// update the app (#400). One frame so the three are one kind of screen.
///
/// These are deliberately plain: a header, a column of words and fields, and
/// the one action in the thumb zone. Nothing here is designed beyond what the
/// Torchlight kit already decides.
///
/// ## Which skin, and whose cycle
///
/// The three are not all the same kind of screen in this one respect, so
/// [skinCycle] is **required** rather than defaulted. Two of them —
/// `/forgot-password` and `/update-required` — are reached with nobody signed
/// in, so they wear the entry skin and carry [EntrySkinCycle]; a default here
/// is how the wrong one got onto them in the first place. `/account/password`
/// needs a session and stays on the agent skin with [AgentSkinCycle].
///
/// The rule the cycle has to obey: **the control and the ground must read the
/// same provider.** A cycle wired to a provider the enclosing route does not
/// watch still moves and still repaints nothing, which is the worst of both —
/// the person taps Veld, the screen stays Night, and the setting silently
/// lands on a skin they are not looking at.
///
/// ## Amber, counted
///
/// Not a tab root and no nav, so Night has two content grants and Day and Veld
/// have one. The only claim is the primary, and it is declared **only while
/// the primary is armed** — a disabled primary declares nothing, so a form
/// with an empty field carries zero amber, and a filled one carries exactly
/// one in every skin.
class AccountFrame extends StatelessWidget {
  const AccountFrame({
    super.key,
    required this.phase,
    required this.title,
    required this.children,
    required this.primary,
    required this.primaryArmed,
    required this.skinCycle,
    this.back,
  });

  /// The declared phase — `blocked`, `armed`, `sending`, `error`, `done`.
  final String phase;
  final String title;
  final List<Widget> children;

  /// The thumb zone's one action.
  final Widget primary;

  /// Whether [primary] can be pressed. Decides the claim, so the light and the
  /// button can never disagree.
  final bool primaryArmed;

  /// The skin cycle for the leading end of the thumb zone — the one wired to
  /// the same provider this screen's route wrapper watches.
  final Widget skinCycle;

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
      child: TorchShell(
        profile: TorchShellProfile.agent,
        header: TorchAppHeader(title: title, back: back),
        // Not a tab root: the cycle sits at the leading end of the thumb zone.
        // Never a screen without it — someone locked out of their account is
        // exactly the person who cannot afford an unreadable screen.
        skinCycle: skinCycle,
        primary: primary,
        children: children,
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
