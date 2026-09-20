import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/torch_scope.dart';
import '../../../core/theme/torchlight/tiq_skin.dart';
import '../../../core/widgets/torchlight/button/buttons.dart';
import '../../../core/widgets/torchlight/chrome/chrome.dart';
import '../../../core/widgets/torchlight/state.dart';
import '../../../l10n/l10n.dart';
import '../data/territories_repository.dart';
import 'territory_map_screen.dart';

/// THE ROUTE'S OWN LOOKUP — a URL carries an id, and the map needs a place.
///
/// `/territories/:id/map` is a real address: it is pasted into a chat, opened
/// from a bookmark and reloaded on the web, and none of those arrive holding
/// the `Territory` the list screen would have handed over. So the gate resolves
/// the id against the list the console already has, and the three answers it
/// can get are three states rather than one blank screen:
///
/// * **loading** — the skeleton the map itself would show;
/// * **failed** — the sanitised error and one Retry;
/// * **no such territory** — a designed state. A deleted territory, a mistyped
///   id and a link from another client all land here, and "we could not find
///   that territory" is the honest thing to say about every one of them.
///   Guessing at the first row instead would open the wrong patch under the
///   right name.
class TerritoryMapGate extends ConsumerWidget {
  const TerritoryMapGate({super.key, required this.territoryId});

  final String territoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final skin = context.skin;
    final list = ref.watch(territoriesListProvider);

    Widget frame({required String phase, required Widget child}) {
      return TorchScope(
        skin: skin,
        phase: phase,
        navRenders: false,
        tabbedRoute: false,
        claims: const <TorchClaim>[],
        child: TorchShell(
          profile: TorchShellProfile.console,
          header: TorchAppHeader(
            title: l10n.territoryMapTitle,
            back: TorchIconButton(
              key: const ValueKey<String>('back-to-territories'),
              icon: Icons.arrow_back,
              semanticLabel: l10n.territoryBackToList,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          children: <Widget>[child],
        ),
      );
    }

    return list.when(
      loading: () => frame(
        phase: 'loading',
        child: Skeleton(
          label: l10n.territoryMapTitle,
          slowLine: l10n.torchStillFetching,
          child: const SkeletonRows(count: 3, rowHeight: 64),
        ),
      ),
      error: (error, _) => frame(
        phase: 'error',
        child: TorchErrorRegion(
          name: 'territory',
          child: ErrorState(
            message: TorchErrorMessage.sanitise(error),
            action: TorchSecondaryButton(
              key: const ValueKey<String>('territory-gate-retry'),
              label: l10n.torchTryAgain,
              onPressed: () => ref.invalidate(territoriesListProvider),
            ),
          ),
        ),
      ),
      data: (territories) {
        for (final territory in territories) {
          if (territory.id == territoryId) {
            return TerritoryMapScreen(territory: territory);
          }
        }
        return frame(
          phase: 'not-found',
          child: EmptyState(
            drawing: EmptyDrawing.pin,
            headline: l10n.territoryNotFoundHeadline,
            body: l10n.territoryNotFoundBody,
            action: TorchSecondaryButton(
              key: const ValueKey<String>('territory-not-found-back'),
              label: l10n.territoryBackToList,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
    );
  }
}
