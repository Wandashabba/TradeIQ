import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// THE CONSOLE'S SKIN CYCLES WERE HERE, AND ARE GONE — 4 October 2026.
//
// Three things stood here: `ConsoleSkinCycle` (the thumb-zone form),
// `consoleSkinCycleButton` (the header-trailing form), and `consoleSkinModeOf`,
// which existed only to tell those two which glyph to draw. They were carried
// with the note *"never a screen without it: the one control that gets a person
// out of a skin they cannot read belongs on every screen they can reach"*.
//
// `console_page.dart` took the cycle off the console's four routes on 3 October
// and nothing has built any of them since — no call site in `lib`, and no test
// naming them, which is why their absence needs this comment rather than a
// `findsNothing`.
//
// The manager's theme control is the menu sheet's `THIS APP` section, which
// drives `themeModeProvider`. The owner has asked three times for it to be in
// exactly one place; zero-reference helpers for putting it back on a screen are
// not things to leave here.
//
// `consoleSkinProvider` itself stays — `ConsoleTorchlightRoute` above reads it
// to pick the console's skin, which is a different job from offering a control
// that writes it.
