import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/torchlight/button/buttons.dart';
import '../../widgets/torchlight/chrome/chrome.dart';
import '../../widgets/torchlight/skin_controls.dart';
import '../../../l10n/l10n.dart';
import '../app_theme.dart';
import 'tiq_skin.dart';

/// WHICH SKIN A MIGRATED **CONSOLE** ROUTE IS WEARING.
///
/// The agent's sibling is [agentSkinProvider]; this is the manager's, and the
/// two are deliberately separate. An agent is outdoors and defaults to Day; a
/// manager is at a desk or in a car park and defaults to **whatever the app
/// theme already said** — which is Night under `AppTheme.dark()` and Day under
/// `AppTheme.light()`, because both of those already register a `TiqSkin`.
///
/// Null therefore means *follow the app*, and it is the default: a manager who
/// has never touched the skin cycle sees exactly the brightness she chose in
/// settings, and nothing about migrating a route changes that.
///
/// ## Veld is manual-only here
///
/// unify §4 lets Veld be entered by solar elevation elsewhere in the app. Not
/// on a console route, and the reason is specific: an analysis surface is not
/// an outdoor surface. A manager reading a ranked answer at a north-facing
/// window at 11:40 should not have her layout reflow to one column, her type
/// jump two steps and her place in the answer move two screens down because
/// the sun came out. She reaches Veld — and leaves it — through the skin cycle
/// in the header, which is the exit this control exists to be.
///
/// Like the agent's, the choice is **session-scoped and not persisted**: the
/// per-user preferences table that Veld memory, handedness and the collapsed
/// plate all need is unify §6 question 13, and it does not exist yet.
class ConsoleSkinController extends Notifier<SkinMode?> {
  @override
  SkinMode? build() => null;

  void set(SkinMode mode) => state = mode == SkinMode.auto ? null : mode;
}

final consoleSkinProvider = NotifierProvider<ConsoleSkinController, SkinMode?>(
  ConsoleSkinController.new,
);

/// Resolve a console route's skin: the manager's override, or the skin the
/// ambient theme already registered.
///
/// Console density throughout — the manager is at a desk with a mouse, and
/// Field's 64dp rows are for someone standing up with one hand on a shelf.
/// Veld has one density by construction.
TiqSkin consoleSkinFor(SkinMode? mode, TiqSkin ambient) => switch (mode) {
  SkinMode.veld => TiqSkin.veld(),
  SkinMode.night => TiqSkin.night(density: TiqDensity.console),
  SkinMode.day => TiqSkin.day(density: TiqDensity.console),
  SkinMode.auto || null => ambient,
};

/// Wraps a migrated console route in its own Torchlight theme.
///
/// The same bring-your-own as [TorchlightRoute] on the agent side: nothing in
/// `main.dart` routes to the Torchlight themes while fifty-odd screens are
/// still painted in Lumen, so a migrated route brings its skin with it.
class ConsoleTorchlightRoute extends ConsumerWidget {
  const ConsoleTorchlightRoute({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = consoleSkinFor(ref.watch(consoleSkinProvider), context.skin);
    return Theme(data: AppTheme.torchlight(skin), child: child);
  }
}

/// The skin cycle in a console header's single trailing slot.
///
/// A function rather than a widget because [TorchAppHeader.trailing] is typed
/// as a `TorchIconButton`: the rule is *exactly one* trailing icon button, and
/// the type is how the chrome enforces it.
TorchIconButton consoleSkinCycleButton(BuildContext context, WidgetRef ref) {
  final mode = consoleSkinModeOf(context, ref);
  final next = TorchSkinCycle.next(mode);
  return TorchIconButton(
    icon: TorchSkinCycle.glyphFor(mode),
    // Names the NEXT state, never this one: a toggle that announces where it
    // is and not where it goes makes a blind manager press it to find out.
    semanticLabel: skinCycleLabel(context.l10n, mode),
    onPressed: () => ref.read(consoleSkinProvider.notifier).set(next),
  );
}

/// The mode the cycle is currently sitting at, resolving "follow the app" to
/// the mode the app actually resolved to.
SkinMode consoleSkinModeOf(BuildContext context, WidgetRef ref) =>
    ref.watch(consoleSkinProvider) ?? context.skin.mode;
