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
/// theme already said**, because every theme registers a `TiqSkin`.
///
/// That is Night under `AppTheme.night()` and Day under `AppTheme.day()` —
/// the two `main.dart` actually wires to `theme`/`darkTheme`. This paragraph
/// named `AppTheme.light()` and `AppTheme.dark()` until 29 September 2026;
/// those exist, and they register a **console** skin, but nothing routes to
/// them. The pair that ships registers a *field* skin on the Day arm, which
/// is precisely the density [consoleSkinFor] now has to correct, and naming
/// the wrong pair here is part of why it went unnoticed for so long.
///
/// Null therefore means *follow the app*, and it is the default: a manager who
/// has never touched the skin cycle sees exactly the brightness she chose in
/// settings, and nothing about migrating a route changes that.
///
/// Like the agent's, the choice is **session-scoped and not persisted**: the
/// per-user preferences table that handedness and the collapsed plate both
/// need is unify §6 question 13, and it does not exist yet.
class ConsoleSkinController extends Notifier<SkinMode?> {
  @override
  SkinMode? build() => null;

  void set(SkinMode mode) => state = mode == SkinMode.auto ? null : mode;
}

final consoleSkinProvider = NotifierProvider<ConsoleSkinController, SkinMode?>(
  ConsoleSkinController.new,
);

/// Resolve a console route's skin: the manager's override, or the skin the
/// ambient theme already registered, **at console density either way**.
///
/// Console density throughout — the manager is at a desk with a mouse, and
/// Field's geometry is for someone standing up with one hand on a shelf.
///
/// THE `auto` ARM USED TO HAND BACK THE AMBIENT SKIN UNTOUCHED, AND THAT WAS
/// A DEFECT. `main.dart` builds the light theme with `AppTheme.day()`, whose
/// density parameter defaults to **field**, so the ambient skin in light mode
/// is a field skin. A manager who had never touched the skin cycle — which is
/// the default, since `mode` starts null — was handed the agent's geometry on
/// every migrated console route: a 96dp header instead of 72, a 232dp trend
/// chart instead of 208, 32dp chips, a 96dp stat-tile floor and a 6px meter
/// track. The two branches directly above it were already forcing console, so
/// cycling the skin once and cycling back *fixed* it, which is the shape of a
/// bug and not of a design.
///
/// It went unseen because `themeMode` defaults to dark and the two arms that
/// name a density cover every case a test exercises. #490 removed the sibling
/// half of this — a bare `TiqSkin.day()` no longer means field — but left
/// `AppTheme.day({density = field})` alone deliberately, so `main.dart`'s
/// light theme still registers a field skin and this arm still inherited it.
///
/// The owner's standing instruction is not to change the manager side. This
/// changes it, in light mode only, and it is the one exception they would
/// want: what that instruction protects is the console they approved, and
/// nobody has ever approved a manager screen wearing the agent's geometry.
/// See the PR body, which states the movement plainly rather than folding it
/// into the spacing work.
TiqSkin consoleSkinFor(SkinMode? mode, TiqSkin ambient) => switch (mode) {
  SkinMode.night => TiqSkin.night(density: TiqDensity.console),
  SkinMode.day => TiqSkin.day(density: TiqDensity.console),
  // Keep the ambient BRIGHTNESS — "follow the app" is about light and dark,
  // and it always was — but never inherit its density.
  SkinMode.auto || null =>
    ambient.space.density == TiqDensity.console
        ? ambient
        : TiqSkin.of(ambient.mode, density: TiqDensity.console),
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

/// The skin cycle at the leading end of a console thumb zone — every console
/// screen that is not a tab root.
///
/// The header's single trailing slot is taken by a route's own action on a
/// form (or is simply absent), and unify §1.2 puts the cycle in the thumb zone
/// everywhere else. Never a screen without it: the one control that gets a
/// person out of a skin they cannot read belongs on every screen they can
/// reach.
class ConsoleSkinCycle extends ConsumerWidget {
  const ConsoleSkinCycle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = consoleSkinModeOf(context, ref);
    return TorchSkinCycle(
      mode: mode,
      semanticLabel: skinCycleLabel(context.l10n, mode),
      onChanged: (next) => ref.read(consoleSkinProvider.notifier).set(next),
    );
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
