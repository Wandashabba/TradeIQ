import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';

/// Whether a notification's `route` may be opened: an in-app path only.
///
/// The payload comes from our own server, but it crosses FCM and lands in a
/// router, so it is checked anyway — no scheme, no `//host`. Which screens a
/// role may see stays the router's redirect's job, as for any other link.
bool isSafePushRoute(String route) {
  if (!route.startsWith('/') || route.startsWith('//') || route.contains(r'\')) {
    return false;
  }
  final uri = Uri.tryParse(route);
  return uri != null && !uri.hasScheme && !uri.hasAuthority;
}

/// Opens a tapped notification's route. A provider so tests can record it.
final pushRouteHandlerProvider = Provider<void Function(String route)>(
  (ref) =>
      (route) => ref.read(routerProvider).go(route),
);
