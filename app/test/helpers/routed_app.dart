import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

/// ManagerScaffold/AgentScaffold read GoRouterState.of(context), so a screen
/// test must pump its screen under a real GoRoute — a bare
/// `MaterialApp(home: ...)` throws a GoError. Wrap the screen under test with
/// this instead.
Widget routedApp(
  Widget screen, {
  List<Override> overrides = const [],
  String path = '/screen',
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: path,
          routes: [GoRoute(path: path, builder: (context, state) => screen)],
        ),
      ),
    );
