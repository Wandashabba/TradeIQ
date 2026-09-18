import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../sync/sync_status.dart';
import 'mark/status_chip.dart';

/// THE SYNC CHIP — the answer to the question a field agent asks all day:
/// *is my work safe?*
///
/// A configuration of [StatusChip], not a second chip. It chooses a level, a
/// word and a tap target; the silhouette, the geometry, the contrast and the
/// "no amber, ever" all come from the mark set. unify §1.14 rules one
/// component in two forms — the chip is the default and the 56dp banner
/// renders only for NEEDS-YOU and OFFLINE-ENTIRELY. The banner form is not
/// built yet; the chip carries the needs-you state at its `critical` level
/// meanwhile, and says so in words.
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
    final data = status.valueOrNull;
    if (data == null) return const SizedBox.shrink();

    final go = onTap ?? () => context.go('/my-work');

    if (data.needsAttention.isNotEmpty) {
      final n = data.needsAttention.length;
      return StatusChip(
        level: StatusLevel.critical,
        label: l10n.syncChipNeedsYou(n),
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
