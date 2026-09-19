import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../sync/sync_status.dart';
import 'mark/status_chip.dart';
import 'state/held_banner.dart';

/// THE SYNC CHIP — the answer to the question a field agent asks all day:
/// *is my work safe?*
///
/// A configuration of [StatusChip], not a second chip. It chooses a level, a
/// word and a tap target; the silhouette, the geometry, the contrast and the
/// "no amber, ever" all come from the mark set. unify §1.14 rules one
/// component in two forms — the chip is the default and the 56dp banner
/// ([TorchSyncBanner]) renders only for NEEDS-YOU. The chip still carries the
/// needs-you state at its `critical` level, because a screen may show both:
/// the header answers "is my work safe?" at a glance and the band says what
/// to do about it.
///
/// The one rule this component exists to enforce: **held is never an error**.
/// Twelve captures on the phone with no signal is the normal state of South
/// African field connectivity, and it takes the Oatmeal square, never crimson
/// and never a severity.
///
/// Suppressed on the screen it opens: a chip on My work is a link to itself.
class TorchSyncChip extends ConsumerWidget {
  const TorchSyncChip({super.key, this.onTap});

  /// Where the chip goes. Defaults to My work; pass something else, or null,
  /// where that would be a link to the screen the agent is already on.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(syncStatusProvider);

    // LOADING is not a state with its own copy: the outbox is a local stream
    // and it answers in a frame. An absent answer renders nothing rather than
    // a chip that says something it does not know.
    final data = status.value;
    if (data == null) return const SizedBox.shrink();

    final go = onTap ?? () => context.go('/my-work');

    if (data.needsAttention.isNotEmpty) {
      final n = data.needsAttention.length;
      return StatusChip(
        level: StatusLevel.critical,
        label: l10n.syncBannerNeedsYou(n),
        onTap: go,
        semanticsLabel: l10n.syncChipNeedsYouSemantics(n),
      );
    }
    if (data.allSent) {
      return StatusChip(
        level: StatusLevel.onTarget,
        label: l10n.syncChipAllSent,
        onTap: go,
        semanticsLabel: l10n.syncChipAllSentSemantics,
      );
    }
    final n = data.pendingCount;
    return StatusChip(
      // Held. An Oatmeal square and a word — never a severity, because
      // nothing is wrong.
      level: StatusLevel.held,
      label: l10n.syncChipHeld(n),
      onTap: go,
      semanticsLabel: l10n.syncChipHeldSemantics(n),
    );
  }
}

/// THE BANNER FORM — the same component, promoted (unify §1.14).
///
/// A chip in the header is the default and this band is the exception: it
/// renders **only for NEEDS-YOU**, because a permanent 56dp strip on every
/// screen spends the fold, and because held work is not news. Everything else
/// — held, sending, all sent — stays a chip.
///
/// **OFFLINE-ENTIRELY is not built.** The ruling gives the banner two states
/// and the second one needs a connectivity channel this app does not have: no
/// plugin, no provider, nothing that knows whether a radio is up. A band that
/// announced "No signal" on a guess would be worse than one that says nothing,
/// and the held state already tells the truth about what is on the phone.
///
/// Held is Oatmeal and needs-you is the only state that raises a colour —
/// [OfflineHeldBanner] owns both, and neither of them is ever amber.
class TorchSyncBanner extends ConsumerWidget {
  const TorchSyncBanner({super.key, this.onTap});

  /// Where the band goes. Defaults to My work; pass null on the screen it
  /// opens, where it would be a link to itself.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = ref.watch(syncStatusProvider).value;
    // It never guesses, and it never claims everything is fine: an absent
    // answer renders nothing at all.
    if (data == null || data.needsAttention.isEmpty) {
      return const SizedBox.shrink();
    }
    final n = data.needsAttention.length;
    return OfflineHeldBanner(
      state: SyncState.needsYou,
      count: n,
      label: l10n.syncBannerNeedsYou(n),
      subtitle: l10n.syncAttentionSubtitle,
      openLabel: l10n.syncBannerOpen,
      onTap: onTap ?? () => context.go('/my-work'),
    );
  }
}
