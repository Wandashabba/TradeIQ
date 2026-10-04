import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../theme/torchlight/agent_skin.dart';
import '../../theme/torchlight/tiq_skin.dart';
import 'chrome/chrome.dart';

/// A skin's name in the agent's language.
String skinName(AppLocalizations l10n, SkinMode mode) => switch (mode) {
  SkinMode.night => l10n.skinNight,
  SkinMode.day || SkinMode.auto => l10n.skinDay,
};

/// The label that names the **next** state, never this one. A toggle that
/// announces where it is and not where it goes makes a blind user press it to
/// find out.
String skinCycleLabel(AppLocalizations l10n, SkinMode mode) =>
    l10n.skinCycleLabel(
      skinName(l10n, mode),
      skinName(l10n, TorchSkinCycle.next(mode)),
    );

/// The skin cycle at the leading end of a thumb zone.
///
/// ## NOTHING BUILDS ONE — 4 October 2026
///
/// This read *"every agent screen that is not a tab root"*, and that was true
/// of six call sites until the owner's third ask settled it: *"Please remove
/// the theme button on this page and everywhere else please. everywhere on the
/// app. I need it only on settings and no where else"*. The agent's theme
/// control is the `THIS APP` row on Me (`my_record_screen.dart`) and nothing
/// else; the manager's is the menu sheet's `THIS APP` section.
///
/// The class is kept with no caller on purpose. `account_screens_test` and the
/// agent goldens assert `find.byType(AgentSkinCycle)` finds **nothing**, and a
/// `findsNothing` on a type that does not exist is a test that cannot fail.
/// Deleting this would quietly delete the guard that it does not come back.
///
/// The header form that sat beside it — `skinCycleIconButton`, a
/// `TorchIconButton` for `TorchAppHeader.trailing` — is **gone**. It lost its
/// last caller when the control left the four tab-root title rows, no test
/// named it, and a helper whose whole purpose is to put the theme control in a
/// screen header is not a thing to leave lying around after three asks.
class AgentSkinCycle extends ConsumerWidget {
  const AgentSkinCycle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(agentSkinProvider);
    return TorchSkinCycle(
      mode: mode,
      semanticLabel: skinCycleLabel(context.l10n, mode),
      onChanged: (next) => ref.read(agentSkinProvider.notifier).set(next),
    );
  }
}
