import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../design/torch_scope.dart';
import '../../theme/torchlight/tiq_skin.dart';
import 'button/buttons.dart';
import 'chrome/chrome.dart';
import 'sheet.dart';

/// THE CONSOLE'S FRAME FOR A ROUTE THAT IS NOT A TAB ROOT.
///
/// [ConsoleFrame] is the tab root's frame: it carries the nav pill, so Night's
/// first amber grant is spent on the active tab before the content asks for
/// anything. A pushed console screen — a form, a preview, a run history — has
/// no nav, which changes three things at once and is why it needs its own
/// frame rather than a flag on the other one:
///
/// * **The bottom region is different.** A screen with a commit action gets a
///   [TorchThumbZone]; a screen with none now gets **no bottom region at
///   all** — see below.
/// * **The amber arithmetic is different.** Untabbed, so Night has **two**
///   content grants rather than one, and Day still has exactly one.
/// * **There is a way back**, and it names where it goes.
///
/// ## THE THEME CONTROL IS OFF THIS FRAME
///
/// The bullet above used to end *"a screen with none gets the 76dp zone
/// holding the skin cycle alone. Never a screen without the cycle."* It is
/// now never a screen *with* one. On 1 October 2026 and again on 3 October the
/// owner said the theme control belongs in settings and nowhere else; #515
/// took it off [EntryFrame] for the four auth routes and this is the same
/// removal on the console's four. Nothing is lost — the control lives in the
/// menu sheet's "This app" section.
///
/// It was also wired wrong, which is worth recording rather than quietly
/// fixing. The cycle here was an `AgentSkinCycle`, so it wrote
/// `agentSkinProvider`; none of the four routes that use this frame wraps
/// itself in `TorchlightRoute`, so none of them *watches* that provider.
/// `account_frame.dart` names this exact failure in its own history — *"the
/// control and the ground must read the same provider. A cycle wired to a
/// provider the enclosing route does not watch still moves and still repaints
/// nothing"* — and this frame was the surviving instance of it.
///
/// A consequence, stated: `report_run_history_screen` has no primary, so it
/// had the 76dp zone for the cycle's sake alone and now has no bottom region.
/// The three form screens keep theirs, because they keep their commit.
///
/// ## The claim is declared while the primary can be pressed
///
/// [primaryArmed] decides the claim, not the button, and since this frame
/// joined the house pattern it means **"pressable"** rather than "every
/// required field is filled". A form on arrival therefore carries exactly one
/// amber object instead of zero, and names what is missing when the reader
/// presses rather than before they have typed. The light and the button can
/// never disagree, because they are still the same boolean.
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
          primary: primary,
          secondary: secondary,
          children: children,
        ),
      ),
    );
  }
}
