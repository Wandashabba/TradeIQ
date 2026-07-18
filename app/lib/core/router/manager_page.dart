import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tiq_colors.dart';
import '../widgets/agent_motion.dart' show reduceMotion;

/// A go_router page for manager-shell destinations. Switching between
/// same-hierarchy top-level screens (Dashboard ↔ Tasks ↔ Alerts …) uses
/// Material's shared-axis (horizontal) transition — the documented pattern for
/// moving between peer top-level destinations. Under reduced motion it degrades
/// to a short fade. Agent/public routes do not use this helper.
CustomTransitionPage<void> managerPage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion(context)) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      }
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: context.colors.plane,
        child: child,
      );
    },
  );
}
