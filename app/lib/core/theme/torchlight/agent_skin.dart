import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import 'tiq_skin.dart';

/// WHICH SCREEN THE AGENT IS LOOKING AT — Day, Veld or Night.
///
/// The Torchlight skins exist and `AppTheme.torchlight(...)` builds a
/// [ThemeData] from any of them, but nothing in `main.dart` routes to them:
/// the other fifty-odd screens are still painted in Lumen and two other
/// workstreams are editing them. So a migrated agent route brings its own
/// skin with it rather than the app swapping underneath everything at once.
///
/// [TorchlightRoute] is that bring-your-own: it reads [agentSkinProvider] and
/// re-roots the theme for its subtree. Everything under it sees
/// `context.skin` in the chosen skin — and, because
/// [AppTheme.torchlight] also registers a `TiqColors.fromSkin`, a widget still
/// on `context.colors` renders in Torchlight tokens rather than throwing.
///
/// The choice is **session-scoped and not persisted**. unify §6 question 13
/// says the per-user preferences table that Veld memory, handedness and the
/// collapsed plate all need does not exist yet; writing this one into
/// `flutter_secure_storage` beside the manager's theme would be a second
/// storage stack for a preference that is about to get a real home. Veld
/// therefore never auto-expires *and* never survives a restart, and both of
/// those are said out loud rather than implied.
class AgentSkinController extends Notifier<SkinMode> {
  /// Day is the agent's default: they start outdoors at 06:30 and the paper
  /// skin is the one that reads in a car park.
  @override
  SkinMode build() => SkinMode.day;

  void set(SkinMode mode) => state = mode == SkinMode.auto ? SkinMode.day : mode;
}

final agentSkinProvider = NotifierProvider<AgentSkinController, SkinMode>(
  AgentSkinController.new,
);

/// Resolve a [SkinMode] to the skin an agent screen wears.
///
/// Night and Day are built at **field** density — the agent is standing up
/// with one hand on a shelf, so rows are 64dp and targets 48dp. Console
/// density belongs to the manager at a desk.
TiqSkin agentSkinFor(SkinMode mode) => switch (mode) {
  SkinMode.veld => TiqSkin.veld(),
  SkinMode.night => TiqSkin.night(density: TiqDensity.field),
  SkinMode.day || SkinMode.auto => TiqSkin.day(density: TiqDensity.field),
};

/// Wraps a migrated agent route in its own Torchlight theme.
class TorchlightRoute extends ConsumerWidget {
  const TorchlightRoute({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = agentSkinFor(ref.watch(agentSkinProvider));
    return Theme(data: AppTheme.torchlight(skin), child: child);
  }
}
