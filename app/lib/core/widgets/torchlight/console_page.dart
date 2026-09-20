import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../design/torch_scope.dart';
import '../../theme/torchlight/tiq_skin.dart';
import 'button/buttons.dart';
import 'chrome/chrome.dart';
import 'sheet.dart';
import 'skin_controls.dart';

/// THE CONSOLE'S FRAME FOR A ROUTE THAT IS NOT A TAB ROOT.
///
/// [ConsoleFrame] is the tab root's frame: it carries the nav pill, so Night's
/// first amber grant is spent on the active tab before the content asks for
/// anything. A pushed console screen — a form, a preview, a run history — has
/// no nav, which changes three things at once and is why it needs its own
/// frame rather than a flag on the other one:
///
/// * **The bottom region is different.** A screen with a commit action gets a
///   [TorchThumbZone]; a screen with none gets the 76dp zone holding the skin
///   cycle alone. Never a screen without the cycle.
/// * **The amber arithmetic is different.** Untabbed, so Night has **two**
///   content grants rather than one, and Day and Veld still have exactly one.
/// * **There is a way back**, and it names where it goes.
///
/// ## The claim is declared only while the primary is armed
///
/// [primaryArmed] decides the claim, not the button. A disabled primary
/// declares nothing, so a form with an empty required field carries **zero**
/// amber in every skin and a fillable one carries exactly one. The light and
/// the button can never disagree, because they are the same boolean.
class ConsolePage extends StatelessWidget {
  const ConsolePage({
    super.key,
    required this.phase,
    required this.title,
    required this.children,
    this.facts = const <String>[],
    this.back,
    this.primary,
    this.primaryArmed = false,
    this.secondary,
    this.scrollController,
  }) : assert(
         primary == null || primaryArmed == true || primaryArmed == false,
         'primaryArmed is required reading whenever there is a primary.',
       );

  /// The declared phase — `loading`, `loaded`, `empty`, `error`, `armed`,
  /// `blocked`, `saving`. Resolved once per route × phase, never per frame.
  final String phase;

  final String title;

  /// The header's capped subtitle facts, joined by middots on screen and read
  /// as one sentence.
  final List<String> facts;

  final List<Widget> children;

  /// A back button that names its destination — never just "Back".
  final TorchIconButton? back;

  /// The route's one commit action, in the thumb zone.
  final Widget? primary;

  /// Whether [primary] can be pressed. See the class comment.
  final bool primaryArmed;

  /// A ghost alternative, above the primary.
  final Widget? secondary;

  final ScrollController? scrollController;

  /// The id every console page's primary claims under.
  static const String primaryClaimId = 'console-page-primary';

  /// A back button that names where it goes.
  static TorchIconButton backTo(String label, VoidCallback onPressed) =>
      TorchIconButton(
        icon: Icons.arrow_back,
        semanticLabel: label,
        onPressed: onPressed,
      );

  @override
  Widget build(BuildContext context) {
    return TorchSheetAware(
      builder: (context, beneathSheet) => TorchScope(
        skin: context.skin,
        phase: phase,
        navRenders: false,
        tabbedRoute: false,
        beneathSheet: beneathSheet,
        claims: <TorchClaim>[
          if (primary != null && primaryArmed)
            TorchPrimaryButton.claim(primaryClaimId),
        ],
        child: TorchShell(
          profile: TorchShellProfile.console,
          header: TorchAppHeader(title: title, facts: facts, back: back),
          scrollController: scrollController,
          // Not a tab root, so the cycle is at the leading end of the bottom
          // region rather than in the header's single trailing slot.
          skinCycle: const AgentSkinCycle(),
          primary: primary,
          secondary: secondary,
          children: children,
        ),
      ),
    );
  }
}
