import 'package:flutter/widgets.dart';

import 'background_location_banner.dart';
import 'location_sharing_banner.dart';

/// The two location statements, for a Torchlight agent screen (#153 T1/T2).
///
/// "Am I being located right now?" must have a visible answer on **every**
/// agent screen, and the notice has to be somewhere an agent actually lands
/// before any ping is sent. The legacy `AgentScaffold` carried both banners;
/// a screen migrated onto `TorchShell` does not get them for free, and the
/// controllers behind them only start when something watches them — so a
/// migrated screen without this line silently drops the consent notice, the
/// indicator and the pings themselves.
///
/// Both render nothing for anyone who is not a field agent, and the
/// background one renders nothing off Android. Neither ever lights itself:
/// their yes asks `TorchScope` for a claim the route does not declare, so it
/// takes its ink form and the route's amber census is unchanged.
class AgentLocationBanners extends StatelessWidget {
  const AgentLocationBanners({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LocationSharingBanner(inset: false),
        BackgroundLocationBanner(inset: false),
      ],
    );
  }
}
