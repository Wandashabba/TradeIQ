import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../theme/torchlight/agent_skin.dart';
import '../../theme/torchlight/tiq_skin.dart';
import 'button/buttons.dart';
import 'chrome/chrome.dart';

/// A skin's name in the agent's language.
String skinName(AppLocalizations l10n, SkinMode mode) => switch (mode) {
  SkinMode.veld => l10n.skinVeld,
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

/// The skin cycle at the leading end of a thumb zone — every agent screen
/// that is not a tab root.
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

/// The same control in the app header's single trailing slot — unify §1.2's
/// placement on a tab root, where the floating nav row has no 56dp to spare.
///
/// Same three glyphs, same cycle, same "name the next state" rule; a
/// different 48dp box.
///
/// A function and not a widget, because [TorchAppHeader.trailing] is **typed**
/// as a `TorchIconButton`: the rule is *exactly one* trailing icon button, and
/// the type is how the chrome enforces it. A `ConsumerWidget` wrapper would
/// satisfy the reader and not the compiler.
TorchIconButton skinCycleIconButton(BuildContext context, WidgetRef ref) {
  final mode = ref.watch(agentSkinProvider);
  final next = TorchSkinCycle.next(mode);
  return TorchIconButton(
    icon: TorchSkinCycle.glyphFor(mode),
    semanticLabel: skinCycleLabel(context.l10n, mode),
    onPressed: () => ref.read(agentSkinProvider.notifier).set(next),
  );
}
