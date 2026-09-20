import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/torchlight/chrome/chrome.dart';
import '../../widgets/torchlight/skin_controls.dart';
import '../app_theme.dart';
import 'tiq_skin.dart';

/// WHICH SKIN THE WAY IN WEARS — the splash, sign-in, the reset code and the
/// refused build.
///
/// The third of three, and it exists because the other two both answer a
/// question these screens cannot ask. [agentSkinProvider] defaults to Day
/// because an agent starts outdoors at 06:30; [consoleSkinProvider] follows
/// the app theme because a manager already chose a brightness in settings.
/// **Before anyone signs in there is no role**, so there is no agent to have a
/// morning and no manager to have a setting.
///
/// So these screens default to **Night**, and the reason is the brand rather
/// than the light: the way in is the dimmed aisle, it has been since the
/// premium-ui redesign, and the first screen anyone sees is the one place in
/// this product where the ground is the message. Day and Veld are one tap away
/// on every one of them — a person locked out of their account in a car park
/// at 13:00 is exactly the person who needs Veld, and they reach it from the
/// same cycle as everybody else.
///
/// Field density: the first screen is met on a phone, standing up.
///
/// Like its two siblings the choice is **session-scoped and not persisted** —
/// unify §6 question 13's per-user preferences table does not exist yet, and a
/// second storage stack for a preference that is about to get a real home is
/// not worth writing twice.
class EntrySkinController extends Notifier<SkinMode> {
  @override
  SkinMode build() => SkinMode.night;

  void set(SkinMode mode) =>
      state = mode == SkinMode.auto ? SkinMode.night : mode;
}

final entrySkinProvider = NotifierProvider<EntrySkinController, SkinMode>(
  EntrySkinController.new,
);

/// Resolve a [SkinMode] to the skin an entry screen wears.
TiqSkin entrySkinFor(SkinMode mode) => switch (mode) {
  SkinMode.veld => TiqSkin.veld(),
  SkinMode.day => TiqSkin.day(density: TiqDensity.field),
  SkinMode.night || SkinMode.auto => TiqSkin.night(density: TiqDensity.field),
};

/// Wraps an entry route in its own Torchlight theme — the same bring-your-own
/// as `TorchlightRoute` on the agent side and `ConsoleTorchlightRoute` on the
/// manager's.
class EntryTorchlightRoute extends ConsumerWidget {
  const EntryTorchlightRoute({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = entrySkinFor(ref.watch(entrySkinProvider));
    return Theme(data: AppTheme.torchlight(skin), child: child);
  }
}

/// The skin cycle at the leading end of an entry screen's thumb zone.
///
/// Never a screen without it. Someone who cannot sign in is already stuck;
/// being stuck on a screen they cannot read is the version of that with no way
/// out at all.
class EntrySkinCycle extends ConsumerWidget {
  const EntrySkinCycle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(entrySkinProvider);
    return TorchSkinCycle(
      mode: mode,
      semanticLabel: skinCycleLabel(context.l10n, mode),
      onChanged: (next) => ref.read(entrySkinProvider.notifier).set(next),
    );
  }
}
