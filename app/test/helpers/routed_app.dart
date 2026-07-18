import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

/// ManagerScaffold/AgentScaffold read GoRouterState.of(context), so a screen
/// test must pump its screen under a real GoRoute — a bare
/// `MaterialApp(home: ...)` throws a GoError. Wrap the screen under test with
/// this instead.
///
/// NOTE: every agent screen now carries the sync chip, which watches the outbox.
/// Rendering one therefore opens the local database — so an agent-screen test
/// MUST override `localDbProvider` with an in-memory LocalDb, or it will reach
/// for the real on-disk connection and never settle.
Widget routedApp(
  Widget screen, {
  List<Override> overrides = const [],
  String path = '/screen',
  ThemeData? theme,
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: theme,
        routerConfig: GoRouter(
          initialLocation: path,
          routes: [GoRoute(path: path, builder: (context, state) => screen)],
        ),
      ),
    );
